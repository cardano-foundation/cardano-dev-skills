"""Core chain query implementation that wraps BlockFrost and Kupo/Ogmios contexts.

Provides unified interface for blockchain interactions with robust error handling,
accurate time calculations, and configurable parameters.
"""

import asyncio
import logging
import time
from dataclasses import dataclass

import requests
from blockfrost import ApiError
from pycardano import (
    Address,
    AssetName,
    BlockFrostChainContext,
    ExtendedSigningKey,
    GenesisParameters,
    NativeScript,
    Network,
    PaymentSigningKey,
    PlutusV3Script,
    ScriptHash,
    Transaction,
    TransactionBuilder,
    TransactionId,
    TransactionInput,
    TransactionOutput,
    UTxO,
)
from pycardano.backend.kupo import KupoChainContextExtension

from .exceptions import (
    ChainContextError,
    CollateralError,
    NetworkConfigError,
    ScriptQueryError,
    TransactionConfirmationError,
    TransactionSubmissionError,
    UTxOQueryError,
)
from .network import NetworkConfig, NetworkType, get_network_type

logger = logging.getLogger(__name__)

NotFoundErrorCode = 404


@dataclass
class ChainQueryConfig:
    """Configuration parameters for chain query operations."""

    # Transaction handling
    max_retries: int = 10
    retry_delay: int = 20  # seconds
    submission_timeout: int = 120  # seconds
    utxo_refresh_delay: int = 5  # seconds

    # Collateral settings
    min_collateral: int = 5_000_000  # lovelace
    max_collateral: int = 20_000_000  # lovelace
    collateral_buffer: int = 1_000_000  # acceptable variance

    # Transaction parameters
    validity_start_offset: int = 0
    ttl_offset: int = 120
    min_utxo_value: int = 2_000_000

    # Time handling
    use_wall_clock: bool = False
    network_config: NetworkConfig | None = None


class ChainQuery:
    """Unified interface for blockchain operations using either Blockfrost or Kupo/Ogmios."""

    def __init__(
        self,
        blockfrost_context: BlockFrostChainContext | None = None,
        kupo_ogmios_context: KupoChainContextExtension | None = None,
        config: ChainQueryConfig | None = None,
    ) -> None:
        """Initialize chain query interface.

        Args:
            blockfrost_context: Optional Blockfrost chain context
            kupo_ogmios_context: Optional Kupo/Ogmios chain context
            config: Optional configuration parameters

        Raises:
            ChainContextError: If no valid context is provided
        """
        if not blockfrost_context and not kupo_ogmios_context:
            raise ChainContextError(
                "Must provide either Blockfrost or Kupo/Ogmios context"
            )

        self.blockfrost = blockfrost_context
        self.ogmios = kupo_ogmios_context
        self.context = blockfrost_context or kupo_ogmios_context
        self.config = config or ChainQueryConfig()

        # Initialize network config if not provided
        if not self.config.network_config:
            try:
                if self.blockfrost:
                    network_type = (
                        NetworkType.MAINNET
                        if self.blockfrost.network == Network.MAINNET
                        else NetworkType.PREPROD
                    )
                elif self.ogmios:
                    network_type = (
                        NetworkType.MAINNET
                        if self.ogmios.network == Network.MAINNET
                        else NetworkType.PREPROD
                    )
                else:
                    network_type = get_network_type(self.genesis_params.network_magic)

                self.config.network_config = NetworkConfig.from_network(network_type)
            except Exception as e:
                raise NetworkConfigError(
                    f"Failed to initialize network config: {e}"
                ) from e

    async def _refresh_utxos(self, addresses: list[str | Address]) -> None:
        """Refresh UTxO cache for given addresses after waiting for chain update."""
        # Wait for chain to update
        await asyncio.sleep(self.config.utxo_refresh_delay)

        # Clear cache
        self._invalidate_cache_for_addresses(addresses)

        # Force refresh by querying UTxOs
        for address in addresses:
            try:
                _ = await self.get_utxos(address)
            except UTxOQueryError:
                logger.warning("Failed to refresh UTxOs for address: %s", address)

    def _invalidate_cache_for_addresses(self, addresses: list[str | Address]) -> None:
        """Invalidate Kupo cache for given addresses."""
        if isinstance(self.context, KupoChainContextExtension):
            for address in addresses:
                addr_str = str(address)
                addr_key = f"address_{addr_str}"
                if addr_key in self.context._utxo_cache:
                    del self.context._utxo_cache[addr_key]

    @property
    def genesis_params(self) -> GenesisParameters:
        """Get genesis parameters for the network."""
        if not self.context:
            raise ChainContextError("No chain context available")
        return self.context.genesis_param

    @property
    def last_block_slot(self) -> int:
        """Get latest block slot number."""
        if not self.context:
            raise ChainContextError("No chain context available")
        return self.context.last_block_slot

    def get_current_posix_chain_time_ms(self) -> int:
        """Get current chain time in milliseconds.

        Uses either wall clock or network time based on configuration.
        """
        if self.config.use_wall_clock:
            return round(time.time_ns() * 1e-6)

        slot = self.last_block_slot
        return self.config.network_config.slot_to_posix(slot)

    async def get_plutus_script(self, script_hash: ScriptHash) -> PlutusV3Script | None:
        """Get Plutus script by hash.

        Args:
            script_hash: Script hash to query

        Returns:
            PlutusV3Script

        Raises:
            ScriptQueryError: If script cannot be found or retrieved
        """
        try:
            if isinstance(self.context, BlockFrostChainContext):
                script = self.context._get_script(str(script_hash))
            else:
                kupo_script_url = f"{self.context._kupo_url}/scripts/{script_hash}"
                script = await asyncio.to_thread(
                    lambda: requests.get(kupo_script_url, timeout=(5, 15)).json()
                )
                if script["language"] == "plutus:v3":
                    script = PlutusV3Script(bytes.fromhex(script["script"]))
            if not script:
                raise ScriptQueryError(f"Script not found for hash: {script_hash}")

            return script

        except Exception as e:
            raise ScriptQueryError(f"Failed to get script: {e}") from e

    async def get_utxos(self, address: str | Address) -> list[UTxO]:
        """Get UTxOs at an address.

        Args:
            address: Target address

        Returns:
            List of UTxOs

        Raises:
            UTxOQueryError: If UTxO query fails
        """
        if not self.context:
            raise ChainContextError("No chain context available")

        try:
            if isinstance(address, str):
                address = Address.from_primitive(address)
            return self.context.utxos(str(address))

        except ApiError as e:
            raise UTxOQueryError(f"Failed to query UTxOs: {e}") from e
        except Exception as e:
            raise UTxOQueryError(f"Unexpected error querying UTxOs: {e}") from e

    def get_utxos_with_asset_from_kupo(
        self, asset_policy_id: ScriptHash, asset_name: AssetName
    ) -> list[UTxO]:
        """Get UTxOs containing some asset using kupo.

        Args:
            asset_policy_id (ScriptHash): Policy ID - asset minting script hash.
            asset_name (AssetName): asset name.

        Returns:
            List of UTxOs

        Raises:
            ChainContextError: Kupo context was not set up
            UTxOQueryError: If UTxO query fails
        """
        if not self.context:
            raise ChainContextError("No chain context available")
        if not isinstance(self.context, KupoChainContextExtension):
            raise ChainContextError("Kupo context was not set up")

        try:
            return self.context._utxos_with_asset_kupo(asset_policy_id, asset_name)

        except ApiError as e:
            raise UTxOQueryError(f"Failed to query UTxOs: {e}") from e
        except Exception as e:
            raise UTxOQueryError(f"Unexpected error querying UTxOs: {e}") from e

    def get_utxo_by_ref_kupo(self, utxo_reference: TransactionInput) -> UTxO | None:
        """Get a UTxO associated with a reference - transaction id and output index number.

        Args:
            utxo_reference (TransactionInput): reference - transaction id and output index number.

        Returns:
            Optional[UTxO]: A UTxO.

        Raises:
            ChainContextError: Kupo context was not set up
            UTxOQueryError: If UTxO query fails
        """
        if not self.context:
            raise ChainContextError("No chain context available")
        if not isinstance(self.context, KupoChainContextExtension):
            raise ChainContextError("Kupo context was not set up")

        try:
            return self.context._utxo_by_ref_kupo(utxo_reference)

        except ApiError as e:
            raise UTxOQueryError(f"Failed to query UTxOs: {e}") from e
        except Exception as e:
            raise UTxOQueryError(f"Unexpected error querying UTxOs: {e}") from e

    async def get_or_create_collateral(
        self,
        address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        amount: int | None = None,
    ) -> UTxO | None:
        """Get existing collateral or create new one.

        Args:
            address: Address for collateral
            signing_key: Signing key for new collateral
            amount: Optional specific amount

        Returns:
            Collateral UTxO if found/created

        Raises:
            CollateralError: If collateral cannot be obtained
        """
        amount = amount or self.config.min_collateral

        # Try find existing
        collateral = await self.find_collateral(address, amount)
        if collateral:
            return collateral

        # Create new
        try:
            logger.info(
                "Creating collateral for address: %s, amount: %d", address, amount
            )

            await self.create_collateral(address, signing_key, amount)
            # Refresh cache and try find again
            await self._refresh_utxos([address])
            return await self.find_collateral(address, amount)
        except Exception as e:
            raise CollateralError(f"Failed to create collateral: {e}") from e

    async def find_collateral(
        self, address: str | Address, required_amount: int
    ) -> UTxO | None:
        """Find suitable collateral UTxO at address.

        Args:
            address: Address to search
            required_amount: Required collateral amount in lovelace

        Returns:
            Suitable UTxO if found, None otherwise

        Raises:
            UTxOQueryError: If UTxO query fails
        """
        try:
            utxos = await self.get_utxos(address)

            return next(
                (
                    utxo
                    for utxo in utxos
                    if not utxo.output.amount.multi_asset
                    and required_amount
                    <= utxo.output.amount.coin
                    <= required_amount + self.config.collateral_buffer
                ),
                None,
            )
        except UTxOQueryError:
            raise
        except Exception as e:  # pylint: disable=broad-except
            logger.warning("Error finding collateral: %s", e)

        return None

    async def create_collateral(
        self,
        address: str | Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        amount: int,
    ) -> None:
        """Create new collateral UTxO.

        Args:
            address: Target address
            signing_key: Signing key for transaction
            amount: Collateral amount in lovelace

        Raises:
            TransactionSubmissionError: If transaction fails
            CollateralError: If amount is invalid
        """
        # Validate amount
        if not self.config.min_collateral <= amount <= self.config.max_collateral:
            raise CollateralError(
                f"Collateral amount {amount} outside valid range "
                f"({self.config.min_collateral}-{self.config.max_collateral})"
            )

        try:
            if isinstance(address, str):
                address = Address.from_primitive(address)

            # Build and submit transaction
            builder = TransactionBuilder(self.context)
            builder.add_input_address(address)
            builder.add_output(TransactionOutput(address, amount))

            signed_tx = builder.build_and_sign(
                [signing_key],
                change_address=address,
            )

            status, _ = await self.submit_tx(signed_tx)
            if status != "confirmed":
                raise TransactionSubmissionError(
                    f"Collateral creation failed with status: {status}"
                )

            # Refresh UTxO cache after collateral creation
            await self._refresh_utxos([address])

        except Exception as e:
            raise CollateralError(f"Failed to create collateral: {e}") from e

    async def submit_tx(
        self, tx: Transaction, wait_confirmation: bool = True
    ) -> tuple[str, Transaction | None]:
        """Submit transaction and optionally wait for confirmation.

        Args:
            tx: Transaction to submit
            wait_confirmation: Whether to wait for confirmation

        Returns:
            Tuple of (status, transaction)

        Raises:
            TransactionSubmissionError: If submission fails
        """
        if not self.context:
            raise ChainContextError("No chain context available")

        try:
            status = "submitting"
            logger.info("Submitting transaction: %s", tx.id)

            # Submit
            if self.blockfrost:
                self.blockfrost.submit_tx(tx.to_cbor())
            else:
                self.ogmios.submit_tx(tx.to_cbor())

            status = "submitted"

            # Clear cache for affected addresses
            addresses = [output.address for output in tx.transaction_body.outputs]
            self._invalidate_cache_for_addresses(addresses)

            if not wait_confirmation:
                return status, tx

            # Wait for confirmation
            status, confirmed_tx = await self._wait_for_confirmation(tx.id)
            if status == "confirmed":
                logger.info("Transaction confirmed: %s", tx.id)
            elif status == "timeout":
                logger.warning("Transaction confirmation timeout: %s", tx.id)

            return status, confirmed_tx

        except Exception as e:
            status = "failed"
            logger.error("Transaction submission failed: %s", e)
            raise TransactionSubmissionError(f"{status}: {e}") from e

    async def _wait_for_confirmation(
        self, tx_id: TransactionId, timeout: int | None = None
    ) -> tuple[str, Transaction | None]:
        """Wait for transaction confirmation with timeout and retries.

        Args:
            tx_id: Transaction ID to monitor
            timeout: Optional custom timeout in seconds

        Returns:
            Tuple of (status, transaction)

        Raises:
            TransactionConfirmationError: If confirmation fails
        """
        timeout = timeout or self.config.submission_timeout
        retries = 0
        tx_id = str(tx_id)

        async def check_blockfrost(tx_id: TransactionId) -> Transaction | None:
            """Check transaction status using Blockfrost."""
            try:
                return self.blockfrost.api.transaction(tx_id)
            except ApiError as e:
                if (
                    e.status_code != NotFoundErrorCode
                ):  # 404 just means not confirmed yet
                    raise TransactionConfirmationError(
                        f"Error checking transaction: {e}"
                    ) from e
                return None

        async def check_ogmios(tx_id: TransactionId) -> Transaction | None:
            """Check transaction status using Ogmios."""
            try:
                # Use UTxO query as a proxy for transaction confirmation
                response = self.context._wrapped_backend._query_utxos_by_tx_id(tx_id, 0)
                return response if response != [] else None
            except Exception as e:
                raise TransactionConfirmationError(
                    f"Error checking transaction: {e}"
                ) from e

        # Select appropriate check function
        check_fn = (
            check_blockfrost
            if isinstance(self.context, BlockFrostChainContext)
            else check_ogmios
        )

        while retries < self.config.max_retries:
            try:
                tx = await check_fn(tx_id)
                if tx:
                    logger.info("Transaction confirmed: %s", tx_id)
                    return "confirmed", tx

            except TransactionConfirmationError:
                raise

            await asyncio.sleep(self.config.retry_delay)
            retries += 1
            logger.info(
                "Waiting for confirmation (attempt %d/%d)",
                retries,
                self.config.max_retries,
            )

        return "timeout", None

    async def submit_tx_builder(
        self,
        builder: TransactionBuilder,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        address: Address,
        collateral_amount: int | None = None,
    ) -> tuple[str, Transaction]:
        """Build, sign and submit a transaction.

        Args:
            builder: Transaction builder
            signing_key: Signing key
            address: Address for change/collateral
            collateral_amount: Optional specific collateral amount

        Returns:
            Tuple of (status, transaction)

        Raises:
            CollateralError: If collateral handling fails
            TransactionSubmissionError: If submission fails
        """
        try:
            # Get collateral
            if collateral_amount:
                collateral = await self.get_or_create_collateral(
                    address, signing_key, collateral_amount
                )
                if collateral:
                    builder.collaterals.append(collateral)
                    builder.required_signers = [address.payment_part]
                else:
                    raise CollateralError("Failed to get collateral")

            # Add input address for fees/balancing
            builder.add_input_address(address)

            # Build and sign transaction
            signed_tx = builder.build_and_sign(
                [signing_key],
                change_address=address,
                validity_start=self.config.validity_start_offset,
                ttl=self.config.ttl_offset,
            )

            # Submit and wait for confirmation
            status, tx = await self.submit_tx(signed_tx)
            if status not in ["confirmed", "submitted"]:
                raise TransactionSubmissionError(
                    f"Transaction failed with status: {status}"
                )

            return status, tx

        except Exception as e:
            raise TransactionSubmissionError(f"Transaction failed: {e}") from e

    async def get_native_script(self, script_hash: ScriptHash) -> NativeScript | None:
        """Get native script by hash."""
        try:
            if isinstance(self.context, BlockFrostChainContext):
                script = self.context._get_script(str(script_hash))
            else:
                kupo_script_url = f"{self.context._kupo_url}/scripts/{script_hash}"
                script_json = await asyncio.to_thread(
                    lambda: requests.get(kupo_script_url, timeout=(5, 15)).json()
                )
                if not isinstance(script_json, dict):
                    raise ScriptQueryError(
                        f"Script not found or invalid response for hash: {script_hash}"
                    )
                script = NativeScript.from_cbor(script_json["script"])
            if not script:
                raise ScriptQueryError(f"Script not found for hash: {script_hash}")

            return script

        except Exception as e:
            raise ScriptQueryError(f"Failed to get script: {e}") from e

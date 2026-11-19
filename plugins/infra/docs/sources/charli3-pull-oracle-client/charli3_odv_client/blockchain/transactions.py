"""Transaction management utilities for building, signing and submitting transactions."""

import logging
from dataclasses import dataclass

from pycardano import (
    Address,
    BlockFrostChainContext,
    ExtendedSigningKey,
    MultiAsset,
    PaymentSigningKey,
    PlutusV3Script,
    Redeemer,
    Transaction,
    TransactionBuilder,
    TransactionInput,
    TransactionOutput,
    UTxO,
    VerificationKeyHash,
    VerificationKeyWitness,
)

from charli3_odv_client.blockchain.chain_query import ChainQuery
from charli3_odv_client.blockchain.exceptions import (
    CollateralError,
    TransactionBuildError,
    TransactionSubmissionError,
)

logger = logging.getLogger(__name__)


@dataclass
class TransactionConfig:
    """Transaction building configuration."""

    validity_offset: int = 0
    ttl_offset: int = 180
    extra_collateral: int = 13_000_000

    min_utxo_value: int = 2_000_000
    default_script_utxo_cost: int = 5_000_000


@dataclass
class ValidityWindow:
    """Validity start, end, and current time."""

    validity_start: int
    validity_end: int
    current_time: int


class TransactionManager:
    """Manages transaction building and submission."""

    def __init__(
        self, chain_query: ChainQuery, config: TransactionConfig | None = None
    ) -> None:
        self.chain_query = chain_query
        self.config = config or TransactionConfig()

    async def _get_collateral(
        self,
        address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
    ) -> UTxO | None:
        """Get or create collateral UTxO for script transaction."""
        logger.info("Finding collateral UTxO for script transaction")

        return await self.chain_query.get_or_create_collateral(
            address, signing_key, self.config.extra_collateral
        )

    async def _prepare_builder(
        self,
        builder: TransactionBuilder,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        metadata: dict | None = None,
        required_signers: list[VerificationKeyHash] | None = None,
        external_collateral: int = 0,
    ) -> None:
        """Prepare transaction builder with inputs, collateral, and metadata."""
        # Add required signers
        if required_signers:
            if builder.required_signers is None:
                builder.required_signers = required_signers
            else:
                builder.required_signers.extend(required_signers)

        # Add metadata if provided
        if metadata:
            builder.auxiliary_data = metadata

        # Handle collateral first if needed for script transactions
        if len(builder.scripts) > 0:
            collateral_utxo = await self._get_collateral(change_address, signing_key)
            if not collateral_utxo:
                raise CollateralError("Failed to get collateral")
            builder.collaterals.append(collateral_utxo)

        # Add collateral from an external address if no script is specified.
        if external_collateral > 0:
            logger.info(
                f"Creating collateral UTxO with {external_collateral // 1_000_000} ADA amount"
            )
            external_collateral_utxo = await self.chain_query.get_or_create_collateral(
                change_address, signing_key, external_collateral
            )
            if not external_collateral_utxo:
                raise CollateralError("Failed to get collateral")
            builder.collaterals.append(external_collateral_utxo)

        # Add input address for fees/balancing after collateral is handled
        # This ensures we have the latest UTxO state
        builder.add_input_address(change_address)

    async def build_simple_payment(
        self,
        outputs: list[TransactionOutput],
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        metadata: dict | None = None,
    ) -> Transaction:
        """Build simple payment transaction."""
        builder = TransactionBuilder(self.chain_query.context)

        # Add outputs
        for output in outputs:
            builder.add_output(output)

        return await self.build_tx(
            builder=builder,
            change_address=change_address,
            signing_key=signing_key,
            metadata=metadata,
        )

    async def build_script_tx(
        self,
        script_inputs: list[tuple[UTxO, Redeemer, UTxO | PlutusV3Script | None]],
        script_outputs: list[TransactionOutput],
        reference_inputs: set[UTxO | TransactionInput] | None = None,
        mint: MultiAsset | None = None,
        mint_redeemer: Redeemer | None = None,
        mint_script: PlutusV3Script | None = None,
        required_signers: list[VerificationKeyHash] | None = None,
        change_address: Address = None,
        signing_key: PaymentSigningKey | ExtendedSigningKey = None,
        validity_start: int | None = None,
        validity_end: int | None = None,
        fee_buffer: int | None = None,
        metadata: dict | None = None,
        external_collateral: int = 0,
    ) -> Transaction:
        """Build script interaction transaction."""
        try:
            builder = TransactionBuilder(
                self.chain_query.context, fee_buffer=fee_buffer
            )

            # Add script inputs
            for utxo, redeemer, script in script_inputs:
                builder.add_script_input(utxo=utxo, script=script, redeemer=redeemer)

            # Add script outputs with datums
            for output in script_outputs:
                builder.add_output(output)

            # Add reference inputs
            if reference_inputs:
                builder.reference_inputs.update(reference_inputs)

            # Add minting if specified
            if mint and mint_script and mint_redeemer:
                builder.mint = mint
                builder.add_minting_script(script=mint_script, redeemer=mint_redeemer)

            return await self.build_tx(
                builder=builder,
                change_address=change_address,
                signing_key=signing_key,
                metadata=metadata,
                required_signers=required_signers,
                validity_start=validity_start,
                validity_end=validity_end,
                external_collateral=external_collateral,
            )

        except Exception as e:
            raise TransactionBuildError(
                f"Failed to build script transaction: {e}"
            ) from e

    async def build_reference_script_tx(
        self,
        script: PlutusV3Script,
        script_address: Address,
        admin_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        reference_ada: int | None = None,
    ) -> Transaction:
        """Build transaction to publish reference script."""
        try:
            builder = TransactionBuilder(self.chain_query.context)

            # Create reference script output
            reference_amount = reference_ada or self.config.default_script_utxo_cost
            reference_output = TransactionOutput(
                address=script_address, amount=reference_amount, script=script
            )
            builder.add_output(reference_output)

            return await self.build_tx(
                builder=builder, change_address=admin_address, signing_key=signing_key
            )

        except Exception as e:
            raise TransactionBuildError(
                f"Failed to build reference script tx: {e}"
            ) from e

    async def build_tx(
        self,
        builder: TransactionBuilder,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        metadata: dict | None = None,
        required_signers: list[VerificationKeyHash] | None = None,
        validity_start: int | None = None,
        validity_end: int | None = None,
        external_collateral: int = 0,
    ) -> Transaction:
        """Build transaction with proper inputs and collateral."""
        try:
            # Prepare builder with all necessary components
            await self._prepare_builder(
                builder=builder,
                change_address=change_address,
                signing_key=signing_key,
                metadata=metadata,
                required_signers=required_signers,
                external_collateral=external_collateral,
            )

            # Set manual validity period if provided
            if validity_start is not None:
                builder.validity_start = validity_start
            if validity_end is not None:
                builder.ttl = validity_end

            # Build transaction components
            tx_body = builder.build(
                change_address=change_address,
                auto_validity_start_offset=(
                    None if validity_start is not None else self.config.validity_offset
                ),
                auto_ttl_offset=(
                    None if validity_end is not None else self.config.ttl_offset
                ),
            )

            # Create initial witness set
            witness_set = builder.build_witness_set()
            witness_set.vkey_witnesses = []

            return Transaction(
                tx_body, witness_set, auxiliary_data=builder.auxiliary_data
            )

        except Exception as e:
            raise TransactionBuildError(f"Failed to build transaction: {e}") from e

    def sign_tx(
        self, tx: Transaction, signing_key: PaymentSigningKey | ExtendedSigningKey
    ) -> None:
        """Sign transaction with key."""
        signature = signing_key.sign(tx.transaction_body.hash())

        # Initialize vkey_witnesses if needed
        if tx.transaction_witness_set.vkey_witnesses is None:
            tx.transaction_witness_set.vkey_witnesses = []

        # Add witness
        tx.transaction_witness_set.vkey_witnesses.append(
            VerificationKeyWitness(signing_key.to_verification_key(), signature)
        )

    async def sign_and_submit(
        self,
        tx: Transaction,
        signing_keys: list[PaymentSigningKey | ExtendedSigningKey],
        wait_confirmation: bool = True,
    ) -> tuple[str, Transaction]:
        """Sign with multiple keys and submit."""
        try:
            # Sign with all provided keys
            for key in signing_keys:
                self.sign_tx(tx, key)

            # Submit and wait for confirmation if requested
            status, submitted_tx = await self.chain_query.submit_tx(
                tx, wait_confirmation=wait_confirmation
            )

            if status not in ["confirmed", "submitted"]:
                raise TransactionSubmissionError(
                    f"Transaction failed with status: {status}"
                )

            return status, submitted_tx

        except Exception as e:
            raise TransactionSubmissionError(
                f"Failed to submit transaction: {e}"
            ) from e

    async def estimate_execution_units(self, tx: Transaction) -> dict[str, int]:
        """Estimate execution units for transaction."""
        try:
            if isinstance(self.chain_query.context, BlockFrostChainContext):
                return self.chain_query.context.evaluate_tx_cbor(tx.to_cbor())
            return await self.chain_query.context.evaluate_tx_cbor(tx.to_cbor())

        except Exception as e:
            raise TransactionBuildError(
                f"Failed to estimate execution units: {e}"
            ) from e

    def calculate_validity_window(
        self, time_absolute_uncertainty: int
    ) -> ValidityWindow:
        """Calculate transaction validity window and current time."""
        current_time = self.chain_query.get_current_posix_chain_time_ms()
        validity_start = current_time - (time_absolute_uncertainty // 2)
        validity_end = current_time + (time_absolute_uncertainty // 2)
        return ValidityWindow(validity_start, validity_end, current_time)

"""Reference script finding and validation utilities."""

import logging

from pycardano import (
    Address,
    Network,
    PlutusV3Script,
    TransactionId,
    TransactionInput,
    UTxO,
    plutus_script_hash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.contracts.aiken_loader import OracleContracts
from charli3_offchain_core.oracle.exceptions import ValidationError

logger = logging.getLogger(__name__)


class ReferenceScriptFinder:
    """Utility for finding and validating oracle reference scripts"""

    def __init__(
        self,
        chain_query: ChainQuery,
        contracts: OracleContracts,
        ref_script_config: ReferenceScriptConfig,
    ) -> None:
        self.chain_query = chain_query
        self.contracts = contracts
        self.ref_script_config = ref_script_config

        if ref_script_config.utxo_reference:
            self.utxo_reference = TransactionInput(
                transaction_id=TransactionId(
                    bytes.fromhex(ref_script_config.utxo_reference.transaction_id)
                ),
                index=ref_script_config.utxo_reference.output_index,
            )

        script_address = (
            self.contracts.spend.mainnet_addr
            if self.chain_query.context.network == Network.MAINNET
            else self.contracts.spend.testnet_addr
        )
        self.reference_script_address = (
            Address.from_primitive(ref_script_config.address)
            if ref_script_config.address
            else script_address
        )

    async def find_manager_reference(
        self,
    ) -> UTxO | None:
        """
        Find existing oracle manager reference script with matching configuration.

        Returns:
            UTxO containing matching reference script if found, None otherwise
        """
        try:
            # Get script hash
            script_hash = self.contracts.spend.script_hash

            if self.ref_script_config.utxo_reference:
                utxo = self.chain_query.get_utxo_by_ref_kupo(self.utxo_reference)
                if utxo is None:
                    raise ValidationError(
                        f"No matching utxo found {self.ref_script_config.utxo_reference}"
                    )
                if utxo.output.script is None:
                    raise ValidationError(
                        f"No utxos with script by reference {self.ref_script_config.utxo_reference}"
                    )
                if await self._validate_script(utxo.output.script, script_hash):
                    return utxo
                raise ValidationError(
                    f"Not matching script hash {script_hash} for utxo reference {self.ref_script_config.utxo_reference}"
                )

            # Get UTxOs at script address
            utxos = await self.chain_query.get_utxos(self.reference_script_address)
            reference_utxos = [utxo for utxo in utxos if utxo.output.script]

            if not reference_utxos:
                return None

            for utxo in reference_utxos:
                if await self._validate_script(utxo.output.script, script_hash):
                    logger.info("Found matching manager reference script")
                    return utxo

            return None

        except Exception as e:  # pylint: disable=broad-except
            logger.error("Error finding manager reference script: %s", e)
            return None

    async def _validate_script(
        self,
        script: PlutusV3Script,
        target_hash: bytes,
    ) -> bool:
        """
        Validate if a script matches the target script hash.

        Args:
            script: Script to validate
            target_hash: Expected script hash

        Returns:
            True if script matches target
        """
        try:
            return plutus_script_hash(script) == target_hash
        except Exception as e:  # pylint: disable=broad-except
            logger.error("Error validating script: %s", e)
            return False

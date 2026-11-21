"""Reference script transaction builders for oracle deployment."""

import logging
from dataclasses import dataclass

from pycardano import (
    Address,
    ExtendedSigningKey,
    PaymentSigningKey,
    Transaction,
    UTxO,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.contracts.aiken_loader import OracleContracts
from charli3_offchain_core.oracle.config import OracleScriptConfig
from charli3_offchain_core.oracle.deployment.reference_script_finder import (
    ReferenceScriptFinder,
)

logger = logging.getLogger(__name__)


@dataclass
class ReferenceScriptResult:
    """Result of reference script operation"""

    manager_utxo: UTxO | None
    manager_tx: Transaction | None


class ReferenceScriptBuilder:
    """Builds reference script transactions for oracle deployment"""

    def __init__(
        self,
        chain_query: ChainQuery,
        contracts: OracleContracts,
        ref_script_config: ReferenceScriptConfig,
        tx_manager: TransactionManager,
    ) -> None:
        self.chain_query = chain_query
        self.contracts = contracts
        self.tx_manager = tx_manager
        self.ref_script_config = ref_script_config
        self.script_finder = ReferenceScriptFinder(
            chain_query, contracts, ref_script_config
        )

    async def prepare_reference_script(
        self,
        script_config: OracleScriptConfig,
        admin_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
    ) -> ReferenceScriptResult:
        """
        Prepare reference script for oracle deployment.

        Args:
            script_config: Reference script configuration
            script_address: Address of oracle script
            admin_address: Address of oracle admin
            signing_key: Signing key for transactions

        Returns:
            ReferenceScriptResult with UTxO and transaction
        """
        result = ReferenceScriptResult(None, None)

        if not script_config.create_manager_reference:
            return result

        result.manager_utxo = await self.script_finder.find_manager_reference()
        if result.manager_utxo:
            return result

        logger.info("Creating new manager reference script")

        result.manager_tx = await self.tx_manager.build_reference_script_tx(
            script=self.contracts.spend.contract,
            reference_script_address=self.script_finder.reference_script_address,
            admin_address=admin_address,
            signing_key=signing_key,
            reference_ada=script_config.reference_ada_amount,
        )

        return result

    async def submit_reference_script(
        self,
        result: ReferenceScriptResult,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
    ) -> None:
        """Submit prepared reference script transaction"""
        if result.manager_tx:
            logger.info("Submitting manager reference script transaction")
            await self.tx_manager.sign_and_submit(
                result.manager_tx,
                [signing_key],
            )

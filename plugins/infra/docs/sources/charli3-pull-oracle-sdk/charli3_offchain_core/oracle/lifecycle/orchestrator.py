"""Oracle lifecycle orchestrator with proper datum handling."""

import logging
from collections.abc import Callable
from dataclasses import dataclass

from pycardano import (
    Address,
    ExtendedSigningKey,
    NativeScript,
    PaymentSigningKey,
    ScriptHash,
    Transaction,
    UTxO,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.constants.status import ProcessStatus

from ..utils.common import get_script_utxos
from .pause_builder import PauseBuilder
from .remove_builder import RemoveBuilder
from .resume_builder import ResumeBuilder

logger = logging.getLogger(__name__)


@dataclass
class LifecycleResult:
    """Result of lifecycle operation"""

    status: ProcessStatus
    transaction: Transaction | None = None
    error: Exception | None = None


class LifecycleOrchestrator:
    """Orchestrates oracle lifecycle operations with proper datum handling"""

    def __init__(
        self,
        chain_query: ChainQuery,
        tx_manager: TransactionManager,
        script_address: Address,
        ref_script_config: ReferenceScriptConfig,
        status_callback: Callable | None = None,
    ) -> None:
        self.chain_query = chain_query
        self.tx_manager = tx_manager
        self.script_address = script_address
        self.ref_script_config = ref_script_config
        self.status_callback = status_callback
        self.current_status = ProcessStatus.NOT_STARTED

    def _update_status(self, status: ProcessStatus, message: str = "") -> None:
        self.current_status = status
        if self.status_callback:
            self.status_callback(status, message)

    async def pause_oracle(
        self,
        oracle_policy: str,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
    ) -> LifecycleResult:
        try:
            utxos = await get_script_utxos(self.script_address, self.tx_manager)
            policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            builder = PauseBuilder(self.chain_query, self.tx_manager)
            result = await builder.build_tx(
                platform_utxo=platform_utxo,
                platform_script=platform_script,
                policy_hash=policy_hash,
                utxos=utxos,
                change_address=change_address,
                signing_key=signing_key,
                script_address=self.script_address,
                ref_script_config=self.ref_script_config,
            )

            return LifecycleResult(
                status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
            )

        except Exception as e:
            logger.error("Pause oracle failed: %s", str(e))
            return LifecycleResult(status=ProcessStatus.FAILED, error=e)

    async def resume_oracle(
        self,
        oracle_policy: str,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
    ) -> LifecycleResult:
        """Resume a paused oracle.

        Args:
            oracle_policy: Oracle policy ID
            platform_utxo: Platform NFT UTxO
            platform_script: Platform authorization script
            change_address: Change address
            signing_key: Signing key

        Returns:
            LifecycleResult containing transaction status and details
        """
        try:

            utxos = await get_script_utxos(self.script_address, self.tx_manager)
            policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            self._update_status(
                ProcessStatus.BUILDING_TRANSACTION, "Building resume transaction"
            )
            builder = ResumeBuilder(self.chain_query, self.tx_manager)
            result = await builder.build_tx(
                platform_utxo=platform_utxo,
                platform_script=platform_script,
                policy_hash=policy_hash,
                utxos=utxos,
                script_address=self.script_address,
                ref_script_config=self.ref_script_config,
                change_address=change_address,
                signing_key=signing_key,
            )

            self._update_status(
                ProcessStatus.TRANSACTION_BUILT, "Resume transaction built"
            )
            return LifecycleResult(
                status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
            )

        except Exception as e:
            logger.error("Resume oracle failed: %s", str(e))
            self._update_status(ProcessStatus.FAILED, f"Resume failed: {e!s}")
            return LifecycleResult(status=ProcessStatus.FAILED, error=e)

    async def remove_oracle(
        self,
        oracle_policy: str,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        pause_period: int,
    ) -> LifecycleResult:
        """Remove an oracle permanently and burn all NFTs.

        Args:
            oracle_policy: Oracle policy ID
            platform_utxo: Platform NFT UTxO
            platform_script: Platform authorization script
            change_address: Change address
            signing_key: Signing key
            pair_count: Optional number of AggregationState + RewardTransport token pairs to burn

        Returns:
            LifecycleResult containing transaction status and details
        """
        try:
            utxos = await get_script_utxos(self.script_address, self.tx_manager)
            policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            self._update_status(
                ProcessStatus.BUILDING_TRANSACTION, "Building remove oracle transaction"
            )
            builder = RemoveBuilder(self.chain_query, self.tx_manager)
            result = await builder.build_tx(
                platform_utxo=platform_utxo,
                platform_script=platform_script,
                policy_hash=policy_hash,
                utxos=utxos,
                script_address=self.script_address,
                ref_script_config=self.ref_script_config,
                change_address=change_address,
                signing_key=signing_key,
                pause_period=pause_period,
            )

            self._update_status(
                ProcessStatus.TRANSACTION_BUILT, "Remove oracle transaction built"
            )
            return LifecycleResult(
                status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
            )

        except Exception as e:
            logger.error("Remove oracle failed: %s", str(e))
            self._update_status(ProcessStatus.FAILED, f"Remove failed: {e!s}")
            return LifecycleResult(status=ProcessStatus.FAILED, error=e)

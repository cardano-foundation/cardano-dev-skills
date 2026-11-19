"""Oracle governance orchestrator"""

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
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.config.nodes import NodesConfig
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.cli.config.token import TokenConfig
from charli3_offchain_core.cli.setup import setup_token
from charli3_offchain_core.constants.status import ProcessStatus
from charli3_offchain_core.models.oracle_datums import OracleConfiguration
from charli3_offchain_core.oracle.exceptions import (
    AddingNodesError,
    AddNodesValidationError,
    RemoveNodesValidationError,
    RemovingNodesError,
    ScalingError,
    StateValidationError,
)
from charli3_offchain_core.oracle.governance.add_nodes_builder import AddNodesBuilder
from charli3_offchain_core.oracle.governance.del_nodes_builder import DelNodesBuilder
from charli3_offchain_core.oracle.governance.scale_builder import OracleScaleBuilder
from charli3_offchain_core.oracle.governance.update_builder import UpdateBuilder
from charli3_offchain_core.oracle.utils.common import get_script_utxos

logger = logging.getLogger(__name__)


@dataclass
class GovernanceResult:
    """Result of governance operation"""

    status: ProcessStatus
    transaction: Transaction | None = None
    error: Exception | None = None


class GovernanceOrchestrator:
    """Orchestrator for oracle governance operations"""

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

    async def add_nodes_oracle(
        self,
        oracle_policy: str,
        new_nodes_config: NodesConfig,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        required_signers: list[VerificationKeyHash] | None = None,
        test_mode: bool = False,
    ) -> GovernanceResult:
        try:
            utxos = await get_script_utxos(self.script_address, self.tx_manager)
            policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            builder = AddNodesBuilder(self.chain_query, self.tx_manager)

            try:
                result = await builder.build_tx(
                    platform_utxo=platform_utxo,
                    platform_script=platform_script,
                    policy_hash=policy_hash,
                    script_address=self.script_address,
                    ref_script_config=self.ref_script_config,
                    utxos=utxos,
                    change_address=change_address,
                    signing_key=signing_key,
                    new_nodes_config=new_nodes_config,
                    required_signers=required_signers,
                    test_mode=test_mode,
                )
            except (AddingNodesError, AddNodesValidationError):
                return GovernanceResult(status=ProcessStatus.FAILED)

            if result.reason:
                return GovernanceResult(ProcessStatus.VERIFICATION_FAILURE)

            if result.transaction is None and result.settings_utxo is None:
                return GovernanceResult(ProcessStatus.CANCELLED_BY_USER)

            return GovernanceResult(
                status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
            )

        except Exception as e:
            logger.error("Update oracle failed: %s", str(e))
            return GovernanceResult(status=ProcessStatus.FAILED, error=e)

    async def del_nodes_oracle(
        self,
        oracle_policy: str,
        new_nodes_config: NodesConfig,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        tokens: TokenConfig,
        required_signers: list[VerificationKeyHash] | None = None,
        test_mode: bool = False,
    ) -> GovernanceResult:
        """
        Delete oracle nodes

        Args:
            oracle_policy: Policy ID for the oracle
            new_nodes_config: Configuration for the new node setup
            platform_utxo: Platform UTxO
            platform_script: Platform native script
            change_address: Address for change
            signing_key: Signing key for the transaction
            tokens: Token configuration
            required_signers: Optional list of required signers

        Returns:
            GovernanceResult containing transaction status and details
        """
        try:

            oracle_policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            contract_utxos = await get_script_utxos(
                self.script_address, self.tx_manager
            )

            reward_token = setup_token(
                tokens.reward_token_policy, tokens.reward_token_name
            )

            builder = DelNodesBuilder(self.chain_query, self.tx_manager)
            try:
                result = await builder.build_tx(
                    platform_utxo=platform_utxo,
                    platform_script=platform_script,
                    policy_hash=oracle_policy_hash,
                    contract_utxos=contract_utxos,
                    script_address=self.script_address,
                    ref_script_config=self.ref_script_config,
                    change_address=change_address,
                    signing_key=signing_key,
                    new_nodes_config=new_nodes_config,
                    reward_token=reward_token,
                    required_signers=required_signers,
                    test_mode=test_mode,
                )

                if result.reason:
                    logger.warning(f"Verification failed: {result.reason}")
                    return GovernanceResult(status=ProcessStatus.VERIFICATION_FAILURE)

                if result.transaction is None and result.settings_utxo is None:
                    logger.info("Transaction cancelled by user")
                    return GovernanceResult(ProcessStatus.CANCELLED_BY_USER)

                return GovernanceResult(
                    status=ProcessStatus.TRANSACTION_BUILT,
                    transaction=result.transaction,
                )
            except (RemovingNodesError, RemoveNodesValidationError) as e:
                logger.error(f"Node removal error: {e}")
                return GovernanceResult(status=ProcessStatus.FAILED, error=e)

        except Exception as e:
            logger.error("Update oracle failed: %s", str(e))
            return GovernanceResult(status=ProcessStatus.FAILED, error=e)

    async def update_oracle(
        self,
        oracle_policy: str,
        oracle_config: OracleConfiguration,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> GovernanceResult:
        """Update oracle settings"""
        try:
            utxos = await get_script_utxos(self.script_address, self.tx_manager)
            policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            builder = UpdateBuilder(self.chain_query, self.tx_manager)

            result = await builder.build_tx(
                oracle_config=oracle_config,
                platform_utxo=platform_utxo,
                platform_script=platform_script,
                script_address=self.script_address,
                ref_script_config=self.ref_script_config,
                policy_hash=policy_hash,
                utxos=utxos,
                change_address=change_address,
                signing_key=signing_key,
                required_signers=required_signers,
            )
            if result.transaction is None and result.settings_utxo is None:
                return GovernanceResult(ProcessStatus.CANCELLED_BY_USER)

            return GovernanceResult(
                status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
            )

        except Exception as e:
            logger.error("Update oracle failed: %s", str(e))
            return GovernanceResult(status=ProcessStatus.FAILED, error=e)

    async def scale_up_oracle(
        self,
        oracle_policy: str,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        reward_account_count: int = 0,
        aggstate_count: int = 0,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> GovernanceResult:
        """Scale up oracle ODV capacity.

        Args:
            oracle_policy: Oracle policy ID
            platform_utxo: Platform authentication UTxO
            platform_script: Platform script
            change_address: Address for change
            signing_key: Signing key
            reward_account_count: Number of RewardAccount UTxOs to create (default 0)
            aggstate_count: Number of AggState UTxOs to create (default 0)
            required_signers: Optional required signers

        Returns:
            GovernanceResult with transaction status
        """
        try:
            utxos = await get_script_utxos(self.script_address, self.tx_manager)
            policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            builder = OracleScaleBuilder(
                tx_manager=self.tx_manager,
                script_address=self.script_address,
                policy_id=policy_hash,
                ref_script_config=self.ref_script_config,
            )

            try:
                result = await builder.build_scale_up_tx(
                    platform_utxo=platform_utxo,
                    platform_script=platform_script,
                    utxos=utxos,
                    change_address=change_address,
                    signing_key=signing_key,
                    reward_account_count=reward_account_count,
                    aggstate_count=aggstate_count,
                    required_signers=required_signers,
                )
            except (ScalingError, StateValidationError) as e:
                logger.info("Scaling error %s", str(e))
                return GovernanceResult(status=ProcessStatus.FAILED)

            if result.transaction is None:
                return GovernanceResult(ProcessStatus.CANCELLED_BY_USER)

            return GovernanceResult(
                status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
            )

        except Exception as e:
            logger.error("Scale up oracle failed: %s", str(e))
            return GovernanceResult(status=ProcessStatus.FAILED, error=e)

    async def scale_down_oracle(
        self,
        oracle_policy: str,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        reward_account_count: int = 0,
        aggstate_count: int = 0,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> GovernanceResult:
        """Scale down oracle ODV capacity.

        Args:
            oracle_policy: Oracle policy ID
            platform_utxo: Platform authentication UTxO
            platform_script: Platform script
            change_address: Address for change
            signing_key: Signing key
            reward_account_count: Number of empty RewardAccount UTxOs to remove (default 0)
            aggstate_count: Number of empty/expired AggState UTxOs to remove (default 0)
            required_signers: Optional required signers

        Returns:
            GovernanceResult with transaction status
        """
        try:
            logger.info(
                "Starting scale down operation for %d RewardAccount(s) and %d AggState(s)",
                reward_account_count,
                aggstate_count,
            )

            utxos = await get_script_utxos(self.script_address, self.tx_manager)
            logger.info("Found %d total UTxOs at script address", len(utxos))

            policy_hash = ScriptHash(bytes.fromhex(oracle_policy))

            builder = OracleScaleBuilder(
                tx_manager=self.tx_manager,
                script_address=self.script_address,
                ref_script_config=self.ref_script_config,
                policy_id=policy_hash,
            )

            try:
                result = await builder.build_scale_down_tx(
                    platform_utxo=platform_utxo,
                    platform_script=platform_script,
                    utxos=utxos,
                    change_address=change_address,
                    signing_key=signing_key,
                    reward_account_count=reward_account_count,
                    aggstate_count=aggstate_count,
                    required_signers=required_signers,
                )
                logger.info(
                    "Successfully built scale down transaction. "
                    "Removed %d RewardAccount UTxOs and %d AggState UTxOs",
                    len(result.removed_reward_account_utxos),
                    len(result.removed_agg_state_utxos),
                )

            except (ScalingError, StateValidationError) as e:
                logger.error("Scale down validation failed: %s", str(e))
                return GovernanceResult(status=ProcessStatus.FAILED)

            if result.transaction is None:
                return GovernanceResult(ProcessStatus.CANCELLED_BY_USER)

            return GovernanceResult(
                status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
            )

        except Exception as e:
            logger.error("Scale down oracle failed: %s", str(e))
            return GovernanceResult(status=ProcessStatus.FAILED, error=e)

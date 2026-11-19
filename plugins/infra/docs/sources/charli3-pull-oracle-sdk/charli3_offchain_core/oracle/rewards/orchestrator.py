"""Oracle reward orchestrator"""

import logging
from collections.abc import Callable
from dataclasses import dataclass

from pycardano import (
    Address,
    NativeScript,
    Network,
    PaymentSigningKey,
    ScriptHash,
    Transaction,
    UTxO,
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.exceptions import CollateralError
from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.base import LoadedKeys
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.cli.config.token import TokenConfig
from charli3_offchain_core.cli.setup import setup_token
from charli3_offchain_core.constants.status import ProcessStatus
from charli3_offchain_core.oracle.exceptions import (
    ADABalanceNotFoundError,
    CollectingNodesError,
    CollectingPlatformError,
    DismissRewardCancelledError,
    NodeCollectCancelled,
    NodeNotRegisteredError,
    NoExpiredTransportsYetError,
    NoPendingTransportsFoundError,
    NoRewardsAvailableError,
    PlatformCollectCancelled,
    RewardsError,
)
from charli3_offchain_core.oracle.rewards.dismiss_rewards_builder import (
    DismissRewardsBuilder,
)
from charli3_offchain_core.oracle.rewards.node_collect_builder import (
    NodeCollectBuilder,
)
from charli3_offchain_core.oracle.rewards.platform_collect_builder import (
    PlatformCollectBuilder,
)

# from charli3_offchain_core.oracle.rewards.platform_collect_builder import PlatformCollectBuilder
from charli3_offchain_core.oracle.utils.common import get_script_utxos

logger = logging.getLogger(__name__)


@dataclass
class RewardOrchestratorResult:
    """Result of reward operation"""

    status: ProcessStatus
    transaction: Transaction | None = None
    error: RewardsError | CollateralError | None = None


class RewardOrchestrator:
    def __init__(
        self,
        chain_query: ChainQuery,
        tx_manager: TransactionManager,
        script_address: Address | str,
        ref_script_config: ReferenceScriptConfig,
        status_callback: Callable | None = None,
    ) -> None:
        self.chain_query = chain_query
        self.tx_manager = tx_manager
        self.ref_script_config = ref_script_config
        self.script_address = (
            Address.from_primitive(script_address)
            if isinstance(script_address, str)
            else script_address
        )
        self.status_callback = status_callback
        self.current_status = ProcessStatus.NOT_STARTED

    def _update_status(self, status: ProcessStatus, message: str = "") -> None:
        self.current_status = status
        if self.status_callback:
            self.status_callback(status, message)

    async def collect_node_oracle(
        self,
        oracle_policy: str | None,
        tokens: TokenConfig,
        loaded_key: LoadedKeys,
        network: Network,
        max_inputs: int = 10,
        payment_key: tuple[PaymentSigningKey, Address] | None = None,
    ) -> RewardOrchestratorResult:
        if not oracle_policy:
            raise ValueError("oracle_policy cannot be None or empty")

        # Contract UTxOs
        contract_utxos = await get_script_utxos(self.script_address, self.tx_manager)

        oracle_policy_hash = ScriptHash(bytes.fromhex(oracle_policy))
        reward_token = setup_token(tokens.reward_token_policy, tokens.reward_token_name)

        # Derive feed_vkh from loaded_key
        feed_vkh = loaded_key.payment_vk.hash()

        # We only add feed_vkh to required_signers.
        # The payment key signs the transaction to authorize spending fees/collateral,
        # but it should NOT be listed in required_signers (tx_signatories on-chain).
        # The on-chain script expects the FIRST signer to be the node. Since required_signers
        # are sorted lexicographically on-chain, adding the payment key here risks it
        # appearing 'before' the feed key, causing the script to check the wrong key against rewards.
        required_signers = [feed_vkh]

        builder = NodeCollectBuilder(self.chain_query, self.tx_manager)

        result = await builder.build_tx(
            policy_hash=oracle_policy_hash,
            contract_utxos=contract_utxos,
            reward_token=reward_token,
            loaded_key=loaded_key,
            script_address=self.script_address,
            ref_script_config=self.ref_script_config,
            network=network,
            max_inputs=max_inputs,
            required_signers=required_signers,
            payment_key=payment_key,
        )

        if isinstance(result.exception_type, NodeNotRegisteredError):
            return RewardOrchestratorResult(
                status=ProcessStatus.VERIFICATION_FAILURE,
                error=result.exception_type,
            )

        if isinstance(result.exception_type, NoRewardsAvailableError):
            return RewardOrchestratorResult(
                status=ProcessStatus.COMPLETED, error=result.exception_type
            )

        if isinstance(result.exception_type, NodeCollectCancelled):
            return RewardOrchestratorResult(
                status=ProcessStatus.CANCELLED_BY_USER, error=result.exception_type
            )

        if isinstance(result.exception_type, ADABalanceNotFoundError | CollateralError):
            return RewardOrchestratorResult(
                status=ProcessStatus.FAILED, error=result.exception_type
            )

        if isinstance(result.exception_type, CollectingNodesError):
            return RewardOrchestratorResult(
                status=ProcessStatus.FAILED, error=result.exception_type
            )

        return RewardOrchestratorResult(
            status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
        )

    async def collect_platform_oracle(
        self,
        oracle_policy: str | None,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        tokens: TokenConfig,
        loaded_key: LoadedKeys,
        network: Network,
        max_inputs: int = 10,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> RewardOrchestratorResult:
        if not oracle_policy:
            raise ValueError("oracle_policy cannot be None or empty")

        # Contract UTxOs
        contract_utxos = await get_script_utxos(self.script_address, self.tx_manager)

        oracle_policy_hash = ScriptHash(bytes.fromhex(oracle_policy))
        reward_token = setup_token(tokens.reward_token_policy, tokens.reward_token_name)

        builder = PlatformCollectBuilder(self.chain_query, self.tx_manager)

        result = await builder.build_tx(
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            policy_hash=oracle_policy_hash,
            contract_utxos=contract_utxos,
            reward_token=reward_token,
            loaded_key=loaded_key,
            script_address=self.script_address,
            ref_script_config=self.ref_script_config,
            network=network,
            max_inputs=max_inputs,
            required_signers=required_signers,
        )

        if isinstance(result.exception_type, CollectingPlatformError):
            return RewardOrchestratorResult(
                status=ProcessStatus.FAILED, error=result.exception_type
            )

        if isinstance(result.exception_type, NoRewardsAvailableError):
            return RewardOrchestratorResult(
                status=ProcessStatus.COMPLETED, error=result.exception_type
            )

        if isinstance(result.exception_type, PlatformCollectCancelled):
            return RewardOrchestratorResult(
                status=ProcessStatus.CANCELLED_BY_USER, error=result.exception_type
            )

        if isinstance(result.exception_type, CollateralError):
            return RewardOrchestratorResult(
                status=ProcessStatus.FAILED, error=result.exception_type
            )
        return RewardOrchestratorResult(
            status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
        )

    async def dismiss_rewards(
        self,
        oracle_policy: str | None,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        tokens: TokenConfig,
        loaded_key: LoadedKeys,
        network: Network,
        reward_dismission_period_length: int,
        max_inputs: int = 10,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> RewardOrchestratorResult:

        if not oracle_policy:
            raise ValueError("oracle_policy cannot be None or empty")

        # Contract UTxOs
        contract_utxos = await get_script_utxos(self.script_address, self.tx_manager)

        oracle_policy_hash = ScriptHash(bytes.fromhex(oracle_policy))
        reward_token = setup_token(tokens.reward_token_policy, tokens.reward_token_name)

        builder = DismissRewardsBuilder(self.chain_query, self.tx_manager)

        result = await builder.build_tx(
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            policy_hash=oracle_policy_hash,
            contract_utxos=contract_utxos,
            reward_token=reward_token,
            loaded_key=loaded_key,
            network=network,
            script_address=self.script_address,
            ref_script_config=self.ref_script_config,
            reward_dismission_period_length=reward_dismission_period_length,
            max_inputs=max_inputs,
            required_signers=required_signers,
        )

        if isinstance(result.exception_type, NoExpiredTransportsYetError):
            return RewardOrchestratorResult(
                status=ProcessStatus.COMPLETED, error=result.exception_type
            )

        if isinstance(result.exception_type, NoPendingTransportsFoundError):
            return RewardOrchestratorResult(
                status=ProcessStatus.COMPLETED, error=result.exception_type
            )

        if isinstance(result.exception_type, DismissRewardCancelledError):
            return RewardOrchestratorResult(
                status=ProcessStatus.CANCELLED_BY_USER, error=result.exception_type
            )

        if isinstance(result.exception_type, NoRewardsAvailableError):
            return RewardOrchestratorResult(
                status=ProcessStatus.COMPLETED, error=result.exception_type
            )

        return RewardOrchestratorResult(
            status=ProcessStatus.TRANSACTION_BUILT, transaction=result.transaction
        )

"""Base classes for oracle rewards operations."""

from dataclasses import dataclass

from pycardano import Transaction, TransactionOutput

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.exceptions import CollateralError
from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.oracle.exceptions import RewardsError


@dataclass
class RewardTxResult:
    """Result of reward transaction build"""

    transaction: Transaction | None = None
    reward_utxo: TransactionOutput | None = None
    reason: str | None = None
    exception_type: RewardsError | CollateralError | None = None


class BaseBuilder:
    """Base builder for reward transactions"""

    MIN_UTXO_VALUE = 2_000_000

    def __init__(self, chain_query: ChainQuery, tx_manager: TransactionManager) -> None:
        self.chain_query = chain_query
        self.tx_manager = tx_manager

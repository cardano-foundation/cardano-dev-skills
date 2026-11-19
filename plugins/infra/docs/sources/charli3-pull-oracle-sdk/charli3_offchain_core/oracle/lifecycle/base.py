"""Base classes for oracle lifecycle operations."""

from dataclasses import dataclass

from pycardano import Transaction, TransactionOutput

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.transactions import TransactionManager


@dataclass
class LifecycleTxResult:
    """Result of lifecycle transaction build"""

    transaction: Transaction
    settings_utxo: TransactionOutput | None = None


class BaseBuilder:
    """Base builder for lifecycle transactions"""

    MIN_UTXO_VALUE = 2_000_000

    def __init__(self, chain_query: ChainQuery, tx_manager: TransactionManager) -> None:
        self.chain_query = chain_query
        self.tx_manager = tx_manager

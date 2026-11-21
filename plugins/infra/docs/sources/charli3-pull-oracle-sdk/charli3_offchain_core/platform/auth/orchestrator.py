"""Orchestrates the platform authorization NFT creation process."""

import logging
from collections.abc import Callable
from dataclasses import dataclass

from pycardano import (
    Address,
    PaymentSigningKey,
    Transaction,
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.transactions import TransactionManager

from ...constants.status import ProcessStatus
from .token_builder import PlatformAuthBuilder
from .token_script_builder import PlatformAuthScript, ScriptConfig

logger = logging.getLogger(__name__)


@dataclass
class AuthResult:
    """Result of platform authorization process"""

    status: ProcessStatus
    transaction: Transaction | None = None
    policy_id: bytes | None = None
    platform_address: Address | None = None
    error: Exception | None = None


class PlatformAuthOrchestrator:
    """Coordinates the platform authorization NFT creation process."""

    def __init__(
        self,
        chain_query: ChainQuery,
        tx_manager: TransactionManager,
        status_callback: Callable[[ProcessStatus, str], None] | None = None,
    ) -> None:
        self.chain_query = chain_query
        self.tx_manager = tx_manager
        self.status_callback = status_callback
        self.current_status = ProcessStatus.NOT_STARTED

    def _update_status(self, status: ProcessStatus, message: str = "") -> None:
        """Update process status and notify callback."""
        self.current_status = status
        if self.status_callback:
            self.status_callback(status, message)

    async def build_tx(
        self,
        sender_address: Address,
        signing_key: PaymentSigningKey,
        multisig_threshold: int,
        multisig_parties: list[str],
        metadata: dict | None = None,
        network: str | None = None,
        is_mock: bool = False,
    ) -> AuthResult:
        """Build platform authorization NFT transaction."""
        try:
            script_config = ScriptConfig(
                signers=[
                    VerificationKeyHash.from_primitive(pkh) for pkh in multisig_parties
                ],
                threshold=multisig_threshold,
                network=network,
            )

            self._update_status(ProcessStatus.CREATING_SCRIPT)
            script_builder = PlatformAuthScript(
                chain_query=self.chain_query, config=script_config, is_mock=is_mock
            )

            self._update_status(
                ProcessStatus.BUILDING_TRANSACTION, "Builidng minting transaction..."
            )
            token_builder = PlatformAuthBuilder(
                self.chain_query, self.tx_manager, script_builder
            )

            result = await token_builder.build_auth_tx(
                sender_address=sender_address,
                signing_key=signing_key,
                metadata=metadata,
            )
            self._update_status(
                ProcessStatus.TRANSACTION_BUILT,
                "platform auth mint transaction was built",
            )
            return AuthResult(
                status=ProcessStatus.TRANSACTION_BUILT,
                transaction=result.transaction,
                policy_id=result.policy_id,
                platform_address=result.platform_address,
            )

        except Exception as e:
            logger.error("Platform auth transaction creation failed: %s", str(e))
            self._update_status(ProcessStatus.FAILED, str(e))
            return AuthResult(status=ProcessStatus.FAILED, error=e)

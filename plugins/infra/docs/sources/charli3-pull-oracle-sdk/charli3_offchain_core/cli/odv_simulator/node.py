"""Node simulator implementation."""

import hashlib
import logging
import secrets
import time

from pycardano import (
    Transaction,
    TransactionBody,
    TransactionWitnessSet,
)

from charli3_offchain_core.models.client import OdvFeedRequest, OdvTxSignatureRequest
from charli3_offchain_core.models.message import (
    OracleNodeMessage,
    SignedOracleNodeMessage,
)

from .models import SimulatedNode

logger = logging.getLogger(__name__)


class NodeSimulator:
    """Simulates a single ODV node's behavior."""

    def __init__(self, node: SimulatedNode, base_feed: int, variance: float) -> None:
        """Initialize node simulator.

        Args:
            node: Simulated node instance with keys
            base_feed: Base feed value
            variance: Maximum variance percentage (0-1)
        """
        self.node = node
        self.base_feed = base_feed
        self.variance = variance

    def _generate_feed(self) -> int:
        """Generate feed value with random variance."""
        variance_amount = self.base_feed * (
            (secrets.randbelow(10000) / 10000.0) * self.variance
        )
        return self.base_feed + int(variance_amount)

    async def handle_feed_request(
        self, request: OdvFeedRequest
    ) -> tuple[str, SignedOracleNodeMessage | None]:
        """Handle ODV feed request."""
        try:
            # Generate feed with variance
            feed_value = self._generate_feed()
            timestamp = int(time.time() * 1000)

            # Create and sign message
            message = OracleNodeMessage(
                feed=feed_value,
                timestamp=timestamp,
                oracle_nft_policy_id=bytes.fromhex(request.oracle_nft_policy_id),
            )

            signature = message.sign(self.node.signing_key)

            logger.info(f"Node {self.node.hex_feed_vkh} generated Feed: {feed_value}")

            signed_message = SignedOracleNodeMessage(
                message=message,
                signature=signature,
                verification_key=self.node.verification_key,
            )

            return self.node.feed_vkh.to_primitive().hex(), signed_message

        except Exception as e:
            logger.error(
                f"Feed request failed for node {self.node.hex_feed_vkh}: {e!s}"
            )
            return self.node.hex_feed_vkh, None

    async def handle_sign_request(self, request: OdvTxSignatureRequest) -> str | None:
        try:
            witness_vkh = self.node.verification_key.hash()
            file_vkh = self.node.feed_vkh

            logger.info(f"Node {self.node.hex_feed_vkh[:8]}:")
            logger.info(f"  VKH from witness vkey: {witness_vkh.to_primitive().hex()}")
            logger.info(f"  VKH from file:         {file_vkh.to_primitive().hex()}")
            logger.info(f"  Match: {witness_vkh.payload == file_vkh.payload}")

            tx_body_cbor_bytes = bytes.fromhex(request.tx_body_cbor)
            tx_body_hash_bytes = hashlib.blake2b(
                tx_body_cbor_bytes, digest_size=32
            ).digest()
            tx_body_hash_hex = tx_body_hash_bytes.hex()

            logger.info(f"Computed transaction body hash: {tx_body_hash_hex}")

            # Deserialize transaction body for validation purposes only
            parsed_tx_body = TransactionBody.from_cbor(request.tx_body_cbor)

            validation_tx = Transaction(
                transaction_body=parsed_tx_body,
                transaction_witness_set=TransactionWitnessSet(),
            )

            if validation_tx.transaction_body.required_signers:
                logger.info("  Required signers in tx:")
                for rs in validation_tx.transaction_body.required_signers:
                    logger.info(f"    {rs.to_primitive().hex()}")

            signature = self.node.signing_key.sign(tx_body_hash_bytes)
            signature_hex = signature.hex()

            logger.info(
                f"Node {self.node.hex_feed_vkh[:8]} signed tx body hash: {tx_body_hash_bytes.hex()[:16]}..."
            )
            return signature_hex

        except Exception as e:
            logger.error(f"Sign request failed: {e!s}")
            return None

    @property
    def vkh(self) -> str:
        """Get node's verification key hash."""
        return self.node.hex_feed_vkh

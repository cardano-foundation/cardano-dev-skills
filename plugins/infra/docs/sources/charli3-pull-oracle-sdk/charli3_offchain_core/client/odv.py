"""Client for ODV node interactions."""

import asyncio
import logging

import aiohttp
from pycardano import Transaction, TransactionWitnessSet, VerificationKeyWitness

from charli3_offchain_core.cli.config.odv_client import NodeConfig
from charli3_offchain_core.models.client import OdvFeedRequest, OdvTxSignatureRequest
from charli3_offchain_core.models.message import SignedOracleNodeMessage

logger = logging.getLogger(__name__)


class ODVClient:
    """Client for ODV node interactions."""

    async def collect_feed_updates(
        self,
        nodes: list[NodeConfig],
        feed_request: OdvFeedRequest,
    ) -> dict[str, SignedOracleNodeMessage]:
        """
        Collect feed updates from nodes.

        :param nodes: List of nodes to interact with.
        :param feed_request: The feed request to send to the nodes.
        :return: A dictionary mapping node public keys to their responses.
        """

        async def fetch_from_node(
            session: aiohttp.ClientSession, node: NodeConfig
        ) -> tuple[str, SignedOracleNodeMessage | None]:
            try:
                endpoint = f"{node.root_url.rstrip('/')}/odv/feed"
                async with session.post(
                    endpoint, json=feed_request.model_dump()
                ) as response:
                    if response.status != 200:
                        logger.error(f"Error from {node.root_url}: {response.status}")
                        return node.pub_key, None

                    data = await response.json()
                    signed_message = SignedOracleNodeMessage.model_validate(data)
                    return node.pub_key, signed_message

            except Exception as e:
                logger.error(f"Failed to fetch from {node.root_url}: {e!s}")
                return node.pub_key, None

        async with aiohttp.ClientSession() as session:
            tasks = [fetch_from_node(session, node) for node in nodes]
            responses = await asyncio.gather(*tasks)

            return {pkh: msg for pkh, msg in responses if msg is not None}

    async def collect_tx_signatures(
        self,
        nodes: list[NodeConfig],
        tx_request: OdvTxSignatureRequest,
    ) -> dict[str, str]:
        """
        Collect transaction signatures from nodes.

        :param nodes: List of nodes to interact with.
        :param tx_request: The transaction signature request with tx_body_cbor.
        :return: A dictionary mapping node public keys to their signature hex strings.
        """

        async def fetch_signature_from_node(
            session: aiohttp.ClientSession, node: NodeConfig
        ) -> tuple[str, str | None]:
            try:
                endpoint = f"{node.root_url.rstrip('/')}/odv/sign"

                payload = tx_request.model_dump()

                async with session.post(endpoint, json=payload) as response:
                    if response.status != 200:
                        logger.error(f"Error from {node.root_url}: {response.status}")
                        return node.pub_key, None

                    data = await response.json()
                    signature_hex = data["signature"]
                    logger.debug(
                        f"Received signature from {node.root_url}: {signature_hex[:20]}..."
                    )
                    return node.pub_key, signature_hex

            except aiohttp.ClientError as e:
                logger.error(f"Connection error to {node.root_url}: {e!s}")
                return node.pub_key, None
            except Exception as e:
                logger.error(f"Error processing {node.root_url}: {e!s}")
                return node.pub_key, None

        async with aiohttp.ClientSession() as session:
            tasks = [fetch_signature_from_node(session, node) for node in nodes]
            responses = await asyncio.gather(*tasks)

            return {
                node_pub_key: sig_hex
                for node_pub_key, sig_hex in responses
                if sig_hex is not None
            }

    def attach_signature_witnesses(
        self,
        original_tx: Transaction,
        signatures: dict[str, str],
        node_messages: dict[str, SignedOracleNodeMessage],
    ) -> Transaction:
        """
        Attach signature witnesses to the original transaction object.

        :param original_tx: Original transaction to attach witnesses to.
        :param signatures: Dictionary mapping node public keys to signature hex strings.
        :param node_messages: Dictionary of node messages containing verification keys.
        :return: Transaction with attached witnesses.
        """

        if original_tx.transaction_witness_set is None:
            original_tx.transaction_witness_set = TransactionWitnessSet()
        if original_tx.transaction_witness_set.vkey_witnesses is None:
            original_tx.transaction_witness_set.vkey_witnesses = []

        for node_pub_key, signature_hex in signatures.items():
            try:
                if node_pub_key not in node_messages:
                    logger.warning(f"No node message found for node {node_pub_key}")
                    continue

                node_message = node_messages[node_pub_key]
                verification_key = node_message.verification_key

                signature = bytes.fromhex(signature_hex)

                witness = VerificationKeyWitness(
                    vkey=verification_key, signature=signature
                )
                original_tx.transaction_witness_set.vkey_witnesses.append(witness)
                logger.debug(f"Created witness for node {node_pub_key}")

            except Exception as e:
                logger.error(f"Failed to create witness for node {node_pub_key}: {e}")
                raise

        logger.info(f"Attached {len(signatures)} witnesses to transaction")
        return original_tx

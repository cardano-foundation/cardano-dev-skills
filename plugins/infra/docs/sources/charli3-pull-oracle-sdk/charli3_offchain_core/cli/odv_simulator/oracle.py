"""Oracle simulation orchestrator."""

import asyncio
import logging

from pycardano import (
    Address,
    Transaction,
    TransactionWitnessSet,
    VerificationKeyWitness,
)

from charli3_offchain_core.cli.aggregate_txs.base import TransactionContext
from charli3_offchain_core.cli.config.formatting import (
    print_header,
    print_progress,
    print_status,
)
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.base import TxValidityInterval
from charli3_offchain_core.models.client import OdvFeedRequest, OdvTxSignatureRequest
from charli3_offchain_core.models.message import SignedOracleNodeMessage
from charli3_offchain_core.oracle.aggregate.builder import (
    OdvResult,
    OracleTransactionBuilder,
)
from charli3_offchain_core.oracle.utils.common import build_aggregate_message

from .models import SimulatedNode, SimulationConfig, SimulationResult
from .node import NodeSimulator

logger = logging.getLogger(__name__)


class OracleSimulator:
    """Orchestrates oracle simulation operations."""

    def __init__(
        self,
        config: SimulationConfig,
        ref_script_config: ReferenceScriptConfig,
    ) -> None:
        """Initialize simulator with configuration."""
        self.config = config

        print_progress("Initializing nodes from configuration")

        self.nodes = [
            SimulatedNode.from_key_directory(node_dir)
            for node_dir in config.simulation.get_node_dirs()
        ]

        self.node_simulators = {
            node.hex_feed_vkh: NodeSimulator(
                node=node,
                base_feed=config.simulation.base_feed,
                variance=config.simulation.variance,
            )
            for node in self.nodes
        }

        print_progress(f"Successfully initialized {len(self.nodes)} node simulators")
        print_progress("Setting up transaction context and builder")

        self.ctx = TransactionContext(config)
        self.tx_builder = OracleTransactionBuilder(
            tx_manager=self.ctx.tx_manager,
            script_address=self.ctx.script_address,
            policy_id=self.ctx.policy_id,
            ref_script_config=ref_script_config,
            reward_token_hash=self.ctx.reward_token_hash,
            reward_token_name=self.ctx.reward_token_name,
        )
        print_status("Success", "Transaction setup complete", success=True)

    async def collect_feed_updates(self) -> dict[str, SignedOracleNodeMessage]:
        """Collect feed updates from all nodes."""
        print_progress("Calculating validity window for feed updates")
        validity_window = self.ctx.tx_manager.calculate_validity_window(
            self.config.odv_validity_length
        )

        feed_request = OdvFeedRequest(
            oracle_nft_policy_id=self.config.policy_id,
            tx_validity_interval=TxValidityInterval(
                start=validity_window.validity_start, end=validity_window.validity_end
            ),
        )

        print_progress("Requesting feed values from all nodes")
        tasks = [
            node.handle_feed_request(feed_request)
            for node in self.node_simulators.values()
        ]

        responses = await asyncio.gather(*tasks)
        feed_responses = {pkh: msg for pkh, msg in responses if msg is not None}

        print_status(
            "Feed Updates",
            f"Received {len(feed_responses)} node responses",
            success=True,
        )
        return feed_responses

    async def collect_signatures(
        self, node_messages: dict[str, SignedOracleNodeMessage], tx: Transaction
    ) -> dict[str, str]:
        """Collect transaction signatures from all nodes."""
        print_progress("Preparing transaction signature request")
        tx_request = OdvTxSignatureRequest(
            node_messages=node_messages,
            tx_body_cbor=tx.transaction_body.to_cbor_hex(),
        )

        print_progress("Requesting transaction signatures from nodes")
        tasks = [
            node.handle_sign_request(tx_request)
            for node in self.node_simulators.values()
        ]

        responses = await asyncio.gather(*tasks)

        signed_signatures = {}
        for node_pkh, response in zip(self.node_simulators.keys(), responses):
            if response is not None:
                signed_signatures[node_pkh] = response

        print_status(
            "Signed Tx Signatures",
            f"Received {len(signed_signatures)} node signatures",
            success=True,
        )
        return signed_signatures

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
                print(node_message)
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

    async def submit_odv(
        self,
        node_messages: dict[str, SignedOracleNodeMessage],
        change_address: Address | None = None,
    ) -> OdvResult:
        """Submit ODV transaction.

        Args:
            node_messages: Dictionary of node messages
            change_address: Optional change address

        Returns:
            OdvResult with transaction and outputs
        """
        print_progress("Loading transaction keys")
        signing_key, default_change = self.ctx.load_keys()
        change_address = change_address or default_change

        print_progress("Building aggregate message from node responses")

        validity_window = self.ctx.tx_manager.calculate_validity_window(
            self.config.odv_validity_length
        )

        aggregate_message = build_aggregate_message(list(node_messages.values()))
        print_status(
            "Aggregate Message",
            f"Created with {aggregate_message.node_feeds_count} feeds "
            f"(validity window timestamp: {validity_window.current_time})",
            success=True,
        )

        print_progress("Building ODV transaction")
        result = await self.tx_builder.build_odv_tx(
            message=aggregate_message,
            signing_key=signing_key,
            change_address=change_address,
            validity_window=validity_window,
        )

        print_progress("Collecting node signatures for transaction")
        node_signatures = await self.collect_signatures(
            node_messages, result.transaction
        )

        print_progress("Adding node signatures to transaction")
        self.attach_signature_witnesses(
            result.transaction,
            node_signatures,
            node_messages,
        )

        print_progress("Submitting final ODV transaction")
        status, _ = await self.ctx.tx_manager.sign_and_submit(
            result.transaction,
            [signing_key],
            wait_confirmation=True,
        )

        if status != "confirmed":
            raise RuntimeError(f"ODV transaction failed: {status}")

        print_status("ODV Submission", "Completed successfully", success=True)
        return result

    async def run_simulation(self) -> SimulationResult:
        """Run complete oracle simulation."""
        try:
            print_header("Phase 1: Feed Collection")
            node_messages = await self.collect_feed_updates()

            if not node_messages:
                raise RuntimeError("No valid node responses received")

            for i, msg in enumerate(node_messages.values()):
                print(
                    f"Node {i} feed: {msg.message.feed}, timestamp: {msg.message.timestamp}"
                )
                print(
                    f"Node {i} VKH: {msg.verification_key.hash().to_primitive().hex()}"
                )

            print_header("Phase 2: ODV Transaction")
            odv_result = await self.submit_odv(node_messages)

            # Extract reward distribution from account output
            rewards_dict = None
            if odv_result.account_output.datum:
                try:
                    reward_datum = odv_result.account_output.datum.datum
                    if hasattr(reward_datum, "nodes_to_rewards"):
                        rewards_dict = {
                            vkh.to_primitive().hex(): amount
                            for vkh, amount in reward_datum.nodes_to_rewards.items()
                        }
                except Exception as e:
                    logger.warning(f"Failed to extract reward distribution: {e}")

            print_status("Simulation", "Completed successfully", success=True)
            return SimulationResult(
                nodes=self.nodes,
                feeds={
                    i: {
                        "feed": msg.message.feed,
                        "verification_key": msg.verification_key.to_cbor().hex(),
                        "timestamp": msg.message.timestamp,
                    }
                    for i, msg in enumerate(node_messages.values())
                },
                odv_tx=str(odv_result.transaction.id),
                rewards=rewards_dict,
            )

        except Exception as e:
            logger.error("Simulation failed: %s", e)
            raise

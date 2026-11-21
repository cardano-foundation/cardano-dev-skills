import logging
from pathlib import Path

import click

from charli3_offchain_core.cli.aggregate_txs.base import TransactionContext, tx_options
from charli3_offchain_core.cli.config.formatting import (
    print_header,
    print_information,
    print_progress,
    print_status,
)
from charli3_offchain_core.cli.config.odv_client import OdvClientConfig
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.cli.config.utils import async_command
from charli3_offchain_core.cli.odv_client.formatting import (
    print_aggregate_summary,
    print_collection_stats,
    print_node_messages,
    print_signature_status,
)
from charli3_offchain_core.client.odv import ODVClient
from charli3_offchain_core.models.base import TxValidityInterval
from charli3_offchain_core.models.client import OdvFeedRequest, OdvTxSignatureRequest
from charli3_offchain_core.oracle.aggregate.builder import OracleTransactionBuilder
from charli3_offchain_core.oracle.exceptions import TransactionError
from charli3_offchain_core.oracle.utils.common import build_aggregate_message

logger = logging.getLogger(__name__)


@click.group()
def client() -> None:
    """Oracle ODV client commands."""


@client.command()
@tx_options
@click.option(
    "--wait/--no-wait",
    default=True,
    help="Wait for transaction confirmation",
)
@async_command
async def send(config: Path, wait: bool) -> None:
    """Send oracle client requests for ODV flow."""
    try:
        print_header("ODV Send Request")
        print_progress("Loading configuration and initializing network connection")
        odv_config = OdvClientConfig.from_yaml(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)
        ctx = TransactionContext(odv_config.tx_config)

        signing_key, change_address = ctx.load_keys()

        builder = OracleTransactionBuilder(
            tx_manager=ctx.tx_manager,
            script_address=ctx.script_address,
            policy_id=ctx.policy_id,
            ref_script_config=ref_script_config,
            reward_token_hash=ctx.reward_token_hash,
            reward_token_name=ctx.reward_token_name,
        )

        odv_client = ODVClient()

        validity_window = ctx.tx_manager.calculate_validity_window(
            odv_config.odv_validity_length
        )

        feed_request = OdvFeedRequest(
            oracle_nft_policy_id=odv_config.tx_config.policy_id,
            tx_validity_interval=TxValidityInterval(
                start=validity_window.validity_start, end=validity_window.validity_end
            ),
        )

        print_progress("Initiating node feed collection process")
        node_messages = await odv_client.collect_feed_updates(
            nodes=odv_config.nodes, feed_request=feed_request
        )

        if not node_messages:
            print_status(
                "Node Collection", "No valid responses received", success=False
            )
            raise click.ClickException("No valid node responses received")

        print_collection_stats(
            received=len(node_messages),
            total=len(odv_config.nodes),
            collection_type="feed responses",
        )
        print_node_messages(node_messages)

        print_progress("Constructing ODV aggregate transaction")
        aggregate_message = build_aggregate_message(list(node_messages.values()))
        print_aggregate_summary(aggregate_message, validity_window)

        result = await builder.build_odv_tx(
            message=aggregate_message,
            signing_key=signing_key,
            change_address=change_address,
            validity_window=validity_window,
        )

        print_information("Transaction Construction Complete")

        print_progress("Initiating signature collection from oracle nodes")
        tx_request = OdvTxSignatureRequest(
            node_messages=node_messages,
            tx_body_cbor=result.transaction.transaction_body.to_cbor_hex(),
        )

        signatures = await odv_client.collect_tx_signatures(
            nodes=odv_config.nodes, tx_request=tx_request
        )

        print_collection_stats(
            received=len(signatures),
            total=len(odv_config.nodes),
            collection_type="signatures",
        )
        print_signature_status(signatures)

        if not signatures:
            print_status(
                "Signature Collection", "No valid signatures received", success=False
            )
            raise click.ClickException("No valid signatures received")

        print_progress("Finalizing transaction with collected signatures")

        result.transaction = odv_client.attach_signature_witnesses(
            original_tx=result.transaction,
            signatures=signatures,
            node_messages=node_messages,
        )

        print_progress("Initiating ODV transaction submission")
        tx_status, _ = await ctx.tx_manager.sign_and_submit(
            result.transaction, [signing_key], wait_confirmation=wait
        )

        if tx_status == "confirmed":
            # print_send_summary(result)  # Out of scope - uses old RewardTransport
            print_status(
                "ODV Aggregation",
                f"Completed successfully. TX: {result.transaction.id}",
                success=True,
            )
        else:
            print_status(
                "Transaction Submission",
                f"Failed with status: {tx_status}",
                success=False,
            )
            raise click.ClickException(f"Transaction failed with status: {tx_status}")

    except TransactionError as e:
        print_status("Transaction Processing", str(e), success=False)
        raise click.ClickException(str(e)) from e
    except Exception as e:
        print_status("ODV Process", str(e), success=False)
        logger.error("ODV failed", exc_info=e)
        raise click.ClickException(str(e)) from e

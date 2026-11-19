"""CLI commands for Oracle Data Verification (ODV) operations."""

import json
import logging
from pathlib import Path
from typing import Any

import click
from pycardano import PaymentExtendedSigningKey, UTxO, VerificationKeyHash

from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.oracle_datums import (
    AggState,
)
from charli3_offchain_core.models.oracle_redeemers import (
    AggregateMessage,
)
from charli3_offchain_core.oracle.aggregate.builder import (
    OdvResult,
    OracleTransactionBuilder,
)
from charli3_offchain_core.oracle.exceptions import TransactionError
from charli3_offchain_core.oracle.utils import (
    asset_checks,
    state_checks,
)

from ..config.formatting import print_header, print_progress
from ..config.utils import async_command
from .base import TransactionContext, TxConfig, tx_options

logger = logging.getLogger(__name__)


@click.group()
def odv_aggregate() -> None:
    """ODV (On-Demand Validation) transaction commands."""


@odv_aggregate.command()
@tx_options
@click.option(
    "--feeds-file",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="JSON file containing node feeds and signatures",
)
@click.option(
    "--node-keys-dir",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Directory containing node signing keys",
)
@click.option(
    "--wait/--no-wait",
    default=True,
    help="Wait for transaction confirmation",
)
@async_command
async def submit(
    config: Path, feeds_file: Path, node_keys_dir: Path, wait: bool
) -> None:
    """Submit ODV transaction with aggregated feeds.

    Example:
        charli3 tx odv_aggregate submit --config tx-config.yaml --feeds-file feeds.json
    """
    try:
        # Load configuration and initialize context
        print_header("ODV Transaction Submission")

        # Load configuration
        print_progress("Loading configuration...")
        tx_config = TxConfig.from_yaml(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)
        ctx = TransactionContext(tx_config)

        # Load and validate feed data
        print_progress("Loading feeds data...")
        with feeds_file.open() as f:
            feed_data = json.load(f)
            validate_feed_data(feed_data)
            message = process_feed_data(feed_data)

        # Load node signing keys
        print_progress("Loading node keys...")
        node_keys = []
        for node_dir in sorted(node_keys_dir.glob("node_*")):
            try:
                skey = PaymentExtendedSigningKey.load(str(node_dir / "feed.skey"))
                node_keys.append(skey)
            except Exception as e:  # pylint: disable=broad-except
                logger.warning("Failed to load key from %s: %s", node_dir, e)

        if not node_keys:
            raise click.ClickException("No node keys found")

        # Load primary signing key
        signing_key, change_address = ctx.load_keys()

        # Initialize transaction builder
        builder = OracleTransactionBuilder(
            tx_manager=ctx.tx_manager,
            script_address=ctx.script_address,
            policy_id=ctx.policy_id,
            ref_script_config=ref_script_config,
            reward_token_hash=ctx.reward_token_hash,
            reward_token_name=ctx.reward_token_name,
        )

        # Build ODV transaction
        print_progress("Building ODV Aggregate transaction...")
        result = await builder.build_odv_tx(
            message=message,
            signing_key=signing_key,
            change_address=change_address,
        )

        # Sign transaction with all node keys
        print_progress("Signing transaction with node keys...")
        all_signing_keys = [signing_key, *node_keys]
        tx_status, _ = await ctx.tx_manager.sign_and_submit(
            result.transaction, all_signing_keys, wait_confirmation=wait
        )

        # Get transaction ID from the original transaction
        tx_id = result.transaction.id

        click.secho(f"\n✓ Transaction {tx_status}!", fg="green")
        click.echo(f"Transaction ID: {tx_id}")

        # Display additional details
        if tx_status == "confirmed":
            _print_odv_summary(result)

    except ValueError as e:
        logger.error("ODV submission failed: %s", e)

    except TransactionError as e:
        logger.error("Transaction failed: %s", e)

    except Exception as e:
        logger.error("ODV submission failed", exc_info=e)
        raise click.ClickException(str(e)) from e


@odv_aggregate.command()
@tx_options
@async_command
async def status(config: Path) -> None:
    """Show current ODV transaction status.

    Example:
        charli3 tx odv_aggregate status --config tx-config.yaml
    """
    try:
        print_header("ODV Aggregate Status Check")
        print_progress("Loading configuration...")
        tx_config = TxConfig.from_yaml(config)
        ctx = TransactionContext(tx_config)

        # Get UTxOs and current time
        print_progress("Checking UTxO status...")
        script_utxos = await ctx.chain_query.get_utxos(ctx.script_address)
        current_time = ctx.chain_query.get_current_posix_chain_time_ms()

        # Filter account states using utility functions
        account_utxos = asset_checks.filter_utxos_by_token_name(
            script_utxos, ctx.policy_id, "C3RA"
        )

        # Filter agg states
        agg_state_utxos = asset_checks.filter_utxos_by_token_name(
            script_utxos, ctx.policy_id, "C3AS"
        )
        empty_agg_states = state_checks.filter_empty_agg_states(agg_state_utxos)

        # Get all valid agg states and separate empty from expired
        valid_agg_states = state_checks.filter_valid_agg_states(
            agg_state_utxos, current_time
        )

        # Filter expired states (valid states that aren't empty)
        expired_agg_states = [
            utxo
            for utxo in valid_agg_states
            if is_expired_agg_state(utxo, current_time)
        ]

        # Display status
        click.echo("\nODV Aggregate Status:")
        click.echo("-" * 40)
        click.echo(f"Number of account UTxOs: {len(account_utxos)}")
        click.echo("\nAggState UTxOs:")
        click.echo(f"Empty: {len(empty_agg_states)}")
        click.echo(f"Expired: {len(expired_agg_states)}")
        click.echo(f"Total Valid (Empty + Expired): {len(valid_agg_states)}")

        if expired_agg_states:
            click.echo("\nExpired AggState UTxOs:")
            click.echo("-" * 40)
            for utxo in expired_agg_states:
                _print_expired_aggstate(utxo)

    except Exception as e:
        logger.error("Status check failed", exc_info=e)
        raise click.ClickException(str(e)) from e


def is_expired_agg_state(utxo: UTxO, current_time: int) -> bool:
    """Check if a UTxO is an expired aggregator state."""
    datum = utxo.output.datum
    return (
        datum is not None
        and isinstance(datum, AggState)
        and datum.price_data is not None
        and datum.price_data.is_expired(current_time)
    )


def _print_expired_aggstate(utxo: UTxO) -> None:
    """Print details of expired AggState UTxO."""
    if not isinstance(utxo.output.datum, AggState):
        return

    price_data = utxo.output.datum.price_data
    if not price_data.is_valid:
        return

    click.echo(f"\nUTxO: {utxo.input.transaction_id}#{utxo.input.index}")
    click.echo(f"Created At: {price_data.get_creation_time}")
    click.echo(f"Expired At: {price_data.get_expiration_time}")
    click.echo(f"Oracle Feed: {price_data.get_price}")


def _print_odv_summary(result: OdvResult) -> None:
    """Print summary of ODV transaction result."""
    click.echo("\nTransaction Summary:")
    click.echo("-" * 40)

    # Print account UTxO details
    account_datum = result.account_output.datum.datum
    total_fee = account_datum.aggregation.rewards_amount_paid
    node_count = len(account_datum.aggregation.message.node_feeds_sorted_by_feed)
    node_reward = account_datum.aggregation.node_reward_price
    platform_fee = total_fee - (node_count * node_reward)

    click.echo("account Details:")
    click.echo(f"  Oracle Feed: {account_datum.aggregation.oracle_feed}")
    click.echo(f"  Node Count: {node_count}")
    click.echo(f"  Reward per Node: {node_reward}")
    click.echo(f"  Platform Fee: {platform_fee}")
    click.echo(f"  Total Rewards Amount: {total_fee}")

    # Print AggState UTxO details
    agg_datum = result.agg_state_output.datum.price_data
    click.echo("\nAggState Details:")
    click.echo(f"  Oracle Feed: {agg_datum.get_price}")
    click.echo(f"  Created At: {agg_datum.get_creation_time}")
    click.echo(f"  Expires At: {agg_datum.get_creation_time}")

    click.echo(f"\nTransaction Fee: {result.transaction.transaction_body.fee}")


def _validate_required_fields(feed_data: dict) -> None:
    """Validate that all required fields are present in feed data."""
    required_fields = ["node_feeds_sorted_by_feed", "node_feeds_count", "timestamp"]
    if not all(field in feed_data for field in required_fields):
        raise ValueError("Missing required fields in feed data")


def _validate_field_types(feed_data: dict) -> None:
    """Validate the types of feed data fields."""
    if not isinstance(feed_data["node_feeds_sorted_by_feed"], dict):
        raise ValueError("node_feeds_sorted_by_feed must be a dictionary")

    if not isinstance(feed_data["node_feeds_count"], int):
        raise ValueError("node_feeds_count must be an integer")

    if not isinstance(feed_data["timestamp"], int):
        raise ValueError("timestamp must be an integer")


def _validate_feed_count(node_feeds: dict, expected_count: int) -> None:
    """Validate that the number of feeds matches the expected count."""
    if len(node_feeds) != expected_count:
        raise ValueError("node_feeds_count doesn't match number of feeds")


def _validate_feed_sorting(node_feeds: dict) -> None:
    """Validate that feeds are sorted by their values."""
    feed_values = list(node_feeds.values())
    if feed_values != sorted(feed_values):
        raise ValueError("node_feeds_sorted_by_feed must be sorted by feed values")


def _validate_vkh_and_feeds(node_feeds: dict) -> None:
    """Validate VKH format and feed values."""
    for vkh, feed_value in node_feeds.items():
        if not isinstance(vkh, str):
            raise ValueError(f"Invalid VKH format: {vkh}")
        try:
            # VKH should be a valid hex string
            bytes.fromhex(vkh)
        except ValueError as exc:
            raise ValueError(f"Invalid VKH hex format: {vkh}") from exc

        if not isinstance(feed_value, int):
            raise ValueError(f"Invalid feed value for VKH {vkh}")


def validate_feed_data(feed_data: dict) -> None:
    """Validate feed data format and content.

    Expected format:
    {
        "node_feeds_sorted_by_feed": {
            "vkh1": feed_value1,
            "vkh2": feed_value2,
            ...
        },
        "node_feeds_count": integer,
        "timestamp": integer
    }
    """
    _validate_required_fields(feed_data)
    _validate_field_types(feed_data)

    node_feeds = feed_data["node_feeds_sorted_by_feed"]
    _validate_feed_count(node_feeds, feed_data["node_feeds_count"])
    _validate_feed_sorting(node_feeds)
    _validate_vkh_and_feeds(node_feeds)


def process_feed_data(feed_data: dict[str, Any]) -> AggregateMessage:
    """Process feed data directly into AggregateMessage.

    Instead of creating an intermediate dictionary, directly construct
    the AggregateMessage object.
    """
    # Convert string VKHs and build the feeds dictionary
    feeds = {}
    for vkh_str, feed_value in feed_data["node_feeds_sorted_by_feed"].items():
        vkh = VerificationKeyHash(bytes.fromhex(vkh_str))
        feeds[vkh] = feed_value  # NodeFeed is just an int

    # Directly create AggregateMessage
    return AggregateMessage(node_feeds_sorted_by_feed=feeds)

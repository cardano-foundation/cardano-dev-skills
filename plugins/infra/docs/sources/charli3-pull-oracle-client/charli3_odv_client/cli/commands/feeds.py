"""Feed collection command implementation."""

import asyncio
import sys
from pathlib import Path
from typing import Optional

import click

from charli3_odv_client.config import ODVClientConfig, ReferenceScriptConfig
from charli3_odv_client.core.client import ODVClient
from charli3_odv_client.models.requests import OdvFeedRequest
from charli3_odv_client.models.base import TxValidityInterval
from charli3_odv_client.cli.display.formatters import CLIDisplay
from charli3_odv_client.cli.utils.shared import (
    create_chain_query,
    setup_transaction_builder,
)
from charli3_odv_client.core.aggregation import build_aggregate_message


@click.command()
@click.option(
    "--config",
    "-c",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Configuration file path",
)
@click.option("--policy-id", "-p", help="Override oracle NFT policy ID")
@click.option(
    "--validity-length",
    "-v",
    type=int,
    default=120000,
    help="Validity window in milliseconds",
)
@click.option(
    "--output", "-o", type=click.Path(path_type=Path), help="Save feed data to file"
)
@click.option("--verbose", is_flag=True, help="Enable detailed output")
def feeds(
    config: Path,
    policy_id: Optional[str],
    validity_length: int,
    output: Optional[Path],
    verbose: bool,
) -> None:
    """Collect current feed data from oracle nodes."""

    async def _collect_feeds() -> None:
        try:
            client_config = ODVClientConfig.from_yaml(config)
            ref_script_config = ReferenceScriptConfig.from_yaml(config)
            target_policy_id = policy_id or client_config.policy_id

            CLIDisplay.print_info("Collecting Oracle Feed Data")
            CLIDisplay.print_info(f"Policy ID: {target_policy_id}")
            CLIDisplay.print_info(f"Validity window: {validity_length}ms")
            CLIDisplay.print_info(f"Target nodes: {len(client_config.nodes)}")

            # Create chain query and tx manager for proper time calculation
            chain_query = create_chain_query(client_config)
            tx_manager, _ = setup_transaction_builder(
                client_config, ref_script_config, chain_query
            )

            with CLIDisplay.create_progress() as progress:
                task = progress.add_task("Collecting feed updates...", total=None)

                # Use transaction manager to calculate validity window
                validity_window = tx_manager.calculate_validity_window(validity_length)

                feed_request = OdvFeedRequest(
                    oracle_nft_policy_id=target_policy_id,
                    tx_validity_interval=TxValidityInterval(
                        start=validity_window.validity_start,
                        end=validity_window.validity_end,
                    ),
                )

                client = ODVClient()
                node_messages = await client.collect_feed_updates(
                    nodes=client_config.nodes, feed_request=feed_request
                )

                progress.update(task, description="Processing responses...")

                aggregate_message = build_aggregate_message(
                    list(node_messages.values()),
                )

                progress.update(task, description="Feed collection complete")

            CLIDisplay.print_feed_results(node_messages, aggregate_message, verbose)

            if output:
                CLIDisplay.save_feed_data(node_messages, aggregate_message, output)
                CLIDisplay.print_success(f"Feed data saved to {output}")

        except Exception as e:
            CLIDisplay.print_error("Feed collection failed", e)
            sys.exit(1)

    asyncio.run(_collect_feeds())

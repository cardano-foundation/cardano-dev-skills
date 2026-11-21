"""ODV aggregation command implementation."""

import asyncio
import json
import sys
from pathlib import Path
from typing import Optional

import click

from charli3_odv_client.config import KeyManager, ODVClientConfig, ReferenceScriptConfig
from charli3_odv_client.core.client import ODVClient
from charli3_odv_client.models.requests import OdvFeedRequest, OdvTxSignatureRequest
from charli3_odv_client.models.base import TxValidityInterval
from charli3_odv_client.cli.display.formatters import CLIDisplay
from charli3_odv_client.cli.utils.shared import (
    create_chain_query,
    setup_transaction_builder,
)
from charli3_odv_client.cli.utils.validation import (
    validate_and_prompt_overwrite,
    prompt_for_confirmation,
)


@click.command()
@click.option(
    "--config",
    "-c",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Configuration file path",
)
@click.option(
    "--feed-data",
    "-f",
    type=click.Path(exists=True, path_type=Path),
    help="Load previously saved feed data instead of collecting fresh data",
)
@click.option(
    "--wallet-key",
    type=click.Path(exists=True, path_type=Path),
    help="Wallet key file (overrides config)",
)
@click.option(
    "--output",
    "-o",
    type=click.Path(path_type=Path),
    help="Save transaction CBOR to file (always saves, whether submitted or not)",
)
@click.option(
    "--auto-submit",
    is_flag=True,
    help="Automatically submit transaction without confirmation prompt",
)
@click.option("--verbose", is_flag=True, help="Enable detailed output")
def aggregate(
    config: Path,
    feed_data: Optional[Path] = None,
    wallet_key: Optional[Path] = None,
    output: Optional[Path] = None,
    auto_submit: bool = False,
    verbose: bool = False,
) -> None:
    """Execute complete ODV aggregation workflow.

    This command will:
    1. Collect feed data from oracle nodes (or load from file)
    2. Build the aggregation transaction
    3. Collect signatures from oracle nodes
    4. Optionally submit the transaction to the blockchain

    The transaction CBOR is always saved to a file for later submission if needed.
    """

    async def _aggregate_async() -> None:
        client_config = None
        output_file = None

        try:
            # Step 1: Initialize and validate
            with CLIDisplay.create_progress() as progress:
                init_task = progress.add_task("Loading configuration...", total=None)

                client_config = ODVClientConfig.from_yaml(config)
                ref_script_config = ReferenceScriptConfig.from_yaml(config)
                client = ODVClient()
                chain_query = create_chain_query(client_config)
                tx_manager, tx_builder = setup_transaction_builder(
                    client_config, ref_script_config, chain_query
                )
                validity_window = tx_manager.calculate_validity_window(
                    client_config.odv_validity_length
                )

                signing_key, _, _, change_address = KeyManager.load_from_config(
                    wallet_key or client_config.wallet
                )

                output_file = output
                if not output_file:
                    output_file = Path(
                        f"odv_transaction_{client_config.policy_id[:8]}.cbor"
                    )

                progress.update(init_task, description="Configuration loaded")
                progress.stop_task(init_task)

            CLIDisplay.print_config_summary(client_config, verbose)

            if not validate_and_prompt_overwrite(output_file):
                CLIDisplay.print_info("Operation cancelled by user")
                return

            # Step 2: Collect or load feed data
            if feed_data:
                CLIDisplay.print_info("Loading feed data from file")
                with feed_data.open() as f:
                    data = json.load(f)
                    node_messages = CLIDisplay.reconstruct_node_messages(
                        data["node_messages"]
                    )
                CLIDisplay.print_success(
                    f"Loaded {len(node_messages)} node messages from file"
                )
            else:
                with CLIDisplay.create_progress() as progress:
                    feed_task = progress.add_task(
                        "Collecting feed data from oracle nodes...", total=None
                    )

                    feed_request = OdvFeedRequest(
                        oracle_nft_policy_id=client_config.policy_id,
                        tx_validity_interval=TxValidityInterval(
                            start=validity_window.validity_start,
                            end=validity_window.validity_end,
                        ),
                    )

                    node_messages = await client.collect_feed_updates(
                        nodes=client_config.nodes, feed_request=feed_request
                    )

                    progress.update(feed_task, description="Feed collection complete")

                if not node_messages:
                    CLIDisplay.print_error("No valid node responses received")
                    sys.exit(1)

                CLIDisplay.print_feed_responses(node_messages, verbose)

            # Step 3: Build transaction
            with CLIDisplay.create_progress() as progress:
                build_task = progress.add_task(
                    "Building aggregation transaction...", total=None
                )

                odv_result = await tx_builder.build_odv_tx(
                    node_messages=node_messages,
                    signing_key=signing_key,
                    change_address=change_address,
                    validity_window=validity_window,
                )

                progress.update(
                    build_task, description="Transaction built successfully"
                )

            CLIDisplay.print_transaction_summary(
                str(odv_result.transaction.id),
                odv_result.median_value,
                verbose,
                node_feeds_processed=odv_result.aggregate_message.node_feeds_count,
                cbor_length=len(odv_result.transaction.to_cbor_hex()),
            )

            # Step 4: Collect signatures
            with CLIDisplay.create_progress() as progress:
                sig_task = progress.add_task(
                    "Collecting signatures from oracle nodes...", total=None
                )

                try:
                    tx_request = OdvTxSignatureRequest(
                        node_messages=node_messages,
                        tx_body_cbor=odv_result.transaction.transaction_body.to_cbor_hex(),
                    )

                    signatures = await client.collect_tx_signatures(
                        nodes=client_config.nodes, tx_request=tx_request
                    )

                    progress.update(
                        sig_task, description="Signature collection complete"
                    )

                except Exception as e:
                    progress.stop()
                    CLIDisplay.handle_signature_collection_error(
                        e, client_config, verbose
                    )
                    sys.exit(1)

            if not signatures:
                CLIDisplay.print_error("No valid signatures received")
                sys.exit(1)

            CLIDisplay.print_signatures_summary(signatures, verbose)

            # Step 5: Attach signatures to the transaction
            CLIDisplay.print_info("Attaching signatures to transaction")

            odv_result.transaction = client.attach_signature_witnesses(
                original_tx=odv_result.transaction,
                signatures=signatures,
                node_messages=node_messages,
            )

            # Step 6: Always save transaction CBOR
            with output_file.open("w") as f:
                f.write(odv_result.transaction.to_cbor_hex())
            CLIDisplay.print_success(f"Transaction saved to {output_file}")

            # Step 7: Show transaction preview and ask for submission confirmation
            CLIDisplay.print_transaction_preview(
                transaction_id=str(odv_result.transaction.id),
                median_value=odv_result.median_value,
                node_count=len(node_messages),
                signature_count=len(signatures),
                output_file=output_file,
            )

            # Determine if we should submit
            should_submit = auto_submit
            if not should_submit:
                should_submit = prompt_for_confirmation(
                    "Submit transaction to blockchain?", default=True
                )

            if should_submit:
                # Step 8: Submit transaction
                with CLIDisplay.create_progress() as progress:
                    submit_task = progress.add_task(
                        "Submitting transaction to blockchain...", total=None
                    )

                    try:
                        status, submitted_tx = await tx_manager.sign_and_submit(
                            odv_result.transaction,
                            signing_keys=[signing_key],
                            wait_confirmation=True,
                        )

                        progress.update(
                            submit_task, description="Transaction submitted"
                        )

                    except Exception as e:
                        progress.stop()
                        CLIDisplay.handle_submission_error(e, verbose)
                        sys.exit(1)

                if status == "confirmed":
                    CLIDisplay.print_success("Transaction confirmed on blockchain")
                    CLIDisplay.print_final_summary(
                        str(odv_result.transaction.id),
                        odv_result.median_value,
                        len(node_messages),
                        len(signatures),
                    )
                else:
                    CLIDisplay.print_error(f"Transaction failed with status: {status}")
                    sys.exit(1)
            else:
                CLIDisplay.print_info("Transaction ready for manual submission")
                CLIDisplay.print_manual_submission_instructions(output_file)

        except Exception as e:
            CLIDisplay.print_error("Aggregation failed", e)
            sys.exit(1)

    asyncio.run(_aggregate_async())

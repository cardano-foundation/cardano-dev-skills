import json
import logging
from pathlib import Path

import click

from charli3_offchain_core.cli.config.formatting import (
    platform_success_callback,
    print_confirmation_message_prompt,
    print_hash_info,
    print_platform_auth_config_prompt,
    print_status,
)
from charli3_offchain_core.cli.transaction import (
    create_sign_tx_command,
    create_submit_tx_command,
)

from ..constants.status import ProcessStatus
from .config.utils import async_command
from .setup import setup_platform_from_config

logger = logging.getLogger(__name__)


@click.group()
def platform() -> None:
    """Platform authorization commands."""
    pass


@platform.group()
def token() -> None:
    """Platform authorization commands."""
    pass


token.add_command(
    create_sign_tx_command(
        status_signed_value=ProcessStatus.TRANSACTION_SIGNED,
    )
)

token.add_command(
    create_submit_tx_command(
        status_success_value=ProcessStatus.TRANSACTION_CONFIRMED,
        success_callback=platform_success_callback,
    )
)


@token.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to platform configuration YAML",
)
@click.option(
    "--metadata",
    type=click.Path(exists=True, path_type=Path),
    help="Optional metadata JSON file",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Output file for transaction data",
)
@async_command
async def mint(
    config: Path,
    metadata: Path | None,
    output: Path | None = None,
) -> None:
    """Build and sign/submit platform auth token transaction."""
    try:
        (
            auth_config,
            payment_sk,
            payment_vk,
            _,
            default_addr,
            _,
            tx_manager,
            orchestrator,
            meta_data,
        ) = setup_platform_from_config(config, metadata)

        if not print_platform_auth_config_prompt(auth_config):
            raise click.Abort()

        result = await orchestrator.build_tx(
            sender_address=default_addr,
            signing_key=payment_sk,
            multisig_threshold=auth_config.multisig.threshold,
            multisig_parties=auth_config.multisig.parties,
            metadata=meta_data,
            network=auth_config.network.network,
            is_mock=False,
        )

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(f"Failed to create transaction: {result.error}")

        # Handle based on threshold
        if auth_config.multisig.threshold > 1:
            output = output or Path("tx_platform_mint.json")
            data = {
                "transaction": result.transaction.to_cbor_hex(),
                "policy_id": result.policy_id,
                "signed_by": [],
                "platform_address": str(result.platform_address),
                "threshold": auth_config.multisig.threshold,
            }

            if print_confirmation_message_prompt(
                "The built tx requires multisignatures. Would you like to sign the transaction now?"
            ):
                tx_manager.sign_tx(result.transaction, payment_sk)
                data["transaction"] = result.transaction.to_cbor_hex()
                data["signed_by"].append(str(payment_vk.payload.hex()))

            with output.open("w") as f:
                json.dump(data, f)

            print_status("Status", "Tx built and signed successfully", success=True)
            print_hash_info("Output file", str(output))
            print_hash_info(
                "Reminder",
                "Tx requires more than 1 signatures for successful submission",
            )
        elif print_confirmation_message_prompt(
            "You can proceed with minting right away. Would you like to continue?"
        ):
            status, _ = await tx_manager.sign_and_submit(
                result.transaction, [payment_sk]
            )
            if status == ProcessStatus.TRANSACTION_CONFIRMED:
                print_status(
                    "Platform authorization token",
                    "Minted successfully",
                    success=True,
                )
                print_hash_info("Transaction ID", result.transaction.id)
                print_hash_info("Platform Address", result.platform_address)
                print_hash_info("Policy ID", result.policy_id)
            else:
                raise click.ClickException("Transaction failed")
        else:
            raise click.Abort

    except click.Abort:
        click.echo("Process aborted by the user.")
    except Exception as e:
        logger.error("Failed to process transaction", exc_info=e)
        raise click.ClickException(str(e)) from e

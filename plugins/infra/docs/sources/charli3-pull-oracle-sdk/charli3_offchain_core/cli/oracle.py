"""CLI commands for oracle deployment and management."""

import json
import logging
from pathlib import Path

import click
from pycardano import Network

from charli3_offchain_core.cli.config.formatting import format_status_update
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.cli.governance import (
    add_nodes,
    del_nodes,
    scale_down,
    scale_up,
    update_settings,
)
from charli3_offchain_core.cli.rewards import (
    dismiss_rewards,
    node_collect,
    platform_collect,
)
from charli3_offchain_core.cli.transaction import (
    create_sign_tx_command,
    create_submit_tx_command,
)
from charli3_offchain_core.constants.colors import CliColor
from charli3_offchain_core.oracle.lifecycle.orchestrator import LifecycleOrchestrator

from ..constants.status import ProcessStatus
from .config.formatting import (
    format_deployment_summary,
    oracle_success_callback,
    print_confirmation_message_prompt,
    print_confirmation_prompt,
    print_hash_info,
    print_header,
    print_progress,
    print_status,
)
from .config.utils import async_command
from .setup import setup_management_from_config, setup_oracle_from_config

logger = logging.getLogger(__name__)


@click.group()
def oracle() -> None:
    """Oracle deployment and management commands."""


oracle.add_command(
    create_sign_tx_command(
        status_signed_value=ProcessStatus.TRANSACTION_SIGNED,
    )
)

oracle.add_command(
    create_submit_tx_command(
        status_success_value=ProcessStatus.TRANSACTION_CONFIRMED,
        success_callback=oracle_success_callback,
    )
)

oracle.add_command(update_settings)
oracle.add_command(scale_up)
oracle.add_command(scale_down)
oracle.add_command(add_nodes)
oracle.add_command(del_nodes)
oracle.add_command(node_collect)
oracle.add_command(platform_collect)
oracle.add_command(dismiss_rewards)


@oracle.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to deployment configuration YAML",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Output file for transaction data",
)
@async_command
async def deploy(config: Path, output: Path | None) -> None:  # noqa
    """Deploy new oracle instance using configuration file."""
    try:
        print_header("Deployment Configuration")
        print_progress("Loading configuration")

        # Setup configuration and components
        setup = setup_oracle_from_config(config)
        (
            deployment_config,
            oracle_config,
            payment_sk,
            _payment_vk,
            addresses,
            chain_query,
            tx_manager,
            orchestrator,
            platform_auth_finder,
            configs,
        ) = setup

        if not print_confirmation_prompt(
            {
                "Admin Address": addresses.admin_address,
                "Script Address": addresses.script_address,
                "Platform Address": addresses.platform_address,
            }
        ):
            raise click.Abort()

        # Validate platform auth
        print_progress("Validating platform auth UTxO...")
        platform_utxo = await platform_auth_finder.find_auth_utxo(
            policy_id=deployment_config.tokens.platform_auth_policy,
            platform_address=addresses.platform_address,
        )
        if not platform_utxo:
            raise click.ClickException(
                f"No UTxO found with platform auth NFT (policy: {deployment_config.tokens.platform_auth_policy})"
            )

        platform_script = await platform_auth_finder.get_platform_script(
            addresses.platform_address
        )
        platform_multisig_config = platform_auth_finder.get_script_config(
            platform_script
        )
        logger.info(
            "Using platform UTxO: %s#%s",
            platform_utxo.input.transaction_id,
            platform_utxo.input.index,
        )

        # Handle reference scripts
        reference_result, needs_reference = await orchestrator.handle_reference_scripts(
            script_config=configs["script"],
            admin_address=addresses.admin_address,
            signing_key=payment_sk,
        )

        if needs_reference:
            if (
                orchestrator.reference_builder.script_finder.reference_script_address
                != (
                    orchestrator.contracts.spend.mainnet_addr
                    if chain_query.context.network == Network.MAINNET
                    else orchestrator.contracts.spend.testnet_addr
                )
            ):
                click.secho(
                    "WARNING: If you are deploying a reference script to an address that you are going to use with another third party wallet:\n\
                                1. This reference script UTXO might become unusable from that third party wallet.\n\
                                2. To use this UTXO again, remove reference script from there using the CLI - run `charli3 reference-script remove`.",
                    fg=CliColor.WARNING,
                )
            if not print_confirmation_message_prompt(
                "Reference Script was not found! Would you like to proceed with reference script creation now?"
            ):
                raise click.Abort()
            await orchestrator.submit_reference_script_tx(reference_result, payment_sk)
        else:
            print_progress("Reference script already exists, Proceeding...")

        # Build deployment transaction
        result = await orchestrator.build_tx(
            oracle_config=oracle_config,
            use_aiken=deployment_config.use_aiken,
            blueprint_path=deployment_config.blueprint_path,
            platform_script=platform_script,
            admin_address=addresses.admin_address,
            script_address=addresses.script_address,
            aggregation_liveness_period=deployment_config.timing.aggregation_liveness,
            time_uncertainty_aggregation=deployment_config.timing.time_uncertainty_aggregation,
            time_uncertainty_platform=deployment_config.timing.time_uncertainty_platform,
            iqr_fence_multiplier=deployment_config.timing.iqr_multiplier,
            median_divergency_factor=deployment_config.timing.median_divergency_factor,
            deployment_config=configs["deployment"],
            rate_config=configs["rate_token"],
            nodes_config=deployment_config.nodes,
            signing_key=payment_sk,
            platform_utxo=platform_utxo,
            utxo_size_safety_buffer=deployment_config.timing.utxo_size_safety_buffer,
        )

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(f"Deployment failed: {result.error}")

        # Handle transaction signing based on threshold
        if platform_multisig_config.threshold == 1:
            if print_confirmation_message_prompt(
                "You can deploy the oracle with the configured Platform Auth NFT right away. Would you like to continue?"
            ):
                status, _ = await tx_manager.sign_and_submit(
                    result.start_result.transaction,
                    [payment_sk],
                    wait_confirmation=True,
                )
                if status == ProcessStatus.TRANSACTION_CONFIRMED:
                    format_deployment_summary(result)
                else:
                    raise click.ClickException(f"Deployment failed: {status}")
        elif print_confirmation_message_prompt(
            "PlatformAuth NFT being used requires multisigatures and thus will be stored. Would you like to continue?"
        ):
            output_path = output or Path("tx_oracle_deploy.json")
            with output_path.open("w") as f:
                json.dump(
                    {
                        "transaction": result.start_result.transaction.to_cbor_hex(),
                        "script_address": str(addresses.script_address),
                        "signed_by": [],
                        "threshold": platform_multisig_config.threshold,
                    },
                    f,
                )
            print_status("Transaction", "saved successfully", success=True)
            print_hash_info("Output file", str(output_path))
            print_hash_info(
                "Next steps",
                f"Transaction requires {platform_multisig_config.threshold} signatures",
            )

    except Exception as e:
        logger.error("Deployment failed", exc_info=e)
        raise click.ClickException(str(e)) from e


@oracle.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to deployment configuration YAML",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Output file for transaction data",
)
@async_command
async def pause(config: Path, output: Path | None) -> None:
    """Pause an oracle instance using configuration file."""
    try:
        print_header("Oracle Pause")
        (
            management_config,
            _,
            loaded_key,
            oracle_addresses,
            chain_query,
            tx_manager,
            platform_auth_finder,
        ) = setup_management_from_config(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)

        platform_utxo = await platform_auth_finder.find_auth_utxo(
            policy_id=management_config.tokens.platform_auth_policy,
            platform_address=oracle_addresses.platform_address,
        )
        if not platform_utxo:
            raise click.ClickException("No platform auth UTxO found")

        platform_script = await platform_auth_finder.get_platform_script(
            oracle_addresses.platform_address
        )
        platform_config = platform_auth_finder.get_script_config(platform_script)

        orchestrator = LifecycleOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )
        result = await orchestrator.pause_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            signing_key=loaded_key.payment_sk,
        )

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(f"Pause failed: {result.error}")

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt("Proceed with oracle pause?"):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(f"Pause failed: {status}")
                print_status("Pause", "completed successfully", success=True)
        elif print_confirmation_message_prompt("Store multisig pause transaction?"):
            output_path = output or Path("tx_oracle_pause.json")
            with output_path.open("w") as f:
                json.dump(
                    {
                        "transaction": result.transaction.to_cbor_hex(),
                        "signed_by": [],
                        "threshold": platform_config.threshold,
                    },
                    f,
                )
            print_status("Transaction", "saved successfully", success=True)
            print_hash_info("Output file", str(output_path))

    except Exception as e:
        logger.error("Pause failed", exc_info=e)
        raise click.ClickException(str(e)) from e


@oracle.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to deployment configuration YAML",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Output file for transaction data",
)
@async_command
async def resume(config: Path, output: Path | None) -> None:
    """Resume a paused oracle instance using configuration file."""
    try:
        print_header("Oracle Resume")
        (
            management_config,
            _,
            loaded_key,
            oracle_addresses,
            chain_query,
            tx_manager,
            platform_auth_finder,
        ) = setup_management_from_config(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)

        platform_utxo = await platform_auth_finder.find_auth_utxo(
            policy_id=management_config.tokens.platform_auth_policy,
            platform_address=oracle_addresses.platform_address,
        )
        if not platform_utxo:
            raise click.ClickException("No platform auth UTxO found")

        platform_script = await platform_auth_finder.get_platform_script(
            oracle_addresses.platform_address
        )
        platform_config = platform_auth_finder.get_script_config(platform_script)

        orchestrator = LifecycleOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.resume_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            signing_key=loaded_key.payment_sk,
        )

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(f"Resume failed: {result.error}")

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt("Proceed with oracle resume?"):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(f"Resume failed: {status}")
                print_status("Resume", "completed successfully", success=True)
        elif print_confirmation_message_prompt("Store multisig resume transaction?"):
            output_path = output or Path("tx_oracle_resume.json")
            with output_path.open("w") as f:
                json.dump(
                    {
                        "transaction": result.transaction.to_cbor_hex(),
                        "signed_by": [],
                        "threshold": platform_config.threshold,
                    },
                    f,
                )
            print_status("Transaction", "saved successfully", success=True)
            print_hash_info("Output file", str(output_path))

    except Exception as e:
        logger.error("Resume failed", exc_info=e)
        raise click.ClickException(str(e)) from e


@oracle.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to deployment configuration YAML",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Output file for transaction data",
)
@async_command
async def remove(config: Path, output: Path | None) -> None:
    """Remove an oracle instance permanently using configuration file."""
    try:
        print_header("Oracle Remove")
        (
            management_config,
            oracle_conf,
            loaded_key,
            oracle_addresses,
            chain_query,
            tx_manager,
            platform_auth_finder,
        ) = setup_management_from_config(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)

        platform_utxo = await platform_auth_finder.find_auth_utxo(
            policy_id=management_config.tokens.platform_auth_policy,
            platform_address=oracle_addresses.platform_address,
        )
        if not platform_utxo:
            raise click.ClickException("No platform auth UTxO found")

        platform_script = await platform_auth_finder.get_platform_script(
            oracle_addresses.platform_address
        )
        platform_config = platform_auth_finder.get_script_config(platform_script)

        orchestrator = LifecycleOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )
        result = await orchestrator.remove_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            signing_key=loaded_key.payment_sk,
            pause_period=oracle_conf.pause_period_length,
        )

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(
                f"Remove failed: {result.error}"
            ) from result.error

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt(
                "Proceed with oracle removal? This action cannot be undone."
            ):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(f"Remove failed: {status}")
                print_status("Remove", "completed successfully", success=True)
        elif print_confirmation_message_prompt("Store multisig remove transaction?"):
            output_path = output or Path("tx_oracle_remove.json")
            with output_path.open("w") as f:
                json.dump(
                    {
                        "transaction": result.transaction.to_cbor_hex(),
                        "signed_by": [],
                        "threshold": platform_config.threshold,
                    },
                    f,
                )
            print_status("Transaction", "saved successfully", success=True)
            print_hash_info("Output file", str(output_path))

    except Exception as e:
        logger.error("Remove failed", exc_info=e)
        raise click.ClickException(str(e)) from e


if __name__ == "__main__":
    oracle(_anyio_backend="asyncio")

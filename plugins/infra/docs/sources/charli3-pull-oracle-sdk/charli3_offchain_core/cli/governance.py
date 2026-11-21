"""CLI commands for oracle deployment and management."""

import json
import logging
from pathlib import Path

import click

from charli3_offchain_core.cli.config.formatting import format_status_update
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.oracle.governance.orchestrator import GovernanceOrchestrator

from ..constants.status import ProcessStatus
from .config.formatting import (
    print_confirmation_message_prompt,
    print_hash_info,
    print_header,
    print_status,
)
from .config.utils import async_command
from .setup import setup_management_from_config

logger = logging.getLogger(__name__)


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
@click.command()
@async_command
async def add_nodes(config: Path, output: Path | None) -> None:  # noqa: C901
    """Add the nodes' PKHs to an Oracle instance"""
    try:
        print_header("Add Nodes")
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

        orchestrator = GovernanceOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.add_nodes_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            new_nodes_config=management_config.nodes,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            signing_key=loaded_key.payment_sk,
        )
        if result.status == ProcessStatus.CANCELLED_BY_USER:
            print_status(
                "Add nodes Status", "Operation cancelled by user", success=True
            )
            return
        if result.status == ProcessStatus.VERIFICATION_FAILURE:
            print_status(
                "Add nodes Status",
                "On-chain validation does not meet the requirements.",
                success=False,
            )
            return
        if result.status != ProcessStatus.TRANSACTION_BUILT:
            if result.error:
                raise click.ClickException(
                    f"Add nodes failed: {result.error}"
                ) from result.error
            raise click.ClickException("Add nodes failed: unknown error")

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt(
                "Proceed signing and submitting add-nodes tx?"
            ):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(f"Add nodes failed: {status}")
                print_status("Add nodes", "completed successfully", success=True)
        elif print_confirmation_message_prompt("Store multisig update transaction?"):
            output_path = output or Path("tx_oracle_add_nodes.json")
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
        logger.error("Add nodes failed", exc_info=e)
        raise click.ClickException(str(e)) from e


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
@click.command()
@async_command
async def del_nodes(config: Path, output: Path | None) -> None:
    """Remove the nodes' PKHs to an Oracle instance"""
    try:
        print_header("Delete Nodes")
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

        orchestrator = GovernanceOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.del_nodes_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            new_nodes_config=management_config.nodes,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            tokens=management_config.tokens,
            signing_key=loaded_key.payment_sk,
        )
        if result.status == ProcessStatus.CANCELLED_BY_USER:
            print_status(
                "Delete nodes Status", "Operation cancelled by user", success=True
            )
            return
        if result.status == ProcessStatus.VERIFICATION_FAILURE:
            print_status(
                "Delete Nodes",
                "On-Chain validation requirements not met",
                success=False,
            )
            return

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(
                f"Delete nodes failed: {result.error}"
            ) from result.error

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt(
                "Proceed signing and submitting delete-nodes tx?"
            ):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(
                        f"Delete nodes failed: {status}"
                    ) from result.error
                print_status("Delete nodes", "completed successfully", success=True)
        elif print_confirmation_message_prompt("Store multisig update transaction?"):
            output_path = output or Path("tx_oracle_delete_nodes.json")
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
        logger.error("Delete nodes failed", exc_info=e)
        raise click.ClickException(str(e)) from e


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
@click.command()
@async_command
async def update_settings(config: Path, output: Path | None) -> None:
    """Updates the core settings configuration of an Oracle instance."""
    try:
        print_header("Oracle Update Settings")
        (
            management_config,
            oracle_config,
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

        orchestrator = GovernanceOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.update_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            oracle_config=oracle_config,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            signing_key=loaded_key.payment_sk,
        )
        if result.status == ProcessStatus.CANCELLED_BY_USER:
            print_status("Update Status", "Operation cancelled by user", success=True)
            return
        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(
                f"Update failed: {result.error}"
            ) from result.error

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt("Proceed with oracle update?"):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(f"Update failed: {status}")
                print_status("Update", "completed successfully", success=True)
        elif print_confirmation_message_prompt("Store multisig update transaction?"):
            output_path = output or Path("tx_oracle_update_settings.json")
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
        logger.error("Update failed", exc_info=e)
        raise click.ClickException(str(e)) from e


@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to deployment configuration YAML",
)
@click.option(
    "--reward-accounts",
    type=int,
    default=0,
    help="Number of RewardAccount UTxOs to create (default 0)",
)
@click.option(
    "--aggstates",
    type=int,
    default=0,
    help="Number of AggState UTxOs to create (default 0)",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Output file for transaction data",
)
@click.command()
@async_command
async def scale_up(
    config: Path, reward_accounts: int, aggstates: int, output: Path | None
) -> None:
    """Scale up ODV capacity by creating new RewardAccount and/or AggState UTxOs"""
    try:
        if reward_accounts == 0 and aggstates == 0:
            raise click.ClickException(
                "At least one of --reward-accounts or --aggstates must be specified"
            )

        print_header("Scale Up ODV Capacity")

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

        orchestrator = GovernanceOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.scale_up_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            reward_account_count=reward_accounts,
            aggstate_count=aggstates,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            signing_key=loaded_key.payment_sk,
        )

        if result.status == ProcessStatus.FAILED:
            print_status(
                "Scale Up Status",
                "On-chain validation does not meet the requirements.",
                success=False,
            )
            return

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(f"Scale up failed: {result.error}")

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt(
                "Proceed signing and submitting scale-up tx?"
            ):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(f"Scale up failed: {status}")
                print_status("Scale up", "completed successfully", success=True)
        elif print_confirmation_message_prompt("Store multisig scale-up transaction?"):
            output_path = output or Path("tx_oracle_scale_up.json")
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
        logger.error("Scale up failed", exc_info=e)
        raise click.ClickException(str(e)) from e


@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to deployment configuration YAML",
)
@click.option(
    "--reward-accounts",
    type=int,
    default=0,
    help="Number of empty RewardAccount UTxOs to remove (default 0)",
)
@click.option(
    "--aggstates",
    type=int,
    default=0,
    help="Number of empty/expired AggState UTxOs to remove (default 0)",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Output file for transaction data",
)
@click.command()
@async_command
async def scale_down(
    config: Path, reward_accounts: int, aggstates: int, output: Path | None
) -> None:
    """Scale down ODV capacity by removing RewardAccount and/or AggState UTxOs"""
    try:
        if reward_accounts == 0 and aggstates == 0:
            raise click.ClickException(
                "At least one of --reward-accounts or --aggstates must be specified"
            )

        print_header("Scale Down ODV Capacity")

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

        orchestrator = GovernanceOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.scale_down_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            reward_account_count=reward_accounts,
            aggstate_count=aggstates,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            change_address=oracle_addresses.admin_address,
            signing_key=loaded_key.payment_sk,
        )

        if result.status == ProcessStatus.FAILED:
            print_status(
                "Scale Down Status",
                "On-chain validation does not meet the requirements.",
                success=False,
            )
            return

        if result.status != ProcessStatus.TRANSACTION_BUILT:
            raise click.ClickException(f"Scale down failed: {result.error}")

        if platform_config.threshold == 1:
            if print_confirmation_message_prompt(
                "Proceed signing and submitting scale-down tx?"
            ):
                status, _ = await tx_manager.sign_and_submit(
                    result.transaction, [loaded_key.payment_sk], wait_confirmation=True
                )
                if status != ProcessStatus.TRANSACTION_CONFIRMED:
                    raise click.ClickException(f"Scale down failed: {status}")
                print_status("Scale down", "completed successfully", success=True)
        elif print_confirmation_message_prompt(
            "Store multisig scale-down transaction?"
        ):
            output_path = output or Path("tx_oracle_scale_down.json")
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
        logger.error("Scale down failed", exc_info=e)
        raise click.ClickException(str(e)) from e

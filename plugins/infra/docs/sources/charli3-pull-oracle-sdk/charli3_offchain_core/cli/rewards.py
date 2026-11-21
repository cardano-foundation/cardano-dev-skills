"""CLI commands for oracle rewards. """

import json
import logging
from pathlib import Path

import click
from pycardano import Address, PaymentSigningKey

from charli3_offchain_core.blockchain.exceptions import CollateralError
from charli3_offchain_core.cli.base import DerivedAddresses, LoadedKeys
from charli3_offchain_core.cli.config.formatting import format_status_update
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.oracle.exceptions import (
    ADABalanceNotFoundError,
    CollectingNodesError,
    CollectingPlatformError,
    DismissRewardCancelledError,
    NodeCollectCancelled,
    NodeNotRegisteredError,
    NoExpiredTransportsYetError,
    NoPendingTransportsFoundError,
    NoRewardsAvailableError,
    PlatformCollectCancelled,
)
from charli3_offchain_core.oracle.rewards.orchestrator import (
    RewardOrchestrator,
    RewardOrchestratorResult,
)

from ..constants.status import ProcessStatus
from .config.formatting import (
    print_confirmation_message_prompt,
    print_hash_info,
    print_header,
    print_progress,
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
@click.option(
    "--batch-size",
    type=int,
    default=10,
    help="Maximum number of reward accounts to process",
)
@click.command()
@async_command
async def node_collect(config: Path, output: Path | None, batch_size: int) -> None:
    """Node Operator Withdrawal Transaction: Individual Rewards Collection"""
    try:
        print_progress("Loading Node Collect Configuration")
        (
            management_config,
            _,
            loaded_key,
            oracle_addresses,
            chain_query,
            tx_manager,
            _,
        ) = setup_management_from_config(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)

        # payment_key: check if withdrawal_mnemonic exists in config
        # If it exists, load full key details
        payment_key = None
        signing_keys = [loaded_key.payment_sk]

        if management_config.network.wallet.withdrawal_mnemonic:
            from charli3_offchain_core.cli.config.keys import KeyManager

            (
                withdrawal_sk,
                withdrawal_vk,
                withdrawal_addr,
            ) = KeyManager.load_withdrawal_key_from_mnemonic(
                management_config.network.wallet.withdrawal_mnemonic,
                management_config.network.network,
            )
            payment_key = (withdrawal_sk, withdrawal_addr)
            # Add withdrawal key to signing keys (prevent duplicates if same key)
            if withdrawal_sk != loaded_key.payment_sk:
                signing_keys.append(withdrawal_sk)

        orchestrator = RewardOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.collect_node_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            tokens=management_config.tokens,
            loaded_key=loaded_key,
            network=management_config.network.network,
            max_inputs=batch_size,
            payment_key=payment_key,
        )

        if _handle_node_collect_error(
            result, oracle_addresses, loaded_key, payment_key
        ):
            return

        if result.transaction and print_confirmation_message_prompt(
            "Proceed signing and submitting Node-Collect tx?"
        ):
            status, _ = await tx_manager.sign_and_submit(
                result.transaction, signing_keys, wait_confirmation=True
            )
            if status != ProcessStatus.TRANSACTION_CONFIRMED:
                raise click.ClickException(f"Collect nodes failed: {status}")
            print_status("Collect nodes", "completed successfully", success=True)

    except Exception as e:
        logger.error("Collect nodes failed", exc_info=e)
        raise click.ClickException(str(e)) from e


def _handle_node_collect_error(
    result: RewardOrchestratorResult,
    oracle_addresses: DerivedAddresses,
    loaded_key: LoadedKeys,
    payment_key: tuple[PaymentSigningKey, Address] | None = None,
) -> bool:
    """Handle errors from node collect operation. Returns True if execution should stop."""
    if isinstance(result.error, NodeNotRegisteredError):
        user_message = (
            f"The payment verification key hash (VKH) derived from the configuration "
            f"is not associated with any node in the oracle contract.\n"
            f"Payment Verification Key Hash (VKH): {result.error}\n"
            f"Oracle contract address: {oracle_addresses.script_address}\n"
            "Please ensure the mnemonic in the configuration file is correct and "
            "corresponds to a registered node."
        )
        print_status(result.status, user_message, False)
        return True

    if isinstance(result.error, NoRewardsAvailableError):
        user_message = (
            f"No rewards available\n"
            f"{result.error} \n"
            f"Contract: {oracle_addresses.script_address}\n"
            "Try again later"
        )
        print_status(result.status, user_message, True)
        return True

    if isinstance(result.error, CollectingNodesError):
        user_message = (
            "Insufficient rewards balance\n"
            "Please verify settings or contact Charli3 support for assistance"
        )
        print_status(result.status, user_message, success=True)
        return True

    if isinstance(result.error, NodeCollectCancelled):
        print_status("Collect Node Status", "Operation cancelled by user", success=True)
        return True

    if isinstance(result.error, ADABalanceNotFoundError | CollateralError):
        user_message = (
            "Your wallet appears to be empty.\n"
            "ADA is required for transaction fees.\n"
            f"Wallet address: {payment_key[1] if payment_key else loaded_key.address}"
        )
        print_status(result.status, user_message, success=False)
        return True

    return False


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
@click.option(
    "--batch-size",
    type=int,
    default=10,
    help="Maximum number of reward accounts to process",
)
@click.command()
@async_command
async def platform_collect(config: Path, output: Path | None, batch_size: int) -> None:
    """Platform Withdrawal Transaction"""
    try:
        print_header("Platform Collect")
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

        orchestrator = RewardOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.collect_platform_oracle(
            oracle_policy=management_config.tokens.oracle_policy,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            tokens=management_config.tokens,
            loaded_key=loaded_key,
            network=management_config.network.network,
            max_inputs=batch_size,
        )

        if isinstance(result.error, NoRewardsAvailableError):
            user_message = (
                f"No rewards available\n"
                f"{result.error} \n"
                f"Contract: {oracle_addresses.script_address}\n"
                "Try again later"
            )
            print_status(result.status, user_message, True)
            return
        if isinstance(result.error, PlatformCollectCancelled):
            print_status(
                "Collect Platform Status", "Operation cancelled by user", success=True
            )
            return
        if isinstance(result.error, CollectingPlatformError):
            user_message = (
                "Insufficient rewards balance\n"
                "Please verify settings or contact Charli3 support for assistance"
            )
            print_status(result.status, user_message, success=True)
            return

        if isinstance(result.error, CollateralError):
            user_message = (
                "Your wallet appears to be empty.\n"
                "ADA is required for transaction fees.\n"
                f"Wallet address: {loaded_key.address}"
            )

            print_status(result.status, user_message, success=False)
            return

        if (
            platform_config.threshold == 1
            and result.transaction
            and print_confirmation_message_prompt("Proceed with Platform Collect tx?")
        ):
            status, _ = await tx_manager.sign_and_submit(
                result.transaction, [loaded_key.payment_sk], wait_confirmation=True
            )
            if status != ProcessStatus.TRANSACTION_CONFIRMED:
                raise click.ClickException(f"Platfrom Collect failed: {status}")
            print_status("Platform Collect", "completed successfully", success=True)
        elif (
            print_confirmation_message_prompt("Store multisig update transaction?")
            and result.transaction
        ):
            output_path = output or Path("tx_oracle_platform_collect.json")
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
        logger.error("Platform Collect failed", exc_info=e)
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
@click.option(
    "--batch-size",
    type=int,
    default=10,
    help="Maximum number of reward accounts to process",
)
@click.command()
@async_command
async def dismiss_rewards(config: Path, output: Path | None, batch_size: int) -> None:
    """Dismiss rewards from reward account UTxOs"""
    try:
        print_header("Dismiss Rewrads")
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

        orchestrator = RewardOrchestrator(
            chain_query=chain_query,
            tx_manager=tx_manager,
            script_address=oracle_addresses.script_address,
            ref_script_config=ref_script_config,
            status_callback=format_status_update,
        )

        result = await orchestrator.dismiss_rewards(
            oracle_policy=management_config.tokens.oracle_policy,
            platform_utxo=platform_utxo,
            platform_script=platform_script,
            tokens=management_config.tokens,
            loaded_key=loaded_key,
            network=management_config.network.network,
            reward_dismission_period_length=management_config.timing.reward_dismissing_period,
            max_inputs=batch_size,
        )

        if isinstance(result.error, NoPendingTransportsFoundError):
            user_message = "No reward account UTxOs available for dismissing"
            print_status(result.status, user_message, success=True)
            return

        if isinstance(result.error, NoRewardsAvailableError):
            user_message = (
                f"No rewards available\n"
                f"{result.error} \n"
                f"Contract: {oracle_addresses.script_address}\n"
                "Try again later"
            )
            print_status(result.status, user_message, True)
            return

        if isinstance(result.error, NoExpiredTransportsYetError):
            user_message = f"{result.error} Try again later"
            print_status(result.status, user_message, True)
            return

        if isinstance(result.error, DismissRewardCancelledError):
            print_status(
                "Dismiss Reward Status", "Operation cancelled by user", success=True
            )
            return
        if (
            platform_config.threshold == 1
            and result.transaction
            and print_confirmation_message_prompt("Proceed with Dismiss Reward tx?")
        ):
            status, _ = await tx_manager.sign_and_submit(
                result.transaction, [loaded_key.payment_sk], wait_confirmation=True
            )
            if status != ProcessStatus.TRANSACTION_CONFIRMED:
                raise click.ClickException(f"Dismiss Reward failed: {status}")
            print_status(
                "Dismiss Reward transaction", "completed successfully", success=True
            )
        elif (
            print_confirmation_message_prompt("Store multisig update transaction?")
            and result.transaction
        ):
            output_path = output or Path("tx_oracle_dismiss_reward.json")
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
        logger.error("Dismiss Reward failed", exc_info=e)
        raise click.ClickException(str(e)) from e

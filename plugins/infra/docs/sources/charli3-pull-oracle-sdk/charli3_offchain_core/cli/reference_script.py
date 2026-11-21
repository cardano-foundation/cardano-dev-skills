import json
import logging
from pathlib import Path

import click
from pycardano import (
    Address,
    Network,
    Transaction,
    TransactionBuilder,
    TransactionOutput,
)
from pycardano.hash import ScriptHash
from pycardano.nativescript import NativeScript

from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.base import (
    LoadedKeys,
    create_chain_query,
    derive_deployment_addresses,
    load_keys_with_validation,
)
from charli3_offchain_core.cli.config.deployment import DeploymentConfig
from charli3_offchain_core.cli.config.formatting import (
    oracle_success_callback,
    print_confirmation_message_prompt,
    print_hash_info,
    print_information,
    print_progress,
    print_status,
    print_title,
)
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.cli.config.utils import async_command
from charli3_offchain_core.cli.setup import (
    apply_spend_params_with_aiken_compiler,
    setup_management_from_config,
    setup_token,
)
from charli3_offchain_core.cli.transaction import (
    create_sign_tx_command,
    create_submit_tx_command,
)
from charli3_offchain_core.constants.colors import CliColor
from charli3_offchain_core.constants.status import ProcessStatus
from charli3_offchain_core.contracts.aiken_loader import OracleContracts
from charli3_offchain_core.models.oracle_datums import OracleConfiguration
from charli3_offchain_core.oracle.config import OracleScriptConfig
from charli3_offchain_core.oracle.deployment.reference_script_finder import (
    ReferenceScriptFinder,
)
from charli3_offchain_core.oracle.utils.common import get_reference_script_utxo

logger = logging.getLogger(__name__)


@click.group()
def reference_script() -> None:
    """Oracle reference script deployment and management commands."""


reference_script.add_command(
    create_sign_tx_command(
        status_signed_value=ProcessStatus.TRANSACTION_SIGNED,
    )
)

reference_script.add_command(
    create_submit_tx_command(
        status_success_value=ProcessStatus.TRANSACTION_CONFIRMED,
        success_callback=oracle_success_callback,
    )
)


@reference_script.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Path to deployment configuration YAML",
)
@click.option(
    "--force/--no-force",
    default=False,
    help="Force creation even if script exists",
)
@async_command
async def create(config: Path, force: bool) -> None:
    """Create oracle manager reference script separately."""
    try:
        # Load configuration and contracts
        print_progress("Loading configuration...")
        deployment_config = DeploymentConfig.from_yaml(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)

        reward_token = setup_token(
            deployment_config.tokens.reward_token_policy,
            deployment_config.tokens.reward_token_name,
        )

        # Create oracle configuration
        oracle_config = OracleConfiguration(
            platform_auth_nft=bytes.fromhex(
                deployment_config.tokens.platform_auth_policy
            ),
            pause_period_length=deployment_config.timing.pause_period,
            reward_dismissing_period_length=deployment_config.timing.reward_dismissing_period,
            fee_token=reward_token,
        )

        # Parameterize contracts
        if deployment_config.use_aiken:
            parameterized_contracts = apply_spend_params_with_aiken_compiler(
                oracle_config, deployment_config.blueprint_path
            )
        else:
            base_contracts = OracleContracts.from_blueprint(
                deployment_config.blueprint_path
            )
            parameterized_contracts = OracleContracts(
                spend=base_contracts.apply_spend_params(oracle_config),
                mint=base_contracts.mint,
            )

        # Load keys and initialize components
        keys = load_keys_with_validation(deployment_config, parameterized_contracts)
        addresses = derive_deployment_addresses(
            deployment_config, parameterized_contracts
        )

        # Initialize chain query
        chain_query = create_chain_query(deployment_config.network)

        tx_manager = TransactionManager(chain_query)

        # Create script config
        script_config = OracleScriptConfig(
            create_manager_reference=True, reference_ada_amount=53000000
        )

        # Check for existing script
        ref_script_finder = ReferenceScriptFinder(
            chain_query, parameterized_contracts, ref_script_config
        )
        if not force:
            print_progress("Checking for existing reference script...")
            existing = await ref_script_finder.find_manager_reference()
            if existing:
                print_information(
                    f"Found existing reference script at: {existing.output.address}"
                )
        if ref_script_finder.reference_script_address != (
            parameterized_contracts.spend.mainnet_addr
            if chain_query.context.network == Network.MAINNET
            else parameterized_contracts.spend.testnet_addr
        ):
            click.secho(
                "WARNING: If you are deploying a reference script to an address that you are going to use with another third party wallet:\n\
                              1. This reference script UTXO might become unusable from that third party wallet.\n\
                              2. To use this UTXO again, remove reference script from there using the CLI - run `charli3 reference-script remove`.",
                fg=CliColor.WARNING,
            )
        if not click.confirm("Continue with creation?"):
            raise click.Abort()

        # Create and submit transaction
        print_progress("Creating reference script...")

        result = await tx_manager.build_reference_script_tx(
            script=parameterized_contracts.spend.contract,
            reference_script_address=ref_script_finder.reference_script_address,
            admin_address=addresses.admin_address,
            signing_key=keys.payment_sk,
            reference_ada=script_config.reference_ada_amount,
        )

        status, _ = await tx_manager.sign_and_submit(result, [keys.payment_sk])
        if status == "confirmed":
            print_status(
                "Reference script creation", "completed successfully", success=True
            )
        else:
            raise click.ClickException(f"Transaction failed with status: {status}")

    except Exception as e:
        logger.error("Reference script creation failed", exc_info=e)
        raise click.ClickException(str(e)) from e


@reference_script.command()
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
async def remove(config: Path, output: Path | None) -> None:  # noqa
    """Remove oracle manager reference script."""
    fee_buffer = 190_000
    try:
        # Load configuration and contracts
        print_progress("Loading configuration...")
        (
            management_config,
            _,
            keys,
            oracle_addresses,
            chain_query,
            tx_manager,
            platform_auth_finder,
        ) = setup_management_from_config(config)
        ref_script_config = ReferenceScriptConfig.from_yaml(config)

        # Check for existing script
        print_progress("Checking for existing reference script...")
        ref_script_utxo = await get_reference_script_utxo(
            chain_query, ref_script_config, oracle_addresses.script_address
        )
        if ref_script_utxo:
            print_information(
                f"Found existing reference script at: {ref_script_utxo.output.address}"
            )

        withdrawal_address = await confirm_withdrawal_address(
            keys,
            ref_script_utxo.output.address,
            ref_script_utxo.output.lovelace,
            management_config.network.network,
        )
        withdrawal_output = TransactionOutput(
            withdrawal_address, ref_script_utxo.output.amount
        )

        # Check script owner
        script_owner = ref_script_utxo.output.address.payment_part
        if script_owner is None:
            raise click.Abort("No reference script owner found")
        if isinstance(script_owner, ScriptHash):
            print_information(
                f"Reference script owner is a script hash {script_owner.payload.hex()}. Will continue using platform multisig."
            )
        else:
            print_information(
                f"Reference script owner is a single verification key hash {script_owner.payload.hex()}. Will continue using this VKH."
            )
            if keys.payment_vk.hash() != script_owner:
                raise click.Abort("This wallet is not script owner")

        # Create and submit transaction
        print_progress("Removing reference script...")
        if not click.confirm("Continue with removal?"):
            return

        if isinstance(script_owner, ScriptHash):
            platform_script: NativeScript = (
                await platform_auth_finder.get_platform_script(
                    oracle_addresses.platform_address
                )
            )
            platform_config = platform_auth_finder.get_script_config(platform_script)

            # Build transaction for NativeScript input
            builder = TransactionBuilder(chain_query.context, fee_buffer=fee_buffer)
            builder.add_input_address(keys.address)  # For fee payment
            builder.add_input(ref_script_utxo)  # Add as regular input

            # Add the native script to the builder
            if builder.native_scripts is None:
                builder.native_scripts = []
            builder.native_scripts.append(platform_script)

            builder.add_output(withdrawal_output)

            tx_body = builder.build(
                change_address=keys.address, collateral_change_address=keys.address
            )

            # Create initial witness set
            witness_set = builder.build_witness_set()
            witness_set.vkey_witnesses = []

            transaction = Transaction(
                tx_body, witness_set, auxiliary_data=builder.auxiliary_data
            )

            if platform_config.threshold == 1:
                if print_confirmation_message_prompt(
                    "Multisig threshold is one, proceed with tx submitting?"
                ):
                    status, _ = await tx_manager.sign_and_submit(
                        transaction, [keys.payment_sk], wait_confirmation=True
                    )
                    if status != ProcessStatus.TRANSACTION_CONFIRMED:
                        raise click.ClickException(f"Transaction failed: {status}")
                    print_status(
                        "Reference script removal",
                        "completed successfully",
                        success=True,
                    )
            elif print_confirmation_message_prompt("Store multisig transaction?"):
                output_path = output or Path("tx_reference_script.json")
                with output_path.open("w") as f:
                    json.dump(
                        {
                            "transaction": transaction.to_cbor_hex(),
                            "signed_by": [],
                            "threshold": platform_config.threshold,
                        },
                        f,
                    )
                print_status("Transaction", "saved successfully", success=True)
                print_hash_info("Output file", str(output_path))
        else:
            builder = TransactionBuilder(chain_query.context, fee_buffer=fee_buffer)
            builder.add_input(ref_script_utxo)
            builder.add_output(withdrawal_output)

            transaction = await tx_manager.build_tx(
                builder, change_address=keys.address, signing_key=keys.payment_sk
            )

            status, _ = await tx_manager.sign_and_submit(
                transaction, [keys.payment_sk], wait_confirmation=True
            )
            if status != ProcessStatus.TRANSACTION_CONFIRMED:
                raise click.ClickException(f"Transaction failed: {status}")
            print_status(
                "Reference script removal", "completed successfully", success=True
            )

    except Exception as e:
        logger.error("Reference script removal failed", exc_info=e)
        raise click.ClickException(str(e)) from e


async def confirm_withdrawal_address(
    loaded_key: LoadedKeys,
    ref_script_address: Address,
    total_ada: int,
    network: Network,
) -> Address:
    """
    Prompts the user to confirm or change an address for ada withdrawal.
    """
    print_progress("Loading wallet configuration...")

    symbol = "₳ (lovelace)"

    print_status(
        "Verification Key Hash associated with user's wallet",
        message=f"{loaded_key.payment_vk.hash()}",
    )

    print_information(f"Total Locked Funds: {total_ada:_} {symbol}")

    print_title("Select a withdrawal address:")

    enterprise_addr = Address(
        payment_part=loaded_key.payment_vk.hash(), network=network
    )

    click.secho("1. Base Address:", fg="blue")
    print(loaded_key.address)
    click.secho("2. Enterprise Address", fg="blue")
    print(enterprise_addr)
    click.secho("3. Reference Script Address", fg="blue")
    print(ref_script_address)
    click.secho("4. Enter a new address", fg="blue")
    click.secho("q. Quit", fg="blue")

    while True:  # Loop until valid choice is made
        choice = click.prompt(
            "Enter your choice (1-4, q):",
            type=click.Choice(["1", "2", "3", "4", "q"]),  # Add 'q' to choices
            default="3",  # Default to the reference script address
        )

        if choice == "q":
            click.echo("Exiting.")
            raise click.Abort()
        elif choice == "1":
            return loaded_key.address
        elif choice == "2":
            return enterprise_addr
        elif choice == "3":
            return ref_script_address
        else:  # choice == "4"
            while True:  # Keep prompting until a valid address is entered
                new_address_str = click.prompt(
                    "Please enter a new address (or 'q' to quit)"
                )
                if new_address_str.lower() == "q":
                    click.echo("Exiting.")
                    raise click.Abort()
                try:
                    new_address = Address.from_primitive(new_address_str)
                    return new_address
                except Exception as e:
                    click.echo(
                        f"Invalid Cardano address format: {e}. Please try again."
                    )


if __name__ == "__main__":
    reference_script(_anyio_backend="asyncio")

"""Update oracle transaction builder."""

import logging
from enum import Enum
from typing import Any

import click
from pycardano import (
    Address,
    AssetName,
    Datum,
    ExtendedSigningKey,
    NativeScript,
    PaymentSigningKey,
    Redeemer,
    ScriptHash,
    UTxO,
    VerificationKeyHash,
)

from charli3_offchain_core.cli.config.formatting import (
    CliColor,
    print_confirmation_message_prompt,
    print_header,
    print_information,
    print_progress,
    print_status,
)
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.oracle_datums import (
    Asset,
    FeeConfig,
    FeeRateNFT,
    NoDatum,
    OracleConfiguration,
    OracleSettingsDatum,
    OracleSettingsVariant,
    RewardPrices,
    SomeAsset,
)
from charli3_offchain_core.models.oracle_redeemers import (
    ManageSettings,
    UpdateSettings,
)
from charli3_offchain_core.oracle.exceptions import (
    SettingsValidationError,
    UpdateCancelled,
    UpdatingError,
)
from charli3_offchain_core.oracle.utils.common import get_reference_script_utxo
from charli3_offchain_core.oracle.utils.state_checks import (
    get_oracle_settings_by_policy_id,
)

from .base import BaseBuilder, GovernanceTxResult

logger = logging.getLogger(__name__)


class SettingOption(Enum):
    AGGREGATION_LIVENESS = ("1", "Aggregation Liveness Period")
    TIME_UNCERTAINTY_AGGREGATION = ("2", "Time Uncertainty For ODV Aggregation")
    TIME_UNCERTAINTY_PLATFORM = ("3", "Time Uncertainty For Platform Governance")
    IQR_MULTIPLIER = ("4", "IQR Fence Multiplier")
    MEDIAN_DIVERGENCY_FACTOR = ("5", "Median divergency factor")
    UTXO_BUFFER = ("6", "UTxO size safety buffer")
    THRESHOLD = ("7", "Required Node Signature Count")
    NODE_REWARD_FEE = ("8", "Reward price for node fee")
    PLATFORM_REWARD_FEE = ("9", "Reward price for platform fee")
    DONE = ("0", "Done")

    def __init__(self, id: str, label: str) -> None:
        self.id = id
        self.label = label


class UpdateBuilder(BaseBuilder):
    REDEEMER = Redeemer(ManageSettings(redeemer=UpdateSettings()))
    FEE_BUFFER = 10_000

    async def build_tx(
        self,
        oracle_config: OracleConfiguration,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        policy_hash: Any,
        script_address: Address,
        utxos: list[UTxO],
        ref_script_config: ReferenceScriptConfig,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> GovernanceTxResult:
        """Build the update transaction."""
        try:
            _, settings_utxo = get_oracle_settings_by_policy_id(utxos, policy_hash)
            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                ref_script_config,
                script_address,
            )

            if not script_utxo:
                raise ValueError("Reference script UTxO not found")

            try:
                modified_settings_utxo = await manual_settings_menu(
                    settings_utxo, oracle_config
                )
            except (UpdateCancelled, click.Abort):
                return GovernanceTxResult()

            tx = await self.tx_manager.build_script_tx(
                script_inputs=[
                    (settings_utxo, self.REDEEMER, script_utxo),
                    (platform_utxo, None, platform_script),
                ],
                script_outputs=[modified_settings_utxo.output, platform_utxo.output],
                fee_buffer=self.FEE_BUFFER,
                change_address=change_address,
                signing_key=signing_key,
                required_signers=required_signers,
            )
            return GovernanceTxResult(
                transaction=tx, settings_utxo=modified_settings_utxo
            )
        except SettingsValidationError as e:
            raise UpdatingError(f"Failed to build pause transaction: {e!s}") from e


async def get_setting_value(  # noqa: C901
    option: SettingOption,
    current_value: int,
    deployed_settings: Any,
    current_settings: dict,
) -> int:
    """Prompt user for new setting value with validation."""
    while True:
        try:
            # Build help text based on option
            help_text = []
            if option == SettingOption.THRESHOLD:
                help_text.append(f"max: {len(deployed_settings.datum.nodes)}")
            elif option == SettingOption.TIME_UNCERTAINTY_AGGREGATION:
                help_text.append("must be positive")
            elif option == SettingOption.UTXO_BUFFER:
                help_text.append("must not be negative")
            elif option == SettingOption.TIME_UNCERTAINTY_PLATFORM:
                current_time_uncertainty_agg = current_settings[
                    SettingOption.TIME_UNCERTAINTY_AGGREGATION
                ]
                help_text.append(
                    f"must be greater than time uncertainty for odv-aggregation: {current_time_uncertainty_agg}"
                )
            elif option == SettingOption.AGGREGATION_LIVENESS:
                current_time_uncertainty_platform = current_settings[
                    SettingOption.TIME_UNCERTAINTY_PLATFORM
                ]
                help_text.append(
                    f"must be greater than time uncertainty for platform actions: {current_time_uncertainty_platform}"
                )
            elif option == SettingOption.IQR_MULTIPLIER:
                help_text.append("must be greater than 100")
            elif option == SettingOption.MEDIAN_DIVERGENCY_FACTOR:
                help_text.append("must be greater or equal to 1")
            elif option in (
                SettingOption.NODE_REWARD_FEE,
                SettingOption.PLATFORM_REWARD_FEE,
            ):
                help_text.append("must not be negative")

            prompt_text = (
                f"Enter new value for {option.label} (current: {current_value})"
            )
            if help_text:
                prompt_text += f" ({', '.join(help_text)})"

            new_value = click.prompt(
                click.style(prompt_text, fg=CliColor.WARNING, bold=True), type=int
            )

            validate_setting(option, new_value, current_settings, deployed_settings)
            return new_value
        except SettingsValidationError as e:
            print_status("Validation Error", str(e), success=False)
            continue


async def manual_settings_menu(  # noqa: C901
    deployed_core_utxo: UTxO, oracle_config: OracleConfiguration
) -> UTxO:
    """Interactive menu for manual settings updates."""
    deployed_core_settings = deployed_core_utxo.output.datum
    initial_fee_rate_nft = deployed_core_settings.datum.fee_info.rate_nft
    initial_settings = {
        SettingOption.AGGREGATION_LIVENESS: deployed_core_settings.datum.aggregation_liveness_period,
        SettingOption.TIME_UNCERTAINTY_AGGREGATION: deployed_core_settings.datum.time_uncertainty_aggregation,
        SettingOption.TIME_UNCERTAINTY_PLATFORM: deployed_core_settings.datum.time_uncertainty_platform,
        SettingOption.IQR_MULTIPLIER: deployed_core_settings.datum.iqr_fence_multiplier,
        SettingOption.MEDIAN_DIVERGENCY_FACTOR: deployed_core_settings.datum.median_divergency_factor,
        SettingOption.THRESHOLD: deployed_core_settings.datum.required_node_signatures_count,
        SettingOption.UTXO_BUFFER: deployed_core_settings.datum.utxo_size_safety_buffer,
        SettingOption.NODE_REWARD_FEE: deployed_core_settings.datum.fee_info.reward_prices.node_fee,
        SettingOption.PLATFORM_REWARD_FEE: deployed_core_settings.datum.fee_info.reward_prices.platform_fee,
    }
    current_settings = initial_settings.copy()
    invalid_settings = set()

    current_fee_rate_nft = choose_fee_rate_nft(initial_fee_rate_nft)

    while True:
        display_initial_settings_context(
            deployed_core_settings,
            current_settings,
            invalid_settings,
        )

        # Get user choice
        choices = [opt.id for opt in SettingOption] + ["q"]
        choice = click.prompt(
            click.style("\nSelect option", fg=CliColor.WARNING, bold=True),
            type=click.Choice(choices),
        )
        if choice == "q":
            if print_confirmation_message_prompt(
                "Are you sure you want to quit without saving?"
            ):
                raise UpdateCancelled()
            continue

        selected_option = next(opt for opt in SettingOption if opt.id == choice)

        if selected_option == SettingOption.DONE:
            if current_settings == initial_settings and current_fee_rate_nft is None:
                print_status("Update Status", "No changes detected", success=True)
                raise UpdateCancelled()
            # Validate all settings
            invalid_settings.clear()
            try:
                for option in SettingOption:
                    if option != SettingOption.DONE:
                        validate_setting(
                            option,
                            current_settings[option],
                            current_settings,
                            deployed_core_settings,
                        )

                if invalid_settings:
                    print_header("Please fix validation errors before proceeding")
                    continue

                if print_confirmation_message_prompt(
                    "Do you want to proceed with these changes?"
                ):
                    return build_new_settings_datum(
                        deployed_core_utxo,
                        oracle_config,
                        deployed_core_settings,
                        current_settings,
                        current_fee_rate_nft,
                    )
                else:
                    continue
            except SettingsValidationError as e:
                print_status("Validation Error", str(e), success=False)
                continue
            except ValueError as e:
                print_status("Value Validation Error", str(e), success=False)
                continue

        await add_settings_value(
            selected_option,
            deployed_core_settings,
            current_settings,
            invalid_settings,
        )


def build_new_settings_datum(
    deployed_core_utxo: UTxO,
    oracle_config: OracleConfiguration,
    deployed_core_settings: Datum,
    current_settings: dict,
    current_fee_rate_nft: FeeRateNFT | None,
) -> UTxO:
    print_progress("Building new settings datum")
    if current_fee_rate_nft is None:
        current_fee_rate_nft = deployed_core_settings.datum.fee_info.rate_nft

    oracle_settings = OracleSettingsDatum(
        nodes=deployed_core_settings.datum.nodes,
        required_node_signatures_count=current_settings[SettingOption.THRESHOLD],
        fee_info=FeeConfig(
            rate_nft=current_fee_rate_nft,
            reward_prices=RewardPrices(
                node_fee=current_settings[SettingOption.NODE_REWARD_FEE],
                platform_fee=current_settings[SettingOption.PLATFORM_REWARD_FEE],
            ),
        ),
        aggregation_liveness_period=current_settings[
            SettingOption.AGGREGATION_LIVENESS
        ],
        time_uncertainty_aggregation=current_settings[
            SettingOption.TIME_UNCERTAINTY_AGGREGATION
        ],
        time_uncertainty_platform=current_settings[
            SettingOption.TIME_UNCERTAINTY_PLATFORM
        ],
        iqr_fence_multiplier=current_settings[SettingOption.IQR_MULTIPLIER],
        median_divergency_factor=current_settings[
            SettingOption.MEDIAN_DIVERGENCY_FACTOR
        ],
        utxo_size_safety_buffer=current_settings[SettingOption.UTXO_BUFFER],
        pause_period_started_at=deployed_core_settings.datum.pause_period_started_at,
    )
    oracle_settings.validate_based_on_config(oracle_config)

    new_datum = OracleSettingsVariant(oracle_settings)
    deployed_core_utxo.output.datum = new_datum
    deployed_core_utxo.output.datum_hash = None
    return deployed_core_utxo


async def add_settings_value(
    selected_option: SettingOption,
    deployed_core_settings: Datum,
    current_settings: dict,
    invalid_settings: set,
) -> None:
    try:
        new_value = await get_setting_value(
            selected_option,
            current_settings[selected_option],
            deployed_core_settings,
            current_settings,
        )
        current_settings[selected_option] = new_value
        invalid_settings.discard(
            selected_option
        )  # Clear validation error if value is valid
    except SettingsValidationError as e:
        invalid_settings.add(selected_option)
        print_status("Validation Error", str(e), success=False)


def display_initial_settings_context(
    deployed_core_settings: Datum,
    current_settings: dict,
    invalid_settings: set,
) -> None:
    # Print current settings
    print_header("Current Settings")
    for option in SettingOption:
        if option != SettingOption.DONE:
            is_valid = option not in invalid_settings
            print_status(option.label, str(current_settings[option]), success=is_valid)

    # Show validation errors if any exist
    if invalid_settings:
        print_header("Validation Errors")
        for option in invalid_settings:
            try:
                validate_setting(
                    option,
                    current_settings[option],
                    current_settings,
                    deployed_core_settings,
                )
            except SettingsValidationError as e:
                print_status(option.label, str(e), success=False)

    print_information(
        "Note: Only the options presented here can be changed with this transaction"
    )

    # Display menu
    print_header("Available Options")
    for option in SettingOption:
        click.echo(f"{option.id}. {option.label}")


def validate_setting(  # noqa: C901
    option: SettingOption,
    value: int,
    current_settings: dict,
    deployed_settings: Any,
) -> None:
    """Validate a setting value."""
    if value <= 0 and option in [
        SettingOption.TIME_UNCERTAINTY_AGGREGATION,
        SettingOption.THRESHOLD,
    ]:
        raise SettingsValidationError(
            "Time uncertainty for odv-aggregation and Node signature count must be positive"
        )

    if option == SettingOption.UTXO_BUFFER and value <= 0:
        raise SettingsValidationError("UTxO ada buffer size must be positive")
    if option == SettingOption.IQR_MULTIPLIER and value <= 100:
        raise SettingsValidationError("IQR fence multiplier must be greater than 100")
    if option == SettingOption.MEDIAN_DIVERGENCY_FACTOR and value < 1:
        raise SettingsValidationError(
            "Median divergency factor must be greater or equal to 1"
        )

    if option == SettingOption.THRESHOLD and value > len(deployed_settings.datum.nodes):
        raise SettingsValidationError(
            f"Threshold cannot be greater than number of deployed parties ({len(deployed_settings.datum.nodes)})"
        )

    if option == SettingOption.TIME_UNCERTAINTY_PLATFORM:
        time_uncertainty_agg = current_settings[
            SettingOption.TIME_UNCERTAINTY_AGGREGATION
        ]
        if value <= time_uncertainty_agg:
            raise SettingsValidationError(
                f"Time uncertainty for platform actions ({value}) must be greater than time uncertainty for odv-aggregation ({time_uncertainty_agg})"
            )

    if option == SettingOption.AGGREGATION_LIVENESS:
        time_uncertainty_platform = current_settings[
            SettingOption.TIME_UNCERTAINTY_PLATFORM
        ]
        if value <= time_uncertainty_platform:
            raise SettingsValidationError(
                f"Aggregation liveness ({value}) must be greater than time uncertainty for platform actions ({time_uncertainty_platform})"
            )

    if option == SettingOption.NODE_REWARD_FEE and value < 0:
        raise SettingsValidationError("Must not have negative node reward price")

    if option == SettingOption.PLATFORM_REWARD_FEE and value < 0:
        raise SettingsValidationError("Must not have negative platform reward price")


def choose_fee_rate_nft(initial_fee_rate_nft: FeeRateNFT) -> FeeRateNFT | None:
    """
    Choose new fee rate NFT interactively.
    Returns None if rate NFT not changed.
    """
    print_current_fee_rate_nft(initial_fee_rate_nft)

    if print_confirmation_message_prompt("Do you want to change the fee rate NFT?"):
        if initial_fee_rate_nft != NoDatum():
            if print_confirmation_message_prompt(
                "Do you want to set the fee rate NFT to none?"
            ):
                current_fee_rate_nft = NoDatum()
                print_current_fee_rate_nft(current_fee_rate_nft)
                return current_fee_rate_nft

        while True:
            new_policy_id = click.prompt(
                click.style(
                    "Enter new value for policy id in hex format",
                    fg=CliColor.WARNING,
                    bold=True,
                ),
                type=str,
            )
            try:
                new_policy_id = ScriptHash.from_primitive(new_policy_id)
            except (ValueError, AssertionError, TypeError) as err:
                print_status(
                    "Policy Id should be a valid script hash (28 bytes) in hex format",
                    str(err),
                    success=False,
                )
                continue
            break

        while True:
            new_token_name = click.prompt(
                click.style(
                    "Enter new value for token name", fg=CliColor.WARNING, bold=True
                ),
                type=str,
            )
            try:
                new_token_name = AssetName.from_primitive(
                    bytes(new_token_name, "utf-8")
                )
            except (ValueError, AssertionError, TypeError) as err:
                print_status(
                    "Token name should be a valid utf-8 string (max 32 bytes)",
                    str(err),
                    success=False,
                )
                continue
            break

        current_fee_rate_nft = SomeAsset(
            Asset(policy_id=new_policy_id.payload, name=new_token_name.payload)
        )
        print_current_fee_rate_nft(current_fee_rate_nft)
        return current_fee_rate_nft


def print_current_fee_rate_nft(current_fee_rate_nft: FeeRateNFT) -> None:
    print_header("Current Fee Rate NFT")
    if current_fee_rate_nft == NoDatum():
        print_status("Fee Rate NFT", "none")
    else:
        print_status(
            "Fee Rate NFT policy id", current_fee_rate_nft.asset.policy_id.hex()
        )
        print_status("Fee Rate NFT name", str(current_fee_rate_nft.asset.name))

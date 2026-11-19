"""Add Nodes transaction builder."""

import logging
from typing import Any

import click
from pycardano import (
    Address,
    ExtendedSigningKey,
    IndefiniteList,
    NativeScript,
    PaymentSigningKey,
    Redeemer,
    UTxO,
    VerificationKeyHash,
)
from tabulate import tabulate

from charli3_offchain_core.cli.config.formatting import (
    CliColor,
    print_confirmation_message_prompt,
    print_header,
    print_information,
    print_title,
)
from charli3_offchain_core.cli.config.nodes import NodesConfig
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.oracle_datums import (
    Nodes,
    OracleSettingsDatum,
    OracleSettingsVariant,
)
from charli3_offchain_core.models.oracle_redeemers import (
    AddNodes,
    ManageSettings,
)
from charli3_offchain_core.oracle.exceptions import (
    AddNodesCancelled,
    AddNodesValidationError,
)
from charli3_offchain_core.oracle.utils.common import get_reference_script_utxo
from charli3_offchain_core.oracle.utils.state_checks import (
    get_oracle_settings_by_policy_id,
)

from .base import BaseBuilder, GovernanceTxResult

logger = logging.getLogger(__name__)


class AddNodesBuilder(BaseBuilder):
    REDEEMER = Redeemer(ManageSettings(redeemer=AddNodes()))
    FEE_BUFFER = 10_000

    async def build_tx(
        self,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        policy_hash: Any,
        script_address: Address,
        utxos: list[UTxO],
        ref_script_config: ReferenceScriptConfig,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        new_nodes_config: NodesConfig,
        required_signers: list[VerificationKeyHash] | None = None,
        test_mode: bool = False,
    ) -> GovernanceTxResult:
        """Build the update transaction."""
        try:
            in_core_datum, in_core_utxo = get_oracle_settings_by_policy_id(
                utxos, policy_hash
            )

            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                ref_script_config,
                script_address,
            )

            if not script_utxo:
                raise ValueError("Reference script UTxO not found")

            try:

                out_core_utxo = modified_core_utxo(
                    in_core_utxo,
                    in_core_datum,
                    new_nodes_config,
                )
                try:
                    confirm_node_updates(
                        in_core_datum, out_core_utxo.output.datum.datum, test_mode
                    )
                except AddNodesValidationError as e:
                    error_msg = f"Failed to validate add nodes rules: {e}"
                    logger.error(error_msg)
                    return GovernanceTxResult(reason=error_msg)

                except AddNodesCancelled as e:
                    logger.info(f"Node update cancelled: {e}")
                    return GovernanceTxResult()

                tx = await self.tx_manager.build_script_tx(
                    script_inputs=[
                        (in_core_utxo, self.REDEEMER, script_utxo),
                        (platform_utxo, None, platform_script),
                    ],
                    script_outputs=[
                        out_core_utxo.output,
                        platform_utxo.output,
                    ],
                    fee_buffer=self.FEE_BUFFER,
                    change_address=change_address,
                    signing_key=signing_key,
                    required_signers=required_signers,
                )
                return GovernanceTxResult(
                    transaction=tx, settings_utxo=out_core_utxo.output
                )
            except (AddNodesCancelled, click.Abort):
                logger.info("Operation cancelled")
                return GovernanceTxResult()

        except Exception as e:
            error_msg = f"Unexpected error building add nodes transaction: {e}"
            logger.error(error_msg)
            raise


def modified_core_utxo(
    in_core_utxo: UTxO,
    in_core_datum: OracleSettingsDatum,
    new_nodes_config: NodesConfig,
) -> UTxO:

    # Merge new nodes with existing nodes
    existing_vkhs = set(in_core_datum.nodes)
    new_vkhs = set(new_nodes_config.nodes)
    merged_vkhs = sorted(existing_vkhs | new_vkhs, key=lambda x: x.payload)

    new_datum = OracleSettingsDatum(
        nodes=Nodes(node_map=IndefiniteList(merged_vkhs)),
        required_node_signatures_count=new_nodes_config.required_signatures,
        fee_info=in_core_datum.fee_info,
        aggregation_liveness_period=in_core_datum.aggregation_liveness_period,
        time_uncertainty_aggregation=in_core_datum.time_uncertainty_aggregation,
        time_uncertainty_platform=in_core_datum.time_uncertainty_platform,
        iqr_fence_multiplier=in_core_datum.iqr_fence_multiplier,
        median_divergency_factor=in_core_datum.median_divergency_factor,
        utxo_size_safety_buffer=in_core_datum.utxo_size_safety_buffer,
        pause_period_started_at=in_core_datum.pause_period_started_at,
    )

    in_core_utxo.output.datum = OracleSettingsVariant(new_datum)
    in_core_utxo.output.datum_hash = None
    return in_core_utxo


def print_nodes_table(
    node_map: list[VerificationKeyHash],
    success: bool = True,
    is_current: bool = True,
) -> None:
    """Print nodes in a formatted table with improved headers."""
    color = CliColor.SUCCESS if success else CliColor.ERROR

    title = "CURRENT NODES" if is_current else "NEW NODES TO BE ADDED"
    # header_length = 120
    # header = f" {title} ".center(header_length, "=")
    print_title(title)

    headers = ["Node #", "Feed Verification Key Hash"]
    table_data = [[f"{i}", feed_vkh] for i, feed_vkh in enumerate(node_map, 1)]

    # click.secho(header, fg=color)
    table = tabulate(
        table_data,
        headers=headers,
        tablefmt="rst",
        stralign="center",
        numalign="center",
    )
    click.secho(table, fg=color)


def print_required_signatories(count: int, is_current: bool = True) -> None:
    """Print required signatories information with improved formatting."""
    status = "Current" if is_current else "New"
    message = f"{status} Required Signatures: {count}"
    click.secho(f"\n{message}", fg=CliColor.NEUTRAL, bold=True)


def print_validation_rules(
    new_node_count: int,
    new_signatures_count: int,
    has_new_nodes: bool,
    has_deleted_nodes: bool,
) -> bool:
    """Print validation rules and their current status."""
    rules = [
        {
            "rule": "Must not break multisig requirements",
            "status": new_signatures_count > 0
            and new_signatures_count <= new_node_count,
            "details": (
                f"Required signatures ({new_signatures_count}) must be greater than 0 "
                f"and not exceed total nodes ({new_node_count})"
            ),
        },
        {
            "rule": "Must not delete existing nodes",
            "status": not has_deleted_nodes,
            "details": "No existing nodes can be removed in this operation",
        },
        {
            "rule": "Must add at least one new node",
            "status": has_new_nodes,
            "details": "At least one new node must be added",
        },
    ]

    all_rules_pass = True

    print_header("Validation Rules")
    for rule in rules:
        status_color = CliColor.SUCCESS if rule["status"] else CliColor.ERROR
        status_symbol = "✓" if rule["status"] else "✗"
        click.secho(f"{status_symbol} {rule['rule']}", fg=status_color)
        print_information(f"   {rule['details']}")

        all_rules_pass = all_rules_pass and rule["status"]

    return all_rules_pass


def show_nodes_update_info(
    in_core_datum: OracleSettingsDatum,
    out_core_datum: OracleSettingsDatum,
) -> bool:
    """
    Displays information about the changes that will be made to the nodes.

    Returns:
        bool: True if changes are valid and should proceed, False otherwise
    """
    print_current_state(in_core_datum)

    new_nodes = get_new_nodes(in_core_datum, out_core_datum)
    deleted_nodes = get_deleted_nodes(in_core_datum, out_core_datum)

    current_signatures = in_core_datum.required_node_signatures_count
    new_signatures_count = out_core_datum.required_node_signatures_count
    signatures_changed = current_signatures != new_signatures_count

    # Handle cases where there are no actual changes
    if not (new_nodes or signatures_changed):
        click.secho("\nNo changes detected", fg=CliColor.NEUTRAL, bold=True)
        click.secho("\n")
        return False

    # Display changes
    if new_nodes:
        click.secho("\n", nl=True)
        print_nodes_table(new_nodes, is_current=False)

    if signatures_changed:
        print_required_signatories(new_signatures_count, is_current=False)
        display_signature_change(current_signatures, new_signatures_count)

    # Validate and return result
    return print_validation_rules(
        new_node_count=len(out_core_datum.nodes),
        new_signatures_count=new_signatures_count,
        has_new_nodes=bool(new_nodes),
        has_deleted_nodes=bool(deleted_nodes),
    )


def print_current_state(datum: OracleSettingsDatum) -> None:
    """Display current nodes and signature requirements."""
    print_nodes_table(datum.nodes, is_current=True)
    print_required_signatories(datum.required_node_signatures_count, is_current=True)


def get_deleted_nodes(
    in_datum: OracleSettingsDatum, out_datum: OracleSettingsDatum
) -> list:
    """Calculate nodes that will be deleted."""
    return [feed_vkh for feed_vkh in in_datum.nodes if feed_vkh not in out_datum.nodes]


def get_new_nodes(
    in_datum: OracleSettingsDatum, out_datum: OracleSettingsDatum
) -> list[VerificationKeyHash]:
    """Calculate new nodes to be added."""
    return [feed_vkh for feed_vkh in out_datum.nodes if feed_vkh not in in_datum.nodes]


def display_signature_change(current: int, new: int) -> None:
    """Display signature requirement changes."""
    click.secho(
        f"\nSignature requirement will change from {current} to {new}",
        fg=CliColor.WARNING if new < current else CliColor.SUCCESS,
        bold=True,
    )


def confirm_node_updates(
    in_core_datum: OracleSettingsDatum,
    out_core_datum: OracleSettingsDatum,
    test_mode: bool = False,
) -> bool:
    """
    Validate and confirm node updates with the user.

    Args:
        in_core_datum: Current oracle settings
        out_core_datum: Proposed oracle settings

    Returns:
        bool: True if changes are valid and confirmed, False otherwise

    Raises:
        UpdateCancelled: If the user cancels the update or validation fails
    """
    # Validate and display changes
    changes_valid = show_nodes_update_info(in_core_datum, out_core_datum)
    if not changes_valid:
        logger.warning("Validation failed for node updates")
        raise AddNodesValidationError("Adding nodes validation failed")

    # Get user confirmation
    if not test_mode and not print_confirmation_message_prompt(
        "Do you want to continue with the detected changes?"
    ):
        logger.info("User cancelled node update")
        raise AddNodesCancelled("Update cancelled by user")

    return True

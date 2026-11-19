"""Del Nodes transaction builder."""

import logging
from copy import deepcopy
from dataclasses import dataclass, replace

import click
from pycardano import (
    Address,
    ExtendedSigningKey,
    IndefiniteList,
    NativeScript,
    PaymentSigningKey,
    Redeemer,
    ScriptHash,
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
    NoDatum,
    Nodes,
    OracleSettingsDatum,
    OracleSettingsVariant,
    SomeAsset,
)
from charli3_offchain_core.models.oracle_redeemers import (
    DelNodes,
    ManageSettings,
)
from charli3_offchain_core.oracle.exceptions import (
    RemoveNodesCancelled,
    RemoveNodesValidationError,
    RemovingNodesError,
)
from charli3_offchain_core.oracle.utils.common import (
    get_reference_script_utxo,
)
from charli3_offchain_core.oracle.utils.state_checks import (
    get_oracle_settings_by_policy_id,
)

from .base import BaseBuilder, GovernanceTxResult

logger = logging.getLogger(__name__)


@dataclass
class ValidityWindow:
    """Represents the validity window for a transaction."""

    start_slot: int | None = None
    end_slot: int | None = None
    current_time: int | None = None


class DelNodesBuilder(BaseBuilder):
    REDEEMER = Redeemer(ManageSettings(redeemer=DelNodes()))
    FEE_BUFFER = 10_000

    async def build_tx(
        self,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        policy_hash: ScriptHash,
        script_address: Address,
        contract_utxos: list[UTxO],
        ref_script_config: ReferenceScriptConfig,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        new_nodes_config: NodesConfig,
        reward_token: NoDatum | SomeAsset,
        required_signers: list[VerificationKeyHash] | None = None,
        test_mode: bool = False,
    ) -> GovernanceTxResult:
        """Builds a governance transaction for updating node configurations.

        This method constructs a transaction that updates the node configuration on the platform.
        It handles the creation of outputs, validation of inputs, and proper signing of the transaction.

        Args:
            platform_utxo: UTxO containing the platform's assets and datum
            platform_script: Native script that controls the platform's spending conditions
            policy_hash: Hash of the policy ID used for minting/burning tokens
            contract_utxos: List of UTxOs associated with the contract
            change_address: Address where any remaining assets will be sent
            signing_key: Key used to sign the transaction (can be payment or extended)
            new_nodes_config: New configuration for the nodes being updated
            reward_token: Token used for rewards, can be NoDatum or a specific asset
            required_signers: Optional list of additional verification key hashes required to sign

        Returns:
            GovernanceTxResult: Object containing the built transaction and related metadata

        Raises:
            ValueError: If any required parameters are invalid or missing
            RemoveNodesValidationError: If the new configuration fails validation rules
            RemoveNodesCancelled: If the transaction building process is cancelled
            TransactionBuildError: If there's an error during transaction construction

        Note:
            The transaction requires proper authorization and will fail if the signing key
            doesn't have the necessary permissions.
        """
        try:
            # Input Core Settings UTxO
            in_core_datum, in_core_utxo = get_oracle_settings_by_policy_id(
                contract_utxos, policy_hash
            )

            # Contract Script
            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                ref_script_config,
                script_address,
            )

            # Nodes to remove
            nodes_to_remove = {node for node in new_nodes_config.nodes}  # noqa

            # Modified Core Settings: removed `Nodes`
            out_core_utxo = modified_core_utxo(
                in_core_utxo,
                in_core_datum,
                nodes_to_remove,
                new_nodes_config.required_signatures,
            )

            # Confirmation of changes
            confirm_node_updates(
                in_core_datum,
                out_core_utxo.output.datum.datum,
                nodes_to_remove,
                reward_token,
                self.MIN_UTXO_VALUE,
                test_mode,
            )

            # Build the transaction
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

        except RemoveNodesValidationError as e:
            error_msg = f"Failed to validate Delete Nodes rules: {e}"
            logger.error(error_msg)
            return GovernanceTxResult(reason=error_msg)

        except RemovingNodesError as e:
            error_msg = (
                f"Provided inputs do not account for payment rewards processing: {e}"
            )
            logger.info(error_msg)
            return GovernanceTxResult(reason=error_msg)

        except (RemoveNodesCancelled, click.Abort):
            logger.info("Operation cancelled")
            return GovernanceTxResult()

        except Exception as e:
            error_msg = f"Unexpected error building delete nodes transaction: {e}"
            logger.error(error_msg)
            raise e


def modified_core_utxo(
    core_utxo: UTxO,
    core_datum: OracleSettingsDatum,
    nodes_to_remove: set[VerificationKeyHash],
    required_signatures: int,
) -> UTxO:
    modified_utxo = deepcopy(core_utxo)

    filtered_nodes = IndefiniteList(
        [vkh for vkh in core_datum.nodes.node_map if vkh not in nodes_to_remove]
    )

    new_datum = replace(
        core_datum,
        nodes=Nodes(node_map=filtered_nodes),
        required_node_signatures_count=required_signatures,
    )

    modified_utxo = replace(
        modified_utxo,
        output=replace(
            modified_utxo.output,
            datum=OracleSettingsVariant(new_datum),
            datum_hash=None,
        ),
    )

    return modified_utxo


def print_nodes_table(
    nodes: list[VerificationKeyHash],
    min_utxo_value: int,
    success: bool = True,
    is_ada: bool = True,
    is_current: bool = True,
) -> None:
    """Print nodes in a formatted table with improved headers."""
    color = CliColor.SUCCESS if success else CliColor.ERROR

    title = "NODES TO REMOVE" if is_current else "NODES REMOVED VS REMAINING"

    print_title(title)

    headers = [
        "Node #",
        "Feed Verification Key Hash",
    ]
    table_data = [
        [
            f"{i}",
            feed_vkh,
        ]
        for i, feed_vkh in enumerate(nodes, 1)
    ]

    # if is_ada:
    #     for row in table_data:
    #         reward = row[3]  # Get the reward amount
    #         if reward > 0 and reward < min_utxo_value:
    #             row[3] = (
    #                 f"Original: {reward:_} ₳, "
    #                 f"Final (Min UTxO): {min_utxo_value:r_} ₳"
    #             )
    #         else:
    #             row[3] = f"{reward:_} ₳ "

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
    has_deleted_nodes: bool,
    has_added_nodes: bool,
    has_all_nodes: bool,
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
            "rule": "Must not add nodes",
            "status": not has_added_nodes,
            "details": "No existing nodes can be removed in this operation",
        },
        {
            "rule": "Must remove at least one node",
            "status": has_deleted_nodes,
            "details": "At least one new node must be added",
        },
        {
            "rule": "All removed nodes must exist",
            "status": has_all_nodes,
            "details": "All configured nodes must exist in the current configuration",
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
    config_nodes_to_remove: set[VerificationKeyHash],
    reward_token: NoDatum | SomeAsset,
    min_utxo_value: int,
    test_mode: bool = False,
) -> bool:
    """
    Displays information about the changes that will be made to the nodes.

    Returns:
        bool: True if changes are valid and should proceed, False otherwise
    """

    nodes_to_remove = get_remove_nodes(in_core_datum, out_core_datum)
    added_nodes = get_added_nodes(in_core_datum, out_core_datum)

    current_signatures = in_core_datum.required_node_signatures_count
    new_signatures_count = out_core_datum.required_node_signatures_count
    signatures_changed = current_signatures != new_signatures_count

    # Handle cases where there are no actual changes
    if not (nodes_to_remove or signatures_changed):
        click.secho("\nNo changes detected", fg=CliColor.NEUTRAL, bold=True)
        click.secho("\n")
        return False

    # Display changes
    if nodes_to_remove and not test_mode:
        click.secho("\n", nl=True)
        print_nodes_table(
            nodes_to_remove,
            min_utxo_value,
            is_current=True,
            is_ada=isinstance(reward_token, NoDatum),
        )

    if signatures_changed:
        print_required_signatories(new_signatures_count, is_current=False)
        display_signature_change(current_signatures, new_signatures_count)

    has_valid_nodes = all_valid_nodes(config_nodes_to_remove, in_core_datum.nodes)

    # Validate and return result
    return print_validation_rules(
        new_node_count=len(out_core_datum.nodes.node_map),
        new_signatures_count=new_signatures_count,
        has_deleted_nodes=bool(nodes_to_remove),
        has_added_nodes=bool(added_nodes),
        has_all_nodes=has_valid_nodes,
    )


def get_added_nodes(
    in_datum: OracleSettingsDatum, out_datum: OracleSettingsDatum
) -> list[VerificationKeyHash]:
    """Calculate nodes that have been added.

    Returns a feed VKH list for nodes present in out_datum
    but not in in_datum (i.e., newly added nodes).
    """
    added_feed_vkhs = set(out_datum.nodes.node_map) - set(in_datum.nodes.node_map)
    return list(added_feed_vkhs)


def get_remove_nodes(
    in_datum: OracleSettingsDatum, out_datum: OracleSettingsDatum
) -> list[VerificationKeyHash]:
    """Calculate nodes that will be removed.

    Returns a feed VKH list for nodes present in in_datum
    but not in out_datum (i.e., nodes being removed).
    """
    removed_feed_vkhs = set(in_datum.nodes.node_map) - set(out_datum.nodes.node_map)
    return list(removed_feed_vkhs)


def all_valid_nodes(
    nodes_to_remove: set[VerificationKeyHash],
    in_nodes: Nodes,
) -> bool:
    """Verify that all nodes marked for removal exist in the current contract"""
    return all(node in in_nodes.node_map for node in nodes_to_remove)


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
    nodes_to_remove: set[VerificationKeyHash],
    reward_token: NoDatum | SomeAsset,
    min_utxo_value: int,
    test_mode: bool = False,
) -> bool:
    """
    Validate and confirm node updates with the user.

    Args:
        in_core_datum: Current oracle settings
        out_core_datum: Proposed oracle settings
        nodes_to_remove: Nodes to be removed, as specified by the user
    Returns:
        bool: True if changes are valid and confirmed, False otherwise

    Raises:
        UpdateCancelled: If the user cancels the update or validation fails
    """
    # Validate and display changes
    changes_valid = show_nodes_update_info(
        in_core_datum,
        out_core_datum,
        nodes_to_remove,
        reward_token,
        min_utxo_value,
        test_mode,
    )
    if not changes_valid:
        logger.warning("Validation failed for delete nodes")
        raise RemoveNodesValidationError("Removing nodes validation failed")

    # Get user confirmation
    if not test_mode and not print_confirmation_message_prompt(
        "Do you want to continue with the detected changes?"
    ):
        logger.info("User cancelled operation: Delete Nodes")
        raise RemoveNodesCancelled("Update cancelled by user")

    return True

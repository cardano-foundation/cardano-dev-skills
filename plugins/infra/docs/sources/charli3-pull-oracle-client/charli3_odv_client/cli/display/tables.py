"""Table formatting utilities for CLI output."""

from rich.table import Table
from rich.console import Console
from typing import Dict

from charli3_odv_client.models.message import SignedOracleNodeMessage
from charli3_odv_client.config import ODVClientConfig

console = Console()


def format_feed_table(node_messages: Dict[str, SignedOracleNodeMessage]) -> Table:
    """Format node feed responses as a table."""
    table = Table(show_header=True, header_style="bold cyan", box=None)
    table.add_column("Node Public Key", style="cyan")
    table.add_column("Feed Value", style="green", justify="right")
    table.add_column("Timestamp", style="blue")

    for pub_key, message in node_messages.items():
        feed_value = message.message.feed / 1_000_000
        table.add_row(
            pub_key,
            f"{feed_value:.6f}",
            str(message.message.timestamp),
        )

    return table


def format_config_table(config: ODVClientConfig) -> Table:
    """Format configuration as a table."""
    table = Table(show_header=True, header_style="bold cyan", box=None)
    table.add_column("Setting", style="cyan", width=20)
    table.add_column("Value", style="white")
    table.add_column("Status", style="bold green", width=10)

    table.add_row("Network", config.network.network, "Valid")
    table.add_row("Oracle Address", config.oracle_address, "Valid")
    table.add_row("Policy ID", config.policy_id, "Valid")
    table.add_row("Validity Length", f"{config.odv_validity_length}ms", "Valid")
    table.add_row("Nodes Count", str(len(config.nodes)), "Valid")

    if config.tokens:
        if config.tokens.reward_token_policy:
            table.add_row(
                "Reward Token Policy", config.tokens.reward_token_policy, "Valid"
            )
        if config.tokens.reward_token_name:
            table.add_row("Reward Token Name", config.tokens.reward_token_name, "Valid")

    return table


def format_transaction_summary_table(
    transaction_id: str,
    median_value: int,
    node_count: int,
    signature_count: int,
    fee_amount: int,
) -> Table:
    """Format transaction summary as a table."""
    table = Table(show_header=True, header_style="bold green", box=None)
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="white")

    table.add_row("Transaction ID", transaction_id)
    table.add_row("Median Value", f"{median_value / 1_000_000:.6f}")
    table.add_row("Node Responses", str(node_count))
    table.add_row("Signatures Collected", str(signature_count))
    table.add_row("Fee Paid", f"{fee_amount / 1_000_000:.6f} ADA")

    return table


def format_reward_distribution_table(reward_distribution: Dict[str, int]) -> Table:
    """Format reward distribution as a table."""
    table = Table(show_header=True, header_style="bold cyan", box=None)
    table.add_column("Node ID", style="cyan")
    table.add_column("Reward Amount", style="green", justify="right")

    for node_id, reward in reward_distribution.items():
        table.add_row(str(node_id), f"{reward / 1_000_000:.6f} ADA")

    return table

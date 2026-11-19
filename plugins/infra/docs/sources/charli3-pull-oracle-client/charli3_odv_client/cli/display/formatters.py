"""Display formatters and output utilities for CLI commands."""

from pathlib import Path
from typing import Dict, Optional, Any

from rich.console import Console
from rich.table import Table
from rich.panel import Panel

from charli3_odv_client.models.message import SignedOracleNodeMessage
from charli3_odv_client.config import ODVClientConfig
from charli3_odv_client.exceptions import (
    ValidationError,
    NetworkError,
    OracleTransactionError,
    StateValidationError,
)

console = Console()


class CLIDisplay:
    """Centralized display utilities for CLI operations."""

    @staticmethod
    def print_error(message: str, exception: Optional[Exception] = None) -> None:
        """Print error message with optional exception details."""
        console.print(f"[bold red]ERROR:[/bold red] {message}")

        if exception:
            CLIDisplay._print_exception_details(exception)

    @staticmethod
    def print_success(message: str) -> None:
        """Print success message."""
        console.print(f"[bold green]SUCCESS:[/bold green] {message}")

    @staticmethod
    def print_info(message: str) -> None:
        """Print info message."""
        console.print(f"[cyan]INFO:[/cyan] {message}")

    @staticmethod
    def print_warning(message: str) -> None:
        """Print warning message."""
        console.print(f"[yellow]WARNING:[/yellow] {message}")

    @staticmethod
    def _print_exception_details(exception: Exception) -> None:
        """Print detailed exception information based on exception type."""
        if isinstance(exception, StateValidationError):
            CLIDisplay._print_state_validation_error(exception)
        elif isinstance(exception, OracleTransactionError):
            CLIDisplay._print_transaction_error(exception)
        elif isinstance(exception, NetworkError):
            CLIDisplay._print_network_error(exception)
        elif isinstance(exception, ValidationError):
            CLIDisplay._print_validation_error(exception)
        else:
            CLIDisplay._print_generic_error(exception)

    @staticmethod
    def _print_state_validation_error(error: StateValidationError) -> None:
        """Print detailed state validation error information."""
        console.print()
        console.print("[bold yellow]State Validation Issue:[/bold yellow]")

        if "No empty transport UTxO found" in str(error):
            console.print(
                "    [red]•[/red] All oracle transport UTxOs are currently in use"
            )
            console.print("    [cyan]Possible solutions:[/cyan]")
            console.print("      - Wait for current aggregations to complete")
            console.print("      - Check if oracle needs reward consensus processing")
            console.print("      - Verify oracle is not paused or in closing state")
        elif "expired" in str(error).lower():
            console.print("    [red]•[/red] Oracle feed data has expired")
            console.print("    [cyan]Possible solutions:[/cyan]")
            console.print("      - Collect fresh feed data from nodes")
            console.print("      - Check oracle liveness period settings")
        else:
            console.print(f"    [red]•[/red] {error}")

    @staticmethod
    def _print_transaction_error(error: OracleTransactionError) -> None:
        """Print detailed transaction error information."""
        console.print()
        console.print("[bold yellow]Transaction Error:[/bold yellow]")
        console.print(f"    [red]•[/red] {error}")

        if "insufficient funds" in str(error).lower():
            console.print("    [cyan]Possible solutions:[/cyan]")
            console.print("      - Check wallet ADA balance")
            console.print("      - Verify reward token balance if required")
        elif "script" in str(error).lower():
            console.print("    [cyan]Possible solutions:[/cyan]")
            console.print("      - Verify oracle script address is correct")
            console.print("      - Check if oracle contract is up to date")

    @staticmethod
    def _print_network_error(error: NetworkError) -> None:
        """Print detailed network error information."""
        console.print()
        console.print("[bold yellow]Network Error:[/bold yellow]")
        console.print(f"    [red]•[/red] {error}")
        console.print("    [cyan]Possible solutions:[/cyan]")
        console.print("      - Check network connectivity")
        console.print("      - Verify API endpoints are accessible")
        console.print("      - Check API credentials and rate limits")

    @staticmethod
    def _print_validation_error(error: ValidationError) -> None:
        """Print detailed validation error information."""
        console.print()
        console.print("[bold yellow]Configuration Error:[/bold yellow]")
        console.print(f"    [red]•[/red] {error}")

    @staticmethod
    def _print_generic_error(error: Exception) -> None:
        """Print generic error information."""
        console.print()
        console.print("[bold yellow]Unexpected Error:[/bold yellow]")
        console.print(f"    [red]•[/red] {type(error).__name__}: {error}")

    @staticmethod
    def print_config_summary(config: ODVClientConfig, verbose: bool = False) -> None:
        """Print configuration summary."""
        CLIDisplay.print_success("Configuration and components initialized")
        if verbose:
            console.print("    Oracle Configuration:", style="bold cyan")
            console.print(f"      Policy ID: {config.policy_id}")
            console.print(f"      Oracle Address: {config.oracle_address}")
            console.print(f"      Target nodes: {len(config.nodes)}")
            console.print()

    @staticmethod
    def print_feed_responses(
        node_messages: Dict[str, SignedOracleNodeMessage], verbose: bool = False
    ) -> None:
        """Print feed response summary."""
        CLIDisplay.print_success(f"Collected {len(node_messages)} feed responses")

        if verbose and node_messages:
            console.print("    Node Feed Responses:", style="bold cyan")
            for pub_key, msg in node_messages.items():
                feed_value = msg.message.feed / 1_000_000
                console.print(f"      {pub_key}: {feed_value:.6f}")
            console.print()

    @staticmethod
    def print_transaction_preview(
        transaction_id: str,
        median_value: int,
        node_count: int,
        signature_count: int,
        output_file: Path,
    ) -> None:
        """Display transaction preview before submission."""
        console.print()
        console.print(
            Panel(
                f"[bold cyan]Transaction Ready for Submission[/bold cyan]\n\n"
                f"[bold]Transaction ID:[/bold]\n{transaction_id}\n\n"
                f"[bold]Oracle Feed Details:[/bold]\n"
                f"  • Median Value: [green]{median_value / 1_000_000:.6f}[/green]\n"
                f"  • Node Responses: [blue]{node_count}[/blue]\n"
                f"  • Signatures Collected: [blue]{signature_count}[/blue]\n\n"
                f"[bold]Transaction Details:[/bold]\n"
                f"  • Saved to: [cyan]{output_file}[/cyan]\n\n"
                f"[bold yellow]⚠️  This action will submit the transaction to the blockchain[/bold yellow]",
                title="Transaction Preview",
                border_style="cyan",
                padding=(1, 2),
            )
        )

    @staticmethod
    def print_manual_submission_instructions(output_file: Path) -> None:
        """Display instructions for manual transaction submission."""
        console.print()
        console.print(
            Panel(
                f"[bold green]Transaction Prepared Successfully[/bold green]\n\n"
                f"Your transaction has been saved to:\n"
                f"[cyan]{output_file}[/cyan]\n\n"
                f"[bold]Manual Submission Options:[/bold]\n\n"
                f"1. [bold]Cardano CLI:[/bold]\n"
                f"   cardano-cli transaction submit --tx-file {output_file}\n\n"
                f"2. [bold]Re-run with auto-submit:[/bold]\n"
                f"   Add --auto-submit flag to skip confirmation\n\n"
                f"3. [bold]Submit via block explorer:[/bold]\n"
                f"   Copy CBOR content to submit via web interface",
                title="Manual Submission",
                border_style="green",
                padding=(1, 2),
            )
        )

    @staticmethod
    def print_help_summary() -> None:
        """Display helpful command summary."""
        console.print()
        console.print("[bold blue]Common Usage Patterns:[/bold blue]")
        console.print()
        console.print("[cyan]1. Full aggregation with confirmation:[/cyan]")
        console.print("   charli3-odv aggregate --config config.yaml")
        console.print()
        console.print("[cyan]2. Auto-submit without confirmation:[/cyan]")
        console.print("   charli3-odv aggregate --config config.yaml --auto-submit")
        console.print()
        console.print("[cyan]3. Save transaction only:[/cyan]")
        console.print(
            "   charli3-odv aggregate --config config.yaml --output my_tx.cbor"
        )
        console.print()
        console.print("[cyan]4. Use saved feed data:[/cyan]")
        console.print(
            "   charli3-odv aggregate --config config.yaml --feed-data saved_feeds.json"
        )
        console.print()

    @staticmethod
    def print_transaction_summary(
        transaction_id: str, median_value: int, verbose: bool = False, **kwargs
    ) -> None:
        """Print transaction construction summary."""
        CLIDisplay.print_success("Transaction constructed")
        console.print(f"    Transaction ID: {transaction_id}")
        console.print(f"    Median value: {median_value / 1_000_000:.6f}")

        if verbose:
            console.print("    Transaction Details:", style="bold cyan")
            for key, value in kwargs.items():
                console.print(f"      {key.replace('_', ' ').title()}: {value}")
            console.print()

    @staticmethod
    def print_signatures_summary(
        signatures: Dict[str, Any], verbose: bool = False
    ) -> None:
        """Print signature collection summary."""
        CLIDisplay.print_success(f"Collected {len(signatures)} signatures")

        if verbose:
            console.print("    Node Signatures:", style="bold cyan")
            for pub_key in signatures.keys():
                console.print(f"      {pub_key}")
            console.print()

    @staticmethod
    def print_final_summary(
        transaction_id: str,
        median_value: int,
        node_count: int,
        signature_count: int,
    ) -> None:
        """Print final aggregation summary."""
        console.print(
            Panel(
                f"[bold green]ODV Aggregation Complete[/bold green]\n\n"
                f"Transaction ID:\n{transaction_id}\n\n"
                f"Median Value: {median_value / 1_000_000:.6f}\n"
                f"Node Responses: {node_count}\n"
                f"Signatures: {signature_count}",
                title="Aggregation Summary",
                border_style="green",
                padding=(1, 2),
            )
        )

    @staticmethod
    def print_feed_results(
        node_messages: Dict[str, SignedOracleNodeMessage],
        aggregate_message: Any,
        verbose: bool = False,
    ) -> None:
        """Display feed collection results."""
        CLIDisplay.print_success("Feed collection complete")
        console.print(f"    Received: {len(node_messages)} responses")
        console.print(f"    Aggregate feeds: {aggregate_message.node_feeds_count}")
        console.print()

        if verbose and node_messages:
            table = Table(show_header=True, header_style="bold cyan", box=None)
            table.add_column("Node Public Key", style="cyan")
            table.add_column("Feed Value", style="green", justify="right")

            for pub_key, message in node_messages.items():
                feed_value = message.message.feed / 1_000_000
                table.add_row(
                    pub_key,
                    f"{feed_value:.6f}",
                    str(message.message.timestamp),
                )

            console.print(table)
            console.print()

            from charli3_odv_client.utils.math import median

            feeds = [msg.message.feed for msg in node_messages.values()]
            calculated_median = median(feeds, len(feeds))
            console.print(
                f"Calculated median: {calculated_median / 1_000_000:.6f}",
                style="bold green",
            )

    @staticmethod
    def print_config_validation(config: ODVClientConfig) -> None:
        """Print configuration validation results."""
        console.print("Configuration Validation", style="bold blue")
        console.print()

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
                table.add_row(
                    "Reward Token Name", config.tokens.reward_token_name, "Valid"
                )

        console.print(table)
        console.print()
        CLIDisplay.print_success("Configuration is valid")

        # Show node details
        if len(config.nodes) > 0:
            console.print("Node Endpoints:", style="bold cyan")
            for i, node in enumerate(config.nodes, 1):
                console.print(f"    {i}. {node.root_url}")

    @staticmethod
    def print_version_info() -> None:
        """Print version information."""
        console.print(
            Panel(
                "[bold blue]ODV Charli3 Client SDK[/bold blue]\n"
                "Version: 0.1.0\n"
                "Oracle Data Verification Client",
                border_style="blue",
                padding=(1, 2),
            )
        )

    @staticmethod
    def save_feed_data(
        node_messages: Dict[str, SignedOracleNodeMessage],
        aggregate_message: Any,
        output_path: Path,
    ) -> None:
        """Save feed data to JSON file."""
        from charli3_odv_client.cli.utils.file_operations import save_feed_data

        save_feed_data(node_messages, aggregate_message, output_path)

    @staticmethod
    def reconstruct_node_messages(data: dict) -> Dict[str, SignedOracleNodeMessage]:
        """Reconstruct node messages from saved JSON data."""

        reconstructed = {}
        for pub_key, msg_data in data.items():
            try:
                reconstructed[pub_key] = SignedOracleNodeMessage.model_validate(
                    msg_data
                )
            except Exception as e:
                CLIDisplay.print_error(
                    f"Failed to reconstruct message for {pub_key}: {e}"
                )
        return reconstructed

    @staticmethod
    def handle_signature_collection_error(
        e: Exception, config: ODVClientConfig, verbose: bool = False
    ) -> None:
        """Handle signature collection errors with detailed information."""
        CLIDisplay.print_error("Signature collection failed", e)

        if verbose:
            console.print("    Possible causes:", style="yellow")
            console.print("      - Oracle nodes not responding")
            console.print("      - Network connectivity issues")
            console.print("      - Invalid transaction format")
            console.print("    Node endpoints:", style="yellow")
            for node in config.nodes:
                console.print(f"      {node.root_url}")

    @staticmethod
    def handle_submission_error(e: Exception, verbose: bool = False) -> None:
        """Handle transaction submission errors."""
        CLIDisplay.print_error("Transaction submission failed", e)

        if verbose:
            console.print_exception()

    @staticmethod
    def create_progress():
        """Create a progress indicator."""
        from charli3_odv_client.cli.display.progress import create_progress

        return create_progress()

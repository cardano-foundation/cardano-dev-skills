"""Main CLI entry point for Charli3 ODV tools."""

import click

from charli3_offchain_core.cli.aggregate_txs.odv_aggregate import odv_aggregate
from charli3_offchain_core.cli.config.utils import setup_logging
from charli3_offchain_core.cli.node_keys.generate_node_keys_command import (
    generate_node_keys_command,
)
from charli3_offchain_core.cli.odv_client.commands import client
from charli3_offchain_core.cli.odv_simulator.commands import simulator
from charli3_offchain_core.cli.oracle import oracle
from charli3_offchain_core.cli.platform import platform
from charli3_offchain_core.cli.reference_script import reference_script


@click.group()
@click.option("-v", "--verbose", is_flag=True, help="Enable verbose logging")
def cli(verbose: bool) -> None:
    """Charli3 Oracle Data Verification (ODV) CLI tools."""
    setup_logging(verbose)


# Add command groups
cli.add_command(oracle)
cli.add_command(client)
cli.add_command(odv_aggregate)
cli.add_command(platform)
cli.add_command(simulator)
cli.add_command(generate_node_keys_command, name="generate-node-keys")
cli.add_command(reference_script)


if __name__ == "__main__":
    cli(_anyio_backend="asyncio", verbose="True")

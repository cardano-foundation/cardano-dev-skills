"""CLI commands for oracle simulation."""

from pathlib import Path

import click

from charli3_offchain_core.cli.aggregate_txs.base import tx_options
from charli3_offchain_core.cli.config.formatting import print_header, print_progress
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.cli.config.utils import async_command
from charli3_offchain_core.cli.odv_simulator.models import SimulationConfig
from charli3_offchain_core.cli.odv_simulator.oracle import OracleSimulator
from charli3_offchain_core.cli.odv_simulator.utils import (
    print_simulation_config,
    print_simulation_results,
    save_simulation_results,
)


@click.group()
def simulator() -> None:
    """Oracle simulator commands."""


@simulator.command()
@tx_options
@click.option(
    "--output",
    type=click.Path(path_type=Path),
    help="Save results to JSON file",
)
@async_command
async def run(
    config: Path,
    output: Path | None,
) -> None:
    """Run complete oracle simulation using configuration file."""

    print_header("ODV Oracle Simulator")
    print_progress("Loading configuration...")
    # Load simulation config
    sim_config = SimulationConfig.from_yaml(config)
    ref_script_config = ReferenceScriptConfig.from_yaml(config)

    # Create simulator
    oracle_simulator = OracleSimulator(sim_config, ref_script_config)

    try:
        # Run simulation
        result = await oracle_simulator.run_simulation()

        # Show configuration and results
        print_simulation_config(sim_config.simulation)

        # Show results
        print_simulation_results(result)

        # Save if requested
        if output:
            click.echo(f"\nSaving results to {output}")
            save_simulation_results(result, output)

    except Exception as e:
        raise click.ClickException(f"Simulation failed: {e}") from e

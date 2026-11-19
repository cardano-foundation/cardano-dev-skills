"""Utilities for oracle simulation."""

import json
import time

import click

from charli3_offchain_core.cli.odv_simulator.models import (
    SimulationResult,
    SimulationSettings,
)


def print_simulation_config(config: "SimulationSettings") -> None:
    """Print simulation configuration.

    Args:
        config: Simulation configuration to display
    """
    click.echo("\nSimulation Configuration")
    click.echo("=======================")
    click.echo(f"Nodes: {config.node_count}")
    click.echo(f"Base Feed: {config.base_feed}")
    click.echo(f"Variance: {config.variance*100}%")
    click.echo(f"Wait Time: {config.wait_time} milliseconds")


def print_simulation_results(result: "SimulationResult") -> None:
    """Pretty print simulation results.

    Args:
        result: Simulation results to display
    """
    click.echo("\nSimulation Results")
    click.echo("=================")

    # Show ODV details
    click.echo("\nODV Transaction:")
    click.echo(f"ID: {result.odv_tx}")

    click.echo("\nNode Feeds:")
    for node_id, feed_data in result.feeds.items():
        click.echo(
            f"Node {node_id}: value={feed_data['feed']}, "
            f"ts={feed_data['timestamp']}"
        )

    # Show rewards
    click.echo("\nReward Distribution:")
    if result.rewards:
        for i, (vkh, amount) in enumerate(result.rewards.items()):
            click.echo(f"Node {i} ({vkh[:16]}...): {amount} lovelace")
    else:
        click.echo("No rewards distributed")


def save_simulation_results(result: "SimulationResult", output_file: str) -> None:
    """Save simulation results to JSON file.

    Args:
        result: Simulation results to save
        output_file: Path to output JSON file
    """
    output = {
        "timestamp": int(time.time() * 1000),
        "odv_transaction": result.odv_tx,
        "nodes": [node.to_dict() for node in result.nodes],
        "feeds": result.feeds,
    }

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2)

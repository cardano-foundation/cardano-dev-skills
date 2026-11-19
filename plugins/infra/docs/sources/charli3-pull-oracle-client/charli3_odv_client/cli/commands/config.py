"""Configuration validation command implementation."""

import sys
from pathlib import Path

import click

from charli3_odv_client.config import ODVClientConfig
from charli3_odv_client.cli.display.formatters import CLIDisplay


@click.command()
@click.option(
    "--config",
    "-c",
    type=click.Path(exists=True, path_type=Path),
    required=True,
    help="Configuration file path",
)
def validate_config(config: Path) -> None:
    """Validate configuration file."""
    try:
        config_obj = ODVClientConfig.from_yaml(config)
        CLIDisplay.print_config_validation(config_obj)

    except Exception as e:
        CLIDisplay.print_error("Configuration validation failed", e)
        sys.exit(1)

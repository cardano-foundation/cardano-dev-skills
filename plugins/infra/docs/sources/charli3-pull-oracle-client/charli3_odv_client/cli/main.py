"""Main CLI entry point for ODV Client SDK."""

import click
from charli3_odv_client.cli.commands.aggregate import aggregate
from charli3_odv_client.cli.commands.feeds import feeds
from charli3_odv_client.cli.commands.config import validate_config
from charli3_odv_client.cli.display.formatters import CLIDisplay


@click.group()
@click.version_option(version="0.1.0", prog_name="charli3")
def main() -> None:
    """Charli3 Oracle Data Verification (ODV) Client SDK."""
    pass


@main.command()
def version() -> None:
    """Show version information."""
    CLIDisplay.print_version_info()


main.add_command(aggregate)
main.add_command(feeds)
main.add_command(validate_config)


if __name__ == "__main__":
    main()

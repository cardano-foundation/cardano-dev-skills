"""CLI command for generating oracle node keys and configurations."""

import logging
from pathlib import Path

import click
import yaml
from pycardano import (
    ExtendedSigningKey,
    HDWallet,
    PaymentVerificationKey,
    VerificationKeyHash,
)

from charli3_offchain_core.cli.config import NodesConfig, async_command

logger = logging.getLogger(__name__)


def generate_node_keys(
    mnemonic: str,
    start_index: int = 0,
    count: int = 1,
) -> list[dict]:
    """Generate node keys from mnemonic.

    Args:
        mnemonic: 24-word mnemonic phrase
        start_index: Starting index for key derivation
        count: Number of nodes to generate

    Returns:
        List of dictionaries containing node keys and VKHs
    """
    # Create HD wallet from mnemonic
    hdwallet = HDWallet.from_mnemonic(mnemonic)
    nodes = []

    for i in range(start_index, start_index + count):
        # Derive feed keys
        feed_hdwallet = hdwallet.derive_from_path(f"m/4343'/1815'/0'/0/{i}")
        feed_signing_key = ExtendedSigningKey.from_hdwallet(feed_hdwallet)
        feed_verification_key = PaymentVerificationKey.from_primitive(
            feed_hdwallet.public_key
        )
        feed_vkh = feed_verification_key.hash()

        # Derive payment keys
        payment_hdwallet = hdwallet.derive_from_path(f"m/1852'/1815'/0'/0/{i}")
        payment_signing_key = ExtendedSigningKey.from_hdwallet(payment_hdwallet)
        payment_verification_key = PaymentVerificationKey.from_primitive(
            payment_hdwallet.public_key
        )
        payment_vkh = payment_verification_key.hash()

        nodes.append(
            {
                "index": i,
                "feed_vkey": feed_verification_key,
                "payment_vkey": payment_verification_key,
                "feed_skey": feed_signing_key,
                "payment_skey": payment_signing_key,
                "feed_vkh": feed_vkh,
                "payment_vkh": payment_vkh,
            }
        )

    return nodes


def save_node_keys(nodes: list[dict], output_dir: Path) -> None:
    """Save node keys to individual files.

    Args:
        nodes: List of node key dictionaries
        output_dir: Directory to save key files
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Add a metadata file with required signatures
    with (output_dir / "required_signatures").open("w") as f:
        f.write(str(len(nodes)))

    for node in nodes:
        index = node["index"]
        node_dir = output_dir / f"node_{index}"
        node_dir.mkdir(exist_ok=True)

        # Save verification keys
        node["feed_vkey"].save(str(node_dir / "feed.vkey"))
        node["payment_vkey"].save(str(node_dir / "payment.vkey"))

        # Save signing keys
        node["feed_skey"].save(str(node_dir / "feed.skey"))
        node["payment_skey"].save(str(node_dir / "payment.skey"))

        # Save VKH values for easy reference
        with (node_dir / "feed.vkh").open("w") as f:
            f.write(node["feed_vkh"].to_primitive().hex())
        with (node_dir / "payment.vkh").open("w") as f:
            f.write(node["payment_vkh"].to_primitive().hex())


def load_nodes_config(keys_dir: Path) -> NodesConfig:
    """Load NodesConfig from key directory structure.

    Args:
        keys_dir: Directory containing node keys

    Returns:
        NodesConfig instance

    Raises:
        ValueError: If directory structure is invalid
    """
    if not keys_dir.is_dir():
        raise ValueError(f"Keys directory not found: {keys_dir}")

    # Read required signatures
    try:
        required_sigs = int((keys_dir / "required_signatures").read_text())
    except (ValueError, FileNotFoundError) as e:
        raise ValueError("Invalid or missing required_signatures file") from e

    # Load node configs
    nodes = []
    for node_dir in sorted(keys_dir.glob("node_*")):
        try:
            feed_hex = (node_dir / "feed.vkh").read_text()
            feed_vkh = VerificationKeyHash(bytes.fromhex(feed_hex))
            nodes.append(feed_vkh)
        except FileNotFoundError as e:
            raise ValueError(f"Missing key files in {node_dir}") from e

    return NodesConfig(
        required_signatures=required_sigs,
        nodes=nodes,
    )


def print_yaml_config(nodes_config: NodesConfig) -> None:
    """Print node configuration in YAML format."""
    config = {
        "nodes": {
            "required_signatures": nodes_config.required_signatures,
            "feed_vkh": [str(node) for node in nodes_config.nodes],
        }
    }

    click.echo(yaml.dump(config, default_flow_style=False, indent=4))


@click.command()
@click.option(
    "--mnemonic",
    prompt="Enter mnemonic phrase",
    help="24-word mnemonic phrase",
    hide_input=True,
)
@click.option(
    "--count",
    type=int,
    default=4,
    help="Number of nodes to generate",
)
@click.option(
    "--start-index",
    type=int,
    default=0,
    help="Starting derivation index",
)
@click.option(
    "--required-sigs",
    type=int,
    help="Required signature count (defaults to n for all nodes)",
)
@click.option(
    "--output-dir",
    type=click.Path(path_type=Path),
    default="node_keys",
    help="Output directory for key files",
)
@click.option(
    "--print-yaml/--no-print-yaml",
    default=True,
    help="Print configuration in YAML format",
)
@async_command
async def generate_node_keys_command(
    mnemonic: str,
    count: int,
    start_index: int,
    required_sigs: int | None,
    output_dir: Path,
    print_yaml: bool = True,
) -> None:
    """Generate oracle node keys from mnemonic."""
    try:
        click.echo(f"Generating {count} node key pairs...")

        # Generate node keys

        nodes = generate_node_keys(
            mnemonic=mnemonic,
            start_index=start_index,
            count=count,
        )

        # Save node keys (creates the directory)
        save_node_keys(nodes, output_dir)

        # Override required signatures if specified
        if required_sigs is not None:
            if required_sigs > count:
                raise click.ClickException(
                    "Required signatures cannot exceed node count"
                )
            with (output_dir / "required_signatures").open("w") as f:
                f.write(str(required_sigs))

        # Verify we can load the config
        nodes_config = load_nodes_config(output_dir)

        click.echo(f"\nSuccessfully generated {count} node configurations:")
        click.echo(f"- Keys saved to: {output_dir}")
        click.echo(f"- Required signatures: {nodes_config.required_signatures}")
        click.echo()

        if print_yaml:
            print_yaml_config(nodes_config)

    except Exception as e:
        logger.error("Failed to generate node keys", exc_info=e)
        raise click.ClickException(str(e)) from e

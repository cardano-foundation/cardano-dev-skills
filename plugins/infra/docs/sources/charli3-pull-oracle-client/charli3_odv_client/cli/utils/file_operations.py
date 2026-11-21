"""File I/O operations for CLI."""

import json
from pathlib import Path
from typing import Dict, Any

from charli3_odv_client.models.message import SignedOracleNodeMessage


def save_feed_data(
    node_messages: Dict[str, SignedOracleNodeMessage],
    aggregate_message: Any,
    output_path: Path,
) -> None:
    """Save feed data to JSON file."""
    data = {
        "node_messages": {
            pub_key: msg.model_dump() for pub_key, msg in node_messages.items()
        },
        "aggregate_message": {
            "node_feeds_count": aggregate_message.node_feeds_count,
            "feeds": {
                vkh.to_primitive().hex(): feed_value
                for vkh, feed_value in aggregate_message.node_feeds_sorted_by_feed.items()
            },
        },
    }

    with output_path.open("w") as f:
        json.dump(data, f, indent=2)


def load_feed_data(input_path: Path) -> Dict[str, SignedOracleNodeMessage]:
    """Load feed data from JSON file."""
    with input_path.open() as f:
        data = json.load(f)

    reconstructed = {}
    for pub_key, msg_data in data["node_messages"].items():
        try:
            reconstructed[pub_key] = SignedOracleNodeMessage.model_validate(msg_data)
        except Exception as e:
            raise ValueError(f"Failed to reconstruct message for {pub_key}: {e}")

    return reconstructed


def save_transaction_cbor(transaction_cbor: str, output_path: Path) -> None:
    """Save transaction CBOR to file."""
    with output_path.open("w") as f:
        f.write(transaction_cbor)


def load_transaction_cbor(input_path: Path) -> str:
    """Load transaction CBOR from file."""
    with input_path.open("r") as f:
        return f.read().strip()


def save_json_data(data: Dict[str, Any], output_path: Path) -> None:
    """Save arbitrary JSON data to file."""
    with output_path.open("w") as f:
        json.dump(data, f, indent=2)


def load_json_data(input_path: Path) -> Dict[str, Any]:
    """Load JSON data from file."""
    with input_path.open("r") as f:
        return json.load(f)


def ensure_directory_exists(file_path: Path) -> None:
    """Ensure the directory for a file path exists."""
    file_path.parent.mkdir(parents=True, exist_ok=True)


def validate_file_extension(file_path: Path, expected_extension: str) -> bool:
    """Validate that a file has the expected extension."""
    return file_path.suffix.lower() == expected_extension.lower()

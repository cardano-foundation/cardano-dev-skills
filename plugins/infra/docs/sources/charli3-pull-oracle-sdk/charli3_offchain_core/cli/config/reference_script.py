from dataclasses import dataclass
from pathlib import Path

from charli3_offchain_core.cli.config.utils import ConfigFromDict, load_yaml_config


@dataclass
class UtxoReference(ConfigFromDict):
    """Reference script utxo reference configuration."""

    transaction_id: str
    output_index: int


@dataclass
class ReferenceScriptConfig(ConfigFromDict):
    """Reference script deployment configuration."""

    address: str | None = None
    utxo_reference: UtxoReference | None = None

    @classmethod
    def from_yaml(cls, path: Path | str) -> "ReferenceScriptConfig":
        """Load Reference script configuration from YAML."""
        config = load_yaml_config(path)
        yaml_data = config.get("reference_script", {})

        return cls(
            address=yaml_data["address"] if "address" in yaml_data else None,
            utxo_reference=(
                UtxoReference.from_dict(yaml_data["utxo_reference"])
                if "utxo_reference" in yaml_data
                else None
            ),
        )

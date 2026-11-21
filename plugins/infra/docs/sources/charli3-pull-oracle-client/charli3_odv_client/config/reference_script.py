"""Reference script configuration."""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

import yaml


@dataclass
class UtxoReference:
    """Reference script utxo reference configuration."""

    transaction_id: str
    output_index: int

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "UtxoReference":
        return cls(
            transaction_id=data["transaction_id"],
            output_index=data["output_index"],
        )


@dataclass
class ReferenceScriptConfig:
    """Reference script deployment configuration."""

    address: Optional[str] = None
    utxo_reference: Optional[UtxoReference] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ReferenceScriptConfig":
        return cls(
            address=data.get("address"),
            utxo_reference=(
                UtxoReference.from_dict(data["utxo_reference"])
                if "utxo_reference" in data
                else None
            ),
        )

    @classmethod
    def from_yaml(cls, path: Path | str) -> "ReferenceScriptConfig":
        """Load Reference script configuration from YAML."""
        path = Path(path)
        with path.open() as f:
            config = yaml.safe_load(f)

        yaml_data = config.get("reference_script", {})
        return cls.from_dict(yaml_data)

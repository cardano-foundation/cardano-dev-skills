from dataclasses import dataclass
from pathlib import Path

from charli3_offchain_core.cli.config.deployment import NetworkConfig
from charli3_offchain_core.cli.config.multisig import MultisigConfig

from .utils import load_yaml_config


@dataclass
class PlatformAuthConfig:
    """Configuration for platform authorization."""

    network: NetworkConfig
    multisig: MultisigConfig
    min_utxo_value: int = 2_000_000

    @classmethod
    def from_yaml(cls, path: Path | str) -> "PlatformAuthConfig":
        """Load platform auth configuration from YAML."""
        data = load_yaml_config(path)

        return cls(
            network=NetworkConfig.from_dict(data.get("network", {})),
            multisig=MultisigConfig.from_dict(data.get("multisig", {})),
            min_utxo_value=data.get("min_utxo_value", 2_000_000),
        )

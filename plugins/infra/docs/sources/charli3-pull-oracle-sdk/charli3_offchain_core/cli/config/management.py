"""Config for lifecycle operations."""

from dataclasses import dataclass
from pathlib import Path

from charli3_offchain_core.cli.config.settings import TimingConfig

from .multisig import MultisigConfig
from .network import NetworkConfig
from .nodes import NodesConfig
from .token import TokenConfig
from .utils import load_yaml_config


@dataclass
class ManagementConfig:
    """Minimal config required for lifecycle operations."""

    network: NetworkConfig
    tokens: TokenConfig
    timing: TimingConfig
    oracle_address: str
    multi_sig: MultisigConfig
    nodes: NodesConfig
    blueprint_path: Path = Path("artifacts/plutus.json")

    @classmethod
    def from_yaml(cls, path: Path | str) -> "ManagementConfig":
        """Load config from a yaml file."""
        data = load_yaml_config(path)
        return cls(
            network=NetworkConfig.from_dict(data.get("network", {})),
            tokens=TokenConfig.from_dict(data.get("tokens", {})),
            timing=TimingConfig.from_dict(data.get("timing", {})),
            oracle_address=data.get("oracle_address", ""),
            multi_sig=MultisigConfig.from_dict(data.get("multisig", {})),
            nodes=NodesConfig.from_dict(data.get("nodes", {})),
            blueprint_path=Path(data.get("blueprint_path", "artifacts/plutus.json")),
        )

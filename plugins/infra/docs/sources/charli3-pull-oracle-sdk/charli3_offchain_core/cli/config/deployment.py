"""Oracle deployment configuration and YAML loader."""

from dataclasses import dataclass
from pathlib import Path

from .multisig import MultisigConfig
from .network import NetworkConfig
from .nodes import NodesConfig
from .settings import FeeConfig, TimingConfig
from .token import TokenConfig
from .utils import load_yaml_config


@dataclass
class DeploymentConfig:
    """Complete deployment configuration."""

    network: NetworkConfig
    tokens: TokenConfig
    fees: FeeConfig
    timing: TimingConfig
    nodes: NodesConfig
    reward_count: int = 1
    aggstate_count: int = 1
    multi_sig: MultisigConfig | None = None
    blueprint_path: Path = Path("artifacts/plutus.json")
    use_aiken: bool = False
    create_reference: bool = True

    @classmethod
    def from_yaml(cls, path: Path | str) -> "DeploymentConfig":
        """Load configuration from YAML file."""
        data = load_yaml_config(path)

        return cls(
            network=NetworkConfig.from_dict(data.get("network", {})),
            tokens=TokenConfig.from_dict(data.get("tokens", {})),
            multi_sig=MultisigConfig.from_dict(data.get("multisig", {})),
            fees=FeeConfig.from_dict(data.get("fees", {})),
            timing=TimingConfig.from_dict(data.get("timing", {})),
            nodes=NodesConfig.from_dict(data.get("nodes", {})),
            blueprint_path=Path(data.get("blueprint_path", "artifacts/plutus.json")),
            use_aiken=data.get("apply_arguments_with_aiken", False),
            create_reference=data.get("create_reference", True),
            reward_count=data.get("reward_count", 1),
            aggstate_count=data.get("aggstate_count", 1),
        )

"""Odv Client deployment configuration and YAML loader."""

from dataclasses import dataclass
from pathlib import Path

from charli3_offchain_core.cli.aggregate_txs.base import TxConfig
from charli3_offchain_core.cli.config.utils import load_yaml_config


@dataclass
class NodeConfig:
    """Network identification for oracle node."""

    root_url: str
    pub_key: str

    @classmethod
    def from_dict(cls, data: dict) -> "NodeConfig":
        """Create node config from dictionary."""
        return cls(
            root_url=data["root_url"],
            pub_key=data["pub_key"],
        )


@dataclass
class OdvClientConfig:
    """Complete Odv Client configuration."""

    tx_config: TxConfig
    odv_validity_length: int  # milliseconds
    nodes: list[NodeConfig]

    @classmethod
    def from_yaml(cls, path: Path | str) -> "OdvClientConfig":
        """Load configuration from YAML file."""
        data = load_yaml_config(path)

        if isinstance(path, str):
            path = Path(path)

        return cls(
            tx_config=TxConfig.from_yaml(path),
            nodes=[NodeConfig.from_dict(node) for node in data["nodes"]],
            odv_validity_length=data["odv_validity_length"],
        )

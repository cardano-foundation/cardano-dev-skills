"""ODV Client configuration models."""

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

import yaml
from pycardano import (
    Network,
)

from charli3_odv_client.config.keys import WalletConfig
from charli3_odv_client.exceptions import ConfigurationError


@dataclass
class NodeConfig:
    """Configuration for an oracle node."""

    root_url: str
    pub_key: str

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "NodeConfig":
        return cls(root_url=data["root_url"], pub_key=data["pub_key"])


@dataclass
class NetworkConfig:
    """Network configuration."""

    network: str
    ogmios_url: Optional[str] = None
    kupo_url: Optional[str] = None
    blockfrost_project_id: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "NetworkConfig":
        network_data = data.get("network", {})

        ogmios_url = None
        kupo_url = None
        blockfrost_project_id = None

        if isinstance(network_data, dict):
            if "ogmios_kupo" in network_data:
                ogmios_url = network_data["ogmios_kupo"].get("ogmios_url")
                kupo_url = network_data["ogmios_kupo"].get("kupo_url")

            if "blockfrost" in network_data:
                blockfrost_project_id = network_data["blockfrost"].get("project_id")

            network_name = network_data.get("network", "testnet")
        else:
            network_name = network_data

        return cls(
            network=network_name,
            ogmios_url=ogmios_url,
            kupo_url=kupo_url,
            blockfrost_project_id=blockfrost_project_id,
        )

    def to_pycardano_network(self) -> Network:
        return Network[self.network.upper()]


@dataclass
class TokenConfig:
    """Token configuration."""

    reward_token_policy: Optional[str] = None
    reward_token_name: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TokenConfig":
        tokens_data = data.get("tokens", {})
        return cls(
            reward_token_policy=tokens_data.get("reward_token_policy"),
            reward_token_name=tokens_data.get("reward_token_name"),
        )


@dataclass
class ODVClientConfig:
    """Complete ODV client configuration."""

    network: NetworkConfig
    wallet: WalletConfig
    oracle_address: str
    policy_id: str
    odv_validity_length: int
    nodes: list[NodeConfig]
    tokens: Optional[TokenConfig] = None

    @classmethod
    def from_yaml(cls, path: Path | str) -> "ODVClientConfig":
        try:
            path = Path(path)
            if not path.exists():
                raise ConfigurationError(f"Config file not found: {path}")

            with path.open("r", encoding="utf-8") as f:
                data = yaml.safe_load(f)

            data = _resolve_env_vars(data)

            network_config = NetworkConfig.from_dict(data)
            wallet_config = WalletConfig.from_dict(data)
            wallet_config.validate()

            return cls(
                network=network_config,
                wallet=wallet_config,
                oracle_address=data["oracle_address"],
                policy_id=data["policy_id"],
                odv_validity_length=data["odv_validity_length"],
                nodes=[NodeConfig.from_dict(node) for node in data["nodes"]],
                tokens=TokenConfig.from_dict(data) if "tokens" in data else None,
            )

        except Exception as e:
            raise ConfigurationError(f"Failed to load config: {e}") from e


def _resolve_env_vars(data: Dict[str, Any]) -> Dict[str, Any]:
    """Recursively resolve environment variables in configuration."""
    resolved = {}
    for key, value in data.items():
        if isinstance(value, dict):
            resolved[key] = _resolve_env_vars(value)
        elif isinstance(value, list):
            resolved[key] = [
                (
                    _resolve_env_vars(item)
                    if isinstance(item, dict)
                    else (
                        os.environ.get(item[1:], item)
                        if isinstance(item, str) and item.startswith("$")
                        else item
                    )
                )
                for item in value
            ]
        elif isinstance(value, str) and value.startswith("$"):
            env_var = value[1:]
            resolved[key] = os.environ.get(env_var, value)
        else:
            resolved[key] = value
    return resolved

from dataclasses import dataclass
from pathlib import Path

from pycardano import Network

from .keys import WalletConfig
from .utils import ConfigFromDict, load_yaml_config


@dataclass
class BlockfrostConfig(ConfigFromDict):
    """Blockfrost backend configuration."""

    project_id: str
    api_url: str | None = None


@dataclass
class OgmiosKupoConfig(ConfigFromDict):
    """Ogmios/Kupo backend configuration."""

    ogmios_url: str
    kupo_url: str


@dataclass
class NetworkConfig(ConfigFromDict):
    """Network-specific configuration."""

    network: Network
    wallet: WalletConfig
    blockfrost: BlockfrostConfig | None = None
    ogmios_kupo: OgmiosKupoConfig | None = None

    @classmethod
    def from_yaml(cls, path: Path | str) -> "NetworkConfig":
        """Load platform auth configuration from YAML."""
        data = load_yaml_config(path)
        network_data = data.get("network", {})

        return cls(
            network=Network[network_data.get("network", "TESTNET").upper()],
            wallet=WalletConfig.from_dict(network_data.get("wallet", {})),
            blockfrost=(
                BlockfrostConfig.from_dict(network_data["blockfrost"])
                if "blockfrost" in network_data
                else None
            ),
            ogmios_kupo=(
                OgmiosKupoConfig.from_dict(network_data["ogmios_kupo"])
                if "ogmios_kupo" in network_data
                else None
            ),
        )

    @classmethod
    def from_dict(cls, data: dict) -> "NetworkConfig":
        """Create network config from dictionary."""
        return cls(
            network=Network[data.get("network", "TESTNET").upper()],
            wallet=WalletConfig.from_dict(data.get("wallet", {})),
            blockfrost=(
                BlockfrostConfig.from_dict(data["blockfrost"])
                if "blockfrost" in data
                else None
            ),
            ogmios_kupo=(
                OgmiosKupoConfig.from_dict(data["ogmios_kupo"])
                if "ogmios_kupo" in data
                else None
            ),
        )

    def validate(self) -> None:
        """Validate backend configuration."""
        if not self.blockfrost and not self.ogmios_kupo:
            raise ValueError(
                "Either Blockfrost or Ogmios/Kupo configuration must be provided"
            )
        if self.blockfrost and self.ogmios_kupo:
            raise ValueError(
                "Cannot specify both Blockfrost and Ogmios/Kupo configuration"
            )

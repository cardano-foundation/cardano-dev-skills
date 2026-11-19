"""Simulated node implementation using real node keys."""

from dataclasses import dataclass
from logging import getLogger
from pathlib import Path

import yaml
from pycardano import (
    PaymentExtendedSigningKey,
    PaymentVerificationKey,
    VerificationKeyHash,
)

from charli3_offchain_core.cli.aggregate_txs.base import TxConfig
from charli3_offchain_core.cli.config import NetworkConfig, WalletConfig

logger = getLogger(__name__)


class SimulatedNode:
    """Represents a simulated oracle node using real keys."""

    def __init__(
        self,
        signing_key: PaymentExtendedSigningKey,
        verification_key: PaymentVerificationKey,
        feed_vkh: VerificationKeyHash,
    ) -> None:
        """Initialize node with provided keys.

        Args:
            signing_key: Payment signing key
            verification_key: Payment verification key
            feed_vkh: Feed verification key hash
        """
        self.signing_key = signing_key
        self.verification_key = verification_key
        self.feed_vkh = feed_vkh

        logger.info("Initialized node VKH: %s", self.feed_vkh.to_primitive().hex()[:8])

    @classmethod
    def from_key_directory(cls, node_dir: Path) -> "SimulatedNode":
        """Create node from generated key directory.

        Args:
            node_dir: Directory containing node keys

        Returns:
            SimulatedNode: New node instance

        Raises:
            ValueError: If key files are missing or invalid
        """
        try:
            # Load keys from files
            signing_key = PaymentExtendedSigningKey.load(str(node_dir / "feed.skey"))
            verification_key = PaymentVerificationKey.load(str(node_dir / "feed.vkey"))

            # Load VKH values
            feed_vkh = VerificationKeyHash(
                bytes.fromhex((node_dir / "feed.vkh").read_text().strip())
            )

            # Create instance using __init__
            return cls(
                signing_key=signing_key,
                verification_key=verification_key,
                feed_vkh=feed_vkh,
            )

        except FileNotFoundError as e:
            raise ValueError(f"Missing key file in {node_dir}: {e}") from e
        except Exception as e:
            logger.error("Failed to load node keys from %s: %s", node_dir, e)
            raise ValueError(f"Failed to load node keys: {e!s}") from e

    @property
    def hex_feed_vkh(self) -> str:
        """Get feed verification key hash as hex."""
        return self.feed_vkh.to_primitive().hex()

    @property
    def verify_key_bytes(self) -> bytes:
        """Get raw verification key bytes for signature validation."""
        return self.verification_key.hash().payload

    def to_dict(self) -> dict:
        """Convert node to dictionary representation."""
        return {
            "feed_vkh": self.hex_feed_vkh,
            "verification_key": self.verify_key_bytes.hex(),
        }


@dataclass
class SimulationSettings:
    """Simulation-specific configuration."""

    node_keys_dir: Path
    base_feed: int
    variance: float = 0.01
    wait_time: int = 60

    def __post_init__(self) -> None:
        """Validate and set defaults."""
        if not self.node_keys_dir.is_dir():
            raise ValueError(f"Node keys directory not found: {self.node_keys_dir}")

    @property
    def node_count(self) -> int:
        """Get number of nodes from directory structure."""
        return len(list(self.node_keys_dir.glob("node_*")))

    def get_node_dirs(self) -> list[Path]:
        """Get sorted list of node directories."""
        return sorted(self.node_keys_dir.glob("node_*"))


@dataclass
class SimulationResult:
    """Results of oracle simulation."""

    nodes: list[SimulatedNode]
    feeds: dict[int, dict]
    odv_tx: str
    rewards: dict[str, int] | None = None


class SimulationConfig(TxConfig):
    """Extends base transaction config with simulation settings."""

    def __init__(
        self,
        network: NetworkConfig,
        script_address: str,
        policy_id: str,
        wallet: WalletConfig,
        odv_validity_length: int,
        simulation: SimulationSettings,
        reward_token_policy: str | None = None,
        reward_token_name: str | None = None,
    ) -> None:
        """Initialize simulation config with base config and simulation settings."""
        super().__init__(
            network,
            script_address,
            policy_id,
            wallet,
            odv_validity_length,
            reward_token_policy,
            reward_token_name,
        )
        self.simulation = simulation

    @classmethod
    def from_yaml(cls, path: Path) -> "SimulationConfig":
        """Load simulation config from YAML file."""
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {path}")

        with path.open("r") as f:
            data = yaml.safe_load(f)

        # Load simulation settings
        sim_data = data.get("simulation", {})
        if not sim_data:
            raise ValueError("Missing simulation settings in config file")

        sim_settings = SimulationSettings(
            node_keys_dir=Path(sim_data["node_keys_dir"]),
            base_feed=sim_data["base_feed"],
            variance=sim_data.get("variance", 0.01),
            wait_time=sim_data.get("wait_time", 60),
        )

        tokens = data.get("tokens", {})

        return cls(
            network=NetworkConfig.from_dict(data.get("network", {})),
            script_address=data["oracle_address"],
            policy_id=data["policy_id"],
            wallet=WalletConfig.from_dict(data["wallet"]),
            simulation=sim_settings,
            odv_validity_length=data["odv_validity_length"],
            reward_token_policy=tokens.get("reward_token_policy"),
            reward_token_name=tokens.get("reward_token_name"),
        )

    def validate(self) -> None:
        """Validate complete configuration."""
        super().validate()

        if not 0 < self.simulation.variance < 1:
            raise ValueError("Variance must be between 0 and 1")

        if self.simulation.wait_time < 0:
            raise ValueError("Wait time cannot be negative")

        if not self.simulation.node_keys_dir.is_dir():
            raise ValueError(
                f"Node keys directory not found: {self.simulation.node_keys_dir}"
            )

        if self.simulation.base_feed <= 0:
            raise ValueError("Base feed value must be positive")

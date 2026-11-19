"""Oracle deployment configuration models."""

from dataclasses import dataclass

from pycardano import Network

MINIMUM_REWARD_COUNT = 1
MINIMUM_AGGSTATE_COUNT = 1


@dataclass
class OracleTokenNames:
    """Token names for oracle NFTs"""

    core_settings: str
    reward_account: str
    aggstate: str

    @classmethod
    def from_network(cls, network: Network) -> "OracleTokenNames":
        """Create token names configuration based on network"""
        # For now use same token names for testnet and mainnet
        # due to validator is not able to handle testnet token names
        return cls(
            core_settings="C3CS",
            reward_account="C3RA",
            aggstate="C3AS",
        )


@dataclass
class OracleDeploymentConfig:
    """Configuration for oracle deployment."""

    network: Network
    reward_count: int
    aggstate_count: int
    disallow_less_than_four_nodes: bool | None = None
    token_names: OracleTokenNames | None = None

    def __post_init__(self) -> None:
        """Validate and set default configuration."""
        if self.token_names is None:
            self.token_names = OracleTokenNames.from_network(self.network)

        if self.disallow_less_than_four_nodes is None:
            self.disallow_less_than_four_nodes = self.network == Network.MAINNET

        if self.reward_count < MINIMUM_REWARD_COUNT:
            raise ValueError(f"Reward count must be at least {MINIMUM_REWARD_COUNT}")

        if self.aggstate_count < MINIMUM_AGGSTATE_COUNT:
            raise ValueError(
                f"Aggstate count must be at least {MINIMUM_AGGSTATE_COUNT}"
            )


@dataclass
class OracleScriptConfig:
    """Configuration for oracle reference scripts."""

    create_manager_reference: bool = True
    reference_ada_amount: int = 64_000_000  # 64 ADA for reference scripts

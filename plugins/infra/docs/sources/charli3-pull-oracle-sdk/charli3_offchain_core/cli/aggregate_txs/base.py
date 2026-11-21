"""Base utilities and types for oracle transaction CLI commands."""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import click
import yaml
from pycardano import Address, AssetName, PaymentSigningKey, ScriptHash

from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.base import create_chain_query
from charli3_offchain_core.cli.config.deployment import NetworkConfig
from charli3_offchain_core.cli.config.keys import KeyManager, WalletConfig

logger = logging.getLogger(__name__)


@dataclass
class TxConfig:
    """Transaction configuration parameters."""

    network: NetworkConfig
    script_address: str  # Oracle script address
    policy_id: str  # Oracle NFT policy ID
    wallet: WalletConfig  # Wallet configuration with mnemonic
    odv_validity_length: int
    reward_token_policy: str | None = None  # Fee token policy ID
    reward_token_name: str | None = None  # Fee token name

    def validate(self) -> None:
        """Validate complete configuration."""
        # Validate network configuration
        if not self.network:
            raise ValueError("Network configuration required")
        self.network.validate()

        # Validate addresses and ID
        if not self.script_address:
            raise ValueError("Script address required")
        if not self.policy_id:
            raise ValueError("Policy ID required")

        # Validate wallet configuration
        if not self.wallet:
            raise ValueError("Wallet configuration required")
        if not self.wallet.mnemonic:
            raise ValueError("Wallet mnemonic required")

    @classmethod
    def from_yaml(cls, path: Path) -> "TxConfig":
        """Load transaction config from YAML file."""
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {path}")
        try:
            with path.open("r") as f:
                data = yaml.safe_load(f)

            # Reward token information
            tokens = data.get("tokens", {})

            return cls(
                network=NetworkConfig.from_dict(data.get("network", {})),
                script_address=data["oracle_address"],
                policy_id=data["policy_id"],
                reward_token_policy=tokens.get("reward_token_policy"),
                reward_token_name=tokens.get("reward_token_name"),
                wallet=WalletConfig.from_dict(data["wallet"]),
                odv_validity_length=data["odv_validity_length"],
            )
        except KeyError as e:
            logger.error("Failed to load configuration: %s", e)
            raise ValueError(f"Invalid configuration file: {e}") from e
        except Exception as e:
            logger.error("Failed to load configuration: %s", e)
            raise ValueError(f"Error loading configuration: {e}") from e

    def get_script_address(self) -> Address:
        """Get script address as Address object."""
        return Address.from_primitive(self.script_address)

    def get_policy_id(self) -> ScriptHash:
        """Get policy ID as ScriptHash object."""
        return ScriptHash(bytes.fromhex(self.policy_id))


class TransactionContext:
    """Holds common transaction context and utilities."""

    def __init__(self, config: TxConfig) -> None:
        self.config = config
        self.chain_query = create_chain_query(config.network)
        self.tx_manager = TransactionManager(self.chain_query)
        self.script_address = config.get_script_address()
        self.policy_id = config.get_policy_id()
        self.reward_token_hash = (
            ScriptHash(bytes.fromhex(config.reward_token_policy))
            if config.reward_token_policy is not None
            else None
        )
        self.reward_token_name = (
            AssetName(bytes.fromhex(config.reward_token_name))
            if config.reward_token_name is not None
            else None
        )

    def load_keys(self) -> tuple[PaymentSigningKey, Address]:
        """Load keys from mnemonic."""
        payment_sk, _, _, change_address = KeyManager.load_from_mnemonic(
            self.config.wallet.mnemonic, self.config.network.network
        )
        return payment_sk, change_address


def tx_options(f: Callable) -> Callable:
    """Common transaction command options.

    Args:
        f: Function to decorate

    Returns:
        Decorated function with common options
    """
    f = click.option(
        "--config",
        type=click.Path(exists=True, path_type=Path),
        required=True,
        help="Path to transaction configuration YAML",
    )(f)

    return f

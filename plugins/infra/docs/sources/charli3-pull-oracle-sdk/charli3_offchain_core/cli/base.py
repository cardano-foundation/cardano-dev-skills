"""Base CLI utilities and helper functions."""

import logging
from dataclasses import dataclass
from urllib.parse import urlparse

import click
from pycardano import (
    Address,
    BlockFrostChainContext,
    Network,
    PaymentSigningKey,
    PaymentVerificationKey,
    ScriptHash,
    UTxO,
)
from pycardano.backend import OgmiosV6ChainContext
from pycardano.backend.kupo import KupoChainContextExtension

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.contracts.aiken_loader import OracleContracts

from .config.deployment import DeploymentConfig
from .config.keys import KeyManager
from .config.network import NetworkConfig

logger = logging.getLogger(__name__)


@dataclass
class LoadedKeys:
    """Container for loaded keys and address."""

    payment_sk: PaymentSigningKey
    payment_vk: PaymentVerificationKey
    stake_vk: PaymentVerificationKey
    address: Address


@dataclass
class DerivedAddresses:
    """Container for derived deployment addresses."""

    admin_address: Address
    script_address: Address


def derive_deployment_addresses(
    config: DeploymentConfig,
    contracts: OracleContracts,
) -> DerivedAddresses:
    """Derive deployment addresses from contracts.

    Args:
        config: Deployment configuration
        contracts: Oracle contracts

    Returns:
        DerivedAddresses containing admin and script addresses
    """
    # Load wallet keys
    keys = KeyManager.load_from_config(config.network.wallet)
    admin_addr = keys[3]  # Address is fourth element in tuple

    # Get address based on network

    script_addr = (
        contracts.spend.mainnet_addr
        if config.network.network == Network.MAINNET
        else contracts.spend.testnet_addr
    )

    logger.info("Derived script address: %s", script_addr)
    return DerivedAddresses(admin_address=admin_addr, script_address=script_addr)


def validate_platform_auth_utxo(utxos: list[UTxO], auth_policy_id: str) -> UTxO:
    """Find and validate platform auth UTxO."""
    if not utxos:
        raise click.ClickException("No UTxOs found at address")

    auth_policy_hash = ScriptHash(bytes.fromhex(auth_policy_id))

    for utxo in utxos:
        if (
            utxo.output.amount.multi_asset
            and auth_policy_hash in utxo.output.amount.multi_asset
        ):
            return utxo

    raise click.ClickException(
        f"No UTxO found with platform auth NFT (policy: {auth_policy_id})"
    )


def load_keys_with_validation(
    config: DeploymentConfig, contracts: OracleContracts
) -> LoadedKeys:
    """Load and validate keys from config."""
    try:
        # Load keys and get derived addresses
        derived = derive_deployment_addresses(config, contracts)
        payment_sk, payment_vk, stake_vk, _ = KeyManager.load_from_config(
            config.network.wallet
        )
        return LoadedKeys(payment_sk, payment_vk, stake_vk, derived.admin_address)

    except Exception as e:
        raise click.ClickException(f"Failed to load keys: {e}") from e


def validate_deployment_config(config: DeploymentConfig) -> None:
    """Validate deployment configuration."""
    if config.reward_count <= 0:
        raise click.ClickException("Reward count must be positive")

    if config.aggstate_count <= 0:
        raise click.ClickException("AggState count must be positive")

    if config.timing.pause_period <= 0:
        raise click.ClickException("Pause period must be positive")

    if config.timing.reward_dismissing_period <= config.timing.pause_period:
        raise click.ClickException(
            "Reward dismissing period must be greater than pause period"
        )

    if config.fees.node_fee <= 0 or config.fees.platform_fee <= 0:
        raise click.ClickException("Fees must be positive")


def create_chain_query(config: NetworkConfig) -> ChainQuery:
    """Create chain query from configuration file."""
    try:
        # Use Blockfrost
        if config.blockfrost:
            context = BlockFrostChainContext(
                project_id=config.blockfrost.project_id,
                network=config.network,
            )
            return ChainQuery(blockfrost_context=context)

        # Use Ogmios/Kupo
        ogmios_url = config.ogmios_kupo.ogmios_url
        host, port, secure = parse_ws_url(ogmios_url)

        ogmios_context = OgmiosV6ChainContext(
            host=host,
            port=port,
            secure=secure,
            network=config.network,
        )
        kupo_context = KupoChainContextExtension(
            ogmios_context,
            config.ogmios_kupo.kupo_url,
        )
        return ChainQuery(kupo_ogmios_context=kupo_context)

    except Exception as e:
        raise click.ClickException(f"Failed to create chain query: {e}") from e


def parse_ws_url(url: str) -> tuple[str, int, bool]:
    """Parse WebSocket URL into host, port, and secure flag."""
    parsed = urlparse(url)

    # Determine if secure based on scheme
    secure = parsed.scheme in ("wss", "https")

    # Extract host without port if port is in the URL
    host = parsed.hostname or parsed.netloc.split(":")[0]
    port = parsed.port or (443 if secure else 1337)
    return host, port, secure

"""Shared helper functions for CLI commands."""

import urllib.parse

from pycardano import ScriptHash, AssetName
from pycardano import Address, Network, BlockFrostChainContext
from pycardano.backend.kupo import KupoChainContextExtension
from pycardano.backend import OgmiosV6ChainContext

from charli3_odv_client.config import ODVClientConfig, ReferenceScriptConfig
from charli3_odv_client.blockchain.transactions import TransactionManager
from charli3_odv_client.blockchain.chain_query import ChainQuery, ChainQueryConfig
from charli3_odv_client.core.transaction_builder import ODVTransactionBuilder
from charli3_odv_client.exceptions import ValidationError


def create_chain_query(config: ODVClientConfig) -> ChainQuery:
    """Create chain query from configuration."""
    network_config = config.network
    network = (
        Network.MAINNET if network_config.network == "mainnet" else Network.TESTNET
    )

    if network_config.blockfrost_project_id:
        blockfrost_context = BlockFrostChainContext(
            project_id=network_config.blockfrost_project_id, network=network
        )
        return ChainQuery(
            blockfrost_context=blockfrost_context,
            config=ChainQueryConfig(use_wall_clock=False),
        )
    elif network_config.ogmios_url and network_config.kupo_url:
        ogmios_parsed = urllib.parse.urlparse(network_config.ogmios_url)
        ogmios_context = OgmiosV6ChainContext(
            host=ogmios_parsed.hostname,
            port=ogmios_parsed.port or (443 if ogmios_parsed.scheme == "wss" else 1337),
            secure=ogmios_parsed.scheme in ("wss", "https"),
            network=network,
        )
        kupo_context = KupoChainContextExtension(
            ogmios_context,
            network_config.kupo_url,
        )
        return ChainQuery(
            kupo_ogmios_context=kupo_context,
            config=ChainQueryConfig(use_wall_clock=False),
        )
    else:
        raise ValidationError("No valid network configuration provided")


def setup_transaction_builder(
    config: ODVClientConfig,
    ref_script_config: ReferenceScriptConfig,
    chain_query: ChainQuery,
):
    """Setup ODV transaction builder with configuration."""

    # Configure transaction builder
    reward_token_hash = None
    reward_token_name = None

    if config.tokens:
        if config.tokens.reward_token_policy:
            reward_token_hash = ScriptHash.from_primitive(
                bytes.fromhex(config.tokens.reward_token_policy)
            )
        if config.tokens.reward_token_name:
            reward_token_name = AssetName(
                bytes.fromhex(config.tokens.reward_token_name)
            )
    tx_manager = TransactionManager(chain_query)

    tx_builder = ODVTransactionBuilder(
        tx_manager=tx_manager,
        script_address=Address.from_primitive(config.oracle_address),
        policy_id=ScriptHash.from_primitive(bytes.fromhex(config.policy_id)),
        ref_script_config=ref_script_config,
        reward_token_hash=reward_token_hash,
        reward_token_name=reward_token_name,
    )

    return tx_manager, tx_builder

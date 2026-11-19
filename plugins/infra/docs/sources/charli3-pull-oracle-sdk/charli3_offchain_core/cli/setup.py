import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any, NamedTuple

from pycardano import (
    Address,
    PaymentSigningKey,
    PaymentVerificationKey,
    StakeVerificationKey,
)

from charli3_offchain_core.cli.config.formatting import format_status_update
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.contracts.aiken_loader import (
    OracleContracts,
)
from charli3_offchain_core.models.oracle_datums import (
    Asset,
    FeeConfig,
    NoDatum,
    OracleConfiguration,
    RewardPrices,
    SomeAsset,
)
from charli3_offchain_core.oracle.config import (
    OracleDeploymentConfig,
    OracleScriptConfig,
)
from charli3_offchain_core.oracle.deployment.orchestrator import (
    OracleDeploymentOrchestrator,
)
from charli3_offchain_core.platform.auth.token_finder import PlatformAuthFinder

from ..blockchain.chain_query import ChainQuery
from ..blockchain.transactions import TransactionManager
from ..platform.auth.orchestrator import (
    PlatformAuthOrchestrator,
)
from .base import (
    LoadedKeys,
    create_chain_query,
    derive_deployment_addresses,
    load_keys_with_validation,
    validate_deployment_config,
)
from .config.deployment import DeploymentConfig
from .config.keys import KeyManager
from .config.management import ManagementConfig
from .config.platform import PlatformAuthConfig


class OracleAddresses(NamedTuple):
    admin_address: str
    script_address: str
    platform_address: str


def setup_platform_from_config(config: Path, metadata: Path | None) -> tuple[
    PlatformAuthConfig,
    PaymentSigningKey,
    PaymentVerificationKey,
    StakeVerificationKey,
    Address,
    ChainQuery,
    TransactionManager,
    PlatformAuthOrchestrator,
    Any,
]:
    """Set up all required modules that are common across platform functions from config file."""
    auth_config = PlatformAuthConfig.from_yaml(config)
    payment_sk, payment_vk, stake_vk, default_addr = KeyManager.load_from_config(
        auth_config.network.wallet
    )

    chain_query = create_chain_query(auth_config.network)
    tx_manager = TransactionManager(chain_query)

    orchestrator = PlatformAuthOrchestrator(
        chain_query=chain_query,
        tx_manager=tx_manager,
        status_callback=format_status_update,
    )
    meta_data = None
    if metadata:
        with metadata.open() as f:
            meta_data = json.load(f)

    return (
        auth_config,
        payment_sk,
        payment_vk,
        stake_vk,
        default_addr,
        chain_query,
        tx_manager,
        orchestrator,
        meta_data,
    )


def setup_oracle_from_config(
    config: Path,
) -> tuple[
    DeploymentConfig,
    OracleConfiguration,
    PaymentSigningKey,
    PaymentVerificationKey,
    OracleAddresses,
    ChainQuery,
    TransactionManager,
    OracleDeploymentOrchestrator,
    PlatformAuthFinder,
    dict,
]:
    """Set up all required modules for oracle deployment from config file."""
    # Load and validate configuration
    deployment_config = DeploymentConfig.from_yaml(config)
    validate_deployment_config(deployment_config)
    ref_script_config = ReferenceScriptConfig.from_yaml(config)

    reward_token = setup_token(
        deployment_config.tokens.reward_token_policy,
        deployment_config.tokens.reward_token_name,
    )
    rate_token = setup_token(
        deployment_config.tokens.rate_token_policy,
        deployment_config.tokens.rate_token_name,
    )

    # Create oracle configuration
    oracle_config = OracleConfiguration(
        platform_auth_nft=bytes.fromhex(deployment_config.tokens.platform_auth_policy),
        pause_period_length=deployment_config.timing.pause_period,
        reward_dismissing_period_length=deployment_config.timing.reward_dismissing_period,
        fee_token=reward_token,
    )

    # Parameterize contracts
    if deployment_config.use_aiken:
        parameterized_contracts = apply_spend_params_with_aiken_compiler(
            oracle_config, deployment_config.blueprint_path
        )
    else:
        base_contracts = OracleContracts.from_blueprint(
            deployment_config.blueprint_path
        )
        parameterized_contracts = OracleContracts(
            spend=base_contracts.apply_spend_params(oracle_config),
            mint=base_contracts.mint,
        )

    # Load keys and derive addresses
    keys = load_keys_with_validation(deployment_config, parameterized_contracts)
    addresses = derive_deployment_addresses(deployment_config, parameterized_contracts)
    platform_address = (
        deployment_config.multi_sig.platform_addr or addresses.admin_address
    )

    # In your setup function, replace the dictionary creation with:
    oracle_addresses = OracleAddresses(
        admin_address=addresses.admin_address,
        script_address=addresses.script_address,
        platform_address=platform_address,
    )

    chain_query = create_chain_query(deployment_config.network)

    tx_manager = TransactionManager(chain_query)

    # Create configurations
    configs = {
        "script": OracleScriptConfig(
            create_manager_reference=deployment_config.create_reference,
            reference_ada_amount=54663730,
        ),
        "deployment": OracleDeploymentConfig(
            network=deployment_config.network.network,
            reward_count=deployment_config.reward_count,
            aggstate_count=deployment_config.aggstate_count,
        ),
        "rate_token": FeeConfig(
            rate_nft=rate_token,
            reward_prices=RewardPrices(
                node_fee=deployment_config.fees.node_fee,
                platform_fee=deployment_config.fees.platform_fee,
            ),
        ),
    }

    # Initialize platform auth finder
    platform_auth_finder = PlatformAuthFinder(chain_query)

    # Initialize orchestrator
    orchestrator = OracleDeploymentOrchestrator(
        chain_query=chain_query,
        contracts=parameterized_contracts,
        tx_manager=tx_manager,
        ref_script_config=ref_script_config,
        status_callback=format_status_update,
    )

    return (
        deployment_config,
        oracle_config,
        keys.payment_sk,
        keys.payment_vk,
        oracle_addresses,
        chain_query,
        tx_manager,
        orchestrator,
        platform_auth_finder,
        configs,
    )


def setup_management_from_config(config: Path) -> tuple[
    ManagementConfig,
    OracleConfiguration,
    LoadedKeys,
    OracleAddresses,
    ChainQuery,
    TransactionManager,
    PlatformAuthFinder,
]:
    management_config = ManagementConfig.from_yaml(config)
    base_contracts = OracleContracts.from_blueprint(management_config.blueprint_path)

    reward_token = setup_token(
        management_config.tokens.reward_token_policy,
        management_config.tokens.reward_token_name,
    )
    # Create oracle configuration
    oracle_config = OracleConfiguration(
        platform_auth_nft=bytes.fromhex(management_config.tokens.platform_auth_policy),
        pause_period_length=management_config.timing.pause_period,
        reward_dismissing_period_length=management_config.timing.reward_dismissing_period,
        fee_token=reward_token,
    )

    keys = load_keys_with_validation(management_config, base_contracts)
    addresses = derive_deployment_addresses(management_config, base_contracts)

    platform_address = (
        management_config.multi_sig.platform_addr or addresses.admin_address
    )

    oracle_addresses = OracleAddresses(
        admin_address=addresses.admin_address,
        script_address=management_config.oracle_address,
        platform_address=platform_address,
    )

    chain_query = create_chain_query(management_config.network)
    tx_manager = TransactionManager(chain_query)
    platform_auth_finder = PlatformAuthFinder(chain_query)

    return (
        management_config,
        oracle_config,
        keys,
        oracle_addresses,
        chain_query,
        tx_manager,
        platform_auth_finder,
    )


def setup_token(
    token_policy: str | None, token_name: str | None
) -> NoDatum | SomeAsset:
    """Setup fee token from config params"""
    if not (token_policy and token_name):
        fee_token = NoDatum()
    else:
        fee_token = SomeAsset(
            asset=Asset(
                policy_id=bytes.fromhex(token_policy),
                name=bytes.fromhex(token_name),
            )
        )
    return fee_token


def apply_spend_params_with_aiken_compiler(
    config: OracleConfiguration, blueprint_path: Path
) -> OracleContracts:
    cbor_hex = config.to_cbor().hex()
    output_file = "tmp_oracle_manager.json"
    validator_name = "oracle_manager"

    print(blueprint_path.name)
    original_dir = os.getcwd()
    try:
        project_root = Path(__file__).parent.parent.parent

        # Check if the path exists as-is (absolute or relative to CWD)
        if blueprint_path.exists():
            artifact_path = blueprint_path.parent
        else:
            # Try relative to project root (handling /artifacts style paths)
            artifact_path = (project_root / str(blueprint_path).lstrip(os.sep)).parent

        os.chdir(artifact_path)

        # Create aiken.toml file
        aiken_toml_content = """name = "charli3-official/odv-multisig-charli3-oracle-onchain"
        version = "0.0.0"
        """

        # Write aiken.toml file in the artifact directory
        with open("aiken.toml", "w") as f:
            f.write(aiken_toml_content)

        output_path = artifact_path / output_file

        if os.path.exists(output_path):
            os.remove(output_path)

        # Use shutil.which to get the full path to aiken executable
        aiken_path = shutil.which("aiken")
        if not aiken_path:
            raise FileNotFoundError("aiken executable not found in PATH")

        subprocess.run(  # noqa: S603
            [
                aiken_path,
                "blueprint",
                "apply",
                "-i",
                blueprint_path.name,
                "-v",
                validator_name,
                "-o",
                output_file,
                cbor_hex,
            ],
            check=True,
            capture_output=True,
        )

        # Pass the relative path (just the filename) since we're already in artifact_path
        contracts = OracleContracts.from_blueprint(output_file)

        os.remove(output_file)

        return contracts
    finally:
        os.chdir(original_dir)

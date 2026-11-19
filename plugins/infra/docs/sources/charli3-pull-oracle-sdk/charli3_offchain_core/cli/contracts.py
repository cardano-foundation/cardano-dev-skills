"""Script for loading, parameterizing and displaying Oracle contract details"""

import argparse
import json
from pathlib import Path

from opshin import PlutusContract
from pycardano import Address, ScriptHash, TransactionOutput

from charli3_offchain_core.contracts.aiken_loader import OracleContracts
from charli3_offchain_core.models.oracle_datums import (
    Asset,
    OracleConfiguration,
    SomeAsset,
)


def safe_dump_artifacts(contract: PlutusContract, target_dir: Path) -> None:
    """Safely dump contract artifacts without schema generation"""
    target_dir.mkdir(exist_ok=True, parents=True)

    # Save CBOR
    with (target_dir / "script.cbor").open("w") as fp:
        fp.write(contract.cbor_hex)

    # Save script hash/policy id
    with (target_dir / "script.policy_id").open("w") as fp:
        fp.write(contract.policy_id)

    # Save addresses
    with (target_dir / "mainnet.addr").open("w") as fp:
        fp.write(str(contract.mainnet_addr))
    with (target_dir / "testnet.addr").open("w") as fp:
        fp.write(str(contract.testnet_addr))

    # Save metadata
    metadata = {
        "title": contract.title,
        "version": contract.version,
        "description": contract.description,
        "license": contract.license,
        "script_hash": contract.script_hash.to_primitive().hex(),
        "policy_id": contract.policy_id,
        "mainnet_address": str(contract.mainnet_addr),
        "testnet_address": str(contract.testnet_addr),
    }
    with (target_dir / "metadata.json").open("w") as fp:
        json.dump(metadata, fp, indent=2)


def display_contract_info(contract: PlutusContract, name: str) -> None:
    """Display contract details using PlutusContract properties"""
    print(f"\n{name} Contract Details:")
    print("-" * 50)

    # Contract basics
    print(f"Title: {contract.title}")
    print(f"Version: {contract.version}")
    if contract.description:
        print(f"Description: {contract.description}")
    if contract.license:
        print(f"License: {contract.license}")

    # Core identifiers
    print(f"\nScript Hash: {contract.script_hash}")
    print(f"CBOR Hex: {contract.cbor_hex}")

    # Network addresses
    print("\nNetwork Addresses:")
    print(f"Mainnet: {contract.mainnet_addr}")
    print(f"Testnet: {contract.testnet_addr}")

    if any(p for p in contract.purpose if p.value == "minting"):
        print(f"\nPolicy ID: {contract.policy_id}")

    # Parameter info
    if contract.parameter_types:
        print("\nParameters:")
        for param_name, param_type in contract.parameter_types:
            print(f"- {param_name}: {param_type.__name__}")

    # Datum/Redeemer info
    if contract.datum_type:
        print(
            f"\nDatum Type: {contract.datum_type[0]} ({contract.datum_type[1].__name__})"
        )
    if contract.redeemer_type:
        print(
            f"Redeemer Type: {contract.redeemer_type[0]} ({contract.redeemer_type[1].__name__})"
        )


def main() -> None:
    """Main script entrypoint for loading, parameterizing and displaying Oracle contracts"""

    parser = argparse.ArgumentParser(
        description="Load and parameterize Oracle contracts"
    )
    parser.add_argument(
        "--blueprint",
        type=str,
        help="Path to the plutus.json file",
        default="artifacts/plutus.json",
    )
    parser.add_argument(
        "--dump-dir",
        type=str,
        help="Directory to dump contract artifacts",
        default="build",
    )

    args = parser.parse_args()

    # Load contracts
    print(f"Loading contracts from {args.blueprint}")
    blueprint_path = Path(args.blueprint)
    contracts = OracleContracts.from_blueprint(blueprint_path)

    # Create sample configuration for parameterization
    print("\nCreating oracle configuration...")
    config = OracleConfiguration(
        platform_auth_nft=bytes.fromhex("00" * 28),
        pause_period_length=3600,
        reward_dismissing_period_length=7200,
        fee_token=SomeAsset(
            asset=Asset(policy_id=bytes.fromhex("00" * 28), name=b"TOKEN"),
        ),
    )

    # Create sample UTxO ref and script hash for mint policy
    utxo_ref = TransactionOutput(
        address=Address.from_primitive(
            "addr1wyd8cezjr0gcf8nfxuc9trd4hs7ec520jmkwkqzywx6l5jg0al0ya"
        ),
        amount=0,
    )
    oracle_script_hash = ScriptHash(bytes.fromhex("00" * 28))

    # Apply parameters
    print("\nApplying parameters to contracts...")
    parameterized_spend = contracts.apply_spend_params(config)
    parameterized_mint = contracts.apply_mint_params(
        utxo_ref, config, oracle_script_hash
    )

    # Display contract information
    display_contract_info(parameterized_spend, "Spending Validator")
    display_contract_info(parameterized_mint, "Minting Policy")

    # Dump contract artifacts
    dump_dir = Path(args.dump_dir)
    print(f"\nDumping contract artifacts to {dump_dir}")

    spend_dir = dump_dir / "spend"
    mint_dir = dump_dir / "mint"

    safe_dump_artifacts(parameterized_spend, spend_dir)
    safe_dump_artifacts(parameterized_mint, mint_dir)

    print("\nArtifacts dumped successfully!")


if __name__ == "__main__":
    main()

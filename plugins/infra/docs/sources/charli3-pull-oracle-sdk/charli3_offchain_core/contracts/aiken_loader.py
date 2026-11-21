"""Aiken contract loader for the Charli3 Oracle"""

import json
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, ClassVar, TypedDict

from pycardano import (
    PlutusV3Script,
    ScriptHash,
    UTxO,
)

from charli3_offchain_core.contracts.plutus_v3_contract import PlutusV3Contract, Purpose
from charli3_offchain_core.models.oracle_datums import (
    NftsConfiguration,
    OracleConfiguration,
    OracleDatum,
    OutputReference,
)
from charli3_offchain_core.models.oracle_redeemers import (
    MintingRedeemer,
    OracleRedeemer,
)


class OracleValidatorType(str, Enum):
    """Oracle validator types."""

    SPEND = "oracle.oracle_manager.spend"
    MINT = "oracle.oracle_nfts.mint"


class ValidatorConfig(TypedDict, total=False):
    """Type definition for validator configuration."""

    datum_type: tuple[str, type[OracleDatum]]
    redeemer_type: tuple[str, type[MintingRedeemer | OracleRedeemer]]
    parameter_types: list[tuple[str, type[Any]]]
    purpose: list[Purpose]


def create_validator(
    validator: dict[str, Any], config: ValidatorConfig
) -> PlutusV3Contract:
    """Create PlutusV3Contract from validator config."""
    return PlutusV3Contract(
        contract=PlutusV3Script(bytes.fromhex(validator["compiledCode"])),
        title=validator["title"],
        version="1.0.0",
        **config
    )


@dataclass
class OracleContracts:
    """Oracle spend validator and mint policy container."""

    spend: PlutusV3Contract
    mint: PlutusV3Contract

    VALIDATOR_CONFIGS: ClassVar[dict[OracleValidatorType, ValidatorConfig]] = {
        OracleValidatorType.SPEND: {
            "datum_type": ("own_datum", OracleDatum),
            "redeemer_type": ("redeemer", OracleRedeemer),
            "parameter_types": [("config", OracleConfiguration)],
            "purpose": [Purpose.spending],
        },
        OracleValidatorType.MINT: {
            "redeemer_type": ("redeemer", MintingRedeemer),
            "parameter_types": [("nfts_config", NftsConfiguration)],
            "purpose": [Purpose.minting],
        },
    }

    ERROR_MESSAGES: ClassVar[dict[str, str]] = {
        "plutus_version": "Only Plutus V3 contracts supported",
        "missing_validators": "Missing required validators",
        "invalid_blueprint": "Invalid blueprint: {error}",
    }

    @classmethod
    def from_blueprint(cls, blueprint_path: str | Path) -> "OracleContracts":
        """Load Oracle contracts from blueprint."""
        try:
            blueprint = json.loads(Path(blueprint_path).read_text(encoding="utf-8"))

            if blueprint["preamble"].get("plutusVersion") != "v3":
                raise ValueError(cls.ERROR_MESSAGES["plutus_version"])

            validators = {v["title"]: v for v in blueprint["validators"]}
            required = set(OracleValidatorType)

            if not all(t.value in validators for t in required):
                raise ValueError(cls.ERROR_MESSAGES["missing_validators"])

            contracts = {
                "spend": create_validator(
                    validators[OracleValidatorType.SPEND.value],
                    cls.VALIDATOR_CONFIGS[OracleValidatorType.SPEND],
                ),
                "mint": create_validator(
                    validators[OracleValidatorType.MINT.value],
                    cls.VALIDATOR_CONFIGS[OracleValidatorType.MINT],
                ),
            }

            return cls(**contracts)

        except (json.JSONDecodeError, FileNotFoundError) as e:
            raise ValueError(
                cls.ERROR_MESSAGES["invalid_blueprint"].format(error=e)
            ) from e

    def apply_spend_params(self, config: OracleConfiguration) -> PlutusV3Contract:
        """Apply parameters to spend validator."""
        return self.spend.apply_parameter(config)

    def apply_mint_params(
        self,
        utxo_ref: UTxO,
        config: OracleConfiguration,
        oracle_script_hash: ScriptHash,
    ) -> PlutusV3Contract:
        """Apply parameters to mint policy."""
        tx_ref = OutputReference(
            utxo_ref.input.transaction_id.payload, utxo_ref.input.index
        )
        return self.mint.apply_parameter(
            NftsConfiguration(tx_ref, config, oracle_script_hash.to_primitive())
        )

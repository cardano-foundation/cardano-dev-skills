""" Module for PlutusV3Contract class, an extension of PlutusContract for Plutus V3 scripts """

import json
import typing

import uplc.ast
from opshin.builder import PlutusContract, Purpose
from opshin.util import datum_to_cbor
from pycardano import Datum, PlutusV3Script
from uplc import flatten


class PlutusV3Contract(PlutusContract):
    """Extension of PlutusContract for Plutus V3 scripts."""

    def __init__(
        self,
        contract: PlutusV3Script,
        datum_type: tuple[str, type[Datum]] | None = None,
        redeemer_type: tuple[str, type[Datum]] | None = None,
        parameter_types: list[tuple[str, type[Datum]]] | None = None,
        purpose: typing.Iterable[Purpose] = (Purpose.any,),
        version: str | None = "1.0.0",
        title: str = "validator",
        description: str | None = None,
        license: str | None = None,
    ) -> None:
        super().__init__(
            contract=contract,
            datum_type=datum_type,
            redeemer_type=redeemer_type,
            parameter_types=parameter_types or [],
            purpose=purpose,
            version=version,
            title=title,
            description=description or "aiken '1.0.0' Smart Contract (V3)",
            license=license,
        )

    @property
    def plutus_json(self) -> str:
        """Return Plutus V3 script JSON representation."""
        return json.dumps(
            {
                "type": "PlutusScriptV3",
                "description": self.description,
                "cborHex": self.cbor_hex,
            },
            indent=2,
        )

    @property
    def blueprint(self) -> dict:
        """Return blueprint with V3 specification."""
        blueprint_data = super().blueprint
        blueprint_data["preamble"]["plutusVersion"] = "v3"
        return blueprint_data

    def apply_parameter(self, *args: Datum) -> "PlutusV3Contract":
        """Apply parameters to contract."""
        if len(self.parameter_types) < len(args):
            raise ValueError(
                f"Too many parameters: allowed {len(self.parameter_types)}, got {len(args)}"
            )

        new_params = self.parameter_types[len(args) :]
        new_contract = apply_parameters(self.contract, *args)

        return PlutusV3Contract(
            new_contract,
            self.datum_type,
            self.redeemer_type,
            new_params,
            self.purpose,
            self.version,
            self.title,
            self.description,
        )


def apply_parameters(script: PlutusV3Script, *args: Datum) -> PlutusV3Script:
    """Apply parameters to PlutusV3Script."""
    return _build(_apply_parameters(uplc.unflatten(script), *args))


def _apply_parameters(script: uplc.ast.Program, *args: Datum) -> uplc.ast.Program:
    """Apply parameters to UPLC program."""
    code = script.term
    for d in args:
        code = uplc.ast.Apply(
            code,
            (
                uplc.ast.data_from_cbor(datum_to_cbor(d))
                if not isinstance(d, uplc.ast.Constant)
                else d
            ),
        )
    return uplc.ast.Program((1, 0, 0), code)


def _build(contract: uplc.ast.Program) -> PlutusV3Script:
    """Build PlutusV3Script from UPLC program."""
    return PlutusV3Script(flatten(contract))

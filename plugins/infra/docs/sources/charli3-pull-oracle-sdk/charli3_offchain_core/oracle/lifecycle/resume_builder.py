"""Resume oracle transaction builder."""

from copy import deepcopy
from typing import Any

from pycardano import (
    Address,
    ExtendedSigningKey,
    NativeScript,
    PaymentSigningKey,
    Redeemer,
    UTxO,
)

from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.oracle_datums import (
    NoDatum,
    OracleSettingsVariant,
)
from charli3_offchain_core.models.oracle_redeemers import ManageSettings, ResumeOracle
from charli3_offchain_core.oracle.exceptions import PauseError
from charli3_offchain_core.oracle.lifecycle.base import BaseBuilder, LifecycleTxResult
from charli3_offchain_core.oracle.utils.common import get_reference_script_utxo
from charli3_offchain_core.oracle.utils.state_checks import (
    get_oracle_settings_by_policy_id,
    is_oracle_paused,
)


class ResumeBuilder(BaseBuilder):
    """Builds oracle resume transaction."""

    REDEEMER = Redeemer(ManageSettings(redeemer=ResumeOracle()))
    FEE_BUFFER = 10_000

    async def build_tx(
        self,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        policy_hash: Any,
        script_address: Address,
        utxos: list[UTxO],
        ref_script_config: ReferenceScriptConfig,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
    ) -> LifecycleTxResult:
        try:
            settings_datum, settings_utxo = get_oracle_settings_by_policy_id(
                utxos, policy_hash
            )
            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                ref_script_config,
                script_address,
            )

            if not script_utxo:
                raise ValueError("Reference script UTxO not found")

            if not is_oracle_paused(settings_datum):
                raise PauseError("Oracle not in pause period")

            modified_datum = deepcopy(settings_datum)
            modified_settings_utxo = deepcopy(settings_utxo)
            modified_datum.pause_period_started_at = NoDatum()

            modified_settings_utxo.output.datum = OracleSettingsVariant(modified_datum)

            modified_settings_utxo.output.datum_hash = None

            validity_start = self.chain_query.last_block_slot
            validity_end = validity_start + (
                settings_datum.time_uncertainty_platform // 1000
            )

            tx = await self.tx_manager.build_script_tx(
                script_inputs=[
                    (
                        settings_utxo,
                        self.REDEEMER,
                        script_utxo,
                    ),
                    (platform_utxo, None, platform_script),
                ],
                script_outputs=[modified_settings_utxo.output, platform_utxo.output],
                validity_start=validity_start,
                validity_end=validity_end,
                fee_buffer=self.FEE_BUFFER,
                change_address=change_address,
                signing_key=signing_key,
            )

            return LifecycleTxResult(
                transaction=tx, settings_utxo=modified_settings_utxo
            )

        except Exception as e:
            raise ValueError(f"Failed to build resume transaction: {e!s}") from e

"""Pause oracle transaction builder."""

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
    OracleSettingsDatum,
    OracleSettingsVariant,
    SomePosixTime,
)
from charli3_offchain_core.models.oracle_redeemers import ManageSettings, PauseOracle
from charli3_offchain_core.oracle.exceptions import PauseError
from charli3_offchain_core.oracle.lifecycle.base import BaseBuilder, LifecycleTxResult
from charli3_offchain_core.oracle.utils.common import get_reference_script_utxo
from charli3_offchain_core.oracle.utils.state_checks import (
    get_oracle_settings_by_policy_id,
    is_oracle_paused,
)


class PauseBuilder(BaseBuilder):
    """Builds oracle pause transaction"""

    REDEEMER = Redeemer(ManageSettings(redeemer=PauseOracle()))
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

            if is_oracle_paused(settings_datum):
                raise PauseError("Oracle already in pause period")

            pause_time_ms, validity_start, validity_end = (
                self._get_pause_time_and_slot_ranges(settings_datum)
            )

            modified_settings_utxo = deepcopy(settings_utxo)
            modified_settings_datum = deepcopy(settings_datum)
            modified_settings_datum.pause_period_started_at = SomePosixTime(
                pause_time_ms
            )

            modified_settings_utxo.output.datum = OracleSettingsVariant(
                modified_settings_datum
            )
            modified_settings_utxo.output.datum_hash = None

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
            raise ValueError(f"Failed to build pause transaction: {e!s}") from e

    def _get_pause_time_and_slot_ranges(
        self, settings_datum: OracleSettingsDatum
    ) -> tuple[int, int, int]:
        """Get pause time and slot ranges."""
        current_slot = self.chain_query.last_block_slot
        validity_end = current_slot + (settings_datum.time_uncertainty_platform // 1000)
        conversion = self.chain_query.config.network_config.slot_to_posix
        pause_time_ms = (conversion(current_slot) + conversion(validity_end)) // 2
        return pause_time_ms, current_slot, validity_end

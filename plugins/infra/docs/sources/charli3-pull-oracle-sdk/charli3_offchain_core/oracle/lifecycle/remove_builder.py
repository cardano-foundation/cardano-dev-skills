"""Remove oracle transaction builder."""

import time
from datetime import datetime, timezone

from pycardano import (
    Address,
    Asset,
    AssetName,
    ExtendedSigningKey,
    MultiAsset,
    NativeScript,
    PaymentSigningKey,
    Redeemer,
    ScriptHash,
    TransactionOutput,
    UTxO,
)

from charli3_offchain_core.blockchain.transactions import (
    TransactionConfig,
    TransactionManager,
)
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.oracle_datums import OracleSettingsDatum
from charli3_offchain_core.models.oracle_redeemers import (
    Burn,
    ManageSettings,
    RemoveOracle,
)
from charli3_offchain_core.oracle.exceptions import PauseError, ValidationError
from charli3_offchain_core.oracle.lifecycle.base import BaseBuilder, LifecycleTxResult
from charli3_offchain_core.oracle.utils.common import get_reference_script_utxo
from charli3_offchain_core.oracle.utils.state_checks import (
    get_oracle_settings_by_policy_id,
    is_oracle_paused,
)


class RemoveBuilder(BaseBuilder):
    """Builds oracle remove transaction that burns all NFTs and cleans up UTxOs."""

    REDEEMER = Redeemer(ManageSettings(redeemer=RemoveOracle()))
    FEE_BUFFER = 10_000
    EXTRA_COLLATERAL = 10_000_000

    TOKEN_CORE_SETTINGS = "C3CS"  # noqa

    async def build_tx(
        self,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        policy_hash: ScriptHash,
        script_address: Address,
        utxos: list[UTxO],
        ref_script_config: ReferenceScriptConfig,
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        pause_period: int,
    ) -> LifecycleTxResult:
        """Build transaction to remove oracle and burn NFTs."""
        self.tx_manager = TransactionManager(
            self.chain_query, TransactionConfig(extra_collateral=self.EXTRA_COLLATERAL)
        )
        try:
            settings_datum, settings_utxo = get_oracle_settings_by_policy_id(
                utxos, policy_hash
            )
            self._raise_for_status(settings_datum, pause_period)

            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                ref_script_config,
                script_address,
            )
            minting_script = await self.chain_query.get_plutus_script(policy_hash)

            # Calculate validity range
            validity_start_slot = self.chain_query.last_block_slot
            validity_end_slot = validity_start_slot + (
                settings_datum.time_uncertainty_platform // 1000
            )

            burn_value = self._calculate_burn_tokens(
                policy_hash=policy_hash,
            )

            ada_collect_utxo = self._collect_ada_from_utxos(
                [
                    settings_utxo,
                ],
                change_address,
            )

            script_inputs = [
                (settings_utxo, self.REDEEMER, script_utxo),
                (platform_utxo, None, platform_script),
            ]

            tx = await self.tx_manager.build_script_tx(
                script_inputs=script_inputs,
                script_outputs=[platform_utxo.output, ada_collect_utxo],
                validity_start=validity_start_slot,
                validity_end=validity_end_slot,
                fee_buffer=self.FEE_BUFFER,
                change_address=change_address,
                signing_key=signing_key,
                mint=burn_value,
                mint_redeemer=Redeemer(Burn()),
                mint_script=minting_script,
            )

            return LifecycleTxResult(transaction=tx, settings_utxo=None)

        except Exception as e:
            raise ValidationError(f"Failed to build remove transaction: {e}") from e

    def _calculate_burn_tokens(
        self,
        policy_hash: ScriptHash,
    ) -> MultiAsset:
        """Calculate tokens to burn based on provided UTxO lists."""
        burn_value = MultiAsset()
        policy_assets = burn_value[policy_hash] = Asset()

        policy_assets[AssetName(self.TOKEN_CORE_SETTINGS.encode())] = -1

        return burn_value

    def _collect_ada_from_utxos(
        self, utxos: list[UTxO], change_address: Address
    ) -> TransactionOutput:
        """return utxo output with collected amount from all to be consumed utxos."""
        ada_collected = sum(utxo.output.amount.coin for utxo in utxos)
        return TransactionOutput(address=change_address, amount=ada_collected)

    def _raise_for_status(
        self, settings_datum: OracleSettingsDatum, pause_period: int
    ) -> None:
        """Raise errors if conditions for removal not met"""
        if not is_oracle_paused(settings_datum):
            raise PauseError("Pause period has not started")
        current_ts = round(time.time_ns() * 1e-6)
        pause_period_end = settings_datum.pause_period_started_at.value + pause_period
        if current_ts < pause_period_end:
            raise PauseError(
                f"Pause period has not ended yet, wait till {datetime.fromtimestamp(pause_period_end / 1000, tz=timezone.utc)}"
            )

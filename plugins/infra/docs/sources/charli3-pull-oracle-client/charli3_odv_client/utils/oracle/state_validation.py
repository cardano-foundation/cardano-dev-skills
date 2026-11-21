"""Utilities for validating and managing oracle state transitions."""

import logging
from collections.abc import Sequence

from pycardano import ScriptHash, UTxO

from charli3_odv_client.models.datums import (
    AggState,
    OracleSettingsDatum,
    OracleSettingsVariant,
    RewardAccountDatum,
    RewardAccountVariant,
    SomePosixTime,
)
from charli3_odv_client.exceptions import StateValidationError
from charli3_odv_client.utils.oracle import utxo_filters

logger = logging.getLogger(__name__)


def convert_cbor_to_reward_accounts(account_utxos: Sequence[UTxO]) -> list[UTxO]:
    """Convert CBOR encoded NodeDatum objects to their corresponding Python objects."""
    result: list[UTxO] = []
    for utxo in account_utxos:
        if utxo.output.datum and not isinstance(
            utxo.output.datum, RewardAccountVariant
        ):
            if utxo.output.datum.cbor:
                utxo.output.datum = RewardAccountVariant.from_cbor(
                    utxo.output.datum.cbor
                )
                result.append(utxo)
        elif utxo.output.datum and isinstance(utxo.output.datum, RewardAccountVariant):
            result.append(utxo)
    return result


def convert_cbor_to_agg_states(agg_state_utxos: Sequence[UTxO]) -> list[UTxO]:
    """Convert CBOR encoded agg state UTxOs to Python objects."""
    result: list[UTxO] = []
    for utxo in agg_state_utxos:
        if utxo.output.datum and not isinstance(utxo.output.datum, AggState):
            if utxo.output.datum.cbor:
                utxo.output.datum = AggState.from_cbor(utxo.output.datum.cbor)
                result.append(utxo)
        elif utxo.output.datum and isinstance(utxo.output.datum, AggState):
            result.append(utxo)
    return result


def filter_valid_agg_states(utxos: Sequence[UTxO], current_time: int) -> list[UTxO]:
    """Filter UTxOs for empty or expired aggregation states."""
    utxos_with_datum = convert_cbor_to_agg_states(utxos)

    return [
        utxo
        for utxo in utxos_with_datum
        if utxo.output.datum
        and isinstance(utxo.output.datum, AggState)
        and (
            utxo.output.datum.price_data.is_empty
            or (utxo.output.datum.price_data.is_expired(current_time))
        )
    ]


def filter_reward_account(utxos: Sequence[UTxO]) -> list[UTxO]:
    """Filter UTxOs for empty reward transport states."""

    utxos_with_datum = convert_cbor_to_reward_accounts(utxos)

    return [
        utxo
        for utxo in utxos_with_datum
        if utxo.output.datum
        and isinstance(utxo.output.datum, RewardAccountVariant)
        and isinstance(utxo.output.datum.datum, RewardAccountDatum)
    ]


def get_oracle_settings_by_policy_id(
    utxos: Sequence[UTxO], policy_id: ScriptHash
) -> tuple[OracleSettingsDatum, UTxO]:
    """Get oracle settings datum by policy ID."""
    try:
        settings_utxos = utxo_filters.filter_utxos_by_token_name(
            utxos, policy_id, "C3CS"
        )
        if not settings_utxos:
            raise StateValidationError("No oracle settings UTxO found")

        settings_utxo = settings_utxos[0]

        if settings_utxo.output.datum and not isinstance(
            settings_utxo.output.datum, OracleSettingsVariant
        ):
            settings_utxo.output.datum = OracleSettingsVariant.from_cbor(
                settings_utxo.output.datum.cbor
            )

        return settings_utxo.output.datum.datum, settings_utxo

    except Exception as e:
        raise StateValidationError(f"Failed to get oracle settings: {e}") from e


def get_reward_account_by_policy_id(
    utxos: Sequence[UTxO], policy_id: ScriptHash
) -> tuple[RewardAccountDatum, UTxO]:
    """Get reward account datum by policy ID."""
    try:
        reward_account_utxos = utxo_filters.filter_utxos_by_token_name(
            utxos, policy_id, "C3RA"
        )
        if not reward_account_utxos:
            raise StateValidationError("No reward account UTxO found")

        reward_account_utxo = reward_account_utxos[0]

        if reward_account_utxo.output.datum and not isinstance(
            reward_account_utxo.output.datum, RewardAccountVariant
        ):
            reward_account_utxo.output.datum = RewardAccountVariant.from_cbor(
                reward_account_utxo.output.datum.cbor
            )

        return reward_account_utxo.output.datum.datum, reward_account_utxo

    except Exception as e:
        raise StateValidationError(f"Failed to get reward account: {e}") from e


def is_oracle_paused(settings: OracleSettingsDatum) -> bool:
    """Check if oracle is in pause period."""
    return isinstance(settings.pause_period_started_at, SomePosixTime)

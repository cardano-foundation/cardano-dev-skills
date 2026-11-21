"""Chain interaction utilities for oracle operations."""

import time
import asyncio
from typing import Any

from pycardano import (
    Address,
    AssetName,
    RawPlutusData,
    ScriptHash,
    TransactionInput,
    TransactionId,
    UTxO,
    plutus_script_hash,
)

from charli3_odv_client.blockchain.chain_query import ChainQuery
from charli3_odv_client.blockchain.transactions import TransactionManager
from charli3_odv_client.config.reference_script import ReferenceScriptConfig
from charli3_odv_client.models.datums import (
    AggState,
    SomeAsset,
)
from charli3_odv_client.exceptions import (
    OracleTransactionError,
    ValidationError,
)


async def get_script_utxos(
    script_address: str | Address, tx_manager: TransactionManager
) -> list[UTxO]:
    """Get and validate UTxOs at script address."""
    try:
        utxos = await tx_manager.chain_query.get_utxos(script_address)
        if not utxos:
            raise ValidationError("No UTxOs found at script address")
        return utxos
    except Exception as e:
        raise OracleTransactionError(f"Failed to get script UTxOs: {e}") from e


async def get_fee_rate_reference_utxo(
    chain_query: ChainQuery, rate_nft: SomeAsset
) -> UTxO:
    """Get fee rate UTxOs and return the most fresh Aggregation State."""
    try:
        rate_policy_id = ScriptHash.from_primitive(rate_nft.asset.policy_id)
        rate_name = AssetName.from_primitive(rate_nft.asset.name)

        utxos = await chain_query.get_utxos_with_asset_from_kupo(
            rate_policy_id, rate_name
        )
        if not utxos:
            raise ValidationError("No UTxOs found with fee rate asset")

        # Parse datums for all UTxOs
        for utxo in utxos:
            if utxo.output.datum and utxo.output.datum.cbor:
                try:
                    utxo.output.datum = AggState.from_cbor(utxo.output.datum.cbor)
                except Exception:
                    continue  # Skip UTxOs with invalid datums

        current_time = int(time.time() * 1000)  # Convert to milliseconds

        # Filter for valid, non-expired aggregation states
        valid_agg_states = [
            utxo
            for utxo in utxos
            if utxo.output.datum
            and isinstance(utxo.output.datum, AggState)
            and utxo.output.datum.price_data.is_valid
            and utxo.output.datum.price_data.is_active(current_time)
        ]

        if not valid_agg_states:
            raise ValidationError("No valid fee rate datum found with fresh timestamp")

        # Sort by expiration time (descending) and return the freshest
        valid_agg_states.sort(
            key=lambda utxo: utxo.output.datum.price_data.get_expiration_time,
            reverse=True,
        )

        return valid_agg_states[0]

    except Exception as e:
        raise OracleTransactionError(f"Failed to get fee rate UTxOs: {e}") from e


async def get_reference_script_utxo(
    chain_query: ChainQuery,
    ref_script_config: ReferenceScriptConfig,
    script_address: Address | str,
) -> UTxO:
    """Find reference script UTxO.

    Raises:
        ValidationError: If no reference script UTxO is found
    """

    try:
        if isinstance(script_address, str):
            script_address = Address.from_primitive(script_address)

        reference_script_address = (
            Address.from_primitive(ref_script_config.address)
            if ref_script_config.address
            else script_address
        )

        # Get script hash
        script_hash = script_address.payment_part

        if ref_script_config.utxo_reference:
            utxo_reference = TransactionInput(
                transaction_id=TransactionId(
                    bytes.fromhex(ref_script_config.utxo_reference.transaction_id)
                ),
                index=ref_script_config.utxo_reference.output_index,
            )
            utxo = chain_query.get_utxo_by_ref_kupo(utxo_reference)
            if utxo is None:
                raise ValidationError(
                    f"No matching utxo found {ref_script_config.utxo_reference}"
                )
            if utxo.output.script is None:
                raise ValidationError(
                    f"No utxos with script by reference {ref_script_config.utxo_reference}"
                )
            if plutus_script_hash(utxo.output.script) == script_hash:
                return utxo
            raise ValidationError(
                f"Not matching script hash {script_hash} for utxo reference {ref_script_config.utxo_reference}"
            )

        # Get UTxOs at script address
        utxos = await chain_query.get_utxos(reference_script_address)
        reference_utxos = [utxo for utxo in utxos if utxo.output.script]

        if not reference_utxos:
            raise ValidationError(
                f"No utxos with script at address {reference_script_address}"
            )

        for utxo in reference_utxos:
            if plutus_script_hash(utxo.output.script) == script_hash:
                return utxo

        raise ValidationError(f"No matching script hash {script_hash}")

    except Exception as e:  # pylint: disable=broad-except
        raise ValidationError("No reference script UTxO found") from e


def try_parse_datum(datum: RawPlutusData, datum_class: Any) -> Any:
    """Attempt to parse a datum using the provided class."""
    try:
        return datum_class.from_cbor(datum.to_cbor())
    except Exception:
        return None


async def query_oracle_state(
    script_address: Address,
    policy_id: ScriptHash,
    tx_manager: TransactionManager,
) -> dict[str, Any]:
    """Query complete oracle state information."""
    try:
        utxos = await get_script_utxos(script_address, tx_manager)

        from charli3_odv_client.utils.oracle.state_validation import check_oracle_health

        health_report = check_oracle_health(utxos, policy_id)

        from charli3_odv_client.utils.oracle.utxo_filters import (
            filter_utxos_by_token_name,
            calculate_total_value,
        )

        # Get UTxO counts by type
        settings_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3CS")
        reward_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3RA")
        transport_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3RT")
        agg_state_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3AS")

        # Calculate total value locked
        total_value = calculate_total_value(utxos)

        return {
            "health": health_report,
            "utxo_counts": {
                "total": len(utxos),
                "settings": len(settings_utxos),
                "reward_account": len(reward_utxos),
                "transport": len(transport_utxos),
                "agg_state": len(agg_state_utxos),
                "reference_scripts": len([u for u in utxos if u.output.script]),
            },
            "total_value_locked": {
                "ada": total_value.coin / 1_000_000,  # Convert to ADA
                "tokens": (
                    len(total_value.multi_asset.keys())
                    if total_value.multi_asset
                    else 0
                ),
            },
            "script_address": str(script_address),
            "policy_id": str(policy_id),
        }

    except Exception as e:
        return {
            "error": str(e),
            "script_address": str(script_address),
            "policy_id": str(policy_id),
        }


async def wait_for_utxo_update(
    script_address: Address,
    expected_utxo_count: int,
    tx_manager: TransactionManager,
    max_attempts: int = 10,
    delay_seconds: int = 5,
) -> bool:
    """Wait for UTxO state to update after transaction submission."""

    for attempt in range(max_attempts):
        try:
            utxos = await get_script_utxos(script_address, tx_manager)
            if len(utxos) == expected_utxo_count:
                return True

            if attempt < max_attempts - 1:
                await asyncio.sleep(delay_seconds)

        except Exception:
            if attempt < max_attempts - 1:
                await asyncio.sleep(delay_seconds)

    return False


def validate_oracle_utxo_structure(
    utxos: list[UTxO], policy_id: ScriptHash
) -> dict[str, Any]:
    """Validate oracle UTxO structure and return analysis."""
    from charli3_odv_client.utils.oracle.utxo_filters import filter_utxos_by_token_name

    issues = []
    warnings = []

    # Check for required UTxO types
    settings_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3CS")
    reward_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3RA")
    transport_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3RT")
    agg_state_utxos = filter_utxos_by_token_name(utxos, policy_id, "C3AS")

    # Validate counts
    if len(settings_utxos) == 0:
        issues.append("No oracle settings UTxO found")
    elif len(settings_utxos) > 1:
        issues.append(f"Multiple oracle settings UTxOs found: {len(settings_utxos)}")

    if len(reward_utxos) == 0:
        issues.append("No reward account UTxO found")
    elif len(reward_utxos) > 1:
        issues.append(f"Multiple reward account UTxOs found: {len(reward_utxos)}")

    if len(transport_utxos) == 0:
        issues.append("No transport UTxOs found")
    elif len(transport_utxos) < 4:
        warnings.append(
            f"Low transport UTxO count: {len(transport_utxos)} (recommended: 4+)"
        )

    if len(agg_state_utxos) == 0:
        issues.append("No aggregation state UTxOs found")

    # Check pairing
    if len(transport_utxos) != len(agg_state_utxos):
        issues.append(
            f"Mismatched transport/agg-state counts: {len(transport_utxos)}/{len(agg_state_utxos)}"
        )

    # Check for reference script
    reference_scripts = [utxo for utxo in utxos if utxo.output.script]
    if not reference_scripts:
        warnings.append("No reference script UTxO found")

    return {
        "valid": len(issues) == 0,
        "issues": issues,
        "warnings": warnings,
        "counts": {
            "settings": len(settings_utxos),
            "reward_account": len(reward_utxos),
            "transport": len(transport_utxos),
            "agg_state": len(agg_state_utxos),
            "reference_scripts": len(reference_scripts),
        },
    }

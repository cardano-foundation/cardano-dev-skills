"""Common utility functions for oracle operations."""

import time
from typing import Any

from pycardano import (
    Address,
    AssetName,
    RawPlutusData,
    ScriptHash,
    TransactionId,
    TransactionInput,
    UTxO,
    plutus_script_hash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.message import SignedOracleNodeMessage
from charli3_offchain_core.models.oracle_datums import (
    AggState,
    SomeAsset,
)
from charli3_offchain_core.models.oracle_redeemers import AggregateMessage

from ..exceptions import TransactionError, ValidationError


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
        raise TransactionError(f"Failed to get script UTxOs: {e}") from e


def get_fee_rate_reference_utxo(chain_query: ChainQuery, rate_nft: SomeAsset) -> UTxO:
    """Get fee rate UTxOs and return the most fresh Aggregation State."""
    try:
        rate_policy_id = ScriptHash.from_primitive(rate_nft.asset.policy_id)
        rate_name = AssetName.from_primitive(rate_nft.asset.name)

        utxos = chain_query.get_utxos_with_asset_from_kupo(rate_policy_id, rate_name)
        if not utxos:
            raise ValidationError("No UTxOs found with asset name")

        for utxo in utxos:
            if utxo.output.datum and utxo.output.datum.cbor:
                utxo.output.datum = AggState.from_cbor(utxo.output.datum.cbor)

        current_time = int(time.time_ns() * 1e-6)
        non_expired_agg_states = [
            utxo
            for utxo in utxos
            if utxo.output.datum
            and isinstance(utxo.output.datum, AggState)
            and utxo.output.datum.price_data.is_valid
            and utxo.output.datum.price_data.is_active(current_time)
        ]
        if not non_expired_agg_states:
            raise ValidationError(
                "No Aggregation State Rate datum with fresh timestamp"
            )

        non_expired_agg_states.sort(
            key=lambda utxo: utxo.output.datum.price_data.get_expiration_time
        )
        return non_expired_agg_states.pop()
    except Exception as e:
        raise TransactionError(f"Failed to get fee rate UTxOs: {e}") from e


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


def build_aggregate_message(
    nodes_messages: list[SignedOracleNodeMessage],
) -> AggregateMessage:
    if not nodes_messages:
        raise ValueError("No node messages provided")

    for msg in nodes_messages:
        msg.validate_signature()

    feeds = {}
    for msg in nodes_messages:
        vkh = msg.verification_key.hash()
        print(f"VKH length: {len(vkh.payload)} bytes (should be 28)")
        print(f"VKH hex: {vkh.to_primitive().hex()}")

        feeds[vkh] = msg.message.feed

    # Sort ONLY by feed value (ascending order)
    # VKH order does not matter - check_nodes_multisig handles unsorted VKHs

    sorted_feeds = dict(sorted(feeds.items(), key=lambda x: x[1]))
    return AggregateMessage(node_feeds_sorted_by_feed=sorted_feeds)


def try_parse_datum(datum: RawPlutusData, datum_class: Any) -> Any:
    """Attempt to parse a datum using the provided class."""
    try:
        return datum_class.from_cbor(datum.to_cbor())
    except Exception:
        return None

"""Validation functions for ODV aggregation related operations."""

import logging
from typing import Any

from pycardano import ScriptHash, Transaction

from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.models.base import PosixTime
from charli3_offchain_core.models.message import SignedOracleNodeMessage
from charli3_offchain_core.models.oracle_datums import (
    AggState,
    OracleSettingsDatum,
    RewardAccountVariant,
)
from charli3_offchain_core.oracle.exceptions import (
    AggregationError,
    DataError,
    NFTError,
    NodeNotRegisteredError,
    NodeValidationError,
    SignatureError,
    StateValidationError,
    TimestampError,
)
from charli3_offchain_core.oracle.utils.calc_methods import median
from charli3_offchain_core.oracle.utils.common import get_script_utxos, try_parse_datum
from charli3_offchain_core.oracle.utils.state_checks import (
    get_oracle_settings_by_policy_id,
    is_oracle_paused,
)

logger = logging.getLogger(__name__)


def validate_timestamp(tx_validity: dict[str, PosixTime], timestamp: PosixTime) -> None:
    """Validates if the given timestamp falls within the transaction validity window."""
    start = tx_validity.start if hasattr(tx_validity, "start") else tx_validity["start"]
    end = tx_validity.end if hasattr(tx_validity, "end") else tx_validity["end"]

    if not start <= timestamp <= end:
        raise TimestampError(
            f"Timestamp {timestamp} outside validity interval [{start}, {end}]"
        )


async def validate_is_node_registered(
    tx_manager: TransactionManager, oracle_addr: str, policy_id: str, node_vkh: str
) -> tuple[bool, OracleSettingsDatum]:
    """Verifies if the node is registered in oracle settings and returns registration status with settings."""
    try:
        utxos = await get_script_utxos(oracle_addr, tx_manager)
        settings_datum, settings_utxo = get_oracle_settings_by_policy_id(
            utxos, ScriptHash(bytes.fromhex(policy_id))
        )
        if settings_utxo is None:
            raise StateValidationError("Oracle settings not found")

        if is_oracle_paused(settings_datum):
            raise StateValidationError("Oracle is currently paused")

        if node_vkh not in settings_datum.nodes.node_map:
            raise NodeNotRegisteredError(f"Node {node_vkh} not registered")
        return True, settings_datum
    except Exception as e:
        if isinstance(e, (StateValidationError | NodeNotRegisteredError)):
            raise
        raise NodeValidationError(f"Node registration validation error: {e!s}") from e


def validate_node_message_signatures(
    node_messages: list[dict[str, Any]]
) -> list[SignedOracleNodeMessage]:
    """Validates signatures of node messages and returns list of serialized responses."""
    signed_messages: list[SignedOracleNodeMessage] = []
    try:
        for node_message in node_messages:
            signed_message = SignedOracleNodeMessage.model_validate(node_message)
            signed_messages.append(signed_message)
        return signed_messages
    except Exception as e:
        raise SignatureError(f"Signature validation error: {e!s}") from e


def validate_policy_id_in_messages(node_messages: list[SignedOracleNodeMessage]) -> str:
    """Validates Oracle NFT policy ID consistency across messages and returns the policy ID."""
    policy_ids = {data.message.oracle_nft_policy_id for data in node_messages}
    if len(policy_ids) == 1:
        return bytes.hex(policy_ids.pop())
    raise NFTError("Mismatch in oracle_nft_policy_id across messages") from None


def validate_node_updates_and_aggregation_median(
    signed_messages: list[SignedOracleNodeMessage], aggstate_datum: AggState
) -> bool:
    """Validates median calculation from signed messages against AggState datum."""
    try:
        if not isinstance(aggstate_datum, AggState):
            raise DataError("Provided datum is not of type AggState")

        if (
            aggstate_datum is None
            or not hasattr(aggstate_datum, "price_data")
            or not aggstate_datum.price_data.has_required_fields
        ):
            raise DataError("Invalid or missing AggState price data")

        feeds = [msg.message.feed for msg in signed_messages]
        if not feeds:
            raise AggregationError("No feeds provided in signed messages")

        calculated_median = median(feeds, len(feeds))
        datum_value = aggstate_datum.price_data.get_price
        if calculated_median != datum_value:
            raise AggregationError(
                f"Median mismatch: {calculated_median} vs {datum_value}"
            )

        return True

    except Exception as e:
        if isinstance(e, (DataError | AggregationError)):
            raise
        raise AggregationError(f"Median validation error: {e!s}") from e


def validate_transaction_datums(
    tx: Transaction, oracle_addr: str
) -> tuple[RewardAccountVariant, AggState]:
    """Extracts and validates reward account and aggregation state datums from transaction outputs."""
    reward_account_datum: RewardAccountVariant | None = None
    aggstate_datum: AggState | None = None

    for output in tx.transaction_body.outputs:
        if str(output.address) != oracle_addr or not output.datum:
            continue

        if reward_account_datum is None:
            reward_account_datum = try_parse_datum(output.datum, RewardAccountVariant)
        if aggstate_datum is None:
            aggstate_datum = try_parse_datum(output.datum, AggState)

        if reward_account_datum and aggstate_datum:
            break

    if not aggstate_datum:
        raise DataError("Missing or invalid AggState datum in transaction outputs")
    if not reward_account_datum:
        raise DataError(
            "Missing or invalid RewardAccountVariant in transaction outputs"
        )

    return reward_account_datum, aggstate_datum

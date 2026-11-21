"""Aggregation utility functions."""

from typing import Dict, List

from charli3_odv_client.models.message import SignedOracleNodeMessage
from charli3_odv_client.models.redeemers import AggregateMessage
from charli3_odv_client.utils.math import median


def build_aggregate_message(
    nodes_messages: list[SignedOracleNodeMessage],
) -> AggregateMessage:
    """Build aggregate message from node responses."""
    if not nodes_messages:
        raise ValueError("No node messages provided")

    for msg in nodes_messages:
        msg.validate_signature()

    feeds = {}
    for msg in nodes_messages:
        vkh = msg.verification_key.hash()

        feeds[vkh] = msg.message.feed

    sorted_feeds = dict(sorted(feeds.items(), key=lambda x: x[1]))
    return AggregateMessage(node_feeds_sorted_by_feed=sorted_feeds)


def calculate_median(feeds: List[int]) -> int:
    """Calculate median from list of feeds using the same algorithm as on-chain."""
    if not feeds:
        raise ValueError("Cannot calculate median of empty list")

    return median(feeds, len(feeds))


def validate_node_responses(
    responses: Dict[str, SignedOracleNodeMessage], min_responses: int = 1
) -> None:
    """Validate node responses meet minimum requirements."""

    if len(responses) < min_responses:
        raise ValueError(
            f"Insufficient responses: got {len(responses)}, need {min_responses}"
        )

    policy_ids = {msg.message.oracle_nft_policy_id for msg in responses.values()}
    if len(policy_ids) > 1:
        raise ValueError("Node messages have different policy IDs")

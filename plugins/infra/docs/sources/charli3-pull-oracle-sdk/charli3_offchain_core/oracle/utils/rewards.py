"""Reward calculation utilities for oracle operations."""

import math
from fractions import Fraction

from pycardano import Asset, AssetName, ScriptHash, UTxO, Value

from charli3_offchain_core.models.base import FeedVkh, NodeFeed
from charli3_offchain_core.models.oracle_datums import (
    IQR_APPLICABILITY_THRESHOLD,
    AggState,
    Nodes,
    RewardAccountDatum,
    RewardPrices,
)
from charli3_offchain_core.models.oracle_redeemers import AggregateMessage
from charli3_offchain_core.oracle.exceptions import DistributionError

# Typical coin precision, such as lovelace for ada
COIN_PRECISION: int = 1_000_000


def calculate_min_fee_amount(reward_prices: RewardPrices, node_count: int) -> int:
    """Calculate minimum fee amount."""
    try:
        min_fee = reward_prices.platform_fee
        min_fee += reward_prices.node_fee * node_count
        return min_fee
    except Exception as e:
        raise DistributionError(f"Failed to calculate minimum fee: {e}") from e


def scale_rewards_by_rate(reward_prices: RewardPrices, rate_datum: AggState) -> None:
    """Calculate new reward prices based on the fee rate."""
    rate = Fraction(rate_datum.price_data.get_price, COIN_PRECISION)

    def convert_reward(reward: int) -> int:
        return math.ceil(rate * Fraction(reward))

    reward_prices.node_fee = convert_reward(reward_prices.node_fee)
    reward_prices.platform_fee = convert_reward(reward_prices.platform_fee)


# def calculate_reward_distribution(
#     message: AggregateMessage,
#     iqr_fence_multiplier: int,
#     median_divergency_factor: int,
#     in_distribution: dict[FeedVkh, int],
#     node_reward_price: int,
#     nodes: dict[FeedVkh, PaymentVkh],
# ) -> dict[FeedVkh, int]:
#     """Calculate node rewards from transport UTxOs."""
#     try:
#         out_distribution = {}

#         rewarded_feed_nodes = consensus_by_iqr_and_divergency(
#             message.node_feeds_sorted_by_feed,
#             iqr_fence_multiplier,
#             median_divergency_factor,
#         )

#         for feed_vkh in set(nodes.keys()):
#             reward = node_reward_price if feed_vkh in rewarded_feed_nodes else 0
#             in_amount = in_distribution.get(feed_vkh, 0)
#             out_distribution[feed_vkh] = in_amount + reward

#         return out_distribution

#     except Exception as e:
#         raise DistributionError(f"Failed to calculate node rewards: {e}") from e


def calculate_reward_distribution(
    message: AggregateMessage,
    iqr_fence_multiplier: int,
    median_divergency_factor: int,
    in_distribution: dict[FeedVkh, int],
    node_reward_price: int,
    nodes: Nodes,
) -> dict[FeedVkh, int]:
    """Calculate node rewards from transport UTxOs."""
    try:
        out_distribution = {}

        rewarded_feed_nodes = consensus_by_iqr_and_divergency(
            message.node_feeds_sorted_by_feed,
            iqr_fence_multiplier,
            median_divergency_factor,
        )

        node_keys = set(nodes)

        for feed_vkh in node_keys:
            reward = node_reward_price if feed_vkh in rewarded_feed_nodes else 0
            in_amount = in_distribution.get(feed_vkh, 0)
            out_distribution[feed_vkh] = in_amount + reward

        # Sort by VKH in ascending order before returning
        sorted_distribution = dict(
            sorted(out_distribution.items(), key=lambda x: x[0].payload)
        )
        return sorted_distribution

    except Exception as e:
        raise DistributionError(f"Failed to calculate node rewards: {e}") from e


def consensus_by_iqr_and_divergency(
    node_feeds: dict[FeedVkh, NodeFeed],
    iqr_fence_multiplier: int,
    median_divergency_factor: int,
) -> list[FeedVkh]:
    """
    Filter nodes based on IQR consensus.
    Uses divergency from the middle point (median) if IQR is not applicable.
    Returns list of node IDs that fall within the IQR fences.
    """
    node_feed_count = len(node_feeds)

    if node_feed_count == 0:
        raise RuntimeError("Empty nodes feeds list")

    if node_feed_count == 1:
        return [*node_feeds.keys()]

    # Convert percentage to multiplier
    multiplier = iqr_fence_multiplier / 100
    factor = median_divergency_factor / 1000

    # Get sorted values
    values = sorted(node_feeds.values())
    midpoint = quantile(values, node_feed_count, 0.5)

    if node_feed_count >= IQR_APPLICABILITY_THRESHOLD:
        # Calculate IQR fences
        lower_fence, upper_fence = iqr_fence(values, node_feed_count, multiplier)
        # Round fences
        lower_limit = round(lower_fence)
        upper_limit = round(upper_fence)

    if node_feed_count < IQR_APPLICABILITY_THRESHOLD or lower_limit == upper_limit:
        fence = midpoint * factor
        lower_limit = round(midpoint - fence)
        upper_limit = round(midpoint + fence)

    # Filter nodes within fences
    return [
        node_id
        for node_id, feed in node_feeds.items()
        if lower_limit <= feed <= upper_limit
    ]


def quantile(sorted_input: list[int], n: int, q: float) -> float:
    """
    Returns weighted average of two elements closest to quantile index q * (n - 1)

    Args:
        sorted_input: Sorted list of integers
        n: Length of the list
        q: Desired quantile (between 0 and 1)
    """
    # Calculate quantile index: q * (n - 1)
    n_sub_one = n - 1
    quantile_index = q * n_sub_one

    # Get integral and fractional parts
    j = int(quantile_index)  # floor
    g = quantile_index - j  # fractional part

    # Get j-th and (j+1)-th elements
    x_j = sorted_input[j]
    x_j_1 = sorted_input[j + 1]

    # Linear interpolation
    fst = (1 - g) * x_j
    snd = g * x_j_1

    return fst + snd


def iqr_fence(
    sorted_input: list[int], input_length: int, iqr_multiplier: float
) -> tuple[float, float]:
    """
    Calculate IQR fences for outlier detection

    Args:
        sorted_input: Sorted list of integers
        input_length: Length of the list
        iqr_multiplier: Multiplier for IQR fence calculation
    """
    # Calculate quartiles (25% and 75%)
    q25 = quantile(sorted_input, input_length, 0.25)
    q75 = quantile(sorted_input, input_length, 0.75)

    # Calculate IQR and fences
    iqr = q75 - q25
    fence = iqr_multiplier * iqr

    fence_lower = q25 - fence
    fence_upper = q75 + fence

    return (fence_lower, fence_upper)


def accumulate_node_rewards(
    current_datum: RewardAccountDatum,
    node_rewards: dict[FeedVkh, int],
    nodes: list[FeedVkh],
) -> list[int]:
    """Accumulate new rewards with existing rewards in datum format.

    Args:
        current_datum: Current reward account datum
        node_rewards: New rewards to add
        nodes: Ordered list of node IDs

    Returns:
        List of accumulated rewards in datum format
    """
    try:
        new_rewards = []
        for node_id in nodes:
            current_idx = len(new_rewards)
            current_reward = (
                current_datum.nodes_to_rewards[current_idx]
                if current_idx < len(current_datum.nodes_to_rewards)
                else 0
            )
            new_reward = current_reward + node_rewards.get(node_id, 0)
            new_rewards.append(new_reward)
        return new_rewards
    except Exception as e:
        raise DistributionError(f"Failed to accumulate rewards: {e}") from e


def calculate_total_fees(
    transports: list[UTxO],
    reward_token_hash: ScriptHash | None,
    reward_token_name: AssetName | None,
) -> int:
    """Calculate total fees from transport UTxOs."""
    try:
        if reward_token_hash and reward_token_name:
            return sum(
                transport.output.amount.multi_asset.get(reward_token_hash, {}).get(
                    reward_token_name, 0
                )
                for transport in transports
            )

        return sum(
            transport.output.datum.datum.aggregation.rewards_amount_paid
            for transport in transports
        )

    except Exception as e:
        raise DistributionError(f"Failed to calculate total fees: {e}") from e


def update_fee_tokens(
    output_amount: Value,
    reward_token_hash: ScriptHash | None,
    reward_token_name: AssetName | None,
    reward_amount: int,
) -> Value:
    """Update fee tokens in output amount.

    Args:
        output_amount: Reward Account Value
        reward_token_hash: Optional hash of the fee token script
        reward_token_name: Optional name of the fee token asset
        reward_amount: Amount of fees to add (defaults to 0)

    Returns:
        Value: Updated output amount object

    Raises:
        DistributionError: If fee token update fails
        ValueError: If fee_amount is negative
    """
    if reward_amount < 0:
        raise ValueError("Reward amount cannot be negative")

    if reward_amount == 0:
        return output_amount

    try:
        if reward_token_hash and reward_token_name:
            # Handle custom token rewards
            token_assets = output_amount.multi_asset.setdefault(
                reward_token_hash, Asset()
            )
            current_amount = token_assets.get(reward_token_name, 0)
            token_assets[reward_token_name] = current_amount + reward_amount
        else:
            # Handle ADA rewards
            output_amount.coin += reward_amount

        return output_amount

    except Exception as e:
        raise DistributionError(f"Failed to update reward tokens: {e}") from e

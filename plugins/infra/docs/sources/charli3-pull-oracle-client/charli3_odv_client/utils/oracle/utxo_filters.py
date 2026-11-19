"""Utilities for validating and filtering UTxOs based on asset criteria."""

from collections.abc import Sequence

from pycardano import Asset, AssetName, MultiAsset, ScriptHash, UTxO, Value

from charli3_odv_client.exceptions import ValidationError

from charli3_odv_client.utils.oracle.state_validation import (
    filter_valid_agg_states,
    filter_reward_account,
)


def filter_utxos_by_asset(utxos: Sequence[UTxO], asset: MultiAsset) -> list[UTxO]:
    """Filter UTxOs containing specific assets."""
    return [
        utxo
        for utxo in utxos
        if utxo.output.amount.multi_asset
        and all(
            policy_id in utxo.output.amount.multi_asset
            and all(
                token_name in utxo.output.amount.multi_asset[policy_id]
                and utxo.output.amount.multi_asset[policy_id][token_name] >= quantity
                for token_name, quantity in tokens.items()
            )
            for policy_id, tokens in asset.to_primitive().items()
        )
    ]


def filter_utxos_by_currency(utxos: Sequence[UTxO], currency: ScriptHash) -> list[UTxO]:
    """Filter UTxOs containing assets from a specific policy."""
    if not currency:
        raise ValidationError("Invalid currency: cannot be empty")

    return [
        utxo
        for utxo in utxos
        if utxo.output.amount.multi_asset and currency in utxo.output.amount.multi_asset
    ]


def filter_utxos_by_token_name(
    utxos: Sequence[UTxO], policy_id: ScriptHash, token_name: str
) -> list[UTxO]:
    """Filter UTxOs containing a specific token."""
    if not policy_id or not token_name:
        raise ValidationError("Invalid policy_id or token_name: cannot be empty")

    encoded_name = AssetName(
        token_name.encode() if isinstance(token_name, str) else token_name
    )

    return [
        utxo
        for utxo in utxos
        if (
            utxo.output.amount.multi_asset
            and policy_id in utxo.output.amount.multi_asset
            and encoded_name in utxo.output.amount.multi_asset[policy_id]
            and utxo.output.amount.multi_asset[policy_id][encoded_name] >= 1
        )
    ]


def has_required_tokens(utxo: UTxO, policy_id: bytes, token_names: list[str]) -> bool:
    """Check if UTxO contains all required tokens from a policy."""
    if not policy_id or not token_names:
        raise ValidationError("Invalid policy_id or token_names: cannot be empty")

    if not utxo.output.amount.multi_asset:
        return False

    policy_hash = ScriptHash(policy_id)
    if policy_hash not in utxo.output.amount.multi_asset:
        return False

    policy_tokens = utxo.output.amount.multi_asset[policy_hash]
    return all(
        token_name.encode() in policy_tokens and policy_tokens[token_name.encode()] > 0
        for token_name in token_names
    )


def filter_utxos_with_minimum_ada(utxos: Sequence[UTxO], min_ada: int) -> list[UTxO]:
    """Filter UTxOs that have at least the minimum ADA amount."""
    return [utxo for utxo in utxos if utxo.output.amount.coin >= min_ada]


def filter_utxos_with_datum(utxos: Sequence[UTxO]) -> list[UTxO]:
    """Filter UTxOs that have a datum attached."""
    return [utxo for utxo in utxos if utxo.output.datum is not None]


def filter_utxos_with_script(utxos: Sequence[UTxO]) -> list[UTxO]:
    """Filter UTxOs that have a script attached."""
    return [utxo for utxo in utxos if utxo.output.script is not None]


def group_utxos_by_policy(utxos: Sequence[UTxO]) -> dict[ScriptHash, list[UTxO]]:
    """Group UTxOs by their primary policy ID (first policy in multi_asset)."""
    groups = {}

    for utxo in utxos:
        if utxo.output.amount.multi_asset:
            policy_id = next(iter(utxo.output.amount.multi_asset.keys()))
            if policy_id not in groups:
                groups[policy_id] = []
            groups[policy_id].append(utxo)

    return groups


def find_utxo_by_asset_name(
    utxos: Sequence[UTxO], policy_id: ScriptHash, asset_name: str
) -> UTxO | None:
    """Find the first UTxO containing a specific asset."""
    filtered = filter_utxos_by_token_name(utxos, policy_id, asset_name)
    return filtered[0] if filtered else None


def calculate_total_value(utxos: Sequence[UTxO]) -> Value:
    """Calculate total value across multiple UTxOs."""
    total = Value(0)

    for utxo in utxos:
        total.coin += utxo.output.amount.coin

        if utxo.output.amount.multi_asset:
            if total.multi_asset is None:
                total.multi_asset = MultiAsset()

            for policy_id, assets in utxo.output.amount.multi_asset.items():
                if policy_id not in total.multi_asset:
                    total.multi_asset[policy_id] = Asset()

                for asset_name, quantity in assets.items():
                    current_amount = total.multi_asset[policy_id].get(asset_name, 0)
                    total.multi_asset[policy_id][asset_name] = current_amount + quantity

    return total


def find_account_pair(
    utxos: Sequence[UTxO], policy_id: ScriptHash, current_time: int
) -> tuple[UTxO, UTxO]:
    """Find account and agg state pair (empty or expired).

    Args:
        utxos: List of UTxOs to search
        policy_id: Policy ID for filtering tokens
        current_time: Current time for checking expiry

    Returns:
        Tuple of (account UTxO, agg state UTxO)
    """
    try:
        reward_accounts = filter_reward_account(
            filter_utxos_by_token_name(utxos, policy_id, "C3RA")
        )
        if not reward_accounts:
            raise ValueError("No Reward Account UTxOs found")

        # Find empty or expired agg states
        agg_states = filter_valid_agg_states(
            filter_utxos_by_token_name(utxos, policy_id, "C3AS"),
            current_time,
        )
        if not agg_states:
            raise ValueError("No valid agg state UTxO found")

        # Return first pair found
        return reward_accounts[0], agg_states[0]
    except Exception as e:
        raise ValueError(f"Failed to find UTxO pair: {e}") from e

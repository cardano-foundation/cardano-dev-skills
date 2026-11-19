"""Utilities for validating and filtering UTxOs based on asset criteria."""

from collections.abc import Sequence

from pycardano import Asset, AssetName, MultiAsset, ScriptHash, UTxO, Value

from charli3_offchain_core.oracle.exceptions import ValidationError


def filter_utxos_by_asset(utxos: Sequence[UTxO], asset: MultiAsset) -> list[UTxO]:
    """Filter UTxOs containing specific assets.

    Args:
        utxos: List of UTxOs to filter
        asset: MultiAsset to search for

    Returns:
        List of UTxOs containing the asset
    """
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
    """Filter UTxOs containing assets from a specific policy.

    Args:
        utxos: List of UTxOs to filter
        currency: Policy ID to search for

    Returns:
        List of UTxOs containing assets from the policy

    Raises:
        ValidationError: If currency is invalid
    """
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
    """Filter UTxOs containing a specific token.

    Args:
        utxos: List of UTxOs to filter
        policy_id: Policy ID of the token
        token_name: Name of the token

    Returns:
        List of UTxOs containing the token

    Raises:
        ValidationError: If policy_id or token_name is invalid
    """
    if not policy_id or not token_name:
        raise ValidationError("Invalid policy_id or token_name: cannot be empty")

    encoded_name = AssetName(
        token_name.encode() if isinstance(token_name, str) else token_name
    )

    return [
        utxo
        for utxo in utxos
        if (
            utxo.output.amount.multi_asset  # Has multi_asset
            and policy_id in utxo.output.amount.multi_asset  # Has correct policy
            and encoded_name in utxo.output.amount.multi_asset[policy_id]  # Has token
            and utxo.output.amount.multi_asset[policy_id][encoded_name] >= 1
        )  # Amount is >= 1
    ]


def has_required_tokens(utxo: UTxO, policy_id: bytes, token_names: list[str]) -> bool:
    """Check if UTxO contains all required tokens from a policy.

    Args:
        utxo: UTxO to check
        policy_id: Policy ID to check
        token_names: List of required token names

    Returns:
        bool: True if UTxO contains all required tokens

    Raises:
        ValidationError: If policy_id or token_names is invalid
    """
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


def validate_token_quantities(utxo: UTxO, expected_quantities: dict[str, int]) -> bool:
    """Validate token quantities in UTxO match expected amounts.

    Args:
        utxo: UTxO to validate
        expected_quantities: Dict mapping token names to expected quantities

    Returns:
        bool: True if quantities match expectations

    Raises:
        ValidationError: If validation fails
    """
    if not expected_quantities:
        raise ValidationError("Expected quantities cannot be empty")

    if not utxo.output.amount.multi_asset:
        return False

    for token_name, expected_qty in expected_quantities.items():
        actual_qty = 0
        for policy_tokens in utxo.output.amount.multi_asset.values():
            encoded_name = token_name.encode()
            if encoded_name in policy_tokens:
                actual_qty += policy_tokens[encoded_name]

        if actual_qty != expected_qty:
            return False

    return True


def check_value_preservation(
    input_utxo: UTxO, output_utxo: UTxO, exclude_tokens: list[Asset] | None = None
) -> bool:
    """Check if token values are preserved between input and output UTxOs.

    Args:
        input_utxo: Input UTxO
        output_utxo: Output UTxO
        exclude_tokens: Optional list of tokens to exclude from comparison

    Returns:
        bool: True if values are preserved
    """
    exclude_tokens = exclude_tokens or []

    def get_comparable_value(value: Value) -> Value:
        """Get value without excluded tokens."""
        result = Value(value.coin)
        if not value.multi_asset:
            return result

        result.multi_asset = MultiAsset()
        for policy_id, tokens in value.multi_asset.items():
            for token_name, quantity in tokens.items():
                should_exclude = any(
                    token.policy_id == policy_id and token.name == token_name
                    for token in exclude_tokens
                )
                if not should_exclude:
                    if policy_id not in result.multi_asset:
                        result.multi_asset[policy_id] = {}
                    result.multi_asset[policy_id][token_name] = quantity

        return result

    input_value = get_comparable_value(input_utxo.output.amount)
    output_value = get_comparable_value(output_utxo.output.amount)

    return input_value == output_value

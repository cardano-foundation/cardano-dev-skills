from pycardano import ScriptHash


def validate_policy_id(value: str) -> str:
    """Validate policy ID hex string."""
    try:
        policy_id = ScriptHash.from_primitive(value)
        return policy_id.payload.hex()
    except (ValueError, AssertionError, TypeError) as err:
        raise ValueError("Invalid policy ID format") from err

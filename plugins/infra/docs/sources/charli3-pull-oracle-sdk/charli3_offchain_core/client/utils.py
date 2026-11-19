def format_node_messages(messages: dict) -> dict[str, any]:
    """
    Format node messages by converting SignedOracleNodeMessage objects to dictionaries.

    Args:
        messages: dictionary mapping node pkh to SignedOracleNodeMessage objects

    Returns:
        dictionary mapping node pkh to dumped message dictionaries
    """
    return {pkh: msg.model_dump() for pkh, msg in messages.items()}

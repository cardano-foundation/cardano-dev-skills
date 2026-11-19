"""Utilities for validating oracle node signatures and message authenticity."""

import logging

from nacl.exceptions import BadSignatureError
from nacl.signing import VerifyKey
from pycardano import VerificationKeyHash

from charli3_offchain_core.models.oracle_datums import (
    AggregateMessage,
    OracleSettingsDatum,
)
from charli3_offchain_core.oracle.exceptions import SignatureError, ThresholdError

logger = logging.getLogger(__name__)


def validate_node_signatures(
    message: AggregateMessage,
    node_signatures: list[bytes],
    node_keys: list[bytes],
) -> bool:
    """Validate node signatures for aggregate message.

    Args:
        message: Aggregate message to validate (contains node_feeds_sorted_by_feed)
        node_signatures: List of node signatures
        node_keys: List of node verification keys (raw bytes)

    Returns:
        bool: True if signatures are valid

    Raises:
        SignatureError: If signature validation fails
    """
    try:
        if len(node_signatures) != len(node_keys):
            raise SignatureError("Signature and key count mismatch")

        # Get the verification key hashes from message
        message_vkhs = [vkh for vkh, _ in message.node_feeds_sorted_by_feed]

        # Create verify keys from raw bytes
        verify_keys = [VerifyKey(key_bytes) for key_bytes in node_keys]

        # Verify each VKH corresponds to a key
        key_vkhs = [VerificationKeyHash(bytes(key.verify_key)) for key in verify_keys]
        if set(message_vkhs) != set(key_vkhs):
            logger.warning("Message VKHs don't match provided keys")
            return False

        # Create message bytes for each feed/node pair
        for (vkh, feed_value), signature, verify_key in zip(
            message.node_feeds_sorted_by_feed, node_signatures, verify_keys
        ):
            try:
                # Encode message for this node's feed
                message_bytes = encode_oracle_feed(feed_value, message.timestamp)

                # Verify signature
                try:
                    verify_key.verify(message_bytes, signature)
                except BadSignatureError:
                    logger.warning("Invalid signature for VKH: %s", vkh)
                    return False

            except Exception as e:  # pylint: disable=broad-except
                logger.error("Signature verification failed: %s", e)
                return False

        return True

    except Exception as e:
        raise SignatureError(f"Failed to validate node signatures: {e}") from e


def encode_oracle_feed(
    feed_value: int,
    timestamp: int,
) -> bytes:
    """Encode oracle feed data for signature verification.

    Args:
        feed_value: Oracle feed value
        timestamp: Feed timestamp in milliseconds

    Returns:
        bytes: Encoded feed data

    Raises:
        SignatureError: If encoding fails
    """
    try:
        # Encode components as big-endian bytes matching on-chain validation
        feed_bytes = feed_value.to_bytes(8, byteorder="big", signed=False)
        time_bytes = timestamp.to_bytes(8, byteorder="big", signed=False)
        return feed_bytes + time_bytes

    except Exception as e:
        raise SignatureError(f"Failed to encode oracle feed: {e}") from e


def validate_message_nodes(
    msg: AggregateMessage, settings: OracleSettingsDatum
) -> bool:
    """Validate nodes in aggregate message against oracle settings.

    Args:
        msg: Aggregate message to validate
        settings: Oracle settings datum

    Returns:
        bool: True if message nodes are valid

    Raises:
        SignatureError: If validation fails
    """
    try:
        # Get set of registered node VKHs from settings
        registered_nodes = set(settings.nodes.keys())

        # Get set of VKHs from message
        message_nodes = set(msg.node_feeds_sorted_by_feed.keys())

        # Validate all message nodes are registered
        if not message_nodes.issubset(registered_nodes):
            logger.warning("Message contains unregistered nodes")
            return False

        # Validate node count matches
        if msg.node_feeds_count != len(message_nodes):
            logger.warning("Node count mismatch in message")
            return False

        return True

    except Exception as e:
        raise SignatureError(f"Failed to validate message nodes: {e}") from e


def check_signature_threshold(valid_signatures: int, required_count: int) -> bool:
    """Check if number of valid signatures meets threshold.

    Args:
        valid_signatures: Number of valid signatures
        required_count: Required signature count

    Returns:
        bool: True if threshold is met

    Raises:
        ThresholdError: If threshold check fails
    """
    try:
        if required_count < 1:
            raise ThresholdError("Required count must be positive")

        if valid_signatures < 0:
            raise ThresholdError("Valid signature count cannot be negative")

        return valid_signatures >= required_count

    except Exception as e:
        raise ThresholdError(f"Failed to check signature threshold: {e}") from e


def get_valid_node_set(
    aggregate_message: AggregateMessage,
    node_signatures: list[bytes],
    node_keys: list[bytes],
) -> set[VerificationKeyHash]:
    """Get set of nodes with valid signatures.

    Args:
        aggregate_message: Aggregate message containing node feeds and VKHs
        node_signatures: List of signatures
        node_keys: List of verification keys in raw bytes

    Returns:
        Set of verification key hashes with valid signatures

    Raises:
        SignatureError: If validation fails
    """
    try:
        # Validate input lengths
        if len(node_signatures) != len(node_keys):
            raise SignatureError("Signatures and keys must have same length")

        if len(node_signatures) != len(aggregate_message.node_feeds_sorted_by_feed):
            raise SignatureError("Number of signatures must match number of feeds")

        valid_nodes = set()

        # Create verify keys from raw bytes
        verify_keys = [VerifyKey(key_bytes) for key_bytes in node_keys]

        # Validate each node's signature
        for (node_vkh, feed_value), signature, verify_key in zip(
            aggregate_message.node_feeds_sorted_by_feed, node_signatures, verify_keys
        ):
            try:
                # Verify the key matches the VKH in the message
                key_vkh = VerificationKeyHash(bytes(verify_key.verify_key))
                if key_vkh != node_vkh:
                    logger.warning(
                        "Key VKH mismatch. Expected: %s, Got: %s", node_vkh, key_vkh
                    )
                    continue

                # Encode the message
                message = encode_oracle_feed(
                    feed_value=feed_value,
                    timestamp=aggregate_message.timestamp,
                )

                # Verify signature
                try:
                    verify_key.verify(message, signature)
                    valid_nodes.add(node_vkh)
                except BadSignatureError:
                    logger.warning("Invalid signature for VKH: %s", node_vkh)

            except Exception as e:  # pylint: disable=broad-except
                logger.warning(
                    "Signature validation failed for VKH %s: %s",
                    node_vkh,
                    str(e),
                )

        return valid_nodes

    except Exception as e:
        raise SignatureError(f"Failed to get valid node set: {e}") from e

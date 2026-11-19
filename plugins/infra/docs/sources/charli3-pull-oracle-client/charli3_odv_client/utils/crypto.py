"""Cryptographic utilities."""

from pycardano import VerificationKeyHash, VerificationKey


def get_verification_key_hash(vkey: VerificationKey) -> VerificationKeyHash:
    """Get verification key hash from verification key."""
    return VerificationKeyHash(vkey.hash().payload)


def get_verification_key_hash_from_hex(vkey_hex: str) -> VerificationKeyHash:
    """Get verification key hash from hex string."""
    vkey_bytes = bytes.fromhex(vkey_hex)
    vkey = VerificationKey.from_cbor(vkey_bytes)
    return get_verification_key_hash(vkey)

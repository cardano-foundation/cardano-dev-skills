"""Base types and utilities."""

from pycardano import PlutusData
from dataclasses import dataclass

PosixTime = int
NodeId = int
OracleFeed = int


@dataclass
class Ed25519Signature(PlutusData):
    """Ed25519 signature wrapper."""

    CONSTR_ID = 0
    payload: bytes

    @classmethod
    def from_primitive(cls, signature: bytes) -> "Ed25519Signature":
        """Create from raw signature bytes."""
        return cls(payload=signature)


@dataclass
class TxValidityInterval:
    """Transaction validity interval."""

    start: int
    end: int

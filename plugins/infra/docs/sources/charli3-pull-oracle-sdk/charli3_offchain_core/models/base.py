"""Base types used in the models."""

from pycardano import ConstrainedBytes, VerificationKeyHash
from pydantic import BaseModel, Field

PosixTime = int
PosixTimeDiff = int
PolicyId = bytes
AssetName = bytes
ScriptHash = bytes
OracleFeed = int
NodeFeed = int
FeedVkh = VerificationKeyHash
PaymentVkh = VerificationKeyHash


class Ed25519Signature(ConstrainedBytes):
    """Ed25519 signature constrained to 64 bytes."""

    MAX_SIZE = MIN_SIZE = 64

    @classmethod
    def from_hex(cls, hex_str: str) -> "Ed25519Signature":
        """Create signature from hex string."""
        try:
            return cls.from_primitive(hex_str)
        except (ValueError, AssertionError, TypeError) as err:
            raise ValueError("Invalid Ed25519 signature format") from err


class TxValidityInterval(BaseModel):
    """Transaction validity interval model"""

    start: PosixTime = Field(..., description="Start timestamp in milliseconds")
    end: PosixTime = Field(..., description="End timestamp in milliseconds")

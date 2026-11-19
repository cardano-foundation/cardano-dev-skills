"""Domain-specific types and models."""

from dataclasses import dataclass
from typing import Any

from opshin import sha256
from pycardano import (
    BIP32ED25519PublicKey,
    ExtendedSigningKey,
    PlutusData,
    SigningKey,
    VerificationKey,
)
from pydantic import BaseModel, ConfigDict, Field, model_serializer, model_validator

from charli3_offchain_core.models.base import Ed25519Signature, PosixTime


@dataclass
class OracleNodeMessage(PlutusData):
    """Oracle node message containing feed data."""

    CONSTR_ID = 0
    feed: int
    timestamp: PosixTime
    oracle_nft_policy_id: bytes

    def get_message_digest(self) -> bytes:
        """Get message digest for signing."""
        return sha256(self.to_cbor()).digest()

    def sign(self, key: SigningKey | ExtendedSigningKey) -> Ed25519Signature:
        """Create message signature using signing key."""
        return Ed25519Signature.from_primitive(key.sign(self.get_message_digest()))


class SignedOracleNodeMessage(BaseModel):
    """Pydantic model for signed oracle message."""

    model_config = ConfigDict(arbitrary_types_allowed=True)

    message: OracleNodeMessage = Field(..., description="Oracle feed message")
    signature: Ed25519Signature = Field(..., description="ed25519 signature")
    verification_key: VerificationKey = Field(
        ..., description="Node's verification key"
    )

    @model_validator(mode="before")
    @classmethod
    def deserialize_fields(cls, data: dict[str, Any]) -> dict[str, Any]:
        """Convert serialized data back to objects."""
        if not all(k in data for k in ["message", "signature", "verification_key"]):
            raise ValueError(
                "Missing required fields: message, signature, and verification_key"
            )

        if isinstance(data["message"], str):
            data["message"] = OracleNodeMessage.from_cbor(
                bytes.fromhex(data["message"])
            )

        if isinstance(data["signature"], str):
            data["signature"] = Ed25519Signature(bytes.fromhex(data["signature"]))

        if isinstance(data["verification_key"], str):
            data["verification_key"] = VerificationKey.from_cbor(
                bytes.fromhex(data["verification_key"])
            )

        return data

    @model_validator(mode="after")
    def validate_signature(self) -> "SignedOracleNodeMessage":
        """Validate signature and verify message."""
        try:
            public_key = BIP32ED25519PublicKey(
                self.verification_key.payload[:32],
                self.verification_key.payload[32:],
            )

            if not public_key.verify(
                self.signature.payload, self.message.get_message_digest()
            ):
                raise ValueError("Invalid signature")
        except Exception as e:
            raise ValueError(f"Signature validation failed: {e}") from e

        return self

    @model_serializer
    def serialize_model(self) -> dict[str, str]:
        """Serialize to dict with hex strings."""
        return {
            "message": self.message.to_cbor().hex(),
            "signature": self.signature.payload.hex(),
            "verification_key": self.verification_key.to_cbor().hex(),
        }

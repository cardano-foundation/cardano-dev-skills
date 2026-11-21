from pydantic import BaseModel, Field

from charli3_offchain_core.models.base import TxValidityInterval
from charli3_offchain_core.models.message import SignedOracleNodeMessage


class OdvFeedRequest(BaseModel):
    """Request for oracle feed data."""

    oracle_nft_policy_id: str = Field(..., description="Oracle NFT policy ID")
    tx_validity_interval: TxValidityInterval = Field(
        ..., description="Transaction validity window"
    )


class OdvTxSignatureRequest(BaseModel):
    """Request for transaction signatures."""

    node_messages: dict[str, SignedOracleNodeMessage] = Field(
        ..., description="Node messages"
    )
    tx_body_cbor: str = Field(..., description="Transaction Body CBOR to sign")

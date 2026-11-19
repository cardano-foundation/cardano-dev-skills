"""Request models for ODV operations."""

from pydantic import BaseModel, Field
from typing import Dict

from charli3_odv_client.models.base import TxValidityInterval
from charli3_odv_client.models.message import SignedOracleNodeMessage


class OdvFeedRequest(BaseModel):
    """Request for oracle feed data."""

    oracle_nft_policy_id: str = Field(..., description="Oracle NFT policy ID")
    tx_validity_interval: TxValidityInterval = Field(
        ..., description="Transaction validity window"
    )


class OdvTxSignatureRequest(BaseModel):
    """Request for transaction signatures."""

    node_messages: Dict[str, SignedOracleNodeMessage] = Field(
        ..., description="Node messages"
    )
    tx_body_cbor: str = Field(..., description="Transaction Body CBOR to sign")

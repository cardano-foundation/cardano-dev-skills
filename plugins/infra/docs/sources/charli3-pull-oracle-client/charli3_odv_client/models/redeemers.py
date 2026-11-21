"""Oracle Redeemers for Oracle smart contract and Oracle NFTs"""

from dataclasses import dataclass

from pycardano import PlutusData, VerificationKeyHash


@dataclass
class MintingRedeemer(PlutusData):
    """Types of actions for Oracle NFTs (protocol tokens)"""

    CONSTR_ID = 0  # For Mint


class Mint(MintingRedeemer):
    """One time mint for CoreSettings and RewardAccount"""

    CONSTR_ID = 0


class Scale(MintingRedeemer):
    """Scale RewardTransport and AggState UTxOs"""

    CONSTR_ID = 1


class Burn(MintingRedeemer):
    """Oracle remove: all tokens are burned"""

    CONSTR_ID = 2


@dataclass
class OracleRedeemer(PlutusData):
    """Types of actions for Oracle smart contract"""

    CONSTR_ID = 0  # Base constructor ID


@dataclass
class OdvAggregate(OracleRedeemer):
    """User sends on demand validation request with oracle nodes message."""

    CONSTR_ID = 0
    message: dict

    @classmethod
    def create_sorted(
        cls, node_feeds: dict[VerificationKeyHash, int]
    ) -> "OdvAggregate":
        """Create OdvAggregate with message in the provided order.

        Args:
            node_feeds: Dictionary mapping VerificationKeyHash to node feed values
                       MUST be pre-sorted by (feed_value, VKH) as required by validator

        Returns:
            OdvAggregate with message as dict (serializes as CBOR Map)

        """
        return cls(message=node_feeds)


@dataclass
class AggregateMessage:
    """Off-chain representation of aggregate message."""

    node_feeds_sorted_by_feed: dict[VerificationKeyHash, int]

    def to_redeemer(self) -> OdvAggregate:
        """Convert to properly formatted redeemer."""
        return OdvAggregate.create_sorted(self.node_feeds_sorted_by_feed)

    @property
    def node_feeds_count(self) -> int:
        """Calculate count from the map (not stored)."""
        return len(self.node_feeds_sorted_by_feed)


class OdvAggregateMsg(OracleRedeemer):
    """Marks the AggState UTxO as spent during aggregation"""

    CONSTR_ID = 1


class CalculateRewards(OracleRedeemer):
    """Calculate reward consensus and transfer fees to reward UTxO"""

    CONSTR_ID = 2

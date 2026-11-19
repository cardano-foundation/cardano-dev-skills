"""Oracle Redeemers for Oracle smart contract and Oracle NFTs"""

from dataclasses import dataclass
from typing import Union

from pycardano import PlutusData, VerificationKeyHash


### Oracle NFTs - Minting Redeemer variants
@dataclass
class Mint(PlutusData):
    """One time mint for CoreSettings and RewardAccount"""

    CONSTR_ID = 0


@dataclass
class Scale(PlutusData):
    """Scale RewardTransport and AggState UTxOs"""

    CONSTR_ID = 1


@dataclass
class Burn(PlutusData):
    """Oracle remove: all tokens are burned"""

    CONSTR_ID = 2


# Type alias for MintingRedeemer variants
MintingRedeemer = Union[Mint, Scale, Burn]  # noqa


## Reward Redeemer variants
@dataclass
class NodeCollect(PlutusData):
    """Node Collect"""

    CONSTR_ID = 0


@dataclass
class PlatformCollect(PlutusData):
    """Platform Collect"""

    CONSTR_ID = 1


# Type alias for RewardRedeemer variants
RewardRedeemer = Union[NodeCollect, PlatformCollect]  # noqa


### Oracle Manager Redeemer variants
@dataclass
class OdvAggregate(PlutusData):
    """User sends on demand validation request with oracle nodes message"""

    CONSTR_ID = 0
    message: dict  # Map of VKH -> feed_value

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
class OdvAggregateMsg(PlutusData):
    """Calculate reward consensus and transfer fees to reward UTxO"""

    CONSTR_ID = 1


@dataclass
class RedeemRewards(PlutusData):
    """Redeem rewards"""

    CONSTR_ID = 2
    collector: RewardRedeemer
    corresponding_out_ix: int


### Settings Redeemer variants
@dataclass
class UpdateSettings(PlutusData):
    """Oracle platform changes consensus, timing or fee settings"""

    CONSTR_ID = 0


@dataclass
class AddNodes(PlutusData):
    """Oracle platform adds new nodes"""

    CONSTR_ID = 1


@dataclass
class DelNodes(PlutusData):
    """Oracle platform deletes nodes"""

    CONSTR_ID = 2


@dataclass
class PauseOracle(PlutusData):
    """Platform starts pause period"""

    CONSTR_ID = 3


@dataclass
class ResumeOracle(PlutusData):
    """Cancel oracle pause for temporary suspension"""

    CONSTR_ID = 4


@dataclass
class RemoveOracle(PlutusData):
    """Remove oracle and destroy all UTxOs and NFTs"""

    CONSTR_ID = 5


# Type alias for SettingsRedeemer variants
SettingsRedeemer = Union[  # noqa
    UpdateSettings, AddNodes, DelNodes, PauseOracle, ResumeOracle, RemoveOracle
]


@dataclass
class ManageSettings(PlutusData):
    """Oracle Manage Settings Redeemer"""

    CONSTR_ID = 3
    redeemer: SettingsRedeemer


@dataclass
class ScaleDown(PlutusData):
    """Platform burns RewardTransport and AggState NFTs"""

    CONSTR_ID = 4


@dataclass
class DismissRewards(PlutusData):
    """Platform turns RewardTransport UTxOs with pending rewards into NoRewards"""

    CONSTR_ID = 5


# Type alias for OracleRedeemer variants
OracleRedeemer = Union[  # noqa
    OdvAggregate,
    OdvAggregateMsg,
    RedeemRewards,
    ManageSettings,
    ScaleDown,
    DismissRewards,
]


@dataclass
class AggregateMessage:
    """Off-chain representation of aggregate message.

    This is NOT serialized to chain. When building transactions, use
    OdvAggregate.create_sorted() to create the properly formatted redeemer.

    IMPORTANT: On-chain, AggregateMessage is just Pairs<FeedVkh, NodeFeed>.
    Count and timestamp are NOT part of the on-chain structure.
    """

    node_feeds_sorted_by_feed: dict[VerificationKeyHash, int]

    def to_redeemer(self) -> OdvAggregate:
        """Convert to properly formatted redeemer."""
        return OdvAggregate.create_sorted(self.node_feeds_sorted_by_feed)

    @property
    def node_feeds_count(self) -> int:
        """Calculate count from the map (not stored)."""
        return len(self.node_feeds_sorted_by_feed)

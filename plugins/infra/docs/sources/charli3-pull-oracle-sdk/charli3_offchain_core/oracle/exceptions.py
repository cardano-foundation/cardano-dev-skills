"""Custom exceptions for oracle operations and validation."""


class OracleError(Exception):
    """Base exception for all oracle-related errors."""

    pass


class ValidationError(OracleError):
    """Base exception for validation errors."""

    pass


# State Validation Errors
class StateValidationError(ValidationError):
    """Raised when oracle state validation fails."""

    pass


class TransitionError(StateValidationError):
    """Raised when oracle state transition is invalid."""

    pass


class SequenceError(StateValidationError):
    """Raised when oracle sequence validation fails."""

    pass


class NoPendingTransportUtxosFoundError(StateValidationError):
    """Raised when no pending transport UTxOs were found."""

    pass


class RewardCalculationIsNotSubsidizedError(StateValidationError):
    """Raised when transaction fee for reward calculation is not subsidized."""

    pass


# Time Validation Errors
class TimeValidationError(ValidationError):
    """Raised when time-related validation fails."""

    pass


class TimestampError(TimeValidationError):
    """Raised when timestamp validation fails."""

    pass


class LivenessError(TimeValidationError):
    """Raised when liveness period validation fails."""

    pass


# Fee Validation Errors
class FeeValidationError(ValidationError):
    """Raised when fee validation fails."""

    pass


class FeeCalculationError(FeeValidationError):
    """Raised when fee calculation fails."""

    pass


class InsufficientFeeError(FeeValidationError):
    """Raised when fee payment is insufficient."""

    pass


# Node Validation Errors
class NodeValidationError(ValidationError):
    """Raised when node validation fails."""

    pass


class SignatureError(NodeValidationError):
    """Raised when node signature validation fails."""

    pass


class ThresholdError(NodeValidationError):
    """Raised when node threshold requirements are not met."""

    pass


# Value Validation Errors
class ValueValidationError(ValidationError):
    """Raised when value validation fails."""

    pass


class OutlierError(ValueValidationError):
    """Raised when feed value is identified as an outlier."""

    pass


class RangeError(ValueValidationError):
    """Raised when feed value is outside valid range."""

    pass


# Asset Validation Errors
class AssetValidationError(ValidationError):
    """Raised when asset validation fails."""

    pass


class TokenError(AssetValidationError):
    """Raised when token validation fails."""

    pass


class NFTError(AssetValidationError):
    """Raised when NFT validation fails."""

    pass


# Deployment Errors
class DeploymentError(OracleError):
    """Base exception for deployment errors."""

    pass


class ConfigurationError(DeploymentError):
    """Raised when oracle configuration is invalid."""

    pass


class ReferenceScriptError(DeploymentError):
    """Raised when reference script operations fail."""

    pass


# Transaction Errors
class TransactionError(OracleError):
    """Base exception for transaction errors."""

    pass


class BuildError(TransactionError):
    """Raised when transaction building fails."""

    pass


class SubmissionError(TransactionError):
    """Raised when transaction submission fails."""

    pass


class CollateralError(TransactionError):
    """Raised when collateral handling fails."""

    pass


# Consensus Errors
class ConsensusError(OracleError):
    """Base exception for consensus-related errors."""

    pass


class AggregationError(ConsensusError):
    """Raised when feed aggregation fails."""

    pass


class QuorumError(ConsensusError):
    """Raised when consensus quorum is not met."""

    pass


# Reward Errors
class RewardError(OracleError):
    """Base exception for reward-related errors."""

    pass


class DistributionError(RewardError):
    """Raised when reward distribution fails."""

    pass


class AccountingError(RewardError):
    """Raised when reward accounting fails."""

    pass


# Operation Errors
class OperationError(OracleError):
    """Base exception for operation errors."""

    pass


class PauseError(OperationError):
    """Raised when oracle pause operations fail."""

    pass


class ScalingError(OperationError):
    """Raised when oracle scaling operations fail."""

    pass


# Data Errors
class DataError(OracleError):
    """Base exception for data-related errors."""

    pass


class SerializationError(DataError):
    """Raised when datum serialization fails."""

    pass


class DeserializationError(DataError):
    """Raised when datum deserialization fails."""

    pass


# Recovery Errors
class RecoveryError(OracleError):
    """Base exception for recovery operations."""

    pass


class StateRecoveryError(RecoveryError):
    """Raised when state recovery fails."""

    pass


class SyncError(RecoveryError):
    """Raised when oracle state synchronization fails."""

    pass


class GovernanceError(OracleError):
    """Base exception for all governance-related errors."""

    pass


class UpdatingError(GovernanceError):
    """Raised when oracle update operations fail."""

    pass


class SettingsValidationError(GovernanceError):
    """Raised when settings validation fails."""

    pass


class UpdateCancelled(GovernanceError):  # noqa
    """Exception raised when user intentionally cancels the update."""

    pass


class AddNodesValidationError(GovernanceError):
    """Raised when settings validation fails."""

    pass


class AddNodesCancelled(GovernanceError):  # noqa
    """Exception raised when user intentionally cancels the add nodes tx."""

    pass


class AddingNodesError(GovernanceError):
    """Raised when oracle update operations fail."""

    pass


class RemoveNodesValidationError(GovernanceError):
    """Raised when remove nodes validation fails."""

    pass


class RemoveNodesCancelled(GovernanceError):  # noqa
    """Exception raised when user intentionally cancels the delete nodes tx."""

    pass


class RemovingNodesError(GovernanceError):
    """Raised when oracle delete nodes operations fail."""

    pass


class RewardsError(OracleError):
    """Base exception for all governance-related errors."""

    pass


class NodeCollectCancelled(RewardsError):  # noqa
    """Exception raised when user intentionally cancels the delete nodes tx."""

    pass


class CollectingNodesError(RewardsError):
    """Raised when oracle delete nodes operations fail."""

    pass


class NodeNotRegisteredError(RewardsError):
    pass


class NoRewardsAvailableError(RewardsError):
    pass


class ADABalanceNotFoundError(RewardsError):
    pass


class PlatformCollectValidationError(RewardsError):
    """Raised when remove nodes validation fails."""

    pass


class PlatformCollectCancelled(RewardsError):  # noqa
    """Exception raised when user intentionally cancels the delete nodes tx."""

    pass


class CollectingPlatformError(RewardsError):
    """Raised when oracle delete nodes operations fail."""

    pass


class NoPendingTransportsFoundError(RewardsError):
    """
    Raised when no UTxOs with pending rewards are found in the reward accounts.
    This indicates that there are no rewards to be processed or transported.
    """

    pass


class NoExpiredTransportsYetError(RewardsError):
    """
    Raised when there are pending rewards to be processed, but the dismissal
    period has not yet expired. No expired transports were found.
    """

    pass


class DismissRewardCancelledError(RewardsError):
    """
    Raised when the user cancels the dismissal of rewards during the transaction.
    """

    pass

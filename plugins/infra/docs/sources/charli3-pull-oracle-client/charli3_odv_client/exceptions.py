"""Exceptions for client operations."""


class ODVClientError(Exception):
    """Base exception for ODV client errors."""

    pass


class ConfigurationError(ODVClientError):
    """Raised when configuration is invalid."""

    pass


class NetworkError(ODVClientError):
    """Raised when network operations fail."""

    pass


class ValidationError(ODVClientError):
    """Raised when validation fails."""

    pass


class AggregationError(ODVClientError):
    """Raised when aggregation operations fail."""

    pass


class OracleTransactionError(ODVClientError):
    """Base class for oracle transaction related errors."""

    pass


class StateValidationError(OracleTransactionError):
    """Raised when oracle state validation fails."""

    pass


class DistributionError(OracleTransactionError):
    """Raised when reward distribution calculations fail."""

    pass


class SignatureError(OracleTransactionError):
    """Raised when signature validation fails."""

    pass


class ThresholdError(OracleTransactionError):
    """Raised when signature threshold checks fail."""

    pass


class NoPendingTransportUtxosFoundError(StateValidationError):
    """Raised when no pending transport UTxOs are found."""

    pass


class RewardCalculationIsNotSubsidizedError(StateValidationError):
    """Raised when reward calculation transaction fee is not subsidized."""

    pass

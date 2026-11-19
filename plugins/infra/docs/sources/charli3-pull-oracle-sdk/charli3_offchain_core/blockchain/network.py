"""Network configuration and timing utilities for Cardano blockchain operations.

This module provides utilities for:
- Network type identification
- Network configuration management
- Slot and time conversions
- Network time calculations
"""

import time
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Final, TypeAlias

import requests

from .exceptions import NetworkConfigError, NetworkTimeError, ValidationError

# Type aliases for clarity and type safety
NetworkMagic: TypeAlias = int
SlotNo: TypeAlias = int
Timestamp: TypeAlias = int

# Network timing constraints
MIN_SLOT_LENGTH: Final[int] = 200  # milliseconds
MAX_SLOT_LENGTH: Final[int] = 10000  # milliseconds
MAX_TIME_DRIFT: Final[int] = 5000  # milliseconds


class NetworkType(str, Enum):
    """Supported Cardano network types."""

    MAINNET = "MAINNET"
    PREVIEW = "PREVIEW"
    PREPROD = "PREPROD"
    CUSTOM = "CUSTOM"
    DEVNET = "DEVNET"


# Network magic numbers for identification
NETWORK_MAGIC: dict[NetworkType, NetworkMagic] = {
    NetworkType.MAINNET: 764824073,
    NetworkType.PREPROD: 1,
    NetworkType.PREVIEW: 2,
    NetworkType.DEVNET: 42,
    NetworkType.CUSTOM: 4,
}


@dataclass
class NetworkConfig:
    """Network configuration parameters for time and slot calculations.

    Attributes:
        zero_time: POSIX timestamp in milliseconds for network start
        zero_slot: Initial slot number at network start
        slot_length: Duration of each slot in milliseconds
    """

    zero_time: Timestamp  # POSIX timestamp in milliseconds
    zero_slot: SlotNo  # Slot number at zero_time
    slot_length: int  # Milliseconds per slot

    def __post_init__(self) -> None:
        """Validate configuration parameters."""
        self._validate_config()

    def _validate_config(self) -> None:
        """Validate configuration values."""
        if self.zero_time < 0:
            raise ValidationError("zero_time cannot be negative")

        if not MIN_SLOT_LENGTH <= self.slot_length <= MAX_SLOT_LENGTH:
            raise ValidationError(
                f"slot_length must be between {MIN_SLOT_LENGTH} "
                f"and {MAX_SLOT_LENGTH} ms"
            )

        if self.zero_slot < 0:
            raise ValidationError("zero_slot cannot be negative")

    @classmethod
    def from_network(cls, network: NetworkType) -> "NetworkConfig":
        """Create network configuration from network type.

        Args:
            network: Type of Cardano network

        Returns:
            NetworkConfig for specified network

        Raises:
            NetworkConfigError: If network type is invalid or custom network
                              is not properly configured
        """
        try:
            # For DevNet, always fetch the configuration dynamically
            if network == NetworkType.DEVNET:
                config = get_devnet_config()
                if config is None:
                    raise NetworkConfigError(
                        "Failed to fetch DevNet configuration from local node. "
                        "Ensure the node is running at localhost:10000."
                    )
            else:
                config = NETWORK_CONFIGS[network]

            if network == NetworkType.CUSTOM:
                validate_custom_network(config)
            return config
        except Exception as e:
            raise NetworkConfigError(
                f"Failed to create config for network {network}: {e}"
            ) from e

    def slot_to_posix(self, slot: SlotNo) -> Timestamp:
        """Convert slot number to POSIX timestamp in milliseconds.

        Args:
            slot: Slot number to convert

        Returns:
            POSIX timestamp in milliseconds

        Raises:
            NetworkTimeError: If slot is before network start
        """
        if slot < self.zero_slot:
            raise NetworkTimeError(
                f"Slot {slot} is before network start at slot {self.zero_slot}"
            )

        ms_after_zero = (slot - self.zero_slot) * self.slot_length
        return self.zero_time + ms_after_zero

    def posix_to_slot(self, posix_ms: Timestamp) -> SlotNo:
        """Convert POSIX timestamp to slot number.

        Args:
            posix_ms: POSIX timestamp in milliseconds

        Returns:
            Slot number

        Raises:
            NetworkTimeError: If timestamp is before network start
        """
        if posix_ms < self.zero_time:
            raise NetworkTimeError(
                f"Timestamp {posix_ms} is before network start at {self.zero_time}"
            )

        ms_after_zero = posix_ms - self.zero_time
        return self.zero_slot + (ms_after_zero // self.slot_length)


def get_devnet_config() -> NetworkConfig | None:
    """Dynamically fetch DevNet configuration from local node.

    Returns:
        NetworkConfig for DevNet if successful, None otherwise

    Raises:
        NetworkConfigError: If unable to fetch configuration from the local node
    """
    try:
        # Fetch the Shelley parameters from the local endpoint
        response = requests.get(
            "http://localhost:10000/local-cluster/api/admin/devnet/genesis/shelley",
            timeout=5.0,  # Add timeout to prevent long delays
        )
        response.raise_for_status()  # Raise exception for non-200 status codes

        shelley_params = response.json()

        # Convert the systemStart to a timestamp in milliseconds
        system_start = shelley_params.get("systemStart")
        if not system_start:
            raise NetworkConfigError(
                "DevNet configuration missing systemStart parameter"
            )

        # Handle ISO format with Z for UTC timezone
        zero_time = int(
            datetime.fromisoformat(system_start.replace("Z", "+00:00")).timestamp()
            * 1000
        )

        return NetworkConfig(
            zero_time=zero_time,
            zero_slot=0,
            slot_length=1000,
        )
    except requests.RequestException as e:
        raise NetworkConfigError(
            f"Failed to fetch DevNet config: Connection error - {e}"
        ) from e
    except ValueError as e:
        raise NetworkConfigError(f"Failed to parse DevNet config: {e}") from e
    except KeyError as e:
        raise NetworkConfigError(f"Missing key in DevNet config: {e}") from e
    except Exception as e:
        raise NetworkConfigError(f"Unexpected error fetching DevNet config: {e}") from e


# Pre-configured network configurations
NETWORK_CONFIGS: dict[NetworkType, NetworkConfig] = {
    NetworkType.MAINNET: NetworkConfig(
        zero_time=1596059091000,  # Shelley era start
        zero_slot=4492800,
        slot_length=1000,
    ),
    NetworkType.PREVIEW: NetworkConfig(
        zero_time=1666656000000,  # Preview testnet start
        zero_slot=0,
        slot_length=1000,
    ),
    NetworkType.PREPROD: NetworkConfig(
        zero_time=1654041600000 + 1728000000,  # Preprod testnet start
        zero_slot=86400,
        slot_length=1000,
    ),
    NetworkType.CUSTOM: NetworkConfig(
        zero_time=0,
        zero_slot=0,
        slot_length=1000,
    ),
}


def get_network_type(network_magic: NetworkMagic) -> NetworkType:
    """Convert network magic number to network type.

    Args:
        network_magic: Network identifier number

    Returns:
        Corresponding NetworkType

    Raises:
        NetworkConfigError: If network magic is unknown
    """
    for network_type, magic in NETWORK_MAGIC.items():
        if magic == network_magic:
            return network_type
    raise NetworkConfigError(f"Unknown network magic: {network_magic}")


def validate_custom_network(config: NetworkConfig) -> None:
    """Validate custom network configuration parameters.

    Args:
        config: Network configuration to validate

    Raises:
        NetworkConfigError: If configuration is invalid
    """
    if config.zero_time == 0 and config.slot_length == 0:
        raise NetworkConfigError(
            "Custom network requires valid zero_time and slot_length"
        )


class NetworkTime:
    """Network time utilities for slot and time calculations."""

    def __init__(
        self, network_config: NetworkConfig, use_wall_clock: bool = True
    ) -> None:
        """Initialize network time calculator.

        Args:
            network_config: Network configuration parameters
            use_wall_clock: Whether to use system time instead of network time
        """
        self.config = network_config
        self.use_wall_clock = use_wall_clock
        self._last_sync: Timestamp = 0
        self._time_drift: int = 0

    def current_slot(self) -> SlotNo:
        """Get current slot number.

        Returns:
            Current slot number based on network or wall clock time

        Raises:
            NetworkTimeError: If time calculation fails
        """
        try:
            current_time = self.current_time()
            return self.config.posix_to_slot(current_time)
        except Exception as e:
            raise NetworkTimeError(f"Failed to get current slot: {e}") from e

    def current_time(self) -> Timestamp:
        """Get current time in milliseconds.

        Returns:
            Current POSIX timestamp in milliseconds

        Raises:
            NetworkTimeError: If time calculation fails
        """
        try:
            if self.use_wall_clock:
                return int(time.time_ns() * 1e-6)
            return self._get_network_time()
        except Exception as e:
            raise NetworkTimeError(f"Failed to get current time: {e}") from e

    def _get_network_time(self) -> Timestamp:
        """Calculate current network time with drift correction.

        Returns:
            Network POSIX timestamp in milliseconds

        Raises:
            NetworkTimeError: If time calculation fails
        """
        try:
            current_time = round(time.time_ns() * 1e-6)
            time_since_zero = current_time - self.config.zero_time

            # Apply drift correction
            if self._time_drift:
                time_since_zero += self._time_drift

            # Align to slot boundaries
            current_slot = time_since_zero // self.config.slot_length
            return self.config.zero_time + (current_slot * self.config.slot_length)

        except Exception as e:
            raise NetworkTimeError(f"Failed to calculate network time: {e}") from e

    def adjust_time_drift(self, chain_tip_slot: SlotNo) -> None:
        """Adjust time drift based on chain tip.

        Args:
            chain_tip_slot: Latest slot number from chain
        """
        current_slot = self.current_slot()
        drift_slots = chain_tip_slot - current_slot

        if abs(drift_slots) > 0:
            self._time_drift = drift_slots * self.config.slot_length
            self._last_sync = int(time.time_ns() * 1e-6)

    def slot_to_posix(self, slot: SlotNo) -> Timestamp:
        """Convert slot to POSIX timestamp.

        Args:
            slot: Slot number to convert

        Returns:
            POSIX timestamp in milliseconds
        """
        return self.config.slot_to_posix(slot)

    def posix_to_slot(self, posix_ms: Timestamp) -> SlotNo:
        """Convert POSIX timestamp to slot.

        Args:
            posix_ms: POSIX timestamp in milliseconds

        Returns:
            Slot number
        """
        return self.config.posix_to_slot(posix_ms)

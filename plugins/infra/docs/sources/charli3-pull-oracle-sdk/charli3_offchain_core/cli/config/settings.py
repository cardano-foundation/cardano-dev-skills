from dataclasses import dataclass


@dataclass
class FeeConfig:
    """Fee configuration."""

    node_fee: int
    platform_fee: int

    @classmethod
    def from_dict(cls, data: dict) -> "FeeConfig":
        """Create fee config from dictionary."""
        return cls(node_fee=data["node_fee"], platform_fee=data["platform_fee"])


@dataclass
class TimingConfig:
    """Timing parameters configuration."""

    pause_period: int = 3600000
    reward_dismissing_period: int = 7200000
    aggregation_liveness: int = 300000
    time_uncertainty_aggregation: int = 120000
    time_uncertainty_platform: int = 180000
    utxo_size_safety_buffer: int | None = None
    iqr_multiplier: int = 150
    median_divergency_factor: int = 300

    @classmethod
    def from_dict(cls, data: dict) -> "TimingConfig":
        """Create timing config from dictionary."""
        return cls(
            pause_period=data.get("pause_period", 3600000),
            reward_dismissing_period=data.get("reward_dismissing_period", 7200000),
            aggregation_liveness=data.get("aggregation_liveness", 300000),
            time_uncertainty_aggregation=data.get(
                "time_uncertainty_aggregation", 120000
            ),
            time_uncertainty_platform=data.get("time_uncertainty_platform", 180000),
            utxo_size_safety_buffer=data.get("utxo_size_safety_buffer", None),
            iqr_multiplier=data.get("iqr_multiplier", 150),
            median_divergency_factor=data.get("median_divergency_factor", 300),
        )

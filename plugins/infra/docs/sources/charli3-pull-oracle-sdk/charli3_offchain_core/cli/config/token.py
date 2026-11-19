from dataclasses import dataclass


@dataclass
class TokenConfig:
    """Token configuration."""

    platform_auth_policy: str
    reward_token_policy: str | None
    reward_token_name: str | None
    rate_token_policy: str | None
    rate_token_name: str | None
    oracle_policy: str | None

    @classmethod
    def from_dict(cls, data: dict) -> "TokenConfig":
        """Create token config from dictionary."""
        return cls(
            platform_auth_policy=data["platform_auth_policy"],
            rate_token_policy=data.get("rate_token_policy", None),
            reward_token_policy=(
                data.get("reward_token_policy")
                if data.get("reward_token_policy") is not None
                else data.get("fee_token_policy")
            ),
            reward_token_name=(
                data.get("reward_token_name")
                if data.get("reward_token_name") is not None
                else data.get("fee_token_name")
            ),
            rate_token_name=data.get("rate_token_name", None),
            oracle_policy=data.get("oracle_policy", None),
        )

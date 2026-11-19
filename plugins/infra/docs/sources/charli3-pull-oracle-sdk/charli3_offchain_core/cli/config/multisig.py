from dataclasses import dataclass


@dataclass
class MultisigConfig:
    """Configuration for multisig authorization."""

    threshold: int
    parties: list[str]
    platform_addr: str | None = None

    @classmethod
    def from_dict(cls, data: dict) -> "MultisigConfig":
        return cls(
            threshold=data.get("threshold", 1),
            parties=data.get("parties", []),
            platform_addr=data.get("platform_addr"),
        )

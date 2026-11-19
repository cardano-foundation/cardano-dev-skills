"""Node configuration parameters."""

from dataclasses import dataclass

from pycardano import VerificationKeyHash


@dataclass
class NodesConfig:
    """Configuration for oracle nodes: list of feed VKHs + required signatures."""

    required_signatures: int
    nodes: list[VerificationKeyHash]

    @classmethod
    def from_dict(cls, data: dict) -> "NodesConfig":
        """Create from dict with 'required_signatures' and 'nodes' as list of hex strings."""
        try:
            required = int(data["required_signatures"])
            nodes_hex = data["feed_vkh"]

            if not isinstance(nodes_hex, list):
                raise ValueError("'nodes' must be a list of hex strings")
            if not all(isinstance(h, str) for h in nodes_hex):
                raise ValueError("All nodes must be hex strings")
            if required < 0:
                raise ValueError("required_signatures cannot be negative")
            if len(nodes_hex) != len({*nodes_hex}):
                raise ValueError("Must not have duplicate nodes")

            nodes = sorted(
                [VerificationKeyHash(bytes.fromhex(h)) for h in nodes_hex],
                key=lambda x: x.payload,
            )
            return cls(required_signatures=required, nodes=nodes)

        except (KeyError, ValueError, TypeError) as e:
            raise ValueError(f"Invalid NodesConfig: {e}") from e

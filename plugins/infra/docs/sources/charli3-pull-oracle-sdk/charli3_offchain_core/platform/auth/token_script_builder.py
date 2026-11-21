"""Platform authorization NFT script builder."""

import logging
from dataclasses import dataclass

from pycardano import (
    Address,
    InvalidHereAfter,
    NativeScript,
    ScriptAll,
    ScriptNofK,
    ScriptPubkey,
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.exceptions import ChainQueryError

logger = logging.getLogger(__name__)


@dataclass
class ScriptConfig:
    """Configuration parameters for platform authorization script."""

    signers: list[VerificationKeyHash]
    threshold: int
    network: str | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.threshold, int) or self.threshold < 1:
            raise ValueError("Threshold must be an integer greater than or equal to 1")
        if not self.signers or self.threshold > len(self.signers):
            raise ValueError(
                f"Threshold {self.threshold} cannot exceed number of signers ({len(self.signers)})"
            )


class PlatformAuthScript:
    """Builds native script for platform authorization NFT."""

    VALIDITY_BUFFER = 1000

    def __init__(
        self, chain_query: ChainQuery, config: ScriptConfig, is_mock: bool = False
    ) -> None:
        self.chain_query = chain_query
        self.config = config
        self.is_mock = is_mock
        self._multisig = self._create_multisig()

    def _create_multisig(self) -> ScriptNofK:
        """Create the multisig component."""
        return ScriptNofK(
            self.config.threshold, [ScriptPubkey(pkh) for pkh in self.config.signers]
        )

    def build_minting_script(self) -> tuple[int, NativeScript]:
        """Build native script for minting."""
        try:
            current_slot = self.chain_query.last_block_slot
            validity_slot = current_slot + self.VALIDITY_BUFFER
            logger.info(
                "Building minting script valid until slot: %d (current: %d)",
                validity_slot,
                current_slot,
            )
            return validity_slot, self._build_script(validity_slot)
        except Exception as e:
            raise ChainQueryError(f"Failed to build minting script: {e}") from e

    def build_spending_script(self) -> NativeScript:
        """Build native script for spending."""
        try:
            logger.info("Building spending script")
            return ScriptAll([self._multisig]) if not self.is_mock else None
        except Exception as e:
            raise ChainQueryError(f"Failed to build spending script: {e}") from e

    def _build_script(self, validity_slot: int) -> NativeScript:
        """Build time-locked native script."""
        if self.is_mock:
            return None

        return ScriptAll([self._multisig, InvalidHereAfter(validity_slot)])

    def script_address(self) -> Address:
        """Get script address."""
        script = self.build_spending_script()
        return Address(payment_part=script.hash(), network=self.config.network)

    @staticmethod
    def from_native_script(
        script: NativeScript, network: str | None = None
    ) -> ScriptConfig:
        """Extract ScriptConfig from a native script."""
        try:
            if isinstance(script, ScriptAll):
                for inner_script in script.native_scripts:
                    if isinstance(inner_script, ScriptNofK):
                        signers = []
                        for pub_script in inner_script.native_scripts:
                            if isinstance(pub_script, ScriptPubkey):
                                signers.append(pub_script.key_hash)
                        return ScriptConfig(
                            signers=signers, threshold=inner_script.n, network=network
                        )

            elif isinstance(script, ScriptNofK):
                signers = []
                for pub_script in script.native_scripts:
                    if isinstance(pub_script, ScriptPubkey):
                        signers.append(pub_script.key_hash)
                return ScriptConfig(
                    signers=signers, threshold=script.n, network=network
                )

            raise ValueError("Unsupported script structure")

        except Exception as e:
            raise ValueError(f"Failed to deserialize script: {e}") from e

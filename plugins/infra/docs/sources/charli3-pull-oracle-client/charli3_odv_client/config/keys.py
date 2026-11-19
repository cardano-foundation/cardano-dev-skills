"""Key management and wallet configuration."""

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

from pycardano import (
    Address,
    ExtendedSigningKey,
    HDWallet,
    Network,
    PaymentSigningKey,
    PaymentVerificationKey,
)

from charli3_odv_client.exceptions import ConfigurationError


@dataclass
class WalletConfig:
    """Wallet configuration."""

    mnemonic: Optional[str] = None
    payment_skey_path: Optional[str] = None
    payment_vkey_path: Optional[str] = None
    stake_vkey_path: Optional[str] = None
    network: Optional[str] = "testnet"

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "WalletConfig":
        wallet_data = data.get("wallet", {})
        return cls(
            mnemonic=wallet_data.get("mnemonic"),
            payment_skey_path=wallet_data.get("payment_skey_path"),
            payment_vkey_path=wallet_data.get("payment_vkey_path"),
            stake_vkey_path=wallet_data.get("stake_vkey_path"),
            network=wallet_data.get("network", "testnet"),
        )

    def validate(self) -> None:
        if not self.mnemonic and not all(
            [
                self.payment_skey_path,
                self.payment_vkey_path,
                self.stake_vkey_path,
            ]
        ):
            raise ConfigurationError(
                "Wallet config must contain either a mnemonic or all key file paths."
            )

    def to_pycardano_network(self) -> Network:
        return Network[self.network.upper()]


class KeyManager:
    """Manages loading and deriving keys from mnemonic or files."""

    @staticmethod
    def load_from_mnemonic(
        mnemonic: str, network: Network = Network.TESTNET
    ) -> tuple[
        PaymentSigningKey, PaymentVerificationKey, PaymentVerificationKey, Address
    ]:
        """Load keys from mnemonic phrase."""
        hdwallet = HDWallet.from_mnemonic(mnemonic)

        payment_hdwallet = hdwallet.derive_from_path("m/1852'/1815'/0'/0/0")
        payment_signing_key = ExtendedSigningKey.from_hdwallet(payment_hdwallet)
        payment_verification_key = PaymentVerificationKey.from_primitive(
            payment_hdwallet.public_key
        )

        stake_hdwallet = hdwallet.derive_from_path("m/1852'/1815'/0'/2/0")
        stake_verification_key = PaymentVerificationKey.from_primitive(
            stake_hdwallet.public_key
        )

        address = Address(
            payment_verification_key.hash(), stake_verification_key.hash(), network
        )

        return (
            payment_signing_key,
            payment_verification_key,
            stake_verification_key,
            address,
        )

    @staticmethod
    def load_from_files(
        payment_skey_path: Path | str,
        payment_vkey_path: Path | str,
        stake_vkey_path: Path | str,
        network: Network = Network.TESTNET,
    ) -> tuple[
        PaymentSigningKey, PaymentVerificationKey, PaymentVerificationKey, Address
    ]:
        """Load keys from key files."""
        payment_signing_key = PaymentSigningKey.load(payment_skey_path)
        payment_verification_key = PaymentVerificationKey.load(payment_vkey_path)
        stake_verification_key = PaymentVerificationKey.load(stake_vkey_path)

        address = Address(
            payment_verification_key.hash(), stake_verification_key.hash(), network
        )

        return (
            payment_signing_key,
            payment_verification_key,
            stake_verification_key,
            address,
        )

    @classmethod
    def load_from_config(
        cls, config: WalletConfig
    ) -> tuple[
        PaymentSigningKey, PaymentVerificationKey, PaymentVerificationKey, Address
    ]:
        """Load keys from WalletConfig."""
        if config.mnemonic:
            return cls.load_from_mnemonic(
                config.mnemonic, config.to_pycardano_network()
            )
        elif all(
            [config.payment_skey_path, config.payment_vkey_path, config.stake_vkey_path]
        ):
            return cls.load_from_files(
                config.payment_skey_path,
                config.payment_vkey_path,
                config.stake_vkey_path,
                config.to_pycardano_network(),
            )
        else:
            raise ConfigurationError(
                "Wallet config must contain either a mnemonic or all key file paths."
            )

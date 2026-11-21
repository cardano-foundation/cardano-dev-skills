"""Key and wallet management utilities for CLI operations."""

from dataclasses import dataclass
from pathlib import Path

from pycardano import (
    Address,
    ExtendedSigningKey,
    HDWallet,
    Network,
    PaymentSigningKey,
    PaymentVerificationKey,
)


@dataclass
class WalletConfig:
    """Configuration for wallet loading."""

    mnemonic: str | None = None
    withdrawal_mnemonic: str | None = None
    payment_skey_path: str | None = None
    payment_vkey_path: str | None = None
    stake_vkey_path: str | None = None
    network: Network = Network.TESTNET

    @classmethod
    def from_dict(cls, config: dict) -> "WalletConfig":
        """Create wallet config from dictionary."""
        return cls(
            mnemonic=config.get("mnemonic"),
            withdrawal_mnemonic=config.get("withdrawal_mnemonic"),
            payment_skey_path=config.get("payment_skey_path"),
            payment_vkey_path=config.get("payment_vkey_path"),
            stake_vkey_path=config.get("stake_vkey_path"),
            network=Network[config.get("network", "TESTNET").upper()],
        )


class KeyManager:
    """Manages loading and deriving keys from mnemonic or files."""

    @staticmethod
    def load_from_mnemonic(
        mnemonic: str, network: Network = Network.TESTNET
    ) -> tuple[
        PaymentSigningKey, PaymentVerificationKey, PaymentVerificationKey, Address
    ]:
        """Load keys from mnemonic phrase.

        Args:
            mnemonic: 24-word mnemonic phrase
            network: Target network

        Returns:
            Tuple of (payment signing key, payment verification key,
                     stake verification key, derived address)
        """
        # Create HD wallet from mnemonic
        hdwallet = HDWallet.from_mnemonic(mnemonic)

        # Derive payment keys
        payment_hdwallet = hdwallet.derive_from_path("m/1852'/1815'/0'/0/0")
        payment_signing_key = ExtendedSigningKey.from_hdwallet(payment_hdwallet)
        payment_verification_key = PaymentVerificationKey.from_primitive(
            payment_hdwallet.public_key
        )

        # Derive stake keys
        stake_hdwallet = hdwallet.derive_from_path("m/1852'/1815'/0'/2/0")
        stake_verification_key = PaymentVerificationKey.from_primitive(
            stake_hdwallet.public_key
        )

        # Create address
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
        """Load keys from key files.

        Args:
            payment_skey_path: Path to payment signing key file
            payment_vkey_path: Path to payment verification key file
            stake_vkey_path: Path to stake verification key file
            network: Target network

        Returns:
            Tuple of (payment signing key, payment verification key,
                     stake verification key, derived address)
        """
        # Load keys
        payment_signing_key = PaymentSigningKey.load(str(payment_skey_path))
        payment_verification_key = PaymentVerificationKey.load(str(payment_vkey_path))
        stake_verification_key = PaymentVerificationKey.load(str(stake_vkey_path))

        # Create address
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
        """Load keys from configuration.

        Args:
            config: Wallet configuration

        Returns:
            Tuple of (payment signing key, payment verification key,
                     stake verification key, derived address)

        Raises:
            ValueError: If neither mnemonic nor key paths are provided
        """
        if config.mnemonic:
            return cls.load_from_mnemonic(config.mnemonic, config.network)

        elif all(
            [config.payment_skey_path, config.payment_vkey_path, config.stake_vkey_path]
        ):
            return cls.load_from_files(
                config.payment_skey_path,
                config.payment_vkey_path,
                config.stake_vkey_path,
                config.network,
            )

        else:
            raise ValueError("Must provide either mnemonic or all key file paths")

    @staticmethod
    def derive_payment_vkh_from_mnemonic(
        mnemonic: str, network: Network = Network.TESTNET
    ) -> PaymentVerificationKey:
        """Derive only the payment verification key hash from a mnemonic.

        This is useful for deriving the withdrawal payment VKH from a separate mnemonic
        without loading the full wallet.

        Args:
            mnemonic: 24-word mnemonic phrase
            network: Target network

        Returns:
            Payment verification key
        """
        hdwallet = HDWallet.from_mnemonic(mnemonic)
        payment_hdwallet = hdwallet.derive_from_path("m/4343'/1815'/0'/0/1")
        payment_verification_key = PaymentVerificationKey.from_primitive(
            payment_hdwallet.public_key
        )
        return payment_verification_key

    @staticmethod
    def load_withdrawal_key_from_mnemonic(
        mnemonic: str, network: Network = Network.TESTNET
    ) -> tuple[PaymentSigningKey, PaymentVerificationKey, Address]:
        """Load withdrawal keys from mnemonic (derivation path .../0/0/1).

        Args:
            mnemonic: 24-word mnemonic phrase
            network: Target network

        Returns:
            Tuple of (payment signing key, payment verification key, derived address)
        """
        hdwallet = HDWallet.from_mnemonic(mnemonic)
        # Withdrawal key path
        payment_hdwallet = hdwallet.derive_from_path("m/1852'/1815'/0'/0/0")
        payment_signing_key = ExtendedSigningKey.from_hdwallet(payment_hdwallet)
        payment_verification_key = PaymentVerificationKey.from_primitive(
            payment_hdwallet.public_key
        )
        # Enterprise address (no stake key)
        address = Address(payment_part=payment_verification_key.hash(), network=network)

        return payment_signing_key, payment_verification_key, address

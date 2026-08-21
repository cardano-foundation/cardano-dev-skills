package apollo

import (
	"errors"
	"fmt"

	"github.com/blinklabs-io/bursa"
	"github.com/blinklabs-io/bursa/bip32"
	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// Wallet provides signing and address capabilities for transaction building.
type Wallet interface {
	// Address returns the payment address for this wallet.
	Address() common.Address
	// SignTxBody signs a serialized transaction body hash and returns a VkeyWitness.
	SignTxBody(txBodyHash common.Blake2b256) (common.VkeyWitness, error)
	// PubKeyHash returns the payment public key hash.
	PubKeyHash() common.Blake2b224
	// StakePubKeyHash returns the staking public key hash (zero if not staking).
	StakePubKeyHash() common.Blake2b224
}

// BursaWallet wraps bursa key derivation for HD wallet functionality.
type BursaWallet struct {
	mnemonic   string
	address    common.Address
	paymentKey bip32.XPrv
	stakeKey   bip32.XPrv
}

// NewBursaWallet creates a new wallet from a mnemonic string.
// An optional passphrase can be provided for BIP39 key derivation.
func NewBursaWallet(mnemonic string, opts ...bursa.WalletOption) (*BursaWallet, error) {
	return NewBursaWalletWithPassphrase(mnemonic, "", opts...)
}

// NewBursaWalletWithPassphrase creates a new wallet from a mnemonic and passphrase.
// The passphrase is used for BIP39 key derivation.
func NewBursaWalletWithPassphrase(mnemonic string, passphrase string, opts ...bursa.WalletOption) (*BursaWallet, error) {
	// Resolve the effective bursa configuration so signing keys are derived
	// with the same passphrase and indices as the address.
	cfg := &bursa.WalletConfig{Network: "mainnet"}
	for _, opt := range opts {
		opt(cfg)
	}
	if cfg.Password != "" && passphrase != "" && cfg.Password != passphrase {
		return nil, errors.New("conflicting passphrases: bursa.WithPassword option does not match the passphrase argument")
	}
	if passphrase == "" {
		passphrase = cfg.Password
	}
	// bursa derives the payment address credentials from the address index,
	// so payment/stake indices that differ from it would yield signing keys
	// that do not control the wallet address.
	if cfg.PaymentID != cfg.AddressID || cfg.StakeID != cfg.AddressID {
		return nil, errors.New("bursa derives the wallet address from WithAddressID; conflicting WithPaymentID/WithStakeID values are not supported")
	}

	// Append WithPassword last so the address derivation always uses the same
	// passphrase as key derivation.
	allOpts := append(append([]bursa.WalletOption{}, opts...), bursa.WithPassword(passphrase))
	w, err := bursa.NewWallet(mnemonic, allOpts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create bursa wallet: %w", err)
	}

	addr, err := common.NewAddress(w.PaymentAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to parse wallet address: %w", err)
	}

	// Derive keys directly for signing, using the same indices bursa used for
	// the address (account index, then address index for both credentials).
	rootKey, err := bursa.GetRootKeyFromMnemonic(mnemonic, passphrase)
	if err != nil {
		return nil, fmt.Errorf("failed to derive root key: %w", err)
	}
	accountKey, err := bursa.GetAccountKey(rootKey, cfg.AccountID)
	if err != nil {
		return nil, fmt.Errorf("failed to derive account key: %w", err)
	}
	paymentKey, err := bursa.GetPaymentKey(accountKey, cfg.AddressID)
	if err != nil {
		return nil, fmt.Errorf("failed to derive payment key: %w", err)
	}
	stakeKey, err := bursa.GetStakeKey(accountKey, cfg.AddressID)
	if err != nil {
		return nil, fmt.Errorf("failed to derive stake key: %w", err)
	}

	// Fail closed if the derived keys do not control the wallet address.
	if common.Blake2b224Hash(paymentKey.Public().PublicKey()) != addr.PaymentKeyHash() {
		return nil, errors.New("derived payment key does not match the wallet address payment credential")
	}
	if common.Blake2b224Hash(stakeKey.Public().PublicKey()) != addr.StakeKeyHash() {
		return nil, errors.New("derived stake key does not match the wallet address stake credential")
	}

	return &BursaWallet{
		mnemonic:   w.Mnemonic,
		address:    addr,
		paymentKey: paymentKey,
		stakeKey:   stakeKey,
	}, nil
}

// NewBursaWalletGenerate creates a new wallet with a generated mnemonic.
func NewBursaWalletGenerate(opts ...bursa.WalletOption) (*BursaWallet, error) {
	mnemonic, err := bursa.GenerateMnemonic()
	if err != nil {
		return nil, fmt.Errorf("failed to generate mnemonic: %w", err)
	}
	return NewBursaWallet(mnemonic, opts...)
}

func (w *BursaWallet) Address() common.Address {
	return w.address
}

func (w *BursaWallet) SignTxBody(txBodyHash common.Blake2b256) (common.VkeyWitness, error) {
	return common.VkeyWitness{
		Vkey:      w.paymentKey.Public().PublicKey(),
		Signature: w.paymentKey.Sign(txBodyHash.Bytes()),
	}, nil
}

// EvaluationWitnesses provides payment and stake witnesses required by a
// preliminary transaction evaluation.
func (w *BursaWallet) EvaluationWitnesses(
	txBodyHash common.Blake2b256,
	requiredSigners []common.Blake2b224,
) ([]common.VkeyWitness, error) {
	witnesses := make([]common.VkeyWitness, 0, 2)
	for _, required := range requiredSigners {
		switch required {
		case w.PubKeyHash():
			witnesses = append(witnesses, common.VkeyWitness{
				Vkey:      w.paymentKey.Public().PublicKey(),
				Signature: w.paymentKey.Sign(txBodyHash.Bytes()),
			})
		case w.StakePubKeyHash():
			witnesses = append(witnesses, common.VkeyWitness{
				Vkey:      w.stakeKey.Public().PublicKey(),
				Signature: w.stakeKey.Sign(txBodyHash.Bytes()),
			})
		}
	}
	return witnesses, nil
}

func (w *BursaWallet) PubKeyHash() common.Blake2b224 {
	pubKey := w.paymentKey.Public().PublicKey()
	return common.Blake2b224Hash(pubKey)
}

func (w *BursaWallet) StakePubKeyHash() common.Blake2b224 {
	pubKey := w.stakeKey.Public().PublicKey()
	return common.Blake2b224Hash(pubKey)
}

// Mnemonic returns the mnemonic for this wallet.
func (w *BursaWallet) Mnemonic() string {
	return w.mnemonic
}

// String returns a safe string representation that does not expose key material.
// Value receiver so the redaction also applies to dereferenced values
// (e.g. fmt.Sprintf("%+v", *w)), which would otherwise dump the mnemonic.
func (w BursaWallet) String() string {
	return fmt.Sprintf("BursaWallet{address: %s}", w.address.String())
}

// GoString implements fmt.GoStringer to prevent key material from leaking via %#v.
func (w BursaWallet) GoString() string {
	return w.String()
}

// KeyPairWallet provides signing from raw key bytes.
type KeyPairWallet struct {
	address    common.Address
	privateKey bip32.XPrv
}

// NewKeyPairWallet creates a wallet from a BIP32 extended private key and address.
// The key must be a 96-byte BIP32-Ed25519 extended private key; bursa's bip32
// primitives panic on other lengths, so this is validated up front.
func NewKeyPairWallet(addr common.Address, key bip32.XPrv) (*KeyPairWallet, error) {
	if len(key) != 96 {
		return nil, fmt.Errorf("invalid BIP32 extended private key length: expected 96 bytes, got %d", len(key))
	}
	keyCopy := make(bip32.XPrv, len(key))
	copy(keyCopy, key)
	return &KeyPairWallet{
		address:    addr,
		privateKey: keyCopy,
	}, nil
}

func (w *KeyPairWallet) Address() common.Address {
	return w.address
}

func (w *KeyPairWallet) SignTxBody(txBodyHash common.Blake2b256) (common.VkeyWitness, error) {
	return common.VkeyWitness{
		Vkey:      w.privateKey.Public().PublicKey(),
		Signature: w.privateKey.Sign(txBodyHash.Bytes()),
	}, nil
}

func (w *KeyPairWallet) PubKeyHash() common.Blake2b224 {
	pubKey := w.privateKey.Public().PublicKey()
	return common.Blake2b224Hash(pubKey)
}

// StakePubKeyHash returns a zero hash because KeyPairWallet has no staking key.
func (w *KeyPairWallet) StakePubKeyHash() common.Blake2b224 {
	return common.Blake2b224{}
}

// String returns a safe string representation that does not expose key material.
// Value receiver so the redaction also applies to dereferenced values
// (e.g. fmt.Sprintf("%+v", *w)), which would otherwise dump the private key.
func (w KeyPairWallet) String() string {
	return fmt.Sprintf("KeyPairWallet{address: %s}", w.address.String())
}

// GoString implements fmt.GoStringer to prevent key material from leaking via %#v.
func (w KeyPairWallet) GoString() string {
	return w.String()
}

// ExternalWallet is an address-only wallet for watch-only flows.
// It cannot sign transactions.
type ExternalWallet struct {
	address common.Address
}

// NewExternalWallet creates a watch-only wallet from an address.
func NewExternalWallet(addr common.Address) *ExternalWallet {
	return &ExternalWallet{address: addr}
}

func (w *ExternalWallet) Address() common.Address {
	return w.address
}

func (w *ExternalWallet) SignTxBody(_ common.Blake2b256) (common.VkeyWitness, error) {
	return common.VkeyWitness{}, errors.New("external wallet cannot sign transactions")
}

func (w *ExternalWallet) PubKeyHash() common.Blake2b224 {
	return w.address.PaymentKeyHash()
}

func (w *ExternalWallet) StakePubKeyHash() common.Blake2b224 {
	return w.address.StakeKeyHash()
}

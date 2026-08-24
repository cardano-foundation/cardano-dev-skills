# Wallets

Apollo signs through the `Wallet` interface:

```go
type Wallet interface {
    Address() common.Address
    SignTxBody(txBodyHash common.Blake2b256) (common.VkeyWitness, error)
    PubKeyHash() common.Blake2b224
    StakePubKeyHash() common.Blake2b224
}
```

Set a wallet with `SetWallet(w)` or the mnemonic helpers. The wallet address is
the default change address; `SetWalletAsChangeAddress` from v1 is gone.

`fmt` of `BursaWallet` and `KeyPairWallet` redacts key material (`String` /
`GoString`).

## Bursa HD wallet

[bursa](https://github.com/blinklabs-io/bursa) derives CIP-1852 payment and
stake keys from a BIP39 mnemonic.

```go
builder, err := apollo.New(ctx).SetWalletFromMnemonic(mnemonic)
builder, err = apollo.New(ctx).SetWalletFromMnemonicWithPassphrase(mnemonic, passphrase)

wallet, err := apollo.NewBursaWallet(mnemonic)
wallet, err = apollo.NewBursaWalletWithPassphrase(mnemonic, passphrase)
wallet, err = apollo.NewBursaWalletGenerate() // new mnemonic
builder = apollo.New(ctx).SetWallet(wallet)
```

Passphrase rules:

- `NewBursaWalletWithPassphrase` and `bursa.WithPassword` must not disagree.
- Payment and stake derivation indices must match the address index
  (`WithAddressID`). Conflicting `WithPaymentID` / `WithStakeID` are rejected
  so the signing keys actually control the address.
- Construction fails closed if the derived hashes do not match the address
  payment and stake credentials.

`BursaWallet` can also sign the stake key during
[evaluation](evaluation_witnesses.md). `Mnemonic()` returns the phrase; do not
log it.

## Key-pair wallet

`NewKeyPairWallet(addr, key)` takes a 96-byte BIP32-Ed25519 extended private
key. Other lengths are rejected up front (bursa panics on them). There is no
staking key: `StakePubKeyHash()` is zero.

This is **not** a replacement for v1 `SetWalletFromKeypair` of raw vkey/skey
pairs. Build an address, then wrap it.

## External (watch-only) wallet

```go
addr, err := apollo.ParseAddress("addr1...")
builder = apollo.New(ctx).SetWallet(apollo.NewExternalWallet(addr))
```

`SignTxBody` always errors. Use this for hardware, remote, or "build unsigned"
flows. After `Complete()`, attach witnesses with `AddVerificationKeyWitness` or
`SignWithSkey`, or sign outside Apollo.

`ExternalWallet` is skipped when Apollo collects
[evaluation witnesses](evaluation_witnesses.md). Register an
`EvaluationWitnessProvider` for any required hashes that wallet would have
signed.

v1 `SetWalletFromBech32` is this pattern: parse, then `NewExternalWallet`.

## Extra signatures

```go
builder, err = builder.Sign()                     // wallet payment key
builder, err = builder.SignWithSkey(extendedSkey) // additional payment key
builder, err = builder.AddVerificationKeyWitness(witness)
```

Call `Complete()` before `Sign()`. Required signers on the body are
`AddRequiredSigner`, `AddRequiredSignerPaymentKey`, and
`AddRequiredSignerStakeKey`.

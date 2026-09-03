# Credential Helpers

This page documents how to obtain **stake credentials** and use **addresses with a staking part** in Apollo v2: `GetStakeCredentialFromWallet`, `GetStakeCredentialFromAddress`, and related address/wallet assumptions. Implementation: [`apollo.go`](../../apollo.go), [`helpers.go`](../../helpers.go).

## Purpose and method signatures

### GetStakeCredentialFromWallet

```go
func (a *Apollo) GetStakeCredentialFromWallet() (common.Credential, error)
```

Returns the stake credential derived from the wallet's address. Requires a wallet with a staking component (e.g. `BursaWallet` from mnemonic).

### GetStakeCredentialFromAddress

```go
func GetStakeCredentialFromAddress(addr common.Address) (common.Credential, error)
```

Extracts the staking credential from an address's `StakingPayload()`. Supports both key hash and script hash staking components. Returns an error if the address has no staking part.

## Inputs and constraints

- **Stake credential**: `common.Credential` with `CredType` (0 = key hash, 1 = script hash) and `Credential` (`common.Blake2b224`). Used in certificates and when building stake/reward addresses.
- **GetStakeCredentialFromWallet**: Delegates to `GetStakeCredentialFromAddress` using the wallet's address. Works with any wallet whose address has a staking component (including `ExternalWallet` and `KeyPairWallet`). Returns an error if the wallet is not set or the address has no staking part.
- **GetStakeCredentialFromAddress**: Address must have a valid staking component (base address or stake address).

## Behavior details

- **Address**: Apollo uses `common.Address` from gouroboros. Base addresses have both payment and staking components. Stake-only addresses have a staking component and correct header/hrp.
- **BursaWallet**: Derives payment and staking keys from mnemonic (staking path `m/1852'/1815'/0'/2/0`). `StakePubKeyHash()` returns the stake key hash.
- **resolveCredential**: Internal helper used by all staking methods. Accepts `*common.Credential`, `common.Credential`, `common.Address`, `string` (bech32), or `nil` (wallet fallback). This is what powers the unified `any` parameter in methods like `RegisterStake(credOrAddr any)`.

## Cardano CLI equivalence (10.14.0.0)

| CLI | Apollo |
|-----|--------|
| `stake-address build` (from verification key) | Build credential with `GetStakeCredentialFromWallet()` or `GetStakeCredentialFromAddress()` |
| `address build --stake-verification-key-file` | Build `common.Address` with staking component |
| Staking key from mnemonic | `NewBursaWallet(mnemonic)`; wallet has `StakePubKeyHash()` |

## Example

**Apollo (credential from wallet, then use in certificate):**

```go
import (
    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

cred, err := a.GetStakeCredentialFromWallet()
if err != nil {
    // wallet has no stake keys
}
a, err = a.RegisterStake(&cred)
```

**Apollo (credential from address):**

```go
addr, err := common.NewAddress("stake1u...")
if err != nil {
    panic(err)
}
cred, err := apollo.GetStakeCredentialFromAddress(addr)
```

**Apollo (unified method with bech32 - no explicit credential needed):**

```go
// RegisterStake accepts bech32 string directly
a, err = a.RegisterStake("stake1u...")
```

## Caveats and validation

- `GetStakeCredentialFromWallet()` requires a wallet whose address has a staking component.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.
- Validate on preprod/mainnet with small amounts when relying on implementation-only paths.

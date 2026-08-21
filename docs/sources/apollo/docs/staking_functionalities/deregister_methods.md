# Deregister Methods

This page documents **stake deregistration**: `DeregisterStake`, `DeregisterStakeFromAddress`, `DeregisterStakeFromBech32`. Deregistering refunds the current network's stake key deposit (2 ADA on networks using the default); `Complete()` accounts for the refund. Implementation: [`apollo.go`](../../apollo.go), [`convenience.go`](../../convenience.go).

## Purpose and method signatures

### DeregisterStake (unified)

```go
func (a *Apollo) DeregisterStake(credOrAddr any) (*Apollo, error)
```

`credOrAddr` can be: `*common.Credential`, `common.Credential`, `common.Address`, `string` (bech32), or `nil` (uses wallet). Appends a `StakeDeregistration` certificate.

### DeregisterStakeFromAddress / DeregisterStakeFromBech32

```go
func (a *Apollo) DeregisterStakeFromAddress(addr common.Address) (*Apollo, error)
func (a *Apollo) DeregisterStakeFromBech32(bech32 string) (*Apollo, error)
```

Type-safe convenience methods that delegate to `DeregisterStake`.

## Inputs and constraints

- Credential from wallet (nil), from address, or from Bech32 string. Same pattern as registration helpers.
- The unified method accepts any of the listed types; the `FromAddress`/`FromBech32` variants provide compile-time type safety.

## Behavior details

- The transaction's requested balance is **reduced** by the deposit refund in `Complete()` when deregistration certificates are present.

## Cardano CLI equivalence (10.14.0.0)

| CLI                                        | Apollo                                                                                             |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| `stake-address deregistration-certificate` | `DeregisterStake(cred)` / `DeregisterStakeFromAddress(addr)` / `DeregisterStakeFromBech32(bech32)` |

## Example

### Deregister using wallet credential

```go
import (
    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

a := apollo.New(cc)
a.SetWallet(wallet)
a, err := a.DeregisterStake(nil)
if err != nil {
    panic(err)
}
a.AddLoadedUTxOs(utxos...)
a.PayToAddress(myAddr, 10_000_000)
tx, err := a.Complete()
```

### Deregister from bech32 address

```go
a, err = a.DeregisterStakeFromBech32("stake1u...")
```

**Cardano CLI:**

```bash
cardano-cli stake-address deregistration-certificate --stake-verification-key-file stake.vkey --out-file dereg.cert
cardano-cli transaction build --certificate-file dereg.cert ...
```

## Caveats and validation

- Ensure the stake key is actually registered before deregistering.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.
- Validate on preprod/mainnet with small amounts.

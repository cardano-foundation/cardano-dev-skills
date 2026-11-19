# Delegate Vote Methods

This page documents **vote (DRep) delegation**: `DelegateVote*`. Implementation: [`apollo.go`](../../apollo.go), [`convenience.go`](../../convenience.go).

## DRep type

`common.Drep` (from gouroboros):

- `Type`: 0 = key hash, 1 = script hash, or special values for "always abstain" / "no confidence."
- `Credential`: optional key or script hash (zero for abstain/no-confidence).

Build a `Drep` and pass it into the delegation methods.

## Purpose and method signatures

### DelegateVote (unified)

```go
func (a *Apollo) DelegateVote(credOrAddr any, drep common.Drep) (*Apollo, error)
```

`credOrAddr` can be: `*common.Credential`, `common.Credential`, `common.Address`, `string` (bech32), or `nil` (uses wallet). Appends a `VoteDelegCert` certificate (vote-only; stake key may already be registered).

### DelegateVoteFromAddress / DelegateVoteFromBech32

```go
func (a *Apollo) DelegateVoteFromAddress(addr common.Address, drep common.Drep) (*Apollo, error)
func (a *Apollo) DelegateVoteFromBech32(bech32 string, drep common.Drep) (*Apollo, error)
```

Type-safe convenience methods that delegate to `DelegateVote`.

## Inputs and constraints

- DRep key/script hash and special codes must match what the node expects.
- The unified method accepts any of the listed types; the `FromAddress`/`FromBech32` variants provide compile-time type safety.

## Cardano CLI equivalence (10.14.0.0)

| CLI                    | Apollo                                                                                                              |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Vote delegation cert   | `DelegateVote(cred, drep)` / `DelegateVoteFromAddress(addr, drep)` / `DelegateVoteFromBech32(bech32, drep)` |

## Example

### Vote delegation (using wallet credential)

```go
import (
    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

drep := common.Drep{
    Type: 0,
    Credential: drepKeyHash,
}
a := apollo.New(cc)
a.SetWallet(wallet)
a, err := a.DelegateVote(nil, drep)
if err != nil {
    panic(err)
}
a.AddLoadedUTxOs(utxos...)
a.PayToAddress(myAddr, 10_000_000)
tx, err := a.Complete()
```

### Delegate vote from bech32 address

```go
a, err = a.DelegateVoteFromBech32("stake1u...", drep)
```

**Cardano CLI:** Vote delegation certificate in `transaction build`.

## Caveats and validation

- No end-to-end integration tests for vote delegation are documented here. Validate on preprod/mainnet with small amounts.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.

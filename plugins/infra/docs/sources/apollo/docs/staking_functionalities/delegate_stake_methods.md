# Delegate Stake Methods

This page documents **stake pool delegation** and **stake+vote delegation**: `DelegateStake*`, `DelegateStakeAndVote*`. Implementation: [`apollo.go`](../../apollo.go), [`convenience.go`](../../convenience.go).

## Purpose and method signatures

### DelegateStake (unified)

```go
func (a *Apollo) DelegateStake(credOrAddr any, poolHash common.Blake2b224) (*Apollo, error)
```

`credOrAddr` can be: `*common.Credential`, `common.Credential`, `common.Address`, `string` (bech32), or `nil` (uses wallet). Appends a `StakeDelegation` certificate.

### DelegateStakeFromAddress / DelegateStakeFromBech32

```go
func (a *Apollo) DelegateStakeFromAddress(addr common.Address, poolHash common.Blake2b224) (*Apollo, error)
func (a *Apollo) DelegateStakeFromBech32(bech32 string, poolHash common.Blake2b224) (*Apollo, error)
```

Type-safe convenience methods that delegate to `DelegateStake`.

### DelegateStakeAndVote (unified)

```go
func (a *Apollo) DelegateStakeAndVote(credOrAddr any, poolHash common.Blake2b224, drep common.Drep) (*Apollo, error)
```

Appends a `StakeVoteDelegCert` (kind 10): delegates both stake (to pool) and vote (to DRep) in one certificate.

### DelegateStakeAndVoteFromAddress / DelegateStakeAndVoteFromBech32

```go
func (a *Apollo) DelegateStakeAndVoteFromAddress(addr common.Address, poolHash common.Blake2b224, drep common.Drep) (*Apollo, error)
func (a *Apollo) DelegateStakeAndVoteFromBech32(bech32 string, poolHash common.Blake2b224, drep common.Drep) (*Apollo, error)
```

## Inputs and constraints

- `poolHash`: 28-byte cold key hash (`common.Blake2b224`) of the target stake pool.
- `drep`: `common.Drep` with Type (0 = key hash, 1 = script hash, or special values) and optional Credential.

## Cardano CLI equivalence (10.14.0.0)

| CLI                                    | Apollo                                                               |
| -------------------------------------- | -------------------------------------------------------------------- |
| `stake-address delegation-certificate` | `DelegateStake(cred, poolHash)` / `DelegateStakeFromAddress(addr, poolHash)` / `DelegateStakeFromBech32(bech32, poolHash)` |
| Stake + vote delegation (one cert)     | `DelegateStakeAndVote(cred, poolHash, drep)` etc.                    |

## Examples

### Stake pool delegation (using wallet credential)

```go
import (
    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

var poolHash common.Blake2b224
a := apollo.New(cc)
a.SetWallet(wallet)
a, err := a.DelegateStake(nil, poolHash)
if err != nil {
    panic(err)
}
a.AddLoadedUTxOs(utxos...)
a.PayToAddress(myAddr, 10_000_000)
tx, err := a.Complete()
```

### Delegate from bech32 address

```go
a, err = a.DelegateStakeFromBech32("stake1u...", poolHash)
```

**Cardano CLI:**

```bash
cardano-cli stake-address delegation-certificate --stake-verification-key-file stake.vkey --cold-verification-key-file pool.vkey --out-file deleg.cert
cardano-cli transaction build --certificate-file deleg.cert ...
```

### Stake and vote delegation (one cert)

```go
drep := common.Drep{Type: 0, Credential: drepKeyHash}
a, err = a.DelegateStakeAndVote(nil, poolHash, drep)
```

## Caveats and validation

- Pool key hash must be the correct cold key hash. DRep must match node expectations.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.
- Validate on preprod/mainnet with small amounts.

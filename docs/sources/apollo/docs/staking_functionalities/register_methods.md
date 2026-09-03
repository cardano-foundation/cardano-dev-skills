# Register Methods

This page documents **stake registration** and **register+delegate** certificate methods. Implementation: [`apollo.go`](../../apollo.go), [`convenience.go`](../../convenience.go).

## Constants

- **Stake key deposit**: `StakeDeposit` in `apollo.go` is the 2 ADA (`2_000_000` lovelace) fallback. When registration certificates are present, `Complete()` uses the current network's `key_deposit` protocol parameter when available.

## Purpose and method signatures

### RegisterStake (unified)

```go
func (a *Apollo) RegisterStake(credOrAddr any) (*Apollo, error)
```

`credOrAddr` can be: `*common.Credential`, `common.Credential`, `common.Address`, `string` (bech32), or `nil` (uses wallet). Appends a `StakeRegistration` certificate.

### RegisterStakeFromAddress / RegisterStakeFromBech32

```go
func (a *Apollo) RegisterStakeFromAddress(addr common.Address) (*Apollo, error)
func (a *Apollo) RegisterStakeFromBech32(bech32 string) (*Apollo, error)
```

Type-safe convenience methods that delegate to `RegisterStake`.

### RegisterAndDelegateStake (unified)

```go
func (a *Apollo) RegisterAndDelegateStake(credOrAddr any, poolHash common.Blake2b224, coin int64) (*Apollo, error)
```

`coin` is the deposit (typically `StakeDeposit`). Appends a `StakeRegDelegCert` certificate.

### RegisterAndDelegateStakeFromAddress / FromBech32

```go
func (a *Apollo) RegisterAndDelegateStakeFromAddress(addr common.Address, poolHash common.Blake2b224, coin int64) (*Apollo, error)
func (a *Apollo) RegisterAndDelegateStakeFromBech32(bech32 string, poolHash common.Blake2b224, coin int64) (*Apollo, error)
```

### RegisterAndDelegateVote (unified)

```go
func (a *Apollo) RegisterAndDelegateVote(credOrAddr any, drep common.Drep, coin int64) (*Apollo, error)
```

Appends a `VoteRegDelegCert` (kind 12). Deposit required.

### RegisterAndDelegateVoteFromAddress / FromBech32

```go
func (a *Apollo) RegisterAndDelegateVoteFromAddress(addr common.Address, drep common.Drep, coin int64) (*Apollo, error)
func (a *Apollo) RegisterAndDelegateVoteFromBech32(bech32 string, drep common.Drep, coin int64) (*Apollo, error)
```

### RegisterAndDelegateStakeAndVote (unified)

```go
func (a *Apollo) RegisterAndDelegateStakeAndVote(credOrAddr any, poolHash common.Blake2b224, drep common.Drep, coin int64) (*Apollo, error)
```

Appends a `StakeVoteRegDelegCert` (kind 13). Deposit required.

### RegisterAndDelegateStakeAndVoteFromAddress / FromBech32

```go
func (a *Apollo) RegisterAndDelegateStakeAndVoteFromAddress(addr common.Address, poolHash common.Blake2b224, drep common.Drep, coin int64) (*Apollo, error)
func (a *Apollo) RegisterAndDelegateStakeAndVoteFromBech32(bech32 string, poolHash common.Blake2b224, drep common.Drep, coin int64) (*Apollo, error)
```

## Inputs and constraints

- Ensure inputs cover the current network's key deposit when registering (2 ADA by default). `Complete()` adds the protocol-parameter amount automatically when it is available.
- Pool key hash must be the correct 28-byte cold key hash for the target pool. DRep must be built as `common.Drep`.
- The unified methods accept any of the listed types; the `FromAddress`/`FromBech32` variants provide compile-time type safety.

## Behavior details

- Apollo's staking methods **append** certificates to the builder's certificate list. `SetCertificates(certs)` is available to set the full list at once if needed.

## Cardano CLI equivalence (10.14.0.0)

| CLI                                      | Apollo                                                                     |
| ---------------------------------------- | -------------------------------------------------------------------------- |
| `stake-address registration-certificate` | `RegisterStake(cred)` / `RegisterStakeFromAddress(addr)` / `RegisterStakeFromBech32(bech32)` |
| Reg + deleg (combined cert)              | `RegisterAndDelegateStake(cred, poolHash, StakeDeposit)` etc.             |
| Reg + vote delegation                    | `RegisterAndDelegateVote(cred, drep, coin)` etc.                           |
| Reg + stake + vote                       | `RegisterAndDelegateStakeAndVote(cred, poolHash, drep, coin)` etc.         |

## Examples

### Stake registration (using wallet credential)

```go
import (
    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

a := apollo.New(cc)
a.SetWallet(wallet)
a, err := a.RegisterStake(nil) // nil => use wallet credential
if err != nil {
    panic(err)
}
a.AddLoadedUTxOs(utxos...)
a.PayToAddress(myAddr, 10_000_000)
tx, err := a.Complete()
```

### Register from bech32 address

```go
a, err = a.RegisterStakeFromBech32("stake1u...")
```

### Register and delegate in one transaction

```go
cred, err := a.GetStakeCredentialFromWallet()
if err != nil {
    panic(err)
}
a, err = a.RegisterAndDelegateStake(&cred, poolKeyHash, apollo.StakeDeposit)
if err != nil {
    panic(err)
}
a.AddLoadedUTxOs(utxos...)
a.PayToAddress(myAddr, 12_000_000)
tx, err := a.Complete()
```

## Caveats and validation

- Ensure enough inputs for the current network's key deposit (2 ADA by default). Pool key hash and DRep must match node expectations.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.
- Validate on preprod/mainnet with small amounts before production use.

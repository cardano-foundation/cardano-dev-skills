# Migrating from the SundaeSwap Apollo Fork

This page is a focused checklist for applications moving from
`github.com/SundaeSwap-finance/apollo` to Apollo v2. The forks have diverged,
so do not assume that types or method signatures are interchangeable.

## Change the module path

Replace Apollo imports with the v2 module path:

```go
import apollo "github.com/Salvionied/apollo/v2"
```

Apollo v2 does not contain the old `serialization/*` package tree. Replace
those imports with ledger types from gouroboros, primarily:

```go
import "github.com/blinklabs-io/gouroboros/ledger/common"
```

Then run:

```bash
go mod tidy
go test ./...
```

## Builder differences to check

Apollo v2 uses these current signatures:

```go
builder := apollo.New(chainContext)

builder, err := builder.Complete()
txCbor, err := builder.GetTxCbor()

builder = builder.AddLoadedUTxOs(utxos...)
builder = builder.PayToAddress(address, lovelace, units...)
builder = builder.CollectFrom(utxo, redeemer, exUnits)

builder, err = builder.AddReferenceInput(txHash, index)
used := builder.GetUsedUTxOs() // map[string]bool
```

Reference scripts are constructed from a `common.Script`; the constructor can
fail for an unsupported or nil script:

```go
scriptRef, err := apollo.NewScriptRef(script)
if err != nil {
    return err
}
```

Datums are `common.Datum` values. The underlying Plutus data representation
comes from `github.com/blinklabs-io/plutigo/data`; there is no
`common.PlutusData` type.

## Custom chain contexts

Custom backends must implement `backend.ChainContext` from
`github.com/Salvionied/apollo/v2/backend`. Use that interface as the source of
truth rather than copying method lists into application code; compile-time
conformance catches future signature changes:

```go
var _ backend.ChainContext = (*myChainContext)(nil)
```

The repository includes Blockfrost, Ogmios/Kupo, UTxO RPC, and a deterministic
fixed backend for tests.

## Dependency expectations

Apollo v2 currently uses Blink Labs packages for ledger behavior, wallet key
derivation, and Plutus data:

- `github.com/blinklabs-io/gouroboros`
- `github.com/blinklabs-io/bursa`
- `github.com/blinklabs-io/plutigo`

Backend implementations may have additional provider-specific dependencies.
Applications should not import Apollo's transitive dependencies directly.

## Recommended migration process

1. Change the Apollo module path and remove old `serialization/*` imports.
2. Replace serialization types with the corresponding gouroboros/common types.
3. Update calls based on compiler errors; pay particular attention to methods
   returning `(*Apollo, error)`.
4. Update custom backends to satisfy `backend.ChainContext`.
5. Run `go mod tidy`, `gofmt`, and `go test -race ./...`.

For migration from Salvionied Apollo v1, use the
[v1-to-v2 migration guide](v2_migration/MIGRATION.md).

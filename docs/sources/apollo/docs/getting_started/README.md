# Install and first transaction

Apollo v2 is the module `github.com/Salvionied/apollo/v2`. It requires **Go
1.25.13 or newer**. The `go` directive in `go.mod` is a hard floor: an older
1.25 patch refuses to build the module rather than warning.

```bash
go get github.com/Salvionied/apollo/v2
```

Ledger types come from [gouroboros](https://github.com/blinklabs-io/gouroboros).
Import `apollo` with an alias so it does not collide with the package name:

```go
apollo "github.com/Salvionied/apollo/v2"
```

## Network IDs

Backend constructors take a Cardano **network ID**, not a named enum:

| Network | ID |
|---------|----|
| Mainnet | `1` |
| Preview, preprod, and other testnets | `0` |

Apollo v1 exported `constants.MAINNET` numbered `0`, the inverse of these IDs.
That enum is gone. Pass `1` or `0` directly. Blockfrost base URLs live in
[`constants`](https://pkg.go.dev/github.com/Salvionied/apollo/v2/constants):
`BlockfrostBaseUrlMainnet`, `BlockfrostBaseUrlPreview`,
`BlockfrostBaseUrlPreprod`.

## Lifecycle

1. Construct a [`ChainContext`](../backends/README.md).
2. `apollo.New(ctx)` then set a [wallet](../wallets/README.md).
3. Load UTxOs (`AddLoadedUTxOs`, `AddInputAddress`, or both).
4. Add outputs, scripts, certificates, metadata.
5. `Complete()` — coin selection, fees, collateral, execution units.
6. `Sign()` — wallet witness. Extra witnesses via `AddVerificationKeyWitness`
   or `SignWithSkey`.
7. `GetTx()` / `GetTxCbor()` and optionally `Submit()`.

`Complete()` may be called **once**. A second call returns
`transaction already built - call Complete() only once`. Use `Clone()` before
`Complete()` if you need a second attempt from the same builder state.

## First ADA payment

```go
package main

import (
    "encoding/hex"
    "fmt"

    "github.com/blinklabs-io/gouroboros/ledger/common"

    apollo "github.com/Salvionied/apollo/v2"
    "github.com/Salvionied/apollo/v2/backend/blockfrost"
    "github.com/Salvionied/apollo/v2/constants"
)

func main() {
    chain := blockfrost.NewBlockFrostChainContext(
        constants.BlockfrostBaseUrlMainnet,
        1,
        "your_blockfrost_project_id",
    )

    builder, err := apollo.New(chain).SetWalletFromMnemonic("your mnemonic here")
    if err != nil {
        panic(err)
    }

    utxos, err := chain.Utxos(builder.GetWallet().Address())
    if err != nil {
        panic(err)
    }

    receiver, err := common.NewAddress("addr1...")
    if err != nil {
        panic(err)
    }

    builder, err = builder.
        AddLoadedUTxOs(utxos...).
        PayToAddress(receiver, 1_000_000).
        Complete()
    if err != nil {
        panic(err)
    }

    builder, err = builder.Sign()
    if err != nil {
        panic(err)
    }

    txId, err := builder.Submit()
    if err != nil {
        panic(err)
    }
    fmt.Println(hex.EncodeToString(txId.Bytes()))
}
```

Prefer `apollo.ParseAddress` over `common.NewAddress` when the input might be
mistyped. See [address validation](../validation/README.md).

## Next

- [Fluent builder and errors](fluent_api.md)
- [Backends](../backends/README.md)
- [v1 to v2 migration](../v2_migration/MIGRATION.md)

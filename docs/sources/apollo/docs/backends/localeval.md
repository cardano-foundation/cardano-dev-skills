# Local script evaluation

`backend/localeval` computes Plutus execution units in-process with
gouroboros's ledger evaluator (built on plutigo), instead of asking a
provider. It produces the same units as the Haskell ledger: the tests compare
it with `cardano-cli transaction calculate-plutus-script-cost` on a mainnet
transaction and on V1, V2 and V3 scripts.

## Offline: `Evaluate`

`Evaluate` makes no chain queries. Supply the transaction, every UTxO it
spends or references, the protocol parameters and a slot mapping:

```go
import "github.com/Salvionied/apollo/v2/backend/localeval"

units, err := localeval.Evaluate(txCbor, utxos, localeval.Params{
    ProtocolParams: protocolParams, // cost models, version, max tx ex units
    SlotConfig:     localeval.PreprodSlotConfig,
})
```

Each script runs against the protocol's maximum transaction execution units
(`MaxTxExMem`, `MaxTxExSteps`), not the units its redeemer declares, and the
result is what it consumed. A failing script returns the evaluator's error,
which wraps `common.PlutusScriptFailedError`.

`SlotConfig` converts the validity interval to the POSIX times scripts see.
`MainnetSlotConfig`, `PreprodSlotConfig` and `PreviewSlotConfig` cover the
public networks; `SlotConfigForNetworkMagic` selects one by magic. For another
network, set `ZeroTime`, `ZeroSlot` and `SlotLength` for its current era.

## Wrapping a backend: `LocalEvalChainContext`

```go
cc := localeval.NewLocalEvalChainContext(inner)
```

`EvaluateTx` reads protocol parameters from `inner`, resolves inputs from its
`additionalUtxos` argument first and `inner.UtxoByRef` second, and evaluates
locally. Every other method is delegated to `inner`.

The slot mapping comes from `inner`'s genesis network magic for mainnet,
preprod and preview. For any other magic it starts at slot 0 at the genesis
system start, which suits networks with no Byron era, such as most local
devnets. Use `WithSlotConfig` otherwise:

```go
cc := localeval.NewLocalEvalChainContext(inner, localeval.WithSlotConfig(localeval.SlotConfig{
    ZeroTime:   shelleyStart,
    ZeroSlot:   firstShelleySlot,
    SlotLength: time.Second,
}))
```

**Capabilities:** those of `inner`, plus `EvaluateTx` and
`EvaluateTxAdditionalUtxos` when `inner` reports protocol parameters and
either reports genesis parameters or `WithSlotConfig` is set. Use `Unwrap` to
reach `inner`'s own optional methods.

## Limits

- Conway transactions and the top level of Dijkstra transactions. A Dijkstra
  transaction with sub-transaction redeemers is rejected, because
  `EvaluateTx`'s result has no field for the sub-transaction index.
- A language without a cost model in the protocol parameters cannot run, so a
  script in that language fails.
- `EvaluateTxContext` stops between chain queries when its context ends, but a
  script that has started runs to completion or to its budget.

# Complete, sign, and submit

## `Complete()`

Balances inputs and outputs, selects coins, derives fees and (when needed)
Plutus execution units, sets collateral, and builds a Conway transaction body.
It also:

- Loads UTxOs for `AddInputAddress*` if you did not pre-load them.
- Rejects mixed-network addresses (wallet, change, inputs, payments vs
  `NetworkId()`).
- Rejects a context network ID outside `{0, 1}`.
- Returns the first error stored by fluent methods (`setErrOnce`).
- May be called **once**. After success, `a.tx` is set.

v1 `CompleteExact(fee)` is `SetFee(fee)` then `Complete()`.
`SetEstimateRequired()` is automatic when `CollectFrom` or `Mint` carries a
redeemer.

## `Sign()` / `GetTx()` / `GetTxCbor()` / `Submit()`

```go
builder, err = builder.Sign()
tx := builder.GetTx()                 // *conway.ConwayTransaction
cborBytes, err := builder.GetTxCbor()
txId, err := builder.Submit()         // chainContext.SubmitTx
```

`Sign()` hashes the freshly encoded body (it does not trust a cached
`Body.Id()` after `SetCbor`). Extra witnesses:
`AddVerificationKeyWitness`, `SignWithSkey`.

## `LoadTxCbor`

Loads a hex-encoded Conway transaction into the builder (`a.tx`). Used to
inspect or re-submit an already-built body; it is not a substitute for
`Complete()`.

## `DisableExecutionUnitsEstimation`

Skips `EvaluateTx`. Every redeemer must already carry `ExUnits`.

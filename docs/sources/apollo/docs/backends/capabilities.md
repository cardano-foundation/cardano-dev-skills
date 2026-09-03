# Backend capabilities

A `ChainContext` always has the interface methods, but a particular provider
may not be able to honour every one. Backends that implement
`backend.CapabilityReporter` return a bit set:

```go
if !backend.Supports(ctx, backend.CapabilityEvaluateTxAdditionalUtxos) {
    // Do not pass chained, still-unconfirmed inputs as additionalUtxos.
}
```

Helpers:

- `backend.CapabilitiesOf(ctx)` — reported set, or `AllCapabilities` when the
  context does not implement `CapabilityReporter` (third-party backends stay
  source-compatible).
- `backend.Supports(ctx, cap)` — every requested bit is present.
- `backend.ErrUnsupported` / `backend.UnsupportedError` — use `errors.Is` /
  `errors.As` when a call is declined.

## Capability matrix (in-tree)

| Capability | Blockfrost | Ogmios | Ogmios (no Kupo) | UTxO RPC | Fixed |
|------------|:----------:|:------:|:----------------:|:--------:|:-----:|
| Protocol params | yes | yes | yes | yes | yes |
| Genesis params | yes | yes | yes | no | yes |
| Current epoch | yes | yes | yes | no | no |
| Max tx fee | yes | yes | yes | yes | yes |
| Tip | yes | yes | yes | yes | no |
| UTxOs by address | yes | yes | no | yes | yes |
| Submit | yes | yes | yes | yes | no |
| EvaluateTx | yes | yes | yes | yes | no |
| EvaluateTx additional UTxOs | yes | yes | yes | **no** | no |
| UTxO by ref | yes | yes | yes | yes | yes |
| Script CBOR | yes | yes | no | no | no |

`backend/cache` forwards `CapabilitiesOf(inner)`.

## Additional UTxOs and chaining

`EvaluateTx(txCbor, additionalUtxos)` lets the evaluator see inputs that are
not yet on chain (transaction chaining, indexing lag). Callers that need that
must check `CapabilityEvaluateTxAdditionalUtxos` first.

Apollo itself checks the capability before forwarding resolved spending inputs
during execution-unit estimation. The UTxO RPC backend **declines** the
capability: a non-empty additional set would be rejected, which used to make
every Plutus transaction fail evaluation. Apollo now passes `nil` additional
UTxOs to that backend and lets the evaluator resolve inputs from its own chain
view.

Each additional UTxO must pass `backend.ValidateAdditionalUtxo` (input and
output present, no typed-nil interfaces).

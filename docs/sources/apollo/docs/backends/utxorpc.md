# UTxO RPC

```go
import "github.com/Salvionied/apollo/v2/backend/utxorpc"

ctx := utxorpc.NewUtxoRpcChainContext(
    "https://your-utxorpc-endpoint",
    1,              // network ID
    map[string]string{
        // optional headers, e.g. API keys
    },
)
```

The backend prefers `utxorpc.v1beta`. v1alpha and v1beta are independent
connect services (the request path comes from the protobuf package), so the
first call falls back to v1alpha when the server reports v1beta
`UNIMPLEMENTED` and remembers the working version for the lifetime of the
context. Construction is unchanged.

## Capabilities

UTxO RPC does **not** report:

- `CapabilityGenesisParams`
- `CapabilityCurrentEpoch`
- `CapabilityEvaluateTxAdditionalUtxos`
- `CapabilityScriptCbor`

Do not pass additional UTxOs into evaluation. Apollo already omits them when
the capability is absent, so script transactions evaluate against the
provider's own chain view.

Cardano `EvalTx` errors are surfaced as `utxorpc.EvaluationError` rather than
dropped. Redeemer purpose encoding is validated against the transaction's
redeemers.

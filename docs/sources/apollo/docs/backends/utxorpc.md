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

- `CapabilityEvaluateTxAdditionalUtxos`
- `CapabilityScriptCbor`

Genesis parameters come from `ReadGenesis`. A server that implements it in
neither `utxorpc.v1beta` nor `utxorpc.v1alpha` returns an error matching
`backend.ErrUnsupported`. `ReadGenesis` tries both versions regardless of the
version negotiated for other calls, since a server may add it to only one. The
slot length must be a whole number of seconds, because
`GenesisParameters.SlotLength` holds seconds, and the active slots coefficient
must lie in (0, 1].

The current epoch comes from `ReadEraSummary`, the tip slot, and the genesis
epoch length: the start epoch of the era containing the tip plus the whole
epochs since its start slot. A server that implements `ReadEraSummary` in
neither version returns an error matching `backend.ErrUnsupported`. A summary
with no eras, overlapping eras, or no era containing the tip is rejected, as is
a tip inside a Byron era, whose epoch length differs from the genesis one.

Protocol and genesis parameters and the era summary are cached for five
minutes per context.

Do not pass additional UTxOs into evaluation. Apollo already omits them when
the capability is absent, so script transactions evaluate against the
provider's own chain view.

Cardano `EvalTx` errors are surfaced as `utxorpc.EvaluationError` rather than
dropped. Redeemer purpose encoding is validated against the transaction's
redeemers.

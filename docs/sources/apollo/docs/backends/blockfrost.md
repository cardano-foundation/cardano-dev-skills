# Blockfrost

```go
import (
    "github.com/Salvionied/apollo/v2/backend/blockfrost"
    "github.com/Salvionied/apollo/v2/constants"
)

ctx := blockfrost.NewBlockFrostChainContext(
    constants.BlockfrostBaseUrlMainnet, // or Preview / Preprod
    1,                                  // network ID: 1 mainnet, 0 testnet
    "your_blockfrost_project_id",
)
```

The base URL is used as given, so it must include the API version path, as the
`constants.BlockfrostBaseUrl*` values do. For a self-hosted or third-party
Blockfrost-compatible provider, pass its full API base URL, such as
`https://blockfrost.example.com/api/v1`. Trailing slashes are removed.

## Capabilities

Blockfrost reports `AllCapabilities`, including
`CapabilityEvaluateTxAdditionalUtxos`.

## Behaviour worth knowing

- `UtxoByRef` fills `TxHash` from `/txs/{hash}/utxos` responses so confirmation
  polling can complete.
- Script evaluation prefers `/utils/txs/evaluate` over `/evaluate/utxos`, with
  a backoff retry for indexing lag. The hosted evaluate-utxos proxy faults on
  some inline-datum and reference-script inputs.
- Protocol parameters prefer `cost_models_raw` over named cost models so
  language views match the chain after a cost-model bump.
- UTxO script hydration is parallelized (bounded concurrency).

See the [v2 changelog](https://github.com/Salvionied/apollo/blob/master/CHANGELOG.md)
for the full list of provider-response fixes.

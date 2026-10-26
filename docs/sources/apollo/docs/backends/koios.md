# Koios

```go
import (
    "github.com/Salvionied/apollo/v2/backend/koios"
    "github.com/Salvionied/apollo/v2/constants"
)

ctx := koios.NewKoiosChainContext(
    constants.KoiosBaseUrlMainnet, // or Preview / Preprod
    1,                             // network ID: 1 mainnet, 0 testnet
    "",                            // optional Koios bearer token
)
```

The base URL is used as given, so it must include the API version path, as the
`constants.KoiosBaseUrl*` values do. For a self-hosted Koios instance, pass its
full API base URL, such as `https://koios.example.com/api/v1`. Trailing slashes
are removed. Pass a Koios bearer token for a paid tier, or `""` for the public
tier; the token is sent as `Authorization: Bearer <token>`.

## Capabilities

Koios reports `AllCapabilities`, including
`CapabilityEvaluateTxAdditionalUtxos`.

## Behaviour worth knowing

- Protocol parameters come from `/epoch_params` for the tip's epoch, including
  the Conway `min_fee_ref_script_cost_per_byte`, kept as an exact rational.
  Required parameters that are null are an error, not a zero value.
  Cost models must use the flat integer-array form; a keyed form is rejected
  rather than reordered.
- Address UTxOs come from `/address_utxos` with extended output, paginated in
  stable `tx_hash`, `tx_index` order. Inline datums keep their original CBOR,
  and reference scripts are taken from the response and verified against
  their hash. No extra request is made per script. Koios reports native
  (timelock) scripts as JSON without bytes, so they are re-encoded from that
  JSON and accepted only when the hash matches.
- `UtxoByRef` uses `/utxo_info`. Like Blockfrost, it returns an output that
  exists on chain even if it has since been spent.
- `ScriptCbor` uses `/script_info` and returns the script in the gouroboros
  script-type form, verified against the requested hash.
- Script evaluation uses the Koios Ogmios proxy (`/ogmios`,
  `evaluateTransaction`). Koios returns Ogmios errors with HTTP status 400; the
  JSON-RPC error is still parsed and reported. Apollo passes every spending
  input as an additional UTxO. Ogmios accepts an entry identical to the
  ledger's but rejects one that differs from it. When Ogmios reports such an
  overlap, the overlapping entries are dropped, so the ledger's versions are
  used, and evaluation is retried once.
- Submission posts raw CBOR to `/submittx`.

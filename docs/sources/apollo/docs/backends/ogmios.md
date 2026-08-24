# Ogmios and Kupo

Apollo owns the constructor types. You do not pass `*ogmigo.Client` or
`*kugo.Client` into the public API, so the client library major version is not
frozen for the life of 2.x.

```go
import "github.com/Salvionied/apollo/v2/backend/ogmios"

ctx, err := ogmios.NewOgmiosChainContext(ogmios.Config{
    OgmiosEndpoint: "ws://localhost:1337",
    KupoEndpoint:   "http://localhost:1442",
    NetworkId:      1,
})
if err != nil {
    return err
}
```

`OgmiosEndpoint` is required. HTTP(S) URLs are accepted and dialed as `ws` /
`wss`. `KupoEndpoint` is optional: without Kupo, the context still answers
queries Ogmios serves, but it reports neither `CapabilityUtxos` nor
`CapabilityScriptCbor`. `UtxoByRef` is served by Ogmios itself.

`KupoTimeout` bounds each Kupo HTTP request; zero leaves the client default.

## Custom transports

`NewOgmiosChainContextFromClients(ogmiosClient, kupoClient, networkId)` is the
escape hatch for tests and custom transports. Both client interfaces are
Apollo's (`ogmios.OgmiosClient`, `ogmios.KupoClient`). `ogmiosClient` is
required; `kupoClient` may be nil.

## Protocol-parameter decoding

Ogmios v6.1.0 and later encode lovelace-valued parameters as
`{"ada": {"lovelace": N}}`. Apollo accepts that shape and the older
`{"lovelace": N}` shape. An unrecognized shape or missing required key is an
error — previously every lovelace field decoded as zero, which zeroed
`minFeeConstant` and underpriced every transaction by 155381 lovelace on
mainnet. Shelley genesis decoding is similarly strict (`activeSlotsCoefficient`
as a ratio string, `slotLength`, `startTime`, `maxReferenceScriptsSize`).

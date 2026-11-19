# Fixed backend and cache

## `backend/fixed`

In-memory backend with preset protocol parameters and UTxOs. Apollo's tests
and examples use it so builds are deterministic and offline.

```go
import "github.com/Salvionied/apollo/v2/backend/fixed"

ctx := fixed.NewEmptyFixedChainContext() // preprod-like defaults, network ID 0
ctx.AddUtxo(addr, utxo)

// Or supply parameters explicitly:
ctx = fixed.NewFixedChainContext(protocolParams, genesisParams, networkId)
```

`AddUtxo` also registers the UTxO for `UtxoByRef`, so it can be a reference
input.

**Capabilities:** protocol params, genesis params, max tx fee, UTxOs, UTxO by
ref. No tip, submit, evaluate, epoch, or script CBOR — it does not pretend to
be a node. Wrap it with [`backend/localeval`](localeval.md) to evaluate
scripts in tests.

## `backend/cache`

TTL wrapper around any `ChainContext`. Caches protocol and genesis parameters
and `MaxTxFee` so a multi-step `Complete()` does not re-fetch them on every
probe. Errors are not cached.

```go
import (
    "time"

    "github.com/Salvionied/apollo/v2/backend/cache"
)

cached := cache.NewCachedChainContext(inner, 5*time.Minute)
```

Capabilities are those of `inner`. Cached protocol parameters are deep-copied
on read, including cost models and reference-script prices, so callers cannot
mutate the cache.

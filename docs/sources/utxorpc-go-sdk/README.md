# UTxO RPC Go SDK

A Go client for [UTxO RPC](https://utxorpc.org) servers, with generic Query,
Submit, Sync, and Watch clients and optional Cardano helpers. The default
package targets **v1beta** and uses Connect RPC in gRPC mode over HTTP/2.

[![Go Reference](https://pkg.go.dev/badge/github.com/utxorpc/go-sdk.svg)](https://pkg.go.dev/github.com/utxorpc/go-sdk)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Installation

Requires **Go 1.26.10 or later**, as declared in [go.mod](go.mod).

```bash
go get github.com/utxorpc/go-sdk
```

| Package | Purpose |
| --- | --- |
| `github.com/utxorpc/go-sdk` (package `sdk`) | Generic v1beta client, header management, streaming, and pagination |
| `github.com/utxorpc/go-sdk/cardano` | Cardano UTxO searches, transaction helpers, and block helpers |
| `github.com/utxorpc/go-sdk/v1alpha` | Frozen legacy client for v1alpha servers |

## Quick start

Set `UTXORPC_URL` to your server's base URL. If your provider uses the
`dmtr-api-key` header, set `DMTR_API_KEY` as well; other authentication headers
can be supplied with `WithHeaders`.

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
	sdk "github.com/utxorpc/go-sdk"
)

func main() {
	baseURL := os.Getenv("UTXORPC_URL")
	if baseURL == "" {
		log.Fatal("set UTXORPC_URL to your UTxO RPC server URL")
	}
	client := sdk.NewClient(sdk.WithBaseUrl(baseURL))
	if key := os.Getenv("DMTR_API_KEY"); key != "" {
		client.SetHeader("dmtr-api-key", key)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	req := connect.NewRequest(&query.ReadParamsRequest{})
	resp, err := client.ReadParamsWithContext(ctx, req)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Ledger tip slot: %d\n", resp.Msg.GetLedgerTip().GetSlot())
}
```

Every generic RPC wrapper has two forms: `ReadParams(req)` uses
`context.Background()`, and `ReadParamsWithContext(ctx, req)` uses the caller's
context. Both inject configured headers before dispatching.

### Cardano helpers

Use the same SDK options for a Cardano client. With `baseURL` and `ctx` from
above, and `github.com/utxorpc/go-sdk/cardano` imported:

```go
client := cardano.NewClient(sdk.WithBaseUrl(baseURL))
if key := os.Getenv("DMTR_API_KEY"); key != "" {
	client.UtxorpcClient.SetHeader("dmtr-api-key", key)
}
resp, err := client.GetTipWithContext(ctx)
if err != nil {
	log.Fatal(err)
}
fmt.Printf("Tip slot: %d\n", resp.Msg.GetTip().GetSlot())
```

The generic client is available through `client.UtxorpcClient`, including its
service wrappers and header management methods.

## Client configuration

```go
client := sdk.NewClient(
	sdk.WithBaseUrl(os.Getenv("UTXORPC_URL")),
	sdk.WithDialTimeout(10*time.Second),
	sdk.WithRequestTimeout(30*time.Second),
)
```

| Option | Behavior |
| --- | --- |
| `WithBaseUrl(url)` | Server base URL; `https://` uses TLS, `http://` uses cleartext HTTP/2 (h2c) |
| `WithHeaders(headers)` | Initial headers injected by SDK wrappers |
| `WithDialTimeout(duration)` | Connection establishment timeout for the default HTTP client |
| `WithRequestTimeout(duration)` | Timeout for the entire request, including reading the response |
| `WithHttpClient(client)` | Supply a `connect.HTTPClient`; SDK dial and request timeout options then have no effect |
| `WithConnectOptions(options...)` | Apply Connect client options to all four services |

The default transport uses Go's `net/http` HTTP/2 support, requires TLS 1.2 or
later for HTTPS, and does not follow redirects. With no request timeout set,
there is no client-wide request deadline. A nonzero request timeout also
limits streaming responses; use a cancellable context and a suitable timeout
for long-running streams.

`SetURL` rebuilds all four service clients with the new URL and existing
Connect options. It reuses the HTTP client, so create a new client when
switching between HTTPS and cleartext HTTP/2.

### Headers and direct service access

```go
client.SetHeader("dmtr-api-key", os.Getenv("DMTR_API_KEY"))
client.SetHeaders(map[string]string{"Authorization": "Bearer " + token})
client.RemoveHeader("Authorization")
headers := client.Headers()
```

`SetHeaders` replaces the entire stored map. `WithHeaders` and `SetHeaders`
retain the supplied map; `Headers` returns the live map when one is set.
Configure headers and URLs before concurrent use, or synchronize mutations
with calls yourself. Use separate request objects for concurrent calls.

The exported `Query`, `Submit`, `Sync`, and `Watch` fields are generated
Connect clients. Direct calls require explicit header injection:

```go
req := connect.NewRequest(&query.ReadParamsRequest{})
client.AddHeadersToRequest(req)
resp, err := client.Query.ReadParams(ctx, req)
```

Prefer `client.ReadParamsWithContext(ctx, req)` for automatic header injection.

### Interceptors and retry

```go
client := sdk.NewClient(
	sdk.WithBaseUrl(os.Getenv("UTXORPC_URL")),
	sdk.WithConnectOptions(connect.WithInterceptors(metricsInterceptor)),
)
```

Connect options apply to all services and survive `SetURL`. They are applied
in order after the default `connect.WithGRPC()` option. Repeated
`WithConnectOptions` calls append options.

The SDK does not retry calls automatically. Limit retry interceptors to
transient failures on idempotent reads. Retrying transaction submission needs
an application-level deduplication guarantee.

## Services

These methods are available on `*sdk.UtxorpcClient`. Each has a `WithContext`
variant and takes a `*connect.Request` containing the corresponding v1beta
protobuf request from `github.com/utxorpc/go-codegen/utxorpc/v1beta/...`.

| Service | Unary methods | Streaming methods |
| --- | --- | --- |
| Query | `ReadData`, `ReadEraSummary`, `ReadGenesis`, `ReadParams`, `ReadState`, `ReadTx`, `ReadUtxos`, `SearchUtxos` | — |
| Submit | `EvalTx`, `SubmitTx`, `ReadMempool` | `WaitForTx`, `WatchMempool` |
| Sync | `DumpHistory`, `FetchBlock`, `ReadTip` | `FollowTip` |
| Watch | — | `WatchTx` |

See the [package reference](https://pkg.go.dev/github.com/utxorpc/go-sdk) for
signatures and the [UTxO RPC specification](https://utxorpc.org/spec) for
request and response semantics. Server support for individual methods may vary.

## Pagination

`SearchUtxos` and `DumpHistory` return one page. Use `SearchUtxosPages` or
`DumpHistoryPages` (and their `WithContext` variants) to iterate all pages:

```go
// import "google.golang.org/protobuf/proto"
// predicate is a *query.UtxoPredicate describing the UTxOs to match.
req := connect.NewRequest(&query.SearchUtxosRequest{
	Predicate: predicate,
	MaxItems:  proto.Int32(100),
})
for page, err := range client.SearchUtxosPagesWithContext(ctx, req) {
	if err != nil {
		log.Fatal(err)
	}
	for _, item := range page.Msg.GetItems() {
		fmt.Println(item.GetTxoRef())
	}
}
```

The helpers return lazy `iter.Seq2` sequences of responses and errors. Breaking
iteration prevents further page requests. Each helper clones the protobuf
request, copies request headers to each page, and injects stored client headers.
The original request is unchanged. An RPC error is yielded once and ends
iteration.

Iteration starts at the request's `StartToken`. UTxO searches follow string
`NextToken` values until empty; history pages follow `*sync.BlockRef` tokens
until nil. For manual pagination, save a response's `NextToken` and pass it
as the next request's `StartToken`.

## Cardano API

See the [Cardano package reference](https://pkg.go.dev/github.com/utxorpc/go-sdk/cardano)
for full signatures. Helpers return Connect responses or server streams.

| Purpose | Helpers |
| --- | --- |
| Protocol parameters | `GetProtocolParameters` |
| UTxOs by reference | `GetUtxoByRef`, `GetUtxosByRefs` |
| UTxO search | `GetUtxosByAddress`, `GetUtxosByAddressWithAsset`, `GetUtxosByAsset` |
| Paginated UTxO search | `GetUtxosByAddressPages`, `GetUtxosByAddressWithAssetPages`, `GetUtxosByAssetPages` |
| Transactions | `SubmitTransaction`, `EvaluateTransaction`, `GetMempoolTransactions` |
| Transaction streams | `WaitForTransaction`, `WatchMempoolTransactions`, `WatchTransaction` |
| Blocks | `GetTip`, `GetBlockByRef`, `ReadBlock`, `WatchBlocksByRef` |

### Input encodings

- `GetUtxoByRef` tries a transaction hash as hex first, then standard base64.
  `GetUtxosByRefs` takes `[]*query.TxoRef` with raw hash bytes.
- Address searches take raw bytes. Decode bech32 addresses first, for example
  with `common.NewAddress` from
  `github.com/blinklabs-io/gouroboros/ledger/common`, then call `Bytes()`.
- Asset policy IDs and asset names are raw bytes. Decode hex strings before
  passing them. `GetUtxosByAsset` requires at least one non-nil filter;
  address-plus-asset searches allow both filters to be empty.
- `SubmitTransaction` and `EvaluateTransaction` take signed transaction CBOR
  as hex. `WaitForTransaction` takes a hex transaction hash.
- `GetBlockByRef`, `WatchBlocksByRef`, and `WatchTransaction` take a hex block
  hash and a slot. An empty hash and slot `-1` omit the reference or intersect;
  the server determines the behavior. `WatchTransaction` watches transactions
  from a block intersect, rather than selecting a transaction by its hash.
- `ReadBlock` takes a `*sync.BlockRef` and checks that the first returned block
  is a Cardano block with a header. It returns the full `FetchBlock` response.

### Search options

Cardano search helpers return a single page of up to 100 items by default,
starting with an empty token and requesting all fields. All three search
helpers and their `Pages` variants accept these options:

| Option | Purpose |
| --- | --- |
| `cardano.WithSearchMaxItems(n)` | Set the maximum number of results per page |
| `cardano.WithSearchStartToken(token)` | Resume from a search response's `NextToken` |
| `cardano.WithSearchFieldMask(paths...)` | Select protobuf field-mask paths; no paths requests all fields |

For a Cardano `client` and decoded `addressBytes`:

```go
for page, err := range client.GetUtxosByAddressPagesWithContext(
	ctx,
	addressBytes,
	cardano.WithSearchMaxItems(50),
) {
	if err != nil {
		log.Fatal(err)
	}
	for _, item := range page.Msg.GetItems() {
		fmt.Printf("Coin: %v\n", item.GetCardano().GetCoin())
	}
}
```

### Context variants

Every helper has a `WithContext` variant, but some take a protobuf request
instead of the convenience arguments:

| Convenience call | Context call's arguments after `ctx` |
| --- | --- |
| `SubmitTransaction(txCborHex)` | `*submit.SubmitTxRequest` |
| `EvaluateTransaction(txCborHex)` | `*submit.EvalTxRequest` |
| `WaitForTransaction(txHashHex)` | `*submit.WaitForTxRequest` |
| `GetBlockByRef(blockHashHex, slot)` | `*sync.FetchBlockRequest` |
| `WatchBlocksByRef(blockHashHex, slot)` | `*sync.FollowTipRequest` |
| `WatchTransaction(blockHashHex, slot)` | `*watch.WatchTxRequest` |

These context variants take hashes and transaction CBOR already decoded to
bytes in the protobuf request. Other helpers retain their convenience
arguments after `ctx`.

## Working with streams

Streams use Connect RPC server streaming over HTTP/2. Close each stream,
process messages with `Receive` and `Msg`, and check `Err` after the loop.
For a generic SDK client, with the v1beta `sync` package imported:

```go
req := connect.NewRequest(&sync.FollowTipRequest{})
stream, err := client.FollowTipWithContext(ctx, req)
if err != nil {
	log.Fatal(err)
}
defer stream.Close()

for stream.Receive() {
	switch action := stream.Msg().GetAction().(type) {
	case *sync.FollowTipResponse_Apply:
		fmt.Println("Apply:", action.Apply)
	case *sync.FollowTipResponse_Undo:
		fmt.Println("Undo:", action.Undo)
	case *sync.FollowTipResponse_Reset_:
		fmt.Println("Reset:", action.Reset_)
	}
}
if err := stream.Err(); err != nil {
	log.Print(err)
}
```

Handle Apply, Undo, and Reset events to keep local chain state consistent.
Use a context whose lifetime covers the stream, and cancel it when finished.
The SDK does not automatically reconnect or resume a failed stream.

## Error handling

RPC methods return Go errors. Inspect underlying transport failures with
`errors.As` and RPC status information with `sdk.AsConnectError`:

```go
// import "errors" and "net"
resp, err := client.ReadParamsWithContext(ctx, req)
if err != nil {
	var transportErr net.Error
	if errors.As(err, &transportErr) {
		log.Printf("transport error: %v", transportErr)
	} else if rpcErr, ok := sdk.AsConnectError(err); ok {
		log.Printf("RPC error: code=%s message=%q", rpcErr.Code(), rpcErr.Message())
	} else {
		log.Printf("local error: %v", err)
	}
	return
}
fmt.Printf("Ledger tip slot: %d\n", resp.Msg.GetLedgerTip().GetSlot())
```

The returned `*connect.Error` also exposes `Details()` and `Meta()`.
`sdk.HandleError` is a deprecated compatibility helper that prints and panics;
handle returned errors explicitly in new code.

## Legacy v1alpha

For a v1alpha server, use matching SDK and generated protobuf imports:

```go
import (
	"github.com/utxorpc/go-codegen/utxorpc/v1alpha/query"
	sdk "github.com/utxorpc/go-sdk/v1alpha"
)
```

The legacy package retains service wrappers, header management, and
background/context method pairs for v1alpha. It is frozen for new features
and has no Cardano helper package. It does not provide v1beta additions such
as `ReadState`, `DumpHistory`, page iterators, `WithConnectOptions`, or
`AsConnectError`; inspect `*connect.Error` with `errors.As` instead.

When migrating to v1beta, update both SDK and generated protobuf import paths,
and adapt requests and response handling to the v1beta schema. The packages'
`ClientOption` types are distinct.

## Examples

Run examples from the repository root after setting `UTXORPC_URL` and, if
needed, `DMTR_API_KEY`:

```bash
go run ./examples/query
go run ./examples/submit
go run ./examples/sync
```

- [Query](examples/query/main.go): protocol parameters, era summaries, genesis,
  UTxOs by reference, address searches, and native asset filters.
- [Submit](examples/submit/main.go): reads the mempool by default. Edit the
  `mode` variable to select `submitTx`, `waitForTx`, or `watchMempool`; replace
  the transaction CBOR or hash with your own data for submission or waiting.
- [Sync](examples/sync/main.go): fetches a block, then follows chain-tip events
  including Apply, Undo, and Reset.

The examples contain sample Cardano addresses and block/transaction references.
Replace them with data for your server's network. They fall back to a Demeter
preview endpoint when `UTXORPC_URL` is unset.

## Development

```bash
make test       # go mod tidy, then go test -v -race ./...
make format     # go fmt ./... and gofmt -s -w
make build      # build example binaries in the repository root
make mod-tidy   # tidy module dependencies
make golines    # optional 80-column formatting; requires golines
golangci-lint run
```

CI runs golangci-lint with the linters and formatters in
[.golangci.yml](.golangci.yml); there is no `make lint` target.
Tests use local fixtures and test servers. Live server checks are separate;
building examples does not run them. See [AGENTS.md](AGENTS.md) for repository
conventions and contribution guidance.

## Related projects

- [UTxO RPC](https://utxorpc.org) — protocol documentation and ecosystem
- [go-codegen](https://github.com/utxorpc/go-codegen) — generated protobuf and
  Connect clients
- [gouroboros](https://github.com/blinklabs-io/gouroboros) — Cardano primitives
  used by the examples

## License

[Apache License 2.0](LICENSE).

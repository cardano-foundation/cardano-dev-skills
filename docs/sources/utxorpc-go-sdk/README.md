# UTxO RPC Go SDK

A Go client library for interacting with [UTxO RPC](https://utxorpc.org) servers. UTxO RPC is a specification for a common interface that can be used to query and submit transactions to UTxO-based blockchains.

[![Go Reference](https://pkg.go.dev/badge/github.com/utxorpc/go-sdk.svg)](https://pkg.go.dev/github.com/utxorpc/go-sdk)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Features

This SDK implements the [UTxO RPC specification](https://utxorpc.org/spec) with the following services:

- **[Query Service](https://utxorpc.org/spec/query)** - Read UTxOs, protocol parameters, chain data, and more
- **[Submit Service](https://utxorpc.org/spec/submit)** - Submit and evaluate transactions, watch mempool
- **[Sync Service](https://utxorpc.org/spec/sync)** - Fetch blocks and follow the chain tip in real-time
- **[Watch Service](https://utxorpc.org/spec/watch)** - Watch for specific transactions across blocks
- **Streaming Support** - Server-sent events for real-time blockchain updates
- **HTTP/2 Transport** - Built on Connect RPC with HTTP/2 support
- **Configurable Timeouts** - Dial and request timeouts for production use
- **Cardano Helpers** - High-level convenience methods for Cardano blockchain

## Installation

```bash
go get github.com/utxorpc/go-sdk
```

Requires Go 1.24.0 or later.

## Quick Start

For general information about UTxO RPC concepts, visit the [UTxO RPC documentation](https://utxorpc.org/docs).

### Using the Generic SDK

The top-level SDK package provides a blockchain-agnostic client that works with any UTxO RPC server:

```go
package main

import (
    "context"
    "errors"
    "fmt"
    "log"
    "net"

    "connectrpc.com/connect"
    "github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
    "github.com/utxorpc/go-sdk"
)

func main() {
    // Create a client with options
    client := sdk.NewClient(
        sdk.WithBaseUrl("https://preview.utxorpc-v0.demeter.run"),
        sdk.WithHeaders(map[string]string{
            "dmtr-api-key": "your-api-key",
        }),
    )

    // Query protocol parameters
    req := connect.NewRequest(&query.ReadParamsRequest{})
    resp, err := client.ReadParamsWithContext(context.Background(), req)
    if err != nil {
        var transportErr net.Error
        if errors.As(err, &transportErr) {
            log.Printf("transport error: %v", transportErr)
            return
        }
        if connectErr, ok := sdk.AsConnectError(err); ok {
            log.Printf(
                "RPC error: code=%s message=%q metadata=%v",
                connectErr.Code(),
                connectErr.Message(),
                connectErr.Meta(),
            )
            return
        }
        log.Printf("local error: %v", err)
        return
    }

    fmt.Printf("Ledger Tip Slot: %d\n", resp.Msg.GetLedgerTip().GetSlot())
}
```

### Using the Cardano Package

The `cardano` subpackage provides high-level helpers specifically for Cardano:

```go
package main

import (
    "fmt"
    "log"

    "github.com/utxorpc/go-sdk"
    "github.com/utxorpc/go-sdk/cardano"
)

func main() {
    // Create a Cardano-specific client
    client := cardano.NewClient(sdk.WithBaseUrl("https://preview.utxorpc-v0.demeter.run"))
    client.UtxorpcClient.SetHeader("dmtr-api-key", "your-api-key")

    // Get protocol parameters
    resp, err := client.GetProtocolParameters()
    if err != nil {
        log.Printf("get protocol parameters: %v", err)
        return
    }

    fmt.Printf("Slot: %d\n", resp.Msg.GetLedgerTip().GetSlot())

    // Get a UTxO by transaction reference
    utxo, err := client.GetUtxoByRef(
        "24efe5f12d1d93bb419cfb84338d6602dfe78c614b489edb72df0594a077431c",
        0,
    )
    if err != nil {
        log.Printf("get UTxO: %v", err)
        return
    }

    for _, item := range utxo.Msg.GetItems() {
        fmt.Printf("Coin: %d\n", item.GetCardano().GetCoin())
    }
}
```

### Using v1alpha (Legacy)

The previous `v1alpha` UTxO RPC version remains available under the `v1alpha` subpackage for users targeting servers that have not yet upgraded. Migration from earlier SDK releases is a one-line import change:

```go
import (
    sdk "github.com/utxorpc/go-sdk/v1alpha"
    "github.com/utxorpc/go-codegen/utxorpc/v1alpha/query"
)
```

The `v1alpha` subpackage exposes the same `UtxorpcClient`, options, wrapper methods, and `HandleError` utility as the top-level package — only the underlying protobuf types differ.

The `cardano` helper subpackage is `v1beta` only; there is no v1alpha cardano helper.

## Client Configuration

The SDK uses a functional options pattern for configuration:

```go
client := sdk.NewClient(
    sdk.WithBaseUrl("https://your-utxorpc-server.com"),
    sdk.WithHeaders(map[string]string{
        "Authorization": "Bearer token",
    }),
    sdk.WithDialTimeout(10 * time.Second),
    sdk.WithRequestTimeout(30 * time.Second),
)
```

### Available Options

| Option | Description |
|--------|-------------|
| `WithBaseUrl(url)` | Set the UTxO RPC server URL |
| `WithHeaders(headers)` | Set custom HTTP headers (e.g., API keys) |
| `WithDialTimeout(duration)` | Timeout for establishing connections |
| `WithRequestTimeout(duration)` | Timeout for individual requests |
| `WithHttpClient(client)` | Provide a custom HTTP client |
| `WithConnectOptions(options...)` | Apply Connect options such as interceptors to every service |

### Error Handling

RPC methods return ordinary Go errors and never require panic-based handling.
Use `errors.As` with `net.Error` to identify underlying transport failures.
Use `sdk.AsConnectError` to inspect a Connect/gRPC status code, message,
details, and response metadata. Errors that match neither category are local
failures such as invalid input or decoding errors.

`sdk.HandleError` remains available for compatibility but is deprecated
because it panics. Migrate by returning or logging the error and inspecting it
as shown in the quick-start example.

### Interceptors and Retry

Connect client options can be passed without replacing the SDK's HTTP client:

```go
client := sdk.NewClient(
    sdk.WithBaseUrl("https://your-utxorpc-server.com"),
    sdk.WithConnectOptions(
        connect.WithInterceptors(metricsInterceptor),
    ),
)
```

The options apply to Query, Submit, Sync, and Watch clients, including clients
rebuilt by `SetURL`. The SDK does not retry calls by default. A retry
interceptor should be limited to transient status codes and idempotent reads;
do not retry `SubmitTx` or other non-idempotent operations unless the
application provides its own deduplication guarantee.

### Dynamic Header Management

```go
// Set a single header
client.SetHeader("dmtr-api-key", "your-key")

// Set multiple headers
client.SetHeaders(map[string]string{
    "dmtr-api-key": "your-key",
    "X-Custom":     "value",
})

// Remove a header
client.RemoveHeader("X-Custom")

// Get current headers
headers := client.Headers()
```

## Services

For detailed information about each service, see the [UTxO RPC specification](https://utxorpc.org/spec).

### Query Service

Read blockchain data without modifying state:

```go
// Read UTxOs by reference
client.Query.ReadUtxos(ctx, req)

// Search UTxOs with patterns
client.Query.SearchUtxos(ctx, req)

// Read protocol parameters
client.Query.ReadParams(ctx, req)

// Read chain data
client.Query.ReadData(ctx, req)

// Read selected chain state
client.Query.ReadState(ctx, req)
```

### Submit Service

Submit and manage transactions:

```go
// Submit a transaction
client.Submit.SubmitTx(ctx, req)

// Evaluate a transaction (dry run)
client.Submit.EvalTx(ctx, req)

// Read current mempool
client.Submit.ReadMempool(ctx, req)

// Stream: Wait for transaction confirmation
stream, _ := client.Submit.WaitForTx(ctx, req)

// Stream: Watch mempool changes
stream, _ := client.Submit.WatchMempool(ctx, req)
```

### Sync Service

Synchronize with the blockchain:

```go
// Fetch a specific block
client.Sync.FetchBlock(ctx, req)

// Read historical blocks
client.Sync.DumpHistory(ctx, req)

// Read current chain tip
client.Sync.ReadTip(ctx, req)

// Stream: Follow the chain tip
stream, _ := client.Sync.FollowTip(ctx, req)
```

### Watch Service

Watch for transactions:

```go
// Stream: Watch for specific transactions
stream, _ := client.Watch.WatchTx(ctx, req)
```

## Cardano Package API

The `cardano` package wraps the generic SDK with Cardano-specific convenience methods:

### Query Methods

```go
// Protocol parameters
client.GetProtocolParameters()

// UTxO queries
client.GetUtxoByRef(txHash, index)
client.GetUtxosByRefs(refs)
client.GetUtxosByAddress(address)
client.GetUtxosByAddressWithAsset(address, policyId, assetName)
client.GetUtxosByAsset(policyId, assetName)
```

### Transaction Methods

```go
// Submit a signed transaction (hex-encoded CBOR)
client.SubmitTransaction(txCbor)

// Evaluate a transaction
client.EvaluateTransaction(txCbor)

// Read mempool
client.GetMempoolTransactions()

// Stream: Wait for confirmation
stream, _ := client.WaitForTransaction(txRef)

// Stream: Watch mempool
stream, _ := client.WatchMempoolTransactions()
```

### Sync Methods

```go
// Get current tip
client.GetTip()

// Fetch block by reference
client.GetBlockByRef(hash, slot)

// Read and validate a block
client.ReadBlock(blockRef)

// Stream: Follow blocks from a point
stream, _ := client.WatchBlocksByRef(hash, slot)

// Stream: Watch transactions
stream, _ := client.WatchTransaction(hash, slot)
```

All methods have `WithContext` variants for timeout and cancellation control.

## Examples

The `examples/` directory contains complete, runnable examples:

### Query Example

```bash
export UTXORPC_URL="https://preview.utxorpc-v0.demeter.run"
export DMTR_API_KEY="your-api-key"
go run examples/query/main.go
```

Demonstrates:
- Getting protocol parameters
- Reading UTxOs by transaction reference
- Searching UTxOs by address
- Filtering UTxOs by native assets

### Submit Example

```bash
go run examples/submit/main.go
```

Demonstrates:
- Submitting transactions
- Reading mempool state
- Waiting for transaction confirmation
- Watching mempool for changes

### Sync Example

```bash
go run examples/sync/main.go
```

Demonstrates:
- Fetching blocks by hash and slot
- Following the chain tip with streaming
- Handling Apply/Undo/Reset actions

## Working with Streams

For real-time updates, the SDK provides streaming methods:

```go
// Start following the chain tip
stream, err := client.WatchBlocksByRef(blockHash, slot)
if err != nil {
    log.Fatal(err)
}
defer stream.Close()

// Process incoming blocks
for stream.Receive() {
    resp := stream.Msg()
    action := resp.GetAction()

    switch a := action.(type) {
    case *sync.FollowTipResponse_Apply:
        fmt.Println("New block applied")
        // Handle new block
    case *sync.FollowTipResponse_Undo:
        fmt.Println("Block rolled back")
        // Handle rollback
    case *sync.FollowTipResponse_Reset_:
        fmt.Println("Chain reset")
        // Handle reset
    }
}

if err := stream.Err(); err != nil {
    log.Fatal("Stream error:", err)
}
```

## Error Handling

The SDK provides utilities for handling Connect RPC errors:

```go
resp, err := client.SubmitTransaction(txCbor)
if err != nil {
    var connectErr *connect.Error
    if errors.As(err, &connectErr) {
        fmt.Printf("Error Code: %v\n", connectErr.Code())
        fmt.Printf("Message: %s\n", connectErr.Message())
        fmt.Printf("Details: %v\n", connectErr.Details())
    }
}
```

## Development

```bash
# Run tests
make test

# Format code
make format

# Build examples
make build

# Tidy dependencies
make mod-tidy
```

## Related Projects

**UTxO RPC Ecosystem:**
- [utxorpc.org](https://utxorpc.org) - Official UTxO RPC website and documentation
- [UTxO RPC Specification](https://utxorpc.org/spec) - The protocol specification
- [SDKs in Other Languages](https://utxorpc.org/sdks) - Client libraries for Python, Rust, and more
- [go-codegen](https://github.com/utxorpc/go-codegen) - Generated protobuf types for Go

**Cardano Libraries:**
- [gouroboros](https://github.com/blinklabs-io/gouroboros) - Cardano library for address handling and CBOR

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

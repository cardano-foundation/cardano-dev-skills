# ADR-018: gRPC Server for Cardano Node (cardano-rpc)

# Status

📜 Proposed 2026-03-11

# Context

Cardano node exposes its API via the Node-to-Client mini-protocol over a Unix socket.
This requires clients to implement the Ouroboros protocol, which is a significant barrier for third-party tools, wallets, and indexers that just need to query chain state or submit transactions.

The [UTxO RPC](https://utxorpc.org/) specification defines a blockchain-agnostic gRPC API standard for UTxO-based blockchains.
Implementing this standard would let Cardano benefit from cross-chain tooling and give clients a well-documented, strongly-typed interface with automatic code generation in many languages.

# Decision

We will add a `cardano-rpc` package to `cardano-api` that provides a gRPC server exposing Cardano node functionality.
The server implements the **UTxO RPC** standard plus custom Cardano-specific extensions.

## Transport

The server communicates over a **Unix domain socket** (IPC), keeping the same security model as the existing node socket — local access only, no network exposure by default.
The default socket path is `rpc.sock` in the same directory as the node socket; it can be overridden via `--grpc-socket-path` or the `RpcSocketPath` config key.

Operators who need remote access can use [Envoy](https://www.envoyproxy.io/) as a reverse proxy in front of the Unix socket.
Envoy terminates TLS, enforces access control (e.g., rate limiting, IP allowlists, mTLS client authentication), and translates between HTTP (including gRPC-Web for browser clients) and the upstream gRPC-over-Unix-socket connection.
Working Envoy configurations are available in the [examples directory](https://github.com/IntersectMBO/cardano-api/tree/master/cardano-wasm/examples/grpc/).

## Integration with cardano-node

The feature is **opt-in and experimental**.
It is enabled via the `--grpc-enable` CLI flag or `EnableRpc` config key.

The RPC server runs concurrently in the node process.
It connects to the node via the standard Node-to-Client IPC connection to execute local state queries and submit transactions.

Although the RPC server runs in the same process as the node, it currently communicates through the Node-to-Client IPC socket — the same external interface any separate client would use.
This has several limitations:

- **Serialization overhead** — every query round-trips through CBOR encoding and decoding even though both sides share the same process.
- **Connection-per-request cost** — each gRPC call opens a new IPC connection, paying the Ouroboros handshake cost every time.
- **Mini-protocol bottleneck** — the local state query mini-protocol is [sequential within a connection](https://ouroboros-network.cardano.intersectmbo.org/pdfs/network-spec/network-spec.pdf), limiting concurrency. The gRPC API can only expose what the Node-to-Client protocol supports.

Future iterations should move toward **direct ledger state access** — reading the node's in-memory state (e.g., via shared `TVar`/`STM` references) instead of going through IPC.
This would eliminate serialization overhead and connection management entirely.
As a nearer-term improvement, **connection pooling** over persistent IPC connections would amortize handshake costs without requiring changes to the node's internals.

## Observability

All RPC operations are traced through the node's standard tracing infrastructure.
Trace events cover query and submit operations with timing and error reporting.

## Dependencies

The package introduces new dependencies:
- **grapesy** — gRPC server and client framework
- **grpc-spec** — gRPC protocol specification
- **proto-lens** — Protocol Buffer lens-based encoding/decoding

# Alternatives Considered

**JSON-RPC over HTTP** was considered as a simpler alternative.
However, it lacks streaming support, strong typing, and automatic code generation across languages that gRPC provides out of the box.

**REST API** was considered but is less suitable for the request/response patterns needed by blockchain clients.
There is also no established blockchain-agnostic REST specification comparable to UTxO RPC.


# Consequences

- Third-party tools, wallets, and indexers get a standard gRPC interface to the node, with auto-generated client libraries in many languages.
- UTxO RPC compatibility enables cross-chain tooling that targets multiple UTxO blockchains.
- The Unix socket transport preserves the existing security model — no network exposure by default.
- The node gains gRPC/protobuf build dependencies (`grapesy`, `grpc-spec`, `proto-lens`).
- The feature is opt-in and experimental, so it does not affect existing node deployments.

# References

- [UTxO RPC specification](https://utxorpc.org/)
- [Proto definitions](https://github.com/IntersectMBO/cardano-api/tree/master/cardano-rpc/proto/)
- [Server implementation](https://github.com/IntersectMBO/cardano-api/blob/master/cardano-rpc/src/Cardano/Rpc/Server.hs)
- [Node integration](https://github.com/IntersectMBO/cardano-node/blob/master/cardano-node/src/Cardano/Node/Run.hs)
- [Envoy gRPC-Web example](https://github.com/IntersectMBO/cardano-api/tree/master/cardano-wasm/examples/grpc/)

# Related ADRs

- [ADR-015](ADR-015-Cardano-API-WASM-library-for-browser) — the WASM library provides browser-side access to `cardano-api`; the gRPC server with Envoy/gRPC-Web enables browser clients to query the node.

# Authors

- Mateusz Gałażyn (initial version)

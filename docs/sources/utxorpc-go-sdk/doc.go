// Package sdk is the Go client SDK for the UTxO RPC specification (v1beta).
//
// UTxO RPC is a common RPC interface for querying and submitting transactions
// to UTxO-based blockchains. This package wraps the generated Connect RPC
// clients in [github.com/utxorpc/go-codegen] with a single configurable
// [UtxorpcClient], header management, and method pairs that accept either a
// background context or a caller-supplied [context.Context].
//
// Spec: https://utxorpc.org/spec
//
// # Module layout
//
//	sdk           This package. Generic v1beta client; works with any UTxO RPC server.
//	sdk/cardano   High-level Cardano helpers (v1beta only) built on top of UtxorpcClient.
//	sdk/v1alpha   Legacy v1alpha mirror of this package. Use this package for new code.
//
// # Quick start
//
//	client := sdk.NewClient(
//	    sdk.WithBaseUrl("https://preview.utxorpc-v0.demeter.run"),
//	    sdk.WithHeaders(map[string]string{"dmtr-api-key": "..."}),
//	)
//
//	req := connect.NewRequest(&query.ReadParamsRequest{})
//	resp, err := client.ReadParams(req) // headers are auto-injected
//
// # Transport
//
// The default HTTP client uses HTTP/2 via [golang.org/x/net/http2] and Connect
// RPC's gRPC mode. TLS is enabled automatically unless [WithBaseUrl] starts
// with "http://". A custom client can be supplied via [WithHttpClient]; in
// that case [WithDialTimeout] and [WithRequestTimeout] are ignored.
//
// # API surface
//
// Construction:
//
//	NewClient(opts ...ClientOption) *UtxorpcClient
//
// Options (all return [ClientOption]):
//
//	WithBaseUrl(url)             — server URL; "http://" prefix disables TLS
//	WithHeaders(map)             — initial headers (e.g., API keys)
//	WithDialTimeout(d)           — connect timeout (default client only)
//	WithRequestTimeout(d)        — per-request timeout (default client only)
//	WithHttpClient(c)            — replace the entire HTTP client
//	WithConnectOptions(opts...)  — options/interceptors for all service clients
//
// Client lifecycle:
//
//	(*UtxorpcClient).URL() / SetURL(url)        — get/set base URL; SetURL rebuilds service clients
//	(*UtxorpcClient).HTTPClient()               — underlying connect.HTTPClient
//	(*UtxorpcClient).Headers() / SetHeaders(m)
//	(*UtxorpcClient).SetHeader(k, v) / RemoveHeader(k)
//	(*UtxorpcClient).AddHeadersToRequest(req)   — applies stored headers to a connect request
//
// Service clients (also exposed as Query / Submit / Sync / Watch fields):
//
//	NewQueryServiceClient(), NewSubmitServiceClient(),
//	NewSyncServiceClient(),  NewWatchServiceClient()
//
// Query (read blockchain state, all WithContext variants available):
//
//	ReadData, ReadEraSummary, ReadGenesis, ReadParams,
//	ReadState, ReadTx, ReadUtxos, SearchUtxos
//	SearchUtxosPages                                  — lazy automatic pagination
//
// Submit (transaction lifecycle):
//
//	EvalTx, SubmitTx, ReadMempool                      — unary
//	WaitForTx, WatchMempool                            — server-streaming
//
// Sync (chain follower):
//
//	DumpHistory, FetchBlock, ReadTip                   — unary
//	DumpHistoryPages                                  — lazy automatic pagination
//	FollowTip                                          — server-streaming
//
// Watch (cross-block transaction watcher):
//
//	WatchTx                                            — server-streaming
//
// Errors:
//
//	AsConnectError(err) — exposes a Connect code/message/details/metadata.
//	HandleError(err)    — deprecated panic-based compatibility helper.
//
// # Method-pair convention
//
// Every RPC method is exposed twice on [*UtxorpcClient]:
//
//	Foo(req)              — uses context.Background()
//	FooWithContext(ctx, req)
//
// Both inject the client's stored headers via [(*UtxorpcClient).AddHeadersToRequest]
// before delegating to the underlying Connect client. Use the WithContext
// form whenever you need cancellation, deadlines, or request-scoped values.
//
// # Streaming
//
// Streaming methods return *[connect.ServerStreamForClient]:
//
//	stream, err := client.FollowTip(req)
//	if err != nil { ... }
//	defer stream.Close()
//	for stream.Receive() {
//	    msg := stream.Msg()
//	    // handle msg
//	}
//	if err := stream.Err(); err != nil { ... }
//
// Streams MUST be closed; iterate with Receive() until it returns false, then
// check Err(). FollowTip and WatchTx deliver Apply / Undo / Reset actions —
// callers should handle all three to maintain a consistent view of chain state.
//
// # See also
//
//   - [github.com/utxorpc/go-sdk/cardano] — Cardano convenience methods
//     (hex/base64 decoding, address-based UTxO search, single-tx submit/wait).
//   - [github.com/utxorpc/go-sdk/v1alpha] — legacy v1alpha mirror of this
//     package for servers that have not upgraded to v1beta.
package sdk

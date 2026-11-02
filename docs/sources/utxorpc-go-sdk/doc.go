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
//	sdk/v1alpha   Frozen legacy v1alpha client. Prefer the root sdk package for new code.
//
// # Quick start
//
//	client := sdk.NewClient(
//	    sdk.WithBaseUrl(os.Getenv("UTXORPC_URL")),
//	)
//	if key := os.Getenv("DMTR_API_KEY"); key != "" {
//	    client.SetHeader("dmtr-api-key", key)
//	}
//
//	req := connect.NewRequest(&query.ReadParamsRequest{})
//	resp, err := client.ReadParamsWithContext(ctx, req) // headers are auto-injected
//	if err != nil {
//	    return err
//	}
//	fmt.Println(resp.Msg.GetLedgerTip().GetSlot())
//
// Set UTXORPC_URL to your server's base URL. The snippet assumes a caller's
// context ctx and the v1beta query types from go-codegen.
//
// # Transport
//
// The default HTTP client uses [net/http]'s HTTP/2 support and Connect RPC's
// gRPC mode. Use an https:// base URL for TLS (minimum TLS 1.2), or http://
// for cleartext HTTP/2 (h2c). Redirects are not followed. A custom client can
// be supplied via [WithHttpClient]; in that case [WithDialTimeout] and
// [WithRequestTimeout] are ignored.
//
// There is no client-wide request deadline unless [WithRequestTimeout] is
// set. This timeout covers reading the response, including a stream's entire
// lifetime. Use caller contexts for cancellation and appropriate deadlines.
// [UtxorpcClient.SetURL] reuses the existing HTTP client; create a new client
// when switching between TLS and cleartext transport.
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
//	WithRequestTimeout(d)        — entire request/stream timeout (default client only)
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
// Calls through the Query, Submit, Sync, and Watch fields, or clients returned
// by the service constructors, require explicit AddHeadersToRequest calls.
// Configure headers and URLs before concurrent use, or synchronize mutations
// with calls. Header maps are shared with the caller, and Headers returns the
// live map when set. Use a separate request object for each concurrent call.
//
// # Pagination
//
// [UtxorpcClient.SearchUtxosPagesWithContext] and
// [UtxorpcClient.DumpHistoryPagesWithContext] return lazy [iter.Seq2]
// sequences of responses and errors. They clone the protobuf request, copy
// request headers, and inject stored client headers for every page. Iteration
// begins at the request's start token and follows response tokens until empty
// (SearchUtxos) or nil (DumpHistory). Breaking the loop avoids later page
// requests. An RPC error is yielded once and ends iteration. The original
// request is unchanged. Background-context variants are also available.
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
// Streams use RPC server streaming over HTTP/2. The SDK does not automatically
// reconnect or resume them, and does not retry RPC calls by default.
//
// # See also
//
//   - [github.com/utxorpc/go-sdk/cardano] — Cardano convenience methods
//     (hex/base64 decoding, address-based UTxO search, single-tx submit/wait).
//   - [github.com/utxorpc/go-sdk/v1alpha] — frozen legacy client for servers
//     that have not upgraded to v1beta; its API lacks newer v1beta helpers.
package sdk

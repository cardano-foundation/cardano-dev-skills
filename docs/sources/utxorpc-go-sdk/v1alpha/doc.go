// Package v1alpha is the legacy UTxO RPC client targeting the v1alpha
// protobuf schema. It retains service wrappers, header management, and
// background/context method pairs using request and response types from
// utxorpc/v1alpha. This package is frozen for new features; its API differs
// from the current [github.com/utxorpc/go-sdk] v1beta package.
//
// ReadState, DumpHistory, page iterators, WithConnectOptions, and AsConnectError
// are available only in the parent package. ClientOption types from the two
// packages are distinct and cannot be interchanged.
//
// # Use the parent package for new code
//
// Prefer [github.com/utxorpc/go-sdk] for new development. This package exists
// so callers pinned to servers that have not yet upgraded to v1beta can
// continue to compile and run. Once the server speaks v1beta, update both SDK
// and generated protobuf imports, then adapt requests and response handling
// to the v1beta schema:
//
//	import (
//	    sdk "github.com/utxorpc/go-sdk"
//	    "github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
//	)
//
// There is no v1alpha equivalent of the [github.com/utxorpc/go-sdk/cardano]
// helper package; the Cardano helpers are v1beta only.
//
// # Quick start
//
//	client := v1alpha.NewClient(
//	    v1alpha.WithBaseUrl(os.Getenv("UTXORPC_URL")),
//	)
//	if key := os.Getenv("DMTR_API_KEY"); key != "" {
//	    client.SetHeader("dmtr-api-key", key)
//	}
//
//	req := connect.NewRequest(&query.ReadParamsRequest{}) // utxorpc/v1alpha/query
//	resp, err := client.ReadParamsWithContext(ctx, req)
//	if err != nil {
//	    return err
//	}
//	fmt.Println(resp.Msg.GetLedgerTip().GetSlot())
//
// Set UTXORPC_URL to a v1alpha server's base URL. The snippet assumes a
// caller's context ctx and matching v1alpha query types from go-codegen.
//
// # API surface
//
// Construction:
//
//	NewClient(opts ...ClientOption) *UtxorpcClient
//
// Options:
//
//	WithBaseUrl, WithHeaders, WithDialTimeout, WithRequestTimeout, WithHttpClient
//
// Client lifecycle:
//
//	URL, SetURL, HTTPClient, Headers, SetHeaders, SetHeader, RemoveHeader,
//	AddHeadersToRequest
//
// Service clients (also exposed as Query / Submit / Sync / Watch fields):
//
//	NewQueryServiceClient, NewSubmitServiceClient,
//	NewSyncServiceClient,  NewWatchServiceClient
//
// RPC methods (each has a WithContext variant; streaming methods marked):
//
//	Query:  ReadData, ReadEraSummary, ReadGenesis, ReadParams,
//	        ReadTx, ReadUtxos, SearchUtxos
//	Submit: EvalTx, SubmitTx, ReadMempool,
//	        WaitForTx (stream), WatchMempool (stream)
//	Sync:   FetchBlock, ReadTip, FollowTip (stream)
//	Watch:  WatchTx (stream)
//
// Errors:
//
//	HandleError(err) — prints the Connect code/message/details and panics.
//
// Prefer inspecting returned errors with [errors.As] and [*connect.Error]
// instead of calling HandleError. Direct calls through the service fields
// require explicit [UtxorpcClient.AddHeadersToRequest] calls.
//
// See the [github.com/utxorpc/go-sdk] package documentation for the
// method-pair convention, transport configuration, and streaming patterns.
package v1alpha

// Package v1alpha is the legacy UTxO RPC client targeting the v1alpha
// protobuf schema. It mirrors the API of the parent [github.com/utxorpc/go-sdk]
// package one-for-one — same [UtxorpcClient], options, method pairs, and
// [HandleError] utility — only the underlying request/response types come
// from utxorpc/v1alpha rather than utxorpc/v1beta.
//
// # Use the parent package for new code
//
// Prefer [github.com/utxorpc/go-sdk] for new development. This package exists
// so callers pinned to servers that have not yet upgraded to v1beta can
// continue to compile and run. Migration is a one-line import change once
// the server speaks v1beta:
//
//	import (
//	    sdk "github.com/utxorpc/go-sdk"           // new (v1beta)
//	    // sdk "github.com/utxorpc/go-sdk/v1alpha" // old
//	    "github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
//	)
//
// There is no v1alpha equivalent of the [github.com/utxorpc/go-sdk/cardano]
// helper package; the Cardano helpers are v1beta only.
//
// # Quick start
//
//	client := v1alpha.NewClient(
//	    v1alpha.WithBaseUrl("https://your-v1alpha-server.example"),
//	    v1alpha.WithHeaders(map[string]string{"dmtr-api-key": "..."}),
//	)
//
//	req := connect.NewRequest(&query.ReadParamsRequest{}) // utxorpc/v1alpha/query
//	resp, err := client.ReadParams(req)
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
// See the [github.com/utxorpc/go-sdk] package documentation for the
// method-pair convention, transport details, and streaming patterns; they
// apply identically here.
package v1alpha

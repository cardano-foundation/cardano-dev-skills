package sdk

import (
	"context"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/watch"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/watch/watchconnect"
)

// WatchServiceClient is the generated Connect client for the UTxO RPC Watch
// service. Re-exported so callers can hold a typed reference without
// importing watchconnect directly.
type WatchServiceClient = watchconnect.WatchServiceClient

// NewWatchServiceClient is the free-function form of
// [(*UtxorpcClient).NewWatchServiceClient].
func NewWatchServiceClient(u *UtxorpcClient) WatchServiceClient {
	return u.NewWatchServiceClient()
}

// NewWatchServiceClient returns a fresh [WatchServiceClient] bound to this
// client's HTTP client and base URL.
func (u *UtxorpcClient) NewWatchServiceClient() WatchServiceClient {
	return watchconnect.NewWatchServiceClient(
		u.httpClient,
		u.baseUrl,
		u.clientOptions()...,
	)
}

// WatchTx calls [(*UtxorpcClient).WatchTxWithContext] with a background context.
func (u *UtxorpcClient) WatchTx(
	req *connect.Request[watch.WatchTxRequest],
) (*connect.ServerStreamForClient[watch.WatchTxResponse], error) {
	ctx := context.Background()
	return u.WatchTxWithContext(ctx, req)
}

// WatchTxWithContext opens a server stream of transaction events matching
// the request's predicate, starting from the given intersect point. Like
// FollowTip, the stream emits Apply / Undo / Reset actions; the caller must
// close the stream when done.
func (u *UtxorpcClient) WatchTxWithContext(
	ctx context.Context,
	req *connect.Request[watch.WatchTxRequest],
) (*connect.ServerStreamForClient[watch.WatchTxResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Watch.WatchTx(ctx, req)
}

package v1alpha

import (
	"context"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1alpha/watch"
	"github.com/utxorpc/go-codegen/utxorpc/v1alpha/watch/watchconnect"
)

// WatchServiceClient is the generated Connect client for the v1alpha Watch
// service.
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
		connect.WithGRPC(),
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
// the request's predicate, starting from the given intersect point. The
// caller must close the returned stream.
func (u *UtxorpcClient) WatchTxWithContext(
	ctx context.Context,
	req *connect.Request[watch.WatchTxRequest],
) (*connect.ServerStreamForClient[watch.WatchTxResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Watch.WatchTx(ctx, req)
}

package v1alpha

import (
	"context"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1alpha/submit"
	"github.com/utxorpc/go-codegen/utxorpc/v1alpha/submit/submitconnect"
)

// SubmitServiceClient is the generated Connect client for the v1alpha
// Submit service.
type SubmitServiceClient = submitconnect.SubmitServiceClient

// NewSubmitServiceClient returns a fresh [SubmitServiceClient] bound to this
// client's HTTP client and base URL.
func (u *UtxorpcClient) NewSubmitServiceClient() SubmitServiceClient {
	return submitconnect.NewSubmitServiceClient(
		u.httpClient,
		u.baseUrl,
		connect.WithGRPC(),
	)
}

// EvalTx calls [(*UtxorpcClient).EvalTxWithContext] with a background context.
func (u *UtxorpcClient) EvalTx(
	req *connect.Request[submit.EvalTxRequest],
) (*connect.Response[submit.EvalTxResponse], error) {
	ctx := context.Background()
	return u.EvalTxWithContext(ctx, req)
}

// EvalTxWithContext invokes Submit.EvalTx after injecting stored headers
// into the request. Performs a dry run; the transaction is not broadcast.
func (u *UtxorpcClient) EvalTxWithContext(
	ctx context.Context,
	req *connect.Request[submit.EvalTxRequest],
) (*connect.Response[submit.EvalTxResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Submit.EvalTx(ctx, req)
}

// ReadMempool calls [(*UtxorpcClient).ReadMempoolWithContext] with a background context.
func (u *UtxorpcClient) ReadMempool(
	req *connect.Request[submit.ReadMempoolRequest],
) (*connect.Response[submit.ReadMempoolResponse], error) {
	ctx := context.Background()
	return u.ReadMempoolWithContext(ctx, req)
}

// ReadMempoolWithContext invokes Submit.ReadMempool after injecting stored
// headers into the request.
func (u *UtxorpcClient) ReadMempoolWithContext(
	ctx context.Context,
	req *connect.Request[submit.ReadMempoolRequest],
) (*connect.Response[submit.ReadMempoolResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Submit.ReadMempool(ctx, req)
}

// SubmitTx calls [(*UtxorpcClient).SubmitTxWithContext] with a background context.
func (u *UtxorpcClient) SubmitTx(
	req *connect.Request[submit.SubmitTxRequest],
) (*connect.Response[submit.SubmitTxResponse], error) {
	ctx := context.Background()
	return u.SubmitTxWithContext(ctx, req)
}

// SubmitTxWithContext invokes Submit.SubmitTx after injecting stored headers
// into the request. Broadcasts a signed transaction.
func (u *UtxorpcClient) SubmitTxWithContext(
	ctx context.Context,
	req *connect.Request[submit.SubmitTxRequest],
) (*connect.Response[submit.SubmitTxResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Submit.SubmitTx(ctx, req)
}

// WaitForTx calls [(*UtxorpcClient).WaitForTxWithContext] with a background context.
func (u *UtxorpcClient) WaitForTx(
	req *connect.Request[submit.WaitForTxRequest],
) (*connect.ServerStreamForClient[submit.WaitForTxResponse], error) {
	ctx := context.Background()
	return u.WaitForTxWithContext(ctx, req)
}

// WaitForTxWithContext opens a server stream that emits stage transitions
// for one or more transaction references. The caller must close the
// returned stream.
func (u *UtxorpcClient) WaitForTxWithContext(
	ctx context.Context,
	req *connect.Request[submit.WaitForTxRequest],
) (*connect.ServerStreamForClient[submit.WaitForTxResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Submit.WaitForTx(ctx, req)
}

// WatchMempool calls [(*UtxorpcClient).WatchMempoolWithContext] with a background context.
func (u *UtxorpcClient) WatchMempool(
	req *connect.Request[submit.WatchMempoolRequest],
) (*connect.ServerStreamForClient[submit.WatchMempoolResponse], error) {
	ctx := context.Background()
	return u.WatchMempoolWithContext(ctx, req)
}

// WatchMempoolWithContext opens a server stream of mempool Apply / Undo
// events. The caller must close the returned stream.
func (u *UtxorpcClient) WatchMempoolWithContext(
	ctx context.Context,
	req *connect.Request[submit.WatchMempoolRequest],
) (*connect.ServerStreamForClient[submit.WatchMempoolResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Submit.WatchMempool(ctx, req)
}

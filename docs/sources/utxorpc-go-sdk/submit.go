package sdk

import (
	"context"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/submit"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/submit/submitconnect"
)

// SubmitServiceClient is the generated Connect client for the UTxO RPC
// Submit service. Re-exported so callers can hold a typed reference without
// importing submitconnect directly.
type SubmitServiceClient = submitconnect.SubmitServiceClient

// NewSubmitServiceClient returns a fresh [SubmitServiceClient] bound to this
// client's HTTP client and base URL. The result is independent of
// [UtxorpcClient.Submit] and is rebuilt every call.
func (u *UtxorpcClient) NewSubmitServiceClient() SubmitServiceClient {
	return submitconnect.NewSubmitServiceClient(
		u.httpClient,
		u.baseUrl,
		u.clientOptions()...,
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
// into the request. EvalTx is a dry run: it computes execution units and
// validation outcome without broadcasting the transaction.
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
// headers into the request. Returns a snapshot of pending transactions.
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
// into the request. Broadcasts a signed transaction; the response carries
// the resulting transaction reference.
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
// (e.g. mempool → confirmed) for one or more transaction references. The
// caller must close the returned stream; see the package docs for the
// standard streaming pattern.
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

// WatchMempoolWithContext opens a server stream that emits Apply / Undo
// events as transactions enter or leave the mempool. The caller must close
// the returned stream.
func (u *UtxorpcClient) WatchMempoolWithContext(
	ctx context.Context,
	req *connect.Request[submit.WatchMempoolRequest],
) (*connect.ServerStreamForClient[submit.WatchMempoolResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Submit.WatchMempool(ctx, req)
}

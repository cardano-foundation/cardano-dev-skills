package v1alpha

import (
	"context"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1alpha/query"
	"github.com/utxorpc/go-codegen/utxorpc/v1alpha/query/queryconnect"
)

// QueryServiceClient is the generated Connect client for the v1alpha Query
// service.
type QueryServiceClient = queryconnect.QueryServiceClient

// NewQueryServiceClient is the free-function form of
// [(*UtxorpcClient).NewQueryServiceClient].
func NewQueryServiceClient(u *UtxorpcClient) QueryServiceClient {
	return u.NewQueryServiceClient()
}

// NewQueryServiceClient returns a fresh [QueryServiceClient] bound to this
// client's HTTP client and base URL.
func (u *UtxorpcClient) NewQueryServiceClient() QueryServiceClient {
	return queryconnect.NewQueryServiceClient(
		u.httpClient,
		u.baseUrl,
		connect.WithGRPC(),
	)
}

// QueryService returns the [QueryServiceClient] held in [UtxorpcClient.Query].
func (u *UtxorpcClient) QueryService() QueryServiceClient {
	return u.Query
}

// ReadData calls [(*UtxorpcClient).ReadDataWithContext] with a background context.
func (u *UtxorpcClient) ReadData(
	req *connect.Request[query.ReadDataRequest],
) (*connect.Response[query.ReadDataResponse], error) {
	ctx := context.Background()
	return u.ReadDataWithContext(ctx, req)
}

// ReadDataWithContext invokes Query.ReadData after injecting stored headers
// into the request.
func (u *UtxorpcClient) ReadDataWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadDataRequest],
) (*connect.Response[query.ReadDataResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadData(ctx, req)
}

// ReadEraSummary calls [(*UtxorpcClient).ReadEraSummaryWithContext] with a background context.
func (u *UtxorpcClient) ReadEraSummary(
	req *connect.Request[query.ReadEraSummaryRequest],
) (*connect.Response[query.ReadEraSummaryResponse], error) {
	ctx := context.Background()
	return u.ReadEraSummaryWithContext(ctx, req)
}

// ReadEraSummaryWithContext invokes Query.ReadEraSummary after injecting
// stored headers into the request.
func (u *UtxorpcClient) ReadEraSummaryWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadEraSummaryRequest],
) (*connect.Response[query.ReadEraSummaryResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadEraSummary(ctx, req)
}

// ReadGenesis calls [(*UtxorpcClient).ReadGenesisWithContext] with a background context.
func (u *UtxorpcClient) ReadGenesis(
	req *connect.Request[query.ReadGenesisRequest],
) (*connect.Response[query.ReadGenesisResponse], error) {
	ctx := context.Background()
	return u.ReadGenesisWithContext(ctx, req)
}

// ReadGenesisWithContext invokes Query.ReadGenesis after injecting stored
// headers into the request.
func (u *UtxorpcClient) ReadGenesisWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadGenesisRequest],
) (*connect.Response[query.ReadGenesisResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadGenesis(ctx, req)
}

// ReadParams calls [(*UtxorpcClient).ReadParamsWithContext] with a background context.
func (u *UtxorpcClient) ReadParams(
	req *connect.Request[query.ReadParamsRequest],
) (*connect.Response[query.ReadParamsResponse], error) {
	ctx := context.Background()
	return u.ReadParamsWithContext(ctx, req)
}

// ReadParamsWithContext invokes Query.ReadParams after injecting stored
// headers into the request.
func (u *UtxorpcClient) ReadParamsWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadParamsRequest],
) (*connect.Response[query.ReadParamsResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadParams(ctx, req)
}

// ReadTx calls [(*UtxorpcClient).ReadTxWithContext] with a background context.
func (u *UtxorpcClient) ReadTx(
	req *connect.Request[query.ReadTxRequest],
) (*connect.Response[query.ReadTxResponse], error) {
	ctx := context.Background()
	return u.ReadTxWithContext(ctx, req)
}

// ReadTxWithContext invokes Query.ReadTx after injecting stored headers
// into the request.
func (u *UtxorpcClient) ReadTxWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadTxRequest],
) (*connect.Response[query.ReadTxResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadTx(ctx, req)
}

// ReadUtxos calls [(*UtxorpcClient).ReadUtxosWithContext] with a background context.
func (u *UtxorpcClient) ReadUtxos(
	req *connect.Request[query.ReadUtxosRequest],
) (*connect.Response[query.ReadUtxosResponse], error) {
	ctx := context.Background()
	return u.ReadUtxosWithContext(ctx, req)
}

// ReadUtxosWithContext invokes Query.ReadUtxos after injecting stored
// headers into the request.
func (u *UtxorpcClient) ReadUtxosWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadUtxosRequest],
) (*connect.Response[query.ReadUtxosResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadUtxos(ctx, req)
}

// SearchUtxos calls [(*UtxorpcClient).SearchUtxosWithContext] with a background context.
func (u *UtxorpcClient) SearchUtxos(
	req *connect.Request[query.SearchUtxosRequest],
) (*connect.Response[query.SearchUtxosResponse], error) {
	ctx := context.Background()
	return u.SearchUtxosWithContext(ctx, req)
}

// SearchUtxosWithContext invokes Query.SearchUtxos after injecting stored
// headers into the request.
func (u *UtxorpcClient) SearchUtxosWithContext(
	ctx context.Context,
	req *connect.Request[query.SearchUtxosRequest],
) (*connect.Response[query.SearchUtxosResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.SearchUtxos(ctx, req)
}

package sdk

import (
	"context"
	"iter"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/query/queryconnect"
	"google.golang.org/protobuf/proto"
)

// QueryServiceClient is the generated Connect client for the UTxO RPC Query
// service. It is re-exported so callers can hold a typed reference without
// importing the generated queryconnect package directly.
type QueryServiceClient = queryconnect.QueryServiceClient

// NewQueryServiceClient returns a fresh [QueryServiceClient] bound to the
// given [UtxorpcClient]'s HTTP client and base URL. Equivalent to
// [(*UtxorpcClient).NewQueryServiceClient]; provided as a free function for
// callers that prefer that style.
func NewQueryServiceClient(u *UtxorpcClient) QueryServiceClient {
	return u.NewQueryServiceClient()
}

// NewQueryServiceClient returns a fresh [QueryServiceClient] bound to this
// client's HTTP client and base URL. The result is independent of
// [UtxorpcClient.Query] and is rebuilt every call.
func (u *UtxorpcClient) NewQueryServiceClient() QueryServiceClient {
	return queryconnect.NewQueryServiceClient(
		u.httpClient,
		u.baseUrl,
		u.clientOptions()...,
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
// into the request. ReadData fetches arbitrary chain data; refer to the
// UTxO RPC spec for the request shape.
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
// stored headers into the request. Returns era boundaries, slot lengths,
// and other epoch-bound parameters.
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
// headers into the request. Returns the chain's genesis configuration.
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
// headers into the request. Returns the current protocol parameters along
// with the ledger tip they apply to.
func (u *UtxorpcClient) ReadParamsWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadParamsRequest],
) (*connect.Response[query.ReadParamsResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadParams(ctx, req)
}

// ReadState calls [(*UtxorpcClient).ReadStateWithContext] with a background context.
func (u *UtxorpcClient) ReadState(
	req *connect.Request[query.ReadStateRequest],
) (*connect.Response[query.ReadStateResponse], error) {
	ctx := context.Background()
	return u.ReadStateWithContext(ctx, req)
}

// ReadStateWithContext invokes Query.ReadState after injecting stored headers
// into the request. Returns chain state selected by the request.
func (u *UtxorpcClient) ReadStateWithContext(
	ctx context.Context,
	req *connect.Request[query.ReadStateRequest],
) (*connect.Response[query.ReadStateResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.ReadState(ctx, req)
}

// ReadTx calls [(*UtxorpcClient).ReadTxWithContext] with a background context.
func (u *UtxorpcClient) ReadTx(
	req *connect.Request[query.ReadTxRequest],
) (*connect.Response[query.ReadTxResponse], error) {
	ctx := context.Background()
	return u.ReadTxWithContext(ctx, req)
}

// ReadTxWithContext invokes Query.ReadTx after injecting stored headers into
// the request. Returns one or more transactions by reference.
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
// headers into the request. Returns UTxOs by exact reference (tx hash + index).
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
// headers into the request. Searches UTxOs by predicate (e.g. address,
// asset). Use [query.SearchUtxosRequest]'s pagination fields for large
// result sets.
func (u *UtxorpcClient) SearchUtxosWithContext(
	ctx context.Context,
	req *connect.Request[query.SearchUtxosRequest],
) (*connect.Response[query.SearchUtxosResponse], error) {
	u.AddHeadersToRequest(req)
	return u.Query.SearchUtxos(ctx, req)
}

// SearchUtxosPages calls [(*UtxorpcClient).SearchUtxosPagesWithContext] with
// a background context.
func (u *UtxorpcClient) SearchUtxosPages(
	req *connect.Request[query.SearchUtxosRequest],
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	return u.SearchUtxosPagesWithContext(context.Background(), req)
}

// SearchUtxosPagesWithContext returns a lazy sequence of SearchUtxos pages.
// It starts at req's start_token and follows each response's next_token until
// no token remains. The request is cloned and is not modified.
//
// Each iteration yields either a response and a nil error, or a nil response
// and the error that stopped pagination. Callers that stop iteration early
// avoid fetching subsequent pages.
func (u *UtxorpcClient) SearchUtxosPagesWithContext(
	ctx context.Context,
	req *connect.Request[query.SearchUtxosRequest],
) iter.Seq2[*connect.Response[query.SearchUtxosResponse], error] {
	return func(yield func(
		*connect.Response[query.SearchUtxosResponse],
		error,
	) bool,
	) {
		queryReq := proto.Clone(req.Msg).(*query.SearchUtxosRequest)

		for {
			pageReq := connect.NewRequest(queryReq)
			copyRequestHeaders(pageReq, req)

			resp, err := u.SearchUtxosWithContext(ctx, pageReq)
			if err != nil {
				yield(nil, err)
				return
			}
			if !yield(resp, nil) {
				return
			}

			nextToken := resp.Msg.GetNextToken()
			if nextToken == "" {
				return
			}
			queryReq.StartToken = proto.String(nextToken)
		}
	}
}

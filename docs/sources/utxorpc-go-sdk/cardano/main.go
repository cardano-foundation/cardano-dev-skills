package cardano

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/query"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/submit"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/sync"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/watch"
	sdk "github.com/utxorpc/go-sdk"
)

// Client is a high-level Cardano client. It embeds a generic
// [*sdk.UtxorpcClient] (accessible via the UtxorpcClient field) for header
// management and direct service access, and adds Cardano-specific helpers
// that build the appropriate request types and decode common input formats.
type Client struct {
	UtxorpcClient *sdk.UtxorpcClient
}

// NewClient constructs a Cardano [Client] backed by a fresh
// [*sdk.UtxorpcClient] configured with the given SDK options.
func NewClient(options ...sdk.ClientOption) *Client {
	c := &Client{}
	c.UtxorpcClient = sdk.NewClient(options...)
	return c
}

// GetProtocolParameters calls [Client.GetProtocolParametersWithContext] with a background context.
func (c *Client) GetProtocolParameters() (*connect.Response[query.ReadParamsResponse], error) {
	ctx := context.Background()
	return c.GetProtocolParametersWithContext(ctx)
}

// GetProtocolParametersWithContext fetches the current protocol parameters
// via Query.ReadParams. Equivalent to building an empty
// [query.ReadParamsRequest] and calling the generic client.
func (c *Client) GetProtocolParametersWithContext(
	ctx context.Context,
) (*connect.Response[query.ReadParamsResponse], error) {
	req := connect.NewRequest(&query.ReadParamsRequest{})
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Query.ReadParams(ctx, req)
}

// GetUtxoByRef calls [Client.GetUtxoByRefWithContext] with a background context.
func (c *Client) GetUtxoByRef(
	txHashStr string,
	txIndex uint32,
) (*connect.Response[query.ReadUtxosResponse], error) {
	return c.GetUtxoByRefWithContext(context.Background(), txHashStr, txIndex)
}

// GetUtxoByRefWithContext reads a single UTxO by transaction reference.
// txHashStr is decoded as hex first; if hex decoding fails, it is decoded
// as standard base64. An error is returned if neither succeeds.
func (c *Client) GetUtxoByRefWithContext(
	ctx context.Context,
	txHashStr string,
	txIndex uint32,
) (*connect.Response[query.ReadUtxosResponse], error) {
	var txHashBytes []byte
	var err error
	// Attempt to decode the input as hex
	txHashBytes, hexErr := hex.DecodeString(txHashStr)
	if hexErr != nil {
		// If not hex, attempt to decode as Base64
		txHashBytes, err = base64.StdEncoding.DecodeString(txHashStr)
		if err != nil {
			return nil, err
		}
	}
	// Create TxoRef with the decoded hash bytes
	txoRef := &query.TxoRef{
		Hash:  txHashBytes, // Use the decoded []byte
		Index: txIndex,
	}
	txReq := &query.ReadUtxosRequest{Keys: []*query.TxoRef{txoRef}}
	req := connect.NewRequest(txReq)
	return c.UtxorpcClient.ReadUtxosWithContext(ctx, req)
}

// EvaluateTransaction performs a dry run of a transaction without
// broadcasting it. txCbor is the full signed transaction CBOR encoded as a
// hex string; the response carries execution units and validation results.
//
// Use [Client.EvaluateTransactionWithContext] when you need to supply your
// own [submit.EvalTxRequest] (e.g. to evaluate something other than a raw
// hex CBOR transaction).
func (c *Client) EvaluateTransaction(
	txCbor string,
) (*connect.Response[submit.EvalTxResponse], error) {
	ctx := context.Background()
	// Decode the transaction data from hex
	txRawBytes, err := hex.DecodeString(txCbor)
	if err != nil {
		return nil, fmt.Errorf("failed to decode transaction hash: %w", err)
	}

	// Create a EvalTxRequest with the transaction data
	tx := &submit.AnyChainTx{
		Type: &submit.AnyChainTx_Raw{
			Raw: txRawBytes,
		},
	}

	// Create a list with one transaction
	req := &submit.EvalTxRequest{
		Tx: tx,
	}
	return c.EvaluateTransactionWithContext(ctx, req)
}

// EvaluateTransactionWithContext invokes Submit.EvalTx with a caller-supplied
// request and the given context. Stored headers are injected before the call.
func (c *Client) EvaluateTransactionWithContext(
	ctx context.Context,
	txReq *submit.EvalTxRequest,
) (*connect.Response[submit.EvalTxResponse], error) {
	req := connect.NewRequest(txReq)
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Submit.EvalTx(ctx, req)
}

// GetMempoolTransactions calls [Client.GetMempoolTransactionsWithContext] with a background context.
func (c *Client) GetMempoolTransactions() (*connect.Response[submit.ReadMempoolResponse], error) {
	ctx := context.Background()
	return c.GetMempoolTransactionsWithContext(ctx)
}

// GetMempoolTransactionsWithContext returns a snapshot of pending mempool
// transactions via Submit.ReadMempool.
func (c *Client) GetMempoolTransactionsWithContext(
	ctx context.Context,
) (*connect.Response[submit.ReadMempoolResponse], error) {
	req := connect.NewRequest(&submit.ReadMempoolRequest{})
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Submit.ReadMempool(ctx, req)
}

// GetUtxosByRefs calls [Client.GetUtxosByRefsWithContext] with a background context.
func (c *Client) GetUtxosByRefs(
	refs []*query.TxoRef,
) (*connect.Response[query.ReadUtxosResponse], error) {
	return c.GetUtxosByRefsWithContext(context.Background(), refs)
}

// GetUtxosByRefsWithContext reads multiple UTxOs in one call via
// Query.ReadUtxos. Returns an error if refs is empty.
func (c *Client) GetUtxosByRefsWithContext(
	ctx context.Context,
	refs []*query.TxoRef,
) (*connect.Response[query.ReadUtxosResponse], error) {
	if len(refs) == 0 {
		return nil, errors.New("no transaction references provided")
	}

	txReq := &query.ReadUtxosRequest{Keys: refs}
	req := connect.NewRequest(txReq)
	return c.UtxorpcClient.ReadUtxosWithContext(ctx, req)
}

// GetUtxosByAddress calls [Client.GetUtxosByAddressWithContext] with a background context.
func (c *Client) GetUtxosByAddress(
	address []byte,
	options ...SearchOption,
) (*connect.Response[query.SearchUtxosResponse], error) {
	return c.GetUtxosByAddressWithContext(
		context.Background(),
		address,
		options...,
	)
}

// GetUtxosByAddressWithContext searches for UTxOs locked at an exact Cardano
// address via Query.SearchUtxos. The address must be supplied as raw bytes;
// bech32 strings must be decoded by the caller. By default, the first page of
// up to 100 results is returned. Use SearchOption values to configure the page,
// or [Client.GetUtxosByAddressPages] to iterate all pages.
func (c *Client) GetUtxosByAddressWithContext(
	ctx context.Context,
	address []byte,
	options ...SearchOption,
) (*connect.Response[query.SearchUtxosResponse], error) {
	queryReq := newAddressSearchRequest(address, options...)
	req := connect.NewRequest(queryReq)
	return c.UtxorpcClient.SearchUtxosWithContext(ctx, req)
}

// GetUtxosByAddressWithAsset calls [Client.GetUtxosByAddressWithAssetWithContext]
// with a background context.
func (c *Client) GetUtxosByAddressWithAsset(
	addressBytes []byte,
	policyIdBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) (*connect.Response[query.SearchUtxosResponse], error) {
	return c.GetUtxosByAddressWithAssetWithContext(
		context.Background(),
		addressBytes,
		policyIdBytes,
		assetNameBytes,
		options...,
	)
}

// GetUtxosByAddressWithAssetWithContext searches for UTxOs at the given
// address that hold a matching native asset. policyIdBytes and assetNameBytes
// are raw bytes; either may be empty to widen the match (policy-only,
// asset-name-only, or both empty for any UTxO at the address). By default, the
// first page of up to 100 results is returned. Use SearchOption values to
// configure the page.
func (c *Client) GetUtxosByAddressWithAssetWithContext(
	ctx context.Context,
	addressBytes []byte,
	policyIdBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) (*connect.Response[query.SearchUtxosResponse], error) {
	queryReq := newAddressAssetSearchRequest(
		addressBytes,
		policyIdBytes,
		assetNameBytes,
		options...,
	)
	req := connect.NewRequest(queryReq)
	return c.UtxorpcClient.SearchUtxosWithContext(ctx, req)
}

// GetUtxosByAsset calls [Client.GetUtxosByAssetWithContext] with a background context.
func (c *Client) GetUtxosByAsset(
	policyIdBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) (*connect.Response[query.SearchUtxosResponse], error) {
	return c.GetUtxosByAssetWithContext(
		context.Background(),
		policyIdBytes,
		assetNameBytes,
		options...,
	)
}

// GetUtxosByAssetWithContext searches for UTxOs holding a native asset
// across all addresses. policyIdBytes and assetNameBytes are raw bytes; at
// least one must be non-nil — passing nil for both returns an error.
// By default, the first page of up to 100 results is returned. Use SearchOption
// values to configure the page.
func (c *Client) GetUtxosByAssetWithContext(
	ctx context.Context,
	policyIdBytes []byte,
	assetNameBytes []byte,
	options ...SearchOption,
) (*connect.Response[query.SearchUtxosResponse], error) {
	queryReq, err := newAssetSearchRequest(
		policyIdBytes,
		assetNameBytes,
		options...,
	)
	if err != nil {
		return nil, err
	}
	req := connect.NewRequest(queryReq)
	return c.UtxorpcClient.SearchUtxosWithContext(ctx, req)
}

// SubmitTransaction broadcasts a signed transaction. txCbor is the full
// signed transaction CBOR encoded as a hex string; the response carries the
// resulting transaction reference.
//
// Use [Client.SubmitTransactionWithContext] when you need to supply your own
// [submit.SubmitTxRequest] (e.g. a non-raw transaction shape).
func (c *Client) SubmitTransaction(
	txCbor string,
) (*connect.Response[submit.SubmitTxResponse], error) {
	ctx := context.Background()
	// Decode the transaction data from hex
	txRawBytes, err := hex.DecodeString(txCbor)
	if err != nil {
		return nil, fmt.Errorf("failed to decode transaction hash: %w", err)
	}

	// Create a SubmitTxRequest with the transaction data
	tx := &submit.AnyChainTx{
		Type: &submit.AnyChainTx_Raw{
			Raw: txRawBytes,
		},
	}

	// Create a list with one transaction
	req := &submit.SubmitTxRequest{
		Tx: tx,
	}
	return c.SubmitTransactionWithContext(ctx, req)
}

// SubmitTransactionWithContext invokes Submit.SubmitTx with a caller-supplied
// request and the given context. Stored headers are injected before the call.
func (c *Client) SubmitTransactionWithContext(
	ctx context.Context,
	txReq *submit.SubmitTxRequest,
) (*connect.Response[submit.SubmitTxResponse], error) {
	req := connect.NewRequest(txReq)
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Submit.SubmitTx(ctx, req)
}

// WaitForTransaction opens a server stream that emits stage transitions
// (e.g. mempool → confirmed) for the given transaction reference. txRef is a
// hex-encoded transaction hash. The caller must close the returned stream.
//
// Use [Client.WaitForTransactionWithContext] to wait for multiple references
// or when you need a [context.Context].
func (c *Client) WaitForTransaction(
	txRef string,
) (*connect.ServerStreamForClient[submit.WaitForTxResponse], error) {
	ctx := context.Background()
	// Decode the transaction references from hex
	decodedRefs := make([][]byte, 0, 1)
	refBytes, err := hex.DecodeString(txRef)
	if err != nil {
		return nil, fmt.Errorf(
			"failed to decode transaction reference %s: %w",
			txRef,
			err,
		)
	}
	decodedRefs = append(decodedRefs, refBytes)

	// Create a WaitForTxRequest with the decoded transaction references
	req := &submit.WaitForTxRequest{
		Ref: decodedRefs,
	}
	return c.WaitForTransactionWithContext(ctx, req)
}

// WaitForTransactionWithContext invokes Submit.WaitForTx with a caller-supplied
// request and the given context. Stored headers are injected before the call.
func (c *Client) WaitForTransactionWithContext(
	ctx context.Context,
	txReq *submit.WaitForTxRequest,
) (*connect.ServerStreamForClient[submit.WaitForTxResponse], error) {
	req := connect.NewRequest(txReq)
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Submit.WaitForTx(ctx, req)
}

// WatchMempoolTransactions calls
// [Client.WatchMempoolTransactionsWithContext] with a background context.
func (c *Client) WatchMempoolTransactions() (
	*connect.ServerStreamForClient[submit.WatchMempoolResponse],
	error,
) {
	ctx := context.Background()
	return c.WatchMempoolTransactionsWithContext(ctx)
}

// WatchMempoolTransactionsWithContext opens a server stream of mempool
// Apply / Undo events via Submit.WatchMempool. The caller must close the
// returned stream.
func (c *Client) WatchMempoolTransactionsWithContext(ctx context.Context) (
	*connect.ServerStreamForClient[submit.WatchMempoolResponse],
	error,
) {
	req := connect.NewRequest(&submit.WatchMempoolRequest{})
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Submit.WatchMempool(ctx, req)
}

func syncIntersect(blockHashStr string, blockIndex int64) []*sync.BlockRef {
	var intersect []*sync.BlockRef
	// Construct the BlockRef based on the provided parameters
	blockRef := &sync.BlockRef{}
	if blockHashStr != "" {
		hash, err := hex.DecodeString(blockHashStr)
		if err != nil {
			return nil
		}
		blockRef.Hash = hash
	}
	// We assume blockIndex can be 0 or any positive number, and won't overflow
	// #nosec G115
	if blockIndex > -1 {
		blockRef.Slot = uint64(blockIndex)
	}
	// Only add blockRef to intersect if at least one of blockHashStr or blockIndex is provided
	if blockHashStr != "" || blockIndex > -1 {
		intersect = []*sync.BlockRef{blockRef}
	}
	return intersect
}

// GetBlockByRef fetches a block via Sync.FetchBlock. blockHashStr is a hex
// block hash (empty string to omit) and blockIndex is the slot (-1 to omit).
// If both are omitted the request carries no intersect and the server's
// default behavior applies.
func (c *Client) GetBlockByRef(
	blockHashStr string,
	blockIndex int64,
) (*connect.Response[sync.FetchBlockResponse], error) {
	ctx := context.Background()
	req := &sync.FetchBlockRequest{Ref: syncIntersect(blockHashStr, blockIndex)}
	return c.GetBlockByRefWithContext(ctx, req)
}

// GetBlockByRefWithContext invokes Sync.FetchBlock with a caller-supplied
// request and the given context. Stored headers are injected before the call.
func (c *Client) GetBlockByRefWithContext(
	ctx context.Context,
	blockReq *sync.FetchBlockRequest,
) (*connect.Response[sync.FetchBlockResponse], error) {
	req := connect.NewRequest(blockReq)
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Sync.FetchBlock(ctx, req)
}

// WatchBlocksByRef opens a server stream of chain-tip events
// (Apply / Undo / Reset) starting from the given intersect point.
// blockHashStr is a hex block hash (empty string to omit) and blockIndex is
// the slot (-1 to omit). The caller must close the returned stream.
func (c *Client) WatchBlocksByRef(
	blockHashStr string,
	blockIndex int64,
) (*connect.ServerStreamForClient[sync.FollowTipResponse], error) {
	ctx := context.Background()
	req := &sync.FollowTipRequest{
		Intersect: syncIntersect(blockHashStr, blockIndex),
	}
	return c.WatchBlocksByRefWithContext(ctx, req)
}

// WatchBlocksByRefWithContext invokes Sync.FollowTip with a caller-supplied
// request and the given context. Stored headers are injected before the call.
func (c *Client) WatchBlocksByRefWithContext(
	ctx context.Context,
	blockReq *sync.FollowTipRequest,
) (*connect.ServerStreamForClient[sync.FollowTipResponse], error) {
	req := connect.NewRequest(blockReq)
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Sync.FollowTip(ctx, req)
}

// GetTip calls [Client.GetTipWithContext] with a background context.
func (c *Client) GetTip() (*connect.Response[sync.ReadTipResponse], error) {
	return c.GetTipWithContext(context.Background())
}

// GetTipWithContext returns the current chain tip via Sync.ReadTip. Returns
// an error if the server replies with an empty tip.
func (c *Client) GetTipWithContext(
	ctx context.Context,
) (*connect.Response[sync.ReadTipResponse], error) {
	readTipReqProto := &sync.ReadTipRequest{}
	reqReadTip := connect.NewRequest(readTipReqProto)
	c.UtxorpcClient.AddHeadersToRequest(reqReadTip)

	tipResp, err := c.UtxorpcClient.Sync.ReadTip(ctx, reqReadTip)
	if err != nil {
		return nil, fmt.Errorf("failed to read tip: %w", err)
	}
	if tipResp.Msg == nil || tipResp.Msg.GetTip() == nil {
		return nil, errors.New("received nil tip from ReadTipResponse")
	}

	return tipResp, nil
}

// ReadBlock calls [Client.ReadBlockWithContext] with a background context.
func (c *Client) ReadBlock(
	blockRef *sync.BlockRef,
) (*connect.Response[sync.FetchBlockResponse], error) {
	return c.ReadBlockWithContext(context.Background(), blockRef)
}

// ReadBlockWithContext fetches a single block via Sync.FetchBlock and
// validates that the response contains a Cardano block with a non-nil
// header. Returns an error if the response is empty, missing a Cardano
// chain block, or the header is nil; non-Cardano chain blocks return a
// "unknown or unsupported chain type" error.
func (c *Client) ReadBlockWithContext(
	ctx context.Context,
	blockRef *sync.BlockRef,
) (*connect.Response[sync.FetchBlockResponse], error) {
	fetchBlockReqProto := &sync.FetchBlockRequest{
		Ref: []*sync.BlockRef{blockRef},
	}
	reqFetchBlock := connect.NewRequest(fetchBlockReqProto)
	c.UtxorpcClient.AddHeadersToRequest(reqFetchBlock)

	blockRespFull, err := c.UtxorpcClient.Sync.FetchBlock(ctx, reqFetchBlock)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch block for tip: %w", err)
	}
	if blockRespFull.Msg == nil || len(blockRespFull.Msg.GetBlock()) == 0 ||
		blockRespFull.Msg.GetBlock()[0] == nil {
		return nil, errors.New(
			"received nil or empty block data from FetchBlockResponse for tip",
		)
	}

	anyChainBlock := blockRespFull.Msg.GetBlock()[0]

	switch chain := anyChainBlock.GetChain().(type) {
	case *sync.AnyChainBlock_Cardano:
		if chain.Cardano != nil && chain.Cardano.GetHeader() != nil {
			return blockRespFull, nil
		} else {
			return nil, errors.New("cardano block or header is nil in FetchBlock response for tip")
		}
	default:
		return nil, fmt.Errorf("unknown or unsupported chain type in FetchBlock response: %T", chain)
	}
}

func watchIntersect(blockHashStr string, blockIndex int64) []*watch.BlockRef {
	var intersect []*watch.BlockRef
	// Construct the BlockRef based on the provided parameters
	blockRef := &watch.BlockRef{}
	if blockHashStr != "" {
		hash, err := hex.DecodeString(blockHashStr)
		if err != nil {
			return nil
		}
		blockRef.Hash = hash
	}
	// We assume blockIndex can be 0 or any positive number, and won't overflow
	// #nosec G115
	if blockIndex > -1 {
		blockRef.Slot = uint64(blockIndex)
	}
	// Only add blockRef to intersect if at least one of blockHashStr or blockIndex is provided
	if blockHashStr != "" || blockIndex > -1 {
		intersect = []*watch.BlockRef{blockRef}
	}
	return intersect
}

// WatchTransaction opens a server stream of transaction events via
// Watch.WatchTx, starting from the given intersect point. blockHashStr is a
// hex block hash (empty string to omit) and blockIndex is the slot (-1 to
// omit). The caller must close the returned stream.
func (c *Client) WatchTransaction(
	blockHashStr string,
	blockIndex int64,
) (*connect.ServerStreamForClient[watch.WatchTxResponse], error) {
	ctx := context.Background()
	req := &watch.WatchTxRequest{
		Intersect: watchIntersect(blockHashStr, blockIndex),
	}
	return c.WatchTransactionWithContext(ctx, req)
}

// WatchTransactionWithContext invokes Watch.WatchTx with a caller-supplied
// request and the given context. Stored headers are injected before the call.
func (c *Client) WatchTransactionWithContext(
	ctx context.Context,
	watchReq *watch.WatchTxRequest,
) (*connect.ServerStreamForClient[watch.WatchTxResponse], error) {
	req := connect.NewRequest(watchReq)
	c.UtxorpcClient.AddHeadersToRequest(req)
	return c.UtxorpcClient.Watch.WatchTx(ctx, req)
}

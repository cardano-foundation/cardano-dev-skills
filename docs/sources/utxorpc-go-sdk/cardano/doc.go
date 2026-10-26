// Package cardano provides high-level, Cardano-specific convenience methods
// on top of the generic [github.com/utxorpc/go-sdk] client (v1beta).
//
// It removes the boilerplate of building Connect requests, decoding hex/base64
// inputs, constructing Cardano UTxO and asset patterns, and handling common
// streaming flows. Use this package when you are targeting Cardano; for
// blockchain-agnostic access use [github.com/utxorpc/go-sdk] directly.
//
// There is no v1alpha equivalent of this package.
//
// # Quick start
//
//	client := cardano.NewClient(sdk.WithBaseUrl(os.Getenv("UTXORPC_URL")))
//	if key := os.Getenv("DMTR_API_KEY"); key != "" {
//	    client.UtxorpcClient.SetHeader("dmtr-api-key", key)
//	}
//
//	tip, err := client.GetTipWithContext(ctx)
//	if err != nil {
//	    return err
//	}
//	fmt.Println(tip.Msg.GetTip().GetSlot())
//
// Set UTXORPC_URL to your server's base URL. This snippet assumes a caller's
// context ctx and imports the root package as sdk.
//
// # Encoding gotchas
//
//   - Transaction hashes accepted by [Client.GetUtxoByRef] are tried as hex
//     first, then as standard base64 if hex decoding fails.
//   - [Client.WaitForTransaction] expects a hex-encoded transaction reference.
//   - [Client.SubmitTransaction] and [Client.EvaluateTransaction] expect the
//     full signed transaction CBOR encoded as a hex string.
//   - [Client.GetBlockByRef], [Client.WatchBlocksByRef], and
//     [Client.WatchTransaction] accept a hex block hash plus a slot; pass an
//     empty hash and -1 slot to omit the reference or intersect and use the
//     server's default behavior. WatchTransaction takes a block hash, not a
//     transaction hash.
//   - Address arguments are raw bytes, not bech32. Use a Cardano library such
//     as [github.com/blinklabs-io/gouroboros] to decode addresses first.
//   - Asset filters: policy ID and asset name are raw bytes.
//
// # API surface
//
// Construction:
//
//	NewClient(opts ...sdk.ClientOption) *Client
//	(*Client).UtxorpcClient                     — generic client field; use
//	                                              for header management or to
//	                                              reach Query/Submit/Sync/Watch
//	                                              services directly.
//
// Query helpers:
//
//	GetProtocolParameters()
//	GetUtxoByRef(txHash, idx)                   — hex or base64 hash
//	GetUtxosByRefs(refs)                        — batched
//	GetUtxosByAddress(addressBytes)
//	GetUtxosByAddressWithAsset(addr, policyId, assetName)
//	GetUtxosByAsset(policyId, assetName)        — at least one must be non-nil
//	GetUtxosByAddressPages(addressBytes)        — lazy automatic pagination
//	GetUtxosByAddressWithAssetPages(...)
//	GetUtxosByAssetPages(...)
//
// UTxO search helpers accept optional [SearchOption] values. Use
// [WithSearchMaxItems], [WithSearchStartToken], and [WithSearchFieldMask] to
// control pagination and field selection without constructing a raw protobuf
// request. Defaults are up to 100 items on the first page and all fields.
// The Pages variants lazily yield responses and errors until no token remains;
// breaking iteration avoids fetching further pages. Invalid asset filters
// are yielded as the first error without making an RPC.
//
// Submit helpers:
//
//	SubmitTransaction(txCborHex)
//	EvaluateTransaction(txCborHex)
//	GetMempoolTransactions()
//	WaitForTransaction(txRefHex)                — server stream
//	WatchMempoolTransactions()                  — server stream
//
// Sync helpers:
//
//	GetTip()
//	GetBlockByRef(blockHashHex, slot)
//	ReadBlock(blockRef)                         — full FetchBlock response;
//	                                              validates the first block
//	                                              is Cardano with a header.
//	WatchBlocksByRef(blockHashHex, slot)        — server stream
//
// Watch helpers:
//
//	WatchTransaction(blockHashHex, slot)        — server stream
//
// # Method-pair convention
//
// Each helper has a WithContext variant (e.g. [Client.GetTipWithContext])
// that takes an explicit [context.Context]. The non-context form uses
// [context.Background] internally.
//
// Some context variants accept a protobuf request instead of convenience
// arguments. Supply decoded bytes in these requests:
//
//	SubmitTransactionWithContext(ctx, *submit.SubmitTxRequest)
//	EvaluateTransactionWithContext(ctx, *submit.EvalTxRequest)
//	WaitForTransactionWithContext(ctx, *submit.WaitForTxRequest)
//	GetBlockByRefWithContext(ctx, *sync.FetchBlockRequest)
//	WatchBlocksByRefWithContext(ctx, *sync.FollowTipRequest)
//	WatchTransactionWithContext(ctx, *watch.WatchTxRequest)
//
// Other context variants retain their convenience arguments after ctx.
//
// # Streaming
//
// Streaming methods return *[connect.ServerStreamForClient]. Iterate with
// Receive(), read each message via Msg(), check Err() after the loop, and
// call Close(). A configured SDK request timeout also limits stream lifetime.
// See [github.com/utxorpc/go-sdk] for transport and streaming details.
//
// # See also
//
//   - [github.com/utxorpc/go-sdk] — the generic v1beta client this package wraps.
//   - https://utxorpc.org/spec — UTxO RPC specification.
package cardano

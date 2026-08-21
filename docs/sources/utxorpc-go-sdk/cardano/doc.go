// Package cardano provides high-level, Cardano-specific convenience methods
// on top of the generic [github.com/utxorpc/go-sdk] client (v1beta).
//
// It removes the boilerplate of building Connect requests, decoding hex/base64
// inputs, constructing Cardano UTxO and asset patterns, and handling common
// streaming flows. Use this package when you are targeting Cardano; for
// blockchain-agnostic access use the parent [sdk] package directly.
//
// There is no v1alpha equivalent of this package.
//
// # Quick start
//
//	client := cardano.NewClient(sdk.WithBaseUrl("https://preview.utxorpc-v0.demeter.run"))
//	client.UtxorpcClient.SetHeader("dmtr-api-key", "...")
//
//	tip, err := client.GetTip()
//	utxo, err := client.GetUtxoByRef("24efe5...431c", 0)
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
//     empty hash and -1 slot to start from origin / current tip.
//   - Address arguments are raw bytes, not bech32. Use a Cardano library such
//     as [github.com/blinklabs-io/gouroboros] to decode addresses first.
//   - Asset filters: policy ID and asset name are raw bytes.
//
// # API surface
//
// Construction:
//
//	NewClient(opts ...sdk.ClientOption) *Client
//	(*Client).UtxorpcClient                     — embedded generic client; use
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
//	GetUtxosByAsset(policyId, assetName)        — at least one of the two required
//	GetUtxosByAddressPages(addressBytes)        — lazy automatic pagination
//	GetUtxosByAddressWithAssetPages(...)
//	GetUtxosByAssetPages(...)
//
// UTxO search helpers accept optional [SearchOption] values. Use
// [WithSearchMaxItems], [WithSearchStartToken], and [WithSearchFieldMask] to
// control pagination and field selection without constructing a raw protobuf
// request.
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
//	ReadBlock(blockRef)                         — typed Cardano block; errors
//	                                              if response is empty or
//	                                              not a Cardano block.
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
// # Streaming
//
// Streaming methods return *[connect.ServerStreamForClient]. Iterate with
// Receive(), read each message via Msg(), check Err() after the loop, and
// call Close(). See the parent [sdk] package documentation for details.
//
// # See also
//
//   - [github.com/utxorpc/go-sdk] — the generic v1beta client this package wraps.
//   - https://utxorpc.org/spec — UTxO RPC specification.
package cardano

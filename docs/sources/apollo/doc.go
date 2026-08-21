// Package apollo builds Cardano transactions in pure Go.
//
// A build starts from a chain backend and an [Apollo] value returned by [New].
// Fluent methods accumulate inputs, outputs, scripts, certificates, metadata,
// and governance actions. [Apollo.Complete] then balances the transaction,
// selects change, and derives fees and Plutus execution units from the
// backend's protocol parameters; [Apollo.Sign] attaches witnesses and
// [Apollo.Submit] publishes the result.
//
// Ledger types come from github.com/blinklabs-io/gouroboros, so addresses,
// values, scripts, and transaction bodies are the same types the rest of the
// Blink Labs stack uses. Builder methods that cannot fail return *Apollo for
// chaining and record any error internally; Complete reports it.
//
// # Quickstart
//
//	package main
//
//	import (
//		"encoding/hex"
//		"fmt"
//
//		"github.com/blinklabs-io/gouroboros/ledger/common"
//
//		apollo "github.com/Salvionied/apollo/v2"
//		"github.com/Salvionied/apollo/v2/backend/blockfrost"
//		"github.com/Salvionied/apollo/v2/constants"
//	)
//
//	func main() {
//		chainContext := blockfrost.NewBlockFrostChainContext(
//			constants.BlockfrostBaseUrlMainnet,
//			1, // mainnet network ID
//			"your_blockfrost_project_id",
//		)
//
//		builder, err := apollo.New(chainContext).
//			SetWalletFromMnemonic("your mnemonic here")
//		if err != nil {
//			panic(err)
//		}
//
//		utxos, err := chainContext.Utxos(builder.GetWallet().Address())
//		if err != nil {
//			panic(err)
//		}
//
//		receiver, err := common.NewAddress("addr1...")
//		if err != nil {
//			panic(err)
//		}
//
//		builder, err = builder.AddLoadedUTxOs(utxos...).
//			PayToAddress(receiver, 1_000_000).
//			Complete()
//		if err != nil {
//			panic(err)
//		}
//
//		builder, err = builder.Sign()
//		if err != nil {
//			panic(err)
//		}
//
//		txId, err := builder.Submit()
//		if err != nil {
//			panic(err)
//		}
//		fmt.Println(hex.EncodeToString(txId.Bytes()))
//	}
//
// # Backends
//
// Every backend implements ChainContext from
// [github.com/Salvionied/apollo/v2/backend]: blockfrost, maestro, ogmios (with
// Kupo), and utxorpc for live chains, plus fixed for deterministic tests and
// cache as a TTL wrapper. Backends may also report which optional operations
// they support, so check backend.CapabilityReporter before depending on one.
package apollo

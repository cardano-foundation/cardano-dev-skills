package main

import (
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"os"

	sync "github.com/utxorpc/go-codegen/utxorpc/v1beta/sync"
	"github.com/utxorpc/go-sdk"
	utxorpc "github.com/utxorpc/go-sdk/cardano"
)

func main() {
	baseUrl := os.Getenv("UTXORPC_URL")
	if baseUrl == "" {
		baseUrl = "https://preview.utxorpc-v0.demeter.run"
	}
	client := utxorpc.NewClient(sdk.WithBaseUrl(baseUrl))
	dmtrApiKey := os.Getenv("DMTR_API_KEY")
	// set API key for demeter
	if dmtrApiKey != "" {
		client.UtxorpcClient.SetHeader("dmtr-api-key", dmtrApiKey)
	}

	// Run them all
	fetchBlock(
		client,
		"235f9a217b826276d6cdfbb05c11572a06aef092535b6df8c682d501af59c230",
		65017558,
	)
	followTip(
		client,
		"235f9a217b826276d6cdfbb05c11572a06aef092535b6df8c682d501af59c230",
		65017558,
	)
}

func fetchBlock(
	client *utxorpc.Client,
	blockHash string,
	blockIndex int64,
) {
	fmt.Println("connecting to utxorpc host:", client.UtxorpcClient.URL())
	resp, err := client.GetBlockByRef(blockHash, blockIndex)
	if err != nil {
		reportError(err)
		return
	}
	fmt.Printf("Response: %+v\n", resp)
	for i, blockRef := range resp.Msg.GetBlock() {
		fmt.Printf("Block[%d]:\n", i)
		fmt.Printf("Index: %d\n", blockRef.GetCardano().GetHeader().GetSlot())
		fmt.Printf("Hash: %x\n", blockRef.GetCardano().GetHeader().GetHash())
	}
}

func followTip(
	client *utxorpc.Client,
	blockHash string,
	blockIndex int64,
) {
	fmt.Println("connecting to utxorpc host:", client.UtxorpcClient.URL())
	stream, err := client.WatchBlocksByRef(blockHash, blockIndex)
	if err != nil {
		reportError(err)
		return
	}
	fmt.Println("Connected to utxorpc host, following tip...")

	for stream.Receive() {
		resp := stream.Msg()
		action := resp.GetAction()
		switch a := action.(type) {
		case *sync.FollowTipResponse_Apply:
			fmt.Println("Action: Apply")
			printAnyChainBlock(a.Apply)
		case *sync.FollowTipResponse_Undo:
			fmt.Println("Action: Undo")
			printAnyChainBlock(a.Undo)
		case *sync.FollowTipResponse_Reset_:
			fmt.Println("Action: Reset")
			printBlockRef(a.Reset_)
		default:
			fmt.Println("Unknown action type")
		}
	}

	if err := stream.Err(); err != nil {
		reportError(err)
	} else {
		fmt.Println("Stream ended normally.")
	}
}

func reportError(err error) {
	var transportErr net.Error
	if errors.As(err, &transportErr) {
		fmt.Printf("transport error: %v\n", transportErr)
		return
	}
	if connectErr, ok := sdk.AsConnectError(err); ok {
		fmt.Printf(
			"RPC error: code=%s message=%q metadata=%v details=%v\n",
			connectErr.Code(),
			connectErr.Message(),
			connectErr.Meta(),
			connectErr.Details(),
		)
		return
	}
	fmt.Printf("local error: %v\n", err)
}

func printAnyChainBlock(block *sync.AnyChainBlock) {
	if block == nil {
		return
	}
	if cardanoBlock := block.GetCardano(); cardanoBlock != nil {
		hash := hex.EncodeToString(cardanoBlock.GetHeader().GetHash())
		slot := cardanoBlock.GetHeader().GetSlot()
		fmt.Printf("Block Slot: %d, Block Hash: %s\n", slot, hash)
	}
}

func printBlockRef(blockRef *sync.BlockRef) {
	if blockRef == nil {
		return
	}
	hash := hex.EncodeToString(blockRef.GetHash())
	slot := blockRef.GetSlot()
	fmt.Printf("Block Slot: %d, Block Hash: %s\n", slot, hash)
}

package main

import (
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"os"

	"connectrpc.com/connect"
	"github.com/utxorpc/go-codegen/utxorpc/v1beta/submit"
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

	// Set mode to "submitTx", "readMempool", "waitForTx", or "watchMempool" to select the desired example.
	mode := "readMempool"

	switch mode {
	case "submitTx":
		// Submit a transaction
		txCbor := "Replace this with signed CBOR transaction"
		txRef, err := submitTx(client, txCbor)
		if err != nil {
			fmt.Printf("Error submitting transaction: %v\n", err)
			return
		}
		// Immediately wait for the transaction confirmation
		if err := waitForTx(client, txRef); err != nil {
			fmt.Printf("Error waiting for transaction: %v\n", err)
		}
	case "readMempool":
		readMempool(client)
	case "waitForTx":
		if err := waitForTx(client, "31bffedd962f4a6f5e85620985ccdf71f7b78988a6483e090f42d1e8badcebc8"); err != nil {
			fmt.Printf("Error waiting for transaction: %v\n", err)
		}
	case "watchMempool":
		watchMempool(client)
	default:
		fmt.Println("Unknown mode:", mode)
	}
}

// Modified submitTx to return transaction references
func submitTx(client *utxorpc.Client, txCbor string) (string, error) {
	fmt.Println("Connecting to utxorpc host:", client.UtxorpcClient.URL())
	resp, err := client.SubmitTransaction(txCbor)
	if err != nil {
		var connectErr *connect.Error
		if errors.As(err, &connectErr) {
			// Extract error details
			errorCode := connectErr.Code()
			errorMessage := connectErr.Error()
			grpcMessage := connectErr.Meta().Get("Grpc-Message")
			return "", fmt.Errorf(
				"gRPC error occurred:\n  Code: %v\n  Message: %s\n  Details: %s",
				errorCode,
				errorMessage,
				grpcMessage,
			)
		}
		return "", fmt.Errorf("unexpected error occurred: %w", err)
	}

	fmt.Println("Response:")
	// Extract and return transaction reference
	var txRef string
	if resp != nil && resp.Msg.Ref != nil {
		txRef = hex.EncodeToString(resp.Msg.GetRef())
		fmt.Printf("  TxRef: %s\n", txRef)
	}

	return txRef, nil
}

func readMempool(client *utxorpc.Client) {
	resp, err := client.GetMempoolTransactions()
	if err != nil {
		reportError(err)
		return
	}
	fmt.Printf("Response: %+v\n", resp)
}

func waitForTx(
	client *utxorpc.Client,
	txRef string,
) error {
	fmt.Println("Waiting for the following transaction reference:")
	fmt.Printf("  TxRef: %s\n", txRef)

	fmt.Println("Connecting to utxorpc host:", client.UtxorpcClient.URL())
	// Open a streaming connection to wait for transaction confirmation
	stream, err := client.WaitForTransaction(txRef)
	if err != nil {
		return fmt.Errorf("failed to open waitForTx stream: %w", err)
	}
	defer stream.Close()

	// Process the stream of responses
	for stream.Receive() {
		resp := stream.Msg()

		// Decode and print the received stage and reference
		txRef := hex.EncodeToString(resp.GetRef())
		txStage := resp.GetStage()
		fmt.Printf("Transaction %s is at stage: %v\n", txRef, txStage)

		// Break if the desired stage is reached (e.g., confirmed)
		if txStage == submit.Stage_STAGE_CONFIRMED {
			fmt.Printf("Transaction %s has been confirmed.\n", txRef)
			break
		}
	}

	// Check for stream errors
	if err := stream.Err(); err != nil {
		return fmt.Errorf("stream error: %w", err)
	}
	return nil
}

func watchMempool(client *utxorpc.Client) {
	fmt.Println("Connecting to utxorpc host:", client.UtxorpcClient.URL())
	stream, err := client.WatchMempoolTransactions()
	if err != nil {
		reportError(err)
		return
	}

	fmt.Println("Connected to utxorpc host, watching mempool...")
	for stream.Receive() {
		resp := stream.Msg()
		fmt.Printf("Stream response: %+v\n", resp)
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

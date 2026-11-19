// This example shows how to implement a webhook endpoint for receiving Blockfrost Webhook requests
// https://blockfrost.dev/start-building/webhooks/
// Run using: go run example/webhook/main.go
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"

	"github.com/blockfrost/blockfrost-go"
)

const SECRET_AUTH_TOKEN string = "dc8f4b23-6c44-405f-8940-5d451222458e"

func main() {
	http.HandleFunc("/webhook", func(w http.ResponseWriter, req *http.Request) {
		const MaxBodyBytes = int64(524288)
		req.Body = http.MaxBytesReader(w, req.Body, MaxBodyBytes)
		payload, err := io.ReadAll(req.Body)

		fmt.Printf("Received webhook request.\n")

		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading request body: %v\n", err)
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}

		event, err := blockfrost.VerifyWebhookSignature(payload, req.Header.Get("Blockfrost-Signature"), SECRET_AUTH_TOKEN)

		if err != nil {
			fmt.Fprintf(os.Stderr, "Error verifying webhook signature: %v\n", err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		// Unmarshal the event data into an appropriate struct depending on its Type
		switch event.Type {
		case "block":
			var blockEvent blockfrost.WebhookEventBlock
			err := json.Unmarshal(payload, &blockEvent)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error parsing webhook JSON: %v\n", err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			fmt.Printf("Received block event: %v\n", blockEvent)
		case "transaction":
			var transactionEvent blockfrost.WebhookEventTransaction
			err := json.Unmarshal(payload, &transactionEvent)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error parsing webhook JSON: %v\n", err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			fmt.Printf("Received tx event: %v\n", transactionEvent)
		case "epoch":
			var epochEvent blockfrost.WebhookEventEpoch
			err := json.Unmarshal(payload, &epochEvent)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error parsing webhook JSON: %v\n", err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			fmt.Printf("Received epoch event: %v\n", epochEvent)
		case "delegation":
			var delegationEvent blockfrost.WebhookEventDelegation
			err := json.Unmarshal(payload, &delegationEvent)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error parsing webhook JSON: %v\n", err)
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			fmt.Printf("Received delegation event: %v\n", delegationEvent)
		default:
			fmt.Fprintf(os.Stderr, "Unhandled webhook type: %s\n", event.Type)
		}

		w.WriteHeader(http.StatusOK)
	})

	fmt.Println("Server is starting on port 8080...")

	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Server failed to start: %v\n", err)
	}
}

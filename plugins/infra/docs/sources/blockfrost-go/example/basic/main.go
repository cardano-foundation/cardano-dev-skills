// A basic example of how to initialize and get info from Blockfrost API
// using the SDK.
// Run using:
// 		go run main.go
//
// You'll need a valid project_id from blockfrost.io
// This example fetches project_id from env:BLOCKFROST_IPFS_PROJECT_ID
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/blockfrost/blockfrost-go"
)

func main() {
	api := blockfrost.NewAPIClient(
		blockfrost.APIClientOptions{}, // Add ProjectID or exclude to load from env:BLOCKFROST_PROJECT_ID
	)

	info, err := api.Info(context.TODO())
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("API Info:\n\tUrl: %s\n\tVersion: %s", info.Url, info.Version)
}

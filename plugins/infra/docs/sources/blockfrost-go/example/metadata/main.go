// Example script introducing usage of query params for pagination
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

	q := blockfrost.APIQueryParams{}
	m, err := api.MetadataTxLabels(context.TODO(), q)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%+v", m)
}

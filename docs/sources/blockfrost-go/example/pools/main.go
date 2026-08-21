// Fetch pool history from a poolId and print to console
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
	poolID := "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy"

	api := blockfrost.NewAPIClient(
		blockfrost.APIClientOptions{}, // Add ProjectID or exclude to load from env:BLOCKFROST_PROJECT_ID
	)

	q := blockfrost.APIQueryParams{}

	pool, err := api.PoolHistory(context.TODO(), poolID, q)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%+v", pool)
}

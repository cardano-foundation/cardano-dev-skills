// Example showing how to get genesis block
// Run it using
//
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
	api := blockfrost.NewAPIClient(blockfrost.APIClientOptions{})

	gen, err := api.Genesis(context.TODO())
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Genesis Block: \n \t%+v", gen)
}

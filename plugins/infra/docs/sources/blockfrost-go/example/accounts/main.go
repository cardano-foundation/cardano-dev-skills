package main

import (
	"context"
	"fmt"
	"log"

	"github.com/blockfrost/blockfrost-go"
)

func main() {
	stakeAddress := "stake1ux3g2c9dx2nhhehyrezyxpkstartcqmu9hk63qgfkccw5rqttygt7"

	api := blockfrost.NewAPIClient(
		blockfrost.APIClientOptions{}, // Add ProjectID or exclude to load from env:BLOCKFROST_PROJECT_ID
	)

	acc, err := api.Account(context.TODO(), stakeAddress)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("%+v", acc)
}

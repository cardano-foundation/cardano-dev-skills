package main

import (
	"context"
	"log"

	"github.com/blockfrost/blockfrost-go"
)

func main() {
	api := blockfrost.NewAPIClient(blockfrost.APIClientOptions{})

	addr := "addr1qxqs59lphg8g6qndelq8xwqn60ag3aeyfcp33c2kdp46a09re5df3pzwwmyq946axfcejy5n4x0y99wqpgtp2gd0k09qsgy6pz"
	details, err := api.AddressDetails(context.TODO(), addr)
	if err != nil {
		log.Fatal(err)
	}

	log.Println(details)
}

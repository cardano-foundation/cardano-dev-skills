package main

import (
	"context"
	"fmt"
	"log"

	"github.com/blockfrost/blockfrost-go"
)

func main() {
	api := blockfrost.NewAPIClient(blockfrost.APIClientOptions{})

	scripts, err := api.Scripts(context.TODO(), blockfrost.APIQueryParams{})
	if err != nil {
		log.Fatal(err)
	}
	if len(scripts) == 0 {
		return
	}

	addr := scripts[0].ScriptHash

	script, err := api.Script(context.TODO(), addr)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Script: %+v\n", script)
}

package main

import (
	"context"
	"fmt"
	"log"

	"github.com/blockfrost/blockfrost-go"
)

func main() {
	api := blockfrost.NewAPIClient(blockfrost.APIClientOptions{})

	addr := "addr1q85yx2w7ragn5sx6umgmtjpc3865s9sg59sz4rrh6f90kgwfwlzu3w8ttacqg89mkdgwshwnplj5c5n9f8dhp0h55q2q7qm63t"
	meta, err := api.Nutlink(context.TODO(), addr)
	if err != nil {
		log.Fatal(err)
	}

	tickers, err := api.Tickers(context.TODO(), addr, blockfrost.APIQueryParams{})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Meta: \n\tAddress: %s\n\tURL: %s\n", meta.Address, meta.MetadataUrl)

	if len(tickers) == 0 {
		return
	}
	fmt.Printf("\nTickers(%d): \n\t%+v\n\t...", len(tickers), tickers[0])

	adtickers, err := api.AddressTickerRecords(
		context.TODO(), addr, tickers[0].Name, blockfrost.APIQueryParams{},
	)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("\nAddress Tickers (%d): \n\t%s : %+v\n\t...", len(adtickers), tickers[0].Name, adtickers[0])
}

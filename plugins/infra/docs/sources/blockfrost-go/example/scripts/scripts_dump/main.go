// This example gets and dumps scripts to csv file utilising ScriptsAll Method
// Run it using
//
// 		go run main.go -file scripts.csv
//
// You'll need a valid project_id from blockfrost.io
// This example fetches project_id from env:BLOCKFROST_IPFS_PROJECT_ID

package main

import (
	"context"
	"encoding/csv"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/blockfrost/blockfrost-go"
)

var (
	fp = flag.String("file", "", "path to export csv")
)

func handleError(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	flag.Parse()

	api := blockfrost.NewAPIClient(blockfrost.APIClientOptions{})
	file, err := os.Create(*fp)
	handleError(err)

	wr := csv.NewWriter(file)
	defer wr.Flush()

	err = wr.Write([]string{"batch_id", "script_hash"})
	handleError(err)

	for r := range api.ScriptsAll(context.TODO()) {
		for k, v := range r.Res {
			arr := []string{fmt.Sprintf("%d", k), v.ScriptHash}
			err := wr.Write(arr)
			handleError(err)
		}
	}
}

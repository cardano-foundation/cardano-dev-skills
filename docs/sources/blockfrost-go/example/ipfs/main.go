// Add and Pin file using the IPFS client
// Run it using
//
// 		go run main.go -file blockfrost.txt
//
// You'll need a valid project_id from blockfrost.io
// This example fetches project_id from env:BLOCKFROST_IPFS_PROJECT_ID

package main

import (
	"context"
	"flag"
	"fmt"
	"log"

	"github.com/blockfrost/blockfrost-go"
)

var (
	fp = flag.String("file", "", "Path to file")
)

func main() {
	flag.Parse()
	ipfs := blockfrost.NewIPFSClient(blockfrost.IPFSClientOptions{})

	ipo, err := ipfs.Add(context.TODO(), *fp)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("IPFS Object: %+v\n", ipo)

	pin, err := ipfs.Pin(context.TODO(), ipo.IPFSHash)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Pin: %+v", pin)
}

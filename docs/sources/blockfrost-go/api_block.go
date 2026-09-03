package blockfrost

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sync"
)

const (
	resourceBlocksAffectedAddresses = "addresses"
)

// Block defines content of a block
type Block struct {
	// Block creation time in UNIX time
	Time int `json:"time"`

	// Block number
	Height int `json:"height"`

	// Hash of the block
	Hash string `json:"hash"`

	// Slot number
	Slot int `json:"slot"`

	// Epoch number
	Epoch int `json:"epoch"`

	// Slot within the epoch
	EpochSlot int `json:"epoch_slot"`

	// Bech32 ID of the slot leader or specific block description in case there is no slot leader
	SlotLeader string `json:"slot_leader"`

	// Block size in Bytes
	Size int `json:"size"`

	// Number of transactions in the block
	TxCount int `json:"tx_count"`

	// Total output within the block in Lovelaces
	Output *string `json:"output"`

	// Total fees within the block in Lovelaces
	Fees *string `json:"fees"`

	// VRF key of the block
	BlockVRF *string `json:"block_vrf"`

	// The hash of the operational certificate of the block producer
	OPCert *string `json:"op_cert,omitempty"` // omitempty due to webhook test fixtures

	// The value of the counter used to produce the operational certificate
	OPCertCounter *string `json:"op_cert_counter,omitempty"` // omitempty due to webhook test fixtures

	// Hash of the previous block
	PreviousBlock string `json:"previous_block"`

	// Hash of the next block
	NextBlock *string `json:"next_block"`

	// Number of block confirmations
	Confirmations int `json:"confirmations"`
}

type BlockAffectedAddresses struct {
	Address      string `json:"address"`
	Transactions []struct {
		TxHash string `json:"tx_hash"`
	} `json:"transactions"`
}

type BlockAffectedAddressesResult struct {
	Res []BlockAffectedAddresses
	Err error
}

type BlockTransactionResult struct {
	Res []Transaction
	Err error
}

// BlocksLatest Return the latest block available to the backends, also known as the
// tip of the blockchain.
func (c *apiClient) BlockLatest(ctx context.Context) (b Block, err error) {
	requestUrl, err := url.Parse((fmt.Sprintf("%s/%s", c.server, resourceBlocksLatest)))
	if err != nil {
		return
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	err = json.NewDecoder(res.Body).Decode(&b)
	if err != nil {
		return
	}
	return b, nil
}

// Block returns the content of a requested block by the hash or block number
func (c *apiClient) Block(ctx context.Context, hashOrNumber string) (bl Block, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceBlock, hashOrNumber))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&bl); err != nil {
		return
	}
	return bl, nil
}

// BlocksNext returns the list of blocks following a specific block
// denoted by the hash or block number
func (c *apiClient) BlocksNext(ctx context.Context, hashorNumber string) (bls []Block, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceBlock, hashorNumber, "next"))
	if err != nil {
		return
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&bls); err != nil {
		return
	}
	return bls, nil
}

// BlocksPrevious returns the list of blocks preceding a specific block
// specified by a hash or block number
func (c *apiClient) BlocksPrevious(ctx context.Context, hashorNumber string) (bls []Block, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceBlock, hashorNumber, "previous"))
	if err != nil {
		return
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&bls); err != nil {
		return
	}
	return bls, nil
}

// BlocksTransactions returns slice of Transaction within the block specified
// by a hash or block number
func (c *apiClient) BlockTransactions(ctx context.Context, hashOrNumber string, query APIQueryParams) (txs []Transaction, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceBlock, hashOrNumber, "txs"))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	v := req.URL.Query()
	v = formatParams(v, query)
	req.URL.RawQuery = v.Encode()

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	err = json.NewDecoder(res.Body).Decode(&txs)
	if err != nil {
		return
	}
	return txs, nil
}

// BlockLatestTransactions returns the transactions within the latest block.
func (c *apiClient) BlockLatestTransactions(ctx context.Context, query APIQueryParams) (txs []Transaction, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceBlocksLatestTransactions))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	v := req.URL.Query()
	v = formatParams(v, query)
	req.URL.RawQuery = v.Encode()

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&txs); err != nil {
		return
	}
	return txs, nil
}

// BlocksBySlot returns the content of a requested block for a specific slot.
func (c *apiClient) BlockBySlot(ctx context.Context, slotNumber int) (bl Block, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%d", c.server, resourceBlocksSlot, slotNumber))
	if err != nil {
		return
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	err = json.NewDecoder(res.Body).Decode(&bl)
	if err != nil {
		return
	}
	return bl, nil

}

// BlocksBySlotAndEpoch returns a Block for a specific slot and epoch
func (c *apiClient) BlocksBySlotAndEpoch(ctx context.Context, slotNumber int, epochNumber int) (bl Block, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%d/%s/%d", c.server, "blocks", "epoch", epochNumber, "slot", slotNumber))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	err = json.NewDecoder(res.Body).Decode(&bl)
	if err != nil {
		return
	}
	return bl, nil
}

// BlocksAddresses returns list of addresses affected in the specified block with additional information
func (c *apiClient) BlocksAddresses(ctx context.Context, hashOrNumber string, query APIQueryParams) (txs []BlockAffectedAddresses, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceBlock, hashOrNumber, resourceBlocksAffectedAddresses))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	v := req.URL.Query()
	v = formatParams(v, query)
	req.URL.RawQuery = v.Encode()

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&txs); err != nil {
		return
	}
	return txs, nil
}

func (c *apiClient) BlocksAddressesAll(ctx context.Context, hashOrNumber string) <-chan BlockAffectedAddressesResult {
	ch := make(chan BlockAffectedAddressesResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan BlockAffectedAddressesResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				affectedAddresses, err := c.BlocksAddresses(j.ctx, hashOrNumber, j.query)
				if len(affectedAddresses) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := BlockAffectedAddressesResult{Res: affectedAddresses, Err: err}
				ch <- res
			}

		}(jobs, ch, &wg)
	}
	go func() {
		defer close(ch)
		fetchNextPage := true
		for i := 1; fetchNextPage; i++ {
			select {
			case <-quit:
				fetchNextPage = false
			default:
				jobs <- methodOptions{ctx: ctx, query: APIQueryParams{Count: 100, Page: i}}
			}
		}

		close(jobs)
		wg.Wait()
	}()
	return ch
}

// BlockTransactionsAll returns all transactions within the block specified
// by a hash or block number.
func (c *apiClient) BlockTransactionsAll(ctx context.Context, hashOrNumber string) <-chan BlockTransactionResult {
	ch := make(chan BlockTransactionResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan BlockTransactionResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				txs, err := c.BlockTransactions(j.ctx, hashOrNumber, j.query)
				if len(txs) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := BlockTransactionResult{Res: txs, Err: err}
				ch <- res
			}

		}(jobs, ch, &wg)
	}
	go func() {
		defer close(ch)
		fetchNextPage := true
		for i := 1; fetchNextPage; i++ {
			select {
			case <-quit:
				fetchNextPage = false
			default:
				jobs <- methodOptions{ctx: ctx, query: APIQueryParams{Count: 100, Page: i}}
			}
		}

		close(jobs)
		wg.Wait()
	}()
	return ch
}

// BlockLatestTransactionsAll returns all transactions within the latest block.
func (c *apiClient) BlockLatestTransactionsAll(ctx context.Context) <-chan BlockTransactionResult {
	ch := make(chan BlockTransactionResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan BlockTransactionResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				txs, err := c.BlockLatestTransactions(j.ctx, j.query)
				if len(txs) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := BlockTransactionResult{Res: txs, Err: err}
				ch <- res
			}

		}(jobs, ch, &wg)
	}
	go func() {
		defer close(ch)
		fetchNextPage := true
		for i := 1; fetchNextPage; i++ {
			select {
			case <-quit:
				fetchNextPage = false
			default:
				jobs <- methodOptions{ctx: ctx, query: APIQueryParams{Count: 100, Page: i}}
			}
		}

		close(jobs)
		wg.Wait()
	}()
	return ch
}

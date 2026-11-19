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
	resourceAddresses    = "addresses"
	resourceTotal        = "total"
	resourceTransactions = "transactions"
	resourceUTXOs        = "utxos"
	resourceExtended     = "extended"
)

type AddressAmount struct {
	Unit     string `json:"unit"`
	Quantity string `json:"quantity"`
}

type AddressAmountExtended struct {
	Unit                  string `json:"unit"`
	Quantity              string `json:"quantity"`
	Decimals              *int   `json:"decimals"`
	HasNftOnchainMetadata bool   `json:"has_nft_onchain_metadata"`
}

type Address struct {
	// Bech32 encoded addresses
	Address string          `json:"address"`
	Amount  []AddressAmount `json:"amount"`

	// Stake address that controls the key
	StakeAddress *string `json:"stake_address"`

	// Address era.
	// Enum: "byron" "shelley"
	Type string `json:"type"`

	// True if this is a script address
	Script bool `json:"script"`
}

type AddressDetails struct {
	// Bech32 encoded address
	Address     string          `json:"address"`
	ReceivedSum []AddressAmount `json:"received_sum"`
	SentSum     []AddressAmount `json:"sent_sum"`

	// Count of all transactions on the address
	TxCount int `json:"tx_count"`
}

type AddressExtended struct {
	// Bech32 encoded addresses
	Address string                  `json:"address"`
	Amount  []AddressAmountExtended `json:"amount"`

	// Stake address that controls the key
	StakeAddress *string `json:"stake_address"`

	// Address era.
	// Enum: "byron" "shelley"
	Type string `json:"type"`

	// True if this is a script address
	Script bool `json:"script"`
}

type AddressTransactions struct {
	// Hash of the transaction
	TxHash string `json:"tx_hash"`

	// Transaction index within the block
	TxIndex int `json:"tx_index"`

	// Block height
	BlockHeight int `json:"block_height"`

	// Block Time (Unix time)
	BlockTime int `json:"block_time"`
}

type AddressUTXO struct {
	Address string `json:"address"`
	// Transaction hash of the UTXO
	TxHash string `json:"tx_hash"`

	// UTXO index in the transaction
	OutputIndex int             `json:"output_index"`
	Amount      []AddressAmount `json:"amount"`

	// Block hash of the UTXO
	Block string `json:"block"`

	// The hash of the transaction output datum
	DataHash *string `json:"data_hash"`

	InlineDatum         *string `json:"inline_datum"`
	ReferenceScriptHash *string `json:"reference_script_hash"`
}

type AddressTxResult struct {
	Res []AddressTransactions
	Err error
}

type AddressUTXOResult struct {
	Res []AddressUTXO
	Err error
}

// Address ret
func (c *apiClient) Address(ctx context.Context, address string) (addr Address, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceAddresses, address))
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

	if err = json.NewDecoder(res.Body).Decode(&addr); err != nil {
		return
	}
	return addr, nil
}

func (c *apiClient) AddressTransactions(ctx context.Context, address string, query APIQueryParams) (txs []AddressTransactions, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAddresses, address, resourceTransactions))
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

func (c *apiClient) AddressTransactionsAll(ctx context.Context, address string) <-chan AddressTxResult {
	ch := make(chan AddressTxResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AddressTxResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				atx, err := c.AddressTransactions(j.ctx, address, j.query)
				if len(atx) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AddressTxResult{Res: atx, Err: err}
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

func (c *apiClient) AddressDetails(ctx context.Context, address string) (ad AddressDetails, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAddresses, address, resourceTotal))
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

	if err = json.NewDecoder(res.Body).Decode(&ad); err != nil {
		return
	}
	return ad, nil
}

func (c *apiClient) AddressUTXOs(ctx context.Context, address string, query APIQueryParams) (utxos []AddressUTXO, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAddresses, address, resourceUTXOs))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	v := req.URL.Query()
	query.From = ""
	query.To = ""
	v = formatParams(v, query)
	req.URL.RawQuery = v.Encode()

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&utxos); err != nil {
		return
	}
	return utxos, nil
}

func (c *apiClient) AddressUTXOsAll(ctx context.Context, address string) <-chan AddressUTXOResult {
	ch := make(chan AddressUTXOResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AddressUTXOResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				autxo, err := c.AddressUTXOs(j.ctx, address, j.query)
				if len(autxo) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AddressUTXOResult{Res: autxo, Err: err}
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

func (c *apiClient) AddressUTXOsAsset(ctx context.Context, address, asset string, query APIQueryParams) (utxos []AddressUTXO, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s/%s", c.server, resourceAddresses, address, resourceUTXOs, asset))
	if err != nil {
		return
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}
	v := req.URL.Query()
	query.From = ""
	query.To = ""
	v = formatParams(v, query)
	req.URL.RawQuery = v.Encode()

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&utxos); err != nil {
		return
	}
	return utxos, nil
}

func (c *apiClient) AddressUTXOsAssetAll(ctx context.Context, address, asset string) <-chan AddressUTXOResult {
	ch := make(chan AddressUTXOResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AddressUTXOResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				autxo, err := c.AddressUTXOsAsset(j.ctx, address, asset, j.query)
				if len(autxo) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AddressUTXOResult{Res: autxo, Err: err}
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

func (c *apiClient) AddressExtended(ctx context.Context, address string) (addrExtended AddressExtended, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAddresses, address, resourceExtended))
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

	if err = json.NewDecoder(res.Body).Decode(&addrExtended); err != nil {
		return
	}
	return addrExtended, nil
}

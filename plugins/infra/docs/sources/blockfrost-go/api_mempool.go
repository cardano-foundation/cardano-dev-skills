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
	resourceMempool          = "mempool"
	resourceMempoolAddresses = "addresses"
)

type Mempool struct {
	TxHash string `json:"tx_hash"`
}

type MempoolTransaction struct {
	// Count of asset mints and burns within the transaction
	AssetMintOrBurnCount int `json:"asset_mint_or_burn_count"`

	// Count of the delegations within the transaction
	DelegationCount int `json:"delegation_count"`

	// Deposit within the transaction in Lovelaces
	Deposit string `json:"deposit"`

	// Fees of the transaction in Lovelaces
	Fees string `json:"fees"`

	// Transaction hash
	Hash string `json:"hash"`

	// Left (included) endpoint of the timelock validity intervals
	InvalidBefore *string `json:"invalid_before"`

	// Right (excluded) endpoint of the timelock validity intervals
	InvalidHereafter *string `json:"invalid_hereafter"`

	// Count of the MIR certificates within the transaction
	MirCertCount int `json:"mir_cert_count"`
	OutputAmount []struct {
		// The quantity of the unit
		Quantity string `json:"quantity"`

		// The unit of the value
		Unit string `json:"unit"`
	} `json:"output_amount"`

	// Count of the stake pool retirement certificates within the transaction
	PoolRetireCount int `json:"pool_retire_count"`

	// Count of the stake pool registration and update certificates within the transaction
	PoolUpdateCount int `json:"pool_update_count"`

	// Count of redeemers within the transaction
	RedeemerCount int `json:"redeemer_count"`

	// Size of the transaction in Bytes
	Size int `json:"size"`

	// Count of the stake keys (de)registration and delegation certificates within the transaction
	StakeCertCount int `json:"stake_cert_count"`

	// Count of UTXOs within the transaction
	UtxoCount int `json:"utxo_count"`

	// Script passed validation
	ValidContract bool `json:"valid_contract"`

	// Count of the withdrawals within the transaction
	WithdrawalCount int `json:"withdrawal_count"`
}

type MempoolTransactionOutput struct {
	// Output address
	Address             string     `json:"address"`
	Amount              []TxAmount `json:"amount"`
	OutputIndex         int        `json:"output_index"`
	DataHash            *string    `json:"data_hash"`
	InlineDatum         *string    `json:"inline_datum"`
	Collateral          bool       `json:"collateral"`
	ReferenceScriptHash *string    `json:"reference_script_hash"`
}
type MempoolTransactionInput struct {
	Address     string  `json:"address"`
	OutputIndex float32 `json:"output_index"`
	TxHash      string  `json:"tx_hash"`
	Collateral  bool    `json:"collateral"`
	Reference   bool    `json:"reference"`
}

type MempoolTransactionRedeemers struct {
	TxIndex   int    `json:"tx_index"`
	Purpose   string `json:"purpose"`
	UnitMem   string `json:"unit_mem"`
	UnitSteps string `json:"unit_steps"`
}

type MempoolTransactionContent struct {
	Tx        MempoolTransaction            `json:"tx"`
	Inputs    []MempoolTransactionInput     `json:"inputs"`
	Outputs   []MempoolTransactionOutput    `json:"outputs"`
	Redeemers []MempoolTransactionRedeemers `json:"redeemers"`
}

type MempoolResult struct {
	Res []Mempool
	Err error
}

func (c *apiClient) Mempool(ctx context.Context, query APIQueryParams) (a []Mempool, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceMempool))
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

	if err = json.NewDecoder(res.Body).Decode(&a); err != nil {
		return
	}
	return a, nil
}

// AssetsAll returns all assets.
func (c *apiClient) MempoolAll(ctx context.Context) <-chan MempoolResult {
	ch := make(chan MempoolResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan MempoolResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				mempool, err := c.Mempool(j.ctx, j.query)
				if len(mempool) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := MempoolResult{Res: mempool, Err: err}
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

func (c *apiClient) MempoolTx(ctx context.Context, hash string) (tc MempoolTransactionContent, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceMempool, hash))
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
	if err = json.NewDecoder(res.Body).Decode(&tc); err != nil {
		return
	}
	return tc, nil
}

func (c *apiClient) MempoolByAddress(ctx context.Context, address string, query APIQueryParams) (a []Mempool, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceMempool, resourceMempoolAddresses, address))
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

	if err = json.NewDecoder(res.Body).Decode(&a); err != nil {
		return
	}
	return a, nil
}

// AssetsAll returns all assets.
func (c *apiClient) MempoolByAddressAll(ctx context.Context, address string) <-chan MempoolResult {
	ch := make(chan MempoolResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan MempoolResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				mempool, err := c.MempoolByAddress(j.ctx, address, j.query)
				if len(mempool) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := MempoolResult{Res: mempool, Err: err}
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

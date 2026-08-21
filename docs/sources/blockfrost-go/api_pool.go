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
	resourcePool          = "pools"
	resourcePoolRetired   = "pools/retired"
	resourcePoolRetiring  = "pools/retiring"
	resourcePoolHistory   = "history"
	resourcePoolMetadata  = "metadata"
	resourcePoolRelay     = "relays"
	resourcePoolDelegator = "delegators"
	resourcePoolBlocks    = "blocks"
	resourcePoolUpdate    = "updates"
	resourcePoolExtended  = "pools/extended"
)

// List of stake pools
// List of registered stake pools.
type Pools []string

// List of retired stake pools
// List of already retired pools.
type PoolRetired struct {
	PoolID string `json:"pool_id"`
	Epoch  int    `json:"epoch"`
}

type PoolRetiring struct {
	PoolID string `json:"pool_id"`
	Epoch  int    `json:"epoch"`
}

// Pool information.
type Pool struct {
	PoolID         string      `json:"pool_id"`
	Hex            string      `json:"hex"`
	VrfKey         string      `json:"vrf_key"`
	BlocksMinted   int         `json:"blocks_minted"`
	LiveStake      string      `json:"live_stake"`
	LiveSize       float64     `json:"live_size"`
	LiveSaturation float64     `json:"live_saturation"`
	LiveDelegators int         `json:"live_delegators"`
	ActiveStake    string      `json:"active_stake"`
	ActiveSize     float64     `json:"active_size"`
	DeclaredPledge string      `json:"declared_pledge"`
	LivePledge     string      `json:"live_pledge"`
	MarginCost     float64     `json:"margin_cost"`
	FixedCost      string      `json:"fixed_cost"`
	RewardAccount  string      `json:"reward_account"`
	Owners         []string    `json:"owners"`
	Registration   []string    `json:"registration"`
	Retirement     []string    `json:"retirement"`
	CalidusKey     *CalidusKey `json:"calidus_key"`
}

type CalidusKey struct {
	ID          string `json:"id"`
	PubKey      string `json:"pub_key"`
	Nonce       int    `json:"nonce"`
	TxHash      string `json:"tx_hash"`
	BlockHeight int    `json:"block_height"`
	BlockTime   int    `json:"block_time"`
	Epoch       int    `json:"epoch"`
}

// PoolHistory return Stake pool history
// History of stake pool parameters over epochs.
type PoolHistory struct {
	Epoch           int     `json:"epoch"`
	Blocks          int     `json:"blocks"`
	ActiveStake     string  `json:"active_stake"`
	ActiveSize      float64 `json:"active_size"`
	DelegatorsCount int     `json:"delegators_count"`
	Rewards         string  `json:"rewards"`
	Fees            string  `json:"fees"`
}

// PoolMetadata return Stake pool metadata
// Stake pool registration metadata.
type PoolMetadata struct {
	PoolID      string         `json:"pool_id"`
	Hex         string         `json:"hex"`
	URL         *string        `json:"url"`
	Hash        *string        `json:"hash"`
	Ticker      *string        `json:"ticker"`
	Name        *string        `json:"name"`
	Description *string        `json:"description"`
	Homepage    *string        `json:"homepage"`
	Error       *MetadataError `json:"error"`
}

type MetadataError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// PoolRelay return Stake pool relays
// Relays of a stake pool.
type PoolRelay struct {
	Ipv4   *string `json:"ipv4"`
	Ipv6   *string `json:"ipv6"`
	DNS    *string `json:"dns"`
	DNSSrv *string `json:"dns_srv"`
	Port   int     `json:"port"`
}

// PoolDelegator return Stake pool delegators
// List of current stake pools delegators.
type PoolDelegator struct {
	Address   string `json:"address"`
	LiveStake string `json:"live_stake"`
}

// PoolBlocks return Stake pool blocks
// List of stake pools blocks.
type PoolBlocks []string

// PoolUpdate return Stake pool updates
// List of certificate updates to the stake pool.
type PoolUpdate struct {
	TxHash    string `json:"tx_hash"`
	CERTIndex int    `json:"cert_index"`
	Action    string `json:"action"`
}

type PoolsResult struct {
	Res Pools
	Err error
}

type PoolsRetiredResult struct {
	Res []PoolRetired
	Err error
}

type PoolsRetiringResult struct {
	Res []PoolRetiring
	Err error
}

type PoolHistoryResult struct {
	Res []PoolHistory
	Err error
}

type PoolDelegatorsResult struct {
	Res []PoolDelegator
	Err error
}

type PoolBlocksResult struct {
	Res PoolBlocks
	Err error
}

type PoolUpdateResult struct {
	Res []PoolUpdate
	Err error
}

type PoolExtendedMetadata struct {
	URL         *string        `json:"url"`
	Hash        *string        `json:"hash"`
	Ticker      *string        `json:"ticker"`
	Name        *string        `json:"name"`
	Description *string        `json:"description"`
	Homepage    *string        `json:"homepage"`
	Error       *MetadataError `json:"error"`
}

type PoolExtended struct {
	PoolID         string                `json:"pool_id"`
	Hex            string                `json:"hex"`
	ActiveStake    string                `json:"active_stake"`
	LiveStake      string                `json:"live_stake"`
	LiveSaturation float64               `json:"live_saturation"`
	BlocksMinted   int                   `json:"blocks_minted"`
	MarginCost     float64               `json:"margin_cost"`
	FixedCost      string                `json:"fixed_cost"`
	DeclaredPledge string                `json:"declared_pledge"`
	Metadata       *PoolExtendedMetadata `json:"metadata"`
}

type PoolsExtendedResult struct {
	Res []PoolExtended
	Err error
}

// Pools returns the List of stake pools
// List of registered stake pools.
func (c *apiClient) Pools(ctx context.Context, query APIQueryParams) (ps Pools, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourcePool))
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

	if err = json.NewDecoder(res.Body).Decode(&ps); err != nil {
		return
	}
	return ps, nil
}

func (c *apiClient) PoolsAll(ctx context.Context) <-chan PoolsResult {
	ch := make(chan PoolsResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolsResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.Pools(j.ctx, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolsResult{Res: pools, Err: err}
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

// PoolsRetired returns the List of retired stake pools
// List of already retired pools.
func (c *apiClient) PoolsRetired(ctx context.Context, query APIQueryParams) (prs []PoolRetired, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourcePoolRetired))
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

	if err = json.NewDecoder(res.Body).Decode(&prs); err != nil {
		return
	}
	return prs, nil
}

func (c *apiClient) PoolsRetiredAll(ctx context.Context) <-chan PoolsRetiredResult {
	ch := make(chan PoolsRetiredResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolsRetiredResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.PoolsRetired(j.ctx, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolsRetiredResult{Res: pools, Err: err}
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

// PoolsRetiring returns the List of retiring stake pools
// List of stake pools retiring in the upcoming epochs
func (c *apiClient) PoolsRetiring(ctx context.Context, query APIQueryParams) (pr []PoolRetiring, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourcePoolRetiring))
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

	if err = json.NewDecoder(res.Body).Decode(&pr); err != nil {
		return
	}

	return pr, nil
}

func (c *apiClient) PoolsRetiringAll(ctx context.Context) <-chan PoolsRetiringResult {
	ch := make(chan PoolsRetiringResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolsRetiringResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.PoolsRetiring(j.ctx, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolsRetiringResult{Res: pools, Err: err}
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

// Pool returns the Specific Stake Pool
func (c *apiClient) Pool(ctx context.Context, poolID string) (pool Pool, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourcePool, poolID))
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
	if err = json.NewDecoder(res.Body).Decode(&pool); err != nil {
		return
	}
	return pool, nil
}

// PoolHistory returns the Stake pool history
// History of stake pool parameters over epochs.
func (c *apiClient) PoolHistory(ctx context.Context, poolID string, query APIQueryParams) (ph []PoolHistory, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourcePool, poolID, resourcePoolHistory))
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

	if err = json.NewDecoder(res.Body).Decode(&ph); err != nil {
		return
	}
	return ph, nil
}

func (c *apiClient) PoolHistoryAll(ctx context.Context, poolId string) <-chan PoolHistoryResult {
	ch := make(chan PoolHistoryResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolHistoryResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.PoolHistory(j.ctx, poolId, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolHistoryResult{Res: pools, Err: err}
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

// PoolMetadata returns the Stake pool metadata
// Stake pool registration metadata.
func (c *apiClient) PoolMetadata(ctx context.Context, poolID string) (pm PoolMetadata, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourcePool, poolID, resourcePoolMetadata))
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
	if err = json.NewDecoder(res.Body).Decode(&pm); err != nil {
		return
	}
	return pm, nil
}

// PoolRelay returns the Stake pool relays
// Relays of a stake pool.
func (c *apiClient) PoolRelays(ctx context.Context, poolID string) (prs []PoolRelay, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourcePool, poolID, resourcePoolRelay))
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

	if err = json.NewDecoder(res.Body).Decode(&prs); err != nil {
		return
	}
	return prs, nil
}

// PoolDelegator returns the Stake pool delegators
// List of current stake pools delegators.
func (c *apiClient) PoolDelegators(ctx context.Context, poolID string, query APIQueryParams) (pd []PoolDelegator, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourcePool, poolID, resourcePoolDelegator))
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

	if err = json.NewDecoder(res.Body).Decode(&pd); err != nil {
		return
	}
	return pd, nil
}

func (c *apiClient) PoolDelegatorsAll(ctx context.Context, poolId string) <-chan PoolDelegatorsResult {
	ch := make(chan PoolDelegatorsResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolDelegatorsResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.PoolDelegators(j.ctx, poolId, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolDelegatorsResult{Res: pools, Err: err}
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

// PoolBlocks returns the Stake pool blocks
// List of stake pools blocks.
func (c *apiClient) PoolBlocks(ctx context.Context, poolID string, query APIQueryParams) (pb PoolBlocks, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourcePool, poolID, resourcePoolBlocks))
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

	if err = json.NewDecoder(res.Body).Decode(&pb); err != nil {
		return
	}
	return pb, nil
}

func (c *apiClient) PoolBlocksAll(ctx context.Context, poolId string) <-chan PoolBlocksResult {
	ch := make(chan PoolBlocksResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolBlocksResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.PoolBlocks(j.ctx, poolId, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolBlocksResult{Res: pools, Err: err}
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

// PoolUpdate returns the Stake pool updates
// List of certificate updates to the stake pool.
func (c *apiClient) PoolUpdates(ctx context.Context, poolID string, query APIQueryParams) (pu []PoolUpdate, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourcePool, poolID, resourcePoolUpdate))
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

	if err = json.NewDecoder(res.Body).Decode(&pu); err != nil {
		return
	}
	return pu, nil
}

func (c *apiClient) PoolUpdatesAll(ctx context.Context, poolId string) <-chan PoolUpdateResult {
	ch := make(chan PoolUpdateResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolUpdateResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.PoolUpdates(j.ctx, poolId, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolUpdateResult{Res: pools, Err: err}
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

func (c *apiClient) PoolsExtended(ctx context.Context, query APIQueryParams) (pe []PoolExtended, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourcePoolExtended))
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
	if err = json.NewDecoder(res.Body).Decode(&pe); err != nil {
		return
	}
	return pe, nil
}

func (c *apiClient) PoolsExtendedAll(ctx context.Context) <-chan PoolsExtendedResult {
	ch := make(chan PoolsExtendedResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan PoolsExtendedResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				pools, err := c.PoolsExtended(j.ctx, j.query)
				if len(pools) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := PoolsExtendedResult{Res: pools, Err: err}
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

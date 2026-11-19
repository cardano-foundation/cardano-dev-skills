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
	resourceAccount                            = "accounts"
	resourceAccountHistory                     = "history"
	resourceAccountRewardsHistory              = "rewards"
	resourceAccountDelegationHistory           = "delegations"
	resourceAccountRegistrationHistory         = "registrations"
	resourceAccountWithdrawalHistory           = "withdrawals"
	resourceAccountMIRHistory                  = "mirs"
	resourceAccountAssociatedAddress           = "addresses"
	resourceAccountAddressWithAssetsAssociated = "addresses/assets"
	resourceAccountAddressesTotal              = "addresses/total"
	resourceAccountTransactions                = "transactions"
)

// Account return Specific account address
// Obtain information about a specific stake account.
type Account struct {
	// Bech32 stake address
	StakeAddress string `json:"stake_address"`

	// Registration state of an account
	Active bool `json:"active"`

	// Epoch of the most recent action - registration or deregistration
	ActiveEpoch *int64 `json:"active_epoch"`

	// Balance of the account in Lovelaces
	ControlledAmount string `json:"controlled_amount"`

	// Sum of all rewards for the account in the Lovelaces
	RewardsSum string `json:"rewards_sum"`

	// Sum of all the withdrawals for the account in Lovelaces
	WithdrawalsSum string `json:"withdrawals_sum"`

	// Sum of all funds from reserves for the account in the Lovelaces
	ReservesSum string `json:"reserves_sum"`

	// Sum of all funds from treasury for the account in the Lovelaces
	TreasurySum string `json:"treasury_sum"`

	// Sum of available rewards that haven't been withdrawn yet for the account in the Lovelaces
	WithdrawableAmount string `json:"withdrawable_amount"`

	// Bech32 pool ID that owns the account
	PoolID *string `json:"pool_id"`

	// Bech32 DRep ID associated with the account
	DrepID *string `json:"drep_id"`

	// Registration state of an account
	Registered bool `json:"registered"`
}

// AccountRewardsHist return Account reward history
// Obtain information about the reward history of a specific account.
type AccountRewardsHistory struct {
	// Epoch of the associated reward
	Epoch int32 `json:"epoch"`

	// Rewards for given epoch in Lovelaces
	Amount string `json:"amount"`

	// Bech32 pool ID being delegated to
	PoolID string `json:"pool_id"`
}

// AccountHistory return Account history
// Obtain information about the history of a specific account.
type AccountHistory struct {
	// Epoch in which the stake was active
	ActiveEpoch int32 `json:"active_epoch"`

	// Stake amount in Lovelaces
	Amount string `json:"amount"`

	// Bech32 ID of pool being delegated to
	PoolID string `json:"pool_id"`
}

// AccountDelegationHistory return Account delegation history
// Obtain information about the delegation of a specific account.
type AccountDelegationHistory struct {
	// Epoch in which the delegation becomes active
	ActiveEpoch int32 `json:"active_epoch"`

	// Hash of the transaction containing the delegation
	TXHash string `json:"tx_hash"`

	// Rewards for given epoch in Lovelaces
	Amount string `json:"amount"`

	// Bech32 ID of pool being delegated to
	PoolID string `json:"pool_id"`

	// Slot of the transaction
	TxSlot int `json:"tx_slot"`

	// Block time of the transaction
	BlockTime int `json:"block_time"`

	// Block height of the transaction
	BlockHeight int `json:"block_height"`
}

// AccountRegistrationHistory return Account registration history
// Obtain information about the registrations and deregistrations of a specific account.
type AccountRegistrationHistory struct {
	// Hash of the transaction containing the (de)registration certificate
	TXHash string `json:"tx_hash"`

	// Action in the certificate
	// Enum: "registered" "deregistered"
	Action string `json:"action"`

	// Deposit in Lovelaces paid at this registration. Null on deregistration rows.
	Deposit *string `json:"deposit"`

	// Slot of the transaction
	TxSlot int `json:"tx_slot"`

	// Block time of the transaction
	BlockTime int `json:"block_time"`

	// Block height of the transaction
	BlockHeight int `json:"block_height"`
}

// AccountWithdrawalHistory return Account withdrawal history
// Obtain information about the withdrawals of a specific account.
type AccountWithdrawalHistory struct {
	// Hash of the transaction containing the withdrawal
	TXHash string `json:"tx_hash"`

	// Withdrawal amount in Lovelaces
	Amount string `json:"amount"`

	// Slot of the transaction
	TxSlot int `json:"tx_slot"`

	// Block time of the transaction
	BlockTime int `json:"block_time"`

	// Block height of the transaction
	BlockHeight int `json:"block_height"`
}

// AccountMIRHistory return Account MIR history
// Obtain information about the MIRs of a specific account.
type AccountMIRHistory struct {
	// Hash of the transaction containing the MIR
	TXHash string `json:"tx_hash"`

	// MIR amount in Lovelaces
	Amount string `json:"amount"`

	// Slot of the transaction
	TxSlot int `json:"tx_slot"`

	// Block time of the transaction
	BlockTime int `json:"block_time"`

	// Block height of the transaction
	BlockHeight int `json:"block_height"`
}

// AccountAssociatedAddress return Account associated addresses
// Obtain information about the addresses of a specific account.
type AccountAssociatedAddress struct {
	// Address associated with the stake key
	Address string `json:"address"`
}

// AccountAssociatedAsset return Assets associated with the account addresses
// Obtain information about assets associated with addresses of a specific account.
// Be careful, as an account could be part of a mangled address and does not necessarily mean the addresses are owned by user as the account.
type AccountAssociatedAsset struct {
	// The unit of the value.
	// Concatenation of asset policy_id and hex-encoded asset_name
	Unit string `json:"unit"`

	// The quantity of the unit
	Quantity string `json:"quantity"`
}

// AccountAddressesTotal return Account addresses total
// Obtain the total sent and received amounts in all addresses associated with a given account.
type AccountAddressesTotal struct {
	StakeAddress string `json:"stake_address"`
	ReceivedSum  []struct {
		Unit     string `json:"unit"`
		Quantity string `json:"quantity"`
	} `json:"received_sum"`
	SentSum []struct {
		Unit     string `json:"unit"`
		Quantity string `json:"quantity"`
	} `json:"sent_sum"`
	TxCount int `json:"tx_count"`
}

// AccountTransaction return Account transaction
// Obtain transactions associated with a given account.
type AccountTransaction struct {
	TxHash      string `json:"tx_hash"`
	TxIndex     int    `json:"tx_index"`
	BlockHeight int    `json:"block_height"`
	BlockTime   int    `json:"block_time"`
	Address     string `json:"address"`
}

type AccountHistoryResult struct {
	Res []AccountHistory
	Err error
}

type AccountRewardHisResult struct {
	Res []AccountRewardsHistory
	Err error
}

type AccDelegationHistoryResult struct {
	Res []AccountDelegationHistory
	Err error
}

type AccountRegistrationHistoryResult struct {
	Res []AccountRegistrationHistory
	Err error
}

type AccountMIRHistoryResult struct {
	Res []AccountMIRHistory
	Err error
}

type AccountWithdrawalHistoryResult struct {
	Res []AccountWithdrawalHistory
	Err error
}

type AccountAssociatedAddressesAll struct {
	Res []AccountAssociatedAddress
	Err error
}

type AccountAssociatedAssetsAll struct {
	Res []AccountAssociatedAsset
	Err error
}

type AccountTransactionResult struct {
	Res []AccountTransaction
	Err error
}

// Account returns the content of a requested Account by the specific stake account.
func (c *apiClient) Account(ctx context.Context, stakeAddress string) (acc Account, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceAccount, stakeAddress))
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

	if err = json.NewDecoder(res.Body).Decode(&acc); err != nil {
		return
	}
	return acc, nil
}

// AccountRewardsHistory returns the content of a requested Account by the specific stake account.
// Obtain information about the reward history.
func (c *apiClient) AccountRewardsHistory(ctx context.Context, stakeAddress string, query APIQueryParams) (ah []AccountRewardsHistory, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountRewardsHistory))
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

	err = json.NewDecoder(res.Body).Decode(&ah)
	if err != nil {
		return
	}
	return ah, nil
}

func (c *apiClient) AccountRewardsHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountRewardHisResult {
	ch := make(chan AccountRewardHisResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountRewardHisResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				his, err := c.AccountRewardsHistory(j.ctx, stakeAddress, j.query)
				if len(his) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountRewardHisResult{Res: his, Err: err}
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

// AccountHistory returns the content of a requested Account by the specific stake account.
// Obtain information about the history.
func (c *apiClient) AccountHistory(ctx context.Context, stakeAddress string, query APIQueryParams) (ah []AccountHistory, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountHistory))
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

	if err = json.NewDecoder(res.Body).Decode(&ah); err != nil {
		return
	}
	return ah, nil
}

func (c *apiClient) AccountHistoryAll(ctx context.Context, address string) <-chan AccountHistoryResult {
	ch := make(chan AccountHistoryResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountHistoryResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				his, err := c.AccountHistory(j.ctx, address, j.query)
				if len(his) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountHistoryResult{Res: his, Err: err}
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

// AccountDelegationHistory returns the content of a requested Account by the specific stake account.
// Obtain information about the delegations.
func (c *apiClient) AccountDelegationHistory(ctx context.Context, stakeAddress string, query APIQueryParams) (adh []AccountDelegationHistory, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountDelegationHistory))
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

	if err = json.NewDecoder(res.Body).Decode(&adh); err != nil {
		return
	}
	return adh, nil
}

func (c *apiClient) AccountDelegationHistoryAll(ctx context.Context, stakeAddress string) <-chan AccDelegationHistoryResult {
	ch := make(chan AccDelegationHistoryResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccDelegationHistoryResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				his, err := c.AccountDelegationHistory(j.ctx, stakeAddress, j.query)
				if len(his) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccDelegationHistoryResult{Res: his, Err: err}
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

// AccountRegistrationHistory returns the content of a requested Account by the specific stake account.
// Obtain information about the Registrations.
func (c *apiClient) AccountRegistrationHistory(ctx context.Context, stakeAddress string, query APIQueryParams) (arh []AccountRegistrationHistory, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountRegistrationHistory))
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

	if err = json.NewDecoder(res.Body).Decode(&arh); err != nil {
		return
	}
	return arh, nil
}

func (c *apiClient) AccountRegistrationHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountRegistrationHistoryResult {
	ch := make(chan AccountRegistrationHistoryResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountRegistrationHistoryResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				his, err := c.AccountRegistrationHistory(j.ctx, stakeAddress, j.query)
				if len(his) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountRegistrationHistoryResult{Res: his, Err: err}
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

// AccountWithdrawalHistory returns the content of a requested Account by the specific stake account.
// Obtain information about the Withdrawals.
func (c *apiClient) AccountWithdrawalHistory(ctx context.Context, stakeAddress string, query APIQueryParams) (awh []AccountWithdrawalHistory, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountWithdrawalHistory))
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

	if err = json.NewDecoder(res.Body).Decode(&awh); err != nil {
		return
	}
	return awh, nil
}

func (c *apiClient) AccountWithdrawalHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountWithdrawalHistoryResult {
	ch := make(chan AccountWithdrawalHistoryResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountWithdrawalHistoryResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				his, err := c.AccountWithdrawalHistory(j.ctx, stakeAddress, j.query)
				if len(his) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountWithdrawalHistoryResult{Res: his, Err: err}
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

// AccountMIRHistory returns the content of a requested Account by the specific stake account.
// Obtain information about the MIRs.
func (c *apiClient) AccountMIRHistory(ctx context.Context, stakeAddress string, query APIQueryParams) (amh []AccountMIRHistory, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountMIRHistory))
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

	if err = json.NewDecoder(res.Body).Decode(&amh); err != nil {
		return
	}
	return amh, nil
}

func (c *apiClient) AccountMIRHistoryAll(ctx context.Context, stakeAddress string) <-chan AccountMIRHistoryResult {
	ch := make(chan AccountMIRHistoryResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountMIRHistoryResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				his, err := c.AccountMIRHistory(j.ctx, stakeAddress, j.query)
				if len(his) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountMIRHistoryResult{Res: his, Err: err}
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

// AccountAssociatedAddresses returns the content of a requested Account by the specific stake account.
// Obtain information about the addresses of a specific account.
func (c *apiClient) AccountAssociatedAddresses(ctx context.Context, stakeAddress string, query APIQueryParams) (aas []AccountAssociatedAddress, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountAssociatedAddress))
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

	if err = json.NewDecoder(res.Body).Decode(&aas); err != nil {
		return
	}
	return aas, nil
}

func (c *apiClient) AccountAssociatedAddressesAll(ctx context.Context, stakeAddress string) <-chan AccountAssociatedAddressesAll {
	ch := make(chan AccountAssociatedAddressesAll, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountAssociatedAddressesAll, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				addrs, err := c.AccountAssociatedAddresses(j.ctx, stakeAddress, j.query)
				if len(addrs) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountAssociatedAddressesAll{Res: addrs, Err: err}
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

// AccountAssociatedAssets returns the content of a requested Account by the specific stake account.
// Obtain information about the addresses of a specific account.
func (c *apiClient) AccountAssociatedAssets(ctx context.Context, stakeAddress string, query APIQueryParams) (aaa []AccountAssociatedAsset, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountAddressWithAssetsAssociated))
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

	err = json.NewDecoder(res.Body).Decode(&aaa)
	if err != nil {
		return
	}
	return aaa, nil
}

func (c *apiClient) AccountAssociatedAssetsAll(ctx context.Context, stakeAddress string) <-chan AccountAssociatedAssetsAll {
	ch := make(chan AccountAssociatedAssetsAll, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountAssociatedAssetsAll, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				as, err := c.AccountAssociatedAssets(j.ctx, stakeAddress, j.query)
				if len(as) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountAssociatedAssetsAll{Res: as, Err: err}
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

// AccountAddressesTotal returns the content of a requested Account by the specific stake account.
// Obtain information about the total addresses.
func (c *apiClient) AccountAddressesTotal(ctx context.Context, stakeAddress string) (aat AccountAddressesTotal, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountAddressesTotal))
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
	if err = json.NewDecoder(res.Body).Decode(&aat); err != nil {
		return
	}
	return aat, nil
}

// AccountTransactions returns the content of a requested Account by the specific stake account.
// Obtain information about the transactions.
func (c *apiClient) AccountTransactions(ctx context.Context, stakeAddress string, query APIQueryParams) (at []AccountTransaction, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceAccount, stakeAddress, resourceAccountTransactions))
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
	if err = json.NewDecoder(res.Body).Decode(&at); err != nil {
		return
	}
	return at, nil
}

func (c *apiClient) AccountTransactionsAll(ctx context.Context, stakeAddress string) <-chan AccountTransactionResult {
	ch := make(chan AccountTransactionResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan AccountTransactionResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				txs, err := c.AccountTransactions(j.ctx, stakeAddress, j.query)
				if len(txs) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := AccountTransactionResult{Res: txs, Err: err}
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

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
	resourceGovernanceDreps     = "governance/dreps"
	resourceGovernanceCommittee = "governance/committee"
	resourceGovernanceProposals = "governance/proposals"
	resourceDrepDelegators      = "delegators"
	resourceDrepMetadata        = "metadata"
	resourceDrepUpdates         = "updates"
	resourceDrepVotes           = "votes"
	resourceProposalParameters  = "parameters"
	resourceProposalWithdrawals = "withdrawals"
	resourceProposalVotes       = "votes"
	resourceProposalMetadata    = "metadata"
)

type Drep struct {
	DrepID string `json:"drep_id"`
	Hex    string `json:"hex"`

	// The total amount of voting power this DRep is delegated.
	Amount          string `json:"amount"`
	HasScript       bool   `json:"has_script"`
	Retired         bool   `json:"retired"`
	Expired         bool   `json:"expired"`
	LastActiveEpoch *int   `json:"last_active_epoch"`

	// Off-chain metadata associated with the DRep's latest registration.
	// Nil when the DRep has no registration anchor (e.g. drep_always_abstain).
	Metadata *DrepListMetadata `json:"metadata"`
}

// DrepListMetadata is the metadata embedded in /governance/dreps list items.
// It matches DrepMetadata without the drep_id and hex fields.
type DrepListMetadata struct {
	URL          string         `json:"url"`
	Hash         string         `json:"hash"`
	JSONMetadata interface{}    `json:"json_metadata"`
	Bytes        *string        `json:"bytes"`
	Error        *MetadataError `json:"error"`
}

type DrepDetails struct {
	DrepID          string `json:"drep_id"`
	Hex             string `json:"hex"`
	Amount          string `json:"amount"`
	Active          bool   `json:"active"`
	ActiveEpoch     *int   `json:"active_epoch"`
	HasScript       bool   `json:"has_script"`
	Retired         bool   `json:"retired"`
	Expired         bool   `json:"expired"`
	LastActiveEpoch *int   `json:"last_active_epoch"`
}

type DrepMetadata struct {
	DrepID       string         `json:"drep_id"`
	Hex          string         `json:"hex"`
	URL          string         `json:"url"`
	Hash         string         `json:"hash"`
	JSONMetadata interface{}    `json:"json_metadata"`
	Bytes        *string        `json:"bytes"`
	Error        *MetadataError `json:"error"`
}

type DrepDelegator struct {
	Address string `json:"address"`
	Amount  string `json:"amount"`
}

type DrepUpdate struct {
	TxHash    string  `json:"tx_hash"`
	CertIndex int     `json:"cert_index"`
	Action    string  `json:"action"`
	Deposit   *string `json:"deposit"`
}

type DrepVote struct {
	TxHash            string `json:"tx_hash"`
	CertIndex         int    `json:"cert_index"`
	ProposalTxHash    string `json:"proposal_tx_hash"`
	ProposalCertIndex int    `json:"proposal_cert_index"`
	ProposalID        string `json:"proposal_id"`
	Vote              string `json:"vote"`
}

type Proposal struct {
	TxHash         string `json:"tx_hash"`
	CertIndex      int    `json:"cert_index"`
	GovernanceType string `json:"governance_type"`
	ID             string `json:"id"`
}

type ProposalDetails struct {
	TxHash                string                  `json:"tx_hash"`
	CertIndex             int                     `json:"cert_index"`
	GovernanceType        string                  `json:"governance_type"`
	ID                    string                  `json:"id"`
	Deposit               string                  `json:"deposit"`
	ReturnAddress         string                  `json:"return_address"`
	GovernanceDescription *map[string]interface{} `json:"governance_description"`
	RatifiedEpoch         *int                    `json:"ratified_epoch"`
	EnactedEpoch          *int                    `json:"enacted_epoch"`
	DroppedEpoch          *int                    `json:"dropped_epoch"`
	ExpiredEpoch          *int                    `json:"expired_epoch"`
	Expiration            int                     `json:"expiration"`
}

type ProposalParameters struct {
	TxHash     string                 `json:"tx_hash"`
	CertIndex  int                    `json:"cert_index"`
	ID         string                 `json:"id"`
	Parameters map[string]interface{} `json:"parameters"`
}

type ProposalWithdrawal struct {
	StakeAddress string `json:"stake_address"`
	Amount       string `json:"amount"`
}

type ProposalVote struct {
	TxHash    string `json:"tx_hash"`
	CertIndex int    `json:"cert_index"`
	Voter     string `json:"voter"`
	VoterRole string `json:"voter_role"`
	Vote      string `json:"vote"`
}

type ProposalMetadata struct {
	TxHash       string      `json:"tx_hash"`
	CertIndex    int         `json:"cert_index"`
	ID           string      `json:"id"`
	URL          string      `json:"url"`
	Hash         string      `json:"hash"`
	JSONMetadata interface{} `json:"json_metadata"`
	Bytes        string      `json:"bytes"`
}

type ProposalMetadataV2 struct {
	TxHash       string         `json:"tx_hash"`
	CertIndex    int            `json:"cert_index"`
	ID           string         `json:"id"`
	URL          string         `json:"url"`
	Hash         string         `json:"hash"`
	JSONMetadata interface{}    `json:"json_metadata"`
	Bytes        *string        `json:"bytes"`
	Error        *MetadataError `json:"error"`
}

type CommitteeQuorum struct {
	Numerator   int `json:"numerator"`
	Denominator int `json:"denominator"`
}

type CommitteeMember struct {
	CCColdID        string  `json:"cc_cold_id"`
	CCColdHex       string  `json:"cc_cold_hex"`
	CCColdHasScript bool    `json:"cc_cold_has_script"`
	CCHotID         *string `json:"cc_hot_id"`
	CCHotHex        *string `json:"cc_hot_hex"`
	CCHotHasScript  *bool   `json:"cc_hot_has_script"`
	Status          string  `json:"status"`
	ExpirationEpoch int     `json:"expiration_epoch"`
}

type Committee struct {
	GovActionID    *string           `json:"gov_action_id"`
	ProposalTxHash *string           `json:"proposal_tx_hash"`
	ProposalIndex  *int              `json:"proposal_index"`
	IsDissolved    bool              `json:"is_dissolved"`
	Quorum         CommitteeQuorum   `json:"quorum"`
	Members        []CommitteeMember `json:"members"`
}

type CommitteeVote struct {
	TxHash         string  `json:"tx_hash"`
	VoterHotID     string  `json:"voter_hot_id"`
	ProposalID     string  `json:"proposal_id"`
	ProposalTxHash string  `json:"proposal_tx_hash"`
	ProposalIndex  int     `json:"proposal_index"`
	GovernanceType string  `json:"governance_type"`
	Vote           string  `json:"vote"`
	MetadataURL    *string `json:"metadata_url"`
	MetadataHash   *string `json:"metadata_hash"`
	BlockHeight    int     `json:"block_height"`
	BlockTime      int     `json:"block_time"`
}

type CommitteeVoteResult struct {
	Res []CommitteeVote
	Err error
}

type DrepResult struct {
	Res []Drep
	Err error
}

type DrepDelegatorResult struct {
	Res []DrepDelegator
	Err error
}

type DrepUpdateResult struct {
	Res []DrepUpdate
	Err error
}

type DrepVoteResult struct {
	Res []DrepVote
	Err error
}

type ProposalResult struct {
	Res []Proposal
	Err error
}

type ProposalWithdrawalResult struct {
	Res []ProposalWithdrawal
	Err error
}

type ProposalVoteResult struct {
	Res []ProposalVote
	Err error
}

// Committee returns the currently active constitutional committee.
func (c *apiClient) Committee(ctx context.Context) (committee Committee, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceGovernanceCommittee))
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

	if err = json.NewDecoder(res.Body).Decode(&committee); err != nil {
		return
	}
	return committee, nil
}

// CommitteeVotes returns the list of constitutional committee votes.
func (c *apiClient) CommitteeVotes(ctx context.Context, query APIQueryParams) (votes []CommitteeVote, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceGovernanceCommittee, resourceProposalVotes))
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

	if err = json.NewDecoder(res.Body).Decode(&votes); err != nil {
		return
	}
	return votes, nil
}

func (c *apiClient) CommitteeVotesAll(ctx context.Context) <-chan CommitteeVoteResult {
	ch := make(chan CommitteeVoteResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan CommitteeVoteResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				votes, err := c.CommitteeVotes(j.ctx, j.query)
				if len(votes) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := CommitteeVoteResult{Res: votes, Err: err}
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

// CommitteeMemberVotes returns votes cast under a constitutional committee credential.
func (c *apiClient) CommitteeMemberVotes(ctx context.Context, ccID string, query APIQueryParams) (votes []CommitteeVote, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceCommittee, ccID, resourceProposalVotes))
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

	if err = json.NewDecoder(res.Body).Decode(&votes); err != nil {
		return
	}
	return votes, nil
}

func (c *apiClient) CommitteeMemberVotesAll(ctx context.Context, ccID string) <-chan CommitteeVoteResult {
	ch := make(chan CommitteeVoteResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan CommitteeVoteResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				votes, err := c.CommitteeMemberVotes(j.ctx, ccID, j.query)
				if len(votes) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := CommitteeVoteResult{Res: votes, Err: err}
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

// Dreps returns the List of registered DReps.
func (c *apiClient) Dreps(ctx context.Context, query APIQueryParams) (ds []Drep, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceGovernanceDreps))
	if err != nil {
		return
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestUrl.String(), nil)
	if err != nil {
		return
	}

	v := req.URL.Query()
	v = formatParams(v, query)
	v = formatDrepsParams(v, query)
	req.URL.RawQuery = v.Encode()

	res, err := c.handleRequest(req)
	if err != nil {
		return
	}

	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&ds); err != nil {
		return
	}
	return ds, nil
}

func (c *apiClient) DrepsAll(ctx context.Context) <-chan DrepResult {
	ch := make(chan DrepResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan DrepResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				dreps, err := c.Dreps(j.ctx, j.query)
				if len(dreps) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := DrepResult{Res: dreps, Err: err}
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

// DrepDetails returns the details of a specific DRep.
func (c *apiClient) DrepDetails(ctx context.Context, drepId string) (dd DrepDetails, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceGovernanceDreps, drepId))
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
	if err = json.NewDecoder(res.Body).Decode(&dd); err != nil {
		return
	}
	return dd, nil
}

// DrepMetadata returns the metadata of a specific DRep.
func (c *apiClient) DrepMetadata(ctx context.Context, drepId string) (dm DrepMetadata, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceDreps, drepId, resourceDrepMetadata))
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
	if err = json.NewDecoder(res.Body).Decode(&dm); err != nil {
		return
	}
	return dm, nil
}

// DrepDelegators returns the list of delegators for a specific DRep.
func (c *apiClient) DrepDelegators(ctx context.Context, drepId string, query APIQueryParams) (dd []DrepDelegator, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceDreps, drepId, resourceDrepDelegators))
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

	if err = json.NewDecoder(res.Body).Decode(&dd); err != nil {
		return
	}
	return dd, nil
}

func (c *apiClient) DrepDelegatorsAll(ctx context.Context, drepId string) <-chan DrepDelegatorResult {
	ch := make(chan DrepDelegatorResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan DrepDelegatorResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				delegators, err := c.DrepDelegators(j.ctx, drepId, j.query)
				if len(delegators) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := DrepDelegatorResult{Res: delegators, Err: err}
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

// DrepUpdates returns the list of updates for a specific DRep.
func (c *apiClient) DrepUpdates(ctx context.Context, drepId string, query APIQueryParams) (du []DrepUpdate, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceDreps, drepId, resourceDrepUpdates))
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

	if err = json.NewDecoder(res.Body).Decode(&du); err != nil {
		return
	}
	return du, nil
}

func (c *apiClient) DrepUpdatesAll(ctx context.Context, drepId string) <-chan DrepUpdateResult {
	ch := make(chan DrepUpdateResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan DrepUpdateResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				updates, err := c.DrepUpdates(j.ctx, drepId, j.query)
				if len(updates) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := DrepUpdateResult{Res: updates, Err: err}
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

// DrepVotes returns the list of votes for a specific DRep.
func (c *apiClient) DrepVotes(ctx context.Context, drepId string, query APIQueryParams) (dv []DrepVote, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceDreps, drepId, resourceDrepVotes))
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

	if err = json.NewDecoder(res.Body).Decode(&dv); err != nil {
		return
	}
	return dv, nil
}

func (c *apiClient) DrepVotesAll(ctx context.Context, drepId string) <-chan DrepVoteResult {
	ch := make(chan DrepVoteResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan DrepVoteResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				votes, err := c.DrepVotes(j.ctx, drepId, j.query)
				if len(votes) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := DrepVoteResult{Res: votes, Err: err}
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

// Proposals returns the List of governance proposals.
func (c *apiClient) Proposals(ctx context.Context, query APIQueryParams) (ps []Proposal, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceGovernanceProposals))
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

func (c *apiClient) ProposalsAll(ctx context.Context) <-chan ProposalResult {
	ch := make(chan ProposalResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan ProposalResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				proposals, err := c.Proposals(j.ctx, j.query)
				if len(proposals) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := ProposalResult{Res: proposals, Err: err}
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

// Proposal returns the details of a specific governance proposal.
func (c *apiClient) Proposal(ctx context.Context, txHash string, certIndex int) (pd ProposalDetails, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%d", c.server, resourceGovernanceProposals, txHash, certIndex))
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
	if err = json.NewDecoder(res.Body).Decode(&pd); err != nil {
		return
	}
	return pd, nil
}

// ProposalParameters returns the parameters of a specific governance proposal.
func (c *apiClient) ProposalParameters(ctx context.Context, txHash string, certIndex int) (pp ProposalParameters, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%d/%s", c.server, resourceGovernanceProposals, txHash, certIndex, resourceProposalParameters))
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
	if err = json.NewDecoder(res.Body).Decode(&pp); err != nil {
		return
	}
	return pp, nil
}

// ProposalMetadata returns the metadata of a specific governance proposal.
func (c *apiClient) ProposalMetadata(ctx context.Context, txHash string, certIndex int) (pm ProposalMetadata, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%d/%s", c.server, resourceGovernanceProposals, txHash, certIndex, resourceProposalMetadata))
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

// ProposalByGovActionID returns the details of a governance proposal by its CIP-0129 governance action ID.
func (c *apiClient) ProposalByGovActionID(ctx context.Context, govActionID string) (pd ProposalDetails, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceGovernanceProposals, govActionID))
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
	if err = json.NewDecoder(res.Body).Decode(&pd); err != nil {
		return
	}
	return pd, nil
}

// ProposalParametersByGovActionID returns the parameters of a governance proposal by its CIP-0129 governance action ID.
func (c *apiClient) ProposalParametersByGovActionID(ctx context.Context, govActionID string) (pp ProposalParameters, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceProposals, govActionID, resourceProposalParameters))
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
	if err = json.NewDecoder(res.Body).Decode(&pp); err != nil {
		return
	}
	return pp, nil
}

// ProposalMetadataByGovActionID returns the metadata of a governance proposal by its CIP-0129 governance action ID.
func (c *apiClient) ProposalMetadataByGovActionID(ctx context.Context, govActionID string) (pm ProposalMetadataV2, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceProposals, govActionID, resourceProposalMetadata))
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

// ProposalWithdrawalsByGovActionID returns the withdrawals of a governance proposal by its CIP-0129 governance action ID.
func (c *apiClient) ProposalWithdrawalsByGovActionID(ctx context.Context, govActionID string) (pw []ProposalWithdrawal, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceProposals, govActionID, resourceProposalWithdrawals))
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
	if err = json.NewDecoder(res.Body).Decode(&pw); err != nil {
		return
	}
	return pw, nil
}

// ProposalVotesByGovActionID returns the votes of a governance proposal by its CIP-0129 governance action ID.
func (c *apiClient) ProposalVotesByGovActionID(ctx context.Context, govActionID string, query APIQueryParams) (pv []ProposalVote, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceGovernanceProposals, govActionID, resourceProposalVotes))
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

	if err = json.NewDecoder(res.Body).Decode(&pv); err != nil {
		return
	}
	return pv, nil
}

func (c *apiClient) ProposalVotesByGovActionIDAll(ctx context.Context, govActionID string) <-chan ProposalVoteResult {
	ch := make(chan ProposalVoteResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan ProposalVoteResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				votes, err := c.ProposalVotesByGovActionID(j.ctx, govActionID, j.query)
				if len(votes) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
					ch <- ProposalVoteResult{Res: votes, Err: err}
					return
				}
				ch <- ProposalVoteResult{Res: votes, Err: err}
			}
		}(jobs, ch, &wg)
	}

	go func() {
		defer close(ch)
		fetchScripts := true
		for i := 1; fetchScripts; i++ {
			select {
			case <-quit:
				fetchScripts = false
				continue
			default:
				jobs <- methodOptions{ctx: ctx, query: APIQueryParams{Count: 100, Page: i}}
			}
		}

		close(jobs)
		wg.Wait()
	}()
	return ch
}

// ProposalWithdrawals returns the withdrawals of a specific governance proposal.
func (c *apiClient) ProposalWithdrawals(ctx context.Context, txHash string, certIndex int, query APIQueryParams) (pw []ProposalWithdrawal, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%d/%s", c.server, resourceGovernanceProposals, txHash, certIndex, resourceProposalWithdrawals))
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

	if err = json.NewDecoder(res.Body).Decode(&pw); err != nil {
		return
	}
	return pw, nil
}

func (c *apiClient) ProposalWithdrawalsAll(ctx context.Context, txHash string, certIndex int) <-chan ProposalWithdrawalResult {
	ch := make(chan ProposalWithdrawalResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan ProposalWithdrawalResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				withdrawals, err := c.ProposalWithdrawals(j.ctx, txHash, certIndex, j.query)
				if len(withdrawals) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := ProposalWithdrawalResult{Res: withdrawals, Err: err}
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

// ProposalVotes returns the votes of a specific governance proposal.
func (c *apiClient) ProposalVotes(ctx context.Context, txHash string, certIndex int, query APIQueryParams) (pv []ProposalVote, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%d/%s", c.server, resourceGovernanceProposals, txHash, certIndex, resourceProposalVotes))
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

	if err = json.NewDecoder(res.Body).Decode(&pv); err != nil {
		return
	}
	return pv, nil
}

func (c *apiClient) ProposalVotesAll(ctx context.Context, txHash string, certIndex int) <-chan ProposalVoteResult {
	ch := make(chan ProposalVoteResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan ProposalVoteResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				votes, err := c.ProposalVotes(j.ctx, txHash, certIndex, j.query)
				if len(votes) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := ProposalVoteResult{Res: votes, Err: err}
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

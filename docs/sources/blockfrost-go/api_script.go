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
	resourceScripts         = "scripts"
	resourceRedeemers       = "redeemers"
	resourceScriptJSON      = "json"
	resourceScriptCBOR      = "cbor"
	resourceScriptDatum     = "scripts/datum"
	resourceScriptDatumCBOR = "cbor"
)

// Script contains information about a script
type Script struct {
	// Script hash
	ScriptHash string `json:"script_hash"`

	// Type of the script language
	Type string `json:"type"`

	// The size of the CBOR serialised script, if a Plutus script
	SerialisedSize *int `json:"serialised_size"`
}

// ScriptRedeemer contains information about a script redeemer.
type ScriptRedeemer struct {
	// Hash of the transaction
	TxHash string `json:"tx_hash"`

	// The index of the redeemer pointer in the transaction
	TxIndex int `json:"tx_index"`

	// Validation purpose. Enum: "spend" "mint" "cert" "reward"
	Purpose string `json:"purpose"`

	// Datum hash
	DatumHash string `json:"datum_hash"`

	// The budget in Memory to run a script
	UnitMem string `json:"unit_mem"`

	// The budget in CPU steps to run a script
	UnitSteps string `json:"unit_steps"`

	// The fee consumed to run the script
	Fee string `json:"fee"`
}

type methodOptions struct {
	ctx   context.Context
	query APIQueryParams
}

type ScriptAllResult struct {
	Res []Script
	Err error
}

type ScriptRedeemerResult struct {
	Res []ScriptRedeemer
	Err error
}

type ScriptJSON struct {
	JSON interface{} `json:"json"`
}

type ScriptCBOR struct {
	CBOR *string `json:"cbor"`
}

type ScriptDatum struct {
	JSONValue interface{} `json:"json_value"`
}

type ScriptDatumCBOR struct {
	CBOR string `json:"cbor"`
}

// Scripts returns a paginated list of scripts.
func (c *apiClient) Scripts(ctx context.Context, query APIQueryParams) (scripts []Script, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceScripts))
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

	if err = json.NewDecoder(res.Body).Decode(&scripts); err != nil {
		return
	}
	return scripts, nil

}

// ScriptsAll returns a list of all scripts.
func (c *apiClient) ScriptsAll(ctx context.Context) <-chan ScriptAllResult {
	ch := make(chan ScriptAllResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan ScriptAllResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				sc, err := c.Scripts(j.ctx, j.query)
				if len(sc) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := ScriptAllResult{Res: sc, Err: err}
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

// Script returns information about a specific script.
func (c *apiClient) Script(ctx context.Context, address string) (script Script, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceScripts, address))
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

	if err = json.NewDecoder(res.Body).Decode(&script); err != nil {
		return
	}
	return script, nil
}

// ScriptRedeemers returns a paginated list of redeemers of a specific script.
func (c *apiClient) ScriptRedeemers(ctx context.Context, address string, query APIQueryParams) (sr []ScriptRedeemer, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceScripts, address, resourceRedeemers))
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

	if err = json.NewDecoder(res.Body).Decode(&sr); err != nil {
		return
	}
	return sr, nil
}

// ScriptRedeemersAll returns a list of all redeemers of a specific script.
func (c *apiClient) ScriptRedeemersAll(ctx context.Context, address string) <-chan ScriptRedeemerResult {
	ch := make(chan ScriptRedeemerResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan ScriptRedeemerResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				sr, err := c.ScriptRedeemers(j.ctx, address, j.query)
				if len(sr) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := ScriptRedeemerResult{Res: sr, Err: err}
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

func (c *apiClient) ScriptJSON(ctx context.Context, scriptHash string) (sj ScriptJSON, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceScripts, scriptHash, resourceScriptJSON))
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
	if err = json.NewDecoder(res.Body).Decode(&sj); err != nil {
		return
	}
	return sj, nil
}

func (c *apiClient) ScriptCBOR(ctx context.Context, scriptHash string) (sc ScriptCBOR, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceScripts, scriptHash, resourceScriptCBOR))
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
	if err = json.NewDecoder(res.Body).Decode(&sc); err != nil {
		return
	}
	return sc, nil
}

func (c *apiClient) ScriptDatum(ctx context.Context, datumHash string) (sd ScriptDatum, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceScriptDatum, datumHash))
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
	if err = json.NewDecoder(res.Body).Decode(&sd); err != nil {
		return
	}
	return sd, nil
}

func (c *apiClient) ScriptDatumCBOR(ctx context.Context, datumHash string) (sdc ScriptDatumCBOR, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceScriptDatum, datumHash, resourceScriptDatumCBOR))
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
	if err = json.NewDecoder(res.Body).Decode(&sdc); err != nil {
		return
	}
	return sdc, nil
}

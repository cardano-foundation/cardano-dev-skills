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
	resourceMetadataTxLabels        = "metadata/txs/labels"
	resourceMetadataTxContentInJSON = "metadata/txs/labels" // and {label_parameter}
	resourceMetadataTxContentInCBOR = "metadata/txs/labels" // and {label_parameter}/cbor
)

// MetadataTxLabel return Transaction metadata labels
// List of all used transaction metadata labels.
type MetadataTxLabel struct {
	Label string  `json:"label"`
	Cip10 *string `json:"cip10"`
	Count string  `json:"count"`
}

// MetadataTxContentInJSON Transaction metadata content raw in JSON
// Transaction metadata per label.
// This struct are more flexible on JSONMetadata field
type MetadataTxContentInJSON struct {
	TxHash string `json:"tx_hash"`
	// 	string or object or Array of any or integer or number or boolean Nullable
	// Content of the JSON metadata
	JSONMetadata *interface{} `json:"json_metadata"`
}

// MetadataTxContentInCBOR return Transaction metadata content in CBOR
// Transaction metadata per label.
type MetadataTxContentInCBOR struct {
	TxHash   string  `json:"tx_hash"`
	Metadata *string `json:"metadata"`
}

type MetadataTxLabelResult struct {
	Res []MetadataTxLabel
	Err error
}

type MetadataTxContentInJSONResult struct {
	Res []MetadataTxContentInJSON
	Err error
}

type MetadataTxContentInCBORResult struct {
	Res []MetadataTxContentInCBOR
	Err error
}

// MetadataTxLabels returns the List of all used transaction metadata labels.
func (c *apiClient) MetadataTxLabels(ctx context.Context, query APIQueryParams) (mls []MetadataTxLabel, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/", c.server, resourceMetadataTxLabels))
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

	if res.StatusCode != http.StatusOK {
		return mls, handleAPIErrorResponse(res)
	}

	if err = json.NewDecoder(res.Body).Decode(&mls); err != nil {
		return
	}
	return mls, nil
}

func (c *apiClient) MetadataTxLabelsAll(ctx context.Context) <-chan MetadataTxLabelResult {
	ch := make(chan MetadataTxLabelResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan MetadataTxLabelResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				as, err := c.MetadataTxLabels(j.ctx, j.query)
				if len(as) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := MetadataTxLabelResult{Res: as, Err: err}
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

// MetadataTxContentInJSON returns the Transaction metadata content in JSON
// Transaction metadata per label.
func (c *apiClient) MetadataTxContentInJSON(ctx context.Context, label string, query APIQueryParams) (mt []MetadataTxContentInJSON, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s", c.server, resourceMetadataTxContentInJSON, label))
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

	err = json.NewDecoder(res.Body).Decode(&mt)
	if err != nil {
		return
	}
	return mt, nil
}

func (c *apiClient) MetadataTxContentInJSONAll(ctx context.Context, label string) <-chan MetadataTxContentInJSONResult {
	ch := make(chan MetadataTxContentInJSONResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan MetadataTxContentInJSONResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				tc, err := c.MetadataTxContentInJSON(j.ctx, label, j.query)
				if len(tc) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := MetadataTxContentInJSONResult{Res: tc, Err: err}
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

// MetadataTxContentInCBOR returns the Transaction metadata content in CBOR
// Transaction metadata per label.
func (c *apiClient) MetadataTxContentInCBOR(ctx context.Context, label string, query APIQueryParams) (mt []MetadataTxContentInCBOR, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s/%s/%s", c.server, resourceMetadataTxContentInCBOR, label, "cbor"))
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

	err = json.NewDecoder(res.Body).Decode(&mt)
	if err != nil {
		return
	}
	return mt, nil
}

func (c *apiClient) MetadataTxContentInCBORAll(ctx context.Context, label string) <-chan MetadataTxContentInCBORResult {
	ch := make(chan MetadataTxContentInCBORResult, c.routines)
	jobs := make(chan methodOptions, c.routines)
	quit := make(chan bool, 1)

	wg := sync.WaitGroup{}

	for i := 0; i < c.routines; i++ {
		wg.Add(1)
		go func(jobs chan methodOptions, ch chan MetadataTxContentInCBORResult, wg *sync.WaitGroup) {
			defer wg.Done()
			for j := range jobs {
				tc, err := c.MetadataTxContentInCBOR(j.ctx, label, j.query)
				if len(tc) != j.query.Count || err != nil {
					select {
					case quit <- true:
					default:
					}
				}
				res := MetadataTxContentInCBORResult{Res: tc, Err: err}
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

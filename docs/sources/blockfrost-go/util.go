package blockfrost

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strconv"

	"github.com/blockfrost/blockfrost-go/internal/version"
)

func handleAPIErrorResponse(res *http.Response) error {
	var err error
	switch res.StatusCode {
	case 400:
		br := BadRequest{}
		if err = json.NewDecoder(res.Body).Decode(&br); err != nil {
			return err
		}
		return &APIError{
			Response: br,
		}
	case 403:
		ua := UnauthorizedError{}
		if err = json.NewDecoder(res.Body).Decode(&ua); err != nil {
			return err
		}
		return &APIError{
			Response: ua,
		}
	case 404:
		nf := NotFound{}
		if err = json.NewDecoder(res.Body).Decode(&nf); err != nil {
			return err
		}
		return &APIError{
			Response: nf,
		}
	case 429:
		ol := OverusageLimit{}
		if err = json.NewDecoder(res.Body).Decode(&ol); err != nil {
			return err
		}
		return &APIError{
			Response: ol,
		}
	case 418:
		ab := AutoBanned{}
		if err = json.NewDecoder(res.Body).Decode(&ab); err != nil {
			return err
		}
		return &APIError{
			Response: ab,
		}
	case 500:
		ise := InternalServerError{}
		if err = json.NewDecoder(res.Body).Decode(&ise); err != nil {
			return err
		}
		return &APIError{
			Response: ise,
		}
	default:
		data, err := ioutil.ReadAll(res.Body)
		if err != nil {
			return err
		}
		return &APIError{
			Response: string(data),
		}
	}
}

func formatParams(v url.Values, query APIQueryParams) url.Values {
	if query.Count > 0 && query.Count <= 100 {
		v.Add("count", fmt.Sprintf("%d", query.Count))
	}
	if query.Page > 0 {
		v.Add("page", fmt.Sprintf("%d", query.Page))
	}
	if query.Order == "asc" || query.Order == "desc" {
		v.Add("order", query.Order)
	}
	if query.From != "" {
		v.Add("from", query.From)
	}
	if query.To != "" {
		v.Add("to", query.To)
	}

	return v
}

// formatDrepsParams adds the query parameters supported by /governance/dreps
// only. Kept separate from formatParams so other endpoints never emit them.
func formatDrepsParams(v url.Values, query APIQueryParams) url.Values {
	if query.OrderBy == "amount" {
		v.Add("order_by", query.OrderBy)
	}
	if query.Retired != nil {
		v.Add("retired", strconv.FormatBool(*query.Retired))
	}
	if query.Expired != nil {
		v.Add("expired", strconv.FormatBool(*query.Expired))
	}

	return v
}

func (c *apiClient) handleRequest(req *http.Request) (res *http.Response, err error) {
	req.Header.Add("project_id", c.projectId)

	userAgent := fmt.Sprintf("%s/%s", "blockfrost-go", version.String())
	req.Header.Set("User-Agent", userAgent)
	res, err = c.client.Do(req)
	if err != nil {
		return
	}

	if res.StatusCode != http.StatusOK {
		return res, handleAPIErrorResponse(res)
	}

	return res, nil
}

func (ip *ipfsClient) handleRequest(req *http.Request) (res *http.Response, err error) {
	req.Header.Add("project_id", ip.projectId)
	userAgent := fmt.Sprintf("%s/%s", "blockfrost-go", version.String())
	req.Header.Set("User-Agent", userAgent)
	res, err = ip.client.Do(req)
	if err != nil {
		return
	}

	if res.StatusCode != http.StatusOK {
		return res, handleAPIErrorResponse(res)
	}

	return res, nil
}

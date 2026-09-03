package blockfrost

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
)

// Info defines model for root endpoint `/`
type Info struct {
	Url     string `json:"url"`
	Version string `json:"version"`
}

// Health describes boolean for backend server health status.
type Health struct {
	IsHealthy bool `json:"is_healthy"`
}

// HealthClock describes current UNIX time
type HealthClock struct {
	ServerTime int64 `json:"server_time"`
}

// Info returns the root endpoint `/`. Root endpoint has
// no other function than to point end users to documentation.
func (c *apiClient) Info(ctx context.Context) (info Info, err error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.server, nil)
	if err != nil {
		return
	}

	res, err := c.handleRequest(req)

	if err != nil {
		return
	}
	defer res.Body.Close()

	if err = json.NewDecoder(res.Body).Decode(&info); err != nil {
		return
	}
	return info, nil

}

// Health returns the backend health status
// Return backend status as a boolean. Your application
// should handle situations when backend for the given chain is unavailable.
func (c *apiClient) Health(ctx context.Context) (h Health, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceHealth))
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

	if err = json.NewDecoder(res.Body).Decode(&h); err != nil {
		return
	}
	return h, nil
}

// HealthClock returns the current UNIX time. Your application might
// use this to verify if the client clock is not out of sync.
func (c *apiClient) HealthClock(ctx context.Context) (hc HealthClock, err error) {
	requestUrl, err := url.Parse(fmt.Sprintf("%s/%s", c.server, resourceHealthClock))
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

	if err = json.NewDecoder(res.Body).Decode(&hc); err != nil {
		return HealthClock{}, err
	}
	return hc, nil
}

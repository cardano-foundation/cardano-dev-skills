package blockfrost

import "fmt"

const (
	CardanoMainNet = "https://cardano-mainnet.blockfrost.io/api/v0"
	CardanoTestNet = "https://cardano-testnet.blockfrost.io/api/v0"
	CardanoPreProd = "https://cardano-preprod.blockfrost.io/api/v0"
	CardanoPreview = "https://cardano-preview.blockfrost.io/api/v0"
	IPFSNet        = "https://ipfs.blockfrost.io/api/v0"
)

// resource paths
const (
	resourceHealth                   = "health"
	resourceHealthClock              = "health/clock"
	resourceMetrics                  = "metrics"
	resourceMetricsEndpoint          = "metrics/endpoints"
	resourceBlock                    = "blocks"
	resourceBlocksLatest             = "blocks/latest"
	resourceBlocksLatestTransactions = "blocks/latest/txs"
	resourceBlocksSlot               = "blocks/slot"
	resourceBlocksEpoch              = "blocks/epoch"
)

// APIError is used to describe errors from the API.
// See https://docs.blockfrost.io/#section/Errors
type APIError struct {
	Response interface{}
}

func (e *APIError) Error() string {
	return fmt.Sprintf("API Error, %+v", e.Response)
}

// Autobanned defines model for HTTP `418` (Auto Banned).
type AutoBanned struct {
	Error      string `json:"error"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

// BadRequest defines model for HTTP `400` (Bad Request)
type BadRequest struct {
	Error      string `json:"error"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

// InternalServerError defines model for HTTP `500` (Internal Server Error)
type InternalServerError struct {
	Error      string `json:"error"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

// NotFound defines model for HTTP `404` (Resource Not Found).
type NotFound struct {
	Error      string `json:"error"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

// OverusageLimit defines model for HTTP `429` (Over Usage).
type OverusageLimit struct {
	Error      string `json:"error"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

// UnauthorizedEror defines model for HTTP `403` (Unauthorized).
type UnauthorizedError struct {
	Error      string `json:"error"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

type Transaction string

// APIQueryParams contains query parameters. Marshalled to
// "count", "page", "order", "from", "to".
type APIQueryParams struct {
	Count int
	Page  int
	Order string
	From  string
	To    string

	// OrderBy, Retired and Expired are marshalled to "order_by", "retired"
	// and "expired" by Dreps only; all other endpoints ignore them.
	// OrderBy set to "amount" sorts by voting power instead of registration order.
	// Retired and Expired filter by registration and activity state; nil returns both.
	OrderBy string
	Retired *bool
	Expired *bool
}

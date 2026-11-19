package v1alpha

import (
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strings"
	"time"

	"connectrpc.com/connect"
)

// UtxorpcClient is a configured client for a UTxO RPC v1alpha server. It
// provides the legacy service wrappers with v1alpha protobuf types. Newer
// v1beta helpers are available in [github.com/utxorpc/go-sdk.UtxorpcClient].
// Construct via [NewClient]; the zero value is not usable.
type UtxorpcClient struct {
	httpClient     connect.HTTPClient
	baseUrl        string
	headers        map[string]string
	dialTimeout    time.Duration
	requestTimeout time.Duration
	Query          QueryServiceClient
	Submit         SubmitServiceClient
	Sync           SyncServiceClient
	Watch          WatchServiceClient
}

// ClientOption configures a [UtxorpcClient] during [NewClient]. Options are
// applied in order; later options override earlier ones.
type ClientOption func(*UtxorpcClient)

// WithBaseUrl sets the UTxO RPC server URL. A "http://" prefix disables TLS
// in the default HTTP client; any other prefix (or none) enables TLS.
func WithBaseUrl(baseUrl string) ClientOption {
	return func(u *UtxorpcClient) {
		u.baseUrl = baseUrl
	}
}

// WithHeaders sets the initial headers injected by SDK wrappers (e.g. API keys).
func WithHeaders(headers map[string]string) ClientOption {
	return func(u *UtxorpcClient) {
		u.headers = headers
	}
}

// WithDialTimeout sets the timeout duration for establishing a connection to the UTxO RPC server.
// The timeout applies to the initial dial operation. If the connection cannot be established
// within the specified duration, the dial operation will fail with a timeout error.
//
// This setting does not apply if a custom HTTP client is provided via WithHttpClient.
//
// See also: WithRequestTimeout for setting the timeout for individual requests.
func WithDialTimeout(timeout time.Duration) ClientOption {
	return func(u *UtxorpcClient) {
		u.dialTimeout = timeout
	}
}

// WithRequestTimeout sets the default HTTP client's timeout for the entire
// request, including reading the response body. For streaming RPCs this
// limits the stream's lifetime. The default is zero (no client-wide timeout);
// caller-supplied contexts may still impose deadlines or cancellation.
//
// This setting does not apply if a custom HTTP client is provided via WithHttpClient.
//
// See also: WithDialTimeout for setting the timeout for establishing connections.
func WithRequestTimeout(timeout time.Duration) ClientOption {
	return func(u *UtxorpcClient) {
		u.requestTimeout = timeout
	}
}

// WithHttpClient replaces the entire HTTP client used by the [UtxorpcClient].
// When set, [WithDialTimeout] and [WithRequestTimeout] have no effect.
func WithHttpClient(httpClient connect.HTTPClient) ClientOption {
	return func(u *UtxorpcClient) {
		u.httpClient = httpClient
	}
}

// NewClient constructs a [UtxorpcClient], applies the given options, builds a
// default HTTP/2 client if [WithHttpClient] was not used, and initializes the
// Query / Submit / Sync / Watch service clients.
func NewClient(options ...ClientOption) *UtxorpcClient {
	u := &UtxorpcClient{}

	for _, option := range options {
		option(u)
	}
	if u.httpClient == nil {
		if strings.HasPrefix(u.baseUrl, "http://") {
			u.httpClient = createHttpClient(false, u.dialTimeout, u.requestTimeout)
		} else {
			u.httpClient = createHttpClient(true, u.dialTimeout, u.requestTimeout)
		}
	}
	u.Query = u.NewQueryServiceClient()
	u.Submit = u.NewSubmitServiceClient()
	u.Sync = u.NewSyncServiceClient()
	u.Watch = u.NewWatchServiceClient()
	return u
}

func (u *UtxorpcClient) reset() {
	u.Query = u.NewQueryServiceClient()
	u.Submit = u.NewSubmitServiceClient()
	u.Sync = u.NewSyncServiceClient()
	u.Watch = u.NewWatchServiceClient()
}

// HTTPClient returns the underlying [connect.HTTPClient] used for transport.
func (u *UtxorpcClient) HTTPClient() connect.HTTPClient {
	return u.httpClient
}

// SetURL updates the server URL and rebuilds all four service clients so
// subsequent calls target the new endpoint.
func (u *UtxorpcClient) SetURL(baseUrl string) {
	u.baseUrl = baseUrl
	u.reset()
}

// URL returns the configured base URL.
func (u *UtxorpcClient) URL() string {
	return u.baseUrl
}

func createHttpClient(enableTls bool, dialTimeout, requestTimeout time.Duration) *http.Client {
	protocols := new(http.Protocols)
	protocols.SetHTTP2(enableTls)
	protocols.SetUnencryptedHTTP2(!enableTls)
	dialer := &net.Dialer{Timeout: dialTimeout}
	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS12,
		NextProtos: []string{"h2"},
	}

	return &http.Client{
		Timeout: requestTimeout,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
		Transport: &http.Transport{
			Protocols:       protocols,
			DialContext:     dialer.DialContext,
			TLSClientConfig: tlsConfig,
			DialTLSContext: (&tls.Dialer{
				NetDialer: dialer,
				Config:    tlsConfig,
			}).DialContext,
		},
	}
}

// Headers returns the client's stored headers. The returned map is the
// client's live map when headers have been set, and a fresh empty map
// otherwise.
func (u *UtxorpcClient) Headers() map[string]string {
	headers := u.headers
	if headers == nil {
		headers = make(map[string]string)
	}
	return headers
}

// SetHeader sets a single header, allocating the underlying map if needed.
func (u *UtxorpcClient) SetHeader(key, value string) {
	if u.headers == nil {
		u.headers = make(map[string]string)
	}
	u.headers[key] = value
}

// SetHeaders replaces all stored headers with the given map.
func (u *UtxorpcClient) SetHeaders(headers map[string]string) {
	u.headers = headers
}

// RemoveHeader deletes a single header. No-op if the key is absent.
func (u *UtxorpcClient) RemoveHeader(key string) {
	delete(u.headers, key)
}

// AddHeadersToRequest copies all stored headers into the given Connect
// request. Wrapper methods on [UtxorpcClient] call this automatically.
func (u *UtxorpcClient) AddHeadersToRequest(req connect.AnyRequest) {
	for key, value := range u.headers {
		req.Header().Set(key, value)
	}
}

// HandleError prints a Connect error's code, message, and details to stdout
// and panics. Intended for examples; production code should inspect
// [*connect.Error] explicitly via [errors.As].
func HandleError(err error) {
	fmt.Println(connect.CodeOf(err))
	if connectErr := new(connect.Error); errors.As(err, &connectErr) {
		fmt.Println(connectErr.Message())
		fmt.Println(connectErr.Details())
	}
	panic(err)
}

package sdk

import (
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/http"
	"strings"
	"time"

	"connectrpc.com/connect"
	"golang.org/x/net/http2"
)

// UtxorpcClient is a configured client for a UTxO RPC server.
//
// The Query, Submit, Sync, and Watch fields are the underlying Connect
// service clients; the methods on UtxorpcClient (e.g. ReadParams, SubmitTx,
// FollowTip) are convenience wrappers that auto-inject stored headers and
// optionally use a caller-supplied [context.Context].
//
// Construct via [NewClient]; the zero value is not usable.
type UtxorpcClient struct {
	httpClient     connect.HTTPClient
	baseUrl        string
	headers        map[string]string
	dialTimeout    time.Duration
	requestTimeout time.Duration
	connectOptions []connect.ClientOption
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

// WithHeaders sets the initial set of headers attached to every request
// (e.g. API keys). Headers can be added, replaced, or removed later via
// [UtxorpcClient.SetHeader], [UtxorpcClient.SetHeaders], and
// [UtxorpcClient.RemoveHeader].
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

// WithRequestTimeout sets the timeout duration for individual requests made by the UtxorpcClient.
// The timeout applies to each request operation and will cause the request to fail if it
// exceeds the specified duration. If not set, requests will use the default timeout behavior.
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
// When set, [WithDialTimeout] and [WithRequestTimeout] have no effect because
// the SDK's default transport is bypassed.
func WithHttpClient(httpClient connect.HTTPClient) ClientOption {
	return func(u *UtxorpcClient) {
		u.httpClient = httpClient
	}
}

// WithConnectOptions applies Connect client options to every generated
// service client. Use it to configure interceptors, compression, or other
// Connect behavior without replacing the HTTP client.
//
// The SDK continues to configure the gRPC protocol by default. Options are
// applied after that default, in the order provided.
func WithConnectOptions(options ...connect.ClientOption) ClientOption {
	return func(u *UtxorpcClient) {
		u.connectOptions = append(
			u.connectOptions,
			options...,
		)
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

func (u *UtxorpcClient) clientOptions() []connect.ClientOption {
	options := make([]connect.ClientOption, 0, len(u.connectOptions)+1)
	options = append(options, connect.WithGRPC())
	return append(options, u.connectOptions...)
}

// HTTPClient returns the underlying [connect.HTTPClient] used for transport.
func (u *UtxorpcClient) HTTPClient() connect.HTTPClient {
	return u.httpClient
}

// SetURL updates the server URL and rebuilds all four service clients so
// subsequent calls target the new endpoint. Existing in-flight requests are
// not affected.
func (u *UtxorpcClient) SetURL(baseUrl string) {
	u.baseUrl = baseUrl
	u.reset()
}

// URL returns the configured base URL.
func (u *UtxorpcClient) URL() string {
	return u.baseUrl
}

func createHttpClient(enableTls bool, dialTimeout, requestTimeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: requestTimeout,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
		Transport: &http2.Transport{
			AllowHTTP: true,
			DialTLS: func(network, addr string, tlsConfig *tls.Config) (net.Conn, error) {
				if enableTls {
					// Establish a TLS connection using the custom TLS configuration
					conn, err := tls.DialWithDialer(&net.Dialer{Timeout: dialTimeout}, network, addr, tlsConfig)
					if err != nil {
						return nil, fmt.Errorf(
							"failed to establish TLS connection: %w",
							err,
						)
					}
					return conn, nil
				}
				return net.DialTimeout(network, addr, dialTimeout)
			},
		},
	}
}

// Headers returns the client's stored headers. The returned map is the
// client's live map when headers have been set, and a fresh empty map
// otherwise; callers should not assume isolation from internal state.
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
// request. The wrapper methods on [UtxorpcClient] call this automatically;
// callers only need it when invoking the embedded [QueryServiceClient],
// [SubmitServiceClient], [SyncServiceClient], or [WatchServiceClient]
// directly.
func (u *UtxorpcClient) AddHeadersToRequest(req connect.AnyRequest) {
	for key, value := range u.headers {
		req.Header().Set(key, value)
	}
}

// AsConnectError returns the underlying Connect RPC error, including its code,
// message, details, and response metadata. The boolean is false when err does
// not contain a [*connect.Error].
func AsConnectError(err error) (*connect.Error, bool) {
	connectErr := new(connect.Error)
	if !errors.As(err, &connectErr) {
		return nil, false
	}
	return connectErr, true
}

// HandleError prints a Connect error's code, message, and details to stdout
// and panics.
//
// Deprecated: Handle errors explicitly. Use [AsConnectError] to inspect
// Connect RPC status information without panicking.
func HandleError(err error) {
	fmt.Println(connect.CodeOf(err))
	if connectErr, ok := AsConnectError(err); ok {
		fmt.Println(connectErr.Message())
		fmt.Println(connectErr.Details())
	}
	panic(err)
}

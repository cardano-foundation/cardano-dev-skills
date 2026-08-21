package ogmios

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/SundaeSwap-finance/kugo"
	ogmigo "github.com/SundaeSwap-finance/ogmigo/v6"
	"github.com/SundaeSwap-finance/ogmigo/v6/ouroboros/chainsync"
	"github.com/SundaeSwap-finance/ogmigo/v6/ouroboros/shared"
	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// OgmiosClient is the Ogmios query surface OgmiosChainContext depends on.
//
// Apollo owns this interface: no method names a type from the library used to
// talk to Ogmios, so that library's major version stays an implementation
// detail of this package instead of part of Apollo's public API.
// NewOgmiosChainContext builds the default implementation from connection
// settings; NewOgmiosChainContextFromClients accepts any other, which is the
// seam tests and custom transports use.
//
// Protocol parameters and the genesis configuration are returned as the raw
// Ogmios JSON result because Apollo, not the client, owns their decoding: the
// wire shapes have changed across Ogmios releases and the conversions live
// here. The remaining results are Cardano domain values, which spares
// implementations from mirroring an Ogmios wire type.
type OgmiosClient interface {
	// ProtocolParameters returns the queryLedgerState/protocolParameters
	// result as sent by Ogmios.
	ProtocolParameters(ctx context.Context) (json.RawMessage, error)
	// GenesisConfig returns the queryNetwork/genesisConfiguration result for
	// an era ("shelley", "byron", ...) as sent by Ogmios.
	GenesisConfig(ctx context.Context, era string) (json.RawMessage, error)
	// CurrentEpoch returns the epoch the ledger is in.
	CurrentEpoch(ctx context.Context) (uint64, error)
	// Tip returns the slot of the current chain tip. A chain sitting at
	// origin has no slot and is an error.
	Tip(ctx context.Context) (uint64, error)
	// SubmitTx submits a serialized transaction and returns its hash.
	SubmitTx(ctx context.Context, txCbor []byte) (common.Blake2b256, error)
	// EvaluateTx returns the execution units each redeemer of a serialized
	// transaction requires. additionalUtxos carries resolved UTxOs the
	// evaluator cannot see on-chain.
	EvaluateTx(
		ctx context.Context,
		txCbor []byte,
		additionalUtxos []common.Utxo,
	) (map[common.RedeemerKey]common.ExUnits, error)
	// UtxoByRef resolves one UTxO by its output reference.
	UtxoByRef(
		ctx context.Context,
		txHash common.Blake2b256,
		index uint32,
	) (*common.Utxo, error)
}

// KupoClient is the Kupo query surface OgmiosChainContext depends on. Ogmios
// cannot answer address UTxO queries or resolve a script by hash, so a
// context built without a Kupo client reports neither CapabilityUtxos nor
// CapabilityScriptCbor. Like OgmiosClient, it names no third-party type.
type KupoClient interface {
	// UtxosAtAddress returns the unspent outputs at an address.
	UtxosAtAddress(
		ctx context.Context,
		address common.Address,
	) ([]common.Utxo, error)
	// ScriptCbor returns the CBOR of the script with the given hash.
	ScriptCbor(
		ctx context.Context,
		scriptHash common.Blake2b224,
	) ([]byte, error)
}

// ogmiosWebsocketURL validates an Ogmios endpoint and returns the URL to
// dial. Ogmios serves JSON-RPC over WebSocket, so an http or https URL is
// accepted and dialed as ws or wss rather than rejected.
func ogmiosWebsocketURL(endpoint string) (string, error) {
	if strings.TrimSpace(endpoint) == "" {
		return "", errors.New("ogmios endpoint is required")
	}
	parsed, err := url.Parse(endpoint)
	if err != nil {
		return "", fmt.Errorf(
			"invalid ogmios endpoint %q: %w", endpoint, err,
		)
	}
	switch parsed.Scheme {
	case "ws", "wss":
	case "http":
		parsed.Scheme = "ws"
	case "https":
		parsed.Scheme = "wss"
	default:
		return "", fmt.Errorf(
			"invalid ogmios endpoint %q: scheme must be ws, wss, http,"+
				" or https", endpoint,
		)
	}
	if parsed.Host == "" {
		return "", fmt.Errorf(
			"invalid ogmios endpoint %q: missing host", endpoint,
		)
	}
	return parsed.String(), nil
}

// kupoBaseURL validates a Kupo endpoint and returns the base URL to request.
// Kupo is a plain HTTP service; its paths are appended by the client, so any
// trailing slash is dropped here.
func kupoBaseURL(endpoint string) (string, error) {
	if strings.TrimSpace(endpoint) == "" {
		return "", errors.New("kupo endpoint is required")
	}
	parsed, err := url.Parse(endpoint)
	if err != nil {
		return "", fmt.Errorf("invalid kupo endpoint %q: %w", endpoint, err)
	}
	switch parsed.Scheme {
	case "http", "https":
	default:
		return "", fmt.Errorf(
			"invalid kupo endpoint %q: scheme must be http or https",
			endpoint,
		)
	}
	if parsed.Host == "" {
		return "", fmt.Errorf(
			"invalid kupo endpoint %q: missing host", endpoint,
		)
	}
	return strings.TrimRight(parsed.String(), "/"), nil
}

// ogmigoClient adapts the ogmigo client to OgmiosClient. Every ogmigo call
// Apollo makes goes through this type, so moving to a new major version of
// ogmigo is a change to this file alone.
type ogmigoClient struct {
	client *ogmigo.Client
}

var _ OgmiosClient = (*ogmigoClient)(nil)

// newOgmigoClient builds the default OgmiosClient for an endpoint. It
// performs no I/O; the connection is made per query.
func newOgmigoClient(endpoint string) (*ogmigoClient, error) {
	websocketURL, err := ogmiosWebsocketURL(endpoint)
	if err != nil {
		return nil, err
	}
	return &ogmigoClient{
		client: ogmigo.New(ogmigo.WithEndpoint(websocketURL)),
	}, nil
}

func (c *ogmigoClient) ProtocolParameters(
	ctx context.Context,
) (json.RawMessage, error) {
	return c.client.CurrentProtocolParameters(ctx)
}

func (c *ogmigoClient) GenesisConfig(
	ctx context.Context,
	era string,
) (json.RawMessage, error) {
	return c.client.GenesisConfig(ctx, era)
}

func (c *ogmigoClient) CurrentEpoch(ctx context.Context) (uint64, error) {
	return c.client.CurrentEpoch(ctx)
}

func (c *ogmigoClient) Tip(ctx context.Context) (uint64, error) {
	point, err := c.client.ChainTip(ctx)
	if err != nil {
		return 0, err
	}
	ps, ok := point.PointStruct()
	if !ok || ps == nil {
		return 0, errors.New("chain tip is origin")
	}
	return ps.Slot, nil
}

func (c *ogmigoClient) SubmitTx(
	ctx context.Context,
	txCbor []byte,
) (common.Blake2b256, error) {
	resp, err := c.client.SubmitTx(ctx, hex.EncodeToString(txCbor))
	if err != nil {
		return common.Blake2b256{}, err
	}
	if resp == nil {
		return common.Blake2b256{}, errors.New("empty submit tx response")
	}
	if resp.Error != nil {
		return common.Blake2b256{}, fmt.Errorf(
			"submit tx error: %s", resp.Error.Message,
		)
	}
	hashBytes, err := hex.DecodeString(resp.ID)
	if err != nil {
		return common.Blake2b256{}, err
	}
	if len(hashBytes) != common.Blake2b256Size {
		return common.Blake2b256{}, fmt.Errorf(
			"invalid tx hash length: expected %d bytes, got %d",
			common.Blake2b256Size, len(hashBytes),
		)
	}
	var result common.Blake2b256
	copy(result[:], hashBytes)
	return result, nil
}

func (c *ogmigoClient) EvaluateTx(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	txHex := hex.EncodeToString(txCbor)
	var resp *ogmigo.EvaluateTxResponse
	var err error
	if len(additionalUtxos) > 0 {
		// Ogmios natively accepts a set of resolved UTxOs so it can evaluate
		// inputs that are not yet visible on-chain.
		sharedUtxos, convErr := commonUtxosToShared(additionalUtxos)
		if convErr != nil {
			return nil, convErr
		}
		resp, err = c.client.EvaluateTxWithAdditionalUtxos(
			ctx, txHex, sharedUtxos,
		)
	} else {
		resp, err = c.client.EvaluateTx(ctx, txHex)
	}
	if err != nil {
		return nil, err
	}
	return evaluateResponseToExUnits(resp)
}

func (c *ogmigoClient) UtxoByRef(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	query := chainsync.TxInQuery{
		Transaction: shared.UtxoTxID{
			ID: hex.EncodeToString(txHash.Bytes()),
		},
		Index: index,
	}
	utxos, err := c.client.UtxosByTxIn(ctx, query)
	if err != nil {
		return nil, err
	}
	if len(utxos) == 0 {
		return nil, errors.New("utxo not found")
	}

	raw := utxos[0]
	addr, err := common.NewAddress(raw.Address)
	if err != nil {
		return nil, err
	}
	result, err := ogmiosUtxoToCommon(raw, addr)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// kugoClient adapts the kugo client to KupoClient. As with ogmigoClient,
// every kugo call Apollo makes goes through this type.
type kugoClient struct {
	client *kugo.Client
}

var _ KupoClient = (*kugoClient)(nil)

// newKugoClient builds the default KupoClient for an endpoint. A zero timeout
// leaves the kugo default in place.
func newKugoClient(
	endpoint string,
	timeout time.Duration,
) (*kugoClient, error) {
	baseURL, err := kupoBaseURL(endpoint)
	if err != nil {
		return nil, err
	}
	options := []kugo.Option{kugo.WithEndpoint(baseURL)}
	if timeout > 0 {
		options = append(options, kugo.WithTimeout(timeout))
	}
	return &kugoClient{client: kugo.New(options...)}, nil
}

func (c *kugoClient) UtxosAtAddress(
	ctx context.Context,
	address common.Address,
) ([]common.Utxo, error) {
	matches, err := c.client.Matches(
		ctx, kugo.OnlyUnspent(), kugo.Address(address.String()),
	)
	if err != nil {
		return nil, err
	}

	var utxos []common.Utxo
	for _, match := range matches {
		// The client doubles as the datum fetcher: kupo reports only the
		// datum hash in a match, so inline datums are resolved separately.
		utxo, err := matchToUtxo(ctx, match, address, c.client)
		if err != nil {
			return nil, fmt.Errorf("failed to parse UTxO match: %w", err)
		}
		utxos = append(utxos, utxo)
	}
	return utxos, nil
}

func (c *kugoClient) ScriptCbor(
	ctx context.Context,
	scriptHash common.Blake2b224,
) ([]byte, error) {
	hashHex := hex.EncodeToString(scriptHash.Bytes())
	script, err := c.client.Script(ctx, hashHex)
	if err != nil {
		return nil, err
	}
	if script == nil {
		return nil, fmt.Errorf("kupo returned no script for %s", hashHex)
	}
	return hex.DecodeString(script.Script)
}

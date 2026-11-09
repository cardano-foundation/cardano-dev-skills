package ouroboros

import (
	"context"
	"errors"
	"fmt"
	"math"
	"net"
	"strings"
	"time"

	gouroboros "github.com/blinklabs-io/gouroboros"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/shelley"
	"github.com/blinklabs-io/gouroboros/protocol/localstatequery"
	"github.com/blinklabs-io/gouroboros/protocol/localtxsubmission"

	"github.com/Salvionied/apollo/v2/backend"
)

// Config holds the settings for a node-to-client connection.
type Config struct {
	// Network is "unix" for the node's local socket, or "tcp" for a socket
	// exposed over TCP (for example through socat). Required.
	Network string
	// Address is the socket path for "unix" or host:port for "tcp".
	// Required.
	Address string
	// NetworkMagic identifies the chain in the handshake: 764824073 for
	// mainnet, 1 for preprod, 2 for preview. Required.
	NetworkMagic uint32
	// NetworkId is the Cardano network identifier reported by NetworkId()
	// (mainnet = 1, testnets = 0).
	NetworkId uint8
	// DialTimeout bounds opening the socket. Zero uses DefaultDialTimeout.
	DialTimeout time.Duration
	// HandshakeTimeout bounds the node-to-client handshake after the socket
	// opens. Zero uses DefaultHandshakeTimeout.
	HandshakeTimeout time.Duration
	// QueryTimeout bounds each ledger-state query. Zero uses
	// DefaultQueryTimeout. Querying UTxOs by address on mainnet can take
	// tens of seconds; a context passed to a ...Context method can end any
	// operation sooner.
	QueryTimeout time.Duration
	// SubmitTimeout bounds waiting for the node to accept or reject a
	// transaction. Zero uses DefaultSubmitTimeout.
	SubmitTimeout time.Duration
}

const (
	// DefaultDialTimeout applies when Config.DialTimeout is zero.
	DefaultDialTimeout = 10 * time.Second
	// DefaultHandshakeTimeout applies when Config.HandshakeTimeout is zero.
	DefaultHandshakeTimeout = 10 * time.Second
	// DefaultQueryTimeout applies when Config.QueryTimeout is zero.
	DefaultQueryTimeout = 3 * time.Minute
	// DefaultSubmitTimeout applies when Config.SubmitTimeout is zero.
	DefaultSubmitTimeout = 30 * time.Second
)

// maxAddressQueryUtxos bounds the retained address-query result after the
// node answers, before allocating and sorting the returned UTxO slice.
const maxAddressQueryUtxos = 100_000

// OuroborosChainContext implements backend.ChainContext by talking to a
// cardano-node directly over the node-to-client mini-protocols.
//
// The node has no query for a script by hash and no script evaluator, so the
// context reports neither CapabilityScriptCbor nor CapabilityEvaluateTx.
type OuroborosChainContext struct {
	session   *session
	networkId uint8
}

var (
	_ backend.ContextChainContext = (*OuroborosChainContext)(nil)
	_ backend.CapabilityReporter  = (*OuroborosChainContext)(nil)
)

// NewOuroborosChainContext creates a context for a node's socket. It
// performs no I/O: the connection is opened by the first query, and reopened
// after any connection failure.
func NewOuroborosChainContext(cfg Config) (*OuroborosChainContext, error) {
	switch cfg.Network {
	case "unix", "tcp":
	default:
		return nil, fmt.Errorf(`invalid node network %q: must be "unix" or "tcp"`, cfg.Network)
	}
	if strings.TrimSpace(cfg.Address) == "" {
		return nil, errors.New("node address is required")
	}
	if cfg.NetworkMagic == 0 {
		return nil, errors.New("network magic is required")
	}
	for name, d := range map[string]time.Duration{
		"dial":      cfg.DialTimeout,
		"handshake": cfg.HandshakeTimeout,
		"query":     cfg.QueryTimeout,
		"submit":    cfg.SubmitTimeout,
	} {
		if d < 0 {
			return nil, fmt.Errorf("invalid %s timeout %v: must not be negative", name, d)
		}
	}
	dialTimeout := orDefault(cfg.DialTimeout, DefaultDialTimeout)
	dialer := net.Dialer{Timeout: dialTimeout}
	return newContext(
		func(ctx context.Context) (net.Conn, error) {
			return dialer.DialContext(ctx, cfg.Network, cfg.Address)
		},
		cfg,
	), nil
}

func newContext(dial dialFunc, cfg Config) *OuroborosChainContext {
	return &OuroborosChainContext{
		session: newSession(
			dial,
			cfg.NetworkMagic,
			orDefault(cfg.HandshakeTimeout, DefaultHandshakeTimeout),
			orDefault(cfg.QueryTimeout, DefaultQueryTimeout),
			orDefault(cfg.SubmitTimeout, DefaultSubmitTimeout),
		),
		networkId: cfg.NetworkId,
	}
}

func orDefault(d, def time.Duration) time.Duration {
	if d == 0 {
		return def
	}
	return d
}

// Close closes the connection to the node. The context stays usable and
// reconnects on its next query.
func (o *OuroborosChainContext) Close() error {
	o.session.close()
	return nil
}

// Capabilities reports everything except script lookup by hash and
// transaction evaluation, which node-to-client does not offer.
func (o *OuroborosChainContext) Capabilities() backend.CapabilitySet {
	return backend.CapabilitySet(backend.AllCapabilities) &^ backend.CapabilitySet(
		backend.CapabilityScriptCbor|
			backend.CapabilityEvaluateTx|
			backend.CapabilityEvaluateTxAdditionalUtxos,
	)
}

func (o *OuroborosChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return o.ProtocolParamsContext(context.Background())
}

func (o *OuroborosChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	var params common.ProtocolParameters
	err := o.session.query(ctx, func(c *localstatequery.Client) error {
		var err error
		params, err = c.GetCurrentProtocolParams()
		return err
	})
	if err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("query protocol parameters: %w", err)
	}
	return protocolParamsFromLedger(params)
}

func (o *OuroborosChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return o.GenesisParamsContext(context.Background())
}

func (o *OuroborosChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	var genesis *localstatequery.GenesisConfigResult
	err := o.session.query(ctx, func(c *localstatequery.Client) error {
		var err error
		genesis, err = c.GetGenesisConfig()
		return err
	})
	if err != nil {
		return backend.GenesisParameters{}, fmt.Errorf("query genesis configuration: %w", err)
	}
	return genesisParamsFromLedger(genesis)
}

func (o *OuroborosChainContext) NetworkId() uint8 {
	return o.networkId
}

func (o *OuroborosChainContext) CurrentEpoch() (uint64, error) {
	return o.CurrentEpochContext(context.Background())
}

func (o *OuroborosChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	var epoch int
	err := o.session.query(ctx, func(c *localstatequery.Client) error {
		var err error
		epoch, err = c.GetEpochNo()
		return err
	})
	if err != nil {
		return 0, fmt.Errorf("query epoch: %w", err)
	}
	if epoch < 0 {
		return 0, fmt.Errorf("node reported negative epoch %d", epoch)
	}
	return uint64(epoch), nil
}

func (o *OuroborosChainContext) MaxTxFee() (uint64, error) {
	return o.MaxTxFeeContext(context.Background())
}

func (o *OuroborosChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	pp, err := o.ProtocolParamsContext(ctx)
	if err != nil {
		return 0, err
	}
	return backend.ComputeMaxTxFee(pp)
}

func (o *OuroborosChainContext) Tip() (uint64, error) {
	return o.TipContext(context.Background())
}

// TipContext returns the slot of the node's current chain tip.
func (o *OuroborosChainContext) TipContext(ctx context.Context) (uint64, error) {
	var slot uint64
	var origin bool
	err := o.session.query(ctx, func(c *localstatequery.Client) error {
		point, err := c.GetChainPoint()
		if err != nil {
			return err
		}
		if point == nil || len(point.Hash) == 0 {
			origin = true
			return nil
		}
		slot = point.Slot
		return nil
	})
	if err != nil {
		return 0, fmt.Errorf("query chain tip: %w", err)
	}
	if origin {
		return 0, errors.New("chain tip is origin")
	}
	return slot, nil
}

func (o *OuroborosChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return o.UtxosContext(context.Background(), address)
}

// UtxosContext returns the unspent outputs at an address. The node answers
// by scanning its UTxO set, which takes noticeable time on mainnet.
// Results containing more than 100,000 UTxOs are rejected.
func (o *OuroborosChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	var result *localstatequery.UTxOsResult
	err := o.session.query(ctx, func(c *localstatequery.Client) error {
		var err error
		result, err = c.GetUTxOByAddress([]common.Address{address})
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("query utxos by address: %w", err)
	}
	if result == nil {
		return nil, nil
	}
	if len(result.Results) > maxAddressQueryUtxos {
		return nil, fmt.Errorf("address query UTxO count %d exceeds limit %d", len(result.Results), maxAddressQueryUtxos)
	}
	return utxosFromLedger(result.Results)
}

func (o *OuroborosChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return o.SubmitTxContext(context.Background(), txCbor)
}

// errReleaseAfterAccept marks a submission the node accepted on a connection
// that then failed to release its ledger state. The connection is discarded,
// but the transaction was submitted.
var errReleaseAfterAccept = errors.New("release ledger state after the node accepted the transaction")

// SubmitTxContext submits a transaction in the node's current era and
// returns its id. A rejection by the node is returned as an error wrapping
// localtxsubmission.TransactionRejectedError.
func (o *OuroborosChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	hash, err := txHash(txCbor)
	if err != nil {
		return common.Blake2b256{}, err
	}
	err = o.session.run(ctx, func(conn *gouroboros.Connection) error {
		lsq := conn.LocalStateQuery().Client
		if err := lsq.AcquireVolatileTip(); err != nil {
			return fmt.Errorf("acquire ledger state: %w", err)
		}
		// The ledger state is released only after the node has answered the
		// submission. Releasing first would put a LocalStateQuery message
		// and the submission on different mini-protocols at the same time,
		// leaving their order on the wire to the muxer.
		err := submitInCurrentEra(lsq, conn.LocalTxSubmission().Client, txCbor)
		return submitOutcome(err, lsq.Release())
	})
	// run returns the context's error instead if the context ended, so an
	// acceptance is reported only when the caller is still waiting for it.
	if err != nil && !errors.Is(err, errReleaseAfterAccept) {
		return common.Blake2b256{}, fmt.Errorf("submit transaction: %w", err)
	}
	return hash, nil
}

// submitOutcome combines a submission's result with releasing the ledger
// state afterwards. Once the node has accepted the transaction, a release
// failure only means the connection is unusable; it is marked with
// errReleaseAfterAccept so run discards the connection and the caller still
// learns the transaction was submitted.
func submitOutcome(submitErr, releaseErr error) error {
	switch {
	case submitErr != nil:
		return submitErr
	case releaseErr != nil:
		return fmt.Errorf("%w: %w", errReleaseAfterAccept, releaseErr)
	default:
		return nil
	}
}

func submitInCurrentEra(lsq *localstatequery.Client, submit *localtxsubmission.Client, txCbor []byte) error {
	era, err := lsq.GetCurrentEra()
	if err != nil {
		return fmt.Errorf("query current era: %w", err)
	}
	if era < 0 || era > math.MaxUint16 {
		return fmt.Errorf("node reported era %d out of range", era)
	}
	err = submit.SubmitTx(uint16(era), txCbor)
	var rejected localtxsubmission.TransactionRejectedError
	if errors.As(err, &rejected) {
		return fmt.Errorf("%w: %w", errTransactionRejected, err)
	}
	return err
}

func (o *OuroborosChainContext) EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return o.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

func (o *OuroborosChainContext) EvaluateTxContext(
	ctx context.Context,
	_ []byte,
	_ []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return nil, backend.NewUnsupportedError("node-to-client", backend.CapabilityEvaluateTx)
}

func (o *OuroborosChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return o.UtxoByRefContext(context.Background(), txHash, index)
}

func (o *OuroborosChainContext) UtxoByRefContext(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	var result *localstatequery.UTxOByTxInResult
	err := o.session.query(ctx, func(c *localstatequery.Client) error {
		var err error
		result, err = c.GetUTxOByTxIn([]common.TransactionInput{
			shelley.ShelleyTransactionInput{TxId: txHash, OutputIndex: index},
		})
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("query utxo by reference: %w", err)
	}
	if result == nil || len(result.Results) == 0 {
		return nil, errors.New("utxo not found")
	}
	utxos, err := utxosFromLedger(result.Results)
	if err != nil {
		return nil, err
	}
	for i := range utxos {
		if utxos[i].Id.Index() == index && utxos[i].Id.Id() == txHash {
			return &utxos[i], nil
		}
	}
	return nil, errors.New("utxo not found")
}

func (o *OuroborosChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return o.ScriptCborContext(context.Background(), scriptHash)
}

func (o *OuroborosChainContext) ScriptCborContext(ctx context.Context, _ common.Blake2b224) ([]byte, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return nil, backend.NewUnsupportedError("node-to-client", backend.CapabilityScriptCbor)
}

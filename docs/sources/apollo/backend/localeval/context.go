package localeval

import (
	"context"
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/blinklabs-io/gouroboros/ledger/common"

	"github.com/Salvionied/apollo/v2/backend"
)

// LocalEvalChainContext wraps a ChainContext and evaluates scripts locally.
// Every other operation is delegated to the wrapped context unchanged.
type LocalEvalChainContext struct {
	inner      backend.ChainContext
	slotConfig *SlotConfig
}

var _ backend.ContextChainContext = (*LocalEvalChainContext)(nil)

// Option configures a LocalEvalChainContext.
type Option func(*LocalEvalChainContext)

// WithSlotConfig sets the slot-to-time mapping instead of deriving it from
// the wrapped context's genesis parameters.
func WithSlotConfig(config SlotConfig) Option {
	return func(c *LocalEvalChainContext) {
		c.slotConfig = &config
	}
}

// NewLocalEvalChainContext wraps inner so EvaluateTx runs locally.
//
// Protocol parameters come from inner on every evaluation. Inputs resolve
// from EvaluateTx's additional UTxOs first and inner's UtxoByRef second.
// Without WithSlotConfig, the slot mapping is the public network's when
// inner's genesis network magic names mainnet, preprod or preview; for any
// other network it starts at slot 0 at the genesis system start, which is
// correct only for networks that began in the Shelley era or later.
func NewLocalEvalChainContext(inner backend.ChainContext, opts ...Option) *LocalEvalChainContext {
	c := &LocalEvalChainContext{inner: inner}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// Unwrap returns the wrapped context.
func (c *LocalEvalChainContext) Unwrap() backend.ChainContext {
	return c.inner
}

// Capabilities adds evaluation to the wrapped context's capabilities when the
// wrapped context can supply what evaluation reads.
func (c *LocalEvalChainContext) Capabilities() backend.CapabilitySet {
	caps := backend.CapabilitiesOf(c.inner)
	if !caps.Has(backend.CapabilityProtocolParams) {
		return caps
	}
	if c.slotConfig == nil && !caps.Has(backend.CapabilityGenesisParams) {
		return caps
	}
	return caps | backend.CapabilitySet(backend.CapabilityEvaluateTx|backend.CapabilityEvaluateTxAdditionalUtxos)
}

func (c *LocalEvalChainContext) EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return c.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

// EvaluateTxContext evaluates txCbor's scripts locally. ctx bounds the
// parameter and UTxO queries made to the wrapped context; the script
// evaluation itself runs to completion once started.
func (c *LocalEvalChainContext) EvaluateTxContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	pp, err := backend.ProtocolParamsContext(ctx, c.inner)
	if err != nil {
		return nil, fmt.Errorf("protocol parameters: %w", err)
	}
	slots, err := c.slotConfigFor(ctx)
	if err != nil {
		return nil, err
	}
	additional, err := staticResolver(additionalUtxos)
	if err != nil {
		return nil, err
	}
	resolve := func(input common.TransactionInput) (common.Utxo, error) {
		if utxo, err := additional(input); err == nil {
			return utxo, nil
		}
		utxo, err := backend.UtxoByRefContext(ctx, c.inner, input.Id(), input.Index())
		if err != nil {
			return common.Utxo{}, fmt.Errorf("resolve %s: %w", input.String(), err)
		}
		if utxo == nil {
			return common.Utxo{}, fmt.Errorf("resolve %s: utxo not found", input.String())
		}
		return *utxo, nil
	}
	return evaluate(txCbor, resolve, Params{ProtocolParams: pp, SlotConfig: slots})
}

func (c *LocalEvalChainContext) slotConfigFor(ctx context.Context) (SlotConfig, error) {
	if c.slotConfig != nil {
		return *c.slotConfig, nil
	}
	gp, err := backend.GenesisParamsContext(ctx, c.inner)
	if err != nil {
		return SlotConfig{}, fmt.Errorf("genesis parameters: %w", err)
	}
	return slotConfigFromGenesis(gp)
}

func slotConfigFromGenesis(gp backend.GenesisParameters) (SlotConfig, error) {
	if magic := int64(gp.NetworkMagic); magic >= 0 && magic <= math.MaxUint32 {
		if config, ok := SlotConfigForNetworkMagic(uint32(magic)); ok {
			return config, nil
		}
	}
	if gp.SystemStart <= 0 {
		return SlotConfig{}, errors.New("genesis parameters have no system start")
	}
	if gp.SlotLength <= 0 {
		return SlotConfig{}, errors.New("genesis parameters have no slot length")
	}
	return SlotConfig{
		ZeroTime:   time.Unix(gp.SystemStart, 0).UTC(),
		SlotLength: time.Duration(gp.SlotLength) * time.Second,
	}, nil
}

func (c *LocalEvalChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return c.ProtocolParamsContext(context.Background())
}

func (c *LocalEvalChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	return backend.ProtocolParamsContext(ctx, c.inner)
}

func (c *LocalEvalChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return c.GenesisParamsContext(context.Background())
}

func (c *LocalEvalChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	return backend.GenesisParamsContext(ctx, c.inner)
}

func (c *LocalEvalChainContext) NetworkId() uint8 {
	return c.inner.NetworkId()
}

func (c *LocalEvalChainContext) CurrentEpoch() (uint64, error) {
	return c.CurrentEpochContext(context.Background())
}

func (c *LocalEvalChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	return backend.CurrentEpochContext(ctx, c.inner)
}

func (c *LocalEvalChainContext) MaxTxFee() (uint64, error) {
	return c.MaxTxFeeContext(context.Background())
}

func (c *LocalEvalChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	return backend.MaxTxFeeContext(ctx, c.inner)
}

func (c *LocalEvalChainContext) Tip() (uint64, error) {
	return c.TipContext(context.Background())
}

func (c *LocalEvalChainContext) TipContext(ctx context.Context) (uint64, error) {
	return backend.TipContext(ctx, c.inner)
}

func (c *LocalEvalChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return c.UtxosContext(context.Background(), address)
}

func (c *LocalEvalChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	return backend.UtxosContext(ctx, c.inner, address)
}

func (c *LocalEvalChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return c.SubmitTxContext(context.Background(), txCbor)
}

func (c *LocalEvalChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	return backend.SubmitTxContext(ctx, c.inner, txCbor)
}

func (c *LocalEvalChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return c.UtxoByRefContext(context.Background(), txHash, index)
}

func (c *LocalEvalChainContext) UtxoByRefContext(ctx context.Context, txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return backend.UtxoByRefContext(ctx, c.inner, txHash, index)
}

func (c *LocalEvalChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return c.ScriptCborContext(context.Background(), scriptHash)
}

func (c *LocalEvalChainContext) ScriptCborContext(ctx context.Context, scriptHash common.Blake2b224) ([]byte, error) {
	return backend.ScriptCborContext(ctx, c.inner, scriptHash)
}

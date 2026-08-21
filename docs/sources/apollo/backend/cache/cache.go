package cache

import (
	"context"
	"sync"
	"time"

	"github.com/blinklabs-io/gouroboros/ledger/common"

	"github.com/Salvionied/apollo/v2/backend"
)

// CachedChainContext wraps another ChainContext with time-based caching.
type CachedChainContext struct {
	inner backend.ChainContext
	ttl   time.Duration

	mu             sync.Mutex
	cachedParams   *backend.ProtocolParameters
	cachedGenesis  *backend.GenesisParameters
	paramsCacheAt  time.Time
	genesisCacheAt time.Time
}

var _ backend.ContextChainContext = (*CachedChainContext)(nil)

// NewCachedChainContext creates a new cached wrapper around the given ChainContext.
func NewCachedChainContext(inner backend.ChainContext, ttl time.Duration) *CachedChainContext {
	return &CachedChainContext{
		inner: inner,
		ttl:   ttl,
	}
}

// Capabilities preserves the feature set of the wrapped context.
func (c *CachedChainContext) Capabilities() backend.CapabilitySet {
	return backend.CapabilitiesOf(c.inner)
}

func (c *CachedChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	return c.ProtocolParamsContext(context.Background())
}

func (c *CachedChainContext) ProtocolParamsContext(ctx context.Context) (backend.ProtocolParameters, error) {
	c.mu.Lock()
	if c.cachedParams != nil && time.Since(c.paramsCacheAt) < c.ttl {
		pp := *c.cachedParams
		// Deep copy CostModels to prevent callers from mutating the cache.
		if pp.CostModels != nil {
			cm := make(map[string][]int64, len(pp.CostModels))
			for k, v := range pp.CostModels {
				dup := make([]int64, len(v))
				copy(dup, v)
				cm[k] = dup
			}
			pp.CostModels = cm
		}
		c.mu.Unlock()
		return pp, nil
	}
	c.mu.Unlock()

	pp, err := backend.ProtocolParamsContext(ctx, c.inner)
	if err != nil {
		return pp, err
	}

	// Deep copy CostModels before storing to prevent callers from mutating the cache.
	cached := pp
	if cached.CostModels != nil {
		cm := make(map[string][]int64, len(cached.CostModels))
		for k, v := range cached.CostModels {
			dup := make([]int64, len(v))
			copy(dup, v)
			cm[k] = dup
		}
		cached.CostModels = cm
	}

	c.mu.Lock()
	c.cachedParams = &cached
	c.paramsCacheAt = time.Now()
	c.mu.Unlock()

	return pp, nil
}

func (c *CachedChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return c.GenesisParamsContext(context.Background())
}

func (c *CachedChainContext) GenesisParamsContext(ctx context.Context) (backend.GenesisParameters, error) {
	c.mu.Lock()
	if c.cachedGenesis != nil && time.Since(c.genesisCacheAt) < c.ttl {
		gp := *c.cachedGenesis
		c.mu.Unlock()
		return gp, nil
	}
	c.mu.Unlock()

	gp, err := backend.GenesisParamsContext(ctx, c.inner)
	if err != nil {
		return gp, err
	}

	c.mu.Lock()
	c.cachedGenesis = &gp
	c.genesisCacheAt = time.Now()
	c.mu.Unlock()

	return gp, nil
}

func (c *CachedChainContext) NetworkId() uint8 {
	return c.inner.NetworkId()
}

func (c *CachedChainContext) CurrentEpoch() (uint64, error) {
	return c.CurrentEpochContext(context.Background())
}

func (c *CachedChainContext) CurrentEpochContext(ctx context.Context) (uint64, error) {
	return backend.CurrentEpochContext(ctx, c.inner)
}

func (c *CachedChainContext) MaxTxFee() (uint64, error) {
	return c.MaxTxFeeContext(context.Background())
}

func (c *CachedChainContext) MaxTxFeeContext(ctx context.Context) (uint64, error) {
	return backend.MaxTxFeeContext(ctx, c.inner)
}

func (c *CachedChainContext) Tip() (uint64, error) {
	return c.TipContext(context.Background())
}

func (c *CachedChainContext) TipContext(ctx context.Context) (uint64, error) {
	return backend.TipContext(ctx, c.inner)
}

func (c *CachedChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return c.UtxosContext(context.Background(), address)
}

func (c *CachedChainContext) UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error) {
	return backend.UtxosContext(ctx, c.inner, address)
}

func (c *CachedChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return c.SubmitTxContext(context.Background(), txCbor)
}

func (c *CachedChainContext) SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error) {
	return backend.SubmitTxContext(ctx, c.inner, txCbor)
}

func (c *CachedChainContext) EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return c.EvaluateTxContext(context.Background(), txCbor, additionalUtxos)
}

func (c *CachedChainContext) EvaluateTxContext(
	ctx context.Context,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	return backend.EvaluateTxContext(ctx, c.inner, txCbor, additionalUtxos)
}

func (c *CachedChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return c.UtxoByRefContext(context.Background(), txHash, index)
}

func (c *CachedChainContext) UtxoByRefContext(
	ctx context.Context,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	return backend.UtxoByRefContext(ctx, c.inner, txHash, index)
}

func (c *CachedChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return c.ScriptCborContext(context.Background(), scriptHash)
}

func (c *CachedChainContext) ScriptCborContext(
	ctx context.Context,
	scriptHash common.Blake2b224,
) ([]byte, error) {
	return backend.ScriptCborContext(ctx, c.inner, scriptHash)
}

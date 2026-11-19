package backend

import (
	"bytes"
	"context"
	"errors"
	"fmt"

	"github.com/blinklabs-io/gouroboros/ledger/common"

	"github.com/Salvionied/apollo/v2/internal/scriptutil"
)

var errNilChainContext = errors.New("chain context is nil")

// ContextChainContext is an optional extension to ChainContext for operations
// that can block. Implementations should stop work promptly when ctx is
// canceled. It is separate from ChainContext so existing third-party backends
// remain source compatible.
type ContextChainContext interface {
	ProtocolParamsContext(ctx context.Context) (ProtocolParameters, error)
	GenesisParamsContext(ctx context.Context) (GenesisParameters, error)
	CurrentEpochContext(ctx context.Context) (uint64, error)
	MaxTxFeeContext(ctx context.Context) (uint64, error)
	TipContext(ctx context.Context) (uint64, error)
	UtxosContext(ctx context.Context, address common.Address) ([]common.Utxo, error)
	SubmitTxContext(ctx context.Context, txCbor []byte) (common.Blake2b256, error)
	EvaluateTxContext(ctx context.Context, txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error)
	UtxoByRefContext(ctx context.Context, txHash common.Blake2b256, index uint32) (*common.Utxo, error)
	ScriptCborContext(ctx context.Context, scriptHash common.Blake2b224) ([]byte, error)
}

func normalizeContext(ctx context.Context) context.Context {
	if ctx == nil {
		return context.Background()
	}
	return ctx
}

// ProtocolParamsContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func ProtocolParamsContext(ctx context.Context, chainContext ChainContext) (ProtocolParameters, error) {
	if isNilInterface(chainContext) {
		return ProtocolParameters{}, errNilChainContext
	}
	if cc, ok := chainContext.(ContextChainContext); ok {
		return cc.ProtocolParamsContext(normalizeContext(ctx))
	}
	return chainContext.ProtocolParams()
}

// GenesisParamsContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func GenesisParamsContext(ctx context.Context, chainContext ChainContext) (GenesisParameters, error) {
	if isNilInterface(chainContext) {
		return GenesisParameters{}, errNilChainContext
	}
	if cc, ok := chainContext.(ContextChainContext); ok {
		return cc.GenesisParamsContext(normalizeContext(ctx))
	}
	return chainContext.GenesisParams()
}

// CurrentEpochContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func CurrentEpochContext(ctx context.Context, chainContext ChainContext) (uint64, error) {
	if isNilInterface(chainContext) {
		return 0, errNilChainContext
	}
	if cc, ok := chainContext.(ContextChainContext); ok {
		return cc.CurrentEpochContext(normalizeContext(ctx))
	}
	return chainContext.CurrentEpoch()
}

// MaxTxFeeContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func MaxTxFeeContext(ctx context.Context, chainContext ChainContext) (uint64, error) {
	if isNilInterface(chainContext) {
		return 0, errNilChainContext
	}
	if cc, ok := chainContext.(ContextChainContext); ok {
		return cc.MaxTxFeeContext(normalizeContext(ctx))
	}
	return chainContext.MaxTxFee()
}

// TipContext calls the context-aware implementation when available, otherwise
// it falls back to the historic ChainContext method.
func TipContext(ctx context.Context, chainContext ChainContext) (uint64, error) {
	if isNilInterface(chainContext) {
		return 0, errNilChainContext
	}
	if cc, ok := chainContext.(ContextChainContext); ok {
		return cc.TipContext(normalizeContext(ctx))
	}
	return chainContext.Tip()
}

// UtxosContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func UtxosContext(ctx context.Context, chainContext ChainContext, address common.Address) ([]common.Utxo, error) {
	if isNilInterface(chainContext) {
		return nil, errNilChainContext
	}
	if cc, ok := chainContext.(ContextChainContext); ok {
		return cc.UtxosContext(normalizeContext(ctx), address)
	}
	return chainContext.Utxos(address)
}

// SubmitTxContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func SubmitTxContext(ctx context.Context, chainContext ChainContext, txCbor []byte) (common.Blake2b256, error) {
	if isNilInterface(chainContext) {
		return common.Blake2b256{}, errNilChainContext
	}
	want, parseErr := submittedTxID(txCbor)
	submitted := bytes.Clone(txCbor)
	var result common.Blake2b256
	var err error
	if cc, ok := chainContext.(ContextChainContext); ok {
		result, err = cc.SubmitTxContext(normalizeContext(ctx), submitted)
	} else {
		result, err = chainContext.SubmitTx(submitted)
	}
	if err != nil {
		return common.Blake2b256{}, err
	}
	if parseErr != nil {
		return common.Blake2b256{}, parseErr
	}
	if err := verifySubmittedTxID(want, result); err != nil {
		return common.Blake2b256{}, err
	}
	return result, nil
}

// EvaluateTxContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func EvaluateTxContext(
	ctx context.Context,
	chainContext ChainContext,
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	if isNilInterface(chainContext) {
		return nil, errNilChainContext
	}
	if cc, ok := chainContext.(ContextChainContext); ok {
		return cc.EvaluateTxContext(normalizeContext(ctx), txCbor, additionalUtxos)
	}
	return chainContext.EvaluateTx(txCbor, additionalUtxos)
}

// UtxoByRefContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func UtxoByRefContext(
	ctx context.Context,
	chainContext ChainContext,
	txHash common.Blake2b256,
	index uint32,
) (*common.Utxo, error) {
	if isNilInterface(chainContext) {
		return nil, errNilChainContext
	}
	var utxo *common.Utxo
	var err error
	if cc, ok := chainContext.(ContextChainContext); ok {
		utxo, err = cc.UtxoByRefContext(normalizeContext(ctx), txHash, index)
	} else {
		utxo, err = chainContext.UtxoByRef(txHash, index)
	}
	if err != nil {
		return nil, err
	}
	if err := ValidateUtxoRef(utxo, txHash, index); err != nil {
		return nil, err
	}
	return utxo, nil
}

// ValidateUtxoRef rejects a lookup result that does not match its requested reference.
func ValidateUtxoRef(utxo *common.Utxo, txHash common.Blake2b256, index uint32) error {
	if utxo == nil {
		return nil
	}
	if isNilInterface(utxo.Id) {
		return errors.New("provider returned UTxO without a reference")
	}
	if utxo.Id.Id() != txHash || utxo.Id.Index() != index {
		return fmt.Errorf("provider returned UTxO %x#%d for requested %x#%d",
			utxo.Id.Id().Bytes(), utxo.Id.Index(), txHash.Bytes(), index)
	}
	return nil
}

// ScriptCborContext calls the context-aware implementation when available,
// otherwise it falls back to the historic ChainContext method.
func ScriptCborContext(
	ctx context.Context,
	chainContext ChainContext,
	scriptHash common.Blake2b224,
) ([]byte, error) {
	if isNilInterface(chainContext) {
		return nil, errNilChainContext
	}
	var scriptCbor []byte
	var err error
	if cc, ok := chainContext.(ContextChainContext); ok {
		scriptCbor, err = cc.ScriptCborContext(normalizeContext(ctx), scriptHash)
	} else {
		scriptCbor, err = chainContext.ScriptCbor(scriptHash)
	}
	if err != nil {
		return nil, err
	}
	scriptCbor = bytes.Clone(scriptCbor)
	if _, err := scriptutil.ScriptRefFromHash(scriptHash, scriptCbor); err != nil {
		return nil, err
	}
	return scriptCbor, nil
}

// BindContext returns a ChainContext whose blocking methods dispatch through
// ctx. This is useful when passing a context through an API that still accepts
// only the historic ChainContext interface.
func BindContext(ctx context.Context, chainContext ChainContext) ChainContext {
	return boundChainContext{
		Context:      normalizeContext(ctx),
		ChainContext: chainContext,
	}
}

type boundChainContext struct {
	context.Context
	ChainContext
}

func (b boundChainContext) Capabilities() CapabilitySet {
	return CapabilitiesOf(b.ChainContext)
}

func (b boundChainContext) ProtocolParams() (ProtocolParameters, error) {
	return ProtocolParamsContext(b.Context, b.ChainContext)
}

func (b boundChainContext) GenesisParams() (GenesisParameters, error) {
	return GenesisParamsContext(b.Context, b.ChainContext)
}

func (b boundChainContext) CurrentEpoch() (uint64, error) {
	return CurrentEpochContext(b.Context, b.ChainContext)
}

func (b boundChainContext) MaxTxFee() (uint64, error) {
	return MaxTxFeeContext(b.Context, b.ChainContext)
}

func (b boundChainContext) Tip() (uint64, error) {
	return TipContext(b.Context, b.ChainContext)
}

func (b boundChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	return UtxosContext(b.Context, b.ChainContext, address)
}

func (b boundChainContext) SubmitTx(txCbor []byte) (common.Blake2b256, error) {
	return SubmitTxContext(b.Context, b.ChainContext, txCbor)
}

func (b boundChainContext) EvaluateTx(
	txCbor []byte,
	additionalUtxos []common.Utxo,
) (map[common.RedeemerKey]common.ExUnits, error) {
	return EvaluateTxContext(b.Context, b.ChainContext, txCbor, additionalUtxos)
}

func (b boundChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	return UtxoByRefContext(b.Context, b.ChainContext, txHash, index)
}

func (b boundChainContext) ScriptCbor(scriptHash common.Blake2b224) ([]byte, error) {
	return ScriptCborContext(b.Context, b.ChainContext, scriptHash)
}

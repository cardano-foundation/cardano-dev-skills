package fixed

import (
	"encoding/hex"
	"errors"
	"math/big"
	"strconv"
	"sync"

	"github.com/blinklabs-io/gouroboros/ledger/common"

	"github.com/Salvionied/apollo/v2/backend"
)

// FixedChainContext is a backend with preset protocol/genesis parameters and UTxOs.
// Useful for testing without a live chain connection.
type FixedChainContext struct {
	protocolParams backend.ProtocolParameters
	genesisParams  backend.GenesisParameters
	networkId      uint8
	mu             sync.RWMutex
	utxos          map[string][]common.Utxo // keyed by address string
	utxosByRef     map[string]common.Utxo   // keyed by "txid#index"
}

// Capabilities reports the deterministic in-memory operations provided by the
// fixed test context. It intentionally does not pretend to be a chain node.
func (f *FixedChainContext) Capabilities() backend.CapabilitySet {
	return backend.CapabilitySet(backend.CapabilityProtocolParams |
		backend.CapabilityGenesisParams |
		backend.CapabilityMaxTxFee |
		backend.CapabilityUtxos |
		backend.CapabilityUtxoByRef)
}

// NewFixedChainContext creates a new FixedChainContext with the given protocol parameters.
func NewFixedChainContext(pp backend.ProtocolParameters, gp backend.GenesisParameters, networkId uint8) *FixedChainContext {
	return &FixedChainContext{
		protocolParams: pp,
		genesisParams:  gp,
		networkId:      networkId,
		utxos:          make(map[string][]common.Utxo),
		utxosByRef:     make(map[string]common.Utxo),
	}
}

// NewEmptyFixedChainContext creates a FixedChainContext with default preprod parameters.
func NewEmptyFixedChainContext() *FixedChainContext {
	pp := backend.ProtocolParameters{
		MinFeeConstant:      155381,
		MinFeeCoefficient:   44,
		MaxTxSize:           16384,
		CoinsPerUtxoByte:    "4310",
		CollateralPercent:   150,
		MaxCollateralInputs: 3,
		MaxValSize:          "5000",
		PriceMem:            0.0577,
		PriceStep:           0.0000721,
		MaxTxExMem:          "14000000",
		MaxTxExSteps:        "10000000000",
		KeyDeposits:         "2000000",
		PoolDeposits:        "500000000",
		// Conway reference-script base price (lovelace per byte), current value.
		MinFeeRefScriptCostPerByte: 15,
	}
	gp := backend.GenesisParameters{
		NetworkMagic: 1,
	}
	return NewFixedChainContext(pp, gp, 0)
}

// AddUtxo adds a UTxO to the fixed context for the given address. It is also
// registered for resolution by reference (UtxoByRef), so it can be used as a
// reference input.
func (f *FixedChainContext) AddUtxo(addr common.Address, utxo common.Utxo) {
	f.mu.Lock()
	defer f.mu.Unlock()
	key := addr.String()
	f.utxos[key] = append(f.utxos[key], utxo)
	f.utxosByRef[utxoRefKey(utxo.Id.Id(), utxo.Id.Index())] = utxo
}

// AddUtxoByRef registers a UTxO for resolution by reference (UtxoByRef) only,
// without adding it to any address's spendable UTxO set. Useful for reference
// inputs, which are read but not spent.
func (f *FixedChainContext) AddUtxoByRef(utxo common.Utxo) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.utxosByRef[utxoRefKey(utxo.Id.Id(), utxo.Id.Index())] = utxo
}

func utxoRefKey(txHash common.Blake2b256, index uint32) string {
	return hex.EncodeToString(txHash.Bytes()) + "#" + strconv.Itoa(int(index))
}

func (f *FixedChainContext) ProtocolParams() (backend.ProtocolParameters, error) {
	pp := f.protocolParams
	if pp.CostModels != nil {
		cm := make(map[string][]int64, len(pp.CostModels))
		for k, v := range pp.CostModels {
			dup := make([]int64, len(v))
			copy(dup, v)
			cm[k] = dup
		}
		pp.CostModels = cm
	}
	if pp.MinFeeRefScriptCostPerByteRational != nil {
		pp.MinFeeRefScriptCostPerByteRational = new(big.Rat).Set(pp.MinFeeRefScriptCostPerByteRational)
	}
	if pp.MinFeeReferenceScriptsMultiplierRational != nil {
		pp.MinFeeReferenceScriptsMultiplierRational = new(big.Rat).Set(pp.MinFeeReferenceScriptsMultiplierRational)
	}
	return pp, nil
}

func (f *FixedChainContext) GenesisParams() (backend.GenesisParameters, error) {
	return f.genesisParams, nil
}

func (f *FixedChainContext) NetworkId() uint8 {
	return f.networkId
}

func (f *FixedChainContext) CurrentEpoch() (uint64, error) {
	// Preserve the fixed context's historic deterministic placeholder. It is
	// intentionally not reported as CapabilityCurrentEpoch because it is not
	// derived from chain state.
	return 0, nil
}

func (f *FixedChainContext) MaxTxFee() (uint64, error) {
	pp, err := f.ProtocolParams()
	if err != nil {
		return 0, err
	}
	return backend.ComputeMaxTxFee(pp)
}

func (f *FixedChainContext) Tip() (uint64, error) {
	// Preserve the fixed context's historic deterministic placeholder. It is
	// intentionally not reported as CapabilityTip because it is not derived
	// from chain state.
	return 0, nil
}

func (f *FixedChainContext) Utxos(address common.Address) ([]common.Utxo, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	src := f.utxos[address.String()]
	result := make([]common.Utxo, len(src))
	copy(result, src)
	return result, nil
}

func (f *FixedChainContext) SubmitTx(_ []byte) (common.Blake2b256, error) {
	return common.Blake2b256{}, backend.NewUnsupportedError("fixed chain context", backend.CapabilitySubmitTx)
}

func (f *FixedChainContext) EvaluateTx(_ []byte, _ []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error) {
	return nil, backend.NewUnsupportedError("fixed chain context", backend.CapabilityEvaluateTx)
}

func (f *FixedChainContext) UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	if utxo, ok := f.utxosByRef[utxoRefKey(txHash, index)]; ok {
		u := utxo
		return &u, nil
	}
	return nil, errors.New("utxo not found in fixed chain context")
}

func (f *FixedChainContext) ScriptCbor(_ common.Blake2b224) ([]byte, error) {
	return nil, backend.NewUnsupportedError("fixed chain context", backend.CapabilityScriptCbor)
}

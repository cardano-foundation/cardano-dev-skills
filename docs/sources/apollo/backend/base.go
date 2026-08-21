package backend

import (
	"errors"
	"fmt"
	"math"
	"math/big"
	"reflect"
	"strconv"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// Capability identifies an optional ChainContext operation. A ChainContext
// always has the corresponding method for source compatibility, but a
// particular backend may not be able to implement every operation.
type Capability uint32

const (
	CapabilityProtocolParams Capability = 1 << iota
	CapabilityGenesisParams
	CapabilityCurrentEpoch
	CapabilityMaxTxFee
	CapabilityTip
	CapabilityUtxos
	CapabilitySubmitTx
	CapabilityEvaluateTx
	// CapabilityEvaluateTxAdditionalUtxos indicates that EvaluateTx honours
	// its additionalUtxos argument for off-chain or chained inputs.
	CapabilityEvaluateTxAdditionalUtxos
	CapabilityUtxoByRef
	CapabilityScriptCbor
)

// AllCapabilities is the set implied by the historic ChainContext contract.
// It is used for contexts that do not opt into CapabilityReporter so existing
// third-party implementations remain source- and behavior-compatible.
const AllCapabilities = CapabilityProtocolParams |
	CapabilityGenesisParams |
	CapabilityCurrentEpoch |
	CapabilityMaxTxFee |
	CapabilityTip |
	CapabilityUtxos |
	CapabilitySubmitTx |
	CapabilityEvaluateTx |
	CapabilityEvaluateTxAdditionalUtxos |
	CapabilityUtxoByRef |
	CapabilityScriptCbor

// CapabilitySet is a bit set of backend capabilities.
type CapabilitySet uint32

// Has reports whether every requested capability is present.
func (s CapabilitySet) Has(capability Capability) bool {
	return Capability(s)&capability == capability
}

// CapabilityReporter is an optional extension to ChainContext. It is kept
// separate from ChainContext so implementations outside this module are not
// forced to add a method when capability reporting is introduced.
type CapabilityReporter interface {
	Capabilities() CapabilitySet
}

// CapabilitiesOf returns the capabilities reported by ctx. Contexts that do
// not implement CapabilityReporter are treated as supporting the historic
// complete ChainContext contract.
func CapabilitiesOf(ctx ChainContext) CapabilitySet {
	if isNilInterface(ctx) {
		return 0
	}
	if reporter, ok := ctx.(CapabilityReporter); ok {
		return reporter.Capabilities()
	}
	return CapabilitySet(AllCapabilities)
}

// Supports reports whether ctx reports support for every requested capability.
func Supports(ctx ChainContext, capability Capability) bool {
	return CapabilitiesOf(ctx).Has(capability)
}

func (c Capability) String() string {
	switch c {
	case CapabilityProtocolParams:
		return "protocol parameter queries"
	case CapabilityGenesisParams:
		return "genesis parameter queries"
	case CapabilityCurrentEpoch:
		return "current epoch queries"
	case CapabilityMaxTxFee:
		return "maximum transaction fee queries"
	case CapabilityTip:
		return "chain tip queries"
	case CapabilityUtxos:
		return "address UTxO queries"
	case CapabilitySubmitTx:
		return "transaction submission"
	case CapabilityEvaluateTx:
		return "transaction evaluation"
	case CapabilityEvaluateTxAdditionalUtxos:
		return "transaction evaluation with additional UTxOs"
	case CapabilityUtxoByRef:
		return "UTxO reference queries"
	case CapabilityScriptCbor:
		return "script CBOR lookup"
	default:
		return fmt.Sprintf("unknown capability (%d)", c)
	}
}

// ErrUnsupported is returned when a ChainContext operation cannot be
// implemented by its backend. Use errors.Is to check the category and
// errors.As with UnsupportedError to inspect the operation.
var ErrUnsupported = errors.New("backend operation unsupported")

// UnsupportedError identifies a backend operation that is unavailable.
type UnsupportedError struct {
	Backend    string
	Capability Capability
}

func (e *UnsupportedError) Error() string {
	if e == nil {
		return ""
	}
	if e.Backend == "" {
		return fmt.Sprintf("%s is unsupported", e.Capability)
	}
	return fmt.Sprintf("%s does not support %s", e.Backend, e.Capability)
}

// Unwrap lets callers use errors.Is(err, ErrUnsupported).
func (e *UnsupportedError) Unwrap() error {
	return ErrUnsupported
}

// NewUnsupportedError constructs an error for an unavailable backend
// capability. Backends should return this instead of a provider-specific
// message when support is known to be absent locally.
func NewUnsupportedError(backendName string, capability Capability) *UnsupportedError {
	return &UnsupportedError{Backend: backendName, Capability: capability}
}

// ChainContext provides an interface for interacting with a Cardano blockchain.
type ChainContext interface {
	ProtocolParams() (ProtocolParameters, error)
	GenesisParams() (GenesisParameters, error)
	NetworkId() uint8
	CurrentEpoch() (uint64, error)
	MaxTxFee() (uint64, error)
	Tip() (uint64, error)
	Utxos(address common.Address) ([]common.Utxo, error)
	SubmitTx(txCbor []byte) (common.Blake2b256, error)
	// EvaluateTx evaluates the scripts in a transaction and returns the
	// execution units required by each redeemer. additionalUtxos is a set of
	// resolved UTxOs supplied to the evaluator (e.g. spending inputs that are
	// not yet confirmed on-chain, such as off-chain or chained inputs), so that
	// script execution-unit estimation can resolve inputs the backend cannot
	// see on-chain. Callers that require additional UTxOs to be considered must
	// check CapabilityEvaluateTxAdditionalUtxos before relying on this behavior.
	// Backends that do not report that capability may ignore additionalUtxos or
	// return ErrUnsupported when the argument is non-empty.
	EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error)
	UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error)
	ScriptCbor(scriptHash common.Blake2b224) ([]byte, error)
}

// ValidateAdditionalUtxo verifies that a resolved UTxO has both pieces needed
// by backend evaluation APIs. TransactionInput and TransactionOutput are
// interfaces, so this also rejects typed nil pointers stored in either field.
func ValidateAdditionalUtxo(utxo common.Utxo) error {
	if isNilInterface(utxo.Id) {
		return errors.New("additional UTxO is missing transaction input")
	}
	if isNilInterface(utxo.Output) {
		return errors.New("additional UTxO is missing transaction output")
	}
	return nil
}

func isNilInterface(value any) bool {
	if value == nil {
		return true
	}

	valueOf := reflect.ValueOf(value)
	switch valueOf.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Pointer, reflect.Slice:
		return valueOf.IsNil()
	default:
		return false
	}
}

// GenesisParameters holds Cardano genesis configuration values.
type GenesisParameters struct {
	ActiveSlotsCoefficient float64 `json:"active_slots_coefficient"`
	UpdateQuorum           int     `json:"update_quorum"`
	MaxLovelaceSupply      string  `json:"max_lovelace_supply"`
	NetworkMagic           int     `json:"network_magic"`
	EpochLength            int     `json:"epoch_length"`
	SystemStart            int64   `json:"system_start"`
	SlotsPerKesPeriod      int     `json:"slots_per_kes_period"`
	SlotLength             int     `json:"slot_length"`
	MaxKesEvolutions       int     `json:"max_kes_evolutions"`
	SecurityParam          int     `json:"security_param"`
}

// ProtocolParameters holds the current Cardano protocol parameters.
type ProtocolParameters struct {
	MinFeeConstant                   int64              `json:"min_fee_b"`
	MinFeeCoefficient                int64              `json:"min_fee_a"`
	MaxBlockSize                     int                `json:"max_block_size"`
	MaxTxSize                        int                `json:"max_tx_size"`
	MaxBlockHeaderSize               int                `json:"max_block_header_size"`
	KeyDeposits                      string             `json:"key_deposit"`
	PoolDeposits                     string             `json:"pool_deposit"`
	PoolInfluence                    float64            `json:"a0"`
	MonetaryExpansion                float64            `json:"rho"`
	TreasuryExpansion                float64            `json:"tau"`
	DecentralizationParam            float64            `json:"decentralisation_param"`
	ExtraEntropy                     string             `json:"extra_entropy"`
	ProtocolMajorVersion             int                `json:"protocol_major_ver"`
	ProtocolMinorVersion             int                `json:"protocol_minor_ver"`
	MinUtxo                          string             `json:"min_utxo"`
	MinPoolCost                      string             `json:"min_pool_cost"`
	PriceMem                         float64            `json:"price_mem"`
	PriceStep                        float64            `json:"price_step"`
	MaxTxExMem                       string             `json:"max_tx_ex_mem"`
	MaxTxExSteps                     string             `json:"max_tx_ex_steps"`
	MaxBlockExMem                    string             `json:"max_block_ex_mem"`
	MaxBlockExSteps                  string             `json:"max_block_ex_steps"`
	MaxValSize                       string             `json:"max_val_size"`
	CollateralPercent                int                `json:"collateral_percent"`
	MaxCollateralInputs              int                `json:"max_collateral_inputs"`
	CoinsPerUtxoWord                 string             `json:"coins_per_utxo_word"`
	CoinsPerUtxoByte                 string             `json:"coins_per_utxo_byte"`
	CostModels                       map[string][]int64 `json:"cost_models"`
	MaximumReferenceScriptsSize      int                `json:"maximum_reference_scripts_size"`
	MinFeeReferenceScriptsRange      int                `json:"min_fee_reference_scripts_range"`
	MinFeeReferenceScriptsBase       int                `json:"min_fee_reference_scripts_base"`
	MinFeeReferenceScriptsMultiplier int                `json:"min_fee_reference_scripts_multiplier"`
	// MinFeeRefScriptCostPerByteRational preserves the exact provider-supplied
	// first-tier reference-script price. It takes precedence over the legacy
	// float64 field below when computing transaction fees.
	MinFeeRefScriptCostPerByteRational *big.Rat `json:"-"`
	// MinFeeReferenceScriptsMultiplierRational preserves the exact
	// provider-supplied per-tier multiplier. It takes precedence over the
	// legacy integer field above when computing transaction fees.
	MinFeeReferenceScriptsMultiplierRational *big.Rat `json:"-"`
	// MinFeeRefScriptCostPerByte is the BlockFrost/ledger flat name for the
	// reference-script base price (lovelace per byte for the first tier). Some
	// providers (e.g. BlockFrost) expose only this field and not the structured
	// MinFeeReferenceScripts{Base,Range,Multiplier} triple. It is retained for
	// compatibility; use MinFeeRefScriptCostPerByteRational for fee computation
	// when a provider supplies a fractional value.
	MinFeeRefScriptCostPerByte float64 `json:"min_fee_ref_script_cost_per_byte"`
}

// Conway reference-script fee tier constants. The ledger prices reference
// scripts on a growing tier: the first SizeIncrement bytes cost the base
// price per byte, and each subsequent tier of SizeIncrement bytes is priced
// at the previous tier's price multiplied by Multiplier. These two values are
// ledger constants (not surfaced by every provider), so they are defaulted
// when a provider does not supply them.
const (
	DefaultRefScriptSizeIncrement = 25600
	DefaultRefScriptMultiplier    = 1.2
	defaultRefScriptMultiplierNum = 6
	defaultRefScriptMultiplierDen = 5
)

// RefScriptFeePerByte returns the base reference-script price (lovelace per
// byte for the first tier), preferring the structured MinFeeReferenceScriptsBase
// when present and falling back to the flat MinFeeRefScriptCostPerByte.
// It is retained for compatibility; fee computation should use
// RefScriptFeePerByteRational to avoid precision loss.
func (p ProtocolParameters) RefScriptFeePerByte() float64 {
	r := p.RefScriptFeePerByteRational()
	if r == nil {
		return 0
	}
	value, _ := r.Float64()
	return value
}

// RefScriptFeePerByteRational returns the exact first-tier reference-script
// price. The returned rational is a copy and may be safely modified by callers.
func (p ProtocolParameters) RefScriptFeePerByteRational() *big.Rat {
	if p.MinFeeReferenceScriptsBase > 0 {
		return big.NewRat(int64(p.MinFeeReferenceScriptsBase), 1)
	}
	if p.MinFeeRefScriptCostPerByteRational != nil {
		return new(big.Rat).Set(p.MinFeeRefScriptCostPerByteRational)
	}
	return rationalFromFloat64(p.MinFeeRefScriptCostPerByte)
}

// RefScriptSizeIncrement returns the per-tier size increment, defaulting to the
// Conway ledger constant when a provider does not supply it.
func (p ProtocolParameters) RefScriptSizeIncrement() int {
	if p.MinFeeReferenceScriptsRange > 0 {
		return p.MinFeeReferenceScriptsRange
	}
	return DefaultRefScriptSizeIncrement
}

// RefScriptMultiplier returns the per-tier price multiplier, defaulting to the
// Conway ledger constant when a provider does not supply it.
// It is retained for compatibility; fee computation should use
// RefScriptMultiplierRational to avoid precision loss.
func (p ProtocolParameters) RefScriptMultiplier() float64 {
	value, _ := p.RefScriptMultiplierRational().Float64()
	return value
}

// RefScriptMultiplierRational returns the exact per-tier reference-script
// multiplier. The returned rational is a copy and may be safely modified by
// callers.
func (p ProtocolParameters) RefScriptMultiplierRational() *big.Rat {
	if p.MinFeeReferenceScriptsMultiplierRational != nil && p.MinFeeReferenceScriptsMultiplierRational.Sign() > 0 {
		return new(big.Rat).Set(p.MinFeeReferenceScriptsMultiplierRational)
	}
	if p.MinFeeReferenceScriptsMultiplier > 0 {
		return big.NewRat(int64(p.MinFeeReferenceScriptsMultiplier), 1)
	}
	return big.NewRat(defaultRefScriptMultiplierNum, defaultRefScriptMultiplierDen)
}

// TierRefScriptFee computes the Conway tiered reference-script fee for a total
// reference-script byte size, matching the ledger's tierRefScriptFee function:
//
//	go acc curTierPrice n
//	  | n < sizeIncrement = floor(acc + n*curTierPrice)
//	  | otherwise         = go (acc + sizeIncrement*curTierPrice)
//	                           (curTierPrice*multiplier) (n - sizeIncrement)
//
// with the first-tier price = baseFeePerByte. A zero base price yields a zero
// fee (pre-Conway / provider that does not charge for reference scripts).
//
// The float64 arguments are retained for compatibility. New code should use
// TierRefScriptFeeRational so provider-supplied fractions never pass through a
// float64. The decimal representation of the legacy floats is converted to an
// exact rational without quantizing the multiplier.
func TierRefScriptFee(totalRefScriptSize int, baseFeePerByte float64, sizeIncrement int, multiplier float64) int64 {
	base := rationalFromFloat64(baseFeePerByte)
	m := rationalFromFloat64(multiplier)
	return TierRefScriptFeeRational(totalRefScriptSize, base, sizeIncrement, m)
}

// TierRefScriptFeeRational computes the Conway tiered reference-script fee
// using exact provider-supplied rational values. The result is the ledger's
// floor of the final accumulated rational fee.
func TierRefScriptFeeRational(totalRefScriptSize int, baseFeePerByte *big.Rat, sizeIncrement int, multiplier *big.Rat) int64 {
	if totalRefScriptSize <= 0 || baseFeePerByte == nil || baseFeePerByte.Sign() <= 0 {
		return 0
	}
	if sizeIncrement <= 0 {
		sizeIncrement = DefaultRefScriptSizeIncrement
	}
	if multiplier == nil || multiplier.Sign() <= 0 {
		multiplier = big.NewRat(defaultRefScriptMultiplierNum, defaultRefScriptMultiplierDen)
	}
	acc := new(big.Rat)
	price := new(big.Rat).Set(baseFeePerByte)
	incr := new(big.Rat).SetInt64(int64(sizeIncrement))
	n := totalRefScriptSize
	for n >= sizeIncrement {
		acc.Add(acc, new(big.Rat).Mul(incr, price))
		price.Mul(price, multiplier)
		n -= sizeIncrement
	}
	if n > 0 {
		acc.Add(acc, new(big.Rat).Mul(new(big.Rat).SetInt64(int64(n)), price))
	}
	// floor(acc): acc is non-negative, so integer division of num/denom truncates
	// toward zero, i.e. floors.
	result := new(big.Int).Quo(acc.Num(), acc.Denom())
	if !result.IsInt64() {
		// A negative fee would be catastrophic: callers could treat it as a
		// credit and construct an underpriced transaction. The public helper
		// predates error returns, so saturate at MaxInt64 and let fee validation
		// reject the impossible result upstream.
		return math.MaxInt64
	}
	return result.Int64()
}

func rationalFromFloat64(value float64) *big.Rat {
	if math.IsNaN(value) || math.IsInf(value, 0) {
		return nil
	}
	// FormatFloat's shortest decimal is the value callers passed to the legacy
	// API, rather than an arbitrary fixed-precision approximation.
	rational, ok := new(big.Rat).SetString(strconv.FormatFloat(value, 'g', -1, 64))
	if !ok {
		return nil
	}
	return rational
}

// CoinsPerUtxoByteValue returns the coins per UTxO byte value parsed from the string field.
// Negative or absurdly large values (which would corrupt min-UTxO math downstream)
// fall back to the protocol default.
func (p ProtocolParameters) CoinsPerUtxoByteValue() int64 {
	if p.CoinsPerUtxoByte != "" {
		v, err := strconv.ParseInt(p.CoinsPerUtxoByte, 10, 64)
		if err == nil && v >= 0 && v <= 1_000_000_000 {
			return v
		}
	}
	return 4310 // default fallback
}

// ComputeMaxTxFee computes the maximum transaction fee from protocol parameters,
// validating that all values are non-negative before the calculation.
func ComputeMaxTxFee(pp ProtocolParameters) (uint64, error) {
	if pp.MaxTxSize < 0 || pp.MinFeeCoefficient < 0 || pp.MinFeeConstant < 0 {
		return 0, fmt.Errorf("invalid protocol parameters: MaxTxSize=%d, MinFeeCoefficient=%d, MinFeeConstant=%d",
			pp.MaxTxSize, pp.MinFeeCoefficient, pp.MinFeeConstant)
	}
	size := uint64(pp.MaxTxSize)          //nolint:gosec // validated non-negative above
	coeff := uint64(pp.MinFeeCoefficient) //nolint:gosec // validated non-negative above
	constant := uint64(pp.MinFeeConstant) //nolint:gosec // validated non-negative above
	// Bound the result to MaxInt64 so callers can safely use it in signed
	// arithmetic; values that large indicate corrupt protocol parameters.
	if size != 0 && coeff > (math.MaxInt64-constant)/size {
		return 0, fmt.Errorf("max tx fee overflows: MaxTxSize=%d, MinFeeCoefficient=%d, MinFeeConstant=%d",
			pp.MaxTxSize, pp.MinFeeCoefficient, pp.MinFeeConstant)
	}
	return size*coeff + constant, nil
}

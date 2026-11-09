package ouroboros

import (
	"bytes"
	"cmp"
	"errors"
	"fmt"
	"math"
	"math/big"
	"slices"
	"strconv"
	"time"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/conway"
	"github.com/blinklabs-io/gouroboros/ledger/dijkstra"
	"github.com/blinklabs-io/gouroboros/ledger/shelley"
	"github.com/blinklabs-io/gouroboros/protocol/localstatequery"

	"github.com/Salvionied/apollo/v2/backend"
	"github.com/Salvionied/apollo/v2/internal/backendutil"
)

// conwayMaxRefScriptSizePerTx is the Conway ledger's limit on the total size
// of the reference scripts a transaction uses. Conway fixes it in the ledger
// rules rather than the protocol parameters; Dijkstra makes it a parameter.
const conwayMaxRefScriptSizePerTx = 200 * 1024

// protocolParamsFromLedger converts the protocol parameters the node reports
// for its current era. Apollo builds Conway and later transactions, so a node
// still in an earlier era is an error rather than a partial conversion.
func protocolParamsFromLedger(p common.ProtocolParameters) (backend.ProtocolParameters, error) {
	switch v := p.(type) {
	case *dijkstra.DijkstraProtocolParameters:
		if v == nil {
			return backend.ProtocolParameters{}, errors.New("node returned no protocol parameters")
		}
		pp, err := protocolParamsFromConway(&v.ConwayProtocolParameters)
		if err != nil {
			return backend.ProtocolParameters{}, err
		}
		if err := applyDijkstraRefScriptParams(&pp, v); err != nil {
			return backend.ProtocolParameters{}, err
		}
		return pp, nil
	case *conway.ConwayProtocolParameters:
		if v == nil {
			return backend.ProtocolParameters{}, errors.New("node returned no protocol parameters")
		}
		pp, err := protocolParamsFromConway(v)
		if err != nil {
			return backend.ProtocolParameters{}, err
		}
		pp.MaximumReferenceScriptsSize = conwayMaxRefScriptSizePerTx
		return pp, nil
	default:
		return backend.ProtocolParameters{}, fmt.Errorf(
			"node reports %T; Apollo requires the Conway era or later", p,
		)
	}
}

func protocolParamsFromConway(p *conway.ConwayProtocolParameters) (backend.ProtocolParameters, error) {
	var errs []error
	bounded := func(v uint64, name string) int {
		n, err := backendutil.BoundedIntFromUint64(v, name)
		errs = append(errs, err)
		return n
	}
	signed := func(v uint64, name string) int64 {
		if v > math.MaxInt64 {
			errs = append(errs, fmt.Errorf("%s out of range: %d", name, v))
			return 0
		}
		return int64(v)
	}
	exUnits := func(v int64, name string) string {
		if v < 0 {
			errs = append(errs, fmt.Errorf("%s is negative: %d", name, v))
		}
		return strconv.FormatInt(v, 10)
	}
	price := func(r *cbor.Rat, name string) float64 {
		if r == nil || r.Rat == nil {
			errs = append(errs, fmt.Errorf("%s is missing", name))
			return 0
		}
		if r.Sign() < 0 {
			errs = append(errs, fmt.Errorf("%s is negative: %s", name, r.RatString()))
			return 0
		}
		f, _ := r.Float64()
		return f
	}
	optionalRatio := func(r *cbor.Rat) float64 {
		if r == nil || r.Rat == nil {
			return 0
		}
		f, _ := r.Float64()
		return f
	}

	pp := backend.ProtocolParameters{
		MinFeeCoefficient:    signed(uint64(p.MinFeeA), "min fee coefficient"),
		MinFeeConstant:       signed(uint64(p.MinFeeB), "min fee constant"),
		MaxBlockSize:         bounded(uint64(p.MaxBlockBodySize), "max block body size"),
		MaxTxSize:            bounded(uint64(p.MaxTxSize), "max tx size"),
		MaxBlockHeaderSize:   bounded(uint64(p.MaxBlockHeaderSize), "max block header size"),
		KeyDeposits:          strconv.FormatUint(uint64(p.KeyDeposit), 10),
		PoolDeposits:         strconv.FormatUint(uint64(p.PoolDeposit), 10),
		PoolInfluence:        optionalRatio(p.A0),
		MonetaryExpansion:    optionalRatio(p.Rho),
		TreasuryExpansion:    optionalRatio(p.Tau),
		ProtocolMajorVersion: bounded(uint64(p.ProtocolVersion.Major), "protocol major version"),
		ProtocolMinorVersion: bounded(uint64(p.ProtocolVersion.Minor), "protocol minor version"),
		MinPoolCost:          strconv.FormatUint(p.MinPoolCost, 10),
		PriceMem:             price(p.ExecutionCosts.MemPrice, "memory price"),
		PriceStep:            price(p.ExecutionCosts.StepPrice, "step price"),
		MaxTxExMem:           exUnits(p.MaxTxExUnits.Memory, "max tx memory units"),
		MaxTxExSteps:         exUnits(p.MaxTxExUnits.Steps, "max tx step units"),
		MaxBlockExMem:        exUnits(p.MaxBlockExUnits.Memory, "max block memory units"),
		MaxBlockExSteps:      exUnits(p.MaxBlockExUnits.Steps, "max block step units"),
		MaxValSize:           strconv.FormatUint(uint64(p.MaxValueSize), 10),
		CollateralPercent:    bounded(uint64(p.CollateralPercentage), "collateral percentage"),
		MaxCollateralInputs:  bounded(uint64(p.MaxCollateralInputs), "max collateral inputs"),
		CoinsPerUtxoByte:     strconv.FormatUint(p.AdaPerUtxoByte, 10),
		CostModels:           costModelsFromLedger(p.CostModels),
	}
	if r := p.MinFeeRefScriptCostPerByte; r != nil && r.Rat != nil {
		if r.Sign() < 0 {
			errs = append(errs, fmt.Errorf("reference script price is negative: %s", r.RatString()))
		} else {
			pp.MinFeeRefScriptCostPerByteRational = new(big.Rat).Set(r.Rat)
			pp.MinFeeRefScriptCostPerByte, _ = r.Float64()
		}
	}
	if err := errors.Join(errs...); err != nil {
		return backend.ProtocolParameters{}, fmt.Errorf("invalid node protocol parameters: %w", err)
	}
	return pp, nil
}

// applyDijkstraRefScriptParams copies the reference-script limit and pricing
// tier that Dijkstra moves from ledger constants into the protocol parameters.
func applyDijkstraRefScriptParams(pp *backend.ProtocolParameters, p *dijkstra.DijkstraProtocolParameters) error {
	var errs []error
	if p.MaxRefScriptSizePerTx > 0 {
		size, err := backendutil.BoundedIntFromUint64(uint64(p.MaxRefScriptSizePerTx), "max reference script size per tx")
		errs = append(errs, err)
		pp.MaximumReferenceScriptsSize = size
	}
	if p.RefScriptCostStride > 0 {
		stride, err := backendutil.BoundedIntFromUint64(uint64(p.RefScriptCostStride), "reference script cost stride")
		errs = append(errs, err)
		pp.MinFeeReferenceScriptsRange = stride
	}
	if r := p.RefScriptCostMultiplier; r != nil && r.Rat != nil {
		if r.Sign() <= 0 {
			errs = append(errs, fmt.Errorf("reference script cost multiplier must be positive: %s", r.RatString()))
		} else {
			pp.MinFeeReferenceScriptsMultiplierRational = new(big.Rat).Set(r.Rat)
		}
	}
	if err := errors.Join(errs...); err != nil {
		return fmt.Errorf("invalid node protocol parameters: %w", err)
	}
	return nil
}

// costModelsFromLedger names each cost model as ComputeScriptDataHash expects.
// The ledger numbers Plutus languages from zero, so language n is
// "PlutusV<n+1>"; a language newer than this code still gets that name.
func costModelsFromLedger(models map[uint][]int64) map[string][]int64 {
	if models == nil {
		return nil
	}
	named := make(map[string][]int64, len(models))
	for language, costs := range models {
		named["PlutusV"+strconv.FormatUint(uint64(language)+1, 10)] = append([]int64(nil), costs...)
	}
	return named
}

// genesisParamsFromLedger converts the node's Shelley genesis configuration.
// The node encodes the system start as a year, a 1-based day of the year and
// picoseconds into that day, and the slot length in microseconds.
func genesisParamsFromLedger(g *localstatequery.GenesisConfigResult) (backend.GenesisParameters, error) {
	if g == nil {
		return backend.GenesisParameters{}, errors.New("node returned no genesis configuration")
	}
	coeff, err := activeSlotsCoeff(g.ActiveSlotsCoeff)
	if err != nil {
		return backend.GenesisParameters{}, err
	}
	systemStart, err := systemStartUnix(g.Start)
	if err != nil {
		return backend.GenesisParameters{}, err
	}
	if g.SlotLength <= 0 {
		return backend.GenesisParameters{}, fmt.Errorf("genesis slot length must be positive, got %d", g.SlotLength)
	}
	// GenesisParameters holds whole seconds, so a slot length that is not one
	// is rejected rather than rounded.
	const microsPerSecond = 1_000_000
	if g.SlotLength%microsPerSecond != 0 {
		return backend.GenesisParameters{}, fmt.Errorf(
			"genesis slot length %d µs is not a whole number of seconds", g.SlotLength,
		)
	}
	if g.EpochLength <= 0 {
		return backend.GenesisParameters{}, fmt.Errorf("genesis epoch length must be positive, got %d", g.EpochLength)
	}
	if g.MaxLovelaceSupply < 0 {
		return backend.GenesisParameters{}, fmt.Errorf("genesis max lovelace supply is negative: %d", g.MaxLovelaceSupply)
	}

	var errs []error
	bounded := func(v int, name string) int {
		n, err := backendutil.BoundedInt(int64(v), name)
		errs = append(errs, err)
		return n
	}
	gp := backend.GenesisParameters{
		ActiveSlotsCoefficient: coeff,
		UpdateQuorum:           bounded(g.UpdateQuorum, "update quorum"),
		MaxLovelaceSupply:      strconv.FormatInt(g.MaxLovelaceSupply, 10),
		NetworkMagic:           bounded(g.NetworkMagic, "network magic"),
		EpochLength:            bounded(g.EpochLength, "epoch length"),
		SystemStart:            systemStart,
		SlotsPerKesPeriod:      bounded(g.SlotsPerKESPeriod, "slots per KES period"),
		SlotLength:             g.SlotLength / microsPerSecond,
		MaxKesEvolutions:       bounded(g.MaxKESEvolutions, "max KES evolutions"),
		SecurityParam:          bounded(g.SecurityParam, "security parameter"),
	}
	if err := errors.Join(errs...); err != nil {
		return backend.GenesisParameters{}, fmt.Errorf("invalid node genesis configuration: %w", err)
	}
	return gp, nil
}

// activeSlotsCoeff converts the coefficient's [numerator, denominator] pair,
// which must lie in (0, 1].
func activeSlotsCoeff(pair []any) (float64, error) {
	if len(pair) != 2 {
		return 0, fmt.Errorf("active slots coefficient must be a [numerator, denominator] pair, got %v", pair)
	}
	num, okNum := bigIntFrom(pair[0])
	den, okDen := bigIntFrom(pair[1])
	if !okNum || !okDen || den.Sign() <= 0 || num.Sign() <= 0 || num.Cmp(den) > 0 {
		return 0, fmt.Errorf("invalid active slots coefficient %v", pair)
	}
	f, _ := new(big.Rat).SetFrac(num, den).Float64()
	return f, nil
}

func bigIntFrom(v any) (*big.Int, bool) {
	switch n := v.(type) {
	case uint64:
		return new(big.Int).SetUint64(n), true
	case int64:
		return big.NewInt(n), true
	case int:
		return big.NewInt(int64(n)), true
	case *big.Int:
		if n == nil {
			return nil, false
		}
		return new(big.Int).Set(n), true
	case big.Int:
		return new(big.Int).Set(&n), true
	default:
		return nil, false
	}
}

// systemStartUnix converts the node's (year, day of year, picoseconds)
// system start to Unix seconds.
func systemStartUnix(s localstatequery.SystemStartResult) (int64, error) {
	const picosPerSecond = 1_000_000_000_000
	if !s.Year.IsInt64() || s.Year.Int64() < 1970 || s.Year.Int64() > 9999 {
		return 0, fmt.Errorf("genesis system start year out of range: %s", s.Year.String())
	}
	year := int(s.Year.Int64())
	daysInYear := int64(time.Date(year, time.December, 31, 0, 0, 0, 0, time.UTC).YearDay())
	if s.Day < 1 || s.Day > daysInYear {
		return 0, fmt.Errorf("genesis system start day %d is not a day of %d", s.Day, year)
	}
	if s.Picoseconds.Sign() < 0 || s.Picoseconds.Cmp(big.NewInt(86_400*picosPerSecond)) >= 0 {
		return 0, fmt.Errorf("genesis system start time of day out of range: %s ps", s.Picoseconds.String())
	}
	seconds := new(big.Int).Quo(&s.Picoseconds, big.NewInt(picosPerSecond)).Int64()
	start := time.Date(year, time.January, int(s.Day), 0, 0, 0, 0, time.UTC).
		Add(time.Duration(seconds) * time.Second)
	return start.Unix(), nil
}

// utxosFromLedger converts a UTxO query result. Results are returned in a
// stable order (transaction id, then output index) since the node's result is
// a map.
func utxosFromLedger(results map[localstatequery.UtxoId]babbage.BabbageTransactionOutput) ([]common.Utxo, error) {
	utxos := make([]common.Utxo, 0, len(results))
	for id, output := range results {
		utxo, err := utxoFromLedger(id, output)
		if err != nil {
			return nil, err
		}
		utxos = append(utxos, utxo)
	}
	sortUtxos(utxos)
	return utxos, nil
}

func sortUtxos(utxos []common.Utxo) {
	slices.SortFunc(utxos, func(a, b common.Utxo) int {
		aId, bId := a.Id.Id(), b.Id.Id()
		if c := bytes.Compare(aId[:], bId[:]); c != 0 {
			return c
		}
		return cmp.Compare(a.Id.Index(), b.Id.Index())
	})
}

func utxoFromLedger(id localstatequery.UtxoId, output babbage.BabbageTransactionOutput) (common.Utxo, error) {
	if id.Idx < 0 || uint64(id.Idx) > math.MaxUint32 {
		return common.Utxo{}, fmt.Errorf("output index %d out of range", id.Idx)
	}
	out := output
	return common.Utxo{
		Id: shelley.ShelleyTransactionInput{
			TxId:        id.Hash,
			OutputIndex: uint32(id.Idx), //nolint:gosec // range checked above
		},
		Output: &out,
	}, nil
}

// txHash returns the id of a serialized transaction: the Blake2b-256 hash of
// its body exactly as encoded, which is the first element of the
// transaction array in every era.
func txHash(txCbor []byte) (common.Blake2b256, error) {
	var parts []cbor.RawMessage
	if _, err := cbor.Decode(txCbor, &parts); err != nil {
		return common.Blake2b256{}, fmt.Errorf("decode transaction: %w", err)
	}
	if len(parts) < 2 {
		return common.Blake2b256{}, fmt.Errorf("transaction has %d elements, want a body and witnesses", len(parts))
	}
	return common.Blake2b256Hash(parts[0]), nil
}

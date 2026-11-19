package localeval

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/conway"
	"github.com/blinklabs-io/gouroboros/ledger/dijkstra"

	"github.com/Salvionied/apollo/v2/backend"
)

// Params holds the chain values evaluation depends on.
type Params struct {
	// ProtocolParams supplies the cost models, the protocol major version and
	// the maximum transaction execution units each script may use.
	ProtocolParams backend.ProtocolParameters
	// SlotConfig converts the transaction's validity interval to the POSIX
	// times scripts see.
	SlotConfig SlotConfig
}

// Evaluate runs every redeemer's script in txCbor and returns the execution
// units each one consumed. utxos must contain every input and reference
// input the transaction names; no chain access is made.
//
// Each script runs against the protocol's maximum transaction execution
// units, not the units its redeemer declares, so the result is what the
// script needs. A script that fails, or exceeds that maximum, makes Evaluate
// return the evaluator's error.
func Evaluate(txCbor []byte, utxos []common.Utxo, params Params) (map[common.RedeemerKey]common.ExUnits, error) {
	resolve, err := staticResolver(utxos)
	if err != nil {
		return nil, err
	}
	return evaluate(txCbor, resolve, params)
}

func evaluate(txCbor []byte, resolve utxoResolver, params Params) (map[common.RedeemerKey]common.ExUnits, error) {
	pp, budget, err := ledgerParams(params.ProtocolParams)
	if err != nil {
		return nil, err
	}
	ls := &evalLedgerState{resolve: resolve, slots: params.SlotConfig}

	isDijkstra, err := isDijkstraEnvelope(txCbor)
	if err != nil {
		return nil, err
	}
	if !isDijkstra {
		tx, err := conway.NewConwayTransactionFromCbor(txCbor)
		if err != nil {
			return nil, fmt.Errorf("decode transaction: %w", err)
		}
		result, err := conway.EvaluatePlutusScripts(tx, ls, pp, &budget)
		if err != nil {
			return nil, fmt.Errorf("evaluate scripts: %w", err)
		}
		if err := validateRedeemerResults(tx, result); err != nil {
			return nil, err
		}
		return result, nil
	}

	tx, err := dijkstra.NewDijkstraTransactionFromCbor(txCbor)
	if err != nil {
		return nil, fmt.Errorf("decode Dijkstra transaction: %w", err)
	}
	if len(tx.Body.TxSubTransactions.Items()) > 0 {
		return nil, errors.New("evaluating Dijkstra sub-transactions is not supported")
	}
	evaluations, err := dijkstra.EvaluatePlutusScripts(tx, ls, pp, budget)
	if err != nil {
		return nil, fmt.Errorf("evaluate scripts: %w", err)
	}
	result := make(map[common.RedeemerKey]common.ExUnits, len(evaluations))
	for _, evaluation := range evaluations {
		// EvaluateTx's result has no room for a sub-transaction index, so
		// a sub-transaction's redeemer would collide with the top level's.
		if evaluation.SubTransactionIndex != nil {
			return nil, errors.New("evaluating sub-transaction redeemers is not supported")
		}
		result[evaluation.Key] = evaluation.ExUnits
	}
	if err := validateRedeemerResults(tx, result); err != nil {
		return nil, err
	}
	return result, nil
}

func validateRedeemerResults(
	tx common.Transaction,
	result map[common.RedeemerKey]common.ExUnits,
) error {
	witnesses := tx.Witnesses()
	if witnesses == nil || witnesses.Redeemers() == nil {
		return nil
	}
	for key := range witnesses.Redeemers().Iter() {
		if _, ok := result[key]; !ok {
			return fmt.Errorf("redeemer %v was not evaluated", key)
		}
	}
	return nil
}

// isDijkstraEnvelope reports whether txCbor uses Dijkstra's three-component
// transaction envelope. Conway and earlier eras use four components.
func isDijkstraEnvelope(txCbor []byte) (bool, error) {
	var envelope []cbor.RawMessage
	if _, err := cbor.Decode(txCbor, &envelope); err != nil {
		return false, fmt.Errorf("decode transaction: %w", err)
	}
	switch len(envelope) {
	case 3:
		return true, nil
	case 4:
		return false, nil
	default:
		return false, fmt.Errorf("transaction has %d components, want 3 or 4", len(envelope))
	}
}

// ledgerParams converts the protocol parameters evaluation reads: the major
// version, which selects script-context rules, the cost models and the
// per-transaction execution limit used as every script's budget.
func ledgerParams(pp backend.ProtocolParameters) (*conway.ConwayProtocolParameters, common.ExUnits, error) {
	if pp.ProtocolMajorVersion <= 0 {
		return nil, common.ExUnits{}, errors.New("protocol parameters have no major version")
	}
	memory, err := parseExUnit("max_tx_ex_mem", pp.MaxTxExMem)
	if err != nil {
		return nil, common.ExUnits{}, err
	}
	steps, err := parseExUnit("max_tx_ex_steps", pp.MaxTxExSteps)
	if err != nil {
		return nil, common.ExUnits{}, err
	}
	costModels := make(map[uint][]int64, len(pp.CostModels))
	for name, costs := range pp.CostModels {
		language, err := languageNumber(name)
		if err != nil {
			return nil, common.ExUnits{}, err
		}
		costModels[language] = append([]int64(nil), costs...)
	}
	ledger := &conway.ConwayProtocolParameters{CostModels: costModels}
	ledger.ProtocolVersion.Major = uint(pp.ProtocolMajorVersion)
	return ledger, common.ExUnits{Memory: memory, Steps: steps}, nil
}

func parseExUnit(field, value string) (int64, error) {
	units, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("protocol parameter %s: %w", field, err)
	}
	if units <= 0 {
		return 0, fmt.Errorf("protocol parameter %s is out of range: %d", field, units)
	}
	return units, nil
}

// languageNumber maps a cost model name to the ledger's language number.
func languageNumber(name string) (uint, error) {
	switch name {
	case "PlutusV1":
		return 0, nil
	case "PlutusV2":
		return 1, nil
	case "PlutusV3":
		return 2, nil
	case "PlutusV4":
		return 3, nil
	default:
		return 0, fmt.Errorf("unsupported cost model language: %q", name)
	}
}

package apollo

import (
	"errors"
	"fmt"
	"math"

	"github.com/blinklabs-io/gouroboros/ledger/babbage"
	"github.com/blinklabs-io/gouroboros/ledger/common"

	"github.com/Salvionied/apollo/v2/backend"
)

// balanceContext contains every value in the Cardano balance equation that is
// not a regular output or transaction fee. It is shared by provisional script
// evaluation and final transaction construction so both see the same change.
type balanceContext struct {
	totalInput         Value
	totalRequired      Value
	governanceRequired Value
	stakeDeposit       int64
	changeAddress      common.Address
}

type balancedOutputs struct {
	Outputs []babbage.BabbageTransactionOutput
	Fee     int64
}

// buildBalancedOutputs appends change to baseOutputs for the supplied fee.
// ADA-only change below min-UTxO is added to the fee; native assets are never
// discarded and must be carried in a valid change output.
func (a *Apollo) buildBalancedOutputs(
	baseOutputs []babbage.BabbageTransactionOutput,
	requestedFee int64,
	ctx balanceContext,
) (balancedOutputs, error) {
	if requestedFee < 0 {
		return balancedOutputs{}, fmt.Errorf("negative fee: %d", requestedFee)
	}
	outputs := make([]babbage.BabbageTransactionOutput, len(baseOutputs), len(baseOutputs)+1)
	copy(outputs, baseOutputs)

	needed, err := ctx.totalRequired.Add(ctx.governanceRequired)
	if err != nil {
		return balancedOutputs{}, fmt.Errorf("required value overflow: %w", err)
	}
	needed, err = needed.Add(NewSimpleValue(uint64(requestedFee))) //nolint:gosec // checked non-negative above
	if err != nil {
		return balancedOutputs{}, fmt.Errorf("required value overflow: %w", err)
	}
	change, err := ctx.totalInput.Sub(needed)
	if err != nil {
		return balancedOutputs{}, fmt.Errorf("insufficient funds: %w", err)
	}
	change.Assets, err = normalizeChangeAssets(change.Assets)
	if err != nil {
		return balancedOutputs{}, err
	}
	if change.Coin == 0 && !change.HasAssets() {
		return balancedOutputs{Outputs: outputs, Fee: requestedFee}, nil
	}

	changeOutput := NewBabbageOutput(ctx.changeAddress, change, nil, nil)
	pp, err := backend.ProtocolParamsContext(a.requestContext, a.Context)
	if err != nil {
		return balancedOutputs{}, fmt.Errorf("failed to get protocol params for change output: %w", err)
	}
	minChange, err := MinLovelacePostAlonzo(&changeOutput, pp.CoinsPerUtxoByteValue())
	if err != nil {
		return balancedOutputs{}, fmt.Errorf("failed to compute min UTxO for change output: %w", err)
	}
	if minChange < 0 {
		return balancedOutputs{}, fmt.Errorf("invalid min UTxO for change output: %d", minChange)
	}

	if change.Coin < uint64(minChange) {
		if !change.HasAssets() {
			if uint64(requestedFee) > math.MaxInt64-change.Coin { //nolint:gosec // checked non-negative above
				return balancedOutputs{}, errorsNewFeeOverflow(requestedFee, change.Coin)
			}
			return balancedOutputs{Outputs: outputs, Fee: requestedFee + int64(change.Coin)}, nil //nolint:gosec // bound checked above
		}
		// A token-bearing output must meet its min-UTxO requirement. Raising
		// its ADA consumes extra change, so prove the selected inputs cover it.
		change.Coin = uint64(minChange)
		changeOutput = NewBabbageOutput(ctx.changeAddress, change, nil, nil)
		actualMin, minErr := MinLovelacePostAlonzo(&changeOutput, pp.CoinsPerUtxoByteValue())
		if minErr != nil {
			return balancedOutputs{}, fmt.Errorf("failed to compute actual min UTxO for change output: %w", minErr)
		}
		if actualMin < 0 {
			return balancedOutputs{}, fmt.Errorf("invalid min UTxO for change output: %d", actualMin)
		}
		change.Coin = uint64(actualMin)
		changeOutput = NewBabbageOutput(ctx.changeAddress, change, nil, nil)
		neededWithChange, addErr := needed.Add(NewSimpleValue(change.Coin))
		if addErr != nil || !ctx.totalInput.GreaterOrEqual(neededWithChange) {
			return balancedOutputs{}, errors.New("insufficient funds for asset change min UTxO")
		}
	}
	outputs = append(outputs, changeOutput)
	return balancedOutputs{Outputs: outputs, Fee: requestedFee}, nil
}

func errorsNewFeeOverflow(fee int64, dust uint64) error {
	return fmt.Errorf("fee overflow absorbing %d lovelace dust into %d", dust, fee)
}

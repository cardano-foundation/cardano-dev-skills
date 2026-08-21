package apollo

import (
	"context"
	"errors"
	"fmt"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// CoinSelector chooses UTxOs from an available pool to cover a target value.
// Implementations must be deterministic: the same pool and target must yield
// the same selection.
type CoinSelector interface {
	// Name returns the algorithm's identifier.
	Name() string
	// Select returns a subset of available whose summed value covers target.
	// The available pool has already been filtered of in-use UTxOs. It
	// returns an error if the pool cannot cover the target.
	//
	// Selection over a large pool is expensive, so implementations must
	// observe ctx while searching and abandon the search with an error
	// wrapping ctx.Err() once it is done, instead of running to completion.
	Select(
		ctx context.Context,
		available []common.Utxo,
		target Value,
	) ([]common.Utxo, error)
}

// selectionCancelStride is how many pool entries a selector may process
// between context checks. Small enough that cancellation is observed
// promptly even on a pool of hundreds of thousands of UTxOs, large enough
// that the check does not dominate the inner loops.
const selectionCancelStride = 256

// selectionInterrupted reports whether ctx is done, as an error wrapping
// ctx.Err() so callers can still match it with errors.Is. A nil context is
// treated as never done: Select is exported and must not panic on one.
func selectionInterrupted(ctx context.Context) error {
	if ctx == nil {
		return nil
	}
	if err := ctx.Err(); err != nil {
		return fmt.Errorf("coin selection interrupted: %w", err)
	}
	return nil
}

// defaultCoinSelector is used by Complete when no selector is configured.
// MACS is the default on measured fees, not on input counts: over a
// 150-transaction wallet lifetime of plain ADA payments it costs within 0.56%
// of largest-first while ending with one dust UTxO rather than ninety, and on a
// multi-asset payment it is about three times cheaper (200,437 lovelace over 20
// inputs against 623,629 over 286). Use
// SetCoinSelector(&LargestFirstSelector{}) for the legacy greedy behavior.
var defaultCoinSelector CoinSelector = NewMACSSelector()

// LargestFirstSelector selects UTxOs greedily by descending lovelace amount,
// consuming ADA-only UTxOs before asset-carrying ones.
type LargestFirstSelector struct{}

// Name returns the algorithm's identifier.
func (s *LargestFirstSelector) Name() string { return "largest-first" }

// Select returns a subset of available whose summed value covers target.
func (s *LargestFirstSelector) Select(
	ctx context.Context,
	available []common.Utxo,
	target Value,
) ([]common.Utxo, error) {
	remaining := target.Clone()
	if remaining.Coin == 0 && !remaining.HasAssets() {
		return nil, nil
	}
	if err := selectionInterrupted(ctx); err != nil {
		return nil, err
	}
	if err := validateUtxos(available); err != nil {
		return nil, fmt.Errorf("invalid coin-selection input: %w", err)
	}
	sorted := SortUtxos(available)
	if err := selectionInterrupted(ctx); err != nil {
		return nil, err
	}
	// Stabilize ordering for equal-amount UTxOs to preserve deterministic selection.
	for i := 0; i < len(sorted); {
		hasAssets := sorted[i].Output.Assets() != nil
		amt := sorted[i].Output.Amount()
		j := i + 1
		for j < len(sorted) {
			if (sorted[j].Output.Assets() != nil) != hasAssets {
				break
			}
			amtJ := sorted[j].Output.Amount()
			if (amt == nil) != (amtJ == nil) {
				break
			}
			if amt != nil && amtJ != nil && amt.Cmp(amtJ) != 0 {
				break
			}
			j++
		}
		if j-i > 1 {
			stable := SortInputs(sorted[i:j])
			copy(sorted[i:j], stable)
		}
		i = j
	}
	var selected []common.Utxo
	for i, utxo := range sorted {
		if i%selectionCancelStride == 0 {
			if err := selectionInterrupted(ctx); err != nil {
				return nil, err
			}
		}
		amt := utxo.Output.Amount()
		// Amounts come from a remote backend; reject anything outside the
		// uint64 lovelace range (big.Int.Uint64 is undefined out of range).
		if amt == nil || !amt.IsUint64() {
			return nil, fmt.Errorf(
				"UTxO %s has an invalid lovelace amount",
				utxoRef(utxo),
			)
		}

		selected = append(selected, utxo)

		if remaining.Coin <= amt.Uint64() {
			remaining.Coin = 0
		} else {
			remaining.Coin -= amt.Uint64()
		}
		if remaining.Assets != nil && utxo.Output.Assets() != nil {
			subtractAssetsSaturating(remaining.Assets, utxo.Output.Assets())
		}

		if remaining.Coin == 0 && !remaining.HasAssets() {
			return selected, nil
		}
	}
	return nil, errors.New("insufficient UTxOs to cover required value")
}

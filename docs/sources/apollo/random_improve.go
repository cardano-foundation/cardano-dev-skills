package apollo

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math"
	"math/big"
	"math/rand/v2"
	"reflect"
	"sort"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// The cover and improve phases shuffle with different PCG streams so that
// the improve order is not simply the cover order continued.
const (
	randomImproveCoverSalt   uint64 = 0x4349503030303201
	randomImproveImproveSalt uint64 = 0x52494d50524f5645
)

// DefaultRandomImproveMaxInputs is the input limit NewRandomImproveSelector
// sets. At roughly 36 bytes per input it keeps a selection's inputs well
// inside the 16384-byte mainnet transaction size limit.
const DefaultRandomImproveMaxInputs = 100

// RandomImproveSelector implements the Random-Improve algorithm from
// CIP-0002, adapted to Apollo's aggregate CoinSelector interface. It covers
// the target by taking UTxOs in random order, drops any cover input a later
// pick made redundant, then adds ADA-only UTxOs that bring the lovelace total
// closer to an ideal of twice the target.
//
// The cover takes only UTxOs that reduce a remaining shortfall, and it uses
// UTxOs that would add surplus assets, either ones the target does not ask
// for or ones the selection already has enough of, only when the others
// cannot cover it. Pruning drops redundant token-carrying inputs before
// ADA-only ones. Surplus native assets become change that needs its own
// min-UTxO lovelace, so these rules keep a payment the wallet can afford from
// becoming impossible to balance.
//
// It also differs from CIP-0002 in that it selects for the aggregate target
// rather than for each output, and improvement may not take lovelace above
// twice the target, where CIP-0002 allows three times.
//
// The order is pseudo-random but deterministic: the same Seed, pool, and
// target always produce the same selection, as CoinSelector requires.
//
// The zero value has no input limit. Prefer NewRandomImproveSelector, which
// sets MaxInputs to DefaultRandomImproveMaxInputs. A nil
// *RandomImproveSelector behaves like NewRandomImproveSelector().
type RandomImproveSelector struct {
	// Seed selects the pseudo-random UTxO order. The zero value is a valid
	// seed.
	Seed int64
	// MaxInputs limits the number of selected UTxOs. If the random cover
	// reaches the limit before covering the target, Select returns an error
	// wrapping ErrInsufficientUtxos, even when a smaller selection exists;
	// improvement stops at the limit. Zero or negative means no limit.
	MaxInputs int
}

// NewRandomImproveSelector returns a RandomImproveSelector with seed 0 and
// MaxInputs set to DefaultRandomImproveMaxInputs.
func NewRandomImproveSelector() *RandomImproveSelector {
	return &RandomImproveSelector{MaxInputs: DefaultRandomImproveMaxInputs}
}

// Name returns the algorithm's identifier.
func (s *RandomImproveSelector) Name() string { return "random-improve" }

// Select returns a subset of available whose summed value covers target. It
// returns an error wrapping ErrInsufficientUtxos when the pool cannot cover
// target or the random cover exceeds MaxInputs.
func (s *RandomImproveSelector) Select(
	ctx context.Context,
	available []common.Utxo,
	target Value,
) ([]common.Utxo, error) {
	if s == nil {
		s = NewRandomImproveSelector()
	}
	if target.Coin == 0 && !target.HasAssets() {
		return nil, nil
	}
	if err := selectionInterrupted(ctx); err != nil {
		return nil, err
	}
	if err := validateUtxos(available); err != nil {
		return nil, fmt.Errorf("invalid coin-selection input: %w", err)
	}
	targets := randomImproveTargets(target)
	cands, err := randomImproveCandidates(ctx, available, targets)
	if err != nil {
		return nil, err
	}

	// Only lovelace and the targeted assets decide coverage, so the running
	// total tracks just those. Lovelace is a big.Int because a redundant
	// input may push the cover's sum past uint64 before pruning removes it.
	acc := randomImproveTotal{amounts: make([]*big.Int, len(targets))}
	for k := range acc.amounts {
		acc.amounts[k] = new(big.Int)
	}
	coinTarget := new(big.Int).SetUint64(target.Coin)
	order, err := randomImproveShuffle(ctx, len(cands), s.Seed, randomImproveCoverSalt)
	if err != nil {
		return nil, err
	}
	selected := make([]bool, len(cands))
	var picks []int
	visited := 0
	// The first pass takes only UTxOs that add no surplus asset: none the
	// target does not ask for, and none the selection already has enough of.
	// The second pass takes any UTxO that reduces a shortfall, and runs only
	// if the first could not cover the target.
	for _, lastPass := range []bool{false, true} {
		for _, idx := range order {
			if acc.covers(coinTarget, targets) {
				break
			}
			if visited%selectionCancelStride == 0 {
				if err := selectionInterrupted(ctx); err != nil {
					return nil, err
				}
			}
			visited++
			cand := &cands[idx]
			if selected[idx] ||
				!acc.reducesShortfall(cand, coinTarget, targets) ||
				(!lastPass && acc.addsSurplusAsset(cand, targets)) {
				continue
			}
			if s.MaxInputs > 0 && len(picks) >= s.MaxInputs {
				return nil, fmt.Errorf(
					"%w: random cover exceeds %d inputs",
					ErrInsufficientUtxos, s.MaxInputs,
				)
			}
			acc.add(cand)
			selected[idx] = true
			picks = append(picks, idx)
		}
	}
	if !acc.covers(coinTarget, targets) {
		return nil, ErrInsufficientUtxos
	}

	// A random cover can take a small input before a large one that covers
	// on its own. Token-carrying inputs are dropped first: once an ADA-only
	// input is gone, a redundant token input may become necessary for its
	// lovelace and leave surplus tokens in change.
	for rank := range randomImproveRanks {
		kept := picks[:0]
		for i, idx := range picks {
			if i%selectionCancelStride == 0 {
				if err := selectionInterrupted(ctx); err != nil {
					return nil, err
				}
			}
			cand := &cands[idx]
			if cand.rank() == rank &&
				acc.coversWithout(cand, coinTarget, targets) {
				acc.sub(cand)
				selected[idx] = false
				continue
			}
			kept = append(kept, idx)
		}
		picks = kept
	}
	if !acc.coin.IsUint64() {
		return nil, errors.New("selection value overflow: selected lovelace exceeds uint64")
	}
	coin := acc.coin.Uint64()

	// A target above half the uint64 range has no representable ideal; the
	// cover is still valid, so improvement is skipped.
	room := func() bool {
		return s.MaxInputs <= 0 || len(picks) < s.MaxInputs
	}
	if target.Coin <= math.MaxUint64/2 && coin < target.Coin*2 && room() {
		ideal := target.Coin * 2
		order, err := randomImproveShuffle(ctx, len(cands), s.Seed, randomImproveImproveSalt)
		if err != nil {
			return nil, err
		}
		for i, idx := range order {
			if i%selectionCancelStride == 0 {
				if err := selectionInterrupted(ctx); err != nil {
					return nil, err
				}
			}
			// Stopping at the ideal also keeps ideal-coin below from
			// wrapping around.
			if coin >= ideal || !room() {
				break
			}
			cand := &cands[idx]
			// Within the ideal, every added lovelace moves the total closer
			// to it, so the CIP-0002 distance test reduces to this bound.
			if selected[idx] || cand.rank() != randomImproveRankAdaOnly ||
				cand.coin == 0 || cand.coin > ideal-coin {
				continue
			}
			coin += cand.coin
			selected[idx] = true
			picks = append(picks, idx)
		}
	}

	result := make([]common.Utxo, 0, len(picks))
	for _, idx := range picks {
		result = append(result, cands[idx].utxo)
	}
	return result, nil
}

// RandomImproveThenLargestFirstSelector follows the Cardano Wallet strategy
// described in CIP-0002: it tries Random-Improve and falls back to
// Largest-First only when Random-Improve reports ErrInsufficientUtxos, which
// with the default input limit includes a random cover that exceeds it.
// Any other error, including cancellation, is returned without a fallback.
// A nil *RandomImproveThenLargestFirstSelector uses both defaults.
type RandomImproveThenLargestFirstSelector struct {
	// RandomImprove is the primary selector. Nil, including a typed nil,
	// means NewRandomImproveSelector().
	RandomImprove CoinSelector
	// Fallback runs when RandomImprove returns an error matching
	// ErrInsufficientUtxos. Nil, including a typed nil, means
	// LargestFirstSelector.
	Fallback CoinSelector
}

// NewRandomImproveThenLargestFirstSelector returns a selector that tries
// Random-Improve before Largest-First.
func NewRandomImproveThenLargestFirstSelector() *RandomImproveThenLargestFirstSelector {
	return &RandomImproveThenLargestFirstSelector{}
}

// Name returns the algorithm's identifier.
func (s *RandomImproveThenLargestFirstSelector) Name() string {
	return "random-improve-largest-first"
}

// Select returns a subset of available whose summed value covers target.
func (s *RandomImproveThenLargestFirstSelector) Select(
	ctx context.Context,
	available []common.Utxo,
	target Value,
) ([]common.Utxo, error) {
	var primary, fallback CoinSelector
	if s != nil {
		primary, fallback = s.RandomImprove, s.Fallback
	}
	if isNilCoinSelector(primary) {
		primary = NewRandomImproveSelector()
	}
	selected, err := primary.Select(ctx, available, target)
	if err == nil {
		return selected, nil
	}
	if !errors.Is(err, ErrInsufficientUtxos) {
		return nil, fmt.Errorf("%s failed: %w", primary.Name(), err)
	}
	if isNilCoinSelector(fallback) {
		fallback = &LargestFirstSelector{}
	}
	selected, fallbackErr := fallback.Select(ctx, available, target)
	if fallbackErr != nil {
		// Only the fallback's error is wrapped: the result matches
		// ErrInsufficientUtxos only if the fallback also found the pool
		// insufficient, not if it failed for another reason.
		return nil, fmt.Errorf(
			"%s failed: %v; %s failed: %w",
			primary.Name(), err, fallback.Name(), fallbackErr,
		)
	}
	return selected, nil
}

// isNilCoinSelector reports whether selector is nil or an interface holding
// a nil pointer, whose Select would dereference it.
func isNilCoinSelector(selector CoinSelector) bool {
	if selector == nil {
		return true
	}
	value := reflect.ValueOf(selector)
	switch value.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Pointer, reflect.Slice:
		return value.IsNil()
	default:
		return false
	}
}

type randomImproveAsset struct {
	policy common.Blake2b224
	name   []byte
	qty    *big.Int
}

// randomImproveTargets lists the target's positive asset quantities in
// policy and name order.
func randomImproveTargets(target Value) []randomImproveAsset {
	if target.Assets == nil {
		return nil
	}
	var out []randomImproveAsset
	for _, policy := range target.Assets.Policies() {
		for _, name := range target.Assets.Assets(policy) {
			qty := target.Assets.Asset(policy, name)
			if qty == nil || qty.Sign() <= 0 {
				continue
			}
			out = append(out, randomImproveAsset{policy: policy, name: name, qty: qty})
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if c := bytes.Compare(out[i].policy.Bytes(), out[j].policy.Bytes()); c != 0 {
			return c < 0
		}
		return bytes.Compare(out[i].name, out[j].name) < 0
	})
	return out
}

// Pruning ranks: inputs whose surplus is costliest in change go first.
const (
	randomImproveRankUntargeted = iota
	randomImproveRankTargeted
	randomImproveRankAdaOnly
	randomImproveRanks
)

type randomImproveCandidate struct {
	utxo common.Utxo
	ref  string
	coin uint64
	// amounts holds the UTxO's quantity of each targeted asset, indexed
	// like the targets; nil when it holds none of them.
	amounts []*big.Int
	// untargeted reports that the UTxO carries an asset the target does not
	// ask for.
	untargeted bool
}

func (c *randomImproveCandidate) rank() int {
	switch {
	case c.untargeted:
		return randomImproveRankUntargeted
	case c.amounts != nil:
		return randomImproveRankTargeted
	default:
		return randomImproveRankAdaOnly
	}
}

// randomImproveCandidates returns the pool sorted by ref, so the shuffle
// depends only on the seed and the pool's contents, not its order.
func randomImproveCandidates(
	ctx context.Context,
	available []common.Utxo,
	targets []randomImproveAsset,
) ([]randomImproveCandidate, error) {
	cands := make([]randomImproveCandidate, 0, len(available))
	for i := range available {
		if i%selectionCancelStride == 0 {
			if err := selectionInterrupted(ctx); err != nil {
				return nil, err
			}
		}
		amt := available[i].Output.Amount()
		if amt == nil || !amt.IsUint64() {
			return nil, fmt.Errorf(
				"UTxO %s has an invalid lovelace amount",
				utxoRef(available[i]),
			)
		}
		cand := randomImproveCandidate{
			utxo: available[i],
			ref:  utxoRef(available[i]),
			coin: amt.Uint64(),
		}
		if assets := available[i].Output.Assets(); assets != nil {
			held := 0
			for _, policy := range assets.Policies() {
				for _, name := range assets.Assets(policy) {
					if qty := assets.Asset(policy, name); qty != nil && qty.Sign() > 0 {
						held++
					}
				}
			}
			matched := 0
			for k, t := range targets {
				qty := assets.Asset(t.policy, t.name)
				if qty == nil || qty.Sign() <= 0 {
					continue
				}
				if cand.amounts == nil {
					cand.amounts = make([]*big.Int, len(targets))
				}
				cand.amounts[k] = qty
				matched++
			}
			cand.untargeted = held > matched
		}
		cands = append(cands, cand)
	}
	sort.Slice(cands, func(i, j int) bool {
		return cands[i].ref < cands[j].ref
	})
	return cands, nil
}

// randomImproveTotal is the selection's lovelace and targeted-asset total.
// Its big.Ints are private to one Select call, so they are updated in place.
type randomImproveTotal struct {
	coin    big.Int
	amounts []*big.Int
}

func (t *randomImproveTotal) add(c *randomImproveCandidate) {
	t.coin.Add(&t.coin, new(big.Int).SetUint64(c.coin))
	for k, qty := range c.amounts {
		if qty != nil {
			t.amounts[k].Add(t.amounts[k], qty)
		}
	}
}

func (t *randomImproveTotal) sub(c *randomImproveCandidate) {
	t.coin.Sub(&t.coin, new(big.Int).SetUint64(c.coin))
	for k, qty := range c.amounts {
		if qty != nil {
			t.amounts[k].Sub(t.amounts[k], qty)
		}
	}
}

func (t *randomImproveTotal) covers(coin *big.Int, targets []randomImproveAsset) bool {
	if t.coin.Cmp(coin) < 0 {
		return false
	}
	for k, target := range targets {
		if t.amounts[k].Cmp(target.qty) < 0 {
			return false
		}
	}
	return true
}

// reducesShortfall reports whether c adds lovelace or a targeted asset the
// total still lacks.
func (t *randomImproveTotal) reducesShortfall(
	c *randomImproveCandidate,
	coin *big.Int,
	targets []randomImproveAsset,
) bool {
	if c.coin > 0 && t.coin.Cmp(coin) < 0 {
		return true
	}
	for k, qty := range c.amounts {
		if qty != nil && t.amounts[k].Cmp(targets[k].qty) < 0 {
			return true
		}
	}
	return false
}

// addsSurplusAsset reports whether c carries an asset the target does not
// ask for, or a targeted asset the total already covers.
func (t *randomImproveTotal) addsSurplusAsset(
	c *randomImproveCandidate,
	targets []randomImproveAsset,
) bool {
	if c.untargeted {
		return true
	}
	for k, qty := range c.amounts {
		if qty != nil && t.amounts[k].Cmp(targets[k].qty) >= 0 {
			return true
		}
	}
	return false
}

// coversWithout reports whether the total still covers the target once c,
// which is part of it, is removed.
func (t *randomImproveTotal) coversWithout(
	c *randomImproveCandidate,
	coin *big.Int,
	targets []randomImproveAsset,
) bool {
	var rest big.Int
	if rest.Sub(&t.coin, new(big.Int).SetUint64(c.coin)).Cmp(coin) < 0 {
		return false
	}
	for k, qty := range c.amounts {
		if qty == nil {
			continue
		}
		if rest.Sub(t.amounts[k], qty).Cmp(targets[k].qty) < 0 {
			return false
		}
	}
	return true
}

// randomImproveShuffle returns a permutation of 0..n-1 from a Fisher-Yates
// shuffle driven by PCG, which takes the full 64-bit seed and salt. The
// output of PCG.Uint64 is fixed by its algorithm, and the index reduction is
// done here rather than by a library helper whose method could change, so a
// seed yields the same order on every platform and Go release. The modulo
// bias is negligible for any pool that fits in memory.
func randomImproveShuffle(ctx context.Context, n int, seed int64, salt uint64) ([]int, error) {
	order := make([]int, n)
	for i := range order {
		order[i] = i
	}
	rng := rand.NewPCG(uint64(seed), salt) //nolint:gosec // deterministic ordering, not a secret
	for i := n - 1; i > 0; i-- {
		if i%selectionCancelStride == 0 {
			if err := selectionInterrupted(ctx); err != nil {
				return nil, err
			}
		}
		j := int(rng.Uint64() % uint64(i+1)) //nolint:gosec // j <= i, an int
		order[i], order[j] = order[j], order[i]
	}
	return order, nil
}

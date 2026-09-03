package apollo

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/big"
	"sort"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// MACSSelector implements the Multi-Asset Coin Selection algorithm from
// "MACS: A Multi-Asset Coin Selection Algorithm for UTXO-based Blockchains"
// (Ramezan, Schneider, McCann — IEEE Blockchain 2023,
// DOI 10.1109/Blockchain60715.2023.00029). Each deficient asset class in the
// target (native assets first, lovelace last) is covered by repeatedly
// picking the unselected UTxO with the highest priority
//
//	P(u,c) = v(u,c) / (|v(u,c) - avg(S,c)| + 1)
//
// which favors valuable UTxOs near the pool-wide average value, keeping the
// wallet's UTxO pool diverse. The paper's confirmation age and linkage factors
// are constant here because common.Utxo carries no such metadata. A final pass
// drops inputs made redundant by later picks, lowest priority first.
// Priorities are compared exactly via big.Int cross-multiplication, so
// selection is deterministic.
//
// Note that small change is not a virtue on Cardano, whatever the priority
// function's shape suggests: a change amount below the minimum UTxO value
// cannot be emitted as an output at all, so the builder folds it into the fee
// and the user loses it. MinChange steers around that dead band.
//
// Priority alone is not enough to keep the input count low. Because avg(S,c)
// is a pool-wide mean, a pool of many dust UTxOs plus a few large ones pulls
// the mean down next to the dust, so every dust UTxO scores far above a large
// one and the deficit is covered by accumulating dust — 90 inputs where one
// would do, for a pool of 1000 1-ADA UTxOs and one of 100 ADA. Recomputing
// the mean over the unselected pool each round does not help: consuming dust
// barely moves a dust-dominated mean. So a candidate that covers the whole
// remaining deficit of the class on its own ("closer") is always preferred,
// and priority decides only which closer to take. Priority still governs
// every pick that cannot finish the class alone, so MACS keeps consuming
// mid-range UTxOs rather than degenerating into largest-first.
//
// The paper's dust-avoidance requirement is met with a bounded sweep: when a
// selection exists and sweeping is enabled, up to MaxDustInputs ADA-only
// UTxOs below DustThreshold lovelace are appended (smallest first), so dust
// is consolidated into change instead of accumulating. The zero value runs
// the pure algorithm with no sweeping; NewMACSSelector returns the
// recommended configuration.
type MACSSelector struct {
	// DustThreshold is the lovelace amount below which an ADA-only UTxO is
	// considered dust and eligible for sweeping. Zero disables sweeping.
	DustThreshold uint64
	// MaxDustInputs caps how many dust UTxOs one selection may sweep.
	MaxDustInputs int
	// MinChange is the smallest lovelace leftover worth emitting as a change
	// output. A pick whose leftover falls between zero and this value is
	// avoided where the pool allows, because the builder cannot emit a change
	// output below the ledger's minimum UTxO value and folds the remainder
	// into the fee instead, where the user simply loses it. Zero uses
	// macsSelectorMinChange.
	MinChange uint64
}

// macsSelectorMinChange is the default MinChange: comfortably above the
// minimum UTxO value of a plain ADA-only change output, which at mainnet's
// 4310 coins-per-UTxO-byte is about 0.86 ADA. Priority alone steers picks
// toward the pool mean, which is exactly where a payment near that mean leaves
// change inside the dead band, so without this the selector burns the leftover
// as fee on a majority of transactions against a realistic pool.
const macsSelectorMinChange = 1_500_000

// NewMACSSelector returns a MACS selector with dust sweeping enabled:
// UTxOs below 1 ADA (the order of Cardano's minimum UTxO value) are swept,
// at most two per selection.
func NewMACSSelector() *MACSSelector {
	return &MACSSelector{
		DustThreshold: 1_000_000,
		MaxDustInputs: 2,
		MinChange:     macsSelectorMinChange,
	}
}

// Name returns the algorithm's identifier.
func (s *MACSSelector) Name() string { return "macs" }

// macsClass identifies one asset class of the target: a (policy, name) pair
// or the chain's native coin.
type macsClass struct {
	policy common.Blake2b224
	name   []byte
	isCoin bool
}

type macsCandidate struct {
	utxo common.Utxo
	ref  string
	coin uint64
}

// value returns the candidate's quantity of the given asset class. The
// returned big.Int must not be mutated: it may alias the UTxO's asset map.
func (c *macsCandidate) value(cls macsClass) *big.Int {
	if cls.isCoin {
		return new(big.Int).SetUint64(c.coin)
	}
	assets := c.utxo.Output.Assets()
	if assets == nil {
		return big.NewInt(0)
	}
	qty := assets.Asset(cls.policy, cls.name)
	if qty == nil || qty.Sign() <= 0 {
		return big.NewInt(0)
	}
	return qty
}

// macsPick records a selected candidate with the priority terms it was
// chosen under, for the pruning pass.
type macsPick struct {
	idx    int
	cand   *macsCandidate
	v, dev *big.Int
	pruned bool
}

// macsClassView holds one asset class's precomputed per-candidate terms.
// avg(S,c) is a pool-wide constant, so a candidate's priority for the class
// never changes during a selection: the terms are computed once per class
// instead of once per pick, which is what made picking cost O(n) every time.
type macsClassView struct {
	// vals holds each candidate's quantity of the class, and devs the
	// matching |v - avg(S,c)|, both indexed by candidate index. devs is
	// only populated where vals is positive.
	vals []*big.Int
	devs []*big.Int
	// held lists the candidate indexes with a positive quantity, in pool
	// order, and poolMax is the largest quantity among them.
	held    []int
	poolMax *big.Int
	// byPriority is held ordered by descending priority and byValue by
	// descending quantity. Both are built on first use, since a class covered
	// by a single closer needs neither. The cursors only move forward, so
	// walking either ordering costs O(n) across a whole selection.
	byPriority []int
	byValue    []int
	prioCur    int
	valCur     int
}

// availableMax returns an upper bound on the quantity still unselected: the
// pool-wide maximum until a scan proves that bound stale, and the exact
// maximum afterwards, so no later round repeats a scan that cannot succeed.
func (v *macsClassView) availableMax(selected []bool) *big.Int {
	if v.byValue == nil {
		return v.poolMax
	}
	for v.valCur < len(v.byValue) && selected[v.byValue[v.valCur]] {
		v.valCur++
	}
	if v.valCur >= len(v.byValue) {
		return new(big.Int)
	}
	return v.vals[v.byValue[v.valCur]]
}

// next returns the index of the candidate to pick for this class given the
// quantity still deficient, or -1 when no unselected candidate holds the
// class at all.
//
// minChange is the smallest leftover worth emitting as a change output, and is
// nil for every class but the coin. See macsSelectorMinChange for why the coin
// class needs it.
func (v *macsClassView) next(
	cands []*macsCandidate,
	selected []bool,
	deficit *big.Int,
	cmp *macsPriorityCmp,
	minChange *big.Int,
) int {
	// No candidate covers the deficit alone unless the largest one does, so
	// the scan below is skipped in the common case, and once it succeeds the
	// class is covered and never scanned again.
	if v.availableMax(selected).Cmp(deficit) >= 0 {
		best, largest := -1, -1
		leftover := new(big.Int)
		for _, idx := range v.held {
			if selected[idx] || v.vals[idx].Cmp(deficit) < 0 {
				continue
			}
			// Track the largest closer as the fallback for when no candidate
			// leaves an emittable change amount, so the leftover is at least
			// as far above the dead band as this pool allows.
			if largest == -1 || betterFallback(
				v.vals[idx], cands[idx].ref,
				v.vals[largest], cands[largest].ref,
			) {
				largest = idx
			}
			// Skip a candidate whose leftover would be stranded: too small to
			// become a change output, so the builder folds it into the fee.
			if minChange != nil {
				leftover.Sub(v.vals[idx], deficit)
				if leftover.Sign() != 0 && leftover.Cmp(minChange) < 0 {
					continue
				}
			}
			if best == -1 || cmp.better(
				v.vals[idx], v.devs[idx], cands[idx].ref,
				v.vals[best], v.devs[best], cands[best].ref,
			) {
				best = idx
			}
		}
		if best >= 0 {
			return best
		}
		// Closers exist but every one strands its leftover. Take the largest:
		// a bigger input cannot make the change smaller, and one input still
		// beats accumulating several.
		if largest >= 0 {
			return largest
		}
		// The pool-wide bound was stale, because the largest candidates went
		// to earlier picks. Order by quantity so availableMax is exact from
		// here on.
		v.byValue = v.orderHeld(func(x, y int) bool {
			if cmp := v.vals[x].Cmp(v.vals[y]); cmp != 0 {
				return cmp > 0
			}
			return cands[x].ref < cands[y].ref
		})
	}

	if v.byPriority == nil {
		v.byPriority = v.orderHeld(func(x, y int) bool {
			return cmp.better(
				v.vals[x], v.devs[x], cands[x].ref,
				v.vals[y], v.devs[y], cands[y].ref,
			)
		})
	}
	for v.prioCur < len(v.byPriority) && selected[v.byPriority[v.prioCur]] {
		v.prioCur++
	}
	if v.prioCur >= len(v.byPriority) {
		return -1
	}
	return v.byPriority[v.prioCur]
}

// orderHeld returns the class's candidate indexes sorted by less, which
// compares two candidate indexes.
func (v *macsClassView) orderHeld(less func(x, y int) bool) []int {
	order := make([]int, len(v.held))
	copy(order, v.held)
	sort.Slice(order, func(a, b int) bool {
		return less(order[a], order[b])
	})
	return order
}

// Select returns a subset of available whose summed value covers target.
func (s *MACSSelector) Select(
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

	// MACS reads every amount to compute pool averages, so the whole pool is
	// validated up front. Amounts come from a remote backend; reject anything
	// outside the uint64 lovelace range (big.Int.Uint64 is undefined out of range).
	if err := validateUtxos(available); err != nil {
		return nil, fmt.Errorf("invalid coin-selection input: %w", err)
	}
	cands := make([]*macsCandidate, 0, len(available))
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
		cands = append(cands, &macsCandidate{
			utxo: available[i],
			ref:  utxoRef(available[i]),
			coin: amt.Uint64(),
		})
	}

	classes := macsTargetClasses(target)
	views, err := macsClassViews(ctx, classes, cands)
	if err != nil {
		return nil, err
	}

	cmp := newMACSPriorityCmp()
	// A zero MinChange means "unset" rather than "no floor": the zero value of
	// MACSSelector runs the paper's algorithm, and only the configured
	// selector steers away from the dead band.
	var minChangeFloor *big.Int
	if s.MinChange > 0 {
		minChangeFloor = new(big.Int).SetUint64(s.MinChange)
	}
	selected := make([]bool, len(cands))
	var picks []*macsPick
	for round := 0; ; round++ {
		if round%selectionCancelStride == 0 {
			if err := selectionInterrupted(ctx); err != nil {
				return nil, err
			}
		}
		clsIdx, deficit, deficient := macsFirstDeficit(remaining, classes)
		if !deficient {
			break
		}
		view := views[clsIdx]
		var minChange *big.Int
		if classes[clsIdx].isCoin {
			minChange = minChangeFloor
		}
		idx := view.next(cands, selected, deficit, cmp, minChange)
		if idx < 0 {
			return nil, errors.New(
				"insufficient UTxOs to cover required value",
			)
		}
		selected[idx] = true
		cand := cands[idx]
		picks = append(picks, &macsPick{
			idx:  idx,
			cand: cand,
			v:    view.vals[idx],
			dev:  view.devs[idx],
		})

		if remaining.Coin <= cand.coin {
			remaining.Coin = 0
		} else {
			remaining.Coin -= cand.coin
		}
		if remaining.Assets != nil && cand.utxo.Output.Assets() != nil {
			subtractAssetsSaturating(
				remaining.Assets,
				cand.utxo.Output.Assets(),
			)
		}
	}

	macsPruneRedundant(picks, views, classes, target, cmp)

	result := make([]common.Utxo, 0, len(picks))
	keep := make([]bool, len(cands))
	for _, p := range picks {
		if !p.pruned {
			result = append(result, p.cand.utxo)
			keep[p.idx] = true
		}
	}
	result = s.sweepDust(result, keep, cands)
	return result, nil
}

// sweepDust appends up to MaxDustInputs unselected ADA-only UTxOs below
// DustThreshold, smallest first (ties by ref), consolidating dust into the
// transaction's change. Token-carrying UTxOs are never swept so change
// outputs do not accumulate assets the target did not ask for.
func (s *MACSSelector) sweepDust(
	result []common.Utxo,
	keep []bool,
	cands []*macsCandidate,
) []common.Utxo {
	if s.DustThreshold == 0 || s.MaxDustInputs <= 0 || len(result) == 0 {
		return result
	}
	var dust []*macsCandidate
	for i, c := range cands {
		if keep[i] || c.coin >= s.DustThreshold {
			continue
		}
		if c.utxo.Output.Assets() != nil {
			continue
		}
		dust = append(dust, c)
	}
	sort.Slice(dust, func(i, j int) bool {
		if dust[i].coin != dust[j].coin {
			return dust[i].coin < dust[j].coin
		}
		return dust[i].ref < dust[j].ref
	})
	for i := 0; i < len(dust) && i < s.MaxDustInputs; i++ {
		result = append(result, dust[i].utxo)
	}
	return result
}

// macsTargetClasses returns the target's asset classes in deterministic
// order: native assets sorted by policy then name, lovelace last (most UTxOs
// carry lovelace incidentally, so covering assets first minimizes inputs).
func macsTargetClasses(target Value) []macsClass {
	var classes []macsClass
	if target.Assets != nil {
		policies := target.Assets.Policies()
		sort.Slice(policies, func(i, j int) bool {
			return bytes.Compare(policies[i].Bytes(), policies[j].Bytes()) < 0
		})
		for _, policy := range policies {
			names := target.Assets.Assets(policy)
			sort.Slice(names, func(i, j int) bool {
				return bytes.Compare(names[i], names[j]) < 0
			})
			for _, name := range names {
				qty := target.Assets.Asset(policy, name)
				if qty == nil || qty.Sign() <= 0 {
					continue
				}
				classes = append(classes, macsClass{policy: policy, name: name})
			}
		}
	}
	return append(classes, macsClass{isCoin: true})
}

// macsClassViews computes each class's per-candidate quantities and their
// deviations from avg(S,c). Absent assets count as zero in the average, per
// the paper.
func macsClassViews(
	ctx context.Context,
	classes []macsClass,
	cands []*macsCandidate,
) ([]*macsClassView, error) {
	views := make([]*macsClassView, len(classes))
	n := big.NewInt(int64(len(cands)))
	for i, cls := range classes {
		vals := make([]*big.Int, len(cands))
		avg := big.NewInt(0)
		poolMax := big.NewInt(0)
		count := 0
		for j, c := range cands {
			if j%selectionCancelStride == 0 {
				if err := selectionInterrupted(ctx); err != nil {
					return nil, err
				}
			}
			vals[j] = c.value(cls)
			avg.Add(avg, vals[j])
			if vals[j].Sign() > 0 {
				count++
				if vals[j].Cmp(poolMax) > 0 {
					poolMax = vals[j]
				}
			}
		}
		if len(cands) > 0 {
			avg.Div(avg, n)
		}

		devs := make([]*big.Int, len(cands))
		held := make([]int, 0, count)
		for j, v := range vals {
			if v.Sign() <= 0 {
				continue
			}
			dev := new(big.Int).Sub(v, avg)
			devs[j] = dev.Abs(dev)
			held = append(held, j)
		}

		views[i] = &macsClassView{
			vals:    vals,
			devs:    devs,
			held:    held,
			poolMax: poolMax,
		}
	}
	return views, nil
}

// macsFirstDeficit returns the index of the first class the remaining target
// still needs, in class order, along with the quantity still missing.
func macsFirstDeficit(
	remaining Value,
	classes []macsClass,
) (int, *big.Int, bool) {
	for i, cls := range classes {
		if cls.isCoin {
			if remaining.Coin > 0 {
				return i, new(big.Int).SetUint64(remaining.Coin), true
			}
			continue
		}
		if remaining.Assets == nil {
			continue
		}
		qty := remaining.Assets.Asset(cls.policy, cls.name)
		if qty != nil && qty.Sign() > 0 {
			return i, qty, true
		}
	}
	return 0, nil, false
}

// betterFallback reports whether the closer (v1, ref1) is the better fallback
// than (v2, ref2): the larger quantity, ties broken by the smaller UTxO ref so
// selection stays deterministic.
func betterFallback(v1 *big.Int, ref1 string, v2 *big.Int, ref2 string) bool {
	if cmp := v1.Cmp(v2); cmp != 0 {
		return cmp > 0
	}
	return ref1 < ref2
}

// macsPriorityCmp compares MACS priorities, reusing its own scratch space so
// that sorting a pool by priority does not allocate per comparison. It holds
// mutable state, so each selection makes its own.
type macsPriorityCmp struct {
	left, right, one big.Int
}

func newMACSPriorityCmp() *macsPriorityCmp {
	cmp := &macsPriorityCmp{}
	cmp.one.SetInt64(1)
	return cmp
}

// better reports whether priority v1/(d1+1) beats v2/(d2+1), compared exactly
// by cross-multiplication. Ties prefer the larger value, then the smaller
// UTxO ref, so selection is deterministic.
func (c *macsPriorityCmp) better(
	v1, d1 *big.Int, ref1 string,
	v2, d2 *big.Int, ref2 string,
) bool {
	c.left.Add(d2, &c.one)
	c.left.Mul(&c.left, v1)
	c.right.Add(d1, &c.one)
	c.right.Mul(&c.right, v2)
	if cmp := c.left.Cmp(&c.right); cmp != 0 {
		return cmp > 0
	}
	if cmp := v1.Cmp(v2); cmp != 0 {
		return cmp > 0
	}
	return ref1 < ref2
}

// macsPruneRedundant drops picks whose removal keeps the target covered,
// trying lowest-priority picks first. Greedy per-class coverage can select a
// UTxO for one asset that a later pick (chosen for a different asset) also
// carries, leaving the earlier pick redundant.
func macsPruneRedundant(
	picks []*macsPick,
	views []*macsClassView,
	classes []macsClass,
	target Value,
	cmp *macsPriorityCmp,
) {
	if len(picks) < 2 {
		return
	}

	// Per-class totals over the current (unpruned) selection and the
	// required quantities.
	sums := make([]*big.Int, len(classes))
	need := make([]*big.Int, len(classes))
	for i, cls := range classes {
		sums[i] = big.NewInt(0)
		for _, p := range picks {
			sums[i].Add(sums[i], views[i].vals[p.idx])
		}
		if cls.isCoin {
			need[i] = new(big.Int).SetUint64(target.Coin)
		} else {
			need[i] = new(big.Int).Set(target.Assets.Asset(cls.policy, cls.name))
		}
	}

	order := make([]*macsPick, len(picks))
	copy(order, picks)
	sort.SliceStable(order, func(i, j int) bool {
		return cmp.better(
			order[j].v, order[j].dev, order[j].cand.ref,
			order[i].v, order[i].dev, order[i].cand.ref,
		)
	})

	for _, p := range order {
		redundant := true
		for i := range classes {
			rest := new(big.Int).Sub(sums[i], views[i].vals[p.idx])
			if rest.Cmp(need[i]) < 0 {
				redundant = false
				break
			}
		}
		if redundant {
			p.pruned = true
			for i := range classes {
				sums[i].Sub(sums[i], views[i].vals[p.idx])
			}
		}
	}
}

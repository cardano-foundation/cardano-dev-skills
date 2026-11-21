package apollo

import (
	"bytes"
	"math/big"
	"sort"

	"github.com/blinklabs-io/gouroboros/ledger/common"
)

// The sort helpers below derive what they compare once per element, into a key
// slice, and sort a permutation of indexes over it. Validating a UTxO and
// reading its id or amount cost far more than the comparison itself, and a
// comparator runs O(n log n) times.
//
// Only valid UTxOs are inspected further: a malformed one has no usable input
// or output to read.

// utxoSortKey holds the terms SortUtxos compares.
type utxoSortKey struct {
	valid     bool
	hasAssets bool
	amount    *big.Int
}

// inputSortKey holds the terms SortInputs compares.
type inputSortKey struct {
	valid bool
	id    []byte
	index uint32
}

// identityOrder returns the permutation the comparators sort, initially the
// slice's own order so that tied elements keep it.
func identityOrder(n int) []int {
	order := make([]int, n)
	for i := range order {
		order[i] = i
	}
	return order
}

// permute returns utxos rearranged into the given order.
func permute(utxos []common.Utxo, order []int) []common.Utxo {
	res := make([]common.Utxo, len(utxos))
	for i, idx := range order {
		res[i] = utxos[idx]
	}
	return res
}

// SortUtxos sorts a slice of UTxOs with ADA-only UTxOs first (by descending amount),
// then UTxOs with assets.
func SortUtxos(utxos []common.Utxo) []common.Utxo {
	keys := make([]utxoSortKey, len(utxos))
	for i, utxo := range utxos {
		if validateUtxo(utxo) != nil {
			continue
		}
		keys[i] = utxoSortKey{
			valid:     true,
			hasAssets: utxo.Output.Assets() != nil,
			amount:    utxo.Output.Amount(),
		}
	}
	order := identityOrder(len(utxos))
	sort.SliceStable(order, func(a, b int) bool {
		i, j := &keys[order[a]], &keys[order[b]]
		if i.valid != j.valid {
			return i.valid
		}
		if !i.valid {
			return false
		}
		if i.hasAssets == j.hasAssets {
			if i.amount != nil && j.amount != nil {
				return i.amount.Cmp(j.amount) > 0
			}
			return false
		}
		return j.hasAssets
	})
	return permute(utxos, order)
}

// SortInputs sorts UTxOs by transaction ID and index for deterministic ordering.
func SortInputs(inputs []common.Utxo) []common.Utxo {
	keys := make([]inputSortKey, len(inputs))
	for i, utxo := range inputs {
		if validateUtxo(utxo) != nil {
			continue
		}
		keys[i] = inputSortKey{
			valid: true,
			id:    utxo.Id.Id().Bytes(),
			index: utxo.Id.Index(),
		}
	}
	order := identityOrder(len(inputs))
	sort.SliceStable(order, func(a, b int) bool {
		i, j := &keys[order[a]], &keys[order[b]]
		if i.valid != j.valid {
			return i.valid
		}
		if !i.valid {
			return false
		}
		// Transaction ids are all Blake2b256, so they are of equal width and
		// comparing the raw bytes orders them exactly as comparing their hex
		// encodings did.
		if cmp := bytes.Compare(i.id, j.id); cmp != 0 {
			return cmp < 0
		}
		return i.index < j.index
	})
	return permute(inputs, order)
}

package plutusencoder

import (
	"bytes"
	"errors"
	"fmt"
	"math/big"
	"slices"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/plutigo/data"
)

const valueMaxTokenNameSize = 32

// Value is the Plutus ledger Value: a map of policy id to a map of asset name
// to quantity. Lovelace is encoded under the empty policy id and the empty
// asset name. Encoding omits a zero quantity and an empty token map, and
// sorts both levels by key bytes. Decoding keeps a zero quantity, and accepts
// an unsorted map or an empty token map. A V4 tagged Value is still rejected
// unless it passes Validate.
type Value struct {
	Lovelace uint64
	Assets   common.MultiAsset[uint64]
}

func marshalPlutusValue(v Value, v4Tagged bool) (data.PlutusData, error) {
	policies := v.Assets.Policies()
	slices.SortFunc(policies, func(a, b common.Blake2b224) int {
		return bytes.Compare(a.Bytes(), b.Bytes())
	})

	pairs := make([][2]data.PlutusData, 0, len(policies)+1)
	if v.Lovelace > 0 {
		pairs = append(pairs, [2]data.PlutusData{
			data.NewByteString(nil),
			data.NewMap([][2]data.PlutusData{
				{
					data.NewByteString(nil),
					data.NewInteger(new(big.Int).SetUint64(v.Lovelace)),
				},
			}),
		})
	}

	for _, policyId := range policies {
		names := v.Assets.Assets(policyId)
		slices.SortFunc(names, bytes.Compare)
		inner := make([][2]data.PlutusData, 0, len(names))
		for _, name := range names {
			if len(name) > valueMaxTokenNameSize {
				return nil, fmt.Errorf("token name exceeds %d bytes: got %d", valueMaxTokenNameSize, len(name))
			}
			amount := v.Assets.Asset(policyId, name)
			if amount == 0 {
				continue
			}
			inner = append(inner, [2]data.PlutusData{
				data.NewByteString(append([]byte(nil), name...)),
				data.NewInteger(new(big.Int).SetUint64(amount)),
			})
		}
		if len(inner) == 0 {
			continue
		}
		pairs = append(pairs, [2]data.PlutusData{
			data.NewByteString(append([]byte(nil), policyId.Bytes()...)),
			data.NewMap(inner),
		})
	}

	m := data.NewMap(pairs).(*data.Map)
	if !v4Tagged {
		return m, nil
	}
	v4 := &data.Value{Inner: m}
	if err := v4.Validate(); err != nil {
		return nil, err
	}
	return v4, nil
}

func unmarshalPlutusValue(pd data.PlutusData) (Value, error) {
	var outer *data.Map
	switch v := pd.(type) {
	case *data.Map:
		if plutusNil(v) {
			return Value{}, fmt.Errorf("expected Plutus Value map or V4 Value, got %T", pd)
		}
		outer = v
	case *data.Value:
		if plutusNil(v) || v.Inner == nil {
			return Value{}, fmt.Errorf("expected Plutus Value map or V4 Value, got %T", pd)
		}
		if err := v.Validate(); err != nil {
			return Value{}, err
		}
		outer = v.Inner
	default:
		return Value{}, fmt.Errorf("expected Plutus Value map or V4 Value, got %T", pd)
	}

	assets := make(map[common.Blake2b224]map[cbor.ByteString]uint64, len(outer.Pairs))
	seenAda := false
	var lovelace uint64

	for _, pair := range outer.Pairs {
		policyBytes, ok := pair[0].(*data.ByteString)
		if !ok || plutusNil(policyBytes) {
			return Value{}, fmt.Errorf("expected byte string policy id, got %T", pair[0])
		}
		innerMap, ok := pair[1].(*data.Map)
		if !ok || plutusNil(innerMap) {
			return Value{}, fmt.Errorf("expected asset map for policy, got %T", pair[1])
		}

		if len(policyBytes.Inner) == 0 {
			if seenAda {
				return Value{}, errors.New("duplicate lovelace policy in Plutus Value")
			}
			seenAda = true
			if len(innerMap.Pairs) == 0 {
				continue
			}
			if len(innerMap.Pairs) != 1 {
				return Value{}, errors.New("lovelace policy must contain one entry")
			}
			nameBytes, ok := innerMap.Pairs[0][0].(*data.ByteString)
			if !ok || plutusNil(nameBytes) || len(nameBytes.Inner) != 0 {
				return Value{}, errors.New("lovelace asset name must be empty")
			}
			qty, err := valueQuantity(innerMap.Pairs[0][1])
			if err != nil {
				return Value{}, err
			}
			lovelace = qty
			continue
		}

		policy, err := common.NewBlake2b224Checked(policyBytes.Inner)
		if err != nil {
			return Value{}, err
		}
		if _, exists := assets[policy]; exists {
			return Value{}, errors.New("duplicate policy id in Plutus Value")
		}

		policyAssets := make(map[cbor.ByteString]uint64, len(innerMap.Pairs))
		for _, item := range innerMap.Pairs {
			nameBytes, ok := item[0].(*data.ByteString)
			if !ok || plutusNil(nameBytes) || len(nameBytes.Inner) > valueMaxTokenNameSize {
				return Value{}, fmt.Errorf("expected token name up to %d bytes", valueMaxTokenNameSize)
			}
			qty, err := valueQuantity(item[1])
			if err != nil {
				return Value{}, err
			}
			key := cbor.NewByteString(append([]byte(nil), nameBytes.Inner...))
			if _, dup := policyAssets[key]; dup {
				return Value{}, errors.New("duplicate token name in Plutus Value")
			}
			policyAssets[key] = qty
		}
		assets[policy] = policyAssets
	}

	return Value{
		Lovelace: lovelace,
		Assets:   common.NewMultiAsset(assets),
	}, nil
}

func valueQuantity(pd data.PlutusData) (uint64, error) {
	integer, ok := pd.(*data.Integer)
	if !ok || plutusNil(integer) || integer.Inner == nil {
		return 0, fmt.Errorf("expected integer quantity, got %T", pd)
	}
	if integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
		return 0, errors.New("asset quantity must be a non-negative uint64")
	}
	return integer.Inner.Uint64(), nil
}

package apollo

import (
	"bytes"
	"errors"
	"fmt"
	"reflect"

	"github.com/blinklabs-io/gouroboros/cbor"
	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/gouroboros/ledger/conway"
	"github.com/blinklabs-io/gouroboros/ledger/dijkstra"
)

var (
	storedCBORType    = reflect.TypeOf(cbor.DecodeStoreCbor{})
	bodyHashCacheType = reflect.TypeOf(common.Blake2b256Cache{})
)

func preservedBodyCBOR(outerCBOR, bodyCBOR, originalCBOR []byte) error {
	if len(originalCBOR) == 0 || !bytes.Equal(bodyCBOR, originalCBOR) {
		return errors.New("transaction body differs from preserved CBOR")
	}
	if len(outerCBOR) == 0 {
		return nil
	}
	var envelope []cbor.RawMessage
	if _, err := cbor.DecodeExact(outerCBOR, &envelope); err != nil {
		return fmt.Errorf("decode preserved transaction: %w", err)
	}
	if len(envelope) == 0 || !bytes.Equal(envelope[0], originalCBOR) {
		return errors.New("transaction body differs from preserved CBOR")
	}
	return nil
}

func (a *Apollo) validateTransactionBodyIntegrity() error {
	if a.loadedBodyErr != nil {
		return a.loadedBodyErr
	}
	if !a.loadedTx {
		return nil
	}
	if a.dijkstraTx != nil {
		if err := preservedBodyCBOR(a.dijkstraTx.DecodeStoreCbor.Cbor(), a.dijkstraTx.Body.Cbor(), a.loadedBodyCBOR); err != nil {
			return err
		}
		var original dijkstra.DijkstraTransactionBody
		if _, err := cbor.DecodeExact(a.loadedBodyCBOR, &original); err != nil {
			return fmt.Errorf("decode preserved transaction body: %w", err)
		}
		if !sameDecodedValue(reflect.ValueOf(a.dijkstraTx.Body), reflect.ValueOf(original)) {
			return errors.New("transaction body differs from preserved CBOR")
		}
		return nil
	}
	if a.tx == nil {
		return nil
	}
	if err := preservedBodyCBOR(a.tx.DecodeStoreCbor.Cbor(), a.tx.Body.Cbor(), a.loadedBodyCBOR); err != nil {
		return err
	}
	var original conway.ConwayTransactionBody
	if _, err := cbor.DecodeExact(a.loadedBodyCBOR, &original); err != nil {
		return fmt.Errorf("decode preserved transaction body: %w", err)
	}
	if !sameDecodedValue(reflect.ValueOf(a.tx.Body), reflect.ValueOf(original)) {
		return errors.New("transaction body differs from preserved CBOR")
	}
	return nil
}

// sameDecodedValue compares ledger fields while ignoring cached CBOR and body
// hashes. Pointer-keyed maps need value comparison because decoding the same
// body twice creates distinct key pointers.
func sameDecodedValue(left, right reflect.Value) bool {
	if !left.IsValid() || !right.IsValid() {
		return !left.IsValid() && !right.IsValid()
	}
	if left.Type() != right.Type() {
		return false
	}
	if left.Type() == storedCBORType || left.Type() == bodyHashCacheType {
		return true
	}
	switch left.Kind() {
	case reflect.Interface, reflect.Pointer:
		if left.IsNil() || right.IsNil() {
			return left.IsNil() && right.IsNil()
		}
		return sameDecodedValue(left.Elem(), right.Elem())
	case reflect.Struct:
		for i := 0; i < left.NumField(); i++ {
			if !sameDecodedValue(left.Field(i), right.Field(i)) {
				return false
			}
		}
		return true
	case reflect.Array, reflect.Slice:
		if left.Kind() == reflect.Slice && left.IsNil() != right.IsNil() {
			return false
		}
		if left.Len() != right.Len() {
			return false
		}
		for i := 0; i < left.Len(); i++ {
			if !sameDecodedValue(left.Index(i), right.Index(i)) {
				return false
			}
		}
		return true
	case reflect.Map:
		if left.IsNil() != right.IsNil() || left.Len() != right.Len() {
			return false
		}
		if mapKeyUsesValueEquality(left.Type().Key()) {
			for _, key := range left.MapKeys() {
				other := right.MapIndex(key)
				if !other.IsValid() || !sameDecodedValue(left.MapIndex(key), other) {
					return false
				}
			}
			return true
		}
		leftKeys := left.MapKeys()
		rightKeys := right.MapKeys()
		used := make([]bool, len(rightKeys))
		for _, leftKey := range leftKeys {
			matched := false
			for i, rightKey := range rightKeys {
				if used[i] || !sameDecodedValue(leftKey, rightKey) ||
					!sameDecodedValue(left.MapIndex(leftKey), right.MapIndex(rightKey)) {
					continue
				}
				used[i] = true
				matched = true
				break
			}
			if !matched {
				return false
			}
		}
		return true
	case reflect.Bool:
		return left.Bool() == right.Bool()
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return left.Int() == right.Int()
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
		return left.Uint() == right.Uint()
	case reflect.Float32, reflect.Float64:
		return left.Float() == right.Float()
	case reflect.Complex64, reflect.Complex128:
		return left.Complex() == right.Complex()
	case reflect.String:
		return left.String() == right.String()
	case reflect.Invalid:
		return true
	default:
		if left.CanInterface() && right.CanInterface() {
			return reflect.DeepEqual(left.Interface(), right.Interface())
		}
		return false
	}
}

func mapKeyUsesValueEquality(keyType reflect.Type) bool {
	switch keyType.Kind() {
	case reflect.Bool,
		reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr,
		reflect.Float32, reflect.Float64, reflect.Complex64, reflect.Complex128,
		reflect.String:
		return true
	case reflect.Array:
		return mapKeyUsesValueEquality(keyType.Elem())
	case reflect.Struct:
		for i := 0; i < keyType.NumField(); i++ {
			if !mapKeyUsesValueEquality(keyType.Field(i).Type) {
				return false
			}
		}
		return true
	default:
		return false
	}
}

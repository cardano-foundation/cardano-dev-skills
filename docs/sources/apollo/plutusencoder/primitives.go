package plutusencoder

import (
	"encoding/hex"
	"fmt"
	"math"
	"math/big"
	"reflect"

	"github.com/blinklabs-io/plutigo/data"
)

func marshalInt(val reflect.Value) (data.PlutusData, error) {
	switch val.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return data.NewInteger(big.NewInt(val.Int())), nil
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return data.NewInteger(new(big.Int).SetUint64(val.Uint())), nil
	default:
		return nil, fmt.Errorf("int tag requires integer type, got %s", val.Kind())
	}
}

func marshalBigInt(val reflect.Value) (data.PlutusData, error) {
	switch v := val.Interface().(type) {
	case *big.Int:
		if v == nil {
			return data.NewInteger(big.NewInt(0)), nil
		}
		return data.NewInteger(v), nil
	case big.Int:
		return data.NewInteger(&v), nil
	default:
		return nil, fmt.Errorf("BigInt tag requires *big.Int or big.Int, got %T", val.Interface())
	}
}

func marshalBytes(val reflect.Value) (data.PlutusData, error) {
	if val.Kind() != reflect.Slice || val.Type().Elem().Kind() != reflect.Uint8 {
		return nil, fmt.Errorf("bytes tag requires []byte, got %s", val.Type())
	}
	return data.NewByteString(val.Bytes()), nil
}

func marshalStringBytes(val reflect.Value) (data.PlutusData, error) {
	if val.Kind() != reflect.String {
		return nil, fmt.Errorf("StringBytes tag requires string, got %s", val.Kind())
	}
	return data.NewByteString([]byte(val.String())), nil
}

func marshalHexString(val reflect.Value) (data.PlutusData, error) {
	if val.Kind() != reflect.String {
		return nil, fmt.Errorf("HexString tag requires string, got %s", val.Kind())
	}
	b, err := hex.DecodeString(val.String())
	if err != nil {
		return nil, fmt.Errorf("HexString: invalid hex: %w", err)
	}
	return data.NewByteString(b), nil
}

func marshalBool(val reflect.Value, useIndef bool) (data.PlutusData, error) {
	if val.Kind() != reflect.Bool {
		return nil, fmt.Errorf("bool tag requires bool, got %s", val.Kind())
	}
	tag := uint(0)
	if val.Bool() {
		tag = 1
	}
	return data.NewConstrDefIndef(useIndef, tag), nil
}

func unmarshalInt(pd data.PlutusData, fieldVal reflect.Value) error {
	integer, ok := pd.(*data.Integer)
	if !ok {
		return fmt.Errorf("expected Integer, got %T", pd)
	}
	switch fieldVal.Kind() {
	case reflect.Int:
		if !integer.Inner.IsInt64() {
			return fmt.Errorf("integer value %s does not fit in int64", integer.Inner.String())
		}
		v := integer.Inner.Int64()
		if v < math.MinInt || v > math.MaxInt {
			return fmt.Errorf("integer value %d does not fit in int", v)
		}
		fieldVal.SetInt(v)
	case reflect.Int64:
		if !integer.Inner.IsInt64() {
			return fmt.Errorf("integer value %s does not fit in int64", integer.Inner.String())
		}
		fieldVal.SetInt(integer.Inner.Int64())
	case reflect.Int32:
		if !integer.Inner.IsInt64() {
			return fmt.Errorf("integer value %s overflows int64 (required for int32)", integer.Inner.String())
		}
		v := integer.Inner.Int64()
		if v < math.MinInt32 || v > math.MaxInt32 {
			return fmt.Errorf("integer value %d does not fit in int32", v)
		}
		fieldVal.SetInt(v)
	case reflect.Int16:
		if !integer.Inner.IsInt64() {
			return fmt.Errorf("integer value %s overflows int64 (required for int16)", integer.Inner.String())
		}
		v := integer.Inner.Int64()
		if v < math.MinInt16 || v > math.MaxInt16 {
			return fmt.Errorf("integer value %d does not fit in int16", v)
		}
		fieldVal.SetInt(v)
	case reflect.Int8:
		if !integer.Inner.IsInt64() {
			return fmt.Errorf("integer value %s overflows int64 (required for int8)", integer.Inner.String())
		}
		v := integer.Inner.Int64()
		if v < math.MinInt8 || v > math.MaxInt8 {
			return fmt.Errorf("integer value %d does not fit in int8", v)
		}
		fieldVal.SetInt(v)
	case reflect.Uint:
		if integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
			return fmt.Errorf("integer value %s does not fit in uint64", integer.Inner.String())
		}
		v := integer.Inner.Uint64()
		if v > math.MaxUint {
			return fmt.Errorf("integer value %d does not fit in uint", v)
		}
		fieldVal.SetUint(v)
	case reflect.Uint64:
		if integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
			return fmt.Errorf("integer value %s does not fit in uint64", integer.Inner.String())
		}
		fieldVal.SetUint(integer.Inner.Uint64())
	case reflect.Uint32:
		if integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
			return fmt.Errorf("integer value %s overflows uint64 (required for uint32)", integer.Inner.String())
		}
		v := integer.Inner.Uint64()
		if v > math.MaxUint32 {
			return fmt.Errorf("integer value %d does not fit in uint32", v)
		}
		fieldVal.SetUint(v)
	case reflect.Uint16:
		if integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
			return fmt.Errorf("integer value %s overflows uint64 (required for uint16)", integer.Inner.String())
		}
		v := integer.Inner.Uint64()
		if v > math.MaxUint16 {
			return fmt.Errorf("integer value %d does not fit in uint16", v)
		}
		fieldVal.SetUint(v)
	case reflect.Uint8:
		if integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
			return fmt.Errorf("integer value %s overflows uint64 (required for uint8)", integer.Inner.String())
		}
		v := integer.Inner.Uint64()
		if v > math.MaxUint8 {
			return fmt.Errorf("integer value %d does not fit in uint8", v)
		}
		fieldVal.SetUint(v)
	default:
		return fmt.Errorf("int tag requires integer type, got %s", fieldVal.Kind())
	}
	return nil
}

func unmarshalBigInt(pd data.PlutusData, fieldVal reflect.Value) error {
	integer, ok := pd.(*data.Integer)
	if !ok {
		return fmt.Errorf("expected Integer, got %T", pd)
	}
	switch fieldVal.Type() {
	case reflect.TypeFor[*big.Int]():
		fieldVal.Set(reflect.ValueOf(new(big.Int).Set(integer.Inner)))
	case reflect.TypeFor[big.Int]():
		fieldVal.Set(reflect.ValueOf(*new(big.Int).Set(integer.Inner)))
	default:
		return fmt.Errorf("BigInt tag requires *big.Int or big.Int, got %s", fieldVal.Type())
	}
	return nil
}

func unmarshalBytes(pd data.PlutusData, fieldVal reflect.Value) error {
	bs, ok := pd.(*data.ByteString)
	if !ok {
		return fmt.Errorf("expected ByteString, got %T", pd)
	}
	if fieldVal.Kind() != reflect.Slice || fieldVal.Type().Elem().Kind() != reflect.Uint8 {
		return fmt.Errorf("bytes tag requires []byte, got %s", fieldVal.Type())
	}
	fieldVal.SetBytes(append([]byte(nil), bs.Inner...))
	return nil
}

func unmarshalStringBytes(pd data.PlutusData, fieldVal reflect.Value) error {
	bs, ok := pd.(*data.ByteString)
	if !ok {
		return fmt.Errorf("expected ByteString, got %T", pd)
	}
	if fieldVal.Kind() != reflect.String {
		return fmt.Errorf("StringBytes tag requires string, got %s", fieldVal.Kind())
	}
	fieldVal.SetString(string(bs.Inner))
	return nil
}

func unmarshalHexString(pd data.PlutusData, fieldVal reflect.Value) error {
	bs, ok := pd.(*data.ByteString)
	if !ok {
		return fmt.Errorf("expected ByteString, got %T", pd)
	}
	if fieldVal.Kind() != reflect.String {
		return fmt.Errorf("HexString tag requires string, got %s", fieldVal.Kind())
	}
	fieldVal.SetString(hex.EncodeToString(bs.Inner))
	return nil
}

func unmarshalBool(pd data.PlutusData, fieldVal reflect.Value) error {
	constr, ok := pd.(*data.Constr)
	if !ok {
		return fmt.Errorf("expected Constr for Bool, got %T", pd)
	}
	if constr.Tag != 0 && constr.Tag != 1 {
		return fmt.Errorf("expected Constr tag 0 or 1 for Bool, got %d", constr.Tag)
	}
	if len(constr.Fields) != 0 {
		return fmt.Errorf("expected empty Constr for Bool, got %d fields", len(constr.Fields))
	}
	if fieldVal.Kind() != reflect.Bool {
		return fmt.Errorf("bool tag requires bool, got %s", fieldVal.Kind())
	}
	fieldVal.SetBool(constr.Tag == 1)
	return nil
}

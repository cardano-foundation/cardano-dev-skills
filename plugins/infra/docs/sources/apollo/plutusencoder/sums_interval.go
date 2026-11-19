package plutusencoder

import (
	"errors"
	"fmt"
	"math/big"
	"reflect"

	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/plutigo/data"
)

// OutputDatum is the Plutus OutputDatum sum type. Neither Inline nor Hash set
// encodes constructor 0 with no fields. A 32-byte Hash encodes constructor 1.
// Inline set encodes constructor 2 with that PlutusData. A non-nil Hash that
// is not 32 bytes is an error.
type OutputDatum struct {
	Inline data.PlutusData
	Hash   []byte
}

// BoundKind selects an interval bound variant.
type BoundKind int

const (
	// BoundNegInf is constructor 0, negative infinity.
	BoundNegInf BoundKind = iota
	// BoundFinite is constructor 1, a finite integer bound.
	BoundFinite
	// BoundPosInf is constructor 2, positive infinity.
	BoundPosInf
)

// IntervalBound is one endpoint of a Plutus Interval. Value is an int64, so a
// finite bound outside that range is rejected on decode. POSIXTime fits.
type IntervalBound struct {
	Kind   BoundKind
	Value  int64
	Closed bool
}

// Interval is a Plutus Interval of integers, such as a POSIXTimeRange.
// Each endpoint is encoded with the closure flag the caller sets.
type Interval struct {
	Lower IntervalBound
	Upper IntervalBound
}

func marshalEither(fieldVal reflect.Value) (data.PlutusData, error) {
	if fieldVal.Kind() != reflect.Struct {
		return nil, fmt.Errorf("either requires a two-field struct, got %s", fieldVal.Kind())
	}
	leftIdx, rightIdx, err := eitherFieldIndexes(fieldVal.Type())
	if err != nil {
		return nil, err
	}
	left := fieldVal.Field(leftIdx)
	right := fieldVal.Field(rightIdx)
	leftSet := !left.IsNil()
	rightSet := !right.IsNil()
	if leftSet == rightSet {
		return nil, errors.New("either requires one of Left or Right to be non-nil")
	}
	if leftSet {
		inner, err := marshalSumElement(left.Elem(), fieldVal.Type().Field(leftIdx))
		if err != nil {
			return nil, err
		}
		return data.NewConstr(0, inner), nil
	}
	inner, err := marshalSumElement(right.Elem(), fieldVal.Type().Field(rightIdx))
	if err != nil {
		return nil, err
	}
	return data.NewConstr(1, inner), nil
}

func unmarshalEither(pd data.PlutusData, fieldVal reflect.Value, cfg decodeConfig) error {
	if fieldVal.Kind() != reflect.Struct {
		return fmt.Errorf("either requires a two-field struct, got %s", fieldVal.Kind())
	}
	leftIdx, rightIdx, err := eitherFieldIndexes(fieldVal.Type())
	if err != nil {
		return err
	}
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil || len(constr.Fields) != 1 {
		return unexpectedConstr("Either constructor with 1 field", pd)
	}
	leftField := fieldVal.Field(leftIdx)
	rightField := fieldVal.Field(rightIdx)
	leftField.SetZero()
	rightField.SetZero()

	switch {
	case constrTagEqual(constr.Tag, 0):
		ptr := reflect.New(leftField.Type().Elem())
		if err := unmarshalSumElement(constr.Fields[0], ptr.Elem(), fieldVal.Type().Field(leftIdx), cfg); err != nil {
			return err
		}
		leftField.Set(ptr)
		return nil
	case constrTagEqual(constr.Tag, 1):
		ptr := reflect.New(rightField.Type().Elem())
		if err := unmarshalSumElement(constr.Fields[0], ptr.Elem(), fieldVal.Type().Field(rightIdx), cfg); err != nil {
			return err
		}
		rightField.Set(ptr)
		return nil
	default:
		return unexpectedConstr("Either constructor 0 or 1", constr)
	}
}

func eitherFieldIndexes(typ reflect.Type) (int, int, error) {
	exported := make([]int, 0, 2)
	for i := 0; i < typ.NumField(); i++ {
		f := typ.Field(i)
		if f.Name == "_" || !f.IsExported() {
			continue
		}
		if f.Type.Kind() != reflect.Pointer {
			return 0, 0, fmt.Errorf("either field %s must be a pointer", f.Name)
		}
		exported = append(exported, i)
	}
	if len(exported) != 2 {
		return 0, 0, fmt.Errorf("either struct %s must have 2 exported pointer fields, got %d", typ.Name(), len(exported))
	}
	return exported[0], exported[1], nil
}

func marshalSumElement(elem reflect.Value, field reflect.StructField) (data.PlutusData, error) {
	if field.Tag.Get("plutusType") != "" {
		return marshalField(elem, field)
	}
	if elem.CanAddr() {
		if m, ok := elem.Addr().Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if m, ok := elem.Interface().(PlutusMarshaler); ok {
		return m.ToPlutusData()
	}
	// big.Int is a struct with no exported fields. Recognize it before the
	// generic struct walk, or it encodes as an empty list.
	if isBigIntType(elem.Type()) {
		return marshalBigInt(elem)
	}
	if elem.Kind() == reflect.Struct {
		return marshalValue(elem)
	}
	switch elem.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return data.NewInteger(big.NewInt(elem.Int())), nil
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return data.NewInteger(new(big.Int).SetUint64(elem.Uint())), nil
	case reflect.String:
		return data.NewByteString([]byte(elem.String())), nil
	case reflect.Slice:
		if elem.Type().Elem().Kind() == reflect.Uint8 {
			return data.NewByteString(elem.Bytes()), nil
		}
	default:
		return nil, fmt.Errorf("unsupported Either element type %s", elem.Type())
	}
	return nil, fmt.Errorf("unsupported Either element type %s", elem.Type())
}

func unmarshalSumElement(pd data.PlutusData, elem reflect.Value, field reflect.StructField, cfg decodeConfig) error {
	if field.Tag.Get("plutusType") != "" {
		return unmarshalField(pd, elem, field, cfg)
	}
	if elem.CanAddr() {
		if m, ok := elem.Addr().Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, elem.Addr().Interface())
		}
	}
	if m, ok := elem.Interface().(PlutusMarshaler); ok {
		return m.FromPlutusData(pd, elem.Interface())
	}
	if isBigIntType(elem.Type()) {
		return unmarshalBigInt(pd, elem)
	}
	if elem.Kind() == reflect.Struct {
		return unmarshalValue(pd, elem, cfg)
	}
	switch elem.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return unmarshalInt(pd, elem)
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return unmarshalInt(pd, elem)
	case reflect.String:
		return unmarshalStringBytes(pd, elem)
	case reflect.Slice:
		if elem.Type().Elem().Kind() == reflect.Uint8 {
			return unmarshalBytes(pd, elem)
		}
	default:
		return fmt.Errorf("unsupported Either element type %s", elem.Type())
	}
	return fmt.Errorf("unsupported Either element type %s", elem.Type())
}

func marshalOutputDatum(od OutputDatum) (data.PlutusData, error) {
	hasInline := od.Inline != nil
	hasHash := od.Hash != nil
	if hasInline && hasHash {
		return nil, errors.New("output datum cannot set both Inline and Hash")
	}
	if hasHash {
		if len(od.Hash) != common.Blake2b256Size {
			return nil, fmt.Errorf("expected %d-byte datum hash, got %d", common.Blake2b256Size, len(od.Hash))
		}
		return data.NewConstr(1, data.NewByteString(append([]byte(nil), od.Hash...))), nil
	}
	if hasInline {
		return data.NewConstr(2, od.Inline), nil
	}
	return data.NewConstr(0), nil
}

func unmarshalOutputDatum(pd data.PlutusData) (OutputDatum, error) {
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil {
		return OutputDatum{}, unexpectedConstr("OutputDatum constructor", pd)
	}
	switch {
	case constrTagEqual(constr.Tag, 0):
		if len(constr.Fields) != 0 {
			return OutputDatum{}, unexpectedConstr("OutputDatum constructor 0 with no fields", pd)
		}
		return OutputDatum{}, nil
	case constrTagEqual(constr.Tag, 1):
		if len(constr.Fields) != 1 {
			return OutputDatum{}, unexpectedConstr("datum-hash OutputDatum constructor 1 with 1 field", pd)
		}
		raw, ok := constr.Fields[0].(*data.ByteString)
		if !ok || plutusNil(raw) || len(raw.Inner) != common.Blake2b256Size {
			return OutputDatum{}, fmt.Errorf("expected %d-byte datum hash", common.Blake2b256Size)
		}
		return OutputDatum{Hash: append([]byte(nil), raw.Inner...)}, nil
	case constrTagEqual(constr.Tag, 2):
		if len(constr.Fields) != 1 || plutusNil(constr.Fields[0]) {
			return OutputDatum{}, unexpectedConstr("inline OutputDatum constructor 2 with 1 field", pd)
		}
		return OutputDatum{Inline: constr.Fields[0]}, nil
	default:
		return OutputDatum{}, unexpectedConstr("OutputDatum constructor 0, 1, or 2", pd)
	}
}

func marshalInterval(iv Interval) (data.PlutusData, error) {
	lower, err := marshalIntervalBound(iv.Lower)
	if err != nil {
		return nil, fmt.Errorf("lower bound: %w", err)
	}
	upper, err := marshalIntervalBound(iv.Upper)
	if err != nil {
		return nil, fmt.Errorf("upper bound: %w", err)
	}
	return data.NewConstr(0, lower, upper), nil
}

func marshalIntervalBound(b IntervalBound) (data.PlutusData, error) {
	var ext data.PlutusData
	switch b.Kind {
	case BoundNegInf:
		ext = data.NewConstr(0)
	case BoundFinite:
		ext = data.NewConstr(1, data.NewInteger(big.NewInt(b.Value)))
	case BoundPosInf:
		ext = data.NewConstr(2)
	default:
		return nil, fmt.Errorf("unknown interval bound kind %d", b.Kind)
	}
	closedTag := uint64(0)
	if b.Closed {
		closedTag = 1
	}
	return data.NewConstr(0, ext, data.NewConstr(closedTag)), nil
}

func unmarshalInterval(pd data.PlutusData) (Interval, error) {
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil || !constrTagEqual(constr.Tag, 0) || len(constr.Fields) != 2 {
		return Interval{}, unexpectedConstr("Interval constructor 0 with 2 fields", pd)
	}
	lower, err := unmarshalIntervalBound(constr.Fields[0])
	if err != nil {
		return Interval{}, fmt.Errorf("lower bound: %w", err)
	}
	upper, err := unmarshalIntervalBound(constr.Fields[1])
	if err != nil {
		return Interval{}, fmt.Errorf("upper bound: %w", err)
	}
	return Interval{Lower: lower, Upper: upper}, nil
}

func unmarshalIntervalBound(pd data.PlutusData) (IntervalBound, error) {
	bound, ok := pd.(*data.Constr)
	if !ok || bound == nil || !constrTagEqual(bound.Tag, 0) || len(bound.Fields) != 2 {
		return IntervalBound{}, unexpectedConstr("interval bound constructor 0 with 2 fields", pd)
	}
	ext, ok := bound.Fields[0].(*data.Constr)
	if !ok || ext == nil {
		return IntervalBound{}, unexpectedConstr("Extended constructor", bound.Fields[0])
	}

	var result IntervalBound
	switch {
	case constrTagEqual(ext.Tag, 0) && len(ext.Fields) == 0:
		result.Kind = BoundNegInf
	case constrTagEqual(ext.Tag, 1) && len(ext.Fields) == 1:
		integer, ok := ext.Fields[0].(*data.Integer)
		if !ok || plutusNil(integer) || integer.Inner == nil {
			return IntervalBound{}, errors.New("expected int64 finite bound")
		}
		if !integer.Inner.IsInt64() {
			return IntervalBound{}, fmt.Errorf("integer value %s does not fit in int64", integer.Inner.String())
		}
		result.Kind = BoundFinite
		result.Value = integer.Inner.Int64()
	case constrTagEqual(ext.Tag, 2) && len(ext.Fields) == 0:
		result.Kind = BoundPosInf
	default:
		return IntervalBound{}, unexpectedConstr("Extended NegInf (0), Finite (1), or PosInf (2)", ext)
	}

	closure, ok := bound.Fields[1].(*data.Constr)
	if !ok || plutusNil(closure) || len(closure.Fields) != 0 {
		return IntervalBound{}, unexpectedConstr("closure Bool constructor with no fields", bound.Fields[1])
	}
	switch {
	case constrTagEqual(closure.Tag, 0):
		result.Closed = false
	case constrTagEqual(closure.Tag, 1):
		result.Closed = true
	default:
		return IntervalBound{}, unexpectedConstr("closure Bool constructor 0 or 1", closure)
	}
	return result, nil
}

func isBigIntType(typ reflect.Type) bool {
	return typ == reflect.TypeFor[big.Int]() || typ == reflect.TypeFor[*big.Int]()
}

// unexpectedConstr reports a constructor shape mismatch. A non-constructor
// keeps its dynamic type. A constructor names its tag and field count.
func unexpectedConstr(expected string, pd data.PlutusData) error {
	constr, ok := pd.(*data.Constr)
	if !ok || constr == nil {
		return fmt.Errorf("expected %s, got %T", expected, pd)
	}
	return fmt.Errorf("expected %s, got tag %s with %d fields", expected, constr.Tag, len(constr.Fields))
}

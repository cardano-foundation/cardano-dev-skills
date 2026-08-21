package plutusencoder

import (
	"errors"
	"fmt"
	"math"
	"math/big"
	"reflect"

	"github.com/blinklabs-io/plutigo/data"
)

func marshalList(val reflect.Value, typ reflect.Type, constrTag uint, hasConstr bool, useIndef bool) (data.PlutusData, error) {
	var fields []data.PlutusData

	for i := 0; i < typ.NumField(); i++ {
		field := typ.Field(i)
		if field.Name == "_" || !field.IsExported() {
			continue
		}

		ignored, err := isIgnoredField(field)
		if err != nil {
			return nil, err
		}
		if ignored {
			continue
		}
		omitEmpty, err := fieldOmitEmpty(field)
		if err != nil {
			return nil, err
		}
		if omitEmpty {
			return nil, fmt.Errorf("field %s: omitempty is not supported on positional list fields", field.Name)
		}

		fieldVal := val.Field(i)
		pd, err := marshalField(fieldVal, field)
		if err != nil {
			return nil, fmt.Errorf("field %s: %w", field.Name, err)
		}
		fields = append(fields, pd)
	}

	if hasConstr {
		return data.NewConstrDefIndef(useIndef, constrTag, fields...), nil
	}
	return data.NewListDefIndef(useIndef, fields...), nil
}

func marshalSliceOrNested(val reflect.Value, field reflect.StructField, useIndef bool) (data.PlutusData, error) {
	if val.Kind() == reflect.Slice {
		var items []data.PlutusData
		for i := 0; i < val.Len(); i++ {
			elem := val.Index(i)
			pd, err := marshalSliceElement(elem)
			if err != nil {
				return nil, fmt.Errorf("element %d: %w", i, err)
			}
			items = append(items, pd)
		}
		return data.NewListDefIndef(useIndef, items...), nil
	}
	// Nested struct without its own container marker honors the field's
	// DefList/IndefList tag. An explicit nested `_` container takes precedence.
	fieldContainer := containerIndefList
	if !useIndef {
		fieldContainer = containerDefList
	}
	return marshalValueWithContainer(val, fieldContainer, true)
}

// marshalSliceElement marshals a single slice element, handling both struct and primitive types.
func marshalSliceElement(elem reflect.Value) (data.PlutusData, error) {
	for elem.Kind() == reflect.Pointer {
		if elem.IsNil() {
			return nil, errors.New("nil pointer in slice")
		}
		elem = elem.Elem()
	}

	if elem.CanAddr() {
		if m, ok := elem.Addr().Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if m, ok := elem.Interface().(PlutusMarshaler); ok {
		return m.ToPlutusData()
	}

	switch elem.Kind() {
	case reflect.Struct:
		return marshalValue(elem)
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
		return nil, fmt.Errorf("unsupported slice element type: %s", elem.Type())
	default:
		return nil, fmt.Errorf("unsupported slice element kind: %s", elem.Kind())
	}
}

func unmarshalFromList(pd data.PlutusData, val reflect.Value, typ reflect.Type) error {
	container, expectedConstr, hasExpectedConstr, err := readContainerMetadata(typ)
	if err != nil {
		return err
	}
	if container == containerMap {
		return errors.New("unmarshalFromList received map container")
	}

	var fields []data.PlutusData

	switch v := pd.(type) {
	case *data.Constr:
		if hasExpectedConstr && v.Tag != expectedConstr {
			return fmt.Errorf("expected Constr tag %d, got %d", expectedConstr, v.Tag)
		}
		fields = v.Fields
	case *data.List:
		if hasExpectedConstr {
			return fmt.Errorf("expected Constr with tag %d, got List", expectedConstr)
		}
		fields = v.Items
	default:
		return fmt.Errorf("expected Constr or List, got %T", pd)
	}

	// Count exported wire fields (excluding the "_" tag field and ignored fields).
	exportedCount := 0
	for i := 0; i < typ.NumField(); i++ {
		f := typ.Field(i)
		if f.Name == "_" || !f.IsExported() {
			continue
		}
		ignored, err := isIgnoredField(f)
		if err != nil {
			return err
		}
		if !ignored {
			exportedCount++
		}
	}
	if len(fields) < exportedCount {
		return fmt.Errorf("plutus data has %d fields, struct %s expects %d", len(fields), typ.Name(), exportedCount)
	}
	// Extra fields in the PlutusData (len(fields) > exportedCount) are intentionally
	// ignored for forward-compatibility with newer datum schemas.

	fieldIdx := 0
	for i := 0; i < typ.NumField(); i++ {
		field := typ.Field(i)
		if field.Name == "_" || !field.IsExported() {
			continue
		}
		ignored, err := isIgnoredField(field)
		if err != nil {
			return err
		}
		if ignored {
			continue
		}

		fieldVal := val.Field(i)
		if err := unmarshalField(fields[fieldIdx], fieldVal, field); err != nil {
			return fmt.Errorf("field %s: %w", field.Name, err)
		}
		fieldIdx++
	}
	return nil
}

func unmarshalSliceOrNested(pd data.PlutusData, fieldVal reflect.Value, field reflect.StructField) error {
	if fieldVal.Kind() == reflect.Slice {
		list, ok := pd.(*data.List)
		if !ok {
			return fmt.Errorf("expected List for slice field %s, got %T", field.Name, pd)
		}
		items := list.Items

		elemType := fieldVal.Type().Elem()
		result := reflect.MakeSlice(fieldVal.Type(), len(items), len(items))
		for i, item := range items {
			// Handle pointer element types (e.g. []*MyStruct)
			if elemType.Kind() == reflect.Pointer {
				ptr := reflect.New(elemType.Elem())
				if err := unmarshalSliceElement(item, ptr.Elem()); err != nil {
					return fmt.Errorf("element %d: %w", i, err)
				}
				result.Index(i).Set(ptr)
			} else {
				elem := reflect.New(elemType).Elem()
				if err := unmarshalSliceElement(item, elem); err != nil {
					return fmt.Errorf("element %d: %w", i, err)
				}
				result.Index(i).Set(elem)
			}
		}
		fieldVal.Set(result)
		return nil
	}
	// Nested struct
	return unmarshalValue(pd, fieldVal)
}

// unmarshalSliceElement unmarshals a single slice element, handling both struct and primitive types.
func unmarshalSliceElement(pd data.PlutusData, elem reflect.Value) error {
	if elem.CanAddr() {
		if m, ok := elem.Addr().Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, elem.Addr().Interface())
		}
	}
	if m, ok := elem.Interface().(PlutusMarshaler); ok {
		return m.FromPlutusData(pd, elem.Interface())
	}

	switch elem.Kind() {
	case reflect.Struct:
		return unmarshalValue(pd, elem)
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		integer, ok := pd.(*data.Integer)
		if !ok {
			return fmt.Errorf("expected Integer, got %T", pd)
		}
		if !integer.Inner.IsInt64() {
			return fmt.Errorf("integer value %s does not fit in %s", integer.Inner.String(), elem.Kind())
		}
		v := integer.Inner.Int64()
		switch elem.Kind() {
		case reflect.Int:
			if v < math.MinInt || v > math.MaxInt {
				return fmt.Errorf("integer value %d does not fit in int", v)
			}
		case reflect.Int8:
			if v < math.MinInt8 || v > math.MaxInt8 {
				return fmt.Errorf("integer value %d does not fit in int8", v)
			}
		case reflect.Int16:
			if v < math.MinInt16 || v > math.MaxInt16 {
				return fmt.Errorf("integer value %d does not fit in int16", v)
			}
		case reflect.Int32:
			if v < math.MinInt32 || v > math.MaxInt32 {
				return fmt.Errorf("integer value %d does not fit in int32", v)
			}
		}
		elem.SetInt(v)
		return nil
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		integer, ok := pd.(*data.Integer)
		if !ok {
			return fmt.Errorf("expected Integer, got %T", pd)
		}
		if integer.Inner.Sign() < 0 || !integer.Inner.IsUint64() {
			return fmt.Errorf("integer value %s does not fit in %s", integer.Inner.String(), elem.Kind())
		}
		v := integer.Inner.Uint64()
		switch elem.Kind() {
		case reflect.Uint:
			if v > math.MaxUint {
				return fmt.Errorf("integer value %d does not fit in uint", v)
			}
		case reflect.Uint8:
			if v > math.MaxUint8 {
				return fmt.Errorf("integer value %d does not fit in uint8", v)
			}
		case reflect.Uint16:
			if v > math.MaxUint16 {
				return fmt.Errorf("integer value %d does not fit in uint16", v)
			}
		case reflect.Uint32:
			if v > math.MaxUint32 {
				return fmt.Errorf("integer value %d does not fit in uint32", v)
			}
		}
		elem.SetUint(v)
		return nil
	case reflect.String:
		bs, ok := pd.(*data.ByteString)
		if !ok {
			return fmt.Errorf("expected ByteString, got %T", pd)
		}
		elem.SetString(string(bs.Inner))
		return nil
	case reflect.Slice:
		if elem.Type().Elem().Kind() == reflect.Uint8 {
			bs, ok := pd.(*data.ByteString)
			if !ok {
				return fmt.Errorf("expected ByteString, got %T", pd)
			}
			elem.SetBytes(append([]byte(nil), bs.Inner...))
			return nil
		}
		return fmt.Errorf("unsupported nested slice type: %s", elem.Type())
	default:
		return fmt.Errorf("unsupported slice element kind: %s", elem.Kind())
	}
}

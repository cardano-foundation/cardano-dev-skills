package plutusencoder

import (
	"errors"
	"fmt"
	"reflect"

	"github.com/blinklabs-io/plutigo/data"
)

// MarshalPlutus encodes a Go struct to PlutusData using struct tags.
func MarshalPlutus(v any) (data.PlutusData, error) {
	return marshalValue(reflect.ValueOf(v))
}

func marshalValue(val reflect.Value) (data.PlutusData, error) {
	return marshalValueWithContainer(val, containerIndefList, false)
}

func marshalValueWithContainer(val reflect.Value, fieldContainer containerTag, hasFieldContainer bool) (data.PlutusData, error) {
	// Dereference pointers
	for val.Kind() == reflect.Pointer {
		if val.IsNil() {
			return nil, errors.New("nil pointer")
		}
		val = val.Elem()
	}

	if val.Kind() != reflect.Struct {
		return nil, fmt.Errorf("MarshalPlutus requires a struct, got %s", val.Kind())
	}

	// Check if the type implements PlutusMarshaler (pointer or value receiver)
	if val.CanAddr() {
		if m, ok := val.Addr().Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if m, ok := val.Interface().(PlutusMarshaler); ok {
		return m.ToPlutusData()
	}

	typ := val.Type()

	container, constrTag, hasConstr, err := readContainerMetadata(typ)
	if err != nil {
		return nil, err
	}
	if !hasConstr && hasFieldContainer {
		container = fieldContainer
	}

	switch container {
	case containerMap:
		return marshalMap(val, typ, constrTag, hasConstr)
	case containerDefList:
		return marshalList(val, typ, constrTag, hasConstr, false)
	case containerIndefList:
		return marshalList(val, typ, constrTag, hasConstr, true)
	default:
		return nil, fmt.Errorf("unknown plutus encoder container: %d", container)
	}
}

func marshalField(fieldVal reflect.Value, field reflect.StructField) (data.PlutusData, error) {
	plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return nil, fmt.Errorf("field %s: %w", field.Name, err)
	}

	// BigInt handles nil *big.Int directly, so dispatch before pointer dereference
	if plutusType == "BigInt" {
		return marshalBigInt(fieldVal)
	}

	// Dereference pointers
	for fieldVal.Kind() == reflect.Pointer {
		if fieldVal.IsNil() {
			return nil, fmt.Errorf("nil pointer for field %s", field.Name)
		}
		fieldVal = fieldVal.Elem()
	}

	// Check for PlutusMarshaler interface (pointer or value receiver)
	if fieldVal.CanAddr() {
		if m, ok := fieldVal.Addr().Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if m, ok := fieldVal.Interface().(PlutusMarshaler); ok {
		return m.ToPlutusData()
	}

	switch plutusType {
	case "Int":
		return marshalInt(fieldVal)
	case "Bytes":
		return marshalBytes(fieldVal)
	case "StringBytes":
		return marshalStringBytes(fieldVal)
	case "HexString":
		return marshalHexString(fieldVal)
	case "Bool":
		return marshalBool(fieldVal, false)
	case "IndefBool":
		return marshalBool(fieldVal, true)
	case "IndefList":
		return marshalSliceOrNested(fieldVal, field, true)
	case "DefList":
		return marshalSliceOrNested(fieldVal, field, false)
	case "Map":
		return marshalSliceAsMap(fieldVal, field)
	case "Custom":
		return nil, fmt.Errorf("field %s tagged Custom but doesn't implement PlutusMarshaler", field.Name)
	default:
		// No tag - recursively marshal as nested struct
		if fieldVal.Kind() == reflect.Struct {
			return marshalValue(fieldVal)
		}
		return nil, fmt.Errorf("unsupported field type %s for field %s", fieldVal.Kind(), field.Name)
	}
}

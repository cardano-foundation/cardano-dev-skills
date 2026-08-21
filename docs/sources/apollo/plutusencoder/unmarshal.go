package plutusencoder

import (
	"errors"
	"fmt"
	"reflect"

	"github.com/blinklabs-io/plutigo/data"
)

// UnmarshalPlutus decodes PlutusData into a Go struct using struct tags.
func UnmarshalPlutus(pd data.PlutusData, v any) error {
	val := reflect.ValueOf(v)
	if val.Kind() != reflect.Pointer || val.IsNil() {
		return errors.New("UnmarshalPlutus requires a non-nil pointer")
	}
	return unmarshalValue(pd, val.Elem())
}

func unmarshalValue(pd data.PlutusData, val reflect.Value) error {
	// Check for PlutusMarshaler (pointer or value receiver)
	if val.CanAddr() {
		if m, ok := val.Addr().Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, val.Addr().Interface())
		}
	}
	if m, ok := val.Interface().(PlutusMarshaler); ok {
		return m.FromPlutusData(pd, val.Interface())
	}

	if val.Kind() != reflect.Struct {
		return fmt.Errorf("unmarshal target must be a struct, got %s", val.Kind())
	}

	typ := val.Type()

	container, _, _, err := readContainerMetadata(typ)
	if err != nil {
		return err
	}

	switch container {
	case containerMap:
		return unmarshalFromMap(pd, val, typ)
	case containerDefList, containerIndefList:
		return unmarshalFromList(pd, val, typ)
	default:
		return fmt.Errorf("unknown plutus encoder container: %d", container)
	}
}

func unmarshalField(pd data.PlutusData, fieldVal reflect.Value, field reflect.StructField) error {
	plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return fmt.Errorf("field %s: %w", field.Name, err)
	}

	// BigInt handles *big.Int directly, so dispatch before pointer dereference
	if plutusType == "BigInt" {
		return unmarshalBigInt(pd, fieldVal)
	}

	// Dereference / allocate pointers
	for fieldVal.Kind() == reflect.Pointer {
		if fieldVal.IsNil() {
			fieldVal.Set(reflect.New(fieldVal.Type().Elem()))
		}
		fieldVal = fieldVal.Elem()
	}

	// Check for PlutusMarshaler (pointer or value receiver)
	if fieldVal.CanAddr() {
		if m, ok := fieldVal.Addr().Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, fieldVal.Addr().Interface())
		}
	}
	if m, ok := fieldVal.Interface().(PlutusMarshaler); ok {
		return m.FromPlutusData(pd, fieldVal.Interface())
	}

	switch plutusType {
	case "Int":
		return unmarshalInt(pd, fieldVal)
	case "Bytes":
		return unmarshalBytes(pd, fieldVal)
	case "StringBytes":
		return unmarshalStringBytes(pd, fieldVal)
	case "HexString":
		return unmarshalHexString(pd, fieldVal)
	case "Bool", "IndefBool":
		return unmarshalBool(pd, fieldVal)
	case "IndefList", "DefList":
		return unmarshalSliceOrNested(pd, fieldVal, field)
	case "Map":
		return unmarshalSliceAsMap(pd, fieldVal, field)
	case "Custom":
		return fmt.Errorf("field %s tagged Custom but doesn't implement PlutusMarshaler", field.Name)
	default:
		// Nested struct
		if fieldVal.Kind() == reflect.Struct {
			return unmarshalValue(pd, fieldVal)
		}
		return fmt.Errorf("unsupported field type %s for field %s", fieldVal.Kind(), field.Name)
	}
}

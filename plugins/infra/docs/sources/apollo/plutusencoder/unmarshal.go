package plutusencoder

import (
	"errors"
	"fmt"
	"reflect"

	"github.com/blinklabs-io/gouroboros/ledger/common"
	"github.com/blinklabs-io/plutigo/data"
)

// UnmarshalPlutus decodes PlutusData into a Go struct using struct tags.
// Options apply to this call only. With no options, addresses decode as testnet.
func UnmarshalPlutus(pd data.PlutusData, v any, opts ...UnmarshalOption) error {
	val := reflect.ValueOf(v)
	if val.Kind() != reflect.Pointer || val.IsNil() {
		return errors.New("UnmarshalPlutus requires a non-nil pointer")
	}
	cfg, err := applyUnmarshalOptions(opts)
	if err != nil {
		return err
	}
	return unmarshalValue(pd, val.Elem(), cfg)
}

func unmarshalValue(pd data.PlutusData, val reflect.Value, cfg decodeConfig) error {
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
		return unmarshalFromMap(pd, val, typ, cfg)
	case containerDefList, containerIndefList:
		return unmarshalFromList(pd, val, typ, cfg)
	default:
		return fmt.Errorf("unknown plutus encoder container: %d", container)
	}
}

func unmarshalField(pd data.PlutusData, fieldVal reflect.Value, field reflect.StructField, cfg decodeConfig) error {
	plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return fmt.Errorf("field %s: %w", field.Name, err)
	}
	return unmarshalFieldWithType(pd, fieldVal, field, plutusType, cfg)
}

func unmarshalFieldWithType(pd data.PlutusData, fieldVal reflect.Value, field reflect.StructField, plutusType string, cfg decodeConfig) error {
	// BigInt, Maybe, and Address are dispatched before pointer allocation.
	// Maybe Nothing must stay nil, and Address writes a common.Address value.
	switch plutusType {
	case "BigInt":
		return unmarshalBigInt(pd, fieldVal)
	case "Maybe":
		return unmarshalMaybe(pd, fieldVal, cfg)
	case "Address":
		if fieldVal.Kind() == reflect.Pointer {
			if fieldVal.IsNil() {
				fieldVal.Set(reflect.New(fieldVal.Type().Elem()))
			}
			fieldVal = fieldVal.Elem()
		}
		if fieldVal.Type() != reflect.TypeOf(common.Address{}) {
			return fmt.Errorf("field %s: Address requires common.Address, got %s", field.Name, fieldVal.Type())
		}
		addr, err := unmarshalAddress(pd, cfg.network)
		if err != nil {
			return err
		}
		fieldVal.Set(reflect.ValueOf(addr))
		return nil
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
		return unmarshalSliceOrNested(pd, fieldVal, field, cfg)
	case "Map":
		return unmarshalSliceAsMap(pd, fieldVal, field, cfg)
	case "Either":
		return unmarshalEither(pd, fieldVal, cfg)
	case "OutputDatum":
		if fieldVal.Type() != reflect.TypeOf(OutputDatum{}) {
			return fmt.Errorf("field %s: OutputDatum requires plutusencoder.OutputDatum, got %s", field.Name, fieldVal.Type())
		}
		od, err := unmarshalOutputDatum(pd)
		if err != nil {
			return err
		}
		fieldVal.Set(reflect.ValueOf(od))
		return nil
	case "Interval":
		if fieldVal.Type() != reflect.TypeOf(Interval{}) {
			return fmt.Errorf("field %s: Interval requires plutusencoder.Interval, got %s", field.Name, fieldVal.Type())
		}
		iv, err := unmarshalInterval(pd)
		if err != nil {
			return err
		}
		fieldVal.Set(reflect.ValueOf(iv))
		return nil
	case "Value", "V4Value":
		if fieldVal.Type() != reflect.TypeOf(Value{}) {
			return fmt.Errorf("field %s: %s requires plutusencoder.Value, got %s", field.Name, plutusType, fieldVal.Type())
		}
		v, err := unmarshalPlutusValue(pd)
		if err != nil {
			return err
		}
		fieldVal.Set(reflect.ValueOf(v))
		return nil
	case "Credential":
		if fieldVal.Type() != reflect.TypeOf(common.Credential{}) {
			return fmt.Errorf("credential requires common.Credential, got %s", fieldVal.Type())
		}
		cred, err := unmarshalCredential(pd)
		if err != nil {
			return err
		}
		fieldVal.Set(reflect.ValueOf(cred))
		return nil
	case "TxOutRef":
		if fieldVal.Type() != reflect.TypeOf(TxOutRef{}) {
			return fmt.Errorf("TxOutRef requires plutusencoder.TxOutRef, got %s", fieldVal.Type())
		}
		ref, err := unmarshalTxOutRef(pd)
		if err != nil {
			return err
		}
		fieldVal.Set(reflect.ValueOf(ref))
		return nil
	case "AssetClass":
		if fieldVal.Type() != reflect.TypeOf(AssetClass{}) {
			return fmt.Errorf("AssetClass requires plutusencoder.AssetClass, got %s", fieldVal.Type())
		}
		asset, err := unmarshalAssetClass(pd)
		if err != nil {
			return err
		}
		fieldVal.Set(reflect.ValueOf(asset))
		return nil
	case "Custom":
		return fmt.Errorf("field %s tagged Custom but doesn't implement PlutusMarshaler", field.Name)
	default:
		// Nested struct
		if fieldVal.Kind() == reflect.Struct {
			return unmarshalValue(pd, fieldVal, cfg)
		}
		return fmt.Errorf("unsupported field type %s for field %s", fieldVal.Kind(), field.Name)
	}
}

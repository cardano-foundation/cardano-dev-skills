package plutusencoder

import (
	"bytes"
	"errors"
	"fmt"
	"reflect"
	"sort"

	"github.com/blinklabs-io/plutigo/data"
)

func marshalMap(val reflect.Value, typ reflect.Type, constrTag uint, hasConstr bool) (data.PlutusData, error) {
	var pairs [][2]data.PlutusData
	seenKeys := make(map[string]struct{}, typ.NumField())

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

		fieldVal := val.Field(i)
		omitEmpty, err := fieldOmitEmpty(field)
		if err != nil {
			return nil, err
		}
		if omitEmpty && isEmptyField(fieldVal) {
			continue
		}

		keyName := field.Tag.Get("plutusKey")
		if keyName == "" {
			keyName = field.Name
		}
		if _, duplicate := seenKeys[keyName]; duplicate {
			return nil, fmt.Errorf("field %s: duplicate map key %q", field.Name, keyName)
		}
		seenKeys[keyName] = struct{}{}

		key := data.NewByteString([]byte(keyName))
		value, err := marshalField(fieldVal, field)
		if err != nil {
			return nil, fmt.Errorf("field %s: %w", field.Name, err)
		}
		pairs = append(pairs, [2]data.PlutusData{key, value})
	}

	if hasConstr {
		mapData := data.NewMap(pairs)
		return data.NewConstr(constrTag, mapData), nil
	}
	return data.NewMap(pairs), nil
}

func marshalSliceAsMap(val reflect.Value, field reflect.StructField) (data.PlutusData, error) {
	if val.Kind() == reflect.Map {
		return marshalNativeMap(val, field)
	}
	if val.Kind() == reflect.Slice {
		var pairs [][2]data.PlutusData
		seenKeys := make(map[string]struct{}, val.Len())
		for i := 0; i < val.Len(); i++ {
			elem := val.Index(i)
			for elem.Kind() == reflect.Pointer {
				if elem.IsNil() {
					return nil, fmt.Errorf("nil pointer at element %d", i)
				}
				elem = elem.Elem()
			}
			// Extract key from first exported field of each element
			key, keyIdx, err := extractMapKey(elem)
			if err != nil {
				return nil, fmt.Errorf("element %d key: %w", i, err)
			}
			keyString := key.String()
			if _, duplicate := seenKeys[keyString]; duplicate {
				return nil, fmt.Errorf("element %d: duplicate map key %s", i, keyString)
			}
			seenKeys[keyString] = struct{}{}
			// Marshal only non-key fields as the value to avoid duplicating
			// the key in both the map key and the value.
			pd, err := marshalMapValueFields(elem, keyIdx)
			if err != nil {
				return nil, fmt.Errorf("element %d: %w", i, err)
			}
			pairs = append(pairs, [2]data.PlutusData{key, pd})
		}
		return data.NewMap(pairs), nil
	}
	return marshalValue(val)
}

func marshalNativeMap(val reflect.Value, field reflect.StructField) (data.PlutusData, error) {
	if val.IsNil() {
		return nil, fmt.Errorf("field %s: nil native map cannot be encoded as Plutus Map", field.Name)
	}

	type encodedPair struct {
		key     []byte
		pair    [2]data.PlutusData
		display string
	}

	pairs := make([]encodedPair, 0, val.Len())
	seen := make(map[string]string, val.Len())
	iterator := val.MapRange()
	for iterator.Next() {
		key, err := marshalNativeMapKey(iterator.Key(), field)
		if err != nil {
			return nil, fmt.Errorf("field %s key: %w", field.Name, err)
		}
		value, err := marshalNativeMapValue(iterator.Value(), field)
		if err != nil {
			return nil, fmt.Errorf("field %s value for key %s: %w", field.Name, key.String(), err)
		}

		encodedKey, err := data.Encode(key)
		if err != nil {
			return nil, fmt.Errorf("field %s key %s: %w", field.Name, key.String(), err)
		}
		keyString := string(encodedKey)
		if previous, duplicate := seen[keyString]; duplicate {
			return nil, fmt.Errorf("field %s: duplicate encoded map key %s for keys %q and %q", field.Name, key.String(), previous, key.String())
		}
		seen[keyString] = key.String()
		pairs = append(pairs, encodedPair{key: encodedKey, pair: [2]data.PlutusData{key, value}, display: key.String()})
	}

	sort.Slice(pairs, func(i, j int) bool {
		if cmp := bytes.Compare(pairs[i].key, pairs[j].key); cmp != 0 {
			return cmp < 0
		}
		return pairs[i].display < pairs[j].display
	})

	result := make([][2]data.PlutusData, len(pairs))
	for i, pair := range pairs {
		result[i] = pair.pair
	}
	return data.NewMap(result), nil
}

func marshalNativeMapKey(key reflect.Value, field reflect.StructField) (data.PlutusData, error) {
	for key.Kind() == reflect.Interface {
		if key.IsNil() {
			return nil, errors.New("nil native map key")
		}
		key = key.Elem()
	}

	if key.CanAddr() {
		if m, ok := key.Addr().Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if m, ok := key.Interface().(PlutusMarshaler); ok {
		return m.ToPlutusData()
	}

	plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return nil, fmt.Errorf("native map key: %w", err)
	}
	if plutusType != "" && plutusType != "Map" {
		synthetic := reflect.StructField{Name: field.Name + "Key", Tag: field.Tag}
		return marshalField(key, synthetic)
	}

	switch key.Kind() {
	case reflect.String:
		return data.NewByteString([]byte(key.String())), nil
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return marshalInt(key)
	case reflect.Slice:
		if key.Type().Elem().Kind() == reflect.Uint8 {
			return marshalBytes(key)
		}
	case reflect.Bool:
		return marshalBool(key, false)
	}
	return nil, fmt.Errorf("unsupported native map key type %s", key.Type())
}

func marshalNativeMapValue(value reflect.Value, field reflect.StructField) (data.PlutusData, error) {
	for value.Kind() == reflect.Interface {
		if value.IsNil() {
			return nil, errors.New("nil native map value")
		}
		value = value.Elem()
	}
	plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return nil, fmt.Errorf("native map value: %w", err)
	}
	if plutusType == "" || plutusType == "Map" {
		return marshalNativeMapScalar(value, field)
	}
	synthetic := reflect.StructField{Name: field.Name + "Value", Tag: field.Tag}
	return marshalField(value, synthetic)
}

func marshalNativeMapScalar(value reflect.Value, field reflect.StructField) (data.PlutusData, error) {
	if value.CanAddr() {
		if m, ok := value.Addr().Interface().(PlutusMarshaler); ok {
			return m.ToPlutusData()
		}
	}
	if m, ok := value.Interface().(PlutusMarshaler); ok {
		return m.ToPlutusData()
	}

	switch value.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return marshalInt(value)
	case reflect.String:
		return marshalStringBytes(value)
	case reflect.Bool:
		return marshalBool(value, false)
	case reflect.Slice:
		if value.Type().Elem().Kind() == reflect.Uint8 {
			return marshalBytes(value)
		}
	}
	return nil, fmt.Errorf("unsupported native map value type %s for field %s", value.Type(), field.Name)
}

// marshalMapValueFields marshals all exported fields of elem except the key field at keyIdx.
// If exactly one non-key field remains, it is returned directly; otherwise a list is returned.
func marshalMapValueFields(elem reflect.Value, keyIdx int) (data.PlutusData, error) {
	typ := elem.Type()
	var fields []data.PlutusData
	for i := 0; i < typ.NumField(); i++ {
		if i == keyIdx {
			continue
		}
		f := typ.Field(i)
		if f.Name == "_" || !f.IsExported() {
			continue
		}
		pd, err := marshalField(elem.Field(i), f)
		if err != nil {
			return nil, fmt.Errorf("field %s: %w", f.Name, err)
		}
		fields = append(fields, pd)
	}
	if len(fields) == 1 {
		return fields[0], nil
	}
	return data.NewList(fields...), nil
}

// extractMapKey gets the map key from a slice element.
// For structs, uses the first exported field as the key (string → ByteString, else marshalled).
// Returns the key, the field index used, and any error.
func extractMapKey(elem reflect.Value) (data.PlutusData, int, error) {
	if elem.Kind() == reflect.Struct {
		typ := elem.Type()
		for j := 0; j < typ.NumField(); j++ {
			f := typ.Field(j)
			if f.Name == "_" || !f.IsExported() {
				continue
			}
			fv := elem.Field(j)
			if fv.Kind() == reflect.String && f.Tag.Get("plutusType") == "" {
				return data.NewByteString([]byte(fv.String())), j, nil
			}
			// For tagged and non-string first fields, marshal it
			pd, err := marshalField(fv, f)
			if err != nil {
				return nil, -1, err
			}
			return pd, j, nil
		}
	}
	return nil, -1, fmt.Errorf("cannot extract map key from non-struct element of kind %s", elem.Kind())
}

func unmarshalFromMap(pd data.PlutusData, val reflect.Value, typ reflect.Type) error {
	container, expectedConstr, hasExpectedConstr, err := readContainerMetadata(typ)
	if err != nil {
		return err
	}
	if container != containerMap {
		return fmt.Errorf("unmarshalFromMap received non-map container: %d", container)
	}

	mapData, ok := pd.(*data.Map)
	if !ok {
		// Could be a Constr wrapping a Map
		if constr, ok := pd.(*data.Constr); ok && len(constr.Fields) == 1 {
			if hasExpectedConstr && constr.Tag != expectedConstr {
				return fmt.Errorf("expected Constr tag %d, got %d", expectedConstr, constr.Tag)
			}
			mapData, ok = constr.Fields[0].(*data.Map)
			if !ok {
				return fmt.Errorf("expected Map in Constr, got %T", constr.Fields[0])
			}
		} else if constr, ok := pd.(*data.Constr); ok {
			return fmt.Errorf("expected Constr with 1 field wrapping a Map, got Constr with %d fields", len(constr.Fields))
		} else {
			return fmt.Errorf("expected Map, got %T", pd)
		}
	} else if hasExpectedConstr {
		return fmt.Errorf("expected Constr with tag %d wrapping Map, got bare Map", expectedConstr)
	}

	// Build a lookup from key name to PlutusData. Keys must be ByteStrings
	// (the only key type produced by marshalMap) and must be unique. Anything
	// else is rejected so that untrusted datums cannot shadow or hide keys.
	keyMap := make(map[string]data.PlutusData, len(mapData.Pairs))
	for i, pair := range mapData.Pairs {
		bs, ok := pair[0].(*data.ByteString)
		if !ok {
			return fmt.Errorf("map pair %d: expected ByteString key, got %T", i, pair[0])
		}
		mapKey := string(bs.Inner)
		if _, dup := keyMap[mapKey]; dup {
			return fmt.Errorf("map pair %d: duplicate key %q", i, mapKey)
		}
		keyMap[mapKey] = pair[1]
	}

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

		keyName := field.Tag.Get("plutusKey")
		if keyName == "" {
			keyName = field.Name
		}

		value, exists := keyMap[keyName]
		if !exists {
			optional, err := isOptionalField(field)
			if err != nil {
				return err
			}
			if !optional {
				optional, err = fieldOmitEmpty(field)
				if err != nil {
					return err
				}
			}
			if optional {
				// Optional field absent from the map: leave the zero value.
				continue
			}
			return fmt.Errorf("missing required map key %q for field %s of struct %s", keyName, field.Name, typ.Name())
		}

		fieldVal := val.Field(i)
		if err := unmarshalField(value, fieldVal, field); err != nil {
			return fmt.Errorf("field %s: %w", field.Name, err)
		}
	}
	return nil
}

func unmarshalSliceAsMap(pd data.PlutusData, fieldVal reflect.Value, field reflect.StructField) error {
	if fieldVal.Kind() == reflect.Map {
		return unmarshalNativeMap(pd, fieldVal, field)
	}
	if fieldVal.Kind() == reflect.Slice {
		mapData, ok := pd.(*data.Map)
		if !ok {
			return fmt.Errorf("expected Map for slice, got %T", pd)
		}

		elemType := fieldVal.Type().Elem()
		result := reflect.MakeSlice(fieldVal.Type(), len(mapData.Pairs), len(mapData.Pairs))
		for i, pair := range mapData.Pairs {
			var elem reflect.Value
			if elemType.Kind() == reflect.Pointer {
				elem = reflect.New(elemType.Elem()).Elem()
			} else {
				elem = reflect.New(elemType).Elem()
			}
			if err := unmarshalMapEntry(pair, elem); err != nil {
				return fmt.Errorf("element %d: %w", i, err)
			}
			if elemType.Kind() == reflect.Pointer {
				result.Index(i).Set(elem.Addr())
			} else {
				result.Index(i).Set(elem)
			}
		}
		fieldVal.Set(result)
		return nil
	}
	return unmarshalValue(pd, fieldVal)
}

func unmarshalNativeMap(pd data.PlutusData, fieldVal reflect.Value, field reflect.StructField) error {
	mapData, ok := pd.(*data.Map)
	if !ok {
		return fmt.Errorf("expected Map for native map field %s, got %T", field.Name, pd)
	}

	mapType := fieldVal.Type()
	if mapType.Key().Kind() == reflect.Interface && mapType.Key().NumMethod() > 0 {
		return fmt.Errorf("field %s: unsupported native map key type %s", field.Name, mapType.Key())
	}

	result := reflect.MakeMapWithSize(mapType, len(mapData.Pairs))
	for i, pair := range mapData.Pairs {
		key := reflect.New(mapType.Key()).Elem()
		if err := unmarshalNativeMapKey(pair[0], key, field); err != nil {
			return fmt.Errorf("field %s pair %d key: %w", field.Name, i, err)
		}

		value := reflect.New(mapType.Elem()).Elem()
		if err := unmarshalNativeMapValue(pair[1], value, field); err != nil {
			return fmt.Errorf("field %s pair %d value: %w", field.Name, i, err)
		}
		result.SetMapIndex(key, value)
	}
	fieldVal.Set(result)
	return nil
}

func unmarshalNativeMapKey(pd data.PlutusData, key reflect.Value, field reflect.StructField) error {
	if key.Kind() == reflect.Interface {
		return fmt.Errorf("unsupported native map key type %s", key.Type())
	}

	if key.CanAddr() {
		if m, ok := key.Addr().Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, key.Addr().Interface())
		}
	}
	if m, ok := key.Interface().(PlutusMarshaler); ok {
		return m.FromPlutusData(pd, key.Interface())
	}

	plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return fmt.Errorf("native map key: %w", err)
	}
	if plutusType != "" && plutusType != "Map" {
		synthetic := reflect.StructField{Name: field.Name + "Key", Tag: field.Tag}
		return unmarshalField(pd, key, synthetic)
	}

	switch key.Kind() {
	case reflect.String:
		return unmarshalStringBytes(pd, key)
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return unmarshalInt(pd, key)
	case reflect.Slice:
		if key.Type().Elem().Kind() == reflect.Uint8 {
			return unmarshalBytes(pd, key)
		}
	case reflect.Bool:
		return unmarshalBool(pd, key)
	}
	return fmt.Errorf("unsupported native map key type %s", key.Type())
}

func unmarshalNativeMapValue(pd data.PlutusData, value reflect.Value, field reflect.StructField) error {
	plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return fmt.Errorf("native map value: %w", err)
	}
	if plutusType == "" || plutusType == "Map" {
		return unmarshalNativeMapScalar(pd, value, field)
	}
	synthetic := reflect.StructField{Name: field.Name + "Value", Tag: field.Tag}
	return unmarshalField(pd, value, synthetic)
}

func unmarshalNativeMapScalar(pd data.PlutusData, value reflect.Value, field reflect.StructField) error {
	if value.CanAddr() {
		if m, ok := value.Addr().Interface().(PlutusMarshaler); ok {
			return m.FromPlutusData(pd, value.Addr().Interface())
		}
	}
	if m, ok := value.Interface().(PlutusMarshaler); ok {
		return m.FromPlutusData(pd, value.Interface())
	}

	switch value.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return unmarshalInt(pd, value)
	case reflect.String:
		return unmarshalStringBytes(pd, value)
	case reflect.Bool:
		return unmarshalBool(pd, value)
	case reflect.Slice:
		if value.Type().Elem().Kind() == reflect.Uint8 {
			return unmarshalBytes(pd, value)
		}
	}
	return fmt.Errorf("unsupported native map value type %s for field %s", value.Type(), field.Name)
}

// unmarshalMapEntry restores a map entry into a struct by setting the key field
// from pair[0] and the remaining value fields from pair[1].
func unmarshalMapEntry(pair [2]data.PlutusData, elem reflect.Value) error {
	if elem.Kind() != reflect.Struct {
		return unmarshalValue(pair[1], elem)
	}
	typ := elem.Type()

	unmarshalKey := func(keyPD data.PlutusData, field reflect.StructField, fieldVal reflect.Value) error {
		plutusType, _, err := parseFieldTag(field.Tag.Get("plutusType"))
		if err != nil {
			return fmt.Errorf("key field %s: %w", field.Name, err)
		}
		if plutusType == "" && fieldVal.Kind() == reflect.String {
			if err := unmarshalStringBytes(keyPD, fieldVal); err != nil {
				return fmt.Errorf("key field %s: %w", field.Name, err)
			}
			return nil
		}
		if err := unmarshalField(keyPD, fieldVal, field); err != nil {
			return fmt.Errorf("key field %s: %w", field.Name, err)
		}
		return nil
	}

	// Find the first exported field (the key field)
	keyIdx := -1
	for j := 0; j < typ.NumField(); j++ {
		f := typ.Field(j)
		if f.Name == "_" || !f.IsExported() {
			continue
		}
		keyIdx = j
		break
	}
	if keyIdx < 0 {
		return unmarshalValue(pair[1], elem)
	}

	// Unmarshal the key into the key field
	keyField := typ.Field(keyIdx)
	if err := unmarshalKey(pair[0], keyField, elem.Field(keyIdx)); err != nil {
		return err
	}

	// Collect non-key exported fields
	var valueFieldIdxs []int
	for j := 0; j < typ.NumField(); j++ {
		if j == keyIdx {
			continue
		}
		f := typ.Field(j)
		if f.Name == "_" || !f.IsExported() {
			continue
		}
		valueFieldIdxs = append(valueFieldIdxs, j)
	}

	if len(valueFieldIdxs) == 1 {
		// Single value field - unmarshal pair[1] directly into it
		f := typ.Field(valueFieldIdxs[0])
		return unmarshalField(pair[1], elem.Field(valueFieldIdxs[0]), f)
	}

	// Multiple value fields must be a bare List; Constr tags are not discarded.
	list, ok := pair[1].(*data.List)
	if !ok {
		return fmt.Errorf("expected List for multi-field map value, got %T", pair[1])
	}
	items := list.Items
	if len(items) < len(valueFieldIdxs) {
		return fmt.Errorf("map value has %d items but struct expects %d non-key fields", len(items), len(valueFieldIdxs))
	}
	for i, fieldIdx := range valueFieldIdxs {
		f := typ.Field(fieldIdx)
		if err := unmarshalField(items[i], elem.Field(fieldIdx), f); err != nil {
			return fmt.Errorf("value field %s: %w", f.Name, err)
		}
	}
	return nil
}

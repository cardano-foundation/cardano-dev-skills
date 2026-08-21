package plutusencoder

import (
	"fmt"
	"reflect"
	"strconv"
	"strings"
)

// containerTag is the normalized form of the anonymous `_` field's
// `plutusType` marker. Empty preserves the historical IndefList behavior;
// unknown values are rejected so a typo cannot silently change the schema.
type containerTag int

const (
	containerIndefList containerTag = iota
	containerDefList
	containerMap
)

func parseContainerTag(raw string) (containerTag, error) {
	tag, options, err := splitPlutusType(raw)
	if err != nil {
		return containerIndefList, err
	}
	if len(options) > 0 {
		return containerIndefList, fmt.Errorf("unknown container plutusType option %q in %q", options[0], raw)
	}

	switch tag {
	case "", "IndefList":
		return containerIndefList, nil
	case "DefList":
		return containerDefList, nil
	case "Map":
		return containerMap, nil
	default:
		return containerIndefList, fmt.Errorf("unknown container plutusType %q", tag)
	}
}

// parseFieldTag normalizes a field's `plutusType` tag. Options are parsed
// after the first comma, with surrounding whitespace ignored.
func parseFieldTag(raw string) (string, map[string]struct{}, error) {
	tag, options, err := splitPlutusType(raw)
	if err != nil {
		return "", nil, err
	}

	optionSet := make(map[string]struct{}, len(options))
	for _, option := range options {
		switch option {
		case "omitempty":
			optionSet[option] = struct{}{}
		default:
			return "", nil, fmt.Errorf("unknown field plutusType option %q in %q", option, raw)
		}
	}
	return tag, optionSet, nil
}

func isIgnoredField(field reflect.StructField) (bool, error) {
	tag, options, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return false, fmt.Errorf("field %s: %w", field.Name, err)
	}
	if tag == "Ignore" {
		if len(options) > 0 {
			return false, fmt.Errorf("field %s: Ignore does not accept options", field.Name)
		}
		return true, nil
	}
	return false, nil
}

func fieldOmitEmpty(field reflect.StructField) (bool, error) {
	_, options, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		return false, fmt.Errorf("field %s: %w", field.Name, err)
	}
	_, omit := options["omitempty"]
	return omit, nil
}

// isEmptyField uses Go's established encoding/json empty-value semantics:
// false, numeric zero, nil pointer/interface, and zero-length strings,
// arrays, slices, or maps. Types may override this with IsZero.
func isEmptyField(fieldVal reflect.Value) bool {
	for fieldVal.Kind() == reflect.Interface {
		if fieldVal.IsNil() {
			return true
		}
		fieldVal = fieldVal.Elem()
	}

	if fieldVal.CanInterface() {
		if zeroer, ok := fieldVal.Interface().(interface{ IsZero() bool }); ok {
			return zeroer.IsZero()
		}
	}

	switch fieldVal.Kind() {
	case reflect.Bool:
		return !fieldVal.Bool()
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return fieldVal.Int() == 0
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
		return fieldVal.Uint() == 0
	case reflect.Float32, reflect.Float64:
		return fieldVal.Float() == 0
	case reflect.Complex64, reflect.Complex128:
		return fieldVal.Complex() == 0
	case reflect.String, reflect.Array, reflect.Slice, reflect.Map:
		return fieldVal.Len() == 0
	case reflect.Pointer:
		if fieldVal.IsNil() {
			return true
		}
		return isEmptyField(fieldVal.Elem())
	default:
		return fieldVal.IsZero()
	}
}

func splitPlutusType(raw string) (string, []string, error) {
	parts := strings.Split(raw, ",")
	tag := strings.TrimSpace(parts[0])
	if tag == "" && len(parts) > 1 {
		return "", nil, fmt.Errorf("invalid plutusType tag %q: missing field type", raw)
	}

	options := make([]string, 0, len(parts)-1)
	seen := make(map[string]struct{}, len(parts)-1)
	for _, part := range parts[1:] {
		option := strings.TrimSpace(part)
		if option == "" {
			return "", nil, fmt.Errorf("invalid plutusType tag %q: empty option", raw)
		}
		lowerOption := strings.ToLower(option)
		if _, duplicate := seen[lowerOption]; duplicate {
			return "", nil, fmt.Errorf("invalid plutusType tag %q: duplicate option %q", raw, option)
		}
		seen[lowerOption] = struct{}{}
		options = append(options, option)
	}
	return tag, options, nil
}

func readContainerMetadata(typ reflect.Type) (containerTag, uint, bool, error) {
	for i := 0; i < typ.NumField(); i++ {
		field := typ.Field(i)
		if field.Name != "_" {
			continue
		}

		container, err := parseContainerTag(field.Tag.Get("plutusType"))
		if err != nil {
			return containerIndefList, 0, false, err
		}

		var constrTag uint
		hasConstr := false
		if constrStr := field.Tag.Get("plutusConstr"); constrStr != "" {
			c, err := strconv.ParseUint(constrStr, 10, 32)
			if err != nil {
				return containerIndefList, 0, false, fmt.Errorf("invalid plutusConstr tag %q: %w", constrStr, err)
			}
			constrTag = uint(c)
			hasConstr = true
		}
		return container, constrTag, hasConstr, nil
	}
	return containerIndefList, 0, false, nil
}

// isOptionalField reports whether a struct field is marked optional via the
// `plutusOptional:"true"` tag. Optional fields may be absent from an input
// map and are left at their zero value. Tag values are parsed with
// strconv.ParseBool; an invalid value is an error rather than being silently
// treated as required.
func isOptionalField(field reflect.StructField) (bool, error) {
	tagVal := field.Tag.Get("plutusOptional")
	if tagVal == "" {
		return false, nil
	}
	optional, err := strconv.ParseBool(tagVal)
	if err != nil {
		return false, fmt.Errorf("invalid plutusOptional tag %q on field %s: %w", tagVal, field.Name, err)
	}
	return optional, nil
}

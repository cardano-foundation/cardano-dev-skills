package plutusencoder

import (
	"fmt"
	"math/big"
	"reflect"
	"strconv"
	"strings"
	"sync"

	"github.com/Salvionied/apollo/v2/constants"
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
		return fieldVal.IsNil()
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

func readContainerMetadata(typ reflect.Type) (containerTag, uint64, bool, error) {
	meta := cachedStructMeta(typ)
	if meta.err != nil {
		return containerIndefList, 0, false, meta.err
	}
	return meta.container, meta.constrTag, meta.hasConstr, nil
}

// parsedField is the cached view of one struct field's plutus tags.
type parsedField struct {
	plutusType  string
	omitempty   bool
	ignore      bool
	key         string
	optional    bool
	tagErr      error
	optionalErr error
}

// structMeta is the cached container tag and per-field tags for one struct type.
type structMeta struct {
	container containerTag
	constrTag uint64
	hasConstr bool
	err       error
	fields    []parsedField
}

var structMetaCache sync.Map

func cachedStructMeta(typ reflect.Type) *structMeta {
	if cached, ok := structMetaCache.Load(typ); ok {
		return cached.(*structMeta)
	}
	meta := buildStructMeta(typ)
	actual, _ := structMetaCache.LoadOrStore(typ, meta)
	return actual.(*structMeta)
}

func buildStructMeta(typ reflect.Type) *structMeta {
	meta := &structMeta{fields: make([]parsedField, typ.NumField())}
	seenBlank := false
	for i := 0; i < typ.NumField(); i++ {
		field := typ.Field(i)
		if field.Name == "_" {
			if seenBlank {
				continue
			}
			seenBlank = true
			container, err := parseContainerTag(field.Tag.Get("plutusType"))
			if err != nil {
				meta.err = err
				return meta
			}
			meta.container = container
			if constrStr := field.Tag.Get("plutusConstr"); constrStr != "" {
				parsed, err := strconv.ParseUint(constrStr, 10, 32)
				if err != nil {
					meta.err = fmt.Errorf("invalid plutusConstr tag %q: %w", constrStr, err)
					return meta
				}
				meta.constrTag = parsed
				meta.hasConstr = true
			}
			continue
		}
		if !field.IsExported() {
			continue
		}
		meta.fields[i] = parseCachedField(field)
	}
	return meta
}

func parseCachedField(field reflect.StructField) parsedField {
	parsed := parsedField{}
	tag, options, err := parseFieldTag(field.Tag.Get("plutusType"))
	if err != nil {
		parsed.tagErr = fmt.Errorf("field %s: %w", field.Name, err)
		return parsed
	}
	parsed.plutusType = tag
	if tag == "Ignore" {
		if len(options) > 0 {
			parsed.tagErr = fmt.Errorf("field %s: Ignore does not accept options", field.Name)
			return parsed
		}
		parsed.ignore = true
	}
	if _, ok := options["omitempty"]; ok {
		parsed.omitempty = true
	}
	parsed.key = field.Tag.Get("plutusKey")
	if parsed.key == "" {
		parsed.key = field.Name
	}
	if opt := field.Tag.Get("plutusOptional"); opt != "" {
		optional, err := strconv.ParseBool(opt)
		if err != nil {
			parsed.optionalErr = fmt.Errorf("invalid plutusOptional tag %q on field %s: %w", opt, field.Name, err)
			return parsed
		}
		parsed.optional = optional
	}
	return parsed
}

func unmarshalPrealloc(n int) int {
	if n < 0 {
		return 0
	}
	if n > constants.MaxContainerPrealloc {
		return constants.MaxContainerPrealloc
	}
	return n
}

func constrTagEqual(tag *big.Int, expected uint64) bool {
	return tag != nil && tag.IsUint64() && tag.Uint64() == expected
}

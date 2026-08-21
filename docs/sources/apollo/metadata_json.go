package apollo

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"sort"
	"strings"
)

const metadataStringMaxBytes = 64

var (
	maxMetadataInteger = new(big.Int).SetUint64(^uint64(0))
	// The Cardano metadata integer range is [-(2^64-1), 2^64-1]; cardano-api
	// rejects values below negate(maxBound::Word64), i.e. below -(2^64-1).
	minMetadataInteger = new(big.Int).Neg(maxMetadataInteger)
)

// MetadataJSONSchema selects the Cardano transaction metadata JSON mapping.
type MetadataJSONSchema int

const (
	// MetadataJSONNoSchema is the cardano-cli no-schema mapping used by --metadata-json-file.
	MetadataJSONNoSchema MetadataJSONSchema = iota

	// MetadataJSONDetailedSchema is the tagged int/bytes/string/list/map mapping.
	MetadataJSONDetailedSchema
)

// MetadataMapEntry is one key/value pair in a Cardano metadata map.
type MetadataMapEntry struct {
	Key   any
	Value any
}

// MetadataMap preserves arbitrary metadata map keys, including bytes.
type MetadataMap []MetadataMapEntry

// ShelleyMetadataFromJSON parses cardano-cli no-schema metadata JSON.
func ShelleyMetadataFromJSON(jsonData []byte) (map[uint64]any, error) {
	return ShelleyMetadataFromJSONWithSchema(jsonData, MetadataJSONNoSchema)
}

// ShelleyMetadataFromJSONWithSchema parses metadata JSON using the requested Cardano mapping.
func ShelleyMetadataFromJSONWithSchema(jsonData []byte, schema MetadataJSONSchema) (map[uint64]any, error) {
	var raw any
	dec := json.NewDecoder(bytes.NewReader(jsonData))
	dec.UseNumber()
	if err := dec.Decode(&raw); err != nil {
		return nil, fmt.Errorf("decode metadata JSON: %w", err)
	}
	var extra any
	if err := dec.Decode(&extra); err != io.EOF {
		if err == nil {
			return nil, errors.New("decode metadata JSON: multiple JSON values")
		}
		return nil, fmt.Errorf("decode metadata JSON: %w", err)
	}
	return parseTopLevelMetadata(raw, schema)
}

func parseTopLevelMetadata(raw any, schema MetadataJSONSchema) (map[uint64]any, error) {
	object, ok := raw.(map[string]any)
	if !ok {
		return nil, errors.New("metadata JSON top level must be an object")
	}
	metadata := make(map[uint64]any, len(object))
	for key, value := range object {
		label, err := parseTopLevelMetadataLabel(key)
		if err != nil {
			return nil, err
		}
		path := fmt.Sprintf("metadata[%d]", label)
		var parsed any
		switch schema {
		case MetadataJSONNoSchema:
			parsed, err = parseNoSchemaMetadataValue(value, path)
		case MetadataJSONDetailedSchema:
			parsed, err = parseDetailedMetadataValue(value, path)
		default:
			err = fmt.Errorf("unsupported metadata JSON schema %d", schema)
		}
		if err != nil {
			return nil, err
		}
		metadata[label] = parsed
	}
	return metadata, nil
}

func parseNoSchemaMetadataValue(value any, path string) (any, error) {
	switch v := value.(type) {
	case nil:
		return nil, fmt.Errorf("%s: null metadata values are not allowed", path)
	case bool:
		return nil, fmt.Errorf("%s: boolean metadata values are not allowed", path)
	case json.Number:
		return parseJSONMetadataNumber(v, path)
	case string:
		return parseNoSchemaString(v, path)
	case []any:
		items := make([]any, 0, len(v))
		for idx, item := range v {
			parsed, err := parseNoSchemaMetadataValue(item, fmt.Sprintf("%s[%d]", path, idx))
			if err != nil {
				return nil, err
			}
			items = append(items, parsed)
		}
		return items, nil
	case map[string]any:
		entries := make(MetadataMap, 0, len(v))
		keys := make([]string, 0, len(v))
		for key := range v {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			item := v[key]
			parsedKey, err := parseNoSchemaMapKey(key, fmt.Sprintf("%s key %q", path, key))
			if err != nil {
				return nil, err
			}
			parsedValue, err := parseNoSchemaMetadataValue(item, fmt.Sprintf("%s.%q", path, key))
			if err != nil {
				return nil, err
			}
			entries = append(entries, MetadataMapEntry{Key: parsedKey, Value: parsedValue})
		}
		return entries, nil
	default:
		return nil, fmt.Errorf("%s: unsupported JSON metadata value", path)
	}
}

func parseDetailedMetadataValue(value any, path string) (any, error) {
	object, ok := value.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("%s: detailed metadata value must be an object", path)
	}
	if len(object) != 1 {
		return nil, fmt.Errorf("%s: detailed metadata value must have exactly one field", path)
	}
	for key, typedValue := range object {
		switch key {
		case "int":
			number, ok := typedValue.(json.Number)
			if !ok {
				return nil, fmt.Errorf("%s.int: expected JSON number", path)
			}
			return parseJSONMetadataNumber(number, path+".int")
		case "bytes":
			text, ok := typedValue.(string)
			if !ok {
				return nil, fmt.Errorf("%s.bytes: expected hex string", path)
			}
			return parseDetailedBytes(text, path+".bytes")
		case "string":
			text, ok := typedValue.(string)
			if !ok {
				return nil, fmt.Errorf("%s.string: expected string", path)
			}
			if err := validateMetadataText(text, path+".string"); err != nil {
				return nil, err
			}
			return text, nil
		case "list":
			list, ok := typedValue.([]any)
			if !ok {
				return nil, fmt.Errorf("%s.list: expected array", path)
			}
			items := make([]any, 0, len(list))
			for idx, item := range list {
				parsed, err := parseDetailedMetadataValue(item, fmt.Sprintf("%s.list[%d]", path, idx))
				if err != nil {
					return nil, err
				}
				items = append(items, parsed)
			}
			return items, nil
		case "map":
			list, ok := typedValue.([]any)
			if !ok {
				return nil, fmt.Errorf("%s.map: expected array", path)
			}
			entries := make(MetadataMap, 0, len(list))
			for idx, item := range list {
				entry, err := parseDetailedMapEntry(item, fmt.Sprintf("%s.map[%d]", path, idx))
				if err != nil {
					return nil, err
				}
				entries = append(entries, entry)
			}
			return entries, nil
		default:
			return nil, fmt.Errorf("%s: unknown detailed metadata field %q", path, key)
		}
	}
	return nil, fmt.Errorf("%s: empty detailed metadata object", path)
}

func parseDetailedMapEntry(value any, path string) (MetadataMapEntry, error) {
	object, ok := value.(map[string]any)
	if !ok || len(object) != 2 {
		return MetadataMapEntry{}, fmt.Errorf("%s: map entry must be an object with k and v fields", path)
	}
	keyValue, hasKey := object["k"]
	valueValue, hasValue := object["v"]
	if !hasKey || !hasValue {
		return MetadataMapEntry{}, fmt.Errorf("%s: map entry must contain k and v fields", path)
	}
	key, err := parseDetailedMetadataValue(keyValue, path+".k")
	if err != nil {
		return MetadataMapEntry{}, err
	}
	parsedValue, err := parseDetailedMetadataValue(valueValue, path+".v")
	if err != nil {
		return MetadataMapEntry{}, err
	}
	return MetadataMapEntry{Key: key, Value: parsedValue}, nil
}

func parseTopLevelMetadataLabel(label string) (uint64, error) {
	parsed, ok := parseUnsignedIntegerText(label)
	if !ok {
		return 0, fmt.Errorf("metadata top-level key %q must be an unsigned integer without leading zeroes", label)
	}
	if parsed.Cmp(maxMetadataInteger) > 0 {
		return 0, fmt.Errorf("metadata top-level key %q exceeds uint64 range", label)
	}
	return parsed.Uint64(), nil
}

func parseNoSchemaMapKey(key string, path string) (any, error) {
	if parsed, ok := parseSignedIntegerText(key); ok {
		return metadataIntegerFromBig(parsed, path)
	}
	if bytesValue, ok, err := parseNoSchemaBytes(key, path); ok || err != nil {
		return bytesValue, err
	}
	if err := validateMetadataText(key, path); err != nil {
		return nil, err
	}
	return key, nil
}

func parseNoSchemaString(value string, path string) (any, error) {
	if bytesValue, ok, err := parseNoSchemaBytes(value, path); ok || err != nil {
		return bytesValue, err
	}
	if err := validateMetadataText(value, path); err != nil {
		return nil, err
	}
	return value, nil
}

func parseNoSchemaBytes(value string, path string) ([]byte, bool, error) {
	if !strings.HasPrefix(value, "0x") {
		return nil, false, nil
	}
	hexValue := value[2:]
	// hex.DecodeString is case-insensitive, so uppercase A-F is accepted.
	decoded, err := hex.DecodeString(hexValue)
	if err != nil {
		return nil, false, nil
	}
	if err := validateMetadataBytes(decoded, path); err != nil {
		return nil, true, err
	}
	return decoded, true, nil
}

func parseDetailedBytes(value string, path string) ([]byte, error) {
	decoded, err := hex.DecodeString(value)
	if err != nil {
		return nil, fmt.Errorf("%s: expected hex-encoded bytes: %w", path, err)
	}
	if err := validateMetadataBytes(decoded, path); err != nil {
		return nil, err
	}
	return decoded, nil
}

func parseJSONMetadataNumber(number json.Number, path string) (any, error) {
	parsed, ok := parseSignedIntegerText(number.String())
	if !ok {
		return nil, fmt.Errorf("%s: metadata number must be an integer", path)
	}
	return metadataIntegerFromBig(parsed, path)
}

func metadataIntegerFromBig(value *big.Int, path string) (any, error) {
	if value.Cmp(minMetadataInteger) < 0 || value.Cmp(maxMetadataInteger) > 0 {
		return nil, fmt.Errorf("%s: metadata integer %s is outside the supported range", path, value.String())
	}
	return new(big.Int).Set(value), nil
}

func parseUnsignedIntegerText(value string) (*big.Int, bool) {
	if value == "" {
		return nil, false
	}
	if len(value) > 1 && value[0] == '0' {
		return nil, false
	}
	for _, ch := range value {
		if ch < '0' || ch > '9' {
			return nil, false
		}
	}
	parsed := new(big.Int)
	if _, ok := parsed.SetString(value, 10); !ok {
		return nil, false
	}
	return parsed, true
}

func parseSignedIntegerText(value string) (*big.Int, bool) {
	if strings.HasPrefix(value, "-") {
		parsed, ok := parseUnsignedIntegerText(value[1:])
		if !ok {
			return nil, false
		}
		parsed.Neg(parsed)
		return parsed, true
	}
	return parseUnsignedIntegerText(value)
}

func validateMetadataText(value string, path string) error {
	if len(value) > metadataStringMaxBytes {
		return fmt.Errorf("%s: metadata text value exceeds %d UTF-8 bytes", path, metadataStringMaxBytes)
	}
	return nil
}

func validateMetadataBytes(value []byte, path string) error {
	if len(value) > metadataStringMaxBytes {
		return fmt.Errorf("%s: metadata bytes value exceeds %d bytes", path, metadataStringMaxBytes)
	}
	return nil
}

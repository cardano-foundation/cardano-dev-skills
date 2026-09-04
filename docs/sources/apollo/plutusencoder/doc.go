// Package plutusencoder marshals Go structs to and from Plutus data using
// plutusType and plutusConstr struct tags, so datums and redeemers can be
// declared as ordinary Go types instead of assembled by hand.
//
// MarshalPlutus takes a struct, or a pointer to one, and returns the encoded
// data.PlutusData. UnmarshalPlutus takes data.PlutusData and a non-nil
// pointer to a struct and fills it in.
//
// # The container marker
//
// An anonymous `_` field describes the struct itself rather than any single
// value. Its plutusType selects the shape:
//
//	IndefList    indefinite-length list (the default)
//	DefList      definite-length list
//	Map          map keyed by field name
//
// An absent `_` field, or an empty plutusType, means IndefList. Any other
// value is an error, so a typo cannot silently change the schema.
//
// A plutusConstr on the same field wraps the container in a constructor with
// that tag. It is parsed as a uint32:
//
//	type Redeemer struct {
//		_      struct{} `plutusType:"DefList" plutusConstr:"1"`
//		Amount int64    `plutusType:"Int"`
//	}
//
// # Field types
//
// plutusType on an exported field selects the codec for that field:
//
//	Int          any signed or unsigned integer kind
//	BigInt       *big.Int or big.Int; a nil *big.Int encodes as 0
//	Bytes        []byte
//	StringBytes  string, encoded as its UTF-8 bytes
//	HexString    string holding hex, decoded to the bytes it names
//	Bool         constructor 0 for false, 1 for true, definite-length
//	IndefBool    the same, indefinite-length
//	DefList      a slice, or a nested struct forced definite-length
//	IndefList    a slice, or a nested struct forced indefinite-length
//	Map          a native Go map, or a slice of key-value structs
//	Ignore       the field is skipped in both directions
//	Custom       the field's type must implement PlutusMarshaler
//
// A field with no plutusType must be a struct, and is marshaled recursively
// under its own container marker. Unexported fields are always skipped.
//
// When DefList or IndefList names a nested struct, the struct takes the
// field's shape unless it carries its own `_` container marker, which wins.
//
// # Options
//
// plutusType accepts comma-separated options after the type name. Surrounding
// whitespace is ignored, and a repeated option is an error. There is one
// option, omitempty, which drops a field whose value is empty from an encoded
// Map:
//
//	Memo string `plutusType:"StringBytes,omitempty"`
//
// Empty follows the encoding/json rules — false, numeric zero, a nil
// pointer or interface, and a zero-length string, array, slice or map — and a
// type may override them by implementing IsZero() bool.
//
// omitempty is rejected on the fields of a list container, where dropping one
// element would shift the position of every element after it. Ignore accepts
// no options at all.
//
// # Naming and optional fields
//
// In a Map container, a field's key is its Go name unless plutusKey overrides
// it. Two fields resolving to the same key is an error rather than one
// silently shadowing the other.
//
// plutusOptional:"true" lets a field be absent when decoding a Map; it is
// left at its zero value. The tag is read with strconv.ParseBool, and a
// value that does not parse is an error rather than being treated as
// required. It has no effect when encoding.
//
//	type Datum struct {
//		_     struct{} `plutusType:"Map"`
//		Owner []byte   `plutusType:"Bytes"       plutusKey:"owner"`
//		Memo  string   `plutusType:"StringBytes" plutusOptional:"true"`
//	}
//
// # Maps
//
// A Map field holds either a native Go map or a slice of structs.
//
// A native map encodes its keys and values with the scalar codec matching
// their Go kind, unless the field's plutusType names something other than
// Map, in which case that codec is used for both. Entries are sorted by
// encoded key bytes, so the output is deterministic, and two keys that encode
// identically are an error. A nil map cannot be encoded.
//
// A slice of structs takes the first exported field of each element as the
// key and the remaining fields as the value — a single remaining field
// becomes the value directly, several become a list. Duplicate keys are
// rejected here too.
//
// # Custom encoding
//
// A type implementing PlutusMarshaler encodes and decodes through its own
// methods, which take precedence over any plutusType on the field. This
// applies to whole fields, to slice elements, and to native map keys and
// values. Tagging a field Custom asserts that its type implements
// PlutusMarshaler, and is an error when it does not.
package plutusencoder

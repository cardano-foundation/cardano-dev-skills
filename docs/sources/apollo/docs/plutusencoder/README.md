# Plutus encoder

Package `plutusencoder` marshals Go structs to and from Plutus data using
struct tags, so datums and redeemers can be ordinary Go types.

```go
import "github.com/Salvionied/apollo/v2/plutusencoder"

type Datum struct {
    _      struct{} `plutusType:"DefList" plutusConstr:"1"`
    Pkh    []byte   `plutusType:"Bytes"`
    Amount int64    `plutusType:"Int"`
}

pd, err := plutusencoder.MarshalPlutus(Datum{Pkh: pkh, Amount: 10})
var out Datum
err = plutusencoder.UnmarshalPlutus(pd, &out)
```

`MarshalPlutus` accepts a struct or a pointer to one. `UnmarshalPlutus` takes
Plutus data and a non-nil pointer to a struct.

Runnable examples (including the encodings they produce) live in the package
godoc: [plutusencoder on pkg.go.dev](https://pkg.go.dev/github.com/Salvionied/apollo/v2/plutusencoder).
Do not copy CBOR hex into docs that can drift; the examples are the checked
source of truth.

## Container (`_` field)

An anonymous `_` field describes the struct itself. Its `plutusType` selects
the shape:

| `plutusType` | Encoding |
|--------------|----------|
| `IndefList` or empty / omitted `_` | Indefinite-length list (default) |
| `DefList` | Definite-length list |
| `Map` | Map keyed by field name (or `plutusKey`) |

Any other container type is an error, so a typo cannot silently change the
schema. `plutusConstr` on the same field wraps the container in a constructor;
it is parsed as a `uint32`.

When `DefList` or `IndefList` names a nested struct, the struct takes the
field's shape unless it carries its own `_` marker, which wins.

## Field types

`plutusType` on an exported field selects the codec:

| `plutusType` | Go types (typical) |
|--------------|-------------------|
| `Int` | any signed or unsigned integer kind |
| `BigInt` | `*big.Int` or `big.Int`; a nil `*big.Int` encodes as 0 |
| `Bytes` | `[]byte` |
| `StringBytes` | `string`, encoded as UTF-8 bytes |
| `HexString` | hex `string`, decoded to the bytes it names |
| `Bool` | constructor 0 for false, 1 for true, definite-length |
| `IndefBool` | the same, indefinite-length |
| `DefList` / `IndefList` | a slice, or a nested struct forced to that list form |
| `Map` | a native Go map, or a slice of key-value structs |
| `Ignore` | skipped in both directions; accepts no options |
| `Custom` | the field's type must implement `PlutusMarshaler` |

A field with no `plutusType` must be a struct and is marshaled recursively
under its own container marker. Unexported fields are always skipped.

Unknown types, unknown options, empty or duplicate options, and a malformed
`plutusConstr` are errors.

## Options

`plutusType` accepts comma-separated options after the type name. Surrounding
whitespace is ignored; a repeated option is an error.

`omitempty` drops a field whose value is empty from an encoded **Map**. Empty
follows `encoding/json` — false, numeric zero, nil pointer or interface, and
zero-length string, array, slice, or map — and a type may override that with
`IsZero() bool`. The option is rejected on positional list fields, where
dropping an element would shift the ones after it.

## Naming and optional fields

In a Map container, a field's key is its Go name unless `plutusKey` overrides
it. Two fields resolving to the same key are an error rather than one
silently shadowing the other.

`plutusOptional:"true"` lets a field be absent when **decoding** a Map; it is
left at its zero value. The tag is read with `strconv.ParseBool`; a value that
does not parse is an error. It has no effect when encoding.

## Maps

A Map field holds either a native Go map or a slice of structs.

A native map encodes keys and values with the scalar codec matching their Go
kind, unless the field's `plutusType` names something other than `Map`, in
which case that codec is used for both. Entries are sorted by encoded key
bytes (deterministic output). Duplicate encoded keys and nil maps are
rejected.

A slice of structs takes the first exported field of each element as the key
and the remaining fields as the value — a single remaining field becomes the
value directly, several become a list. Duplicate keys are rejected here too.
String and byte key fields round-trip.

## Custom encoding

A type implementing `PlutusMarshaler` encodes and decodes through its own
methods, which take precedence over any `plutusType` on the field. This
applies to whole fields, slice elements, and native map keys and values.
Tagging a field `Custom` asserts that its type implements `PlutusMarshaler`,
and is an error when it does not.

## Unmarshal checks

- `Bool` requires a constructor tag of 0 or 1 carrying no fields.
- A constructor is rejected where a bare Plutus list is required (slice
  fields and multi-field map values).
- Nested list encoding tags are honoured, so an inner list keeps its own
  `DefList` / `IndefList` form instead of inheriting the outer one.

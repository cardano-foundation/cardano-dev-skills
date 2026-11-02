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
| `Address` | `common.Address` as a Plutus ledger address |
| `Maybe` | a pointer; nil is Nothing, a value is Just of the element |
| `Either` | a two-pointer struct: `Left` is constructor 0, `Right` is constructor 1 |
| `OutputDatum` | `OutputDatum`: none is constructor 0, datum hash is 1, inline is 2 |
| `Interval` | `Interval` with explicit `BoundNegInf`, `BoundFinite`, and `BoundPosInf` bounds |
| `Value` | `Value` as a map of policy id to asset map, with lovelace under the empty policy |
| `V4Value` | `Value` as the Plutus V4 tagged `data.Value` constructor (CBOR tag 1401) |
| `Credential` | `common.Credential`: key hash is constructor 0, script hash is constructor 1 |
| `TxOutRef` | Plutus V3 `TxOutRef`: constructor 0 of a 32-byte transaction id and an output index. V1 and V2 wrap the id as constructor 0 of `[constructor 0 [txId], index]` |
| `AssetClass` | `AssetClass`: constructor 0 of a policy id and a token name |
| `Ignore` | skipped in both directions; accepts no options |
| `Custom` | the field's type must implement `PlutusMarshaler` |

A field with no `plutusType` must be a struct and is marshaled recursively
under its own container marker. Unexported fields are always skipped.

Unknown types, unknown options, empty or duplicate options, and a malformed
`plutusConstr` are errors.

```go
type Choice struct {
    Left  *int64
    Right *string
}

type Datum struct {
    _      struct{}                  `plutusType:"DefList" plutusConstr:"0"`
    Side   Choice                    `plutusType:"Either"`
    Datum  plutusencoder.OutputDatum `plutusType:"OutputDatum"`
    Window plutusencoder.Interval    `plutusType:"Interval"`
    Locked plutusencoder.Value       `plutusType:"Value"`
    Owner  common.Credential         `plutusType:"Credential"`
    Utxo   plutusencoder.TxOutRef    `plutusType:"TxOutRef"`
    Asset  plutusencoder.AssetClass  `plutusType:"AssetClass"`
}
```

`Either` encodes a struct with two exported pointer fields: the first is
`Left` (constructor 0) and the second is `Right` (constructor 1). Setting
both or neither is an error. `OutputDatum` uses constructor 0 when empty,
constructor 1 for a 32-byte `Hash`, and constructor 2 for `Inline`.
`IntervalBound.Value` is an `int64`, so a finite bound outside that range is
rejected.
`Interval` encodes lower and upper bounds with `BoundNegInf` (0),
`BoundFinite` (1), or `BoundPosInf` (2) and the closure flag the caller sets.

`Value` encodes the Plutus ledger `Value`: a map of policy id to a map of
asset name to quantity, with keys sorted by their bytes. Lovelace uses the
empty policy id and the empty asset name. `V4Value` encodes the same `Value`
struct as the Plutus V4 `data.Value` constructor (CBOR tag 1401) and runs
`data.Value.Validate()`. Encoding omits a zero quantity and an empty token
map, and sorts both levels. Decoding a plain `Value` keeps a zero quantity
and accepts an unsorted map or an empty token map; re-encoding makes that
canonical. `V4Value` still rejects a non-canonical value. Duplicate policy or
asset names and a negative quantity are errors on both paths. `UnmarshalPlutus`
on both tags accepts either `*data.Map` or `*data.Value`.

`Credential` encodes `common.Credential` as constructor 0 for a key hash and
constructor 1 for a script hash, with a 28-byte hash. `TxOutRef` is the
Plutus V3 shape: constructor 0 of a 32-byte transaction id and an unsigned
output index. Plutus V1 and V2 wrap that id as constructor 0 of
`[constructor 0 [txId], index]`. A datum built for those validators encodes
here and then fails on chain.
`AssetClass` is constructor 0 of an empty or 28-byte policy id and a token
name up to 32 bytes; an empty policy id requires an empty token name.

## Options

`plutusType` accepts comma-separated options after the type name. Surrounding
whitespace is ignored; a repeated option is an error.

`omitempty` drops a field whose value is empty. Empty follows `encoding/json`
— false, numeric zero, nil pointer or interface, and zero-length string,
array, slice, or map — and a type may override that with `IsZero() bool`.
A non-nil pointer is present even when the pointed-to value is zero, unless
that pointer's `IsZero` method returns true.

On a Map, the field is left out of the map. On a `DefList` or `IndefList`,
an empty field is left off the end of the list and decodes back as zero.
Decoding into a struct that already has a value resets a missing trailing
`omitempty` field, and an absent optional map key, to zero.
Omitting an empty field that still has a present field after it is an error:
a positional list cannot represent that hole. Put `omitempty` fields last, or
use `Ignore` when the field must never be encoded.

`Address` encodes `common.Address` as Plutus data. Shelley payment addresses
are constructor 0 of a payment credential and a Maybe staking credential:

- types 0–3, base: payment key or script, stake key or script
- types 4 and 5, pointer: `StakingPtr` of a slot, a transaction index, and a certificate index
- types 6 and 7, enterprise: payment key or script and `Nothing`

A reward account uses the bytes `Address.ToPlutusData` already returns. A
stake key (type 14) is constructor 0 of the 28-byte hash. A stake script
(type 15) is constructor 1 of that hash. Byron addresses have no Plutus form
and return an error. A pointer slot above 2^32-1, or a transaction or
certificate index above 65535, returns an error. Plutus data does not carry
a network id. `UnmarshalPlutus` decodes addresses as testnet.
`WithAddressNetwork(common.AddressNetworkMainnet)` selects mainnet for that
call, including an address nested in `Maybe`.

`Maybe` encodes a pointer as PlutusTx `Maybe`. Nil is constructor 1 with no
fields. A value is constructor 0 around the element. A type that implements
`PlutusMarshaler` is used first. `*big.Int` and `big.Int` use the integer
codec. `*common.Address` uses the address codec. Any other struct uses that
struct's codec. A non-nil pointer is `Just`, including `Just 0`.

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

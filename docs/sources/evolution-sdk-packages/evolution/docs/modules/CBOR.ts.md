---
title: CBOR.ts
nav_order: 34
parent: Modules
---

## CBOR overview

---

<h2 class="text-delta">Table of contents</h2>

- [constants](#constants)
  - [AIKEN_DEFAULT_OPTIONS](#aiken_default_options)
  - [CANONICAL_OPTIONS](#canonical_options)
  - [CARDANO_NODE_DATA_OPTIONS](#cardano_node_data_options)
  - [CBOR_ADDITIONAL_INFO](#cbor_additional_info)
  - [CBOR_MAJOR_TYPE](#cbor_major_type)
  - [CBOR_SIMPLE](#cbor_simple)
  - [CML_DATA_DEFAULT_OPTIONS](#cml_data_default_options)
  - [CML_DEFAULT_OPTIONS](#cml_default_options)
  - [STRUCT_FRIENDLY_OPTIONS](#struct_friendly_options)
- [decoding](#decoding)
  - [decodeItemWithOffset](#decodeitemwithoffset)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORBytesWithFormat](#tocborbyteswithformat)
  - [toCBORHex](#tocborhex)
  - [toCBORHexWithFormat](#tocborhexwithformat)
- [equality](#equality)
  - [equals](#equals)
- [errors](#errors)
  - [CBORError (class)](#cborerror-class)
- [model](#model)
  - [BoundedBytes](#boundedbytes)
  - [ByteSize (type alias)](#bytesize-type-alias)
  - [CBOR (type alias)](#cbor-type-alias)
  - [CBORFormat (type alias)](#cborformat-type-alias)
  - [CBORFormat (namespace)](#cborformat-namespace)
    - [Array (type alias)](#array-type-alias)
    - [Bytes (type alias)](#bytes-type-alias)
    - [Map (type alias)](#map-type-alias)
    - [NInt (type alias)](#nint-type-alias)
    - [Simple (type alias)](#simple-type-alias)
    - [Tag (type alias)](#tag-type-alias)
    - [Text (type alias)](#text-type-alias)
    - [UInt (type alias)](#uint-type-alias)
  - [CodecOptions (type alias)](#codecoptions-type-alias)
  - [DecodedWithFormat (type alias)](#decodedwithformat-type-alias)
  - [LengthEncoding (type alias)](#lengthencoding-type-alias)
  - [StringEncoding (type alias)](#stringencoding-type-alias)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORBytesWithFormat](#fromcborbyteswithformat)
  - [fromCBORHex](#fromcborhex)
  - [fromCBORHexWithFormat](#fromcborhexwithformat)
  - [internalDecodeWithFormatSync](#internaldecodewithformatsync)
- [schemas](#schemas)
  - [CBORSchema](#cborschema)
  - [FromBytes](#frombytes)
  - [Integer](#integer)
- [transformation](#transformation)
  - [match](#match)
- [utils](#utils)
  - [ArraySchema](#arrayschema)
  - [ByteArray](#bytearray)
  - [Either (namespace)](#either-namespace)
  - [Float](#float)
  - [FromHex](#fromhex)
  - [MapSchema](#mapschema)
  - [RecordSchema](#recordschema)
  - [Simple](#simple)
  - [Tag](#tag)
  - [Text](#text)
  - [encodeArrayAsDefinite](#encodearrayasdefinite)
  - [encodeArrayAsIndefinite](#encodearrayasindefinite)
  - [encodeTaggedValue](#encodetaggedvalue)
  - [internalDecodeSync](#internaldecodesync)
  - [internalEncodeSync](#internalencodesync)
  - [isArray](#isarray)
  - [isByteArray](#isbytearray)
  - [isInteger](#isinteger)
  - [isMap](#ismap)
  - [isRecord](#isrecord)
  - [isTag](#istag)
  - [map](#map)
  - [tag](#tag-1)

---

# constants

## AIKEN_DEFAULT_OPTIONS

Aiken-compatible CBOR encoding options.

Matches the encoding produced by `cbor.serialise()` in Aiken:

- Indefinite-length arrays (`9f...ff`)
- Maps encoded as arrays of pairs (not CBOR maps)
- Strings as byte arrays (major type 2, not 3)
- Constructor tags: 121–127 for indices 0–6, then 1280+ for 7+

PlutusData byte strings are chunked per the Conway `bounded_bytes` rule
via the `BoundedBytes` CBOR node, independent of these codec options.

**Signature**

```ts
export declare const AIKEN_DEFAULT_OPTIONS: CodecOptions
```

Added in v2.0.0

## CANONICAL_OPTIONS

Canonical CBOR encoding options (RFC 8949 Section 4.2.1)

**Signature**

```ts
export declare const CANONICAL_OPTIONS: CodecOptions
```

Added in v1.0.0

## CARDANO_NODE_DATA_OPTIONS

Cardano Node compatible CBOR encoding options for PlutusData

Uses definite-length encoding for arrays and maps, matching the format
produced by CML's `to_cardano_node_format().to_cbor_hex()`.

Note: The on-chain format uses indefinite-length (AIKEN_DEFAULT_OPTIONS),
but this option is useful for testing compatibility with tools that
expect definite-length encoding.

**Signature**

```ts
export declare const CARDANO_NODE_DATA_OPTIONS: CodecOptions
```

Added in v2.0.0

## CBOR_ADDITIONAL_INFO

CBOR additional information constants

**Signature**

```ts
export declare const CBOR_ADDITIONAL_INFO: {
  readonly DIRECT: 24
  readonly UINT16: 25
  readonly UINT32: 26
  readonly UINT64: 27
  readonly INDEFINITE: 31
}
```

Added in v1.0.0

## CBOR_MAJOR_TYPE

CBOR major types as constants

**Signature**

```ts
export declare const CBOR_MAJOR_TYPE: {
  readonly UNSIGNED_INTEGER: 0
  readonly NEGATIVE_INTEGER: 1
  readonly BYTE_STRING: 2
  readonly TEXT_STRING: 3
  readonly ARRAY: 4
  readonly MAP: 5
  readonly TAG: 6
  readonly SIMPLE_FLOAT: 7
}
```

Added in v1.0.0

## CBOR_SIMPLE

Simple value constants for CBOR

**Signature**

```ts
export declare const CBOR_SIMPLE: { readonly FALSE: 20; readonly TRUE: 21; readonly NULL: 22; readonly UNDEFINED: 23 }
```

Added in v1.0.0

## CML_DATA_DEFAULT_OPTIONS

Default CBOR encoding options for PlutusData.

Uses indefinite-length arrays and maps. The `bounded_bytes` constraint
(Conway CDDL: byte strings ≤ 64 bytes) is enforced at the data-type layer
via the `BoundedBytes` CBOR node, independent of these codec options.

**Signature**

```ts
export declare const CML_DATA_DEFAULT_OPTIONS: CodecOptions
```

Added in v1.0.0

## CML_DEFAULT_OPTIONS

Default CBOR encoding options

**Signature**

```ts
export declare const CML_DEFAULT_OPTIONS: CodecOptions
```

Added in v1.0.0

## STRUCT_FRIENDLY_OPTIONS

CBOR encoding options that return objects instead of Maps for Schema.Struct compatibility

**Signature**

```ts
export declare const STRUCT_FRIENDLY_OPTIONS: CodecOptions
```

Added in v2.0.0

# decoding

## decodeItemWithOffset

Decode a single CBOR item at a given byte offset, returning the decoded value and the new offset.
Useful for extracting raw byte slices from CBOR-encoded data without re-encoding.

**Signature**

```ts
export declare const decodeItemWithOffset: (
  data: Uint8Array,
  offset: number,
  options?: CodecOptions
) => { item: CBOR; newOffset: number }
```

Added in v2.0.0

# encoding

## toCBORBytes

Convert a CBOR value to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (value: CBOR, options?: CodecOptions) => Uint8Array
```

Added in v1.0.0

## toCBORBytesWithFormat

Convert a CBOR value to CBOR bytes using an explicit root format tree.

**Signature**

```ts
export declare const toCBORBytesWithFormat: (value: CBOR, format: CBORFormat) => Uint8Array
```

Added in v2.0.0

## toCBORHex

Convert a CBOR value to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (value: CBOR, options?: CodecOptions) => string
```

Added in v1.0.0

## toCBORHexWithFormat

Convert a CBOR value to CBOR hex string using an explicit root format tree.

**Signature**

```ts
export declare const toCBORHexWithFormat: (value: CBOR, format: CBORFormat) => string
```

Added in v2.0.0

# equality

## equals

Schema-derived structural equivalence for CBOR values.
Handles Uint8Array, Array, Map, Tag and all primitives via the
recursive CBORSchema definition — no hand-rolled comparison needed.

Derived once at module init; at call time it's a plain function.

**Signature**

```ts
export declare const equals: (a: CBOR, b: CBOR) => boolean
```

Added in v2.0.0

# errors

## CBORError (class)

Error class for CBOR value operations

**Signature**

```ts
export declare class CBORError
```

Added in v1.0.0

# model

## BoundedBytes

`BoundedBytes` CBOR node — represents a PlutusData byte string that must comply
with the Conway CDDL constraint `bounded_bytes = bytes .size (0..64)`.

The encoding rule is unconditional and options-independent:

- ≤ 64 bytes → definite-length CBOR bytes
- > 64 bytes → indefinite-length 64-byte chunked byte string (`0x5f` + chunks + `0xff`)

Use `BoundedBytes.make` to construct the node; the encoder handles the rest.

**Signature**

```ts
export declare const BoundedBytes: {
  readonly make: (bytes: Uint8Array) => CBOR
  readonly is: (value: CBOR) => value is { _tag: "BoundedBytes"; bytes: Uint8Array }
}
```

Added in v2.0.0

## ByteSize (type alias)

Width of a CBOR integer argument: inline (0), 1-byte, 2-byte, 4-byte, or 8-byte.

**Signature**

```ts
export type ByteSize = 0 | 1 | 2 | 4 | 8
```

Added in v2.0.0

## CBOR (type alias)

Type representing a CBOR value with simplified, non-tagged structure

**Signature**

```ts
export type CBOR =
  | bigint // integers (both positive and negative)
  | Uint8Array // byte strings
  | string // text strings
  | ReadonlyArray<CBOR> // arrays
  | ReadonlyMap<CBOR, CBOR> // maps
  | { readonly [key: string | number]: CBOR } // record alternative to maps
  | { _tag: "Tag"; tag: number; value: CBOR } // tagged values
  | boolean // boolean values
  | null // null value
  | undefined // undefined value
  | number // floating point numbers
  | { _tag: "BoundedBytes"; bytes: Uint8Array }
```

Added in v1.0.0

## CBORFormat (type alias)

Tagged discriminated union capturing how each CBOR node was originally
serialized. Every variant carries a `_tag` discriminant. Encoding-detail
fields are optional — absent means "use canonical / minimal default".

**Signature**

```ts
export type CBORFormat =
  | CBORFormat.UInt
  | CBORFormat.NInt
  | CBORFormat.Bytes
  | CBORFormat.Text
  | CBORFormat.Array
  | CBORFormat.Map
  | CBORFormat.Tag
  | CBORFormat.Simple
```

Added in v2.0.0

## CBORFormat (namespace)

Added in v2.0.0

### Array (type alias)

Array (major 4). `length` absent → definite, minimal length header.

**Signature**

```ts
export type Array = {
  readonly _tag: "array"
  readonly length?: LengthEncoding
  readonly children: ReadonlyArray<CBORFormat>
}
```

### Bytes (type alias)

Byte string (major 2). `encoding` absent → definite, minimal length.

**Signature**

```ts
export type Bytes = { readonly _tag: "bytes"; readonly encoding?: StringEncoding }
```

### Map (type alias)

Map (major 5). `keyOrder` stores CBOR-encoded key bytes for serializable ordering.

**Signature**

```ts
export type Map = {
  readonly _tag: "map"
  readonly length?: LengthEncoding
  readonly keyOrder?: ReadonlyArray<Uint8Array>
  readonly entries: ReadonlyArray<readonly [CBORFormat, CBORFormat]>
}
```

### NInt (type alias)

Negative integer (major 1). `byteSize` absent → minimal encoding.

**Signature**

```ts
export type NInt = { readonly _tag: "nint"; readonly byteSize?: ByteSize }
```

### Simple (type alias)

Simple value or float (major 7). No encoding choices to preserve.

**Signature**

```ts
export type Simple = { readonly _tag: "simple" }
```

### Tag (type alias)

Tag (major 6). `width` absent → minimal tag header.

**Signature**

```ts
export type Tag = {
  readonly _tag: "tag"
  readonly width?: ByteSize
  readonly child: CBORFormat
}
```

### Text (type alias)

Text string (major 3). `encoding` absent → definite, minimal length.

**Signature**

```ts
export type Text = { readonly _tag: "text"; readonly encoding?: StringEncoding }
```

### UInt (type alias)

Unsigned integer (major 0). `byteSize` absent → minimal encoding.

**Signature**

```ts
export type UInt = { readonly _tag: "uint"; readonly byteSize?: ByteSize }
```

## CodecOptions (type alias)

CBOR codec configuration options

**Signature**

```ts
export type CodecOptions =
  | {
      readonly mode: "canonical"
      readonly mapsAsObjects?: boolean
      readonly encodeMapAsPairs?: boolean
    }
  | {
      readonly mode: "custom"
      readonly useIndefiniteArrays: boolean
      readonly useIndefiniteMaps: boolean
      readonly useDefiniteForEmpty: boolean
      readonly sortMapKeys: boolean
      readonly useMinimalEncoding: boolean
      readonly mapsAsObjects?: boolean
      readonly encodeMapAsPairs?: boolean
    }
```

Added in v1.0.0

## DecodedWithFormat (type alias)

Decoded value paired with its captured root format tree.

**Signature**

```ts
export type DecodedWithFormat<A> = {
  value: A
  format: CBORFormat
}
```

Added in v2.0.0

## LengthEncoding (type alias)

Container length encoding style captured during decode.

**Signature**

```ts
export type LengthEncoding = { readonly tag: "indefinite" } | { readonly tag: "definite"; readonly byteSize: ByteSize }
```

Added in v2.0.0

## StringEncoding (type alias)

Byte/text string encoding style captured during decode.

**Signature**

```ts
export type StringEncoding =
  | { readonly tag: "definite"; readonly byteSize: ByteSize }
  | {
      readonly tag: "indefinite"
      readonly chunks: ReadonlyArray<{ readonly length: number; readonly byteSize: ByteSize }>
    }
```

Added in v2.0.0

# parsing

## fromCBORBytes

Parse a CBOR value from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CodecOptions) => CBOR
```

Added in v1.0.0

## fromCBORBytesWithFormat

Parse a CBOR value from CBOR bytes and return the root format tree.

**Signature**

```ts
export declare const fromCBORBytesWithFormat: (bytes: Uint8Array) => DecodedWithFormat<CBOR>
```

Added in v2.0.0

## fromCBORHex

Parse a CBOR value from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CodecOptions) => CBOR
```

Added in v1.0.0

## fromCBORHexWithFormat

Parse a CBOR value from CBOR hex string and return the root format tree.

**Signature**

```ts
export declare const fromCBORHexWithFormat: (hex: string) => DecodedWithFormat<CBOR>
```

Added in v2.0.0

## internalDecodeWithFormatSync

Decode CBOR bytes and return both the decoded value and the root format tree.

**Signature**

```ts
export declare const internalDecodeWithFormatSync: (data: Uint8Array) => DecodedWithFormat<CBOR>
```

Added in v2.0.0

# schemas

## CBORSchema

CBOR Value discriminated union schema representing all possible CBOR data types
Inspired by OCaml and Rust CBOR implementations

**Signature**

```ts
export declare const CBORSchema: Schema.Schema<CBOR, CBOR, never>
```

Added in v1.0.0

## FromBytes

Create a CBOR bytes schema with custom codec options

**Signature**

```ts
export declare const FromBytes: (
  options: CodecOptions
) => Schema.transformOrFail<typeof Schema.Uint8ArrayFromSelf, Schema.declare<CBOR, CBOR, readonly [], never>, never>
```

Added in v1.0.0

## Integer

CBOR Value schema definitions for each major type

**Signature**

```ts
export declare const Integer: typeof Schema.BigIntFromSelf
```

Added in v1.0.0

# transformation

## match

Pattern matching utility for CBOR values

**Signature**

```ts
export declare const match: <R>(
  value: CBOR,
  patterns: {
    integer: (value: bigint) => R
    bytes: (value: Uint8Array) => R
    text: (value: string) => R
    array: (value: ReadonlyArray<CBOR>) => R
    map: (value: ReadonlyMap<CBOR, CBOR>) => R
    record: (value: { readonly [key: string]: CBOR }) => R
    tag: (tag: number, value: CBOR) => R
    boolean: (value: boolean) => R
    null: () => R
    undefined: () => R
    float: (value: number) => R
    boundedBytes: (value: Uint8Array) => R
  }
) => R
```

Added in v1.0.0

# utils

## ArraySchema

**Signature**

```ts
export declare const ArraySchema: Schema.Array$<Schema.suspend<CBOR, CBOR, never>>
```

## ByteArray

**Signature**

```ts
export declare const ByteArray: typeof Schema.Uint8ArrayFromSelf
```

## Either (namespace)

## Float

**Signature**

```ts
export declare const Float: typeof Schema.Number
```

## FromHex

**Signature**

```ts
export declare const FromHex: (
  options: CodecOptions
) => Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transformOrFail<typeof Schema.Uint8ArrayFromSelf, Schema.declare<CBOR, CBOR, readonly [], never>, never>
>
```

## MapSchema

**Signature**

```ts
export declare const MapSchema: Schema.ReadonlyMapFromSelf<
  Schema.suspend<CBOR, CBOR, never>,
  Schema.suspend<CBOR, CBOR, never>
>
```

## RecordSchema

**Signature**

```ts
export declare const RecordSchema: Schema.Record$<typeof Schema.String, Schema.suspend<CBOR, CBOR, never>>
```

## Simple

**Signature**

```ts
export declare const Simple: Schema.Union<[typeof Schema.Boolean, typeof Schema.Null, typeof Schema.Undefined]>
```

## Tag

**Signature**

```ts
export declare const Tag: Schema.TaggedStruct<
  "Tag",
  { tag: typeof Schema.Number; value: Schema.suspend<CBOR, CBOR, never> }
>
```

## Text

**Signature**

```ts
export declare const Text: typeof Schema.String
```

## encodeArrayAsDefinite

Encode a CBOR definite-length array from already-encoded item bytes.
This is a low-level function that constructs: definite_array_header + items.

**Signature**

```ts
export declare const encodeArrayAsDefinite: (items: ReadonlyArray<Uint8Array>) => Uint8Array
```

## encodeArrayAsIndefinite

Encode a CBOR indefinite-length array from already-encoded item bytes.
This is a low-level function that constructs: 0x9f + items + 0xff.

**Signature**

```ts
export declare const encodeArrayAsIndefinite: (items: ReadonlyArray<Uint8Array>) => Uint8Array
```

## encodeTaggedValue

Encode a CBOR tagged value from already-encoded value bytes.
This is a low-level function that constructs: tag_header + value_bytes.

**Signature**

```ts
export declare const encodeTaggedValue: (tag: number, valueBytes: Uint8Array) => Uint8Array
```

## internalDecodeSync

**Signature**

```ts
export declare const internalDecodeSync: (data: Uint8Array, options?: CodecOptions) => CBOR
```

## internalEncodeSync

**Signature**

```ts
export declare const internalEncodeSync: (value: CBOR, options?: CodecOptions, fmt?: CBORFormat) => Uint8Array
```

## isArray

**Signature**

```ts
export declare const isArray: (u: unknown, overrideOptions?: ParseOptions | number) => u is readonly CBOR[]
```

## isByteArray

**Signature**

```ts
export declare const isByteArray: (u: unknown, overrideOptions?: ParseOptions | number) => u is any
```

## isInteger

**Signature**

```ts
export declare const isInteger: (u: unknown, overrideOptions?: ParseOptions | number) => u is bigint
```

## isMap

**Signature**

```ts
export declare const isMap: (u: unknown, overrideOptions?: ParseOptions | number) => u is ReadonlyMap<CBOR, CBOR>
```

## isRecord

**Signature**

```ts
export declare const isRecord: (
  u: unknown,
  overrideOptions?: ParseOptions | number
) => u is { readonly [x: string]: CBOR }
```

## isTag

**Signature**

```ts
export declare const isTag: (
  u: unknown,
  overrideOptions?: ParseOptions | number
) => u is { readonly _tag: "Tag"; readonly tag: number; readonly value: CBOR }
```

## map

**Signature**

```ts
export declare const map: <K extends CBOR, V extends CBOR>(
  key: Schema.Schema<K>,
  value: Schema.Schema<V>
) => Schema.ReadonlyMapFromSelf<Schema.Schema<K, K, never>, Schema.Schema<V, V, never>>
```

## tag

**Signature**

```ts
export declare const tag: <T extends number, C extends Schema.Schema<any, any>>(
  tag: T,
  value: C
) => Schema.TaggedStruct<"Tag", { tag: Schema.Literal<[T]>; value: C }>
```

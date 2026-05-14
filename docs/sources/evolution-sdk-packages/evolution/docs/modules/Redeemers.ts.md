---
title: Redeemers.ts
nav_order: 110
parent: Modules
---

## Redeemers overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [constructors](#constructors)
  - [makeRedeemerMap](#makeredeemermap)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORBytesMap](#tocborbytesmap)
  - [toCBORHex](#tocborhex)
  - [toCBORHexMap](#tocborhexmap)
- [hashing](#hashing)
  - [toScriptDataHash](#toscriptdatahash)
- [model](#model)
  - [RedeemerArray (class)](#redeemerarray-class)
    - [toArray (method)](#toarray-method)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [RedeemerKey (type alias)](#redeemerkey-type-alias)
  - [RedeemerMap (class)](#redeemermap-class)
    - [get (method)](#get-method)
    - [toArray (method)](#toarray-method-1)
    - [toJSON (method)](#tojson-method-1)
    - [toString (method)](#tostring-method-1)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-1)
    - [[Equal.symbol] (method)](#equalsymbol-method-1)
    - [[Hash.symbol] (method)](#hashsymbol-method-1)
  - [RedeemerValue (class)](#redeemervalue-class)
    - [[Equal.symbol] (method)](#equalsymbol-method-2)
    - [[Hash.symbol] (method)](#hashsymbol-method-2)
  - [Redeemers (type alias)](#redeemers-type-alias)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORBytesMap](#fromcborbytesmap)
  - [fromCBORHex](#fromcborhex)
  - [fromCBORHexMap](#fromcborhexmap)
- [schemas](#schemas)
  - [ArrayCDDLSchema](#arraycddlschema)
  - [CDDLSchema](#cddlschema)
  - [FromArrayCDDL](#fromarraycddl)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORBytesMap](#fromcborbytesmap-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCBORHexMap](#fromcborhexmap-1)
  - [FromCDDL](#fromcddl)
  - [FromMapCDDL](#frommapcddl)
  - [MapCDDLSchema](#mapcddlschema)
  - [Redeemers](#redeemers)
- [utilities](#utilities)
  - [keyToString](#keytostring)

---

# arbitrary

## arbitrary

FastCheck arbitrary for Redeemers — generates both map and array variants.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<RedeemerMap | RedeemerArray>
```

Added in v2.0.0

# constructors

## makeRedeemerMap

Create a `RedeemerMap` from an array of `Redeemer` objects.

**Signature**

```ts
export declare const makeRedeemerMap: (redeemers: ReadonlyArray<Redeemer.Redeemer>) => RedeemerMap
```

Added in v2.0.0

# encoding

## toCBORBytes

Encode to CBOR bytes (array format).

**Signature**

```ts
export declare const toCBORBytes: (data: RedeemerArray, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORBytesMap

Encode to CBOR bytes (map format).

**Signature**

```ts
export declare const toCBORBytesMap: (data: RedeemerMap, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORHex

Encode to CBOR hex string (array format).

**Signature**

```ts
export declare const toCBORHex: (data: RedeemerArray, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

## toCBORHexMap

Encode to CBOR hex string (map format).

**Signature**

```ts
export declare const toCBORHexMap: (data: RedeemerMap, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# hashing

## toScriptDataHash

Compute script_data_hash using standard module encoders.

Accepts the concrete `Redeemers` union type — encoding format is determined
by `_tag` (`RedeemerMap` → map CBOR, `RedeemerArray` → array CBOR).

The payload format per CDDL spec is raw concatenation (not a CBOR structure):

```
redeemers_bytes || datums_bytes || language_views_bytes
```

**Signature**

```ts
export declare const toScriptDataHash: (
  redeemers: Redeemers,
  costModels: CostModel.CostModels,
  datums?: ReadonlyArray<Data.Data>,
  options?: CBOR.CodecOptions
) => ScriptDataHash.ScriptDataHash
```

Added in v2.0.0

# model

## RedeemerArray (class)

Redeemers in legacy array format.

Mirrors the CDDL:

```
[ + redeemer ]
```

Backwards compatible — will be deprecated in the next era.
Prefer `RedeemerMap` for new transactions.

**Signature**

```ts
export declare class RedeemerArray
```

Added in v2.0.0

### toArray (method)

Convert to an array of `Redeemer` objects (identity for array format).

**Signature**

```ts
toArray(): ReadonlyArray<Redeemer.Redeemer>
```

Added in v2.0.0

### toJSON (method)

**Signature**

```ts
toJSON()
```

### toString (method)

**Signature**

```ts
toString(): string
```

### [Inspectable.NodeInspectSymbol] (method)

**Signature**

```ts
[Inspectable.NodeInspectSymbol](): unknown
```

### [Equal.symbol] (method)

**Signature**

```ts
[Equal.symbol](that: unknown): boolean
```

### [Hash.symbol] (method)

**Signature**

```ts
[Hash.symbol](): number
```

## RedeemerKey (type alias)

A redeemer map key: `[tag, index]`.

Mirrors the CDDL: `[tag : redeemer_tag, index : uint .size 4]`

**Signature**

```ts
export type RedeemerKey = readonly [Redeemer.RedeemerTag, bigint]
```

Added in v2.0.0

## RedeemerMap (class)

Redeemers in map format (Conway recommended).

Mirrors the CDDL exactly:

```
{ + [tag : redeemer_tag, index : uint .size 4] => [ data : plutus_data, ex_units : ex_units ] }
```

The map is keyed by `[tag, index]` tuples. Note: JS Map uses reference
equality for non-primitive keys, so lookups by tuple won't work — use
`get()` or `toArray()` helpers instead.

**Signature**

```ts
export declare class RedeemerMap
```

Added in v2.0.0

### get (method)

Look up a redeemer entry by tag and index.

**Signature**

```ts
get(tag: Redeemer.RedeemerTag, index: bigint): RedeemerValue | undefined
```

Added in v2.0.0

### toArray (method)

Convert to an array of `Redeemer` objects (convenience for consumers).

**Signature**

```ts
toArray(): ReadonlyArray<Redeemer.Redeemer>
```

Added in v2.0.0

### toJSON (method)

**Signature**

```ts
toJSON()
```

### toString (method)

**Signature**

```ts
toString(): string
```

### [Inspectable.NodeInspectSymbol] (method)

**Signature**

```ts
[Inspectable.NodeInspectSymbol](): unknown
```

### [Equal.symbol] (method)

**Signature**

```ts
[Equal.symbol](that: unknown): boolean
```

### [Hash.symbol] (method)

**Signature**

```ts
[Hash.symbol](): number
```

## RedeemerValue (class)

A redeemer map entry value: `[data, ex_units]`.

Mirrors the CDDL: `[data : plutus_data, ex_units : ex_units]`

**Signature**

```ts
export declare class RedeemerValue
```

Added in v2.0.0

### [Equal.symbol] (method)

**Signature**

```ts
[Equal.symbol](that: unknown): boolean
```

### [Hash.symbol] (method)

**Signature**

```ts
[Hash.symbol](): number
```

## Redeemers (type alias)

Union type: `RedeemerMap | RedeemerArray`

**Signature**

```ts
export type Redeemers = typeof Redeemers.Type
```

Added in v2.0.0

# parsing

## fromCBORBytes

Parse from CBOR bytes (array format).

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => RedeemerArray
```

Added in v2.0.0

## fromCBORBytesMap

Parse from CBOR bytes (map format).

**Signature**

```ts
export declare const fromCBORBytesMap: (bytes: Uint8Array, options?: CBOR.CodecOptions) => RedeemerMap
```

Added in v2.0.0

## fromCBORHex

Parse from CBOR hex string (array format).

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => RedeemerArray
```

Added in v2.0.0

## fromCBORHexMap

Parse from CBOR hex string (map format).

**Signature**

```ts
export declare const fromCBORHexMap: (hex: string, options?: CBOR.CodecOptions) => RedeemerMap
```

Added in v2.0.0

# schemas

## ArrayCDDLSchema

CDDL schema for array format: `[ + redeemer ]`

**Signature**

```ts
export declare const ArrayCDDLSchema: Schema.Array$<
  Schema.Tuple<
    [
      Schema.SchemaClass<bigint, bigint, never>,
      Schema.SchemaClass<bigint, bigint, never>,
      Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
      Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
    ]
  >
>
```

Added in v2.0.0

## CDDLSchema

Default CDDL schema (map format — Conway recommended).

**Signature**

```ts
export declare const CDDLSchema: Schema.MapFromSelf<
  Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>,
  Schema.Tuple2<
    Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
    Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
  >
>
```

Added in v2.0.0

## FromArrayCDDL

CDDL transformation for array format → `RedeemerArray`.

**Signature**

```ts
export declare const FromArrayCDDL: Schema.transformOrFail<
  Schema.Array$<
    Schema.Tuple<
      [
        Schema.SchemaClass<bigint, bigint, never>,
        Schema.SchemaClass<bigint, bigint, never>,
        Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
        Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
      ]
    >
  >,
  Schema.SchemaClass<RedeemerArray, RedeemerArray, never>,
  never
>
```

Added in v2.0.0

## FromCBORBytes

CBOR bytes schema for array format.

**Signature**

```ts
export declare const FromCBORBytes: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.transformOrFail<
    Schema.Array$<
      Schema.Tuple<
        [
          Schema.SchemaClass<bigint, bigint, never>,
          Schema.SchemaClass<bigint, bigint, never>,
          Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
          Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
        ]
      >
    >,
    Schema.SchemaClass<RedeemerArray, RedeemerArray, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORBytesMap

CBOR bytes schema for map format.

**Signature**

```ts
export declare const FromCBORBytesMap: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.transformOrFail<
    Schema.MapFromSelf<
      Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>,
      Schema.Tuple2<
        Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
        Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
      >
    >,
    Schema.SchemaClass<RedeemerMap, RedeemerMap, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex schema for array format.

**Signature**

```ts
export declare const FromCBORHex: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<
    Schema.transformOrFail<
      typeof Schema.Uint8ArrayFromSelf,
      Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
      never
    >,
    Schema.transformOrFail<
      Schema.Array$<
        Schema.Tuple<
          [
            Schema.SchemaClass<bigint, bigint, never>,
            Schema.SchemaClass<bigint, bigint, never>,
            Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
            Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
          ]
        >
      >,
      Schema.SchemaClass<RedeemerArray, RedeemerArray, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCBORHexMap

CBOR hex schema for map format.

**Signature**

```ts
export declare const FromCBORHexMap: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<
    Schema.transformOrFail<
      typeof Schema.Uint8ArrayFromSelf,
      Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
      never
    >,
    Schema.transformOrFail<
      Schema.MapFromSelf<
        Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>,
        Schema.Tuple2<
          Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
          Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
        >
      >,
      Schema.SchemaClass<RedeemerMap, RedeemerMap, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

Default CDDL transformation (map format).

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.MapFromSelf<
    Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>,
    Schema.Tuple2<
      Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
      Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
    >
  >,
  Schema.SchemaClass<RedeemerMap, RedeemerMap, never>,
  never
>
```

Added in v2.0.0

## FromMapCDDL

CDDL transformation for map format → `RedeemerMap`.

**Signature**

```ts
export declare const FromMapCDDL: Schema.transformOrFail<
  Schema.MapFromSelf<
    Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>,
    Schema.Tuple2<
      Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
      Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
    >
  >,
  Schema.SchemaClass<RedeemerMap, RedeemerMap, never>,
  never
>
```

Added in v2.0.0

## MapCDDLSchema

CDDL schema for map format: `{ + [tag, index] => [data, ex_units] }`

Uses `MapFromSelf` (not `Map`) so the Encoded type is a JS Map — matching
how `CBOR.FromBytes` represents CBOR major-type-5 maps at runtime.
This is the same pattern used by Withdrawals, Mint, MultiAsset, CostModel.

**Signature**

```ts
export declare const MapCDDLSchema: Schema.MapFromSelf<
  Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>,
  Schema.Tuple2<
    Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
    Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
  >
>
```

Added in v2.0.0

## Redeemers

Union schema for redeemers — accepts either map or array format.
Follows the Credential pattern: `Credential = Union(KeyHash, ScriptHash)`.

**Signature**

```ts
export declare const Redeemers: Schema.Union<[typeof RedeemerMap, typeof RedeemerArray]>
```

Added in v2.0.0

# utilities

## keyToString

Create a string key from a RedeemerKey for lookup convenience.

**Signature**

```ts
export declare const keyToString: ([tag, index]: RedeemerKey) => string
```

Added in v2.0.0

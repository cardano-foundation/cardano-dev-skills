---
title: Value.ts
nav_order: 186
parent: Modules
---

## Value overview

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [onlyCoin](#onlycoin)
  - [withAssets](#withassets)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [generators](#generators)
  - [arbitrary](#arbitrary)
- [model](#model)
  - [ValueCDDL (type alias)](#valuecddl-type-alias)
- [ordering](#ordering)
  - [geq](#geq)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [predicates](#predicates)
  - [hasAssets](#hasassets)
  - [is](#is)
  - [isAdaOnly](#isadaonly)
- [schemas](#schemas)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)
  - [OnlyCoin (class)](#onlycoin-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [transformation](#transformation)
  - [add](#add)
  - [getAda](#getada)
  - [getAssets](#getassets)
  - [subtract](#subtract)
- [utils](#utils)
  - [CDDLSchema](#cddlschema)
  - [Value](#value)
  - [Value (type alias)](#value-type-alias)
  - [WithAssets (class)](#withassets-class)
    - [toJSON (method)](#tojson-method-1)
    - [toString (method)](#tostring-method-1)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-1)
    - [[Equal.symbol] (method)](#equalsymbol-method-1)
    - [[Hash.symbol] (method)](#hashsymbol-method-1)

---

# constructors

## onlyCoin

Create a Value containing only ADA.

**Signature**

```ts
export declare const onlyCoin: (ada: Coin.Coin) => OnlyCoin
```

Added in v2.0.0

## withAssets

Create a Value containing ADA and native assets.

**Signature**

```ts
export declare const withAssets: (ada: Coin.Coin, assets: MultiAsset.MultiAsset) => WithAssets
```

Added in v2.0.0

# encoding

## toCBORBytes

Encode Value to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (data: Value, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORHex

Encode Value to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (data: Value, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# generators

## arbitrary

Generate a random Value.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<OnlyCoin | WithAssets>
```

Added in v2.0.0

# model

## ValueCDDL (type alias)

TypeScript type for the raw CDDL representation.
This is what gets encoded/decoded to/from CBOR.

**Signature**

```ts
export type ValueCDDL = typeof FromCDDL.Type
```

Added in v2.0.0

# ordering

## geq

Check if Value a is greater than or equal to Value b.
This means after subtracting b from a, the result would not be negative.

**Signature**

```ts
export declare const geq: (a: Value, b: Value) => boolean
```

Added in v2.0.0

# parsing

## fromCBORBytes

Parse Value from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => OnlyCoin | WithAssets
```

Added in v2.0.0

## fromCBORHex

Parse Value from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => OnlyCoin | WithAssets
```

Added in v2.0.0

# predicates

## hasAssets

Check if a Value contains native assets.

**Signature**

```ts
export declare const hasAssets: (value: Value) => value is WithAssets
```

Added in v2.0.0

## is

Check if a value is a valid Value.

**Signature**

```ts
export declare const is: (value: unknown) => value is Value
```

Added in v2.0.0

## isAdaOnly

Check if a Value contains only ADA (no native assets).

**Signature**

```ts
export declare const isAdaOnly: (value: Value) => value is OnlyCoin
```

Added in v2.0.0

# schemas

## FromCBORBytes

CBOR bytes transformation schema for Value.
Transforms between CBOR bytes and Value using CBOR encoding.

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
    Schema.Union<
      [
        typeof Schema.BigIntFromSelf,
        Schema.Tuple2<
          typeof Schema.BigIntFromSelf,
          Schema.SchemaClass<
            ReadonlyMap<any, ReadonlyMap<any, bigint>>,
            ReadonlyMap<any, ReadonlyMap<any, bigint>>,
            never
          >
        >
      ]
    >,
    Schema.SchemaClass<OnlyCoin | WithAssets, OnlyCoin | WithAssets, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for Value.
Transforms between CBOR hex string and Value using CBOR encoding.

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
      Schema.Union<
        [
          typeof Schema.BigIntFromSelf,
          Schema.Tuple2<
            typeof Schema.BigIntFromSelf,
            Schema.SchemaClass<
              ReadonlyMap<any, ReadonlyMap<any, bigint>>,
              ReadonlyMap<any, ReadonlyMap<any, bigint>>,
              never
            >
          >
        ]
      >,
      Schema.SchemaClass<OnlyCoin | WithAssets, OnlyCoin | WithAssets, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for Value as union structure.

```
value = coin / [coin, multiasset<positive_coin>]
```

This represents either:

- A single coin amount (for ADA-only values)
- An array with [coin, multiasset] (for values with native assets)

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.Union<
    [
      typeof Schema.BigIntFromSelf,
      Schema.Tuple2<
        typeof Schema.BigIntFromSelf,
        Schema.SchemaClass<
          ReadonlyMap<any, ReadonlyMap<any, bigint>>,
          ReadonlyMap<any, ReadonlyMap<any, bigint>>,
          never
        >
      >
    ]
  >,
  Schema.SchemaClass<OnlyCoin | WithAssets, OnlyCoin | WithAssets, never>,
  never
>
```

Added in v2.0.0

## OnlyCoin (class)

Schema for Value representing both ADA and native assets.

```
value = coin / [coin, multiasset<positive_coin>]
```

This can be either:

1. Just a coin amount (lovelace only)
2. A tuple of [coin, multiasset] (lovelace + native assets)

**Signature**

```ts
export declare class OnlyCoin
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

# transformation

## add

Add two Values together.
Combines ADA amounts and merges MultiAssets.

**Signature**

```ts
export declare const add: (a: Value, b: Value) => Value
```

Added in v2.0.0

## getAda

Extract the ADA amount from a Value.

**Signature**

```ts
export declare const getAda: (value: Value) => Coin.Coin
```

Added in v2.0.0

## getAssets

Extract the MultiAsset from a Value, if it exists.

**Signature**

```ts
export declare const getAssets: (value: Value) => Option.Option<MultiAsset.MultiAsset>
```

Added in v2.0.0

## subtract

Subtract Value b from Value a.
Subtracts ADA amounts and MultiAssets properly.

**Signature**

```ts
export declare const subtract: (a: Value, b: Value) => Value
```

Added in v2.0.0

# utils

## CDDLSchema

**Signature**

```ts
export declare const CDDLSchema: Schema.Union<
  [
    typeof Schema.BigIntFromSelf,
    Schema.Tuple2<
      typeof Schema.BigIntFromSelf,
      Schema.SchemaClass<ReadonlyMap<any, ReadonlyMap<any, bigint>>, ReadonlyMap<any, ReadonlyMap<any, bigint>>, never>
    >
  ]
>
```

## Value

**Signature**

```ts
export declare const Value: Schema.Union<[typeof OnlyCoin, typeof WithAssets]>
```

## Value (type alias)

**Signature**

```ts
export type Value = typeof Value.Type
```

## WithAssets (class)

**Signature**

```ts
export declare class WithAssets
```

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

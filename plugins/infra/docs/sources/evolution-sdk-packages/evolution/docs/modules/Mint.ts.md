---
title: Mint.ts
nav_order: 75
parent: Modules
---

## Mint overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [constructors](#constructors)
  - [empty](#empty)
  - [fromEntries](#fromentries)
  - [singleton](#singleton)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [lookup](#lookup)
  - [getAssetsByPolicyHex](#getassetsbypolicyhex)
  - [getByHex](#getbyhex)
- [model](#model)
  - [Mint (class)](#mint-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [predicates](#predicates)
  - [has](#has)
  - [is](#is)
  - [isEmpty](#isempty)
- [schemas](#schemas)
  - [AssetMap](#assetmap)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)
- [transformation](#transformation)
  - [get](#get)
  - [insert](#insert)
  - [policyCount](#policycount)
  - [removeAsset](#removeasset)
  - [removePolicy](#removepolicy)
- [utils](#utils)
  - [AssetMap (type alias)](#assetmap-type-alias)
  - [CDDLSchema](#cddlschema)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random Mint instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Mint>
```

Added in v2.0.0

# constructors

## empty

Create empty Mint.

**Signature**

```ts
export declare const empty: () => Mint
```

Added in v2.0.0

## fromEntries

Create Mint from entries array.

**Signature**

```ts
export declare const fromEntries: (
  entries: Array<[PolicyId.PolicyId, Array<[AssetName.AssetName, NonZeroInt64.NonZeroInt64]>]>
) => Mint
```

Added in v2.0.0

## singleton

Create Mint from a single policy and asset entry.

**Signature**

```ts
export declare const singleton: (
  policyId: PolicyId.PolicyId,
  assetName: AssetName.AssetName,
  amount: NonZeroInt64.NonZeroInt64
) => Mint
```

Added in v2.0.0

# encoding

## toCBORBytes

Encode Mint to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (mint: Mint, options?: CBOR.CodecOptions) => Uint8Array
```

Added in v2.0.0

## toCBORHex

Encode Mint to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (mint: Mint, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# lookup

## getAssetsByPolicyHex

Get the asset map for a specific policy by hex string.
Uses content-based equality (Equal.equals) to find matching PolicyId.

**Signature**

```ts
export declare const getAssetsByPolicyHex: (
  mint: Mint,
  policyIdHex: string
) => Map<AssetName.AssetName, NonZeroInt64.NonZeroInt64> | undefined
```

Added in v2.0.0

## getByHex

Get an asset amount by policy ID hex and asset name hex strings.
Convenience function for tests and lookups using hex strings.

**Signature**

```ts
export declare const getByHex: (
  mint: Mint,
  policyIdHex: string,
  assetNameHex: string
) => NonZeroInt64.NonZeroInt64 | undefined
```

Added in v2.0.0

# model

## Mint (class)

Schema for Mint representing token minting/burning operations.

```
mint = multiasset<nonZeroInt64>

The structure is: policy_id => { asset_name => nonZeroInt64 }
- Positive values represent minting
- Negative values represent burning
```

**Signature**

```ts
export declare class Mint
```

Added in v2.0.0

### toJSON (method)

Convert to JSON representation.

**Signature**

```ts
toJSON()
```

Added in v2.0.0

### toString (method)

Convert to string representation.

**Signature**

```ts
toString(): string
```

Added in v2.0.0

### [Inspectable.NodeInspectSymbol] (method)

Custom inspect for Node.js REPL.

**Signature**

```ts
[Inspectable.NodeInspectSymbol](): unknown
```

Added in v2.0.0

### [Equal.symbol] (method)

Structural equality check.

**Signature**

```ts
[Equal.symbol](that: unknown): boolean
```

Added in v2.0.0

### [Hash.symbol] (method)

**Signature**

```ts
[Hash.symbol](): number
```

Added in v2.0.0

# parsing

## fromCBORBytes

Parse Mint from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => Mint
```

Added in v2.0.0

## fromCBORHex

Parse Mint from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => Mint
```

Added in v2.0.0

# predicates

## has

Check if Mint contains a specific policy and asset.

**Signature**

```ts
export declare const has: (mint: Mint, policyId: PolicyId.PolicyId, assetName: AssetName.AssetName) => boolean
```

Added in v2.0.0

## is

Check if a value is a valid Mint.

**Signature**

```ts
export declare const is: (u: unknown, overrideOptions?: ParseOptions | number) => u is Mint
```

Added in v2.0.0

## isEmpty

Check if Mint is empty.

**Signature**

```ts
export declare const isEmpty: (mint: Mint) => boolean
```

Added in v2.0.0

# schemas

## AssetMap

Schema for inner asset map

```
(asset_name => nonZeroInt64).
```

**Signature**

```ts
export declare const AssetMap: Schema.transform<
  Schema.Array$<
    Schema.Tuple2<
      typeof AssetName.AssetName,
      Schema.Union<[Schema.refine<bigint, typeof Schema.BigInt>, Schema.refine<bigint, typeof Schema.BigInt>]>
    >
  >,
  Schema.MapFromSelf<
    Schema.SchemaClass<AssetName.AssetName, AssetName.AssetName, never>,
    Schema.SchemaClass<bigint, bigint, never>
  >
>
```

Added in v2.0.0

## FromCBORBytes

CBOR bytes transformation schema for Mint.
Transforms between CBOR bytes and Mint using CBOR encoding.

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
    Schema.SchemaClass<ReadonlyMap<any, ReadonlyMap<any, bigint>>, ReadonlyMap<any, ReadonlyMap<any, bigint>>, never>,
    Schema.SchemaClass<Mint, Mint, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for Mint.
Transforms between CBOR hex string and Mint using CBOR encoding.

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
      Schema.SchemaClass<ReadonlyMap<any, ReadonlyMap<any, bigint>>, ReadonlyMap<any, ReadonlyMap<any, bigint>>, never>,
      Schema.SchemaClass<Mint, Mint, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for Mint as map structure.

```
mint = {* policy_id => {* asset_name => nonZeroInt64}}
```

Where:

- policy_id: 28-byte Uint8Array (from CBOR byte string)
- asset_name: variable-length Uint8Array (from CBOR byte string, can be empty)
- nonZeroInt64: signed 64-bit integer (positive = mint, negative = burn, cannot be zero)

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.SchemaClass<ReadonlyMap<any, ReadonlyMap<any, bigint>>, ReadonlyMap<any, ReadonlyMap<any, bigint>>, never>,
  Schema.SchemaClass<Mint, Mint, never>,
  never
>
```

Added in v2.0.0

# transformation

## get

Get the amount for a specific policy and asset.
Uses content-based equality (Equal.equals) to find matching PolicyId and AssetName.

**Signature**

```ts
export declare const get: (
  mint: Mint,
  policyId: PolicyId.PolicyId,
  assetName: AssetName.AssetName
) => bigint | undefined
```

Added in v2.0.0

## insert

Add or update an asset in the Mint.
Uses content-based equality (Equal.equals) to find matching PolicyId and AssetName
since JavaScript Maps use reference equality by default.

**Signature**

```ts
export declare const insert: (
  mint: Mint,
  policyId: PolicyId.PolicyId,
  assetName: AssetName.AssetName,
  amount: NonZeroInt64.NonZeroInt64
) => Mint
```

Added in v2.0.0

## policyCount

Get the number of policies in the Mint.

**Signature**

```ts
export declare const policyCount: (mint: Mint) => number
```

Added in v2.0.0

## removeAsset

Remove an asset from the Mint.
Uses content-based equality (Equal.equals) to find matching PolicyId and AssetName.

**Signature**

```ts
export declare const removeAsset: (mint: Mint, policyId: PolicyId.PolicyId, assetName: AssetName.AssetName) => Mint
```

Added in v2.0.0

## removePolicy

Remove a policy from the Mint.
Uses content-based equality (Equal.equals) to find matching PolicyId.

**Signature**

```ts
export declare const removePolicy: (mint: Mint, policyId: PolicyId.PolicyId) => Mint
```

Added in v2.0.0

# utils

## AssetMap (type alias)

**Signature**

```ts
export type AssetMap = typeof AssetMap.Type
```

## CDDLSchema

**Signature**

```ts
export declare const CDDLSchema: Schema.MapFromSelf<
  typeof Schema.Uint8ArrayFromSelf,
  Schema.MapFromSelf<typeof Schema.Uint8ArrayFromSelf, typeof Schema.BigIntFromSelf>
>
```

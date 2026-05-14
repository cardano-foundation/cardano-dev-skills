---
title: Assets.ts
nav_order: 6
parent: Modules
---

## Assets overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [combining](#combining)
  - [add](#add)
  - [addByHex](#addbyhex)
  - [addLovelace](#addlovelace)
  - [filter](#filter)
  - [merge](#merge)
  - [negate](#negate)
  - [subtract](#subtract)
  - [subtractLovelace](#subtractlovelace)
  - [withLovelace](#withlovelace)
  - [withoutLovelace](#withoutlovelace)
- [constants](#constants)
  - [zero](#zero)
- [constructors](#constructors)
  - [fromAsset](#fromasset)
  - [fromHexStrings](#fromhexstrings)
  - [fromLovelace](#fromlovelace)
  - [fromRecord](#fromrecord)
  - [fromUnit](#fromunit)
  - [withMultiAsset](#withmultiasset)
- [decoding](#decoding)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [inspection](#inspection)
  - [allPositive](#allpositive)
  - [covers](#covers)
  - [getByUnit](#getbyunit)
  - [getMultiAsset](#getmultiasset)
  - [getUnits](#getunits)
  - [hasMultiAsset](#hasmultiasset)
  - [hasOnlyLovelace](#hasonlylovelace)
  - [isEmpty](#isempty)
  - [isZero](#iszero)
  - [lovelaceOf](#lovelaceof)
  - [policies](#policies)
  - [quantityOf](#quantityof)
  - [tokens](#tokens)
- [model](#model)
  - [Assets (class)](#assets-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [schemas](#schemas)
  - [CDDLSchema](#cddlschema)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)
- [transforming](#transforming)
  - [flatten](#flatten)
  - [toDict](#todict)

---

# arbitrary

## arbitrary

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Assets>
```

Added in v2.0.0

# combining

## add

Add a single asset to Assets.

**Signature**

```ts
export declare const add: (
  assets: Assets,
  policyId: PolicyId.PolicyId,
  assetName: AssetName.AssetName,
  quantity: bigint
) => Assets
```

Added in v2.0.0

## addByHex

Add a single asset to Assets using hex strings for policy ID and asset name.

**Signature**

```ts
export declare const addByHex: (assets: Assets, policyIdHex: string, assetNameHex: string, quantity: bigint) => Assets
```

Added in v2.0.0

## addLovelace

Add lovelace to existing assets. Creates new Assets with added lovelace.

**Signature**

```ts
export declare const addLovelace: (assets: Assets, additionalLovelace: bigint) => Assets
```

Added in v2.0.0

## filter

Filter assets based on a predicate.

**Signature**

```ts
export declare const filter: (assets: Assets, predicate: (unit: string, amount: bigint) => boolean) => Assets
```

Added in v2.0.0

## merge

Add two Assets together.
Combines ADA amounts and merges MultiAssets.

**Signature**

```ts
export declare const merge: (a: Assets, b: Assets) => Assets
```

Added in v2.0.0

## negate

Negate all quantities (ADA and tokens).

**Signature**

```ts
export declare const negate: (assets: Assets) => Assets
```

Added in v2.0.0

## subtract

Subtract assets (a - b). Result can have negative values.

**Signature**

```ts
export declare const subtract: (a: Assets, b: Assets) => Assets
```

Added in v2.0.0

## subtractLovelace

Subtract lovelace from existing assets. Creates new Assets with reduced lovelace.

**Signature**

```ts
export declare const subtractLovelace: (assets: Assets, lovelaceToSubtract: bigint) => Assets
```

Added in v2.0.0

## withLovelace

Create a new Assets with a different lovelace amount, keeping multiAsset.

**Signature**

```ts
export declare const withLovelace: (assets: Assets, lovelace: bigint) => Assets
```

Added in v2.0.0

## withoutLovelace

Get Assets without the ADA/Lovelace component.

**Signature**

```ts
export declare const withoutLovelace: (assets: Assets) => Assets
```

Added in v2.0.0

# constants

## zero

Empty Assets with zero ADA and no tokens.

**Signature**

```ts
export declare const zero: Assets
```

Added in v2.0.0

# constructors

## fromAsset

Create a single asset (policy + asset name + quantity) with optional ADA.

**Signature**

```ts
export declare const fromAsset: (
  policyId: PolicyId.PolicyId,
  assetName: AssetName.AssetName,
  quantity: bigint,
  lovelace?: bigint
) => Assets
```

Added in v2.0.0

## fromHexStrings

Create a single asset from hex policy ID and hex asset name strings.
This is a synchronous version using pre-validated hex strings.

**Signature**

```ts
export declare const fromHexStrings: (
  policyIdHex: string,
  assetNameHex: string,
  quantity: bigint,
  lovelace?: bigint
) => Assets
```

Added in v2.0.0

## fromLovelace

Create Assets containing only ADA/Lovelace.

**Signature**

```ts
export declare const fromLovelace: (lovelace: bigint) => Assets
```

Added in v2.0.0

## fromRecord

Create Assets from a record format (for convenience/testing).

Record format:

- `lovelace`: bigint for ADA amount
- `"<policyIdHex><assetNameHex>"`: bigint for native asset quantity
  where policyId is exactly 56 hex chars and assetName is remaining hex chars

**Signature**

```ts
export declare const fromRecord: (record: Record<string, bigint>) => Assets
```

**Example**

```ts
import * as Assets from "@evolution-sdk/evolution/Assets"

const assets = Assets.fromRecord({
  lovelace: 5_000_000n
})
```

Added in v2.0.0

## fromUnit

Create a single asset from unit string format (policyId.assetName or policyId for empty asset name).

**Signature**

```ts
export declare const fromUnit: (unit: string, quantity: bigint, lovelace?: bigint) => Eff.Effect<Assets, Error>
```

Added in v2.0.0

## withMultiAsset

Create Assets containing ADA and native tokens.

**Signature**

```ts
export declare const withMultiAsset: (lovelace: bigint, multiAsset: MultiAsset.MultiAsset) => Assets
```

Added in v2.0.0

# decoding

## fromCBORBytes

Parse Assets from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => Assets
```

Added in v2.0.0

## fromCBORHex

Parse Assets from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => Assets
```

Added in v2.0.0

# encoding

## toCBORBytes

Encode Assets to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (data: Assets, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORHex

Encode Assets to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (data: Assets, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# inspection

## allPositive

Check if all quantities are positive (lovelace >= 0, tokens > 0).
Used for validation at transaction output boundaries per CDDL:
`value = coin / [coin, multiasset<positive_coin>]`

**Signature**

```ts
export declare const allPositive: (assets: Assets) => boolean
```

Added in v2.0.0

## covers

Check if all requirements are covered by accumulated assets.
Compares lovelace and all token quantities.

**Signature**

```ts
export declare const covers: (accumulated: Assets, required: Assets) => boolean
```

Added in v2.0.0

## getByUnit

Get asset quantity by unit string.
Unit is either "lovelace" or "policyId.assetName" (hex encoded).

**Signature**

```ts
export declare const getByUnit: (assets: Assets, unit: string) => bigint
```

Added in v2.0.0

## getMultiAsset

Get the MultiAsset if present.

**Signature**

```ts
export declare const getMultiAsset: (assets: Assets) => MultiAsset.MultiAsset | undefined
```

Added in v2.0.0

## getUnits

Get all unit strings from Assets.
Returns "lovelace" plus all "policyId.assetName" strings.

**Signature**

```ts
export declare const getUnits: (assets: Assets) => Array<string>
```

Added in v2.0.0

## hasMultiAsset

Check if Assets contains native tokens.

**Signature**

```ts
export declare const hasMultiAsset: (assets: Assets) => boolean
```

Added in v2.0.0

## hasOnlyLovelace

Check if assets contain only ADA (no native tokens).

**Signature**

```ts
export declare const hasOnlyLovelace: (assets: Assets) => boolean
```

Added in v2.0.0

## isEmpty

Check if assets are empty (zero lovelace and no tokens).

**Signature**

```ts
export declare const isEmpty: (assets: Assets) => boolean
```

Added in v2.0.0

## isZero

Check if Assets is zero (no ADA and no tokens).

**Signature**

```ts
export declare const isZero: (assets: Assets) => boolean
```

Added in v2.0.0

## lovelaceOf

Extract the ADA/Lovelace amount.

**Signature**

```ts
export declare const lovelaceOf: (assets: Assets) => bigint
```

Added in v2.0.0

## policies

Get all policy IDs in the Assets.

**Signature**

```ts
export declare const policies: (assets: Assets) => Array<PolicyId.PolicyId>
```

Added in v2.0.0

## quantityOf

Get quantity of a specific asset.

**Signature**

```ts
export declare const quantityOf: (assets: Assets, policyId: PolicyId.PolicyId, assetName: AssetName.AssetName) => bigint
```

Added in v2.0.0

## tokens

Get all tokens for a specific policy.

**Signature**

```ts
export declare const tokens: (assets: Assets, policyId: PolicyId.PolicyId) => Map<AssetName.AssetName, bigint>
```

Added in v2.0.0

# model

## Assets (class)

Assets representing both ADA and native tokens.

This is a **base type** with no constraints on values.
Lovelace and token quantities can be positive, negative, or zero
to support arithmetic operations (merge, subtract, negate).

Constraints (positive values) are applied at boundaries like
`TransactionOutput` where CDDL requires `value = coin / [coin, multiasset<positive_coin>]`.

**Signature**

```ts
export declare class Assets
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

# schemas

## CDDLSchema

CDDL schema type for Assets

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

Added in v2.0.0

## FromCBORBytes

CBOR bytes transformation schema for Assets.

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
    Schema.SchemaClass<Assets, Assets, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for Assets.

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
      Schema.SchemaClass<Assets, Assets, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for Assets.

CDDL: `value = coin / [coin, multiasset<positive_coin>]`

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
  Schema.SchemaClass<Assets, Assets, never>,
  never
>
```

Added in v2.0.0

# transforming

## flatten

Flatten Assets into a list of [PolicyId, AssetName, Quantity] tuples.

**Signature**

```ts
export declare const flatten: (assets: Assets) => Array<[PolicyId.PolicyId, AssetName.AssetName, bigint]>
```

Added in v2.0.0

## toDict

Convert Assets to a nested Map structure.

**Signature**

```ts
export declare const toDict: (assets: Assets) => Map<PolicyId.PolicyId, Map<AssetName.AssetName, bigint>>
```

Added in v2.0.0

---
title: Redeemer.ts
nav_order: 109
parent: Modules
---

## Redeemer overview

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [cert](#cert)
  - [mint](#mint)
  - [reward](#reward)
  - [spend](#spend)
- [generators](#generators)
  - [arbitraryExUnits](#arbitraryexunits)
  - [arbitraryRedeemerTag](#arbitraryredeemertag)
- [model](#model)
  - [ExUnits (class)](#exunits-class)
    - [toJSON (method)](#tojson-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [Redeemer (class)](#redeemer-class)
    - [toJSON (method)](#tojson-method-1)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method-1)
    - [[Hash.symbol] (method)](#hashsymbol-method-1)
  - [RedeemerTag](#redeemertag)
- [predicates](#predicates)
  - [isCert](#iscert)
  - [isMint](#ismint)
  - [isReward](#isreward)
  - [isSpend](#isspend)
- [schemas](#schemas)
  - [CDDLSchema](#cddlschema)
  - [FromCBORBytes](#fromcborbytes)
  - [FromCBORHex](#fromcborhex)
  - [FromCDDL](#fromcddl)
- [transformation](#transformation)
  - [fromCBORBytes](#fromcborbytes-1)
  - [fromCBORHex](#fromcborhex-1)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [utilities](#utilities)
  - [integerToTag](#integertotag)
  - [tagToInteger](#tagtointeger)
  - [totalExUnits](#totalexunits)
- [utils](#utils)
  - [RedeemerTag (type alias)](#redeemertag-type-alias)
  - [arbitrary](#arbitrary)

---

# constructors

## cert

Create a cert redeemer for certificate validation.

**Signature**

```ts
export declare const cert: (index: bigint, data: PlutusData.Data, exUnits: ExUnits) => Redeemer
```

Added in v2.0.0

## mint

Create a mint redeemer for minting/burning tokens.

**Signature**

```ts
export declare const mint: (index: bigint, data: PlutusData.Data, exUnits: ExUnits) => Redeemer
```

Added in v2.0.0

## reward

Create a reward redeemer for withdrawal validation.

**Signature**

```ts
export declare const reward: (index: bigint, data: PlutusData.Data, exUnits: ExUnits) => Redeemer
```

Added in v2.0.0

## spend

Create a spend redeemer for spending UTxO inputs.

**Signature**

```ts
export declare const spend: (index: bigint, data: PlutusData.Data, exUnits: ExUnits) => Redeemer
```

Added in v2.0.0

# generators

## arbitraryExUnits

FastCheck arbitrary for generating random ExUnits values.

**Signature**

```ts
export declare const arbitraryExUnits: FastCheck.Arbitrary<ExUnits>
```

Added in v2.0.0

## arbitraryRedeemerTag

FastCheck arbitrary for generating random RedeemerTag values.

**Signature**

```ts
export declare const arbitraryRedeemerTag: FastCheck.Arbitrary<
  "vote" | "spend" | "mint" | "cert" | "reward" | "propose"
>
```

Added in v2.0.0

# model

## ExUnits (class)

Execution units for Plutus script execution.

CDDL: ex_units = [mem: uint64, steps: uint64]

**Signature**

```ts
export declare class ExUnits
```

Added in v2.0.0

### toJSON (method)

**Signature**

```ts
toJSON()
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

## Redeemer (class)

Redeemer for Plutus script execution based on Conway CDDL specification.

CDDL: redeemer = [ tag, index, data, ex_units ]
Where:

- tag: redeemer_tag (0=spend, 1=mint, 2=cert, 3=reward)
- index: uint64 (index into the respective input/output/certificate/reward array)
- data: plutus_data (the actual redeemer data passed to the script)
- ex_units: [mem: uint64, steps: uint64] (execution unit limits)

**Signature**

```ts
export declare class Redeemer
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

Hash code generation.
Only hashes tag and index for performance (minimal structure).

**Signature**

```ts
[Hash.symbol](): number
```

Added in v2.0.0

## RedeemerTag

Redeemer tag enum for different script execution contexts.

CDDL: redeemer_tag = 0 ; spend | 1 ; mint | 2 ; cert | 3 ; reward | 4 ; vote | 5 ; propose

**Signature**

```ts
export declare const RedeemerTag: Schema.Literal<["spend", "mint", "cert", "reward", "vote", "propose"]>
```

Added in v2.0.0

# predicates

## isCert

Check if a redeemer is for certificates.

**Signature**

```ts
export declare const isCert: (redeemer: Redeemer) => boolean
```

Added in v2.0.0

## isMint

Check if a redeemer is for minting/burning.

**Signature**

```ts
export declare const isMint: (redeemer: Redeemer) => boolean
```

Added in v2.0.0

## isReward

Check if a redeemer is for withdrawals.

**Signature**

```ts
export declare const isReward: (redeemer: Redeemer) => boolean
```

Added in v2.0.0

## isSpend

Check if a redeemer is for spending inputs.

**Signature**

```ts
export declare const isSpend: (redeemer: Redeemer) => boolean
```

Added in v2.0.0

# schemas

## CDDLSchema

CDDL schema for Redeemer as tuple structure.

CDDL: redeemer = [ tag, index, data, ex_units ]

**Signature**

```ts
export declare const CDDLSchema: Schema.Tuple<
  [
    Schema.SchemaClass<bigint, bigint, never>,
    Schema.SchemaClass<bigint, bigint, never>,
    Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
    Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
  ]
>
```

Added in v2.0.0

## FromCBORBytes

CBOR bytes transformation schema for Redeemer using CDDL.
Transforms between CBOR bytes and Redeemer using CDDL encoding.

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
    Schema.Tuple<
      [
        Schema.SchemaClass<bigint, bigint, never>,
        Schema.SchemaClass<bigint, bigint, never>,
        Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
        Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
      ]
    >,
    Schema.SchemaClass<Redeemer, Redeemer, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for Redeemer using CDDL.
Transforms between CBOR hex string and Redeemer using CDDL encoding.

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
      Schema.Tuple<
        [
          Schema.SchemaClass<bigint, bigint, never>,
          Schema.SchemaClass<bigint, bigint, never>,
          Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
          Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
        ]
      >,
      Schema.SchemaClass<Redeemer, Redeemer, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL transformation schema for Redeemer.

Transforms between CBOR tuple representation and Redeemer class instance.

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.Tuple<
    [
      Schema.SchemaClass<bigint, bigint, never>,
      Schema.SchemaClass<bigint, bigint, never>,
      Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>,
      Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
    ]
  >,
  Schema.SchemaClass<Redeemer, Redeemer, never>,
  never
>
```

Added in v2.0.0

# transformation

## fromCBORBytes

Decode Redeemer from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => Redeemer
```

Added in v2.0.0

## fromCBORHex

Decode Redeemer from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => Redeemer
```

Added in v2.0.0

## toCBORBytes

Encode Redeemer to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (redeemer: Redeemer, options?: CBOR.CodecOptions) => Uint8Array
```

Added in v2.0.0

## toCBORHex

Encode Redeemer to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (redeemer: Redeemer, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# utilities

## integerToTag

Helper function to convert CBOR integer to RedeemerTag string.

**Signature**

```ts
export declare const integerToTag: (value: bigint) => RedeemerTag
```

Added in v2.0.0

## tagToInteger

Helper function to convert RedeemerTag string to CBOR integer.

**Signature**

```ts
export declare const tagToInteger: (tag: RedeemerTag) => bigint
```

Added in v2.0.0

## totalExUnits

Compute total ex_units by summing over redeemers.

**Signature**

```ts
export declare const totalExUnits: (redeemers: ReadonlyArray<Redeemer>) => ExUnits
```

Added in v2.0.0

# utils

## RedeemerTag (type alias)

**Signature**

```ts
export type RedeemerTag = typeof RedeemerTag.Type
```

## arbitrary

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Redeemer>
```

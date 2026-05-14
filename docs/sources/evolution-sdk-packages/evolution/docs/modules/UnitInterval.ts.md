---
title: UnitInterval.ts
nav_order: 181
parent: Modules
---

## UnitInterval overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [constructors](#constructors)
  - [fromBigDecimal](#frombigdecimal)
- [model](#model)
  - [UnitInterval (class)](#unitinterval-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [schemas](#schemas)
  - [FromCBORBytes](#fromcborbytes)
  - [FromCBORHex](#fromcborhex)
  - [FromCDDL](#fromcddl)
- [transformation](#transformation)
  - [toBigDecimal](#tobigdecimal)
- [utils](#utils)
  - [CDDLSchema](#cddlschema)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random UnitInterval instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<UnitInterval>
```

Added in v2.0.0

# constructors

## fromBigDecimal

Create UnitInterval from BigDecimal value.

**Signature**

```ts
export declare const fromBigDecimal: (value: BigDecimal.BigDecimal) => UnitInterval
```

Added in v2.0.0

# model

## UnitInterval (class)

Schema for UnitInterval representing a fractional value between 0 and 1.

```
CDDL: unit_interval = #6.30([uint, uint])
```

A unit interval is a number in the range between 0 and 1, which
means there are two extra constraints:

```
1. numerator ≤ denominator
2. denominator > 0
```

**Signature**

```ts
export declare class UnitInterval
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

**Signature**

```ts
[Hash.symbol](): number
```

Added in v2.0.0

# schemas

## FromCBORBytes

CBOR bytes transformation schema for UnitInterval.
Transforms between Uint8Array and UnitInterval using CBOR encoding.

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
    Schema.TaggedStruct<
      "Tag",
      { tag: Schema.Literal<[30]>; value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf> }
    >,
    Schema.SchemaClass<UnitInterval, UnitInterval, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for UnitInterval.
Transforms between hex string and UnitInterval using CBOR encoding.

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
      Schema.TaggedStruct<
        "Tag",
        { tag: Schema.Literal<[30]>; value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf> }
      >,
      Schema.SchemaClass<UnitInterval, UnitInterval, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for UnitInterval following the Conway specification.

```
unit_interval = #6.30([uint, uint])
```

Transforms between CBOR tag 30 structure and UnitInterval model.

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.TaggedStruct<
    "Tag",
    { tag: Schema.Literal<[30]>; value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf> }
  >,
  Schema.SchemaClass<UnitInterval, UnitInterval, never>,
  never
>
```

Added in v2.0.0

# transformation

## toBigDecimal

Convert UnitInterval to BigDecimal value.

**Signature**

```ts
export declare const toBigDecimal: (interval: UnitInterval) => BigDecimal.BigDecimal
```

Added in v2.0.0

# utils

## CDDLSchema

**Signature**

```ts
export declare const CDDLSchema: Schema.TaggedStruct<
  "Tag",
  { tag: Schema.Literal<[30]>; value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf> }
>
```

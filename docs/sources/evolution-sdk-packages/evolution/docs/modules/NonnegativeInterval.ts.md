---
title: NonnegativeInterval.ts
nav_order: 83
parent: Modules
---

## NonnegativeInterval overview

---

<h2 class="text-delta">Table of contents</h2>

- [model](#model)
  - [NonnegativeInterval (class)](#nonnegativeinterval-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [utils](#utils)
  - [CDDLSchema](#cddlschema)
  - [FromCBORBytes](#fromcborbytes)
  - [FromCBORHex](#fromcborhex)
  - [FromCDDL](#fromcddl)
  - [arbitrary](#arbitrary)

---

# model

## NonnegativeInterval (class)

Schema for NonnegativeInterval representing a fractional value >= 0.

CDDL: nonnegative_interval = #6.30([uint, positive_int])

**Signature**

```ts
export declare class NonnegativeInterval
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

# utils

## CDDLSchema

**Signature**

```ts
export declare const CDDLSchema: Schema.TaggedStruct<
  "Tag",
  { tag: Schema.Literal<[30]>; value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf> }
>
```

## FromCBORBytes

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
    Schema.SchemaClass<NonnegativeInterval, NonnegativeInterval, never>,
    never
  >
>
```

## FromCBORHex

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
      Schema.SchemaClass<NonnegativeInterval, NonnegativeInterval, never>,
      never
    >
  >
>
```

## FromCDDL

Transform between tag(30) tuple and NonnegativeInterval model.

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.TaggedStruct<
    "Tag",
    { tag: Schema.Literal<[30]>; value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf> }
  >,
  Schema.SchemaClass<NonnegativeInterval, NonnegativeInterval, never>,
  never
>
```

## arbitrary

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<NonnegativeInterval>
```

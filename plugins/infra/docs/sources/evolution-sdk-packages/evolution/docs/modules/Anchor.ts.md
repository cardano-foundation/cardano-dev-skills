---
title: Anchor.ts
nav_order: 4
parent: Modules
---

## Anchor overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [schemas](#schemas)
  - [Anchor (class)](#anchor-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)
- [utils](#utils)
  - [CDDLSchema](#cddlschema)

---

# arbitrary

## arbitrary

FastCheck arbitrary for Anchor instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Anchor>
```

Added in v2.0.0

# encoding

## toCBORBytes

Convert an Anchor to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (anchor: Anchor, options?: CBOR.CodecOptions) => Uint8Array
```

Added in v2.0.0

## toCBORHex

Convert an Anchor to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (anchor: Anchor, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# parsing

## fromCBORBytes

Parse an Anchor from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => Anchor
```

Added in v2.0.0

## fromCBORHex

Parse an Anchor from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => Anchor
```

Added in v2.0.0

# schemas

## Anchor (class)

Schema for Anchor representing an anchor with URL and data hash.

```
anchor = [anchor_url: url, anchor_data_hash: Bytes32]
```

**Signature**

```ts
export declare class Anchor
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

## FromCBORBytes

CBOR bytes transformation schema for Anchor.

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
  Schema.transform<
    Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>,
    Schema.SchemaClass<Anchor, Anchor, never>
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for Anchor.

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
    Schema.transform<
      Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>,
      Schema.SchemaClass<Anchor, Anchor, never>
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for Anchor as tuple structure.

```
anchor = [anchor_url: url, anchor_data_hash: Bytes32]
```

**Signature**

```ts
export declare const FromCDDL: Schema.transform<
  Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>,
  Schema.SchemaClass<Anchor, Anchor, never>
>
```

Added in v2.0.0

# utils

## CDDLSchema

**Signature**

```ts
export declare const CDDLSchema: Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>
```

---
title: TransactionMetadatum.ts
nav_order: 174
parent: Modules
---

## TransactionMetadatum overview

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [array](#array)
  - [bytes](#bytes)
  - [fromEntries](#fromentries)
  - [int](#int)
  - [map](#map)
  - [text](#text)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [equality](#equality)
  - [equals](#equals)
- [model](#model)
  - [List (type alias)](#list-type-alias)
  - [Map (type alias)](#map-type-alias)
  - [TransactionMetadatum (type alias)](#transactionmetadatum-type-alias)
  - [TransactionMetadatumEncoded (type alias)](#transactionmetadatumencoded-type-alias)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [schemas](#schemas)
  - [BytesSchema](#bytesschema)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [IntSchema](#intschema)
  - [ListSchema](#listschema)
  - [MapSchema](#mapschema)
  - [TextSchema](#textschema)
  - [TransactionMetadatumSchema](#transactionmetadatumschema)
- [utils](#utils)
  - [arbitrary](#arbitrary)

---

# constructors

## array

Create an array TransactionMetadatum from an array of TransactionMetadatum values.

**Signature**

```ts
export declare const array: (value: Array<TransactionMetadatum>) => List
```

Added in v2.0.0

## bytes

Create a bytes TransactionMetadatum from a Uint8Array value.

**Signature**

```ts
export declare const bytes: (value: Uint8Array) => Uint8Array
```

Added in v2.0.0

## fromEntries

Create a map TransactionMetadatum from an array of key-value pair entries.

**Signature**

```ts
export declare const fromEntries: (entries: Array<[TransactionMetadatum, TransactionMetadatum]>) => Map
```

Added in v2.0.0

## int

Create an integer TransactionMetadatum from a bigint value.

**Signature**

```ts
export declare const int: (value: bigint) => bigint
```

Added in v2.0.0

## map

Create a map TransactionMetadatum from a Map of TransactionMetadatum key-value pairs.

**Signature**

```ts
export declare const map: (value: globalThis.Map<TransactionMetadatum, TransactionMetadatum>) => Map
```

Added in v2.0.0

## text

Create a text TransactionMetadatum from a string value.

**Signature**

```ts
export declare const text: (value: string) => string
```

Added in v2.0.0

# encoding

## toCBORBytes

Convert a TransactionMetadatum to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (data: TransactionMetadatum, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORHex

Convert a TransactionMetadatum to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (data: TransactionMetadatum, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# equality

## equals

Schema-derived structural equality for TransactionMetadatum values.
Handles maps, lists, ints, bytes, and text via the
recursive TransactionMetadatumSchema definition — no hand-rolled comparison needed.

**Signature**

```ts
export declare const equals: (a: TransactionMetadatum, b: TransactionMetadatum) => boolean
```

Added in v2.0.0

# model

## List (type alias)

TransactionMetadatumList type alias

**Signature**

```ts
export type List = ReadonlyArray<TransactionMetadatum>
```

Added in v2.0.0

## Map (type alias)

TransactionMetadatumMap type alias

**Signature**

```ts
export type Map = globalThis.Map<TransactionMetadatum, TransactionMetadatum>
```

Added in v2.0.0

## TransactionMetadatum (type alias)

Transaction metadata type definition (runtime type).

Transaction metadata supports text strings, integers, byte arrays, arrays, and maps.
Following CIP-10 standard metadata registry.

**Signature**

```ts
export type TransactionMetadatum =
  // Text string
  | string
  // Integer (runtime as bigint)
  | bigint
  // Bytes (runtime as Uint8Array)
  | Uint8Array
  // Map (using standard Map)
  | globalThis.Map<TransactionMetadatum, TransactionMetadatum>
  // Array
  | ReadonlyArray<TransactionMetadatum>
```

Added in v2.0.0

## TransactionMetadatumEncoded (type alias)

Encoded type for transaction metadata (wire format).
Based on CBOR encoding rules.

**Signature**

```ts
export type TransactionMetadatumEncoded =
  // Text string
  | string
  // Int (encoded as string)
  | string
  // Bytes (encoded as hex string)
  | string
  // Map (encoded as array of [key, value] pairs)
  | ReadonlyArray<readonly [TransactionMetadatumEncoded, TransactionMetadatumEncoded]>
  // Array
  | ReadonlyArray<TransactionMetadatumEncoded>
```

Added in v2.0.0

# parsing

## fromCBORBytes

Parse a TransactionMetadatum from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (
  bytes: Uint8Array,
  options?: CBOR.CodecOptions
) =>
  | string
  | bigint
  | Uint8Array
  | globalThis.Map<TransactionMetadatum, TransactionMetadatum>
  | readonly TransactionMetadatum[]
```

Added in v2.0.0

## fromCBORHex

Parse a TransactionMetadatum from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (
  hex: string,
  options?: CBOR.CodecOptions
) =>
  | string
  | bigint
  | Uint8Array
  | globalThis.Map<TransactionMetadatum, TransactionMetadatum>
  | readonly TransactionMetadatum[]
```

Added in v2.0.0

# schemas

## BytesSchema

Schema for TransactionMetadatum bytes type

**Signature**

```ts
export declare const BytesSchema: Schema.Schema<Uint8Array, string, never>
```

Added in v2.0.0

## FromCBORBytes

Schema transformer for TransactionMetadatum from CBOR bytes.

Uses Schema.typeSchema(TransactionMetadatumSchema) because CBOR.FromBytes
returns runtime types (bigint, Uint8Array, Map), not encoded types.

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
  Schema.SchemaClass<
    | string
    | bigint
    | Uint8Array
    | globalThis.Map<TransactionMetadatum, TransactionMetadatum>
    | readonly TransactionMetadatum[],
    | string
    | bigint
    | Uint8Array
    | globalThis.Map<TransactionMetadatum, TransactionMetadatum>
    | readonly TransactionMetadatum[],
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

Schema transformer for TransactionMetadatum from CBOR hex string.

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
    Schema.SchemaClass<
      | string
      | bigint
      | Uint8Array
      | globalThis.Map<TransactionMetadatum, TransactionMetadatum>
      | readonly TransactionMetadatum[],
      | string
      | bigint
      | Uint8Array
      | globalThis.Map<TransactionMetadatum, TransactionMetadatum>
      | readonly TransactionMetadatum[],
      never
    >
  >
>
```

Added in v2.0.0

## IntSchema

Schema for TransactionMetadatum integer type

**Signature**

```ts
export declare const IntSchema: Schema.refine<bigint, typeof Schema.BigInt>
```

Added in v2.0.0

## ListSchema

Schema for TransactionMetadatum list type

**Signature**

```ts
export declare const ListSchema: Schema.Array$<Schema.suspend<TransactionMetadatum, TransactionMetadatumEncoded, never>>
```

Added in v2.0.0

## MapSchema

Schema for TransactionMetadatum map type

**Signature**

```ts
export declare const MapSchema: Schema.transform<
  Schema.Array$<
    Schema.Tuple2<
      Schema.suspend<TransactionMetadatum, TransactionMetadatumEncoded, never>,
      Schema.suspend<TransactionMetadatum, TransactionMetadatumEncoded, never>
    >
  >,
  Schema.MapFromSelf<
    Schema.SchemaClass<TransactionMetadatum, TransactionMetadatum, never>,
    Schema.SchemaClass<TransactionMetadatum, TransactionMetadatum, never>
  >
>
```

Added in v2.0.0

## TextSchema

Schema for TransactionMetadatum string type

**Signature**

```ts
export declare const TextSchema: Schema.SchemaClass<string, string, never>
```

Added in v2.0.0

## TransactionMetadatumSchema

Union schema for all types of transaction metadata.

**Signature**

```ts
export declare const TransactionMetadatumSchema: Schema.Union<
  [
    Schema.transform<
      Schema.Array$<
        Schema.Tuple2<
          Schema.suspend<TransactionMetadatum, TransactionMetadatumEncoded, never>,
          Schema.suspend<TransactionMetadatum, TransactionMetadatumEncoded, never>
        >
      >,
      Schema.MapFromSelf<
        Schema.SchemaClass<TransactionMetadatum, TransactionMetadatum, never>,
        Schema.SchemaClass<TransactionMetadatum, TransactionMetadatum, never>
      >
    >,
    Schema.Array$<Schema.suspend<TransactionMetadatum, TransactionMetadatumEncoded, never>>,
    Schema.refine<bigint, typeof Schema.BigInt>,
    Schema.Schema<Uint8Array, string, never>,
    Schema.SchemaClass<string, string, never>
  ]
>
```

Added in v2.0.0

# utils

## arbitrary

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<TransactionMetadatum>
```

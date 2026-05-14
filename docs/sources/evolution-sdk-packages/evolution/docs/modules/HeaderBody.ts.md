---
title: HeaderBody.ts
nav_order: 65
parent: Modules
---

## HeaderBody overview

---

<h2 class="text-delta">Table of contents</h2>

- [conversion](#conversion)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [model](#model)
  - [HeaderBody (class)](#headerbody-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [predicates](#predicates)
  - [isHeaderBody](#isheaderbody)
- [schemas](#schemas)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)
- [testing](#testing)
  - [arbitrary](#arbitrary)

---

# conversion

## fromCBORBytes

Convert CBOR bytes to HeaderBody

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => HeaderBody
```

Added in v2.0.0

## fromCBORHex

Convert CBOR hex string to HeaderBody

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => HeaderBody
```

Added in v2.0.0

## toCBORBytes

Convert HeaderBody to CBOR bytes

**Signature**

```ts
export declare const toCBORBytes: (headerBody: HeaderBody, options?: CBOR.CodecOptions) => Uint8Array
```

Added in v2.0.0

## toCBORHex

Convert HeaderBody to CBOR hex string

**Signature**

```ts
export declare const toCBORHex: (headerBody: HeaderBody, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# model

## HeaderBody (class)

Schema for HeaderBody representing a block header body.
header_body = [
block_number : uint64,
slot : uint64,
prev_hash : block_header_hash / null,
issuer_vkey : vkey,
vrf_vkey : vrf_vkey,
vrf_result : vrf_cert,
block_body_size : uint32,
block_body_hash : block_body_hash,
operational_cert : operational_cert,
protocol_version : protocol_version
]

**Signature**

```ts
export declare class HeaderBody
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

# predicates

## isHeaderBody

Check if the given value is a valid HeaderBody.

**Signature**

```ts
export declare const isHeaderBody: (u: unknown, overrideOptions?: ParseOptions | number) => u is HeaderBody
```

Added in v2.0.0

# schemas

## FromCBORBytes

CBOR bytes transformation schema for HeaderBody.

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
        typeof Schema.BigIntFromSelf,
        typeof Schema.BigIntFromSelf,
        Schema.NullOr<typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.Uint8ArrayFromSelf,
        typeof Schema.Uint8ArrayFromSelf,
        Schema.Tuple2<typeof Schema.Uint8ArrayFromSelf, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.BigIntFromSelf,
        typeof Schema.Uint8ArrayFromSelf,
        Schema.Tuple<
          [
            typeof Schema.Uint8ArrayFromSelf,
            typeof Schema.BigIntFromSelf,
            typeof Schema.BigIntFromSelf,
            typeof Schema.Uint8ArrayFromSelf
          ]
        >,
        Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
      ]
    >,
    Schema.SchemaClass<HeaderBody, HeaderBody, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for HeaderBody.

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
          typeof Schema.BigIntFromSelf,
          typeof Schema.BigIntFromSelf,
          Schema.NullOr<typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.Uint8ArrayFromSelf,
          typeof Schema.Uint8ArrayFromSelf,
          Schema.Tuple2<typeof Schema.Uint8ArrayFromSelf, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.BigIntFromSelf,
          typeof Schema.Uint8ArrayFromSelf,
          Schema.Tuple<
            [
              typeof Schema.Uint8ArrayFromSelf,
              typeof Schema.BigIntFromSelf,
              typeof Schema.BigIntFromSelf,
              typeof Schema.Uint8ArrayFromSelf
            ]
          >,
          Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
        ]
      >,
      Schema.SchemaClass<HeaderBody, HeaderBody, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for HeaderBody.
header_body = [
block_number : uint64,
slot : uint64,
prev_hash : block_header_hash / null,
issuer_vkey : vkey,
vrf_vkey : vrf_vkey,
vrf_result : vrf_cert,
block_body_size : uint32,
block_body_hash : block_body_hash,
operational_cert : operational_cert,
protocol_version : protocol_version
]

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.Tuple<
    [
      typeof Schema.BigIntFromSelf,
      typeof Schema.BigIntFromSelf,
      Schema.NullOr<typeof Schema.Uint8ArrayFromSelf>,
      typeof Schema.Uint8ArrayFromSelf,
      typeof Schema.Uint8ArrayFromSelf,
      Schema.Tuple2<typeof Schema.Uint8ArrayFromSelf, typeof Schema.Uint8ArrayFromSelf>,
      typeof Schema.BigIntFromSelf,
      typeof Schema.Uint8ArrayFromSelf,
      Schema.Tuple<
        [
          typeof Schema.Uint8ArrayFromSelf,
          typeof Schema.BigIntFromSelf,
          typeof Schema.BigIntFromSelf,
          typeof Schema.Uint8ArrayFromSelf
        ]
      >,
      Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
    ]
  >,
  Schema.SchemaClass<HeaderBody, HeaderBody, never>,
  never
>
```

Added in v2.0.0

# testing

## arbitrary

FastCheck arbitrary for generating random HeaderBody instances

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<HeaderBody>
```

Added in v2.0.0

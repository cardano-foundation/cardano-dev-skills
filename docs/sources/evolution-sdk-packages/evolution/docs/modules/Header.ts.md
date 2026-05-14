---
title: Header.ts
nav_order: 64
parent: Modules
---

## Header overview

Header module based on Conway CDDL specification

CDDL: header = [header_body, body_signature : kes_signature]

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [model](#model)
  - [Header (class)](#header-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [predicates](#predicates)
  - [isHeader](#isheader)
- [schemas](#schemas)
  - [FromBytes](#frombytes)
  - [FromCDDL](#fromcddl)
  - [FromHex](#fromhex)

---

# encoding

## toCBORBytes

Convert a Header to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (header: Header, options?: CBOR.CodecOptions) => Uint8Array
```

Added in v2.0.0

## toCBORHex

Convert a Header to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (header: Header, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# model

## Header (class)

Header implementation using HeaderBody and KesSignature

CDDL: header = [header_body, body_signature : kes_signature]

**Signature**

```ts
export declare class Header
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

# parsing

## fromCBORBytes

Parse a Header from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => Header
```

Added in v2.0.0

## fromCBORHex

Parse a Header from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => Header
```

Added in v2.0.0

# predicates

## isHeader

Predicate to check if a value is a Header instance.

**Signature**

```ts
export declare const isHeader: (value: unknown) => value is Header
```

Added in v2.0.0

# schemas

## FromBytes

CBOR bytes transformation schema for Header.

**Signature**

```ts
export declare const FromBytes: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.transformOrFail<
    Schema.Tuple2<
      Schema.SchemaClass<
        readonly [
          bigint,
          bigint,
          any,
          any,
          any,
          readonly [any, any],
          bigint,
          any,
          readonly [any, bigint, bigint, any],
          readonly [bigint, bigint]
        ],
        readonly [
          bigint,
          bigint,
          any,
          any,
          any,
          readonly [any, any],
          bigint,
          any,
          readonly [any, bigint, bigint, any],
          readonly [bigint, bigint]
        ],
        never
      >,
      typeof Schema.Uint8ArrayFromSelf
    >,
    Schema.SchemaClass<Header, Header, never>,
    never
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for Header.
header = [header_body, body_signature : kes_signature]

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.Tuple2<
    Schema.SchemaClass<
      readonly [
        bigint,
        bigint,
        any,
        any,
        any,
        readonly [any, any],
        bigint,
        any,
        readonly [any, bigint, bigint, any],
        readonly [bigint, bigint]
      ],
      readonly [
        bigint,
        bigint,
        any,
        any,
        any,
        readonly [any, any],
        bigint,
        any,
        readonly [any, bigint, bigint, any],
        readonly [bigint, bigint]
      ],
      never
    >,
    typeof Schema.Uint8ArrayFromSelf
  >,
  Schema.SchemaClass<Header, Header, never>,
  never
>
```

Added in v2.0.0

## FromHex

CBOR hex transformation schema for Header.

**Signature**

```ts
export declare const FromHex: (
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
      Schema.Tuple2<
        Schema.SchemaClass<
          readonly [
            bigint,
            bigint,
            any,
            any,
            any,
            readonly [any, any],
            bigint,
            any,
            readonly [any, bigint, bigint, any],
            readonly [bigint, bigint]
          ],
          readonly [
            bigint,
            bigint,
            any,
            any,
            any,
            readonly [any, any],
            bigint,
            any,
            readonly [any, bigint, bigint, any],
            readonly [bigint, bigint]
          ],
          never
        >,
        typeof Schema.Uint8ArrayFromSelf
      >,
      Schema.SchemaClass<Header, Header, never>,
      never
    >
  >
>
```

Added in v2.0.0

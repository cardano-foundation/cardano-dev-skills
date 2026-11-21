---
title: Url.ts
nav_order: 184
parent: Modules
---

## Url overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [Url (class)](#url-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isUrl](#isurl)
- [utils](#utils)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random Url instances.

**Signature**

```ts
export declare const arbitrary: Arbitrary<Url>
```

Added in v2.0.0

# encoding

## toBytes

Encode Url to bytes.

**Signature**

```ts
export declare const toBytes: (url: Url) => any
```

Added in v2.0.0

## toHex

Encode Url to hex string.

**Signature**

```ts
export declare const toHex: (url: Url) => string
```

Added in v2.0.0

# model

## Url (class)

Schema for Url representing URLs as branded text.
url = text .size (0..128)

**Signature**

```ts
export declare class Url
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

# parsing

## fromBytes

Parse Url from bytes.

**Signature**

```ts
export declare const fromBytes: (bytes: Uint8Array) => Url
```

Added in v2.0.0

## fromHex

Parse Url from hex string.

**Signature**

```ts
export declare const fromHex: (hex: string) => Url
```

Added in v2.0.0

# predicates

## isUrl

Check if the given value is a valid Url

**Signature**

```ts
export declare const isUrl: (u: unknown, overrideOptions?: ParseOptions | number) => u is Url
```

Added in v2.0.0

# utils

## FromBytes

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.transform<
    Schema.transform<typeof Schema.Uint8ArrayFromSelf, typeof Schema.String>,
    Schema.refine<string, typeof Schema.String>
  >,
  typeof Url
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<
    Schema.transform<
      Schema.transform<typeof Schema.Uint8ArrayFromSelf, typeof Schema.String>,
      Schema.refine<string, typeof Schema.String>
    >,
    typeof Url
  >
>
```

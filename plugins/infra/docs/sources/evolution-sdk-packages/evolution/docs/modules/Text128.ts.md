---
title: Text128.ts
nav_order: 167
parent: Modules
---

## Text128 overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [constants](#constants)
  - [TEXT128_MIN_LENGTH](#text128_min_length)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isText128](#istext128)
- [schemas](#schemas)
  - [Text128](#text128)
- [utils](#utils)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)
  - [TEXT128_MAX_LENGTH](#text128_max_length)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random Text128 instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<string>
```

Added in v2.0.0

# constants

## TEXT128_MIN_LENGTH

Constants for Text128 validation.
text .size (0 .. 128)

**Signature**

```ts
export declare const TEXT128_MIN_LENGTH: 0
```

Added in v2.0.0

# encoding

## toBytes

Encode Text128 to bytes (unsafe)

**Signature**

```ts
export declare const toBytes: (a: string, overrideOptions?: ParseOptions) => any
```

Added in v2.0.0

## toHex

Encode Text128 to hex string (unsafe)

**Signature**

```ts
export declare const toHex: (a: string, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# parsing

## fromBytes

Parse Text128 from bytes (unsafe)

**Signature**

```ts
export declare const fromBytes: (i: any, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

## fromHex

Parse Text128 from hex string (unsafe)

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# predicates

## isText128

Check if the given value is a valid Text128

**Signature**

```ts
export declare const isText128: (u: unknown, overrideOptions?: ParseOptions | number) => u is string
```

Added in v2.0.0

# schemas

## Text128

Schema for Text128 representing a variable-length text string (0-128 chars).
text .size (0 .. 128)
Follows the Conway-era CDDL specification.

**Signature**

```ts
export declare const Text128: Schema.refine<string, typeof Schema.String>
```

Added in v2.0.0

# utils

## FromBytes

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.transform<typeof Schema.Uint8ArrayFromSelf, typeof Schema.String>,
  Schema.refine<string, typeof Schema.String>
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<
    Schema.transform<typeof Schema.Uint8ArrayFromSelf, typeof Schema.String>,
    Schema.refine<string, typeof Schema.String>
  >
>
```

## TEXT128_MAX_LENGTH

**Signature**

```ts
export declare const TEXT128_MAX_LENGTH: 128
```

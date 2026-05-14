---
title: DnsName.ts
nav_order: 54
parent: Modules
---

## DnsName overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [DnsName](#dnsname)
  - [DnsName (type alias)](#dnsname-type-alias)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isDnsName](#isdnsname)
- [utils](#utils)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random DnsName instances.

**Signature**

```ts
export declare const arbitrary: Arbitrary<string & Brand<"DnsName">>
```

Added in v2.0.0

# encoding

## toBytes

Encode DnsName to bytes.

**Signature**

```ts
export declare const toBytes: (a: string & Brand<"DnsName">, overrideOptions?: ParseOptions) => any
```

Added in v2.0.0

## toHex

Encode DnsName to hex string.

**Signature**

```ts
export declare const toHex: (a: string & Brand<"DnsName">, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# model

## DnsName

Schema for DnsName with DNS-specific validation.
dns_name = text .size (0 .. 128)

**Signature**

```ts
export declare const DnsName: Schema.brand<Schema.refine<string, typeof Schema.String>, "DnsName">
```

Added in v2.0.0

## DnsName (type alias)

Type alias for DnsName.

**Signature**

```ts
export type DnsName = typeof DnsName.Type
```

Added in v2.0.0

# parsing

## fromBytes

Parse DnsName from bytes.

**Signature**

```ts
export declare const fromBytes: (i: any, overrideOptions?: ParseOptions) => string & Brand<"DnsName">
```

Added in v2.0.0

## fromHex

Parse DnsName from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => string & Brand<"DnsName">
```

Added in v2.0.0

# predicates

## isDnsName

Check if the given value is a valid DnsName

**Signature**

```ts
export declare const isDnsName: (u: unknown, overrideOptions?: ParseOptions | number) => u is string & Brand<"DnsName">
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
  Schema.brand<Schema.refine<string, typeof Schema.String>, "DnsName">
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.transform<
    Schema.Schema<Uint8Array, string, never>,
    Schema.transform<
      Schema.transform<typeof Schema.Uint8ArrayFromSelf, typeof Schema.String>,
      Schema.refine<string, typeof Schema.String>
    >
  >,
  Schema.brand<Schema.refine<string, typeof Schema.String>, "DnsName">
>
```

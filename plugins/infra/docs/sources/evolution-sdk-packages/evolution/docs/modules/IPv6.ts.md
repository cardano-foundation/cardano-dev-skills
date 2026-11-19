---
title: IPv6.ts
nav_order: 68
parent: Modules
---

## IPv6 overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isIPv6](#isipv6)
- [schemas](#schemas)
  - [IPv6 (class)](#ipv6-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [utils](#utils)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random IPv6 instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<IPv6>
```

Added in v2.0.0

# encoding

## toBytes

Encode IPv6 to bytes.

**Signature**

```ts
export declare const toBytes: (a: IPv6, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode IPv6 to hex string.

**Signature**

```ts
export declare const toHex: (a: IPv6, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# parsing

## fromBytes

Parse IPv6 from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => IPv6
```

Added in v2.0.0

## fromHex

Parse IPv6 from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => IPv6
```

Added in v2.0.0

# predicates

## isIPv6

Predicate for IPv6 instances

**Signature**

```ts
export declare const isIPv6: (u: unknown, overrideOptions?: ParseOptions | number) => u is IPv6
```

Added in v2.0.0

# schemas

## IPv6 (class)

IPv6 model stored as 16 raw bytes (network byte order).

**Signature**

```ts
export declare class IPv6
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

# utils

## FromBytes

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<IPv6, IPv6, never>
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<IPv6, IPv6, never>>
>
```

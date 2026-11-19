---
title: PoolKeyHash.ts
nav_order: 99
parent: Modules
---

## PoolKeyHash overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBech32](#tobech32)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [PoolKeyHash (class)](#poolkeyhash-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromBech32](#frombech32)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [schemas](#schemas)
  - [FromBech32](#frombech32-1)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random PoolKeyHash instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<PoolKeyHash>
```

Added in v2.0.0

# encoding

## toBech32

Encode PoolKeyHash to bech32 string (pool1...).

**Signature**

```ts
export declare const toBech32: (a: PoolKeyHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

## toBytes

Encode PoolKeyHash to bytes.

**Signature**

```ts
export declare const toBytes: (a: PoolKeyHash, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode PoolKeyHash to hex string.

**Signature**

```ts
export declare const toHex: (a: PoolKeyHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# model

## PoolKeyHash (class)

PoolKeyHash as a TaggedClass representing a stake pool's verification key hash.
pool_keyhash = hash28

**Signature**

```ts
export declare class PoolKeyHash
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

## fromBech32

Parse PoolKeyHash from bech32 string (pool1...).

**Signature**

```ts
export declare const fromBech32: (i: string, overrideOptions?: ParseOptions) => PoolKeyHash
```

Added in v2.0.0

## fromBytes

Parse PoolKeyHash from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => PoolKeyHash
```

Added in v2.0.0

## fromHex

Parse PoolKeyHash from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => PoolKeyHash
```

Added in v2.0.0

# schemas

## FromBech32

Schema transformer from bech32 string (pool1...) to PoolKeyHash.

**Signature**

```ts
export declare const FromBech32: Schema.transformOrFail<
  typeof Schema.String,
  Schema.SchemaClass<PoolKeyHash, PoolKeyHash, never>,
  never
>
```

Added in v2.0.0

## FromBytes

Schema transformer from bytes to PoolKeyHash.

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<PoolKeyHash, PoolKeyHash, never>
>
```

Added in v2.0.0

## FromHex

Schema transformer from hex string to PoolKeyHash.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<
    Schema.SchemaClass<Uint8Array, Uint8Array, never>,
    Schema.SchemaClass<PoolKeyHash, PoolKeyHash, never>
  >
>
```

Added in v2.0.0

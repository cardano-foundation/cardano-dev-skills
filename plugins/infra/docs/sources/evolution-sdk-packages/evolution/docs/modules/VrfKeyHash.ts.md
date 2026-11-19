---
title: VrfKeyHash.ts
nav_order: 190
parent: Modules
---

## VrfKeyHash overview

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
- [schemas](#schemas)
  - [VrfKeyHash (class)](#vrfkeyhash-class)
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

FastCheck arbitrary for generating random VrfKeyHash instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<VrfKeyHash>
```

Added in v2.0.0

# encoding

## toBytes

Encode VrfKeyHash to raw bytes.

**Signature**

```ts
export declare const toBytes: (a: VrfKeyHash, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode VrfKeyHash to hex string.

**Signature**

```ts
export declare const toHex: (a: VrfKeyHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# parsing

## fromBytes

Parse VrfKeyHash from raw bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => VrfKeyHash
```

Added in v2.0.0

## fromHex

Parse VrfKeyHash from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => VrfKeyHash
```

Added in v2.0.0

# schemas

## VrfKeyHash (class)

VrfKeyHash is a 32-byte hash representing a VRF verification key.
vrf_keyhash = Bytes32

**Signature**

```ts
export declare class VrfKeyHash
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
  Schema.SchemaClass<VrfKeyHash, VrfKeyHash, never>
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<VrfKeyHash, VrfKeyHash, never>>
>
```

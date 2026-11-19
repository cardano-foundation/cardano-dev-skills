---
title: AuxiliaryDataHash.ts
nav_order: 8
parent: Modules
---

## AuxiliaryDataHash overview

Auxiliary Data Hash module - provides an alias for Bytes32 specialized for auxiliary data hashing.

In Cardano, auxiliary_data_hash = Bytes32, representing a 32-byte hash
used for auxiliary data (metadata) attached to transactions.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [AuxiliaryDataHash (class)](#auxiliarydatahash-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isAuxiliaryDataHash](#isauxiliarydatahash)
- [utils](#utils)
  - [BytesSchema](#bytesschema)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)
  - [HexSchema](#hexschema)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random AuxiliaryDataHash instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<AuxiliaryDataHash>
```

Added in v2.0.0

# encoding

## toBytes

Encode AuxiliaryDataHash to bytes.

**Signature**

```ts
export declare const toBytes: (a: AuxiliaryDataHash, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode AuxiliaryDataHash to hex string.

**Signature**

```ts
export declare const toHex: (a: AuxiliaryDataHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# model

## AuxiliaryDataHash (class)

Schema for AuxiliaryDataHash representing auxiliary data hashes.
auxiliary_data_hash = Bytes32

**Signature**

```ts
export declare class AuxiliaryDataHash
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

## fromBytes

Parse AuxiliaryDataHash from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => AuxiliaryDataHash
```

Added in v2.0.0

## fromHex

Parse AuxiliaryDataHash from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => AuxiliaryDataHash
```

Added in v2.0.0

# predicates

## isAuxiliaryDataHash

Check if the given value is a valid AuxiliaryDataHash

**Signature**

```ts
export declare const isAuxiliaryDataHash: (
  u: unknown,
  overrideOptions?: ParseOptions | number
) => u is AuxiliaryDataHash
```

Added in v2.0.0

# utils

## BytesSchema

**Signature**

```ts
export declare const BytesSchema: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<AuxiliaryDataHash, AuxiliaryDataHash, never>
>
```

## FromBytes

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<AuxiliaryDataHash, AuxiliaryDataHash, never>
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<
    Schema.SchemaClass<Uint8Array, Uint8Array, never>,
    Schema.SchemaClass<AuxiliaryDataHash, AuxiliaryDataHash, never>
  >
>
```

## HexSchema

**Signature**

```ts
export declare const HexSchema: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<
    Schema.SchemaClass<Uint8Array, Uint8Array, never>,
    Schema.SchemaClass<AuxiliaryDataHash, AuxiliaryDataHash, never>
  >
>
```

---
title: BlockHeaderHash.ts
nav_order: 16
parent: Modules
---

## BlockHeaderHash overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [BlockHeaderHash (class)](#blockheaderhash-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isBlockHeaderHash](#isblockheaderhash)
- [schemas](#schemas)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random BlockHeaderHash instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<BlockHeaderHash>
```

Added in v2.0.0

# encoding

## toBytes

Encode BlockHeaderHash to bytes.

**Signature**

```ts
export declare const toBytes: (a: BlockHeaderHash, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode BlockHeaderHash to hex string.

**Signature**

```ts
export declare const toHex: (a: BlockHeaderHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# model

## BlockHeaderHash (class)

Schema for BlockHeaderHash representing a block header hash.
block_header_hash = Bytes32
Follows the Conway-era CDDL specification.

**Signature**

```ts
export declare class BlockHeaderHash
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

Parse BlockHeaderHash from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => BlockHeaderHash
```

Added in v2.0.0

## fromHex

Parse BlockHeaderHash from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => BlockHeaderHash
```

Added in v2.0.0

# predicates

## isBlockHeaderHash

Check if the given value is a valid BlockHeaderHash

**Signature**

```ts
export declare const isBlockHeaderHash: (u: unknown, overrideOptions?: ParseOptions | number) => u is BlockHeaderHash
```

Added in v2.0.0

# schemas

## FromBytes

Schema for transforming between Uint8Array and BlockHeaderHash.

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<BlockHeaderHash, BlockHeaderHash, never>
>
```

Added in v2.0.0

## FromHex

Schema for transforming between hex string and BlockHeaderHash.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<
    Schema.SchemaClass<Uint8Array, Uint8Array, never>,
    Schema.SchemaClass<BlockHeaderHash, BlockHeaderHash, never>
  >
>
```

Added in v2.0.0

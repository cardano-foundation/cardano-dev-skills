---
title: VKey.ts
nav_order: 187
parent: Modules
---

## VKey overview

---

<h2 class="text-delta">Table of contents</h2>

- [cryptography](#cryptography)
  - [fromPrivateKey](#fromprivatekey)
  - [verify](#verify)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isVKey](#isvkey)
- [schemas](#schemas)
  - [VKey (class)](#vkey-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [testing](#testing)
  - [arbitrary](#arbitrary)
- [utils](#utils)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# cryptography

## fromPrivateKey

Create a VKey from a PrivateKey (sync version that throws VKeyError).
For extended keys (64 bytes), uses CML-compatible Ed25519-BIP32 algorithm.
For normal keys (32 bytes), uses standard Ed25519.

**Signature**

```ts
export declare const fromPrivateKey: (privateKey: PrivateKey.PrivateKey) => VKey
```

Added in v2.0.0

## verify

Verify a signature against a message using this verification key.

**Signature**

```ts
export declare const verify: (vkey: VKey, message: Uint8Array, signature: Uint8Array) => boolean
```

Added in v2.0.0

# encoding

## toBytes

Convert a VKey to raw bytes.

**Signature**

```ts
export declare const toBytes: (a: VKey, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Convert a VKey to a hex string.

**Signature**

```ts
export declare const toHex: (a: VKey, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# parsing

## fromBytes

Parse a VKey from raw bytes.
Expects exactly 32 bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => VKey
```

Added in v2.0.0

## fromHex

Parse a VKey from a hex string.
Expects exactly 64 hex characters (32 bytes).

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => VKey
```

Added in v2.0.0

# predicates

## isVKey

Check if the given value is a valid VKey

**Signature**

```ts
export declare const isVKey: (u: unknown, overrideOptions?: ParseOptions | number) => u is VKey
```

Added in v2.0.0

# schemas

## VKey (class)

Schema for VKey representing a verification key.
vkey = bytes .size 32
Follows the Conway-era CDDL specification.

**Signature**

```ts
export declare class VKey
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

# testing

## arbitrary

FastCheck arbitrary for generating random VKey instances.
Used for property-based testing to generate valid test data.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<VKey>
```

Added in v2.0.0

# utils

## FromBytes

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<VKey, VKey, never>
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<VKey, VKey, never>>
>
```

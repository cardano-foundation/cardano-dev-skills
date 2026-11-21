---
title: Bip32PublicKey.ts
nav_order: 13
parent: Modules
---

## Bip32PublicKey overview

---

<h2 class="text-delta">Table of contents</h2>

- [accessors](#accessors)
  - [chainCode](#chaincode)
  - [publicKey](#publickey)
- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [derivation](#derivation)
  - [deriveChild](#derivechild)
- [either](#either)
  - [Either (namespace)](#either-namespace)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
  - [toRawBytes](#torawbytes)
- [errors](#errors)
  - [Bip32PublicKeyError (class)](#bip32publickeyerror-class)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [schemas](#schemas)
  - [Bip32PublicKey (class)](#bip32publickey-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# accessors

## chainCode

Get the chain code.

**Signature**

```ts
export declare const chainCode: (bip32PublicKey: Bip32PublicKey) => Uint8Array
```

Added in v2.0.0

## publicKey

Get the public key bytes.

**Signature**

```ts
export declare const publicKey: (bip32PublicKey: Bip32PublicKey) => Uint8Array
```

Added in v2.0.0

# arbitrary

## arbitrary

FastCheck arbitrary for generating random Bip32PublicKey instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Bip32PublicKey>
```

Added in v2.0.0

# derivation

## deriveChild

Derive a child public key using the specified index (soft derivation only).

**Signature**

```ts
export declare const deriveChild: (bip32PublicKey: Bip32PublicKey, index: number) => Bip32PublicKey
```

Added in v2.0.0

# either

## Either (namespace)

Either-based error handling variants for functions that can fail.

Added in v2.0.0

# encoding

## toBytes

Convert a Bip32PublicKey to raw bytes (64 bytes).

**Signature**

```ts
export declare const toBytes: (a: Bip32PublicKey, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Convert a Bip32PublicKey to hex string.

**Signature**

```ts
export declare const toHex: (a: Bip32PublicKey, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

## toRawBytes

Convert a Bip32PublicKey to raw public key bytes (32 bytes only).

**Signature**

```ts
export declare const toRawBytes: (bip32PublicKey: Bip32PublicKey) => Uint8Array
```

Added in v2.0.0

# errors

## Bip32PublicKeyError (class)

Error class for Bip32PublicKey related operations.

**Signature**

```ts
export declare class Bip32PublicKeyError
```

Added in v2.0.0

# parsing

## fromBytes

Create a BIP32 public key from public key and chain code bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => Bip32PublicKey
```

Added in v2.0.0

## fromHex

Parse Bip32PublicKey from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => Bip32PublicKey
```

Added in v2.0.0

# schemas

## Bip32PublicKey (class)

Schema for Bip32PublicKey representing a BIP32-Ed25519 extended public key.
Always 64 bytes: 32-byte public key + 32-byte chaincode.
Follows BIP32-Ed25519 hierarchical deterministic key derivation.
Supports soft derivation only (hardened derivation requires private key).

**Signature**

```ts
export declare class Bip32PublicKey
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

## FromBytes

Schema for transforming between Uint8Array and Bip32PublicKey.

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<Bip32PublicKey, Bip32PublicKey, never>
>
```

Added in v2.0.0

## FromHex

Schema for transforming between hex string and Bip32PublicKey.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<
    Schema.SchemaClass<Uint8Array, Uint8Array, never>,
    Schema.SchemaClass<Bip32PublicKey, Bip32PublicKey, never>
  >
>
```

Added in v2.0.0

---
title: cose/Key.ts
nav_order: 42
parent: Modules
---

## Key overview

COSE key structures (RFC 8152).

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [Model](#model)
  - [COSEKey (class)](#cosekey-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [EdDSA25519Key (class)](#eddsa25519key-class)
    - [toJSON (method)](#tojson-method-1)
    - [toString (method)](#tostring-method-1)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-1)
    - [[Equal.symbol] (method)](#equalsymbol-method-1)
    - [[Hash.symbol] (method)](#hashsymbol-method-1)
    - [setPrivateKey (method)](#setprivatekey-method)
    - [isForSigning (method)](#isforsigning-method)
    - [isForVerifying (method)](#isforverifying-method)
    - [build (method)](#build-method)
- [Schemas](#schemas)
  - [COSEKeyFromCBORBytes](#cosekeyfromcborbytes)

---

# Model

## COSEKey (class)

COSE key representation (RFC 8152).

**Signature**

```ts
export declare class COSEKey
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

## EdDSA25519Key (class)

Ed25519 key for signing and verification.

**Signature**

```ts
export declare class EdDSA25519Key
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

### setPrivateKey (method)

Set the private key for signing.

**Signature**

```ts
setPrivateKey(privateKey: PrivateKey.PrivateKey): this
```

Added in v2.0.0

### isForSigning (method)

Check if key can be used for signing.

**Signature**

```ts
isForSigning(): boolean
```

Added in v2.0.0

### isForVerifying (method)

Check if key can be used for verification.

**Signature**

```ts
isForVerifying(): boolean
```

Added in v2.0.0

### build (method)

Build a COSEKey from this Ed25519 key.

**Signature**

```ts
build(): COSEKey
```

Added in v2.0.0

# Schemas

## COSEKeyFromCBORBytes

CBOR bytes transformation schema for COSEKey.
Encodes COSEKey as a CBOR Map compatible with CSL.

**Signature**

```ts
export declare const COSEKeyFromCBORBytes: (
  options?: CBOR.CodecOptions
) => Schema.transformOrFail<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.SchemaClass<COSEKey, COSEKey, never>,
  never
>
```

Added in v2.0.0

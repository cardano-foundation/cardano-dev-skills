---
title: cose/Sign1.ts
nav_order: 45
parent: Modules
---

## Sign1 overview

COSE_Sign1 structures (RFC 8152).

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [Constructors](#constructors)
  - [coseSign1BuilderNew](#cosesign1buildernew)
- [Conversion](#conversion)
  - [coseSign1FromCBORBytes](#cosesign1fromcborbytes)
  - [coseSign1FromCBORHex](#cosesign1fromcborhex)
  - [coseSign1ToCBORBytes](#cosesign1tocborbytes)
  - [coseSign1ToCBORHex](#cosesign1tocborhex)
- [Model](#model)
  - [COSESign1 (class)](#cosesign1-class)
    - [fromUserFacingEncoding (static method)](#fromuserfacingencoding-static-method)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
    - [signedData (method)](#signeddata-method)
    - [toUserFacingEncoding (method)](#touserfacingencoding-method)
  - [COSESign1Builder (class)](#cosesign1builder-class)
    - [toJSON (method)](#tojson-method-1)
    - [toString (method)](#tostring-method-1)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-1)
    - [[Equal.symbol] (method)](#equalsymbol-method-1)
    - [[Hash.symbol] (method)](#hashsymbol-method-1)
    - [setExternalAad (method)](#setexternalaad-method)
    - [hashPayloadWith224 (method)](#hashpayloadwith224-method)
    - [makeDataToSign (method)](#makedatatosign-method)
    - [build (method)](#build-method)
- [Schemas](#schemas)
  - [COSESign1FromCBORBytes](#cosesign1fromcborbytes-1)
  - [COSESign1FromCBORHex](#cosesign1fromcborhex-1)

---

# Constructors

## coseSign1BuilderNew

Create a new COSESign1Builder.

**Signature**

```ts
export declare const coseSign1BuilderNew: (
  headers: Headers,
  payload: Uint8Array,
  isPayloadExternal: boolean
) => COSESign1Builder
```

Added in v2.0.0

# Conversion

## coseSign1FromCBORBytes

Decode COSESign1 from CBOR bytes.

**Signature**

```ts
export declare const coseSign1FromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => COSESign1
```

Added in v2.0.0

## coseSign1FromCBORHex

Decode COSESign1 from CBOR hex.

**Signature**

```ts
export declare const coseSign1FromCBORHex: (hex: string, options?: CBOR.CodecOptions) => COSESign1
```

Added in v2.0.0

## coseSign1ToCBORBytes

Encode COSESign1 to CBOR bytes.

**Signature**

```ts
export declare const coseSign1ToCBORBytes: (coseSign1: COSESign1, options?: CBOR.CodecOptions) => Uint8Array
```

Added in v2.0.0

## coseSign1ToCBORHex

Encode COSESign1 to CBOR hex.

**Signature**

```ts
export declare const coseSign1ToCBORHex: (coseSign1: COSESign1, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# Model

## COSESign1 (class)

COSE_Sign1 structure (RFC 8152) - signed message.

**Signature**

```ts
export declare class COSESign1
```

Added in v2.0.0

### fromUserFacingEncoding (static method)

Parse from user-facing encoding format (`cms_<base64url>`).

**Signature**

```ts
static fromUserFacingEncoding(encoded: string): COSESign1
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

### signedData (method)

Get the signed data (Sig_structure as per RFC 8152).

**Signature**

```ts
signedData(externalAad: Uint8Array = new Uint8Array(), externalPayload?: Uint8Array): Uint8Array
```

Added in v2.0.0

### toUserFacingEncoding (method)

Convert to user-facing encoding format (`cms_<base64url>`).
Includes checksum for data integrity verification.

**Signature**

```ts
toUserFacingEncoding(): string
```

Added in v2.0.0

## COSESign1Builder (class)

Builder for creating COSE_Sign1 structures.

**Signature**

```ts
export declare class COSESign1Builder
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

### setExternalAad (method)

Set external additional authenticated data.

**Signature**

```ts
setExternalAad(aad: Uint8Array): this
```

Added in v2.0.0

### hashPayloadWith224 (method)

Hash the payload with blake2b-224 and update headers.
Sets the "hashed" header to true in unprotected headers.

**Signature**

```ts
hashPayloadWith224(): this
```

Added in v2.0.0

### makeDataToSign (method)

Create the data that needs to be signed (Sig_structure).

**Signature**

```ts
makeDataToSign(): Uint8Array
```

Added in v2.0.0

### build (method)

Build the final COSESign1 structure with the provided signature.

**Signature**

```ts
build(signature: Ed25519Signature.Ed25519Signature): COSESign1
```

Added in v2.0.0

# Schemas

## COSESign1FromCBORBytes

CBOR bytes transformation schema for COSESign1.

**Signature**

```ts
export declare const COSESign1FromCBORBytes: (
  options?: CBOR.CodecOptions
) => Schema.transformOrFail<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.SchemaClass<COSESign1, COSESign1, never>,
  never
>
```

Added in v2.0.0

## COSESign1FromCBORHex

CBOR hex transformation schema for COSESign1.

**Signature**

```ts
export declare const COSESign1FromCBORHex: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transformOrFail<
    Schema.transformOrFail<
      typeof Schema.Uint8ArrayFromSelf,
      Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
      never
    >,
    Schema.SchemaClass<COSESign1, COSESign1, never>,
    never
  >
>
```

Added in v2.0.0

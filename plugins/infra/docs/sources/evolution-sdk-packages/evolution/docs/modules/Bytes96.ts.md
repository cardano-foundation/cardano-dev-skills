---
title: Bytes96.ts
nav_order: 33
parent: Modules
---

## Bytes96 overview

Bytes96 module provides utilities for handling fixed-length and variable-length byte arrays.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [constants](#constants)
  - [BYTES_LENGTH](#bytes_length)
- [decoding](#decoding)
  - [fromHex](#fromhex)
  - [fromVariableHex](#fromvariablehex)
- [encoding](#encoding)
  - [toHex](#tohex)
  - [toVariableHex](#tovariablehex)
- [schemas](#schemas)
  - [BytesFromHex](#bytesfromhex)
  - [VariableBytesFromHex](#variablebytesfromhex)
- [utils](#utils)
  - [equals](#equals)

---

# constants

## BYTES_LENGTH

Constant bytes length

**Signature**

```ts
export declare const BYTES_LENGTH: 96
```

Added in v2.0.0

# decoding

## fromHex

Decode fixed-length hex into bytes.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## fromVariableHex

Decode variable-length hex (0..BYTES_LENGTH) into bytes.

**Signature**

```ts
export declare const fromVariableHex: (i: string, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

# encoding

## toHex

Encode fixed-length bytes to hex.

**Signature**

```ts
export declare const toHex: (a: Uint8Array, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

## toVariableHex

Encode variable-length bytes (0..BYTES_LENGTH) to hex.

**Signature**

```ts
export declare const toVariableHex: (a: Uint8Array, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# schemas

## BytesFromHex

Schema transformation for fixed-length bytes

**Signature**

```ts
export declare const BytesFromHex: Schema.filter<Schema.Schema<Uint8Array, string, never>>
```

Added in v2.0.0

## VariableBytesFromHex

Schema transformation for variable-length bytes (0..BYTES_LENGTH).

**Signature**

```ts
export declare const VariableBytesFromHex: Schema.filter<Schema.Schema<Uint8Array, string, never>>
```

Added in v2.0.0

# utils

## equals

**Signature**

```ts
export declare const equals: (a: Uint8Array, b: Uint8Array) => boolean
```

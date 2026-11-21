---
title: PointerAddress.ts
nav_order: 97
parent: Modules
---

## PointerAddress overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [encoding/decoding](#encodingdecoding)
  - [decodeVariableLength](#decodevariablelength)
  - [encodeVariableLength](#encodevariablelength)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [schemas](#schemas)
  - [PointerAddress (class)](#pointeraddress-class)
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

Smart constructor for creating PointerAddress instances

/\*\*
FastCheck arbitrary for generating random PointerAddress instances

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<PointerAddress>
```

Added in v2.0.0

# encoding

## toBytes

Convert a PointerAddress to bytes.

**Signature**

```ts
export declare const toBytes: (data: PointerAddress) => any
```

Added in v2.0.0

## toHex

Convert a PointerAddress to hex string.

**Signature**

```ts
export declare const toHex: (data: PointerAddress) => string
```

Added in v2.0.0

# encoding/decoding

## decodeVariableLength

Decode a variable length integer from a Uint8Array (LEB128-like)
Following the Cardano ledger implementation for variable-length integers

**Signature**

```ts
export declare const decodeVariableLength: (
  bytes: Uint8Array,
  offset?: number | undefined
) => Eff.Effect<[Natural.Natural, number], ParseResult.ParseIssue>
```

Added in v2.0.0

## encodeVariableLength

Encode a positive integer using Cardano pointer varint (LEB128-like) encoding.

- Little-endian base-128: emit 7-bit groups, low to high, set MSB (0x80) on all but last.
- Matches decodeVariableLength below and Cardano pointer address spec.

**Signature**

```ts
export declare const encodeVariableLength: (
  natural: Natural.Natural
) => Eff.Effect<Uint8Array, ParseResult.ParseIssue, never>
```

Added in v2.0.0

# parsing

## fromBytes

Parse a PointerAddress from bytes.

**Signature**

```ts
export declare const fromBytes: (bytes: Uint8Array) => PointerAddress
```

Added in v2.0.0

## fromHex

Parse a PointerAddress from hex string.

**Signature**

```ts
export declare const fromHex: (hex: string) => PointerAddress
```

Added in v2.0.0

# schemas

## PointerAddress (class)

Pointer address with payment credential and pointer to stake registration

**Signature**

```ts
export declare class PointerAddress
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
export declare const FromBytes: Schema.transformOrFail<
  typeof Schema.Uint8ArrayFromSelf,
  Schema.SchemaClass<PointerAddress, PointerAddress, never>,
  never
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.SchemaClass<PointerAddress, PointerAddress, never>,
    never
  >
>
```

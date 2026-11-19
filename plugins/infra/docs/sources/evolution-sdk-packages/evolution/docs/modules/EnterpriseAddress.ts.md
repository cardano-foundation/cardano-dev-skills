---
title: EnterpriseAddress.ts
nav_order: 59
parent: Modules
---

## EnterpriseAddress overview

---

<h2 class="text-delta">Table of contents</h2>

- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [schemas](#schemas)
  - [EnterpriseAddress (class)](#enterpriseaddress-class)
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

# encoding

## toBytes

Convert a EnterpriseAddress to bytes.

**Signature**

```ts
export declare const toBytes: (data: EnterpriseAddress) => Uint8Array
```

Added in v2.0.0

## toHex

Convert a EnterpriseAddress to hex string.

**Signature**

```ts
export declare const toHex: (data: EnterpriseAddress) => string
```

Added in v2.0.0

# parsing

## fromBytes

Parse a EnterpriseAddress from bytes.

**Signature**

```ts
export declare const fromBytes: (bytes: Uint8Array) => EnterpriseAddress
```

Added in v2.0.0

## fromHex

Parse a EnterpriseAddress from hex string.

**Signature**

```ts
export declare const fromHex: (hex: string) => EnterpriseAddress
```

Added in v2.0.0

# schemas

## EnterpriseAddress (class)

Enterprise address with only payment credential

**Signature**

```ts
export declare class EnterpriseAddress
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

FastCheck arbitrary for generating random EnterpriseAddress instances

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<EnterpriseAddress>
```

Added in v2.0.0

# utils

## FromBytes

**Signature**

```ts
export declare const FromBytes: Schema.transformOrFail<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<EnterpriseAddress, EnterpriseAddress, never>,
  never
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transformOrFail<
    Schema.SchemaClass<Uint8Array, Uint8Array, never>,
    Schema.SchemaClass<EnterpriseAddress, EnterpriseAddress, never>,
    never
  >
>
```

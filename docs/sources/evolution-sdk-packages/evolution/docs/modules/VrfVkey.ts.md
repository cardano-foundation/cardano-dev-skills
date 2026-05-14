---
title: VrfVkey.ts
nav_order: 191
parent: Modules
---

## VrfVkey overview

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
- [predicates](#predicates)
  - [isVrfVkey](#isvrfvkey)
- [schemas](#schemas)
  - [VrfVkey (class)](#vrfvkey-class)
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

FastCheck arbitrary for generating random VrfVkey instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<VrfVkey>
```

Added in v2.0.0

# encoding

## toBytes

Encode VrfVkey to bytes.

**Signature**

```ts
export declare const toBytes: (a: VrfVkey, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode VrfVkey to hex string.

**Signature**

```ts
export declare const toHex: (a: VrfVkey, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# parsing

## fromBytes

Parse VrfVkey from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => VrfVkey
```

Added in v2.0.0

## fromHex

Parse VrfVkey from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => VrfVkey
```

Added in v2.0.0

# predicates

## isVrfVkey

Check if the given value is a valid VrfVkey

**Signature**

```ts
export declare const isVrfVkey: (u: unknown, overrideOptions?: ParseOptions | number) => u is VrfVkey
```

Added in v2.0.0

# schemas

## VrfVkey (class)

Schema for VrfVkey representing a VRF verification key.
vrf_vkey = bytes .size 32
Follows the Conway-era CDDL specification.

**Signature**

```ts
export declare class VrfVkey
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
  Schema.SchemaClass<VrfVkey, VrfVkey, never>
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<VrfVkey, VrfVkey, never>>
>
```

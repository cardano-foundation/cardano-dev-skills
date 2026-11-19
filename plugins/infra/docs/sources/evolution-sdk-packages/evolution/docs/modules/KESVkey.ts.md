---
title: KESVkey.ts
nav_order: 70
parent: Modules
---

## KESVkey overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [KESVkey (class)](#kesvkey-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isKESVkey](#iskesvkey)
- [schemas](#schemas)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random KESVkey instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<KESVkey>
```

Added in v2.0.0

# encoding

## toBytes

Encode KESVkey to bytes.

**Signature**

```ts
export declare const toBytes: (a: KESVkey, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode KESVkey to hex string.

**Signature**

```ts
export declare const toHex: (a: KESVkey, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# model

## KESVkey (class)

Schema for KESVkey representing a KES verification key.
kes_vkey = bytes .size 32
Follows the Conway-era CDDL specification.

**Signature**

```ts
export declare class KESVkey
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

Parse KESVkey from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => KESVkey
```

Added in v2.0.0

## fromHex

Parse KESVkey from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => KESVkey
```

Added in v2.0.0

# predicates

## isKESVkey

Check if the given value is a valid KESVkey

**Signature**

```ts
export declare const isKESVkey: (u: unknown, overrideOptions?: ParseOptions | number) => u is KESVkey
```

Added in v2.0.0

# schemas

## FromBytes

Schema for transforming between Uint8Array and KESVkey.

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<KESVkey, KESVkey, never>
>
```

Added in v2.0.0

## FromHex

Schema for transforming between hex string and KESVkey.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<KESVkey, KESVkey, never>>
>
```

Added in v2.0.0

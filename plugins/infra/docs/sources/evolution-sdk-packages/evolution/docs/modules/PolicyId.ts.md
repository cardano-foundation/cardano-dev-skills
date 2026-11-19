---
title: PolicyId.ts
nav_order: 98
parent: Modules
---

## PolicyId overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [PolicyId (class)](#policyid-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isPolicyId](#ispolicyid)
- [schemas](#schemas)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random PolicyId instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<PolicyId>
```

Added in v2.0.0

# encoding

## toBytes

Encode PolicyId to bytes.

**Signature**

```ts
export declare const toBytes: (a: PolicyId, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode PolicyId to hex string.

**Signature**

```ts
export declare const toHex: (a: PolicyId, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# model

## PolicyId (class)

PolicyId as a TaggedClass representing a minting policy identifier.
A PolicyId is a script hash (hash28) that identifies a minting policy.

Note: PolicyId is equivalent to ScriptHash as defined in the CDDL:
policy_id = script_hash
script_hash = hash28

**Signature**

```ts
export declare class PolicyId
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

Parse PolicyId from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => PolicyId
```

Added in v2.0.0

## fromHex

Parse PolicyId from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => PolicyId
```

Added in v2.0.0

# predicates

## isPolicyId

Check if the given value is a valid PolicyId

**Signature**

```ts
export declare const isPolicyId: (u: unknown, overrideOptions?: ParseOptions | number) => u is PolicyId
```

Added in v2.0.0

# schemas

## FromBytes

Schema transformer from bytes to PolicyId.

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<PolicyId, PolicyId, never>
>
```

Added in v2.0.0

## FromHex

Schema transformer from hex string to PolicyId.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<PolicyId, PolicyId, never>>
>
```

Added in v2.0.0

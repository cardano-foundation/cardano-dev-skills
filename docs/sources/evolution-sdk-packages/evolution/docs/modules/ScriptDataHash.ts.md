---
title: ScriptDataHash.ts
nav_order: 115
parent: Modules
---

## ScriptDataHash overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [model](#model)
  - [ScriptDataHash (class)](#scriptdatahash-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [predicates](#predicates)
  - [isScriptDataHash](#isscriptdatahash)
- [schemas](#schemas)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random ScriptDataHash instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<ScriptDataHash>
```

Added in v2.0.0

# encoding

## toBytes

Encode ScriptDataHash to bytes.

**Signature**

```ts
export declare const toBytes: (a: ScriptDataHash, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Encode ScriptDataHash to hex string.

**Signature**

```ts
export declare const toHex: (a: ScriptDataHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# model

## ScriptDataHash (class)

ScriptDataHash based on Conway CDDL specification

CDDL: script_data_hash = Bytes32

This is a hash of data which may affect evaluation of a script.
This data consists of:

- The redeemers from the transaction_witness_set (the value of field 5).
- The datums from the transaction_witness_set (the value of field 4).
- The value in the cost_models map corresponding to the script's language
  (in field 18 of protocol_param_update.)

**Signature**

```ts
export declare class ScriptDataHash
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

Parse ScriptDataHash from bytes.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => ScriptDataHash
```

Added in v2.0.0

## fromHex

Parse ScriptDataHash from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => ScriptDataHash
```

Added in v2.0.0

# predicates

## isScriptDataHash

Check if the given value is a valid ScriptDataHash

**Signature**

```ts
export declare const isScriptDataHash: (u: unknown, overrideOptions?: ParseOptions | number) => u is ScriptDataHash
```

Added in v2.0.0

# schemas

## FromBytes

Schema for transforming between Uint8Array and ScriptDataHash.

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<ScriptDataHash, ScriptDataHash, never>
>
```

Added in v2.0.0

## FromHex

Schema for transforming between hex string and ScriptDataHash.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.filter<Schema.Schema<Uint8Array, string, never>>,
  Schema.transform<
    Schema.SchemaClass<Uint8Array, Uint8Array, never>,
    Schema.SchemaClass<ScriptDataHash, ScriptDataHash, never>
  >
>
```

Added in v2.0.0

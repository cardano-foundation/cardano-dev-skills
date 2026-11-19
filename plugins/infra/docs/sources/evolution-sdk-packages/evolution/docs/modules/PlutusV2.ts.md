---
title: PlutusV2.ts
nav_order: 94
parent: Modules
---

## PlutusV2 overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [model](#model)
  - [PlutusV2 (class)](#plutusv2-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [schemas](#schemas)
  - [CDDLSchema](#cddlschema)
  - [FromCDDL](#fromcddl)

---

# arbitrary

## arbitrary

FastCheck arbitrary for PlutusV2.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<PlutusV2>
```

Added in v2.0.0

# model

## PlutusV2 (class)

Plutus V2 script wrapper (raw bytes).

**Signature**

```ts
export declare class PlutusV2
```

Added in v2.0.0

### toJSON (method)

Convert to JSON representation.

**Signature**

```ts
toJSON()
```

Added in v2.0.0

### toString (method)

Convert to string representation.

**Signature**

```ts
toString(): string
```

Added in v2.0.0

### [Inspectable.NodeInspectSymbol] (method)

Custom inspect for Node.js REPL.

**Signature**

```ts
[Inspectable.NodeInspectSymbol](): unknown
```

Added in v2.0.0

### [Equal.symbol] (method)

Structural equality check.

**Signature**

```ts
[Equal.symbol](that: unknown): boolean
```

Added in v2.0.0

### [Hash.symbol] (method)

Hash code generation.

**Signature**

```ts
[Hash.symbol](): number
```

Added in v2.0.0

# schemas

## CDDLSchema

CDDL schema for PlutusV2 scripts as raw bytes.

**Signature**

```ts
export declare const CDDLSchema: typeof Schema.Uint8ArrayFromSelf
```

Added in v2.0.0

## FromCDDL

CDDL transformation schema for PlutusV2.

**Signature**

```ts
export declare const FromCDDL: Schema.transform<
  typeof Schema.Uint8ArrayFromSelf,
  Schema.SchemaClass<PlutusV2, PlutusV2, never>
>
```

Added in v2.0.0

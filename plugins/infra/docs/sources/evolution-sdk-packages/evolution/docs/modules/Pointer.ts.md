---
title: Pointer.ts
nav_order: 96
parent: Modules
---

## Pointer overview

---

<h2 class="text-delta">Table of contents</h2>

- [generators](#generators)
  - [arbitrary](#arbitrary)
- [predicates](#predicates)
  - [isPointer](#ispointer)
- [schemas](#schemas)
  - [Pointer (class)](#pointer-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)

---

# generators

## arbitrary

FastCheck arbitrary for generating random Pointer instances

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Pointer>
```

Added in v2.0.0

# predicates

## isPointer

Check if the given value is a valid Pointer

**Signature**

```ts
export declare const isPointer: (u: unknown, overrideOptions?: ParseOptions | number) => u is Pointer
```

Added in v2.0.0

# schemas

## Pointer (class)

Schema for pointer to a stake registration certificate
Contains slot, transaction index, and certificate index information

**Signature**

```ts
export declare class Pointer
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

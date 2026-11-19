---
title: cose/Label.ts
nav_order: 43
parent: Modules
---

## Label overview

COSE Label types and constructors.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [Constructors](#constructors)
  - [labelFromAlgorithmId](#labelfromalgorithmid)
  - [labelFromCurveType](#labelfromcurvetype)
  - [labelFromInt](#labelfromint)
  - [labelFromKeyType](#labelfromkeytype)
  - [labelFromText](#labelfromtext)
- [Model](#model)
  - [Label (class)](#label-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
    - [asInt (method)](#asint-method)
    - [asText (method)](#astext-method)

---

# Constructors

## labelFromAlgorithmId

Create a Label from AlgorithmId.

**Signature**

```ts
export declare const labelFromAlgorithmId: (alg: AlgorithmId) => Label
```

Added in v2.0.0

## labelFromCurveType

Create a Label from CurveType.

**Signature**

```ts
export declare const labelFromCurveType: (crv: CurveType) => Label
```

Added in v2.0.0

## labelFromInt

Create a Label from an integer.

**Signature**

```ts
export declare const labelFromInt: (value: bigint) => Label
```

Added in v2.0.0

## labelFromKeyType

Create a Label from KeyType.

**Signature**

```ts
export declare const labelFromKeyType: (kty: KeyType) => Label
```

Added in v2.0.0

## labelFromText

Create a Label from a text string.

**Signature**

```ts
export declare const labelFromText: (value: string) => Label
```

Added in v2.0.0

# Model

## Label (class)

COSE header label - can be an integer or text string (RFC 8152).

**Signature**

```ts
export declare class Label
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

### asInt (method)

Get the integer value (throws if label is text).

**Signature**

```ts
asInt(): bigint
```

Added in v2.0.0

### asText (method)

Get the text value (throws if label is integer).

**Signature**

```ts
asText(): string
```

Added in v2.0.0

---
title: UTxO.ts
nav_order: 185
parent: Modules
---

## UTxO overview

---

<h2 class="text-delta">Table of contents</h2>

- [combinators](#combinators)
  - [add](#add)
  - [difference](#difference)
  - [filter](#filter)
  - [intersection](#intersection)
  - [remove](#remove)
  - [union](#union)
- [constructors](#constructors)
  - [empty](#empty)
  - [fromIterable](#fromiterable)
- [conversions](#conversions)
  - [toArray](#toarray)
  - [toInputs](#toinputs)
- [getters](#getters)
  - [size](#size)
  - [toOutRefString](#tooutrefstring)
  - [totalAssets](#totalassets)
- [model](#model)
  - [UTxO (class)](#utxo-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [models](#models)
  - [UTxOSet (type alias)](#utxoset-type-alias)
- [predicates](#predicates)
  - [has](#has)
  - [isEmpty](#isempty)
  - [isUTxO](#isutxo)

---

# combinators

## add

Add a UTxO to the set.

**Signature**

```ts
export declare const add: (set: UTxOSet, utxo: UTxO) => UTxOSet
```

Added in v2.0.0

## difference

Difference of two UTxO sets (elements in a but not in b).

**Signature**

```ts
export declare const difference: (a: UTxOSet, b: UTxOSet) => UTxOSet
```

Added in v2.0.0

## filter

Filter UTxOs in the set by predicate.

**Signature**

```ts
export declare const filter: (set: UTxOSet, predicate: (utxo: UTxO) => boolean) => UTxOSet
```

Added in v2.0.0

## intersection

Intersection of two UTxO sets.

**Signature**

```ts
export declare const intersection: (a: UTxOSet, b: UTxOSet) => UTxOSet
```

Added in v2.0.0

## remove

Remove a UTxO from the set.

**Signature**

```ts
export declare const remove: (set: UTxOSet, utxo: UTxO) => UTxOSet
```

Added in v2.0.0

## union

Union of two UTxO sets.

**Signature**

```ts
export declare const union: (a: UTxOSet, b: UTxOSet) => UTxOSet
```

Added in v2.0.0

# constructors

## empty

Create an empty UTxO set.

**Signature**

```ts
export declare const empty: () => UTxOSet
```

Added in v2.0.0

## fromIterable

Create a UTxO set from an iterable of UTxOs.

**Signature**

```ts
export declare const fromIterable: (utxos: Iterable<UTxO>) => UTxOSet
```

Added in v2.0.0

# conversions

## toArray

Convert a UTxO set to an array.

**Signature**

```ts
export declare const toArray: (set: UTxOSet) => Array<UTxO>
```

Added in v2.0.0

## toInputs

Convert UTxOs to sorted TransactionInputs.
Inputs are sorted by transaction hash then output index for deterministic ordering.

**Signature**

```ts
export declare const toInputs: (utxos: ReadonlyArray<UTxO>) => ReadonlyArray<TransactionInput.TransactionInput>
```

Added in v2.0.0

# getters

## size

Get the number of UTxOs in the set.

**Signature**

```ts
export declare const size: (set: UTxOSet) => number
```

Added in v2.0.0

## toOutRefString

Get the output reference string for a UTxO (txHash#index format).

**Signature**

```ts
export declare const toOutRefString: (utxo: UTxO) => string
```

Added in v2.0.0

## totalAssets

Calculate total assets from a collection of UTxOs.

**Signature**

```ts
export declare const totalAssets: (utxos: ReadonlyArray<UTxO> | Set<UTxO>) => Assets.Assets
```

Added in v2.0.0

# model

## UTxO (class)

UTxO (Unspent Transaction Output) - A transaction output with its on-chain reference.

Combines TransactionOutput with the transaction reference (transactionId + index)
that uniquely identifies it on the blockchain.

**Signature**

```ts
export declare class UTxO
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

# models

## UTxOSet (type alias)

A set of UTxOs with efficient lookups and set operations.
Uses Effect's HashSet for automatic deduplication via Hash protocol.

**Signature**

```ts
export type UTxOSet = HashSet.HashSet<UTxO>
```

Added in v2.0.0

# predicates

## has

Check if a UTxO exists in the set.

**Signature**

```ts
export declare const has: (set: UTxOSet, utxo: UTxO) => boolean
```

Added in v2.0.0

## isEmpty

Check if the set is empty.

**Signature**

```ts
export declare const isEmpty: (set: UTxOSet) => boolean
```

Added in v2.0.0

## isUTxO

Check if the given value is a valid UTxO.

**Signature**

```ts
export declare const isUTxO: (u: unknown, overrideOptions?: ParseOptions | number) => u is UTxO
```

Added in v2.0.0

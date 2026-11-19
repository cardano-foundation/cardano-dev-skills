---
title: PositiveCoin.ts
nav_order: 103
parent: Modules
---

## PositiveCoin overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [constants](#constants)
  - [MAX_POSITIVE_COIN_VALUE](#max_positive_coin_value)
  - [MIN_POSITIVE_COIN_VALUE](#min_positive_coin_value)
- [model](#model)
  - [PositiveCoin (type alias)](#positivecoin-type-alias)
- [ordering](#ordering)
  - [compare](#compare)
- [predicates](#predicates)
  - [is](#is)
- [schemas](#schemas)
  - [PositiveCoinSchema](#positivecoinschema)
- [transformation](#transformation)
  - [add](#add)
  - [subtract](#subtract)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random PositiveCoin values.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<bigint>
```

Added in v2.0.0

# constants

## MAX_POSITIVE_COIN_VALUE

Maximum value for a positive coin amount (maxWord64).

**Signature**

```ts
export declare const MAX_POSITIVE_COIN_VALUE: 18446744073709551615n
```

Added in v2.0.0

## MIN_POSITIVE_COIN_VALUE

Minimum value for a positive coin amount.

**Signature**

```ts
export declare const MIN_POSITIVE_COIN_VALUE: 1n
```

Added in v2.0.0

# model

## PositiveCoin (type alias)

Type alias for PositiveCoin representing positive amounts of native assets.
Used in multiasset maps where zero amounts are not allowed.

**Signature**

```ts
export type PositiveCoin = typeof PositiveCoinSchema.Type
```

Added in v2.0.0

# ordering

## compare

Compare two positive coin amounts.

**Signature**

```ts
export declare const compare: (a: PositiveCoin, b: PositiveCoin) => -1 | 0 | 1
```

Added in v2.0.0

# predicates

## is

Check if a value is a valid PositiveCoin.

**Signature**

```ts
export declare const is: (u: unknown, overrideOptions?: ParseOptions | number) => u is bigint
```

Added in v2.0.0

# schemas

## PositiveCoinSchema

Schema for validating positive coin amounts.
positive_coin = 1 .. maxWord64

**Signature**

```ts
export declare const PositiveCoinSchema: Schema.refine<bigint, typeof Schema.BigInt>
```

Added in v2.0.0

# transformation

## add

Add two positive coin amounts safely.

**Signature**

```ts
export declare const add: (a: PositiveCoin, b: PositiveCoin) => PositiveCoin
```

Added in v2.0.0

## subtract

Subtract two positive coin amounts safely.
Note: Result must still be positive.

**Signature**

```ts
export declare const subtract: (a: PositiveCoin, b: PositiveCoin) => PositiveCoin
```

Added in v2.0.0

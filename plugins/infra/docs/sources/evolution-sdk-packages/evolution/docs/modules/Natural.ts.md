---
title: Natural.ts
nav_order: 80
parent: Modules
---

## Natural overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [model](#model)
  - [Natural (type alias)](#natural-type-alias)
- [predicates](#predicates)
  - [isNatural](#isnatural)
- [schemas](#schemas)
  - [Natural](#natural)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random Natural instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<number>
```

Added in v2.0.0

# model

## Natural (type alias)

Type alias for Natural representing positive integers.

**Signature**

```ts
export type Natural = typeof Natural.Type
```

Added in v2.0.0

# predicates

## isNatural

Check if the given value is a valid Natural

**Signature**

```ts
export declare const isNatural: (u: unknown, overrideOptions?: ParseOptions | number) => u is number
```

Added in v2.0.0

# schemas

## Natural

Natural number schema for positive integers.
Used for validating non-negative integers greater than 0.

**Signature**

```ts
export declare const Natural: Schema.refine<number, typeof Schema.Number>
```

Added in v2.0.0

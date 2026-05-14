---
title: NetworkId.ts
nav_order: 82
parent: Modules
---

## NetworkId overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [schemas](#schemas)
  - [NetworkId](#networkid)
- [utils](#utils)
  - [NetworkId (type alias)](#networkid-type-alias)

---

# arbitrary

## arbitrary

FastCheck generator for creating NetworkId instances.
Generates values 0 (Testnet) or 1 (Mainnet).

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<number>
```

Added in v2.0.0

# schemas

## NetworkId

Schema for NetworkId representing a Cardano network identifier.
0 = Testnet, 1 = Mainnet

**Signature**

```ts
export declare const NetworkId: Schema.refine<number, typeof Schema.NonNegative>
```

Added in v2.0.0

# utils

## NetworkId (type alias)

**Signature**

```ts
export type NetworkId = typeof NetworkId.Type
```

---
title: sdk/EvalRedeemer.ts
nav_order: 152
parent: Modules
---

## EvalRedeemer overview

// EvalRedeemer types and utilities for transaction evaluation

---

<h2 class="text-delta">Table of contents</h2>

- [model](#model)
  - [EvalRedeemer (type alias)](#evalredeemer-type-alias)

---

# model

## EvalRedeemer (type alias)

Evaluation result for a single redeemer from transaction evaluation.

Uses Core CDDL terminology ("cert"/"reward") for consistency.
Provider implementations map from their API formats (e.g., Ogmios "publish"/"withdraw").

**Signature**

```ts
export type EvalRedeemer = {
  readonly ex_units: Redeemer.ExUnits
  readonly redeemer_index: number
  readonly redeemer_tag: Redeemer.RedeemerTag
}
```

Added in v2.0.0

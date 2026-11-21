---
title: sdk/builders/phases/Selection.ts
nav_order: 141
parent: Modules
---

## Selection overview

Selection Phase - UTxO Coin Selection

Selects UTxOs from available pool to cover transaction outputs, fees, and change requirements.
Handles both initial selection and reselection with retry logic up to MAX_ATTEMPTS.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [executeSelection](#executeselection)

---

# utils

## executeSelection

Selection Phase - UTxO Coin Selection

Selects UTxOs from available pool to cover transaction outputs, fees, and change requirements.
Handles both initial selection and reselection with retry logic up to MAX_ATTEMPTS.

**Decision Flow:**

```
Calculate Required Assets
(outputs + shortfall for fees/change)
  ↓
Assets Sufficient?
(inputs >= required)
  ├─ YES → No selection needed
  │        (use existing explicit inputs only)
  │        goto changeCreation
  └─ NO → Calculate asset delta
          ├─ Shortfall from fees? → Reselection mode
          │  (select more lovelace for change minUTxO)
          └─ Shortfall from outputs? → Normal selection
             (select missing native assets or lovelace)
          ↓
       Perform coin selection
       (update totalInputAssets)
       ↓
       Increment attempt counter
       goto changeCreation
```

**Key Principles:**

- Selection phase runs once per state machine iteration
- Reselection (shortfall > 0) adds more UTxOs within MAX_ATTEMPTS limit
- Selection itself doesn't fail; ChangeCreation may trigger reselection
- No selection needed if explicit inputs already cover requirements
- Shortfall tracks lovelace deficit for change output minUTxO
- Asset delta identifies what additional UTxOs must contain
- Attempt counter resets at phase start, incremented at phase end
- Selection is deterministic (same inputs = same selection)

**Signature**

```ts
export declare const executeSelection: () => Effect.Effect<
  PhaseResult,
  TransactionBuilderError,
  PhaseContextTag | TxContext | AvailableUtxosTag | BuildOptionsTag
>
```

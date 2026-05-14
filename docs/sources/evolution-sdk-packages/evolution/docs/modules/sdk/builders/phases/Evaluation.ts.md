---
title: sdk/builders/phases/Evaluation.ts
nav_order: 138
parent: Modules
---

## Evaluation overview

Evaluation Phase

Executes UPLC validators to compute execution units (ExUnits) for redeemers.
Re-evaluation occurs every time the Balance phase completes with scripts present.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [executeEvaluation](#executeevaluation)

---

# utils

## executeEvaluation

Evaluation Phase

Executes UPLC validators to determine execution units (ExUnits) for script redeemers.
This phase is triggered after Balance when scripts are present in the transaction.

**Flow:**

```
Balance (balanced && hasScripts)
  ↓
Evaluation
  ├─ Build transaction CBOR
  ├─ Prepare evaluation context (cost models, slot config, etc.)
  ├─ Execute UPLC evaluator
  ├─ Match results to redeemers by tag+index
  ├─ Update redeemer ExUnits
  └─ Route to FeeCalculation (fee needs recalc with new ExUnits)
```

**Key Principles:**

- Re-evaluation happens every Balance pass (no change detection)
- Loop prevention via existing MAX_BALANCE_ATTEMPTS
- Evaluation errors fail immediately (no fallback)
- ExUnits affect transaction size → affect fees → may change balance
- Process repeats until transaction stabilizes or max attempts reached

**Why Re-evaluation is Mandatory:**
Validators can check outputs, fees, or other transaction properties that change
after reselection or fee adjustments. Re-evaluation ensures ExUnits remain valid
for the final transaction structure.

**Signature**

```ts
export declare const executeEvaluation: () => Effect.Effect<
  PhaseResult,
  TransactionBuilderError,
  BuildOptionsTag | TxContext | PhaseContextTag | TxBuilderConfigTag
>
```

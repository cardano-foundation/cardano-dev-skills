---
title: sdk/builders/phases/FeeCalculation.ts
nav_order: 140
parent: Modules
---

## FeeCalculation overview

Fee Calculation Phase

Calculates transaction fee based on current inputs and outputs (including change).
Stores both calculated fee and leftover amount for the Balance phase to verify.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [executeFeeCalculation](#executefeecalculation)

---

# utils

## executeFeeCalculation

Fee Calculation Phase

Calculates transaction fee based on current inputs and outputs (including change).
Stores both calculated fee and leftover amount for the Balance phase to verify.
This phase is deterministic once inputs and outputs are fixed.

**Decision Flow:**

```
Combine Inputs & Outputs
(base outputs + change outputs)
  ↓
Calculate Fee Iteratively
(account for changing tx size during fee calculation)
  ↓
Calculate Leftover After Fee
(inputs - outputs - change - fee)
  ↓
Store Fee & Leftover
(in build context for Balance phase)
  ↓
goto balance
```

**Key Principles:**

- Fee calculation is deterministic given fixed inputs/outputs/change
- Iterative calculation accounts for fee size affecting tx size
- Leftover = inputs - outputs - change - fee (can be 0, positive, or negative)
- Positive leftover triggers Balance → drainTo/burn strategies
- Negative leftover (shortfall) triggers Balance → reselection
- Zero leftover means perfectly balanced (ideal case)
- Change outputs are always included in fee calculation
- Fee is stored in context for Balance phase validation
- No phase retries here; Balance phase decides next step based on leftover

**Signature**

```ts
export declare const executeFeeCalculation: () => Effect.Effect<
  PhaseResult,
  TransactionBuilderError,
  PhaseContextTag | TxContext | ProtocolParametersTag | BuildOptionsTag
>
```

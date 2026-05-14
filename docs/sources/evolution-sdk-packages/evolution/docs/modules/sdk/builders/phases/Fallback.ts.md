---
title: sdk/builders/phases/Fallback.ts
nav_order: 139
parent: Modules
---

## Fallback overview

Fallback Phase - Terminal Strategy Selection

Handles insufficient change scenarios after MAX_ATTEMPTS exhausted in ChangeCreation.
Routes to one of two terminal strategies: drainTo (merge leftover) or burn (implicit fee).

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [executeFallback](#executefallback)

---

# utils

## executeFallback

Fallback Phase - Terminal Strategy Selection

Handles insufficient change scenarios after MAX_ATTEMPTS exhausted in ChangeCreation.
Routes to one of two terminal strategies: drainTo (merge leftover) or burn (implicit fee).
This phase is only reached when change creation cannot create a valid change output
and a fallback strategy is configured.

**Decision Flow:**

```
Fallback Phase Triggered
(MAX_ATTEMPTS exhausted in changeCreation)
  ↓
Check: drainTo configured?
  ├─ YES → Validate drainTo index
  │         ├─ Valid → Clear change outputs
  │         │          Return to feeCalculation
  │         │          (leftover merged in balance phase)
  │         └─ Invalid → ERROR (invalid output index)
  └─ NO → Check: burn strategy?
          ├─ YES → Clear change outputs
          │        Return to feeCalculation
          │        (leftover becomes implicit fee)
          └─ NO → ERROR (no strategy configured)
                  (ChangeCreation should prevent this)
```

**Key Principles:**

- Fallback only handles ADA-only leftover (ChangeCreation filters native asset cases)
- DrainTo merges excess into a specified output, deferring actual merge to Balance phase
- Burn strategy accepts leftover as implicit network fee
- Both strategies clear change outputs and recalculate fee (leftover not in outputs)
- Invalid drainTo index is caught here with validation
- Reaching fallback without a strategy configured indicates a bug in ChangeCreation routing
- Fee recalculation after clearing change ensures accurate final fee

**Signature**

```ts
export declare const executeFallback: () => Effect.Effect<
  PhaseResult,
  TransactionBuilderError,
  PhaseContextTag | TxContext | BuildOptionsTag
>
```

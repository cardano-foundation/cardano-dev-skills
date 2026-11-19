---
title: sdk/builders/operations/Collect.ts
nav_order: 123
parent: Modules
---

## Collect overview

Collect operation - adds UTxOs as transaction inputs.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [programs](#programs)
  - [createCollectFromProgram](#createcollectfromprogram)

---

# programs

## createCollectFromProgram

Creates a ProgramStep for collectFrom operation.
Adds UTxOs as transaction inputs, validates script requirements, and tracks assets.

Implementation:

1. Validates that inputs array is not empty
2. Checks if any inputs are script-locked (require redeemers)
3. Validates redeemer is provided for script-locked UTxOs
4. Adds UTxOs to state.selectedUtxos
5. Tracks redeemer information for script spending (supports deferred resolution)
6. Updates total input assets for balancing

**RedeemerBuilder Support:**

- Static: Direct Data value stored immediately
- Self: Callback stored for per-input resolution after coin selection
- Batch: Callback + input set stored for multi-input resolution

**Signature**

```ts
export declare const createCollectFromProgram: (
  params: CollectFromParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

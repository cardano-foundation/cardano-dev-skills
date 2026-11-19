---
title: sdk/builders/operations/Vote.ts
nav_order: 134
parent: Modules
---

## Vote overview

Vote operation - submit voting procedures for governance actions.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [programs](#programs)
  - [createVoteProgram](#createvoteprogram)

---

# programs

## createVoteProgram

Creates a ProgramStep for vote operation.
Adds voting procedures to the transaction and tracks redeemers for script-controlled voters.

Implementation:

1. Validates voting procedures structure
2. Merges with existing voting procedures if any
3. Tracks redeemers for script-controlled voters (by voter key)

**RedeemerBuilder Support:**

- Static: Direct Data value stored immediately
- Self: Callback stored for per-voter resolution after coin selection
- Batch: Callback + input set stored for multi-voter resolution

**Signature**

```ts
export declare const createVoteProgram: (params: VoteParams) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

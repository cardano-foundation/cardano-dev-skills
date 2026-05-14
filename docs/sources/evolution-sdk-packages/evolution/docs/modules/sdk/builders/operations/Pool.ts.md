---
title: sdk/builders/operations/Pool.ts
nav_order: 128
parent: Modules
---

## Pool overview

Pool operations - stake pool registration and retirement.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [programs](#programs)
  - [createRegisterPoolProgram](#createregisterpoolprogram)
  - [createRetirePoolProgram](#createretirepoolprogram)

---

# programs

## createRegisterPoolProgram

Creates a ProgramStep for registerPool operation.
Adds a PoolRegistration certificate to the transaction.
Used for both new pool registration and updating existing pool parameters.

**Signature**

```ts
export declare const createRegisterPoolProgram: (
  params: RegisterPoolParams
) => Effect.Effect<void, TransactionBuilderError, TxContext | TxBuilderConfigTag>
```

Added in v2.0.0

## createRetirePoolProgram

Creates a ProgramStep for retirePool operation.
Adds a PoolRetirement certificate to the transaction.
Announces pool retirement effective at the specified epoch.

**Signature**

```ts
export declare const createRetirePoolProgram: (params: RetirePoolParams) => Effect.Effect<void, never, TxContext>
```

Added in v2.0.0

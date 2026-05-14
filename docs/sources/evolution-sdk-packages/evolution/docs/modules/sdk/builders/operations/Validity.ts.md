---
title: sdk/builders/operations/Validity.ts
nav_order: 133
parent: Modules
---

## Validity overview

Validity operation - sets transaction validity interval.

Configures the time window during which the transaction is valid:

- `from`: Transaction is valid after this time (validityIntervalStart slot)
- `to`: Transaction expires after this time (ttl slot)

Times are provided as Unix milliseconds and converted to slots based on
the network's slot configuration.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [programs](#programs)
  - [createSetValidityProgram](#createsetvalidityprogram)

---

# programs

## createSetValidityProgram

Creates a ProgramStep for setValidity operation.
Sets the transaction validity interval (from/to times).

Implementation:

1. Validates at least one bound is provided
2. Stores Unix times in state (slot conversion happens during assembly)

**Signature**

```ts
export declare const createSetValidityProgram: (
  params: ValidityParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

---
title: sdk/builders/SubmitBuilderImpl.ts
nav_order: 146
parent: Modules
---

## SubmitBuilderImpl overview

SubmitBuilder Implementation

Handles transaction submission by delegating to the provider's submitTx method.
The SubmitBuilder is responsible for:

1. Converting the signed transaction to CBOR hex format
2. Submitting to the provider's Effect.submitTx
3. Returning the transaction hash

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [makeSubmitBuilder](#makesubmitbuilder)

---

# constructors

## makeSubmitBuilder

Create a SubmitBuilder instance for a signed transaction.

**Signature**

```ts
export declare const makeSubmitBuilder: (
  signedTransaction: Transaction.Transaction,
  witnessSet: TransactionWitnessSet.TransactionWitnessSet,
  provider: Provider.Provider
) => SubmitBuilder
```

Added in v2.0.0

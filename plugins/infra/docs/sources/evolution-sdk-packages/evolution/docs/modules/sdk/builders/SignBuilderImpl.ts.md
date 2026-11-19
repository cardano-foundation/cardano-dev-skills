---
title: sdk/builders/SignBuilderImpl.ts
nav_order: 144
parent: Modules
---

## SignBuilderImpl overview

SignBuilder Implementation

Handles transaction signing by delegating to the wallet's signTx Effect method.
The SignBuilder is responsible for:

1. Providing the transaction and UTxO context to the wallet
2. Managing the transition from unsigned to signed transaction
3. Creating the SubmitBuilder for transaction submission

The actual signing logic (determining required signers, creating witnesses)
is the wallet's responsibility.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [makeSignBuilder](#makesignbuilder)

---

# constructors

## makeSignBuilder

Create a SignBuilder instance for a built transaction.

**Signature**

```ts
export declare const makeSignBuilder: (params: {
  transaction: Transaction.Transaction
  transactionWithFakeWitnesses: Transaction.Transaction
  fee: bigint
  utxos: ReadonlyArray<CoreUTxO.UTxO>
  referenceUtxos: ReadonlyArray<CoreUTxO.UTxO>
  provider: Provider.Provider
  wallet: SignerWallet
  outputs: ReadonlyArray<TxOut.TransactionOutput>
  availableUtxos: ReadonlyArray<CoreUTxO.UTxO>
}) => SignBuilder
```

Added in v2.0.0

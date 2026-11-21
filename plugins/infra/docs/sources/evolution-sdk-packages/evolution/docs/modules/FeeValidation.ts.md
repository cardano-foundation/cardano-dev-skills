---
title: FeeValidation.ts
nav_order: 61
parent: Modules
---

## FeeValidation overview

Fee Validation Utilities

Independent validation of transaction fees using the Cardano protocol fee formula.
This validation is external to the transaction builder and can be used to verify
that fees meet the minimum requirements according to ledger rules.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [model](#model)
  - [FeeProtocolParams (interface)](#feeprotocolparams-interface)
  - [FeeValidationResult (interface)](#feevalidationresult-interface)
- [validation](#validation)
  - [assertValidFee](#assertvalidfee)
  - [validateTransactionFee](#validatetransactionfee)

---

# model

## FeeProtocolParams (interface)

Protocol parameters required for fee calculation.

**Signature**

```ts
export interface FeeProtocolParams {
  /**
   * Fee coefficient (a) in the linear fee formula: fee = a × tx_size + b
   */
  readonly minFeeCoefficient: bigint

  /**
   * Fee constant (b) in the linear fee formula: fee = a × tx_size + b
   */
  readonly minFeeConstant: bigint
}
```

Added in v2.0.0

## FeeValidationResult (interface)

Result of transaction fee validation.

**Signature**

```ts
export interface FeeValidationResult {
  /**
   * Whether the transaction fee is valid (actualFee >= minRequiredFee)
   */
  readonly isValid: boolean

  /**
   * The actual fee in the transaction (in lovelace)
   */
  readonly actualFee: bigint

  /**
   * The minimum required fee according to protocol parameters (in lovelace)
   */
  readonly minRequiredFee: bigint

  /**
   * The transaction size in bytes
   */
  readonly txSizeBytes: number

  /**
   * The difference between actual and minimum fee (in lovelace)
   * Positive = overpayment, Negative = underpayment
   */
  readonly difference: bigint
}
```

Added in v2.0.0

# validation

## assertValidFee

Assert that a transaction's fee is valid, throwing an error if not.

Useful for tests where you want to ensure fee validity.

**Signature**

```ts
export declare const assertValidFee: (
  transaction: Transaction.Transaction,
  protocolParams: FeeProtocolParams,
  fakeWitnessSet?: TransactionWitnessSet.TransactionWitnessSet
) => void
```

Added in v2.0.0

## validateTransactionFee

Validate that a transaction's fee meets the minimum requirements.

Uses the Cardano protocol fee formula:

```
min_fee = minFeeConstant + (minFeeCoefficient × tx_size_bytes)
```

The ledger rule is: `actualFee >= minFee`

This function is independent of the transaction builder and provides external
verification of fee correctness. It serializes the transaction to CBOR to get
the exact size and calculates the minimum fee according to protocol parameters.

**Important:** When validating unsigned transactions, you should provide a
`fakeWitnessSet` parameter to estimate the size with witnesses included. This
ensures the fee validation matches what the final signed transaction will be.

**Signature**

```ts
export declare const validateTransactionFee: (
  transaction: Transaction.Transaction,
  protocolParams: FeeProtocolParams,
  fakeWitnessSet?: TransactionWitnessSet.TransactionWitnessSet
) => FeeValidationResult
```

Added in v2.0.0

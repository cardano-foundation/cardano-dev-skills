---
title: Transaction.ts
nav_order: 169
parent: Modules
---

## Transaction overview

---

<h2 class="text-delta">Table of contents</h2>

- [encoding](#encoding)
  - [addVKeyWitnesses](#addvkeywitnesses)
  - [addVKeyWitnessesBytes](#addvkeywitnessesbytes)
  - [addVKeyWitnessesHex](#addvkeywitnesseshex)
  - [extractBodyBytes](#extractbodybytes)
  - [toCBORBytesWithFormat](#tocborbyteswithformat)
  - [toCBORHexWithFormat](#tocborhexwithformat)
- [model](#model)
  - [Transaction (class)](#transaction-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromCBORBytesWithFormat](#fromcborbyteswithformat)
  - [fromCBORHexWithFormat](#fromcborhexwithformat)
- [utils](#utils)
  - [CDDLSchema](#cddlschema)
  - [FromCBORBytes](#fromcborbytes)
  - [FromCBORHex](#fromcborhex)
  - [FromCDDL](#fromcddl)
  - [arbitrary](#arbitrary)
  - [fromCBORBytes](#fromcborbytes-1)
  - [fromCBORHex](#fromcborhex-1)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)

---

# encoding

## addVKeyWitnesses

Add VKey witnesses to a transaction at the domain level.

This creates a new Transaction with the additional witnesses merged in.
All encoding metadata (body bytes, redeemers format, witness map structure)
is preserved so that txId and scriptDataHash remain stable.

**Signature**

```ts
export declare const addVKeyWitnesses: (
  tx: Transaction,
  witnesses: ReadonlyArray<TransactionWitnessSet.VKeyWitness>
) => Transaction
```

Added in v2.0.0

## addVKeyWitnessesBytes

Merge wallet vkey witnesses into a transaction, preserving CBOR encoding.

Uses the WithFormat round-trip: decode with format capture, mutate at the
domain level, re-encode with the original format tree. Body encoding,
redeemer bytes, map key ordering, and all non-witness data are preserved
through the format tree reconciliation.

`options` applies only to parsing the wallet witness set bytes. Transaction
decoding and re-encoding are governed by the captured format tree, making
codec options irrelevant for the transaction round-trip path.

**Signature**

```ts
export declare const addVKeyWitnessesBytes: (
  txBytes: Uint8Array,
  walletWitnessSetBytes: Uint8Array,
  options?: CBOR.CodecOptions
) => Uint8Array
```

Added in v2.0.0

## addVKeyWitnessesHex

Hex variant of `addVKeyWitnessesBytes`.

**Signature**

```ts
export declare const addVKeyWitnessesHex: (
  txHex: string,
  walletWitnessSetHex: string,
  options?: CBOR.CodecOptions
) => string
```

Added in v2.0.0

## extractBodyBytes

Extract the original body bytes from a raw transaction CBOR byte array.
A Cardano transaction is a 4-element CBOR array: `[body, witnessSet, isValid, auxiliaryData]`.
This returns the raw body bytes without decoding/re-encoding, preserving the exact CBOR encoding.

**Signature**

```ts
export declare const extractBodyBytes: (txBytes: Uint8Array) => Uint8Array
```

Added in v2.0.0

## toCBORBytesWithFormat

Convert a Transaction to CBOR bytes using an explicit root format tree.

**Signature**

```ts
export declare const toCBORBytesWithFormat: (data: Transaction, format: CBOR.CBORFormat) => Uint8Array
```

Added in v2.0.0

## toCBORHexWithFormat

Convert a Transaction to CBOR hex string using an explicit root format tree.

**Signature**

```ts
export declare const toCBORHexWithFormat: (data: Transaction, format: CBOR.CBORFormat) => string
```

Added in v2.0.0

# model

## Transaction (class)

Transaction based on Conway CDDL specification

CDDL: transaction =
[transaction_body, transaction_witness_set, bool, auxiliary_data / nil]

**Signature**

```ts
export declare class Transaction
```

Added in v2.0.0

### toJSON (method)

**Signature**

```ts
toJSON()
```

### toString (method)

**Signature**

```ts
toString(): string
```

### [Inspectable.NodeInspectSymbol] (method)

**Signature**

```ts
[Inspectable.NodeInspectSymbol](): unknown
```

### [Equal.symbol] (method)

**Signature**

```ts
[Equal.symbol](that: unknown): boolean
```

### [Hash.symbol] (method)

**Signature**

```ts
[Hash.symbol](): number
```

# parsing

## fromCBORBytesWithFormat

Parse a Transaction from CBOR bytes and return the root format tree.

**Signature**

```ts
export declare const fromCBORBytesWithFormat: (bytes: Uint8Array) => CBOR.DecodedWithFormat<Transaction>
```

Added in v2.0.0

## fromCBORHexWithFormat

Parse a Transaction from CBOR hex string and return the root format tree.

**Signature**

```ts
export declare const fromCBORHexWithFormat: (hex: string) => CBOR.DecodedWithFormat<Transaction>
```

Added in v2.0.0

# utils

## CDDLSchema

Conway CDDL schema for Transaction tuple structure.

CDDL: transaction = [transaction_body, transaction_witness_set, bool, auxiliary_data / nil]

**Signature**

```ts
export declare const CDDLSchema: Schema.declare<
  readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
  readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
  readonly [],
  never
>
```

## FromCBORBytes

CBOR bytes transformation schema for Transaction.

**Signature**

```ts
export declare const FromCBORBytes: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.transformOrFail<
    Schema.declare<
      readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
      readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
      readonly [],
      never
    >,
    Schema.SchemaClass<Transaction, Transaction, never>,
    never
  >
>
```

## FromCBORHex

CBOR hex transformation schema for Transaction.

**Signature**

```ts
export declare const FromCBORHex: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.transform<
    Schema.Schema<Uint8Array, string, never>,
    Schema.transformOrFail<
      typeof Schema.Uint8ArrayFromSelf,
      Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
      never
    >
  >,
  Schema.transformOrFail<
    Schema.declare<
      readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
      readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
      readonly [],
      never
    >,
    Schema.SchemaClass<Transaction, Transaction, never>,
    never
  >
>
```

## FromCDDL

Transform between CDDL tuple and Transaction class.

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.declare<
    readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
    readonly [Map<bigint, CBOR.CBOR>, Map<bigint, CBOR.CBOR>, boolean, CBOR.CBOR],
    readonly [],
    never
  >,
  Schema.SchemaClass<Transaction, Transaction, never>,
  never
>
```

## arbitrary

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Transaction>
```

## fromCBORBytes

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => Transaction
```

## fromCBORHex

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => Transaction
```

## toCBORBytes

**Signature**

```ts
export declare const toCBORBytes: (data: Transaction, options?: CBOR.CodecOptions) => Uint8Array
```

## toCBORHex

**Signature**

```ts
export declare const toCBORHex: (data: Transaction, options?: CBOR.CodecOptions) => string
```

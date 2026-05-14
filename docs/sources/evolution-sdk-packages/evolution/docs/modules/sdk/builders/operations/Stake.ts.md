---
title: sdk/builders/operations/Stake.ts
nav_order: 132
parent: Modules
---

## Stake overview

Stake operations - register, deregister stake credentials and withdraw rewards.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [programs](#programs)
  - [createDelegateToDRepProgram](#createdelegatetodrepprogram)
  - [createDelegateToPoolAndDRepProgram](#createdelegatetopoolanddrepprogram)
  - [createDelegateToPoolProgram](#createdelegatetopoolprogram)
  - [~~createDelegateToProgram~~](#createdelegatetoprogram)
  - [createDeregisterStakeLegacyProgram](#createderegisterstakelegacyprogram)
  - [createDeregisterStakeProgram](#createderegisterstakeprogram)
  - [createRegisterAndDelegateToProgram](#createregisteranddelegatetoprogram)
  - [createRegisterStakeLegacyProgram](#createregisterstakelegacyprogram)
  - [createRegisterStakeProgram](#createregisterstakeprogram)
  - [createWithdrawProgram](#createwithdrawprogram)

---

# programs

## createDelegateToDRepProgram

Creates a ProgramStep for delegateToDRep operation.
Adds a VoteDelegCert certificate to delegate voting power to a DRep.

For script-controlled credentials, tracks redeemer for evaluation.

**Signature**

```ts
export declare const createDelegateToDRepProgram: (
  params: DelegateToDRepParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

## createDelegateToPoolAndDRepProgram

Creates a ProgramStep for delegateToPoolAndDRep operation.
Adds a StakeVoteDelegCert certificate to delegate both stake and voting power.

For script-controlled credentials, tracks redeemer for evaluation.

**Signature**

```ts
export declare const createDelegateToPoolAndDRepProgram: (
  params: DelegateToPoolAndDRepParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

## createDelegateToPoolProgram

Creates a ProgramStep for delegateToPool operation.
Adds a StakeDelegation certificate to delegate stake to a pool.

For script-controlled credentials, tracks redeemer for evaluation.

**Signature**

```ts
export declare const createDelegateToPoolProgram: (
  params: DelegateToPoolParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

## ~~createDelegateToProgram~~

Creates a ProgramStep for delegateTo operation.
Delegates stake and/or voting power based on parameters provided.

**Signature**

```ts
export declare const createDelegateToProgram: (
  params: DelegateToParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

## createDeregisterStakeLegacyProgram

Creates a ProgramStep for legacy (pre-Conway) stake deregistration.
Adds a StakeDeregistration (CDDL tag 1) certificate with no deposit refund.

**Signature**

```ts
export declare const createDeregisterStakeLegacyProgram: (
  params: DeregisterStakeLegacyParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

## createDeregisterStakeProgram

Creates a ProgramStep for deregisterStake operation.
Adds an UnregCert (Conway-era) certificate to the transaction.
Requires keyDeposit from protocol parameters for the refund.

For script-controlled credentials, tracks redeemer for evaluation.

**Signature**

```ts
export declare const createDeregisterStakeProgram: (
  params: DeregisterStakeParams
) => Effect.Effect<void, TransactionBuilderError, TxContext | TxBuilderConfigTag>
```

Added in v2.0.0

## createRegisterAndDelegateToProgram

Creates a ProgramStep for registerAndDelegateTo operation.
Combines registration and delegation into a single certificate, saving fees.

Supports three modes:

- Pool only: Creates StakeRegDelegCert certificate
- DRep only: Creates VoteRegDelegCert certificate (Conway)
- Both: Creates StakeVoteRegDelegCert certificate (Conway)

For script-controlled credentials, tracks redeemer for evaluation.

**Signature**

```ts
export declare const createRegisterAndDelegateToProgram: (
  params: RegisterAndDelegateToParams
) => Effect.Effect<void, TransactionBuilderError, TxContext | TxBuilderConfigTag>
```

Added in v2.0.0

## createRegisterStakeLegacyProgram

Creates a ProgramStep for legacy (pre-Conway) stake registration.
Adds a StakeRegistration (CDDL tag 0) certificate with no deposit.

**Signature**

```ts
export declare const createRegisterStakeLegacyProgram: (
  params: RegisterStakeLegacyParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

## createRegisterStakeProgram

Creates a ProgramStep for registerStake operation.
Adds a RegCert (Conway-era) certificate to the transaction.
Requires keyDeposit from protocol parameters.

**Signature**

```ts
export declare const createRegisterStakeProgram: (
  params: RegisterStakeParams
) => Effect.Effect<void, TransactionBuilderError, TxContext | TxBuilderConfigTag>
```

Added in v2.0.0

## createWithdrawProgram

Creates a ProgramStep for withdraw operation.
Adds a withdrawal entry to the transaction.

For script-controlled credentials, tracks redeemer for evaluation.
Use amount: 0n to trigger stake validator without withdrawing (coordinator pattern).

**Signature**

```ts
export declare const createWithdrawProgram: (
  params: WithdrawParams
) => Effect.Effect<void, TransactionBuilderError, TxContext | TxBuilderConfigTag>
```

Added in v2.0.0

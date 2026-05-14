---
title: Certificate.ts
nav_order: 35
parent: Modules
---

## Certificate overview

Certificate types and schemas for Cardano Conway-era transactions.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [certificate](#certificate)
  - [AuthCommitteeHotCert (class)](#authcommitteehotcert-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [PoolRegistration (class)](#poolregistration-class)
    - [toJSON (method)](#tojson-method-1)
    - [toString (method)](#tostring-method-1)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-1)
    - [[Equal.symbol] (method)](#equalsymbol-method-1)
    - [[Hash.symbol] (method)](#hashsymbol-method-1)
  - [PoolRetirement (class)](#poolretirement-class)
    - [toJSON (method)](#tojson-method-2)
    - [toString (method)](#tostring-method-2)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-2)
    - [[Equal.symbol] (method)](#equalsymbol-method-2)
    - [[Hash.symbol] (method)](#hashsymbol-method-2)
  - [RegCert (class)](#regcert-class)
    - [toJSON (method)](#tojson-method-3)
    - [toString (method)](#tostring-method-3)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-3)
    - [[Equal.symbol] (method)](#equalsymbol-method-3)
    - [[Hash.symbol] (method)](#hashsymbol-method-3)
  - [RegDrepCert (class)](#regdrepcert-class)
    - [toJSON (method)](#tojson-method-4)
    - [toString (method)](#tostring-method-4)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-4)
    - [[Equal.symbol] (method)](#equalsymbol-method-4)
    - [[Hash.symbol] (method)](#hashsymbol-method-4)
  - [ResignCommitteeColdCert (class)](#resigncommitteecoldcert-class)
    - [toJSON (method)](#tojson-method-5)
    - [toString (method)](#tostring-method-5)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-5)
    - [[Equal.symbol] (method)](#equalsymbol-method-5)
    - [[Hash.symbol] (method)](#hashsymbol-method-5)
  - [StakeDelegation (class)](#stakedelegation-class)
    - [toJSON (method)](#tojson-method-6)
    - [toString (method)](#tostring-method-6)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-6)
    - [[Equal.symbol] (method)](#equalsymbol-method-6)
    - [[Hash.symbol] (method)](#hashsymbol-method-6)
  - [StakeDeregistration (class)](#stakederegistration-class)
    - [toJSON (method)](#tojson-method-7)
    - [toString (method)](#tostring-method-7)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-7)
    - [[Equal.symbol] (method)](#equalsymbol-method-7)
    - [[Hash.symbol] (method)](#hashsymbol-method-7)
  - [StakeRegDelegCert (class)](#stakeregdelegcert-class)
    - [toJSON (method)](#tojson-method-8)
    - [toString (method)](#tostring-method-8)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-8)
    - [[Equal.symbol] (method)](#equalsymbol-method-8)
    - [[Hash.symbol] (method)](#hashsymbol-method-8)
  - [StakeRegistration (class)](#stakeregistration-class)
    - [toJSON (method)](#tojson-method-9)
    - [toString (method)](#tostring-method-9)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-9)
    - [[Equal.symbol] (method)](#equalsymbol-method-9)
    - [[Hash.symbol] (method)](#hashsymbol-method-9)
  - [StakeVoteDelegCert (class)](#stakevotedelegcert-class)
    - [toJSON (method)](#tojson-method-10)
    - [toString (method)](#tostring-method-10)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-10)
    - [[Equal.symbol] (method)](#equalsymbol-method-10)
    - [[Hash.symbol] (method)](#hashsymbol-method-10)
  - [StakeVoteRegDelegCert (class)](#stakevoteregdelegcert-class)
    - [toJSON (method)](#tojson-method-11)
    - [toString (method)](#tostring-method-11)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-11)
    - [[Equal.symbol] (method)](#equalsymbol-method-11)
    - [[Hash.symbol] (method)](#hashsymbol-method-11)
  - [UnregCert (class)](#unregcert-class)
    - [toJSON (method)](#tojson-method-12)
    - [toString (method)](#tostring-method-12)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-12)
    - [[Equal.symbol] (method)](#equalsymbol-method-12)
    - [[Hash.symbol] (method)](#hashsymbol-method-12)
  - [UnregDrepCert (class)](#unregdrepcert-class)
    - [toJSON (method)](#tojson-method-13)
    - [toString (method)](#tostring-method-13)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-13)
    - [[Equal.symbol] (method)](#equalsymbol-method-13)
    - [[Hash.symbol] (method)](#hashsymbol-method-13)
  - [UpdateDrepCert (class)](#updatedrepcert-class)
    - [toJSON (method)](#tojson-method-14)
    - [toString (method)](#tostring-method-14)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-14)
    - [[Equal.symbol] (method)](#equalsymbol-method-14)
    - [[Hash.symbol] (method)](#hashsymbol-method-14)
  - [VoteDelegCert (class)](#votedelegcert-class)
    - [toJSON (method)](#tojson-method-15)
    - [toString (method)](#tostring-method-15)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-15)
    - [[Equal.symbol] (method)](#equalsymbol-method-15)
    - [[Hash.symbol] (method)](#hashsymbol-method-15)
  - [VoteRegDelegCert (class)](#voteregdelegcert-class)
    - [toJSON (method)](#tojson-method-16)
    - [toString (method)](#tostring-method-16)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method-16)
    - [[Equal.symbol] (method)](#equalsymbol-method-16)
    - [[Hash.symbol] (method)](#hashsymbol-method-16)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [model](#model)
  - [Certificate (type alias)](#certificate-type-alias)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [predicates](#predicates)
  - [is](#is)
- [schemas](#schemas)
  - [Certificate](#certificate-1)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)
- [testing](#testing)
  - [arbitrary](#arbitrary)
- [utils](#utils)
  - [CDDLSchema](#cddlschema)

---

# certificate

## AuthCommitteeHotCert (class)

Authorize a committee hot credential (CDDL: auth_committee_hot_cert = 14).

**Signature**

```ts
export declare class AuthCommitteeHotCert
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

## PoolRegistration (class)

Register a stake pool (CDDL: pool_registration = 3).

**Signature**

```ts
export declare class PoolRegistration
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

## PoolRetirement (class)

Retire a stake pool at a given epoch (CDDL: pool_retirement = 4).

**Signature**

```ts
export declare class PoolRetirement
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

## RegCert (class)

Conway-era stake registration with deposit (CDDL: reg_cert = 7).

**Signature**

```ts
export declare class RegCert
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

## RegDrepCert (class)

Register as a DRep (CDDL: reg_drep_cert = 16).

**Signature**

```ts
export declare class RegDrepCert
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

## ResignCommitteeColdCert (class)

Resign a committee cold credential (CDDL: resign_committee_cold_cert = 15).

**Signature**

```ts
export declare class ResignCommitteeColdCert
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

## StakeDelegation (class)

Delegate stake to a pool (CDDL: stake_delegation = 2).

**Signature**

```ts
export declare class StakeDelegation
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

## StakeDeregistration (class)

Deregister a stake credential (CDDL: stake_deregistration = 1).

**Signature**

```ts
export declare class StakeDeregistration
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

## StakeRegDelegCert (class)

Register stake and delegate to a pool in one certificate (CDDL: stake_reg_deleg_cert = 11).

**Signature**

```ts
export declare class StakeRegDelegCert
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

## StakeRegistration (class)

Register a stake credential (CDDL: stake_registration = 0).

**Signature**

```ts
export declare class StakeRegistration
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

## StakeVoteDelegCert (class)

Delegate stake to a pool and voting rights to a DRep (CDDL: stake_vote_deleg_cert = 10).

**Signature**

```ts
export declare class StakeVoteDelegCert
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

## StakeVoteRegDelegCert (class)

Register stake, delegate to a pool, and delegate voting rights to a DRep (CDDL: stake_vote_reg_deleg_cert = 13).

**Signature**

```ts
export declare class StakeVoteRegDelegCert
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

## UnregCert (class)

Conway-era stake deregistration with deposit refund (CDDL: unreg_cert = 8).

**Signature**

```ts
export declare class UnregCert
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

## UnregDrepCert (class)

Unregister as a DRep (CDDL: unreg_drep_cert = 17).

**Signature**

```ts
export declare class UnregDrepCert
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

## UpdateDrepCert (class)

Update DRep metadata anchor (CDDL: update_drep_cert = 18).

**Signature**

```ts
export declare class UpdateDrepCert
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

## VoteDelegCert (class)

Delegate voting rights to a DRep (CDDL: vote_deleg_cert = 9).

**Signature**

```ts
export declare class VoteDelegCert
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

## VoteRegDelegCert (class)

Register stake and delegate voting rights to a DRep (CDDL: vote_reg_deleg_cert = 12).

**Signature**

```ts
export declare class VoteRegDelegCert
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

# encoding

## toCBORBytes

Convert a Certificate to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (certificate: Certificate, options?: CBOR.CodecOptions) => Uint8Array
```

Added in v2.0.0

## toCBORHex

Convert a Certificate to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (certificate: Certificate, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# model

## Certificate (type alias)

Type alias for Certificate.

**Signature**

```ts
export type Certificate = typeof Certificate.Type
```

Added in v2.0.0

# parsing

## fromCBORBytes

Parse a Certificate from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => Certificate
```

Added in v2.0.0

## fromCBORHex

Parse a Certificate from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => Certificate
```

Added in v2.0.0

# predicates

## is

Check if the given value is a valid Certificate.

**Signature**

```ts
export declare const is: (
  u: unknown,
  overrideOptions?: ParseOptions | number
) => u is
  | StakeRegistration
  | StakeDeregistration
  | StakeDelegation
  | PoolRegistration
  | PoolRetirement
  | RegCert
  | UnregCert
  | VoteDelegCert
  | StakeVoteDelegCert
  | StakeRegDelegCert
  | VoteRegDelegCert
  | StakeVoteRegDelegCert
  | AuthCommitteeHotCert
  | ResignCommitteeColdCert
  | RegDrepCert
  | UnregDrepCert
  | UpdateDrepCert
```

Added in v2.0.0

# schemas

## Certificate

Certificate union schema based on Conway CDDL specification

CDDL: certificate =
[
stake_registration
// stake_deregistration
// stake_delegation
// pool_registration
// pool_retirement
// reg_cert
// unreg_cert
// vote_deleg_cert
// stake_vote_deleg_cert
// stake_reg_deleg_cert
// vote_reg_deleg_cert
// stake_vote_reg_deleg_cert
// auth_committee_hot_cert
// resign_committee_cold_cert
// reg_drep_cert
// unreg_drep_cert
// update_drep_cert
]

stake_registration = (0, stake_credential)
stake_deregistration = (1, stake_credential)
stake_delegation = (2, stake_credential, pool_keyhash)
pool_registration = (3, pool_params)
pool_retirement = (4, pool_keyhash, epoch_no)
reg_cert = (7, stake_credential, coin)
unreg_cert = (8, stake_credential, coin)
vote_deleg_cert = (9, stake_credential, drep)
stake_vote_deleg_cert = (10, stake_credential, pool_keyhash, drep)
stake_reg_deleg_cert = (11, stake_credential, pool_keyhash, coin)
vote_reg_deleg_cert = (12, stake_credential, drep, coin)
stake_vote_reg_deleg_cert = (13, stake_credential, pool_keyhash, drep, coin)
auth_committee_hot_cert = (14, committee_cold_credential, committee_hot_credential)
resign_committee_cold_cert = (15, committee_cold_credential, anchor/ nil)
reg_drep_cert = (16, drep_credential, coin, anchor/ nil)
unreg_drep_cert = (17, drep_credential, coin)
update_drep_cert = (18, drep_credential, anchor/ nil)

**Signature**

```ts
export declare const Certificate: Schema.Union<
  [
    typeof StakeRegistration,
    typeof StakeDeregistration,
    typeof StakeDelegation,
    typeof PoolRegistration,
    typeof PoolRetirement,
    typeof RegCert,
    typeof UnregCert,
    typeof VoteDelegCert,
    typeof StakeVoteDelegCert,
    typeof StakeRegDelegCert,
    typeof VoteRegDelegCert,
    typeof StakeVoteRegDelegCert,
    typeof AuthCommitteeHotCert,
    typeof ResignCommitteeColdCert,
    typeof RegDrepCert,
    typeof UnregDrepCert,
    typeof UpdateDrepCert
  ]
>
```

Added in v2.0.0

## FromCBORBytes

CBOR bytes transformation schema for Certificate.

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
    Schema.Union<
      [
        Schema.Tuple2<Schema.Literal<[0n]>, Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>>,
        Schema.Tuple2<Schema.Literal<[1n]>, Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>>,
        Schema.Tuple<
          [
            Schema.Literal<[2n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.Uint8ArrayFromSelf
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[3n]>,
            typeof Schema.Uint8ArrayFromSelf,
            typeof Schema.Uint8ArrayFromSelf,
            typeof Schema.BigIntFromSelf,
            typeof Schema.BigIntFromSelf,
            Schema.TaggedStruct<
              "Tag",
              {
                tag: Schema.Literal<[30]>
                value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
              }
            >,
            typeof Schema.Uint8ArrayFromSelf,
            Schema.Array$<typeof Schema.Uint8ArrayFromSelf>,
            Schema.Array$<
              Schema.SchemaClass<
                readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
                readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
                never
              >
            >,
            Schema.NullOr<Schema.SchemaClass<readonly [string, any], readonly [string, any], never>>
          ]
        >,
        Schema.Tuple<[Schema.Literal<[4n]>, typeof Schema.Uint8ArrayFromSelf, typeof Schema.BigIntFromSelf]>,
        Schema.Tuple<
          [
            Schema.Literal<[7n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.BigIntFromSelf
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[8n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.BigIntFromSelf
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[9n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Union<
              [
                Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple<[Schema.Literal<[2n]>]>,
                Schema.Tuple<[Schema.Literal<[3n]>]>
              ]
            >
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[10n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.Uint8ArrayFromSelf,
            Schema.Union<
              [
                Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple<[Schema.Literal<[2n]>]>,
                Schema.Tuple<[Schema.Literal<[3n]>]>
              ]
            >
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[11n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.Uint8ArrayFromSelf,
            typeof Schema.BigIntFromSelf
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[12n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Union<
              [
                Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple<[Schema.Literal<[2n]>]>,
                Schema.Tuple<[Schema.Literal<[3n]>]>
              ]
            >,
            typeof Schema.BigIntFromSelf
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[13n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.Uint8ArrayFromSelf,
            Schema.Union<
              [
                Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                Schema.Tuple<[Schema.Literal<[2n]>]>,
                Schema.Tuple<[Schema.Literal<[3n]>]>
              ]
            >,
            typeof Schema.BigIntFromSelf
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[14n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[15n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[16n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.BigIntFromSelf,
            Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[17n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            typeof Schema.BigIntFromSelf
          ]
        >,
        Schema.Tuple<
          [
            Schema.Literal<[18n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
          ]
        >
      ]
    >,
    Schema.SchemaClass<
      | StakeRegistration
      | StakeDeregistration
      | StakeDelegation
      | PoolRegistration
      | PoolRetirement
      | RegCert
      | UnregCert
      | VoteDelegCert
      | StakeVoteDelegCert
      | StakeRegDelegCert
      | VoteRegDelegCert
      | StakeVoteRegDelegCert
      | AuthCommitteeHotCert
      | ResignCommitteeColdCert
      | RegDrepCert
      | UnregDrepCert
      | UpdateDrepCert,
      | StakeRegistration
      | StakeDeregistration
      | StakeDelegation
      | PoolRegistration
      | PoolRetirement
      | RegCert
      | UnregCert
      | VoteDelegCert
      | StakeVoteDelegCert
      | StakeRegDelegCert
      | VoteRegDelegCert
      | StakeVoteRegDelegCert
      | AuthCommitteeHotCert
      | ResignCommitteeColdCert
      | RegDrepCert
      | UnregDrepCert
      | UpdateDrepCert,
      never
    >,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for Certificate.

**Signature**

```ts
export declare const FromCBORHex: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<
    Schema.transformOrFail<
      typeof Schema.Uint8ArrayFromSelf,
      Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
      never
    >,
    Schema.transformOrFail<
      Schema.Union<
        [
          Schema.Tuple2<
            Schema.Literal<[0n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>
          >,
          Schema.Tuple2<
            Schema.Literal<[1n]>,
            Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>
          >,
          Schema.Tuple<
            [
              Schema.Literal<[2n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.Uint8ArrayFromSelf
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[3n]>,
              typeof Schema.Uint8ArrayFromSelf,
              typeof Schema.Uint8ArrayFromSelf,
              typeof Schema.BigIntFromSelf,
              typeof Schema.BigIntFromSelf,
              Schema.TaggedStruct<
                "Tag",
                {
                  tag: Schema.Literal<[30]>
                  value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
                }
              >,
              typeof Schema.Uint8ArrayFromSelf,
              Schema.Array$<typeof Schema.Uint8ArrayFromSelf>,
              Schema.Array$<
                Schema.SchemaClass<
                  readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
                  readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
                  never
                >
              >,
              Schema.NullOr<Schema.SchemaClass<readonly [string, any], readonly [string, any], never>>
            ]
          >,
          Schema.Tuple<[Schema.Literal<[4n]>, typeof Schema.Uint8ArrayFromSelf, typeof Schema.BigIntFromSelf]>,
          Schema.Tuple<
            [
              Schema.Literal<[7n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.BigIntFromSelf
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[8n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.BigIntFromSelf
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[9n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Union<
                [
                  Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple<[Schema.Literal<[2n]>]>,
                  Schema.Tuple<[Schema.Literal<[3n]>]>
                ]
              >
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[10n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.Uint8ArrayFromSelf,
              Schema.Union<
                [
                  Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple<[Schema.Literal<[2n]>]>,
                  Schema.Tuple<[Schema.Literal<[3n]>]>
                ]
              >
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[11n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.Uint8ArrayFromSelf,
              typeof Schema.BigIntFromSelf
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[12n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Union<
                [
                  Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple<[Schema.Literal<[2n]>]>,
                  Schema.Tuple<[Schema.Literal<[3n]>]>
                ]
              >,
              typeof Schema.BigIntFromSelf
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[13n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.Uint8ArrayFromSelf,
              Schema.Union<
                [
                  Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
                  Schema.Tuple<[Schema.Literal<[2n]>]>,
                  Schema.Tuple<[Schema.Literal<[3n]>]>
                ]
              >,
              typeof Schema.BigIntFromSelf
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[14n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[15n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[16n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.BigIntFromSelf,
              Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[17n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              typeof Schema.BigIntFromSelf
            ]
          >,
          Schema.Tuple<
            [
              Schema.Literal<[18n]>,
              Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
            ]
          >
        ]
      >,
      Schema.SchemaClass<
        | StakeRegistration
        | StakeDeregistration
        | StakeDelegation
        | PoolRegistration
        | PoolRetirement
        | RegCert
        | UnregCert
        | VoteDelegCert
        | StakeVoteDelegCert
        | StakeRegDelegCert
        | VoteRegDelegCert
        | StakeVoteRegDelegCert
        | AuthCommitteeHotCert
        | ResignCommitteeColdCert
        | RegDrepCert
        | UnregDrepCert
        | UpdateDrepCert,
        | StakeRegistration
        | StakeDeregistration
        | StakeDelegation
        | PoolRegistration
        | PoolRetirement
        | RegCert
        | UnregCert
        | VoteDelegCert
        | StakeVoteDelegCert
        | StakeRegDelegCert
        | VoteRegDelegCert
        | StakeVoteRegDelegCert
        | AuthCommitteeHotCert
        | ResignCommitteeColdCert
        | RegDrepCert
        | UnregDrepCert
        | UpdateDrepCert,
        never
      >,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for Certificate based on Conway specification.

Transforms between CBOR tuple representation and Certificate union.
Each certificate type is encoded as [type_id, ...fields]

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.Union<
    [
      Schema.Tuple2<Schema.Literal<[0n]>, Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>>,
      Schema.Tuple2<Schema.Literal<[1n]>, Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>>,
      Schema.Tuple<
        [
          Schema.Literal<[2n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.Uint8ArrayFromSelf
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[3n]>,
          typeof Schema.Uint8ArrayFromSelf,
          typeof Schema.Uint8ArrayFromSelf,
          typeof Schema.BigIntFromSelf,
          typeof Schema.BigIntFromSelf,
          Schema.TaggedStruct<
            "Tag",
            {
              tag: Schema.Literal<[30]>
              value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
            }
          >,
          typeof Schema.Uint8ArrayFromSelf,
          Schema.Array$<typeof Schema.Uint8ArrayFromSelf>,
          Schema.Array$<
            Schema.SchemaClass<
              readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
              readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
              never
            >
          >,
          Schema.NullOr<Schema.SchemaClass<readonly [string, any], readonly [string, any], never>>
        ]
      >,
      Schema.Tuple<[Schema.Literal<[4n]>, typeof Schema.Uint8ArrayFromSelf, typeof Schema.BigIntFromSelf]>,
      Schema.Tuple<
        [
          Schema.Literal<[7n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.BigIntFromSelf
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[8n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.BigIntFromSelf
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[9n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          Schema.Union<
            [
              Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple<[Schema.Literal<[2n]>]>,
              Schema.Tuple<[Schema.Literal<[3n]>]>
            ]
          >
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[10n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.Uint8ArrayFromSelf,
          Schema.Union<
            [
              Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple<[Schema.Literal<[2n]>]>,
              Schema.Tuple<[Schema.Literal<[3n]>]>
            ]
          >
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[11n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.Uint8ArrayFromSelf,
          typeof Schema.BigIntFromSelf
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[12n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          Schema.Union<
            [
              Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple<[Schema.Literal<[2n]>]>,
              Schema.Tuple<[Schema.Literal<[3n]>]>
            ]
          >,
          typeof Schema.BigIntFromSelf
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[13n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.Uint8ArrayFromSelf,
          Schema.Union<
            [
              Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
              Schema.Tuple<[Schema.Literal<[2n]>]>,
              Schema.Tuple<[Schema.Literal<[3n]>]>
            ]
          >,
          typeof Schema.BigIntFromSelf
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[14n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[15n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[16n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.BigIntFromSelf,
          Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[17n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          typeof Schema.BigIntFromSelf
        ]
      >,
      Schema.Tuple<
        [
          Schema.Literal<[18n]>,
          Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
          Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
        ]
      >
    ]
  >,
  Schema.SchemaClass<
    | StakeRegistration
    | StakeDeregistration
    | StakeDelegation
    | PoolRegistration
    | PoolRetirement
    | RegCert
    | UnregCert
    | VoteDelegCert
    | StakeVoteDelegCert
    | StakeRegDelegCert
    | VoteRegDelegCert
    | StakeVoteRegDelegCert
    | AuthCommitteeHotCert
    | ResignCommitteeColdCert
    | RegDrepCert
    | UnregDrepCert
    | UpdateDrepCert,
    | StakeRegistration
    | StakeDeregistration
    | StakeDelegation
    | PoolRegistration
    | PoolRetirement
    | RegCert
    | UnregCert
    | VoteDelegCert
    | StakeVoteDelegCert
    | StakeRegDelegCert
    | VoteRegDelegCert
    | StakeVoteRegDelegCert
    | AuthCommitteeHotCert
    | ResignCommitteeColdCert
    | RegDrepCert
    | UnregDrepCert
    | UpdateDrepCert,
    never
  >,
  never
>
```

Added in v2.0.0

# testing

## arbitrary

FastCheck arbitrary for Certificate instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<
  | StakeRegistration
  | StakeDeregistration
  | StakeDelegation
  | PoolRegistration
  | PoolRetirement
  | RegCert
  | UnregCert
  | VoteDelegCert
  | StakeVoteDelegCert
  | StakeRegDelegCert
  | VoteRegDelegCert
  | StakeVoteRegDelegCert
  | AuthCommitteeHotCert
  | ResignCommitteeColdCert
  | RegDrepCert
  | UnregDrepCert
  | UpdateDrepCert
>
```

Added in v2.0.0

# utils

## CDDLSchema

**Signature**

```ts
export declare const CDDLSchema: Schema.Union<
  [
    Schema.Tuple2<Schema.Literal<[0n]>, Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>>,
    Schema.Tuple2<Schema.Literal<[1n]>, Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>>,
    Schema.Tuple<
      [
        Schema.Literal<[2n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.Uint8ArrayFromSelf
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[3n]>,
        typeof Schema.Uint8ArrayFromSelf,
        typeof Schema.Uint8ArrayFromSelf,
        typeof Schema.BigIntFromSelf,
        typeof Schema.BigIntFromSelf,
        Schema.TaggedStruct<
          "Tag",
          {
            tag: Schema.Literal<[30]>
            value: Schema.Tuple2<typeof Schema.BigIntFromSelf, typeof Schema.BigIntFromSelf>
          }
        >,
        typeof Schema.Uint8ArrayFromSelf,
        Schema.Array$<typeof Schema.Uint8ArrayFromSelf>,
        Schema.Array$<
          Schema.SchemaClass<
            readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
            readonly [0n, bigint | null, any, any] | readonly [1n, bigint | null, string] | readonly [2n, string],
            never
          >
        >,
        Schema.NullOr<Schema.SchemaClass<readonly [string, any], readonly [string, any], never>>
      ]
    >,
    Schema.Tuple<[Schema.Literal<[4n]>, typeof Schema.Uint8ArrayFromSelf, typeof Schema.BigIntFromSelf]>,
    Schema.Tuple<
      [
        Schema.Literal<[7n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.BigIntFromSelf
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[8n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.BigIntFromSelf
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[9n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        Schema.Union<
          [
            Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple<[Schema.Literal<[2n]>]>,
            Schema.Tuple<[Schema.Literal<[3n]>]>
          ]
        >
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[10n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.Uint8ArrayFromSelf,
        Schema.Union<
          [
            Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple<[Schema.Literal<[2n]>]>,
            Schema.Tuple<[Schema.Literal<[3n]>]>
          ]
        >
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[11n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.Uint8ArrayFromSelf,
        typeof Schema.BigIntFromSelf
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[12n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        Schema.Union<
          [
            Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple<[Schema.Literal<[2n]>]>,
            Schema.Tuple<[Schema.Literal<[3n]>]>
          ]
        >,
        typeof Schema.BigIntFromSelf
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[13n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.Uint8ArrayFromSelf,
        Schema.Union<
          [
            Schema.Tuple2<Schema.Literal<[0n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple2<Schema.Literal<[1n]>, typeof Schema.Uint8ArrayFromSelf>,
            Schema.Tuple<[Schema.Literal<[2n]>]>,
            Schema.Tuple<[Schema.Literal<[3n]>]>
          ]
        >,
        typeof Schema.BigIntFromSelf
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[14n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[15n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[16n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.BigIntFromSelf,
        Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[17n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        typeof Schema.BigIntFromSelf
      ]
    >,
    Schema.Tuple<
      [
        Schema.Literal<[18n]>,
        Schema.Tuple2<Schema.Literal<[0n, 1n]>, typeof Schema.Uint8ArrayFromSelf>,
        Schema.NullishOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
      ]
    >
  ]
>
```

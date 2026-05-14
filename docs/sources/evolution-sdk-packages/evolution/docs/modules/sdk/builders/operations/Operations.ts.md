---
title: sdk/builders/operations/Operations.ts
nav_order: 126
parent: Modules
---

## Operations overview

---

<h2 class="text-delta">Table of contents</h2>

- [governance](#governance)
  - [AuthCommitteeHotParams (interface)](#authcommitteehotparams-interface)
  - [DeregisterDRepParams (interface)](#deregisterdrepparams-interface)
  - [ProposeParams (interface)](#proposeparams-interface)
  - [RegisterDRepParams (interface)](#registerdrepparams-interface)
  - [ResignCommitteeColdParams (interface)](#resigncommitteecoldparams-interface)
  - [UpdateDRepParams (interface)](#updatedrepparams-interface)
  - [VoteParams (interface)](#voteparams-interface)
- [metadata](#metadata)
  - [AttachMetadataParams (interface)](#attachmetadataparams-interface)
- [payment](#payment)
  - [SendAllParams (interface)](#sendallparams-interface)
- [pool](#pool)
  - [RegisterPoolParams (interface)](#registerpoolparams-interface)
  - [RetirePoolParams (interface)](#retirepoolparams-interface)
- [signers](#signers)
  - [AddSignerParams (interface)](#addsignerparams-interface)
- [staking](#staking)
  - [DelegateToDRepParams (interface)](#delegatetodrepparams-interface)
  - [~~DelegateToParams~~ (interface)](#delegatetoparams-interface)
  - [DelegateToPoolAndDRepParams (interface)](#delegatetopoolanddrepparams-interface)
  - [DelegateToPoolParams (interface)](#delegatetopoolparams-interface)
  - [DeregisterStakeLegacyParams (interface)](#deregisterstakelegacyparams-interface)
  - [DeregisterStakeParams (interface)](#deregisterstakeparams-interface)
  - [RegisterAndDelegateToParams (interface)](#registeranddelegatetoparams-interface)
  - [RegisterStakeLegacyParams (interface)](#registerstakelegacyparams-interface)
  - [RegisterStakeParams (interface)](#registerstakeparams-interface)
  - [WithdrawParams (interface)](#withdrawparams-interface)
- [utils](#utils)
  - [CollectFromParams (interface)](#collectfromparams-interface)
  - [MintTokensParams (interface)](#minttokensparams-interface)
  - [PayToAddressParams (interface)](#paytoaddressparams-interface)
  - [ReadFromParams (interface)](#readfromparams-interface)
- [validity](#validity)
  - [ValidityParams (interface)](#validityparams-interface)

---

# governance

## AuthCommitteeHotParams (interface)

Parameters for authorizing a committee hot credential.

Authorizes a hot credential to act on behalf of a cold committee credential.
The cold credential is kept offline for security; the hot credential signs
governance actions.

**Signature**

```ts
export interface AuthCommitteeHotParams {
  /** The cold credential (offline, secure) */
  readonly coldCredential: Credential.Credential
  /** The hot credential to authorize (online, signing) */
  readonly hotCredential: Credential.Credential
  /** Redeemer for script-controlled cold credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## DeregisterDRepParams (interface)

Parameters for deregistering as a DRep.

Removes DRep registration and reclaims the deposit.

**Signature**

```ts
export interface DeregisterDRepParams {
  /** The DRep credential to deregister */
  readonly drepCredential: Credential.Credential
  /** Redeemer for script-controlled DRep credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## ProposeParams (interface)

Parameters for proposing governance actions.

Submits a governance action proposal.
The deposit is automatically fetched from protocol parameters (like registerStake).
Call .propose() multiple times to submit multiple proposals in one transaction.

**Signature**

```ts
export interface ProposeParams {
  /** The governance action to propose */
  readonly governanceAction: GovernanceAction.GovernanceAction
  /** Reward account for deposit refund when proposal is finalized */
  readonly rewardAccount: RewardAccount.RewardAccount
  /** Optional anchor with metadata URL and hash */
  readonly anchor: Anchor.Anchor | null
}
```

Added in v2.0.0

## RegisterDRepParams (interface)

Parameters for registering as a DRep.

Registers a credential as a Delegated Representative for governance.
Requires paying a deposit.

**Signature**

```ts
export interface RegisterDRepParams {
  /** The credential to register as a DRep */
  readonly drepCredential: Credential.Credential
  /** Optional metadata anchor (URL + hash) */
  readonly anchor?: Anchor.Anchor
  /** Redeemer for script-controlled DRep credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## ResignCommitteeColdParams (interface)

Parameters for resigning from the constitutional committee.

Submits a resignation from committee membership.

**Signature**

```ts
export interface ResignCommitteeColdParams {
  /** The cold credential resigning */
  readonly coldCredential: Credential.Credential
  /** Optional anchor with resignation rationale */
  readonly anchor?: Anchor.Anchor
  /** Redeemer for script-controlled cold credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## UpdateDRepParams (interface)

Parameters for updating DRep metadata.

Updates the anchor (metadata URL + hash) for a registered DRep.

**Signature**

```ts
export interface UpdateDRepParams {
  /** The DRep credential to update */
  readonly drepCredential: Credential.Credential
  /** New metadata anchor (URL + hash) */
  readonly anchor?: Anchor.Anchor
  /** Redeemer for script-controlled DRep credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## VoteParams (interface)

Parameters for submitting votes on governance actions.

Submits voting procedures to vote on governance proposals.
Supports multiple voters voting on multiple proposals in a single transaction.

For script-controlled voters (DRep, CC member, or stake pool with script credential),
provide a redeemer to satisfy the vote purpose validator.

**Signature**

```ts
export interface VoteParams {
  /** Voting procedures to submit - see VotingProcedures.singleVote() for simple cases */
  readonly votingProcedures: VotingProcedures.VotingProcedures
  /** Redeemer for script-controlled voters (vote purpose) */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

# metadata

## AttachMetadataParams (interface)

Parameters for attaching metadata to transaction.

Metadata is attached to the auxiliary data section of the transaction.
Each metadata entry is identified by a label (0-2^64-1) following CIP-10 standard.

Common labels:

- 674n: Message/comment metadata (CIP-20)
- 721n: NFT metadata (CIP-25)
- 777n: Royalty metadata (CIP-27)

**Signature**

```ts
export interface AttachMetadataParams {
  /** Metadata label (bigint 0-2^64-1). See CIP-10 for standard labels. */
  readonly label: Metadata.MetadataLabel
  /** Metadata content as TransactionMetadatum */
  readonly metadata: TransactionMetadatum.TransactionMetadatum
}
```

Added in v2.0.0

# payment

## SendAllParams (interface)

Parameters for sending all wallet assets to a recipient address.

This operation collects all wallet UTxOs and creates a single output
containing all assets minus the transaction fee. It's commonly used for:

- Draining a wallet completely
- Consolidating all UTxOs into a single output
- Migrating funds to a new address

**Signature**

```ts
export interface SendAllParams {
  /** The recipient address to receive all assets */
  readonly to: CoreAddress.Address
}
```

Added in v2.0.0

# pool

## RegisterPoolParams (interface)

Parameters for registering a stake pool.

Registers a new stake pool with the specified parameters.
Also used for updating existing pool parameters.

**Signature**

```ts
export interface RegisterPoolParams {
  /** Complete pool parameters including operator, VRF key, costs, etc. */
  readonly poolParams: PoolParams.PoolParams
}
```

Added in v2.0.0

## RetirePoolParams (interface)

Parameters for retiring a stake pool.

Announces pool retirement effective at the specified epoch.

**Signature**

```ts
export interface RetirePoolParams {
  /** The pool key hash of the pool to retire */
  readonly poolKeyHash: PoolKeyHash.PoolKeyHash
  /** Epoch at which retirement takes effect */
  readonly epoch: EpochNo.EpochNo
}
```

Added in v2.0.0

# signers

## AddSignerParams (interface)

Parameters for adding a required signer to the transaction.

Required signers must sign the transaction even if they don't control any inputs.
This is commonly used for scripts that check for specific signers in their validation logic.

**Signature**

```ts
export interface AddSignerParams {
  /** The key hash that must sign the transaction */
  readonly keyHash: KeyHash.KeyHash
}
```

Added in v2.0.0

# staking

## DelegateToDRepParams (interface)

Parameters for delegating voting power to a DRep.

Creates a VoteDelegCert certificate (Conway era).

**Signature**

```ts
export interface DelegateToDRepParams {
  /** The stake credential delegating */
  readonly stakeCredential: Credential.Credential
  /** DRep to delegate voting power to */
  readonly drep: DRep.DRep
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## ~~DelegateToParams~~ (interface)

Parameters for delegating stake and/or voting power.

Supports three delegation modes:

- **Stake only**: Provide `poolKeyHash` to delegate to a stake pool
- **Vote only**: Provide `drep` to delegate voting power (Conway)
- **Both**: Provide both for combined stake + vote delegation

**Signature**

```ts
export interface DelegateToParams {
  /** The stake credential delegating */
  readonly stakeCredential: Credential.Credential
  /** Pool to delegate stake to (optional) */
  readonly poolKeyHash?: PoolKeyHash.PoolKeyHash
  /** DRep to delegate voting power to (optional, Conway) */
  readonly drep?: DRep.DRep
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## DelegateToPoolAndDRepParams (interface)

Parameters for delegating both stake and voting power.

Creates a StakeVoteDelegCert certificate (Conway era).

**Signature**

```ts
export interface DelegateToPoolAndDRepParams {
  /** The stake credential delegating */
  readonly stakeCredential: Credential.Credential
  /** Pool to delegate stake to */
  readonly poolKeyHash: PoolKeyHash.PoolKeyHash
  /** DRep to delegate voting power to */
  readonly drep: DRep.DRep
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## DelegateToPoolParams (interface)

Parameters for delegating stake to a pool.

Creates a StakeDelegation certificate.

**Signature**

```ts
export interface DelegateToPoolParams {
  /** The stake credential delegating */
  readonly stakeCredential: Credential.Credential
  /** Pool to delegate stake to */
  readonly poolKeyHash: PoolKeyHash.PoolKeyHash
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## DeregisterStakeLegacyParams (interface)

Parameters for legacy (pre-Conway) stake credential deregistration.

Creates a StakeDeregistration certificate (CDDL tag 1) with no deposit refund.
This is the pre-Conway deregistration format still accepted on mainnet.

**Signature**

```ts
export interface DeregisterStakeLegacyParams {
  /** The stake credential to deregister */
  readonly stakeCredential: Credential.Credential
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## DeregisterStakeParams (interface)

Parameters for deregistering a stake credential.

Removes a stake credential from the chain and reclaims the deposit.
Must withdraw all rewards before deregistering.

**Signature**

```ts
export interface DeregisterStakeParams {
  /** The stake credential to deregister */
  readonly stakeCredential: Credential.Credential
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## RegisterAndDelegateToParams (interface)

Parameters for registering AND delegating in a single certificate.

Combines registration and delegation into one certificate, saving fees.
Available in Conway era onwards.

**Signature**

```ts
export interface RegisterAndDelegateToParams {
  /** The stake credential to register and delegate */
  readonly stakeCredential: Credential.Credential
  /** Pool to delegate stake to (optional) */
  readonly poolKeyHash?: PoolKeyHash.PoolKeyHash
  /** DRep to delegate voting power to (optional) */
  readonly drep?: DRep.DRep
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## RegisterStakeLegacyParams (interface)

Parameters for legacy (pre-Conway) stake credential registration.

Creates a StakeRegistration certificate (CDDL tag 0) with no deposit.
This is the pre-Conway registration format still accepted on mainnet.

**Signature**

```ts
export interface RegisterStakeLegacyParams {
  /** The stake credential to register (key hash or script hash) */
  readonly stakeCredential: Credential.Credential
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## RegisterStakeParams (interface)

Parameters for registering a stake credential.

Registers a stake credential on-chain, enabling delegation and rewards.
Requires paying a deposit (currently 2 ADA on mainnet).

**Signature**

```ts
export interface RegisterStakeParams {
  /** The stake credential to register (key hash or script hash) */
  readonly stakeCredential: Credential.Credential
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## WithdrawParams (interface)

Parameters for withdrawing staking rewards.

Withdraws accumulated rewards from a stake credential.
Use amount: 0n to trigger a stake validator without withdrawing rewards
(useful for the coordinator pattern).

**Signature**

```ts
export interface WithdrawParams {
  /** The stake credential to withdraw from */
  readonly stakeCredential: Credential.Credential
  /** Amount of lovelace to withdraw */
  readonly amount: bigint
  /** Redeemer for script-controlled stake credentials */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

# utils

## CollectFromParams (interface)

Parameters for collectFrom operation.

The redeemer supports three modes:

- **Static**: Direct `Data` value when index isn't needed
- **Self**: `(input: IndexedInput) => Data` callback for per-input redeemers
- **Batch**: `{ all: (inputs) => Data, inputs: UTxO[] }` for multi-input coordination

**Signature**

```ts
export interface CollectFromParams {
  /** UTxOs to consume as transaction inputs */
  readonly inputs: ReadonlyArray<UTxO.UTxO>
  /** Optional redeemer for script-locked UTxOs (static, self, or batch mode) */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## MintTokensParams (interface)

Parameters for mint operation.

The redeemer supports three modes:

- **Static**: Direct `Data` value when index isn't needed
- **Self**: `(input: IndexedInput) => Data` callback (index is policy index)
- **Batch**: `{ all: (inputs) => Data, inputs: UTxO[] }` for multi-policy coordination

**Signature**

```ts
export interface MintTokensParams {
  /** Tokens to mint (positive) or burn (negative), excluding lovelace */
  readonly assets: CoreAssets.Assets
  /** Optional redeemer for Plutus minting policies (static, self, or batch mode) */
  readonly redeemer?: RedeemerBuilder.RedeemerArg
  /** Optional label for debugging script failures - identifies this operation in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## PayToAddressParams (interface)

**Signature**

```ts
export interface PayToAddressParams {
  readonly address: CoreAddress.Address
  readonly assets: CoreAssets.Assets
  readonly datum?: CoreDatumOption.DatumOption
  /** Optional script to store as a reference script in the output */
  readonly script?: CoreScript.Script
}
```

## ReadFromParams (interface)

**Signature**

```ts
export interface ReadFromParams {
  readonly referenceInputs: ReadonlyArray<UTxO.UTxO> // Mandatory: UTxOs to read as reference inputs
}
```

# validity

## ValidityParams (interface)

Parameters for setting transaction validity interval.

Both bounds are optional:

- `from`: Transaction is valid after this time (validityIntervalStart)
- `to`: Transaction expires after this time (ttl)

Times are in Unix milliseconds and will be converted to slots based on network config.

**Signature**

```ts
export interface ValidityParams {
  /** Transaction valid after this Unix time (milliseconds). Converted to slot. */
  readonly from?: UnixTime.UnixTime
  /** Transaction expires after this Unix time (milliseconds). Converted to slot. */
  readonly to?: UnixTime.UnixTime
}
```

Added in v2.0.0

---
title: sdk/builders/TransactionBuilder.ts
nav_order: 147
parent: Modules
---

## TransactionBuilder overview

Transaction builder storing a sequence of deferred operations that assemble and balance a transaction.

Added in v2.0.0

## Execution Model

The builder pattern:

- **Immutable configuration** at construction (protocol params, change address, available UTxOs)
- **ProgramSteps array** accumulates deferred effects via chainable API methods
- **Fresh state per build()** — each execution creates new Ref instances, runs all programs sequentially
- **Deferred composition** — no I/O or state updates occur until build() is invoked

Key invariant: calling `build()` twice with the same builder instance produces two independent results
with no cross-contamination because fresh state (Refs) is created each time.

## Coin Selection

Automatic coin selection selects UTxOs from `availableUtxos` to satisfy transaction outputs and fees.
The `collectFrom()` method allows manual input selection; automatic selection excludes these to prevent
double-spending. UTxOs can come from any source (wallet, DeFi protocols, other participants, etc.).

---

<h2 class="text-delta">Table of contents</h2>

- [builder-interfaces](#builder-interfaces)
  - [ReadOnlyTransactionBuilder (interface)](#readonlytransactionbuilder-interface)
  - [SigningTransactionBuilder (interface)](#signingtransactionbuilder-interface)
  - [TransactionBuilder (type alias)](#transactionbuilder-type-alias)
  - [TransactionBuilderBase (interface)](#transactionbuilderbase-interface)
- [config](#config)
  - [BuildOptions (interface)](#buildoptions-interface)
  - [ProtocolParameters (interface)](#protocolparameters-interface)
  - [TxBuilderConfig (interface)](#txbuilderconfig-interface)
  - [UnfrackAdaOptions (interface)](#unfrackadaoptions-interface)
  - [UnfrackOptions (interface)](#unfrackoptions-interface)
  - [UnfrackTokenOptions (interface)](#unfracktokenoptions-interface)
- [constructors](#constructors)
  - [makeTxBuilder](#maketxbuilder)
- [context](#context)
  - [AvailableUtxosTag (class)](#availableutxostag-class)
  - [BuildOptionsTag (class)](#buildoptionstag-class)
  - [ChangeAddressTag (class)](#changeaddresstag-class)
  - [PhaseContextTag (class)](#phasecontexttag-class)
  - [ProtocolParametersTag (class)](#protocolparameterstag-class)
  - [TxBuilderConfigTag (class)](#txbuilderconfigtag-class)
  - [TxContext (class)](#txcontext-class)
- [errors](#errors)
  - [EvaluationError (class)](#evaluationerror-class)
  - [ScriptFailure (interface)](#scriptfailure-interface)
  - [TransactionBuilderError (class)](#transactionbuildererror-class)
- [model](#model)
  - [ChainResult (interface)](#chainresult-interface)
  - [EvaluationContext (interface)](#evaluationcontext-interface)
  - [Evaluator (interface)](#evaluator-interface)
  - [ProgramStep (type alias)](#programstep-type-alias)
- [state](#state)
  - [DeferredRedeemerData (interface)](#deferredredeemerdata-interface)
  - [Phase (type alias)](#phase-type-alias)
  - [PhaseContext (interface)](#phasecontext-interface)
  - [PhaseResult (interface)](#phaseresult-interface)
  - [RedeemerData (interface)](#redeemerdata-interface)
  - [TxBuilderState (interface)](#txbuilderstate-interface)
- [utilities](#utilities)
  - [voterToKey](#votertokey)

---

# builder-interfaces

## ReadOnlyTransactionBuilder (interface)

Transaction builder for read-only wallets (ReadOnlyWallet or undefined).

Builds transactions that cannot be signed. The build() method returns a TransactionResultBase
which provides query methods like toTransaction() but NOT signing capabilities.

This builder type is returned when makeTxBuilder() is called with a read-only wallet or no wallet.
Type narrowing happens automatically at construction time - no call-site guards needed.

**Signature**

```ts
export interface ReadOnlyTransactionBuilder extends TransactionBuilderBase {
  /**
   * Execute all queued operations and return a transaction result via Promise.
   *
   * Creates fresh state and runs all accumulated ProgramSteps sequentially.
   * Can be called multiple times on the same builder instance with independent results.
   *
   * @since 2.0.0
   * @category completion-methods
   */
  readonly build: (options?: BuildOptions) => Promise<TransactionResultBase>

  /**
   * Execute all queued operations and return a transaction result via Effect.
   *
   * Creates fresh state and runs all accumulated ProgramSteps sequentially.
   * Suitable for Effect-TS compositional workflows and error handling.
   *
   * @since 2.0.0
   * @category completion-methods
   */
  readonly buildEffect: (
    options?: BuildOptions
  ) => Effect.Effect<
    TransactionResultBase,
    TransactionBuilderError | EvaluationError | Wallet.WalletError | Provider.ProviderError,
    never
  >

  /**
   * Execute all queued operations with explicit error handling via Either.
   *
   * Creates fresh state and runs all accumulated ProgramSteps sequentially.
   * Returns `Either<Result, Error>` for pattern-matched error recovery.
   *
   * @since 2.0.0
   * @category completion-methods
   */
  readonly buildEither: (
    options?: BuildOptions
  ) => Promise<
    Either<
      TransactionResultBase,
      TransactionBuilderError | EvaluationError | Wallet.WalletError | Provider.ProviderError
    >
  >
}
```

Added in v2.0.0

## SigningTransactionBuilder (interface)

Transaction builder for signing wallets (SigningWallet or ApiWallet).

Builds transactions that can be signed. The build() method returns a SignBuilder
which provides sign(), signWithWitness(), and other signing capabilities.

This builder type is returned when makeTxBuilder() is called with a signing wallet.
Type narrowing happens automatically at construction time - no call-site guards needed.

**Signature**

```ts
export interface SigningTransactionBuilder extends TransactionBuilderBase {
  /**
   * Execute all queued operations and return a signing-ready transaction via Promise.
   *
   * Creates fresh state and runs all accumulated ProgramSteps sequentially.
   * Can be called multiple times on the same builder instance with independent results.
   *
   * @since 2.0.0
   * @category completion-methods
   */
  readonly build: (options?: BuildOptions) => Promise<SignBuilder>

  /**
   * Execute all queued operations and return a signing-ready transaction via Effect.
   *
   * Creates fresh state and runs all accumulated ProgramSteps sequentially.
   * Suitable for Effect-TS compositional workflows and error handling.
   *
   * @since 2.0.0
   * @category completion-methods
   */
  readonly buildEffect: (
    options?: BuildOptions
  ) => Effect.Effect<
    SignBuilder,
    TransactionBuilderError | EvaluationError | Wallet.WalletError | Provider.ProviderError,
    never
  >

  /**
   * Execute all queued operations with explicit error handling via Either.
   *
   * Creates fresh state and runs all accumulated ProgramSteps sequentially.
   * Returns `Either<Result, Error>` for pattern-matched error recovery.
   *
   * @since 2.0.0
   * @category completion-methods
   */
  readonly buildEither: (
    options?: BuildOptions
  ) => Promise<
    Either<SignBuilder, TransactionBuilderError | EvaluationError | Wallet.WalletError | Provider.ProviderError>
  >
}
```

Added in v2.0.0

## TransactionBuilder (type alias)

Union type for all transaction builders.
Use specific types (SigningTransactionBuilder or ReadOnlyTransactionBuilder) when you know the wallet type.

**Signature**

```ts
export type TransactionBuilder = SigningTransactionBuilder | ReadOnlyTransactionBuilder
```

Added in v2.0.0

## TransactionBuilderBase (interface)

Base interface for both signing and read-only transaction builders.
Provides chainable builder methods common to both.

**Signature**

````ts
export interface TransactionBuilderBase {
  /**
   * Append a payment output to the transaction.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category builder-methods
   */
  readonly payToAddress: (params: PayToAddressParams) => this

  /**
   * Specify transaction inputs from provided UTxOs.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category builder-methods
   */
  readonly collectFrom: (params: CollectFromParams) => this

  /**
   * Send all wallet assets to a recipient address.
   *
   * This operation collects all wallet UTxOs and creates a single output
   * containing all assets minus the transaction fee. No change output is created.
   *
   * Use cases:
   * - Draining a wallet completely
   * - Consolidating all UTxOs into a single output
   * - Migrating funds to a new address
   *
   * **Important**: This operation is mutually exclusive with `payToAddress` and `collectFrom`.
   * When `sendAll` is used, all wallet UTxOs are automatically collected and the output
   * is automatically created. Any existing outputs or inputs will cause an error.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import { Address } from "@evolution-sdk/evolution"
   *
   * const tx = await client
   *   .newTx()
   *   .sendAll({ to: Address.fromBech32("addr1...") })
   *   .build()
   * ```
   *
   * @since 2.0.0
   * @category builder-methods
   */
  readonly sendAll: (params: SendAllParams) => this

  /**
   * Attach a script to the transaction.
   *
   * Scripts must be attached before being referenced by transaction inputs, minting policies,
   * or certificate operations. The script is stored in the builder state and indexed by its hash
   * for efficient lookup during transaction assembly.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import * as Script from "../../Script.js"
   * import * as NativeScripts from "../../NativeScripts.js"
   *
   * const nativeScript = NativeScripts.makeScriptPubKey(keyHashBytes)
   * const script = Script.fromNativeScript(nativeScript)
   *
   * const tx = await builder
   *   .attachScript({ script })
   *   .mintAssets({ assets: { "<policyId><assetName>": 1000n } })
   *   .build()
   * ```
   *
   * @since 2.0.0
   * @category builder-methods
   */
  readonly attachScript: (params: { script: CoreScript.Script }) => this

  /**
   * Mint or burn native tokens.
   *
   * Minting creates new tokens, burning destroys existing tokens.
   * - Positive amounts: mint new tokens
   * - Negative amounts: burn existing tokens
   *
   * Can be called multiple times; mints are merged by PolicyId and AssetName.
   * If minting from a script policy, provide the redeemer and attach the script via attachScript().
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * // Mint tokens from a native script policy
   * const tx = await builder
   *   .mintAssets({
   *     assets: {
   *       "<policyId><assetName>": 1000n
   *     }
   *   })
   *   .build()
   *
   * // Mint from Plutus script policy with redeemer
   * const tx = await builder
   *   .attachScript(mintingScript)
   *   .mintAssets({
   *     assets: {
   *       "<policyId><assetName>": 1000n
   *     },
   *     redeemer: myRedeemer
   *   })
   *   .build()
   * ```
   *
   * @since 2.0.0
   * @category builder-methods
   */
  readonly mintAssets: (params: MintTokensParams) => this

  /**
   * Add reference inputs to the transaction.
   *
   * Reference inputs allow reading UTxO data (datums, reference scripts) without consuming them.
   * They are commonly used to:
   * - Reference validators/scripts stored on-chain (reduces tx size and fees)
   * - Read datum values without spending the UTxO
   * - Share scripts across multiple transactions
   *
   * Reference scripts incur tiered fees based on size:
   * - Tier 1 (0-25KB): 15 lovelace/byte
   * - Tier 2 (25-50KB): 25 lovelace/byte
   * - Tier 3 (50-200KB): 100 lovelace/byte
   * - Maximum: 200KB total limit
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import * as UTxO from "../../UTxO.js"
   *
   * // Use reference script stored on-chain instead of attaching to transaction
   * const refScriptUtxo = await provider.getUtxoByTxHash("abc123...")
   *
   * const tx = await builder
   *   .readFrom({ referenceInputs: [refScriptUtxo] })
   *   .collectFrom({ inputs: [scriptUtxo], redeemer: myRedeemer })
   *   .build()
   * ```
   *
   * @since 2.0.0
   * @category builder-methods
   */
  readonly readFrom: (params: ReadFromParams) => this

  /**
   * Register a stake credential on-chain.
   *
   * Creates a stake registration certificate, enabling the credential to delegate
   * to pools and receive rewards. Requires paying a stake key deposit (currently 2 ADA).
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly registerStake: (params: RegisterStakeParams) => this

  /**
   * Register a stake credential using the legacy (pre-Conway) certificate format.
   *
   * Creates a StakeRegistration certificate (CDDL tag 0) with no deposit.
   * This is the pre-Conway registration format still accepted on mainnet and
   * is what most wallets use today.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly registerStakeLegacy: (params: RegisterStakeLegacyParams) => this

  /**
   * Deregister a stake credential from the chain.
   *
   * Removes the stake credential registration and reclaims the deposit.
   * All rewards must be withdrawn before deregistering.
   *
   * For script-controlled credentials, provide a redeemer. The redeemer can use:
   * - **Static**: Direct Data value
   * - **Self**: Callback receiving the indexed certificate
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly deregisterStake: (params: DeregisterStakeParams) => this

  /**
   * Deregister a stake credential using the legacy (pre-Conway) certificate format.
   *
   * Creates a StakeDeregistration certificate (CDDL tag 1) with no deposit refund.
   * This is the pre-Conway deregistration format still accepted on mainnet.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly deregisterStakeLegacy: (params: DeregisterStakeLegacyParams) => this

  /**
   * Delegate stake and/or voting power to a pool or DRep.
   *
   * Supports three delegation modes:
   * - **Stake only**: Provide `poolKeyHash` to delegate to a stake pool
   * - **Vote only**: Provide `drep` to delegate governance voting power (Conway)
   * - **Both**: Provide both for combined stake + vote delegation
   *
   * For script-controlled credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @deprecated Use delegateToPool, delegateToDRep, or delegateToPoolAndDRep instead
   * @since 2.0.0
   * @category staking-methods
   */
  readonly delegateTo: (params: DelegateToParams) => this

  /**
   * Delegate stake to a pool.
   *
   * Creates a StakeDelegation certificate to delegate your stake credential
   * to a specific stake pool for earning staking rewards.
   *
   * For script-controlled credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly delegateToPool: (params: DelegateToPoolParams) => this

  /**
   * Delegate voting power to a DRep.
   *
   * Creates a VoteDelegCert certificate to delegate your governance voting power
   * to a Delegated Representative (Conway era).
   *
   * For script-controlled credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly delegateToDRep: (params: DelegateToDRepParams) => this

  /**
   * Delegate both stake and voting power.
   *
   * Creates a StakeVoteDelegCert certificate to simultaneously delegate your
   * stake to a pool and your voting power to a DRep (Conway era).
   *
   * For script-controlled credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly delegateToPoolAndDRep: (params: DelegateToPoolAndDRepParams) => this

  /**
   * Withdraw staking rewards from a stake credential.
   *
   * Withdraws accumulated rewards to the transaction's change address.
   * Use `amount: 0n` to trigger a stake validator without withdrawing rewards
   * (useful for the coordinator pattern).
   *
   * For script-controlled credentials, provide a redeemer. The redeemer can use:
   * - **Static**: Direct Data value
   * - **Self**: Callback receiving the indexed withdrawal
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly withdraw: (params: WithdrawParams) => this

  /**
   * Register a stake credential and delegate in a single certificate.
   *
   * Combines registration and delegation into one certificate, reducing
   * transaction size and fees. Available in Conway era onwards.
   *
   * Supports three delegation modes:
   * - **Stake only**: Provide `poolKeyHash` to register and delegate to pool
   * - **Vote only**: Provide `drep` to register and delegate voting power
   * - **Both**: Provide both for combined registration + delegation
   *
   * For script-controlled credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category staking-methods
   */
  readonly registerAndDelegateTo: (params: RegisterAndDelegateToParams) => this

  /**
   * Register as a Delegated Representative (DRep).
   *
   * Registers a credential as a DRep for governance voting. Requires paying
   * a DRep deposit. Optionally provide an anchor with metadata URL and hash.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category governance-methods
   */
  readonly registerDRep: (params: RegisterDRepParams) => this

  /**
   * Update DRep metadata anchor.
   *
   * Updates the anchor (metadata URL + hash) for a registered DRep.
   * For script-controlled DRep credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category governance-methods
   */
  readonly updateDRep: (params: UpdateDRepParams) => this

  /**
   * Deregister as a DRep.
   *
   * Removes DRep registration and reclaims the deposit.
   * For script-controlled DRep credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category governance-methods
   */
  readonly deregisterDRep: (params: DeregisterDRepParams) => this

  /**
   * Authorize a committee hot credential.
   *
   * Authorizes a hot credential to act on behalf of a cold committee credential.
   * The cold credential is kept offline for security; the hot credential signs
   * governance actions.
   *
   * For script-controlled cold credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category governance-methods
   */
  readonly authCommitteeHot: (params: AuthCommitteeHotParams) => this

  /**
   * Resign from the constitutional committee.
   *
   * Submits a resignation from committee membership. Optionally provide
   * an anchor with resignation rationale.
   *
   * For script-controlled cold credentials, provide a redeemer.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category governance-methods
   */
  readonly resignCommitteeCold: (params: ResignCommitteeColdParams) => this

  /**
   * Register or update a stake pool.
   *
   * Registers a new stake pool or updates existing pool parameters.
   * Pool parameters include operator key, VRF key, costs, margin, reward account, etc.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category pool-methods
   */
  readonly registerPool: (params: RegisterPoolParams) => this

  /**
   * Retire a stake pool.
   *
   * Announces pool retirement effective at the specified epoch.
   * The pool will continue operating until the retirement epoch.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @since 2.0.0
   * @category pool-methods
   */
  readonly retirePool: (params: RetirePoolParams) => this

  /**
   * Set the transaction validity interval.
   *
   * Configures the time window during which the transaction is valid:
   * - `from`: Transaction is valid after this time (converted to validityIntervalStart slot)
   * - `to`: Transaction expires after this time (converted to ttl slot)
   *
   * Times are Unix timestamps in milliseconds. At least one bound must be specified.
   * For time-locked scripts, `to` is typically required for script evaluation.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import * as Time from "@evolution-sdk/Time"
   *
   * // Transaction valid for 10 minutes from now
   * const tx = await builder
   *   .setValidity({
   *     from: UnixTime.now(),
   *     to: UnixTime.now() + 600_000n  // 10 minutes
   *   })
   *   .build()
   *
   * // Only set expiration (most common)
   * const tx = await builder
   *   .setValidity({ to: UnixTime.now() + 300_000n })  // 5 minute TTL
   *   .build()
   * ```
   *
   * @since 2.0.0
   * @category validity-methods
   */
  readonly setValidity: (params: ValidityParams) => this

  /**
   * Submit votes on governance actions.
   *
   * Submits voting procedures to vote on governance proposals. Supports multiple
   * voters voting on multiple proposals in a single transaction.
   *
   * For script-controlled voters (DRep, Constitutional Committee member, or stake pool
   * with script credential), provide a redeemer to satisfy the vote purpose validator.
   * The redeemer will be applied to all script voters in the voting procedures.
   *
   * Use VotingProcedures.singleVote() helper for simple cases or construct
   * VotingProcedures directly for complex multi-voter scenarios.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import * as VotingProcedures from "@evolution-sdk/VotingProcedures"
   * import * as Vote from "@evolution-sdk/Vote"
   * import * as Data from "@evolution-sdk/Data"
   *
   * // Simple single vote with helper
   * await client.newTx()
   *   .vote({
   *     votingProcedures: VotingProcedures.singleVote(
   *       new VotingProcedures.DRepVoter({ credential: myDRepCred }),
   *       govActionId,
   *       new VotingProcedures.VotingProcedure({
   *         vote: Vote.yes(),
   *         anchor: null
   *       })
   *     ),
   *     redeemer: Data.to(new Constr(0, [])) // for script DRep
   *   })
   *   .attachScript({ script: voteScript })
   *   .build()
   *   .then(tx => tx.sign())
   *   .then(tx => tx.submit())
   *
   * // Multiple votes from same voter
   * await client.newTx()
   *   .vote({
   *     votingProcedures: VotingProcedures.multiVote(
   *       new VotingProcedures.DRepVoter({ credential: myDRepCred }),
   *       [
   *         [govActionId1, new VotingProcedures.VotingProcedure({ vote: Vote.yes(), anchor: null })],
   *         [govActionId2, new VotingProcedures.VotingProcedure({ vote: Vote.no(), anchor: null })]
   *       ]
   *     )
   *   })
   *   .build()
   * ```
   *
   * @since 2.0.0
   * @category governance-methods
   */
  readonly vote: (params: VoteParams) => this

  /**
   * Submit a governance action proposal.
   *
   * Submits a governance action proposal to the blockchain.
   * The deposit (govActionDeposit) is automatically fetched from protocol parameters
   * and will be refunded to the specified reward account when the proposal is finalized.
   *
   * Call .propose() multiple times to submit multiple proposals in one transaction.
   * Consistent with .registerStake() and .registerDRep() - no manual deposit handling.
   *
   * The deposit amount is automatically deducted during transaction balancing.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import * as GovernanceAction from "@evolution-sdk/GovernanceAction"
   * import * as RewardAccount from "@evolution-sdk/RewardAccount"
   *
   * // Submit single proposal (deposit auto-fetched)
   * await client.newTx()
   *   .propose({
   *     governanceAction: new GovernanceAction.InfoAction({}),
   *     rewardAccount: myRewardAccount,
   *     anchor: myAnchor // or null
   *   })
   *   .build()
   *   .then(tx => tx.sign())
   *   .then(tx => tx.submit())
   *
   * // Multiple proposals in one transaction
   * await client.newTx()
   *   .propose({
   *     governanceAction: new GovernanceAction.InfoAction({}),
   *     rewardAccount: myRewardAccount,
   *     anchor: null
   *   })
   *   .propose({
   *     governanceAction: new GovernanceAction.NoConfidenceAction({ govActionId: null }),
   *     rewardAccount: myRewardAccount,
   *     anchor: myOtherAnchor
   *   })
   *   .build()
   *   .then(tx => tx.sign())
   *   .then(tx => tx.submit())
   * ```
   *
   * @since 2.0.0
   * @category governance-methods
   */
  readonly propose: (params: ProposeParams) => this

  /**
   * Add a required signer to the transaction.
   *
   * Adds a key hash to the transaction's requiredSigners field. This is used to
   * require specific key signatures even when those keys don't control inputs.
   * Common use cases include:
   * - Multi-sig schemes requiring explicit signature verification
   * - Plutus scripts that check for specific signers in the transaction
   * - Governance transactions requiring DRep or committee member signatures
   *
   * Duplicate key hashes are automatically deduplicated.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import * as KeyHash from "@evolution-sdk/KeyHash"
   * import * as Address from "@evolution-sdk/Address"
   *
   * // Add signer from address credential
   * const address = Address.fromBech32("addr_test1...")
   * const cred = address.paymentCredential
   * if (cred._tag === "KeyHash") {
   *   const tx = await builder
   *     .addSigner({ keyHash: cred })
   *     .build()
   * }
   * ```
   *
   * @since 2.0.0
   * @category builder-methods
   */
  readonly addSigner: (params: AddSignerParams) => this

  /**
   * Attach metadata to the transaction.
   *
   * Metadata is stored in the auxiliary data section and identified by numeric labels
   * following the CIP-10 standard. Common use cases include:
   * - Transaction messages/comments (label 674, CIP-20)
   * - NFT metadata (label 721, CIP-25)
   * - Royalty information (label 777, CIP-27)
   * - DApp-specific data
   *
   * Multiple metadata entries with different labels can be attached by calling this
   * method multiple times. The same label cannot be used twice.
   *
   * Queues a deferred operation that will be executed when build() is called.
   * Returns the same builder for method chaining.
   *
   * @example
   * ```typescript
   * import { fromEntries } from "@evolution-sdk/evolution/TransactionMetadatum"
   *
   * // Attach a simple message (CIP-20)
   * const tx = await builder
   *   .payToAddress({ address, assets: { lovelace: 2_000_000n } })
   *   .attachMetadata({ label: 674n, metadata: "Hello, Cardano!" })
   *   .build()
   *
   * // Attach NFT metadata (CIP-25)
   * const nftMetadata = fromEntries([
   *   ["name", "My NFT #42"],
   *   ["image", "ipfs://Qm..."]
   * ])
   * const tx = await builder
   *   .mintAssets({ assets: { [policyId + assetName]: 1n } })
   *   .attachMetadata({ label: 721n, metadata: nftMetadata })
   *   .build()
   * ```
   *
   * @since 2.0.0
   * @category metadata-methods
   */
  readonly attachMetadata: (params: AttachMetadataParams) => this

  // ============================================================================
  // Composition Methods
  // ============================================================================

  /**
   * Compose this builder with another builder's accumulated operations.
   *
   * Merges all queued operations from another transaction builder into this one.
   * The other builder's programs are captured at compose time and will be executed
   * when build() is called on this builder.
   *
   * This enables modular transaction building where common patterns can be
   * encapsulated in reusable builder fragments.
   *
   * **Important**: Composition is one-way - changes to the other builder after
   * compose() is called will not affect this builder.
   *
   * @example
   * ```typescript
   * // Create reusable builder for common operations
   * const mintBuilder = builder
   *   .mintAssets({ policyId, assets: { tokenName: 1n }, redeemer })
   *   .attachScript({ script: mintingPolicy })
   *
   * // Compose into a transaction that also pays to an address
   * const tx = await builder
   *   .payToAddress({ address, assets: { lovelace: 5_000_000n } })
   *   .compose(mintBuilder)
   *   .build()
   *
   * // Compose multiple builders
   * const fullTx = await builder
   *   .compose(mintBuilder)
   *   .compose(metadataBuilder)
   *   .compose(certBuilder)
   *   .build()
   * ```
   *
   * @param other - Another transaction builder whose operations will be merged
   *
   * @since 2.0.0
   * @category composition-methods
   */
  readonly compose: (other: TransactionBuilder) => this

  /**
   * Get a snapshot of the accumulated programs.
   *
   * Returns a read-only copy of all queued operations that have been added
   * to this builder. Useful for inspection, debugging, or advanced composition patterns.
   *
   * @since 2.0.0
   * @category composition-methods
   */
  readonly getPrograms: () => ReadonlyArray<ProgramStep>

  // ============================================================================
  // Transaction Chaining Methods
  // ============================================================================

  /**
   * Execute transaction build and return consumed/available UTxOs for chaining.
   *
   * Runs the full build pipeline (coin selection, fee calculation, evaluation) and returns
   * which UTxOs were consumed and which remain available for subsequent transactions.
   * Use this when building multiple dependent transactions in sequence.
   *
   * @example
   * ```typescript
   * // Build first transaction, get remaining UTxOs
   * const tx1 = await builder
   *   .payTo({ address, value: { lovelace: 5_000_000n } })
   *   .build({ availableUtxos: walletUtxos })
   *
   * // Build second transaction using remaining UTxOs from chainResult
   * const tx2 = await builder
   *   .payTo({ address, value: { lovelace: 3_000_000n } })
   *   .build({ availableUtxos: tx1.chainResult().available })
   * ```
   *
   * @since 2.0.0
   * @category chaining-methods
   */
}
````

Added in v2.0.0

# config

## BuildOptions (interface)

Options passed to `build()` to customize a single transaction build.

**Signature**

```ts
export interface BuildOptions {
  /**
   * Override protocol parameters for this specific transaction build.
   *
   * @since 2.0.0
   */
  readonly protocolParameters?: ProtocolParameters

  /**
   * Coin selection strategy for automatic input selection.
   *
   * @default "largest-first"
   */
  readonly coinSelection?: CoinSelectionAlgorithm | CoinSelectionFunction

  /**
   * Override the change address for this specific transaction build.
   *
   * @since 2.0.0
   */
  readonly changeAddress?: CoreAddress.Address

  /**
   * Override the available UTxOs for this specific transaction build.
   *
   * @since 2.0.0
   */
  readonly availableUtxos?: ReadonlyArray<CoreUTxO.UTxO>

  /**
   * Output index to merge leftover assets into as a fallback when change output cannot be created.
   *
   * @since 2.0.0
   */
  readonly drainTo?: number

  /**
   * Strategy for handling insufficient leftover assets when change output cannot be created.
   *
   * @default 'error'
   * @since 2.0.0
   */
  readonly onInsufficientChange?: "error" | "burn"

  /**
   * Script evaluator for Plutus script execution costs.
   *
   * If provided, replaces the default provider-based evaluation.
   *
   * @since 2.0.0
   */
  readonly evaluator?: Evaluator

  /**
   * Pass additional UTxOs to provider-based evaluators.
   *
   * @default false
   * @since 2.0.0
   */
  readonly passAdditionalUtxos?: boolean

  /**
   * Format for encoding redeemers in the script data hash.
   *
   * @deprecated Redeemer format is now determined by the concrete `Redeemers` type.
   * @since 2.0.0
   */
  readonly scriptDataFormat?: "array" | "map"

  /**
   * Custom slot configuration for script evaluation.
   *
   * @since 2.0.0
   */
  readonly slotConfig?: SlotConfig.SlotConfig

  /**
   * Amount to set as collateral return output (in lovelace).
   *
   * @default 5_000_000n
   * @since 2.0.0
   */
  readonly setCollateral?: bigint

  /**
   * Optimize wallet UTxO structure using Unfrack.It principles.
   *
   * @since 2.0.0
   */
  readonly unfrack?: UnfrackOptions

  /**
   * Enable debug logging during transaction build.
   *
   * @default false
   * @since 2.0.0
   */
  readonly debug?: boolean
}
```

Added in v2.0.0

## ProtocolParameters (interface)

Protocol parameters required for transaction building.
Subset of full protocol parameters, only what's needed for minimal build.

**Signature**

```ts
export interface ProtocolParameters {
  /** Coefficient for linear fee calculation (minFeeA) */
  minFeeCoefficient: bigint

  /** Constant for linear fee calculation (minFeeB) */
  minFeeConstant: bigint

  /** Minimum ADA per UTxO byte (for future change output validation) */
  coinsPerUtxoByte: bigint

  /** Maximum transaction size in bytes */
  maxTxSize: number

  /** Price per memory unit for script execution (optional, for ExUnits cost calculation) */
  priceMem?: number

  /** Price per CPU step for script execution (optional, for ExUnits cost calculation) */
  priceStep?: number

  /** Cost per byte for reference scripts (Conway-era, default 44) */
  minFeeRefScriptCostPerByte?: number
}
```

Added in v2.0.0

## TxBuilderConfig (interface)

Configuration for TransactionBuilder.
Immutable configuration passed to builder at creation time.

Wallet-centric design (when wallet provided):

- Wallet provides change address (via wallet.effect.address())
- Provider + Wallet provide available UTxOs (via provider.effect.getUtxos(wallet.address))
- Override per-build via BuildOptions if needed

Manual mode (no wallet):

- Must provide changeAddress and availableUtxos in BuildOptions for each build
- Used for read-only scenarios or advanced use cases

**Signature**

```ts
export interface TxBuilderConfig {
  /**
   * Optional wallet provides:
   * - Change address via wallet.effect.address()
   * - Available UTxOs via wallet.effect.address() + provider.effect.getUtxos()
   * - Signing capability via wallet.effect.signTx() (SigningWallet and ApiWallet only)
   *
   * When provided: Automatic change address and UTxO resolution.
   * When omitted: Must provide changeAddress and availableUtxos in BuildOptions.
   *
   * ReadOnlyWallet: For read-only clients that can build but not sign transactions.
   * SigningWallet/ApiWallet: For signing clients with full transaction signing capability.
   *
   * Override per-build via BuildOptions.changeAddress and BuildOptions.availableUtxos.
   */
  readonly wallet?: Wallet.SigningWallet | Wallet.ApiWallet | Wallet.ReadOnlyWallet

  /**
   * Optional provider for:
   * - Fetching UTxOs for the wallet's address (provider.effect.getUtxos)
   * - Transaction submission (provider.effect.submitTx)
   * - Protocol parameters
   *
   * Works together with wallet to provide everything needed for transaction building.
   * When wallet is omitted, provider is only used if you call provider methods directly.
   */
  readonly provider?: Provider.Provider

  /**
   * Chain descriptor — network identity and slot timing parameters.
   *
   * Provides:
   * - `id`: Network id (1 = mainnet, 0 = testnet) for address and reward account encoding
   * - `slotConfig`: Slot timing required for validity interval conversion and script evaluation
   * - `networkMagic`, `epochLength`, `name`: Additional network metadata
   *
   * Use the presets `mainnet`, `preprod`, `preview` from the client module, or define a
   * custom Chain for private networks and devnets.
   *
   * The per-build `BuildOptions.slotConfig` override takes priority over `chain.slotConfig`.
   *
   * @since 2.0.0
   */
  readonly chain: Chain
}
```

Added in v2.0.0

## UnfrackAdaOptions (interface)

ADA-specific UTxO optimization options.

**Signature**

```ts
export interface UnfrackAdaOptions {
  /**
   * Roll Up ADA-Only: Intentionally collect and consolidate ADA-only UTxOs
   * @default false (only collect when needed for change)
   */
  readonly rollUpAdaOnly?: boolean

  /**
   * Subdivide Leftover ADA: If leftover ADA > threshold, split into multiple UTxOs
   * Creates multiple ADA options for future transactions (parallelism)
   * @default 100_000000 (100 ADA)
   */
  readonly subdivideThreshold?: Coin.Coin

  /**
   * Subdivision percentages for leftover ADA
   * Must sum to 100
   * @default [50, 15, 10, 10, 5, 5, 5]
   */
  readonly subdividePercentages?: ReadonlyArray<number>

  /**
   * Maximum ADA-only UTxOs to consolidate in one transaction.
   * NOTE: Not yet implemented. Will hook into coin selection to merge dust UTxOs.
   * @default 20
   */
  readonly maxUtxosToConsolidate?: number
}
```

Added in v2.0.0

## UnfrackOptions (interface)

Top-level UTxO optimization options (tokens + ADA).

Named in respect to the Unfrack.It open source community.

**Signature**

```ts
export interface UnfrackOptions {
  readonly tokens?: UnfrackTokenOptions
  readonly ada?: UnfrackAdaOptions
}
```

Added in v2.0.0

## UnfrackTokenOptions (interface)

Token-specific UTxO optimization options based on Unfrack.It principles.

**Signature**

```ts
export interface UnfrackTokenOptions {
  /**
   * Bundle Size: Number of tokens to collect per UTxO
   * - Same policy: up to bundleSize tokens together
   * - Multiple policies: up to bundleSize/2 tokens from different policies
   * - Policy exceeds bundle: split into multiple UTxOs
   * @default 10
   */
  readonly bundleSize?: number

  /**
   * Isolate Fungible Behavior: Place each fungible token policy on its own UTxO
   * Decreases fees and makes DEX interactions easier
   * @default false
   */
  readonly isolateFungibles?: boolean

  /**
   * Group NFTs by Policy: Separate NFTs onto policy-specific UTxOs
   * Decreases fees for marketplaces, staking, sending
   * @default false
   */
  readonly groupNftsByPolicy?: boolean
}
```

Added in v2.0.0

# constructors

## makeTxBuilder

Construct a TransactionBuilder instance from protocol configuration.

The builder accumulates chainable method calls as deferred ProgramSteps. Calling build() or chain()
creates fresh state (new Refs) and executes all accumulated programs sequentially, ensuring
no state pollution between invocations.

The return type is narrowed at construction time based on the wallet type provided:

- `SigningTransactionBuilder`: when wallet is `SigningWallet` or `ApiWallet`
- `ReadOnlyTransactionBuilder`: when wallet is `ReadOnlyWallet` or omitted

`chain` is required — use the `mainnet`, `preprod`, or `preview` presets from the client
module, or define a custom `Chain` for private networks and devnets.

When wallet is omitted, `changeAddress` and `availableUtxos` must be supplied at build
time via `BuildOptions`.

**Signature**

```ts
export declare function makeTxBuilder(
  config: TxBuilderConfig & { wallet: Wallet.SigningWallet | Wallet.ApiWallet }
): SigningTransactionBuilder
export declare function makeTxBuilder(
  config: TxBuilderConfig & { wallet: Wallet.ReadOnlyWallet }
): ReadOnlyTransactionBuilder
export declare function makeTxBuilder(config: TxBuilderConfig & { wallet?: undefined }): ReadOnlyTransactionBuilder
```

Added in v2.0.0

# context

## AvailableUtxosTag (class)

Context tag providing available UTxOs for coin selection.

**Signature**

```ts
export declare class AvailableUtxosTag
```

Added in v2.0.0

## BuildOptionsTag (class)

Context tag providing build options for the current build.

**Signature**

```ts
export declare class BuildOptionsTag
```

Added in v2.0.0

## ChangeAddressTag (class)

Context tag providing the change address.

**Signature**

```ts
export declare class ChangeAddressTag
```

Added in v2.0.0

## PhaseContextTag (class)

Context tag providing build-phase state.

**Signature**

```ts
export declare class PhaseContextTag
```

Added in v2.0.0

## ProtocolParametersTag (class)

Context tag providing protocol parameters.

**Signature**

```ts
export declare class ProtocolParametersTag
```

Added in v2.0.0

## TxBuilderConfigTag (class)

Context tag providing the builder configuration.

**Signature**

```ts
export declare class TxBuilderConfigTag
```

Added in v2.0.0

## TxContext (class)

Context tag providing the mutable transaction state.

**Signature**

```ts
export declare class TxContext
```

Added in v2.0.0

# errors

## EvaluationError (class)

Error thrown when script evaluation fails.

**Signature**

```ts
export declare class EvaluationError
```

Added in v2.0.0

## ScriptFailure (interface)

Describes a single script failure from evaluation.

Contains all available information about which script failed and why,
including optional labels from the user's operation definitions.

**Signature**

```ts
export interface ScriptFailure {
  /** Redeemer purpose: "spend", "mint", "withdraw", "publish" */
  readonly purpose: string
  /** Index within the purpose category */
  readonly index: number
  /** User-provided label for debugging (from operation params) */
  readonly label?: string
  /** Key used internally to track this redeemer (e.g., "txHash#index" for spend) */
  readonly redeemerKey?: string
  /** Script hash if available */
  readonly scriptHash?: string
  /** UTxO reference for spend redeemers */
  readonly utxoRef?: string
  /** Credential hash for withdraw/cert redeemers */
  readonly credential?: string
  /** Policy ID for mint redeemers */
  readonly policyId?: string
  /** Validation error message from the script */
  readonly validationError: string
  /** Execution traces emitted by the script */
  readonly traces: ReadonlyArray<string>
}
```

Added in v2.0.0

## TransactionBuilderError (class)

Error thrown when transaction building fails.

**Signature**

```ts
export declare class TransactionBuilderError
```

Added in v2.0.0

# model

## ChainResult (interface)

Result type for transaction chaining operations.

Provides consumed and available UTxOs for building chained transactions.
The available UTxOs include both remaining unspent inputs AND newly created outputs
with pre-computed txHash, ready to be spent in subsequent transactions.

Accessed via `SignBuilder.chainResult()` after calling `build()`.

**Signature**

```ts
export interface ChainResult {
  /** UTxOs consumed from availableUtxos by coin selection */
  readonly consumed: ReadonlyArray<CoreUTxO.UTxO>
  /** Available UTxOs: remaining unspent + newly created (with computed txHash) */
  readonly available: ReadonlyArray<CoreUTxO.UTxO>
  /** Pre-computed transaction hash (blake2b-256 of transaction body) */
  readonly txHash: string
}
```

Added in v2.0.0

## EvaluationContext (interface)

Data required by script evaluators: cost models, execution limits, and slot configuration.

Used by custom evaluators for local UPLC script evaluation.

**Signature**

```ts
export interface EvaluationContext {
  /** Cost models for script evaluation */
  readonly costModels: CostModel.CostModels
  /** Maximum execution steps allowed */
  readonly maxTxExSteps: bigint
  /** Maximum execution memory allowed */
  readonly maxTxExMem: bigint
  /** Slot configuration for time-based operations */
  readonly slotConfig: {
    readonly zeroTime: bigint
    readonly zeroSlot: bigint
    readonly slotLength: number
  }
}
```

Added in v2.0.0

## Evaluator (interface)

Interface for evaluating transaction scripts and computing execution units.

Implement this interface to provide custom script evaluation strategies,
such as local UPLC execution.

**Signature**

```ts
export interface Evaluator {
  /**
   * Evaluate transaction scripts and return execution units.
   *
   * @since 2.0.0
   * @category methods
   */
  evaluate: (
    tx: Transaction.Transaction,
    additionalUtxos: ReadonlyArray<CoreUTxO.UTxO> | undefined,
    context: EvaluationContext
  ) => Effect.Effect<ReadonlyArray<EvalRedeemer>, EvaluationError>
}
```

Added in v2.0.0

## ProgramStep (type alias)

A single deferred builder step executed during `build()`.

**Signature**

```ts
export type ProgramStep = Effect.Effect<void, TransactionBuilderError, TxContext | TxBuilderConfigTag>
```

Added in v2.0.0

# state

## DeferredRedeemerData (interface)

Deferred redeemer data for RedeemerBuilder patterns.
Contains callback that will be resolved after coin selection completes.

**Signature**

```ts
export interface DeferredRedeemerData {
  readonly tag: "spend" | "mint" | "cert" | "reward" | "vote"
  readonly deferred: DeferredRedeemer
  readonly exUnits?: {
    readonly mem: bigint
    readonly steps: bigint
  }
  /** Optional label for debugging - identifies this redeemer in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## Phase (type alias)

Build phases.

**Signature**

```ts
export type Phase =
  | "selection"
  | "changeCreation"
  | "feeCalculation"
  | "balance"
  | "evaluation"
  | "collateral"
  | "fallback"
  | "complete"
```

Added in v2.0.0

## PhaseContext (interface)

Build-phase state machine context tracking fee calculation and change creation progress.

**Signature**

```ts
export interface PhaseContext {
  readonly phase: Phase
  readonly attempt: number
  readonly calculatedFee: bigint
  readonly shortfall: bigint
  readonly changeOutputs: ReadonlyArray<TxOut.TransactionOutput>
  readonly leftoverAfterFee: CoreAssets.Assets
  readonly canUnfrack: boolean
}
```

Added in v2.0.0

## PhaseResult (interface)

Result returned by a phase indicating the next phase to execute.

**Signature**

```ts
export interface PhaseResult {
  readonly next: Phase
}
```

Added in v2.0.0

## RedeemerData (interface)

Redeemer data stored during input collection.
Index is determined later during witness assembly based on input ordering.

**Signature**

```ts
export interface RedeemerData {
  readonly tag: "spend" | "mint" | "cert" | "reward" | "vote"
  readonly data: PlutusData.Data
  readonly exUnits?: {
    readonly mem: bigint
    readonly steps: bigint
  }
  /** Optional label for debugging - identifies this redeemer in error messages */
  readonly label?: string
}
```

Added in v2.0.0

## TxBuilderState (interface)

Mutable state created FRESH on each build() call.
Contains all state needed during transaction construction.

State lifecycle:

1. Created fresh when build() is called
2. Modified by ProgramSteps during execution
3. Used to construct final transaction
4. Discarded after build completes

**Signature**

```ts
export interface TxBuilderState {
  readonly selectedUtxos: ReadonlyArray<CoreUTxO.UTxO>
  readonly outputs: ReadonlyArray<TxOut.TransactionOutput>
  readonly scripts: Map<string, CoreScript.Script>
  readonly totalOutputAssets: CoreAssets.Assets
  readonly totalInputAssets: CoreAssets.Assets
  readonly redeemers: Map<string, RedeemerData>
  readonly deferredRedeemers: Map<string, DeferredRedeemerData>
  readonly referenceInputs: ReadonlyArray<CoreUTxO.UTxO>
  readonly certificates: ReadonlyArray<Certificate.Certificate>
  readonly withdrawals: Map<RewardAccount.RewardAccount, bigint>
  readonly poolDeposits: Map<string, bigint>
  readonly mint?: Mint.Mint
  readonly votingProcedures?: VotingProcedures.VotingProcedures
  readonly proposalProcedures?: ProposalProcedures.ProposalProcedures
  readonly collateral?: {
    readonly inputs: ReadonlyArray<CoreUTxO.UTxO>
    readonly totalAmount: bigint
    readonly returnOutput?: TxOut.TransactionOutput
  }
  readonly validity?: {
    readonly from?: UnixTime.UnixTime
    readonly to?: UnixTime.UnixTime
  }
  readonly requiredSigners: ReadonlyArray<KeyHash.KeyHash>
  readonly auxiliaryData?: AuxiliaryData.AuxiliaryData
  readonly sendAllTo?: CoreAddress.Address
}
```

Added in v2.0.0

# utilities

## voterToKey

Convert a Voter to a unique string key for redeemer tracking.

**Signature**

```ts
export declare const voterToKey: (voter: VotingProcedures.Voter) => string
```

Added in v2.0.0

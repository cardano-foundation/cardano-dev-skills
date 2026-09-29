# API Reference

## CIP113

### `CIP113.init(config: CIP113Config): CIP113Protocol`

Initialize a CIP-113 protocol instance.

```typescript
const protocol = CIP113.init({
  client,                    // Evolution SDK client (ReadOnlyClient or SigningClient)
  standard: {
    blueprint,               // PlutusBlueprint — standard protocol validators
    deployment,              // DeploymentParams — on-chain deployment references
  },
  substandards: [fes],       // SubstandardPlugin[] — registered substandards
});
```

## CIP113Protocol

### Core Operations

> ⚠ Since 0.5.0-alpha.4 (and unchanged in alpha.5, and in `v0.0.1` — the SDK's current target and a byte-identical relabel of alpha.5), every `register`, `mint`, and `burn` transaction carries `issuance_logic`'s withdraw-0; omitting it refuses the mint without naming a missing withdrawal, policy, or index.

| Method | Description |
|--------|-------------|
| `register(substandardId, params)` | Register a new token (first mint + registry insert) |
| `mint(params)` | Mint additional tokens |
| `burn(params)` | Burn tokens from a UTxO |
| `transfer(params)` | Transfer tokens between addresses |

### Compliance Operations

| Method | Description |
|--------|-------------|
| `compliance.init(substandardId, params)` | Initialize compliance infrastructure |
| `compliance.freeze(params)` | Add address to blacklist. **`params.substandardId` is required** — no try-all fallback |
| `compliance.unfreeze(params)` | Remove address from blacklist. **`params.substandardId` is required** — no try-all fallback |
| `compliance.seize(params)` | Seize tokens from frozen address. **`params.substandardId` is required** — no try-all fallback |

### Runtime

| Method | Description |
|--------|-------------|
| `registerSubstandard(plugin)` | Register a substandard at runtime |
| `getSubstandard(id)` | Get a registered substandard by ID |
| `listSubstandards()` | List all registered substandard IDs |

---

## Parameter Types

### RegisterParams

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feePayerAddress` | `Address` | Yes | Transaction fee payer |
| `assetName` | `string` | Yes | Human-readable asset name |
| `quantity` | `bigint` | Yes | Initial mint quantity |
| `recipientAddress` | `Address` | No | Token recipient (default: feePayerAddress) |
| `config` | `Record<string, unknown>` | No | Substandard-specific config |
| `chainedUtxos` | `unknown[]` | No | UTxOs from chained tx |
| `cip68Metadata` | `CIP68MetadataInput` | No | CIP-68 reference token metadata |

### MintParams

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feePayerAddress` | `Address` | Yes | Transaction fee payer |
| `tokenPolicyId` | `PolicyId` | Yes | Token policy ID |
| `assetName` | `HexString` | Yes | Raw asset name hex |
| `quantity` | `bigint` | Yes | Amount to mint |
| `recipientAddress` | `Address` | No | Recipient (default: feePayerAddress) |
| `substandardId` | `string` | No | Route to specific substandard |

### BurnParams

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feePayerAddress` | `Address` | Yes | Transaction fee payer |
| `tokenPolicyId` | `PolicyId` | Yes | Token policy ID |
| `assetName` | `HexString` | Yes | Raw asset name hex |
| `utxoTxHash` | `HexString` | Yes | UTxO transaction hash |
| `utxoOutputIndex` | `number` | Yes | UTxO output index |
| `holderAddress` | `Address` | No | Token holder address (default: feePayerAddress) |
| `substandardId` | `string` | No | Route to specific substandard |

### TransferParams

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `senderAddress` | `Address` | Yes | Sender's address |
| `recipientAddress` | `Address` | Yes | Recipient's address |
| `tokenPolicyId` | `PolicyId` | Yes | Token policy ID |
| `assetName` | `HexString` | Yes | Raw asset name hex |
| `quantity` | `bigint` | Yes | Amount to transfer |
| `substandardId` | `string` | No | Route to specific substandard |

### FreezeParams / UnfreezeParams

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feePayerAddress` | `Address` | Yes | Transaction fee payer (admin) |
| `tokenPolicyId` | `PolicyId` | Yes | Token policy ID |
| `assetName` | `HexString` | Yes | Raw asset name hex |
| `targetAddress` | `Address` | Yes | Address to freeze/unfreeze |

### SeizeParams

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feePayerAddress` | `Address` | Yes | Transaction fee payer (admin) |
| `tokenPolicyId` | `PolicyId` | Yes | Token policy ID |
| `assetName` | `HexString` | Yes | Raw asset name hex |
| `utxoTxHash` | `HexString` | Yes | Target UTxO tx hash |
| `utxoOutputIndex` | `number` | Yes | Target UTxO output index |
| `destinationAddress` | `Address` | Yes | Where to send seized tokens |
| `holderAddress` | `Address` | No | Holder's address (for UTxO lookup) |

### InitComplianceParams

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feePayerAddress` | `Address` | Yes | Transaction fee payer |
| `adminAddress` | `Address` | Yes | Admin address |
| `assetName` | `string` | Yes | Human-readable asset name |
| `bootstrapUtxo` | `unknown` | No | One-shot bootstrap UTxO |

### CIP68MetadataInput

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | Yes | Display name |
| `description` | `string` | No | Token description |
| `ticker` | `string` | No | Short ticker symbol |
| `decimals` | `number` | No | Decimal places (default: 0) |
| `url` | `string` | No | Project URL |
| `logo` | `string` | No | Logo image URI |

---

## Result Type

### UnsignedTx

| Field | Type | Description |
|-------|------|-------------|
| `cbor` | `HexString` | Unsigned transaction CBOR |
| `txHash` | `HexString` | Transaction hash |
| `tokenPolicyId` | `PolicyId?` | Minted token policy (register/mint) |
| `metadata` | `Record?` | Operation-specific metadata |
| `chainAvailable` | `unknown[]?` | UTxOs available for chaining |
| `_signBuilder` | `any?` | SignBuilder for `signAndSubmit()` |

---

## Deployment Types

### DeploymentParams

On-chain protocol deployment references. Obtained from the bootstrap transaction.

> ⚠ **This block was wrong for two protocol versions.** Until 0.8.0 it described the **0.3.x**
> shape — `programmableLogicGlobal: { policyId, scriptHash }`, `protocolParams.alwaysFailScriptHash`,
> a `directoryMint`/`directorySpend` pair — and survived the entire 0.3.x → 0.5.0-alpha.2 migration
> unnoticed, because nothing tests documentation. It is now pinned by
> `test/docs-drift.test.mjs`, which fails if these field names stop matching the real type —
> **top-level names AND one level of nesting**, so `programmableLogicGlobal.unfrackingParameter`
> is compared, not just `programmableLogicGlobal`.
>
> ⚠ **That claim was itself wrong once, which is the reason it now states its depth.** The drift
> test originally collected names at brace-depth 0 only, so every nested field was invisible to it
> and this block could — and did — describe a `programmableLogicGlobal` the SDK refuses, with the
> test sitting green. A check classified by its shape ("it pins `DeploymentParams`") rather than by
> what gets past it is the same defect this section exists to record, one level down.
>
> ⚠ **For 0.5.0-alpha.4, alpha.5 and `v0.0.1` alike, this is the six-field deployment shape** — alpha.5 moved the genesis TRANSACTION, not the datum. The params datum inserts
> `issuance_logic_cred` at index 1, shifting the credential-valued slots at indices 1, 2 and 3.
> Every `register`, `mint`, and `burn` transaction also carries `issuance_logic`'s withdraw-0;
> omitting it refuses the mint without naming a missing withdrawal, policy, or index.

```typescript
interface DeploymentParams {
  txHash: TxHash;

  // ⚑ ONE hash, two roles: policyId is ALSO the params address's payment
  // credential. protocol_params merged its mint and spend handlers in
  // alpha.3, so deriving them separately is two chances to disagree.
  protocolParams: { txInput: TxInput; policyId: PolicyId; utxo: TxInput };

  programmableLogicBase: { scriptHash: ScriptHash };

  // The three withdraw-0 delegates.
  transfer: { scriptHash: ScriptHash };
  thirdParty: { scriptHash: ScriptHash };
  unfracking: { scriptHash: ScriptHash };

  // The dispatcher. Every programmable transaction withdraws through it.
  //
  // unfrackingParameter is a deployment CHOICE, not a derivation — it is what
  // programmable_logic_global was COMPILED AGAINST, baked into scriptHash and
  // recoverable from no hash. It is EITHER unfracking.scriptHash (unfracking
  // enabled) OR UNFRACKING_DISABLED, the 28-byte zero sentinel exported from
  // this package (unfracking deployed and published, but the dispatcher's
  // unfracking arm made permanently unsatisfiable). NOTHING ELSE IN THE RECORD
  // DETERMINES WHICH, so it is REQUIRED and has no default: a record that omits
  // it, or that copies unfracking.scriptHash without checking, is refused by
  // name. Import the constant — a local copy is a second place to disagree
  // about a value that determines a script hash.
  programmableLogicGlobal: { scriptHash: ScriptHash; unfrackingParameter: ScriptHash };

  // A deployment CHOICE, not a derivation — baked into transfer, third_party,
  // unfracking, and issuance_logic hashes and recoverable from none of them.
  maxInlineDatumBytes: number;

  // ⚑ ONE hash, THREE roles: scriptHash is the config NFT policy, the config
  // UTxO address's payment credential, AND the withdraw-0 credential.
  // txInput is the spent one-shot it is parameterised by — NOT interchangeable
  // with protocolParams.txInput, which has the same type. utxo is MUTABLE: a
  // signer rotation spends the config UTxO and recreates it.
  upgradeMultisig: { scriptHash: ScriptHash; txInput: TxInput; utxo: TxInput };
  upgradeMultisigRefInput: TxInput;

  // The ACTIVE authority the params datum names. Not derived from
  // upgradeMultisig, and never checked against it.
  upgradeAuthority: { type: "key" | "script"; hash: ScriptHash };

  // The withdraw-0 credential named by the params datum's field 1. Every mint
  // and every burn carries its withdrawal, and it must be REGISTERED.
  issuanceLogic: { scriptHash: ScriptHash };
  issuanceLogicRefInput: TxInput;

  issuance: { txInput: TxInput; policyId: PolicyId; alwaysFailScriptHash: ScriptHash };

  // ⚑ ONE hash, two roles again: scriptHash is the node NFT policy AND the
  // node address's payment credential.
  registry: { txInput: TxInput; issuanceScriptHash: ScriptHash; scriptHash: ScriptHash };

  programmableBaseRefInput: TxInput;
  programmableLogicGlobalRefInput: TxInput;
  transferRefInput: TxInput;
  thirdPartyRefInput: TxInput;
  unfrackingRefInput: TxInput;
}
```

### FESDeploymentParams

```typescript
interface FESDeploymentParams {
  adminPkh: HexString;
  assetName: HexString;
  blacklistNodePolicyId: HexString;
  blacklistInitTxInput: TxInput;
}
```

---

## Utility Functions

### String/Hex

| Function | Description |
|----------|-------------|
| `stringToHex(str)` | Convert UTF-8 string to hex |
| `labeledAssetName(label, hex)` | Add CIP-67 label prefix (e.g., 333 for FT) |
| `stripCIP67Label(hex)` | Remove CIP-67 label prefix if present |
| `hasCIP67Label(hex)` | Check if hex starts with CIP-67 label |
| `buildCIP68FTDatum(metadata)` | Build CIP-68 FT metadata datum |

### Address

| Function | Description |
|----------|-------------|
| `paymentCredentialHash(addr)` | Extract payment key hash from bech32 address |
| `stakingCredentialHash(addr)` | Extract staking credential hash |
| `scriptAddress(networkId, hash)` | Build enterprise script address |
| `baseAddress(networkId, hash, userAddr)` | Build base address (script + user staking) |
| `rewardAddress(networkId, hash)` | Build reward/staking address |
| `addressHexToBech32(hex)` | Convert hex address to bech32 |

### Transaction

| Function | Description |
|----------|-------------|
| `assembleSignedTx(unsigned, witness)` | Merge witness set into unsigned tx CBOR |
| `sortTxInputs(inputs)` | Sort tx inputs in canonical (ledger) order |
| `findRefInputIndex(sorted, target)` | Find index of input in sorted list |

---

## Substandard Plugin Interface

### SubstandardContext

The object `CIP113.init()` hands to every plugin's `init()`. Field names here are pinned
against `src/substandards/interface.ts` by `test/docs-drift.test.mjs`.

```typescript
interface SubstandardContext {
  evaluator?: unknown;
  client: EvoClient;
  standardScripts: ResolvedStandardScripts;
  deployment: DeploymentParams;
  network?: Network;
  checkStakeRegistration?: (stakeAddress: string) => Promise<boolean>;
}
```

⛔ **`network` is `Network | undefined`, and the `undefined` is load-bearing.** It names the
public Cardano network the client is pointed at — `"mainnet"`, `"preprod"` or `"preview"` —
derived from the chain's **network magic**. A client pointed at a devnet or any other private
network gets `undefined`, because it is none of the three and naming it one would be a lie a
plugin would then act on. Branch on the absence; do not coerce it to a default.

⭐ **The information is not lost, and this is why `undefined` is honest rather than lossy.**
`ctx.client.chain.networkMagic` and `ctx.client.chain.name` are on the same context object, one
field away. If you need to distinguish private networks, read those — do not invent a default for
`network`.

⚠ **It is derived from the magic ALONE, so a private network that REUSES a public magic is
labelled as that network.** A mainnet-fork devnet keeps magic `764824073` and reports `"mainnet"`;
a privnet that picked magic `1` or `2` reports `"preprod"` or `"preview"`. If you gate a
destructive path on `network !== "mainnet"`, that gate does not distinguish a mainnet fork from
mainnet. Check `chain.name` or your own configuration as well.

> ⚠ **Breaking, and it landed after 0.10.0** — the release notes name the version; this
> block deliberately does not, because a number written here ages into a lie. This field
> was previously typed `string` and computed from
> `chain.id`, which is the *address* network id — `1` for mainnet and `0` for **every** testnet.
> A preview client was therefore labelled `"preprod"`, and a devnet was too. Plugins that read
> `ctx.network` into a `string`, or that branch on `=== "preprod"` to detect a devnet, must be
> updated. `networkFromChain(chain)` is exported from the package root if you need the same
> mapping for a chain of your own.
>
> ⛔ **AND THE ONE THE COMPILER WILL NOT CATCH.** At 0.10.0 this field was declared `string`
> while the package exported a `Network` union, so a plugin that wanted the union **had no choice
> but to cast**: `ctx.network as Network`. **That cast still compiles, and now yields `undefined`
> at runtime** — an exhaustive `switch` over it falls off the end and returns `undefined`, with
> no diagnostic anywhere. **Remove the cast.** Plain-JavaScript plugins have the same exposure
> with no typechecker at all: `` `https://${ctx.network}.cardanoscan.io` `` becomes
> `https://undefined.cardanoscan.io`, `ctx.network.toUpperCase()` throws, and `JSON.stringify(ctx)`
> drops the key entirely on a devnet.

---

## Substandard Factories

### `dummySubstandard(config)`

```typescript
import { dummySubstandard } from "@easy1staking/cip113-sdk-ts/dummy";
const dummy = dummySubstandard({ blueprint });
```

### `freezeAndSeizeSubstandard(config)`

```typescript
import { freezeAndSeizeSubstandard } from "@easy1staking/cip113-sdk-ts/freeze-and-seize";
const fes = freezeAndSeizeSubstandard({ blueprint, deployment: FESDeploymentParams });
```

### `createFESScripts(blueprint)`

Low-level script builders for pre-computing hashes:

```typescript
import { createFESScripts } from "@easy1staking/cip113-sdk-ts/freeze-and-seize";
const scripts = createFESScripts(blueprint);
const blacklistMint = scripts.buildBlacklistMint(txInput, adminPkh);
```

---

## Evolution SDK Re-exports

| Export | Description |
|--------|-------------|
| `evoClient` | `Client.make` — create a chain-scoped client |
| `preprodChain` | Preprod chain config |
| `previewChain` | Preview chain config |
| `mainnetChain` | Mainnet chain config |
| `EvoAddress` | Address module |
| `EvoAssets` | Assets module |
| `EvoTransactionHash` | TransactionHash module |
| `EvoData` | Plutus Data module |

## Third-party transfers: the output layout is the contract

`thirdPartyTransfer` moves a holder's tokens **without the holder's signature**. It takes a
different on-chain route from `transfer`: `programmable_logic_base` withdraws through the
`programmable_logic_global` dispatcher, whose own redeemer carries `ThirdPartyAct`, and the
dispatcher requires the standalone `third_party` validator. A third-party transaction never loads
the `transfer` reference script at all.

> ⚠ In 0.5.0-alpha.2 the choice lived on `programmable_logic_base`'s own redeemer, as
> `SpendViaThirdParty`. That constructor no longer exists — see the migration note in the README.
>
> ⚠ Since 0.5.0-alpha.4, `thirdPartyTransfer` still neither mints nor burns, so it carries no
> `issuance_logic` withdrawal. Its six-field params datum instead supplies the shifted delegate
> credentials by their alpha.4 field names.

**The rule that is easy to get backwards**, and which fails with **no diagnostic at all** if you do:

`third_party` walks programmable inputs and outputs **in lockstep**. For each input at the
programmable-logic-base credential it takes the *next* output and requires that output to preserve
the input's **address, datum and reference script**, with lovelace only ratcheting **up**. The
amount seized is the **delta** between the pair.

**So the destination — where the seized tokens actually go — cannot be one of those paired outputs.**
It must sit among the *leading* outputs that `outputs_start_idx` tells the validator to skip; their
tokens are still counted in the conservation check, but they are exempt from the pairing rule.

```
outputs[0 .. outputs_start_idx-1]   destinations   (skipped; tokens still counted)
outputs[outputs_start_idx .. ]      one continuation per spent input, IN LEDGER ORDER
```

Two things follow that are not obvious:

- **Continuations must be in LEDGER input order**, not the order you added them. The ledger sorts
  inputs by `(tx id, index)`; the validator walks that order, so the outputs must match it.
- **Getting the layout wrong encodes cleanly, submits, and dies at script evaluation with an EMPTY
  TRACE LIST.** There is no message naming the layout, because the failure is a structural
  `expect`, not a traced check. If you see an empty trace from `third_party`, suspect the pairing
  before anything else.

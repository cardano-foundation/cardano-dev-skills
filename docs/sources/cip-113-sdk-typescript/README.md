# @easy1staking/cip113-sdk-ts

TypeScript SDK for [CIP-113 Programmable Tokens](https://cips.cardano.org/cip/CIP-0113) on Cardano.

Build, transfer, mint, burn, freeze, and seize programmable tokens with a clean, pluggable API.

## Install

```bash
npm install @easy1staking/cip113-sdk-ts @evolution-sdk/evolution effect
```

## Quick Start

```typescript
import { CIP113, evoClient, preprodChain } from "@easy1staking/cip113-sdk-ts";
import { freezeAndSeizeSubstandard } from "@easy1staking/cip113-sdk-ts/freeze-and-seize";

// 1. Create a client
const client = evoClient(preprodChain)
  .withBlockfrost({ projectId: "your_key", baseUrl: "https://cardano-preprod.blockfrost.io/api/v0" })
  .withSeed({ mnemonic: "your 24 word seed phrase" });

// 2. Initialize the protocol with a substandard
const protocol = CIP113.init({
  client,
  standard: { blueprint: standardBlueprint, deployment: deploymentParams },
  substandards: [fes],
});

// 3. Transfer programmable tokens
const result = await protocol.transfer({
  senderAddress: "addr_test1...",
  recipientAddress: "addr_test1...",
  tokenPolicyId: "abcd1234...",
  assetName: "0014df1044454d4f",          // raw hex, CIP-68 prefix included
  quantity: 1000n,
  substandardId: "freeze-and-seize",      // always specify for direct routing
});

// 4. Sign and submit
const txHash = await result._signBuilder.signAndSubmit();
await client.awaitTx(txHash);
```

## Substandards

| Substandard | Import | Capabilities |
|-------------|--------|-------------|
| **Freeze-and-Seize** | `@easy1staking/cip113-sdk-ts/freeze-and-seize` | Register, Transfer, Mint, Burn, Freeze, Unfreeze, Seize |
| **Dummy** | `@easy1staking/cip113-sdk-ts/dummy` | Transfer (testing only) |

## Exports

| Path | Description |
|------|-------------|
| `@easy1staking/cip113-sdk-ts` | Core SDK: `CIP113`, types, utilities |
| `@easy1staking/cip113-sdk-ts/freeze-and-seize` | Freeze-and-Seize substandard |
| `@easy1staking/cip113-sdk-ts/dummy` | Dummy substandard |

## Migrating to 0.13.0 (CIP-113 `v0.0.1` — a relabel, breaking at `init` and inert on chain)

Upstream cut **`v0.0.1`**, its first mainnet release candidate. It is a **relabel of
`0.5.0-alpha.5`**: all 34 validators' `compiledCode` are byte-identical, `definitions` is
identical, every validator's metadata is identical, and `preamble.version` is the **only**
difference in the file — an 8-byte size delta that is exactly the length difference of the two
version strings. Measured in `test/relabel-0.0.1.test.mjs`, not taken from a release note.

Read the two halves separately, because they point opposite ways.

### It IS breaking at `init`

`validateStandardBlueprint` is a version-**equality** gate. `TARGET_PROTOCOL_VERSION` is now
`"0.0.1"`, so **an alpha.5 blueprint is refused** — the same bytes this SDK accepted in 0.12.0, now
rejected on the version string alone. Point your `standard.blueprint` at
`blueprints/standard/v0.0.1/plutus.json` (pinned to upstream `6b75ba3286b4692ca23059ff51285db357fb09c6`,
the commit behind annotated tag `v0.0.1`, **reproduced from source** with Aiken v1.1.23+8949565,
sha256 `b6c8cb096a15e02f1b9c719fb8c617b624c1aa7719f2258d45faa3e8f144e7b9`, 164112 bytes).

That is the whole upgrade for a caller: one path.

### It is NOT breaking on chain — and this is the half that matters

**Every derived script hash is unchanged.** Same seeds, same nonce, same `maxInlineDatumBytes`, same
twelve hashes: `always_fail`, `upgrade_multisig`, `protocol_params`, `programmable_logic_base`,
`issuance_cbor_hex_mint`, `registry`, `transfer`, `third_party`, `unfracking`,
`programmable_logic_global`, `issuance_logic`, `issuance_mint`. An **alpha.5 deployment keeps every
credential, every address and every policy id, and needs no redeployment.** Your
`DeploymentParams` record is still correct as written.

This is the exact inverse of the 0.12.0 bump, which moved eight of those twelve and forced a
redeployment. Both claims are measured by the same derivation at the same fixed inputs —
`hash-cascade.test.mjs` asserts the eight that moved, `relabel-0.0.1.test.mjs` asserts that none of
them move here.

### ⚠ The directory listing is not a timeline

Upstream **restarted its version series**. `v0.0.1` sorts *before* `v0.3.0` and `v0.5.0-alpha.*` in
`blueprints/standard/`, alphabetically and under semver, while being **newer than all of them**.
`0.0.1 < 0.5.0-alpha.5` is what a comparator says; it is not what upstream shipped.

### Consequently, the refusal no longer says which blueprint is newer

Until 0.13.0 a version mismatch was reported as an **EARLIER** or **LATER** protocol version. Under
a restarted series that diagnosis became confidently wrong: every blueprint this repo ships was
suddenly "LATER", and every holder of one was told to upgrade an SDK that was already ahead of
them. The gate is equality, so the ordering was never load-bearing — it was a diagnostic nicety,
and a nicety that can be confidently wrong is worse than one that is absent.

The message now names the blueprint's declared version, names the version this SDK targets, offers
both remedies (move the blueprint, or use an SDK release that targets yours), and **claims no
direction**. Which one is newer lives in upstream's release history, which is the only thing that
actually records it.

## Migrating to 0.12.0 (CIP-113 0.5.0-alpha.5 — the upgrade authority activates itself)

⛔ **EVERY SCRIPT HASH DOWNSTREAM OF THE PARAMS POLICY CHANGES — EIGHT OF TWELVE.** An alpha.4
instance **cannot be upgraded; it must be REDEPLOYED.** The four that survive (`always_fail`,
`issuance_cbor_hex_mint`, `registry`, `upgrade_multisig`) hang off seeds and nonces rather than the
params policy — and a redeployment uses fresh seeds, so they cannot collide with the old instance in
practice.

There is no migration path for a running deployment, and nothing in this SDK will pretend otherwise:
`validateStandardBlueprint` is a version-**equality** gate, so 0.12.0 refuses an alpha.4 blueprint as
firmly as it refuses an alpha.3 one. Stay on 0.11.x for as long as you need to keep operating an
alpha.4 instance.

⚠ **An earlier draft of this note said "every script hash changes". That was FALSE and it is
recorded here rather than quietly corrected**, because the false version is *checkable*: one
operator deriving `registry` at their old seeds finds it identical, and the credibility of the whole
migration note goes with it. The eight/four split is measured in `test/hash-cascade.test.mjs`. The
operational conclusion did not change.

### What upstream changed — one line

`protocol_params.mint` gained a single check:

```aiken
pairs.has_key(self.withdrawals, genesis_params.upgrade_cred)?
```

The transaction that mints the protocol-params NFT must now carry a **withdraw-0 from the
credential its own datum names as the upgrade authority**. The authority has to *run* — through
the same trampoline every later upgrade uses — before it becomes canonical, so a typo or the hash
of a script nobody deployed can never take the protocol's upgrade seat. Measured against alpha.4:
34 validators either side, **31 byte-identical**, and the only compiled code that moved is
`protocol_params`'s.

### Why one line relocates eight of the twelve

`protocol_params`'s hash **is** the params-NFT policy id, and that policy id is the parameter at the
root of the parameterisation graph. It feeds `programmable_logic_base`, and through it `transfer`,
`third_party`, `unfracking` and `programmable_logic_global`; it feeds `issuance_logic` and
`issuance_mint` directly. Only the four scripts that hang off seeds and nonces instead —
`always_fail`, `issuance_cbor_hex_mint`, `registry`, `upgrade_multisig` — keep their alpha.4 hashes
for the same inputs. This is measured in `test/hash-cascade.test.mjs` against a live alpha.4
deployment record, not asserted.

### What moved in this package's API

**`buildProtocolGenesisTx` takes two new REQUIRED fields.**

```diff
  await buildProtocolGenesisTx({
    client, changeAddress, availableUtxos, evaluator, plan,
    protocolParamsSeedUtxo, issuanceSeedUtxo,
+   upgradeMultisigConfigUtxo,   // REQUIRED — the config UTxO, as a reference input
+   upgradeAuthoritySigners,     // REQUIRED — key hashes for `extra_signatories`; may be []
  });
```

`upgradeMultisigConfigUtxo` is the UTxO `assertMultisigConfigUtxo()` already returns: read it back
off the chain rather than reconstructing it from a record, because a signer rotation spends and
recreates it. `upgrade_multisig.withdraw` finds its authority tree among the transaction's
**reference inputs**, so without it the withdrawal cannot be decided.

`upgradeAuthoritySigners` **cannot be defaulted or inferred, and that is structural.** A
`MultisigScript` tree has seven node kinds; only `Signature` names a key hash. `Script` names
another withdraw-0, `Before`/`After` name a validity bound, and `AnyOf`/`AtLeast` leave a genuine
choice of *which branch* to satisfy. Picking a branch is the caller's decision. Pass `[]` if your
tree needs no signature — but pass it.

⚠ **What this builder does not do for you.** It adds signers, the withdrawal, the reference input
and the script witness. A tree whose satisfying branch needs a `Script` leaf (a second withdraw-0)
or a `Before`/`After` leaf (a validity interval) is **not** served by this step; such a deployment
must build its own genesis, or this builder must grow those inputs first. Left out deliberately
rather than guessed at.

**`BOOTSTRAP_STEPS` reordered, and the strings did not change.** `stake-registrations` moved from
last to **third**, ahead of `protocol-genesis`:

```diff
- seed → multisig-genesis → protocol-genesis → reference-scripts → stake-registrations
+ seed → multisig-genesis → stake-registrations → protocol-genesis → reference-scripts
```

This is a ledger rule, not a preference: a reward account cannot be withdrawn from in the same
transaction that registers it, because withdrawals are applied against the state **before**
certificates. A caller that drives the sequence off `BOOTSTRAP_STEPS` follows automatically. One
that hard-coded the old order gets ledger code **3141**, *"rewards withdrawals must consume rewards
in full"* — a message that names a balance problem and not a missing certificate.

### The blueprint

`blueprints/standard/v0.5.0-alpha.5/` ships alongside the older directories, pinned to upstream
`b83a041eaa053625c502f8ee64b607a787cf5f79` and **reproduced from source** (Aiken v1.1.23+8949565,
sha256 `ca53475332b5932f021fa134f823b932b05433ccd335bbf6251f18167826da66`, 164120 bytes). ⚠ That
commit is a **PR branch head** (`refs/pull/143/head`), not a commit on `main`; see
`blueprints/standard/v0.5.0-alpha.5/UPSTREAM_PIN.json` for why the pull ref is recorded alongside
the branch name.

## Migrating to 0.11.0 (a wrong network label, and the bootstrap becomes public API)

Two changes. The first is breaking for plugin authors and silent in one shape the compiler will
not catch. The second is purely additive.

### `SubstandardContext.network` was wrong, and its type hid it

It was declared `string` and computed from `chain.id` — which is the **address** network id, `1`
for mainnet and `0` for *every* testnet. **A preview client was therefore labelled `"preprod"`,
and so was a devnet.** It is now `network?: Network`, derived from the chain's **network magic**,
and a chain that is none of the three public networks yields **`undefined`** rather than a wrong
name.

```diff
- network: string          // "preprod" on preview, and on a devnet
+ network?: Network        // "preview" on preview; undefined on a devnet
```

⛔ **The shape the compiler will NOT catch.** At 0.10.0 the field was declared `string` while the
package exported a `Network` union, so a plugin that wanted the union **had no choice but to
cast**:

```ts
switch (ctx.network as Network) { case "mainnet": … case "preprod": … case "preview": … }
```

**That cast still compiles and now yields `undefined` at runtime** — the exhaustive switch falls
off the end and returns `undefined`, with no diagnostic anywhere. **Remove the cast.** Untyped
JavaScript has the same exposure: `` `https://${ctx.network}.…` `` becomes `https://undefined.…`,
`ctx.network.toUpperCase()` throws, and `JSON.stringify(ctx)` drops the key on a devnet.

⚠ **The label is derived from the magic alone**, so a private network reusing a public magic is
labelled as that network — a mainnet-fork devnet reports `"mainnet"`. If you gate a destructive
path on `network !== "mainnet"`, that gate does not distinguish a fork from the real thing.
`networkFromChain(chain)` is exported if you want the same mapping yourself, and
`ctx.client.chain.networkMagic` / `.name` are on the same context object when you need more.

### The protocol bootstrap is now exported

`planBootstrap()`, five step builders and `assembleDeploymentParams()` build the transactions that
stand up a protocol instance. **The SDK returns unsigned transactions and does not sign, submit or
await** — orchestration, key handling and confirmation stay with the caller, which is also what
lets a caller keep its own UTxO reservation and resume at a step rather than restart.

The sequence is **stepwise, not a batch**: the one-shot minting policies are parameterised by
output references of an earlier transaction, so step N+1 cannot be built until step N has been
submitted and observed.

⚠ **Values a caller must decide are required inputs, not defaults** — `maxInlineDatumBytes` (a
security parameter), the one-shot nonces, the seed and reference-script lovelace, and
`availableUtxos`. There are no devnet defaults in the published path: no mnemonic, no endpoint, no
fixture values. `availableUtxos` is required on every step precisely so a caller can reserve its
seed UTxOs from coin selection — a wallet-wide selection can otherwise spend a seed a later step
names, or spend live reference scripts.

## Migrating to 0.10.0 (a required field on `DeploymentParams`)

**0.10.0 adds one REQUIRED field and breaks every consumer that builds a `DeploymentParams`
literal.** It is a minor bump because this package is pre-1.0; treat it as major. It targets the
same protocol version as 0.9.0 — CIP-113 0.5.0-alpha.4, upstream
`7e8a63198c5b240135f1aa2f043ce5d7c046b2c4` — so **no on-chain behaviour changed and no redeployment
is needed**. The break is in what a deployment record must say about itself.

```diff
  programmableLogicGlobal: {
    scriptHash: ScriptHash;
+   unfrackingParameter: ScriptHash;   // REQUIRED
  }
```

**What to write in it:** the unfracking hash `programmable_logic_global` was **compiled against**.
For an ordinary deployment that is `deployment.unfracking.scriptHash` — the same value, written
twice on purpose. For a deployment launched with unfracking **disabled**, it is the exported
constant `UNFRACKING_DISABLED`.

⛔ **Why there is no default, and why the field is not a boolean.** A deployment now contains **two
legitimate unfracking values** — the real deployed hash, and the hash the dispatcher was compiled
against — and **which one PLG used cannot be inferred**, because both appear in the record and each
is correct for its own purpose. A boolean would not help: the reader would still need this SDK's
constant to reconstruct what was hashed, so the fact determining the dispatcher's script hash would
live in two places, one of them a version of this package. **A deployment file opened in three years
must say what PLG was built from without needing the SDK that built it.**

And a default would have been the quietest possible failure: `?? deployment.unfracking.scriptHash`
is **correct for every record written before this release** — and wrong for the first record written
after it. A wrong default announces itself; one that is right until precisely the case it was added
for does not.

⚠ **It is validated, not merely typed.** The recorded value must be an own property (an inherited
`Object.prototype` key is refused), 56 lowercase hex characters, and **either** the derived
unfracking hash **or** `UNFRACKING_DISABLED` — nothing else. Uppercase is refused and reported as a
case problem rather than normalised, because the recorded spelling is what the dispatcher was
compiled against. Untyped JavaScript callers hit these refusals at load time rather than at build
time.

**Disabling unfracking at launch.** Compile PLG against `UNFRACKING_DISABLED` and record that;
deploy, register and publish the unfracking script exactly as normal. The dispatcher's unfracking
arm can then never be satisfied. Enabling it later is one recompile: rebuild PLG with the real hash,
publish that one reference script, and `PROTOCOL_UPGRADE` the params datum's `plg_cred` — no new
unfracking deployment, no re-registration, registry nodes untouched, no token reissued.

## Migrating to 0.9.0 (CIP-113 0.5.0-alpha.4)

**0.9.0 targets a different protocol version and breaks every published consumer.** It is a
minor bump because this package is pre-1.0; treat it as major. Version 0.8.0 was never published,
so the real upgrade path is 0.3.1, or any later published release up to 0.7.0, to 0.9.0 and crosses both the
alpha.2-to-alpha.3 and alpha.3-to-alpha.4 boundaries described here.

⛔ **The alpha.3 change that will not announce itself.** `programmable_logic_base`'s redeemer went
from a three-constructor enum to a single record:

```
0.5.0-alpha.2   SpendViaTransfer(params_idx, wdrl_idx)   = Constr(0, [Int, Int])
0.5.0-alpha.3   BaseSpendRedeemer{params_idx, wdrl_idx}  = Constr(0, [Int, Int])
```

Those are **byte-identical**. A stale builder emitting `SpendViaTransfer` produces a redeemer that
decodes cleanly and fails later on a credential check — because `wdrl_idx` now indexes the
**dispatcher's** withdrawal, not the delegate's. `SpendViaThirdParty` and `SpendViaUnfracking`
(constructors 1 and 2) fail loudly instead, so **the silence lands on the transfer path — the common
one**. This SDK refuses the stale call shape at the API surface, because nothing downstream can.

⛔ **The alpha.4 datum change is silent for the same reason.** The protocol-params datum grew
from four fields to six, and `issuance_logic_cred` was inserted at **index 1**, not appended:

| protocol version | protocol-params datum | size |
|---|---|---|
| 0.5.0-alpha.3 | `[plg, transfer, third_party, upgrade]` | 4 fields |
| 0.5.0-alpha.4 | `[plg, ISSUANCE_LOGIC, transfer, third_party, upgrade, pending]` | 6 fields |

Indices 1, 2 and 3 all hold a `Credential` before and after the change. An alpha.3 positional
reader therefore returns well-formed credentials with the wrong meanings: `transfer_cred` moved
to index 2, `third_party_cred` moved to index 3, and the old index 3 is no longer the upgrade
credential. Nothing throws or fails to decode. Change positional readers to the six-field alpha.4
layout and treat the field names, not their old positions, as the authority.

⛔ **Every mint and burn now needs `issuance_logic`'s withdraw-0.** `issuance_mint` does not
diagnose an omitted withdrawal: `covered_by` scans the transaction redeemers, returns `False` when
it finds no matching withdrawal, and the mint fails naming no withdrawal, no policy and no index.
Calling `register()`, `mint()`, or `burn()` on a 0.9.0 protocol emits the withdrawal and its
policy-keyed redeemer alongside the minting-logic withdrawal.

⚠ **CIP-68 metadata now meets the deployment's inline-datum bound on the issuance path.** At the
CIP-68 datum shape, the chain's `serialise_data` measurement is exactly 2 bytes fewer than the
SDK's `Data.toCBORBytes` measurement: Evolution emits indefinite-length CBOR for the outer
constructor and metadata map, while Plutus's canonical encoder uses definite-length headers. The
SDK is conservative: it never accepts a record the chain refuses. A caller's usable budget is
`maxInlineDatumBytes - 2`; do not loosen the SDK comparison to reclaim those two bytes.

| what changed | before | after |
|---|---|---|
| params NFT policy vs address | two derivations | **one hash serves both** (`protocolParams.policyId`) |
| registry node policy vs address | `directoryMint` / `directorySpend` | **one hash serves both** (`registry.scriptHash`) |
| protocol-params datum | 7 fields | **4** in alpha.3, then **6** in alpha.4 |
| PLB redeemer | `SpendVia*` enum | `BaseSpendRedeemer` record; the act moved to the dispatcher |
| `transferRedeemer` | `(params_idx, proofs)` | `(proofs)` |
| `thirdPartyRedeemer` / `unfrackingRedeemer` | `(params_idx, node_idx, outputs_start_idx)` | `(node_idx, outputs_start_idx)` |
| every programmable tx | delegate withdraw-0 | **plus the dispatcher's** — every `wdrl_idx` shifts |
| every mint and burn | minting-logic withdraw-0 | **plus `issuance_logic`** |
| new deployment input | — | `maxInlineDatumBytes`, a **choice**, baked into four script hashes |
| gone | `coordinationNonce`, `coordination`, `directoryMint`, `directorySpend` | — |

⚠ **`max_inline_datum_bytes` changed KIND, not just place.** It was a mutable datum field
(re-tunable by an in-place upgrade) and is now a compile-time parameter of four delegates —
`transfer`, `third_party`, `unfracking` and `issuance_logic` — so changing it is a redeployment.

⚠ **Neither an alpha.3 nor an alpha.2 deployment can be represented by this SDK.** A 4-field
alpha.3 params datum and a 7-field alpha.2 one are rejected outright rather than read
positionally. No published release of this SDK operates an alpha.3 instance; its 0.8.x source line
must be built from git. Point an alpha.2 instance at a published 0.7.x release.

## Examples

> ### ⚠ The examples do not currently run. Do not follow this section yet.
>
> Two things are wrong with it, both known and neither hidden:
>
> 1. **The scripts target a superseded protocol.** They are written against a CIP-113 **0.3.x**
>    deployment on preprod. This SDK now targets **0.5.0-alpha.3**, in which `DeploymentParams`
>    has a different shape again — see the migration note below.
>    The scripts cannot work against that deployment, and the deployment cannot be represented
>    by this SDK.
> 2. **`.env.example` does not exist.** The `cp` below has never worked.
>
> **Nothing here is covered by CI** — `examples/` is a separate package, outside the root
> typecheck and outside the test suite, so neither defect can fail a build.
>
> Choosing a replacement target is an open decision (a local devnet, or a freshly deployed
> preprod instance); it is tracked in `PLAN.md` under workstream **W-E, slice S-7**. Until it is
> made, the working end-to-end reference is the **devnet suite** — `npm run test:devnet` — which
> exercises bootstrap, register, mint, transfer, third-party transfer and an in-place upgrade
> against a live chain. See `docs/devnet.md`.

The `examples/` directory contains runnable scripts for the full token lifecycle:

```bash
cd examples
cp .env.example .env    # add your Blockfrost key + seed phrase
npm install
npm run fes:setup
npm run fes:init-compliance
npm run fes:register
npm run fes:transfer
npm run fes:mint
npm run fes:burn
npm run fes:freeze
npm run fes:transfer-blocked
npm run fes:seize
npm run fes:unfreeze
npm run fes:transfer-unfrozen
```

Each script is standalone — run them sequentially to walk through the complete Freeze-and-Seize lifecycle.

## Documentation

- [Provenance: CIP-171 and blueprint pins](docs/provenance.md) — what ships, how to build a record, and why `compilerVersion` must come from the artefact

- [Getting Started](docs/getting-started.md) — prerequisites, setup, first token
- [API Reference](docs/api-reference.md) — all types, methods, utilities
- [Freeze-and-Seize](docs/substandards/freeze-and-seize.md) — compliance substandard
- [Dummy](docs/substandards/dummy.md) — minimal test substandard

## Peer Dependencies

- `@evolution-sdk/evolution` ^0.5.2
- `effect` ^3.0.0

## License

Apache-2.0

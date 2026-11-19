# The CIP-113 upgrade lifecycle, executed on preview

This document records three protocol lifecycle operations executed against a real CIP-113
deployment on the Cardano **preview** testnet, on 2026-10-01, using the builders this SDK exports.
Every claim below is either a transaction hash you can look up yourself, or a deduction stated as
one. Nothing here asks you to take the SDK's word for anything.

The operations are:

1. **Signer rotation** — change who controls the upgrade authority, without changing the authority's
   credential.
2. **Protocol upgrade and restore** — repoint the live wiring at credentials that do not exist, then
   put it back.
3. **Authority handover** — move `upgrade_cred` to a different `upgrade_multisig` instance, in the
   two phases the validator requires.

Before this run, none of the three had been executed on a public chain. The signer rotation had
never been executed anywhere, by anything — `upgrade_multisig.spend` has been supported upstream
since #125 and no code in this repository built a transaction for it. The authority handover had
only ever been run as multisig → *key*; multisig → *multisig* was blocked by an authorisation
router that refused any script authority other than the deployment's own.

---

## The instance

| | |
|---|---|
| Network | preview (network id 0) |
| Protocol genesis tx | `28cda7d1fc8e05408fc3194a1746a4562522e5bc60ae719f32fce71daee7bc67` |
| `protocol_params` address | `addr_test1wzk0n3rx9rgd0597zcr2tx4g4a79j7ff8envxdx24d0fvdgj3l57a` |
| `protocol_params` policy id | `acf9c46628d0d7d0be1606a59aa8af7c5979293e66c334caab5e9635` |
| `upgrade_multisig` at bootstrap | `8d94ea6c71fbce6a0c055f54627bf317481043e50a143e72c206585b` |
| `upgrade_multisig` address | `addr_test1wzxef6nvw8auu6svq404gcnm7vt5syzru59pg0njcgr9skcp98ln2` |
| Deployment record | [`deployments/preview/upgrade-lifecycle.json`](../deployments/preview/upgrade-lifecycle.json) |
| Campaign record | [`deployments/preview/upgrade-lifecycle-record.json`](../deployments/preview/upgrade-lifecycle-record.json) |

The four signers are derived from one mnemonic at account indices 0–3. **They are accounts of the
wallet that funded the instance**, so whoever holds that seed holds the authority — this document
makes no claim that the instance is beyond anyone's control, because that would not be true.

| signer | payment key hash |
|---|---|
| acct0 (admin, fee payer) | `ae0e585474fd30f5c82440e10b29565cbd3c64210838bdc898b86f42` |
| acct1 | `4a3c7b1573af3d61e02cd9fa23b5d8188ba1ff15469e59df07157b03` |
| acct2 | `cc1752722c295b11a2bc7496f49bc503794bae25aa4428006385be65` |
| acct3 | `8596ef9c04aee86d9ac3c80268d67e2511498a72586dea4038683990` |

---

## Is this the production contract code?

This is the question worth answering first, because every operation below is meaningless if the
scripts on chain are not the audited upstream validators.

**⚠ CIP-171 is not the answer, and it is the answer people reach for.** The protocol genesis
transaction `28cda7d1…` carries metadata label **1984**, a CIP-171 provenance record, and that
record is what lets a tool like uplc.link *find* these scripts. But a CIP-171 record is metadata the
**submitter writes**. It indexes a script hash to a claim about where the script came from; it is
evidence of an assertion, not evidence of the assertion's truth. Treat it as a discovery layer.

The verifiable chain of custody has three links, and you can walk all three:

**1. The blueprint reproduces from upstream source.** `blueprints/standard/v0.0.1/UPSTREAM_PIN.json`
records the recipe and the result:

```
git clone https://github.com/cardano-foundation/cip113-programmable-tokens
cd cip113-programmable-tokens
git fetch origin tag v0.0.1
git checkout 6b75ba3286b4692ca23059ff51285db357fb09c6
aikup install v1.1.23
rm plutus.json && aiken build && sha256sum plutus.json
#  b6c8cb096a15e02f1b9c719fb8c617b624c1aa7719f2258d45faa3e8f144e7b9   164112 bytes
```

Reproduced 2026-09-24 in a throwaway clone with upstream's own `plutus.json` **deleted before the
build**, so it could not be mistaken for the output. `aiken.toml` pins stdlib v3.1.0 and fuzz v2.2.0,
both immutable tags, so this claim needs no scope note.

The pin is to the **commit**, not the tag: `v0.0.1` is an annotated tag whose target is
`6b75ba32…`, and a tag can be moved while a commit cannot.

**2. Every on-chain script hash re-derives from that blueprint.** `assertDeploymentScripts` applies
the parameterisation cascade to the blueprint and compares all ten resulting hashes against the
deployment record. The campaign runs this as its first act and prints the count; a record describing
any other protocol version, or any other instance, is refused before a transaction is built:

```
provenance : 10 script hashes re-derived from the v0.0.1 blueprint and matched
```

**3. The addresses are the hashes.** Each of these validators uses one script hash for two roles, so
the NFT policy id and the address's payment credential are the same value by construction. You can
therefore check the addresses in the table above against the hashes without trusting any mapping:
`protocol_params`' policy id *is* its address's payment credential.

**⚑ One upstream fact that saves confusion:** `v0.0.1` is upstream's first mainnet release candidate
and is a **relabel of `0.5.0-alpha.5`**. All 34 validators' compiled code is byte-identical; the only
difference in the artefact is `preamble.version`, an 8-byte file-size delta exactly equal to the
length difference of the two strings. So every derived script hash is unchanged between them.

---

## Operation 1 — signer rotation

`upgrade_multisig.spend`. The authority's configuration lives in a **datum**, not in the script's
parameters, so rotating signers is a datum edit and the authority's *credential never moves*. That
is the whole point of the design: before upstream #125 every rotation produced a new script, a new
credential, and therefore required a full `upgrade_cred` handover.

| # | what | tx |
|---|---|---|
| 1 | 1-of-1 → 2-of-3 | [`085b71938a2ee27fb6e2c4f7291380e0704d0986fd0c48836cc35fc83fe7377e`](https://preview.cardanoscan.io/transaction/085b71938a2ee27fb6e2c4f7291380e0704d0986fd0c48836cc35fc83fe7377e) |
| 2 | 2-of-3 → a different 2-of-3, **two witnesses** | [`29d1b449200c5cb178dd752d0381a1bac85e2b3bb94e3229828ca4a5b167f4fe`](https://preview.cardanoscan.io/transaction/29d1b449200c5cb178dd752d0381a1bac85e2b3bb94e3229828ca4a5b167f4fe) |

**What to verify.** Fetch each transaction's output at the `upgrade_multisig` address and decode its
inline datum. Read off the chain, the three states are:

```
bootstrap         signature(ae0e5854…)                                  — one key, the admin's
after rotation 1  at-least 2 of [ae0e5854…, 4a3c7b15…, cc175272…]       — acct0, acct1, acct2
after rotation 2  at-least 2 of [ae0e5854…, 4a3c7b15…, 8596ef9c…]       — acct2 out, acct3 in
```

Rotation 1 is authorised by the single key the bootstrap installed. **Rotation 2 is the interesting
one**: the tree being replaced is a 2-of-3, so the transaction carries two vkey witnesses, and the
rule the validator applies is *the tree being replaced must approve its replacement*. Note that
`acct1` holds no funds at all — it signs because the transaction **names its key in
`required_signers`**, which is what `satisfied` reads for a `Signature` leaf. A wallet that merely
signs is not enough.

`upgrade_cred` in the protocol params is **unchanged** across both rotations. You can confirm that
from the params datum before and after: the authority is `8d94ea6c…` throughout.

---

## Operation 2 — break the protocol and put it back

`ProtocolUpgrade`, four times. This arm is authorised by the sitting authority's withdraw-0 and
**freezes both authority fields**, so a handover can never ride inside what looks like a parameter
change.

| # | what | tx |
|---|---|---|
| 3 | `thirdPartyCred` → `de…de` | [`5a61f3092724ec88a91438fec17a8ef928d38ea76d1d6cb316b1fba69c6692c8`](https://preview.cardanoscan.io/transaction/5a61f3092724ec88a91438fec17a8ef928d38ea76d1d6cb316b1fba69c6692c8) |
| 4 | `thirdPartyCred` restored | [`c2faaff5d6d12279e58cb7b474d02514cb79bc34136d6cc9fa8b19978f2e2f69`](https://preview.cardanoscan.io/transaction/c2faaff5d6d12279e58cb7b474d02514cb79bc34136d6cc9fa8b19978f2e2f69) |
| 5 | **all four** mutable delegates → fakes | [`0e4302e4fa8a5a92a8c8955f2374b20295ec3066f11fe34d84f7029bfff52d1d`](https://preview.cardanoscan.io/transaction/0e4302e4fa8a5a92a8c8955f2374b20295ec3066f11fe34d84f7029bfff52d1d) |
| 6 | all four restored | [`eba686445988d18ddc4053f0380d818983a6bcd1be7f0de42db12be37d55f56b`](https://preview.cardanoscan.io/transaction/eba686445988d18ddc4053f0380d818983a6bcd1be7f0de42db12be37d55f56b) |

The fake credentials are deliberately recognisable: `de`, `ad`, `be` and `ef` repeated 28 times. They
are well-formed 28-byte hashes behind which **no script exists** — uplc.link has nothing for them,
which is the point.

**What to verify.** Decode the `protocol_params` output datum of each transaction. After tx 5 the
datum names four credentials for which no script exists anywhere; after tx 6 it is **byte-for-byte
identical to the genesis datum**. The campaign asserts that equality on the decoded params and
refuses to continue otherwise.

**Why this is safe rather than reckless, and why the protocol is repairable.** The repair is
authorised by `upgrade_cred`, which this arm freezes — and no path in the spend, withdrawal, address
or fee/collateral handling reads any of the four credentials being rewritten. `protocol_params.spend`
reads only: its own input, exactly one continuing output at its own address, no reference script,
non-ADA value conserved, the datum well-formed with 28-byte credentials, and the redeemer arm's rule.
`params_well_formed` **length-checks** credentials and nothing more. That is what makes the break
possible and the restore certain.

**⚠ What a break does to the tokens.** While the fakes are installed, programmable tokens cannot
move: `programmable_logic_base.spend` requires a withdrawal from the credential the params datum
names, and with a fake hash no such credential can appear. The protocol is frozen, not damaged, and
tx 6 unfreezes it.

**⛔ Two things an upgrade cannot change, and they are not limitations of this SDK.**
`programmable_logic_base_cred` and `registry_node_cs` are **compile-time parameters of the
delegates**, not fields of the params datum, so no upgrade edits them in place. Their values remain
reachable one hop away — an upgrade that rewrites `programmable_logic_global_cred` installs a
dispatch layer naming delegates of the authority's choosing, and those delegates carry whatever
parameters they were applied with — but that is a different operation from editing a datum field.

---

## Operation 3 — the authority handover

Moving `upgrade_cred` is **two-phase, and deliberately the one thing a sitting authority cannot do
in a single step.** Phase 1, under `NominateAuthority`, the sitting authority writes
`pending_upgrade_cred`; this is an ordinary, reversible upgrade. Phase 2, under `PromoteAuthority`,
the **nominee presents its own withdraw-0**, which promotes it and clears the nomination — and that
is the only transaction shape that may move `upgrade_cred` at all.

The evidence the design demands is that the incoming authority **exists, runs, and consents**, so a
typo or the hash of a script nobody deployed can never take over.

**⇒ A handover is therefore a minimum of four ordered transactions**, not two — the nominee has to
exist and be registered before it can withdraw:

| # | what | tx |
|---|---|---|
| 7 | a second `upgrade_multisig` minted, 2-of-2 of acct2+acct3 | [`d7c5c1157d17a623fe2053c8c0041d6a2f8a7034d8fce2a249956dd41cdcffa4`](https://preview.cardanoscan.io/transaction/d7c5c1157d17a623fe2053c8c0041d6a2f8a7034d8fce2a249956dd41cdcffa4) |
| 8 | its stake credential registered, in its **own** transaction | [`ab844871bc878fbc13dd5bf6547d7b11387f434e80f937ad2ac896f38d887acf`](https://preview.cardanoscan.io/transaction/ab844871bc878fbc13dd5bf6547d7b11387f434e80f937ad2ac896f38d887acf) |
| 9 | `NominateAuthority` — the sitting authority names its successor | [`2ea2fb3b01db07f9c93910cbafeb74e692c0fdb22b68a01e0f65a0727b42d807`](https://preview.cardanoscan.io/transaction/2ea2fb3b01db07f9c93910cbafeb74e692c0fdb22b68a01e0f65a0727b42d807) |
| 10 | `PromoteAuthority` — the nominee promotes itself | [`3fa94d24bdcf88acfdfaf4c00fa669092831bb3c6c5c6a4e80002c2b384fc24a`](https://preview.cardanoscan.io/transaction/3fa94d24bdcf88acfdfaf4c00fa669092831bb3c6c5c6a4e80002c2b384fc24a) |
| 11 | the **new** authority performs an upgrade | [`0d739c0c8e980cd41dc9caeb6ce8f71ad6fcb7640cbe488d2a125bba4d71f954`](https://preview.cardanoscan.io/transaction/0d739c0c8e980cd41dc9caeb6ce8f71ad6fcb7640cbe488d2a125bba4d71f954) |
| 12 | restored again, under the new authority | [`e1f1e17f9ed52c9be535e696a73374bbbf20e44bbd0183846a7da171ae009ae9`](https://preview.cardanoscan.io/transaction/e1f1e17f9ed52c9be535e696a73374bbbf20e44bbd0183846a7da171ae009ae9) |

The nominee is a genuinely different script, with its own one-shot seed, hash, body and config UTxO:

```
authority at bootstrap   8d94ea6c71fbce6a0c055f54627bf317481043e50a143e72c206585b
authority at the end     09cdc422e85525f8149b523b8dad143854aad73d21cb6ccdc399b42e
nominee's config address addr_test1wqyum3pzap2jt7q5ndfrhrddzsu9f2kh85sukmxdcwvmgts6jyfxq
```

**What to verify.** After tx 9 the params datum carries `pending_upgrade_cred = Script(09cdc422…)`
with `upgrade_cred` **still** `8d94ea6c…` — a nomination does not move the authority. After tx 10,
`upgrade_cred` is `09cdc422…` and the nomination is `None`.

**⛔ Tx 11 is what makes the handover real.** A datum field that changed proves a write happened. An
*upgrade authorised by the new authority* proves its credential is live, registered, and satisfied by
its own tree. Without tx 11 the handover is a plausible-looking datum edit.

**⚠ Why registration must be its own transaction (tx 8).** The ledger applies withdrawals against
reward-account state **before** it applies certificates, so registering a credential and withdrawing
from it in one transaction is not one transaction — it is two. Getting this wrong reports as ledger
code **3141**, *"rewards withdrawals must consume rewards in full"*, which reads as a balance problem
and means an unregistered credential.

**⚑ Exclusivity: the promotion carries only the nominee's withdrawal.** You can read the withdrawal
set of tx 10 off the chain and see exactly one entry, the nominee's. This is worth stating precisely
because **the chain does not enforce it**: upstream's rail is `has_key(withdrawals, nominee)`, an
existence check that never mentions the sitting authority, so a promotion carrying *both*
withdrawals would be accepted. The property "a promotion does not need the outgoing authority" is
therefore not provable by any on-chain negative — but the public record of this transaction does
show the sitting authority was not involved.

---

## Findings from the run

Things that were learned by doing this, which are not visible from the validators.

**1. The signer set is the union of two unrelated requirements.** Signing tx 10 with the nominee's
quorum alone was refused with ledger code **3101**,
`missingSignatories: [ae0e5854…]` — the admin's payment key. A transaction needs witnesses for

- the **authority's** satisfying subset, which the tree reads out of `required_signers`; and
- whoever **owns the inputs**, because the fee and collateral come from an ordinary wallet whose
  UTxOs are locked by its payment key.

These are different questions. Every earlier step in this campaign happened to be signed by a set
that *contained* the fee payer, which is why it surfaced only at the promotion — the first
transaction whose authority quorum excludes the wallet paying for it. That is exactly the shape a
real handover has: the incoming authority consents, and somebody else pays.

**2. A confirmed transaction and an updated UTxO view are different facts.** The first attempt at
operation 2 was refused by Blockfrost's evaluator with a bare `evaluateTx failed`. The cause was that
`/txs/{hash}` and `/addresses/{addr}/utxos` advance **independently**: the rotation was confirmed
while the UTxO set still showed the outputs it had spent, so the next transaction was built against
stale inputs. Waiting for the transaction is waiting on the view that is already correct. The
campaign now waits for the *wallet's* UTxO view to stop changing before each build.

**3. A refused transaction leaves no trace on chain.** Every "REFUSED" result in this work — a
quorum one signature short, a promotion with no standing nomination, a malformed credential — is
caught offline by the SDK or rejected at submission, and in neither case is there anything for a
third party to look up. Those refusals are reported in this repository's test suite with their
mutation evidence; they are **not** claimed here as independently verifiable, because they are not.
The only way to make a refusal visible on chain is to submit a phase-2-invalid transaction with
`isValid = false`, which is recorded as a possible future addition and was not done.

---

## Reproducing this

The campaign is `test/harness/upgrade-preview.ts` (a harness fixture — not part of the published
package, which ships only `dist` and `blueprints`). The builders it drives are exported SDK surface:

```ts
import {
  locateProtocolParams, locateUpgradeMultisig,   // read the governable state
  buildRotateMultisigTx,                          // operation 1
  buildProtocolUpgradeTx,                         // operation 2
  buildNominateAuthorityTx, buildPromoteAuthorityTx,   // operation 3
  buildStandaloneMultisigGenesisTx, buildRegisterCredentialTx,  // stand up a nominee
  satisfiesMultisigTree,                          // offline preflight
  assembleMultiSignedTx, assertVKeyWitnessCount,  // M-of-N assembly
  spendableWalletUtxos,                           // never spend a live reference script
} from "@easy1staking/cip113-sdk-ts";
```

Every builder returns an **unsigned** transaction and reads the UTxOs you hand it. The SDK does not
sign, submit, await, hold keys, or name a network endpoint.

The same campaign runs on a local devnet as `test/devnet/upgrade-lifecycle.test.ts`, where it
additionally asserts the offline refusals that cannot be shown on a public chain.

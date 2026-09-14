# Contract Surface Changes Since the Pre-Audit Baseline

Tracking document for every **breaking change to the contract surface**
(validator set, blueprint parameters, redeemer schemas, off-chain-built
datums, and transaction-shape requirements) introduced by the audit-fix
work. Purpose: drive the documentation rewrite and the migration of the
Evolution CIP-113 SDK (`/Users/giovanni/Development/workspace/cip113-sdk-ts`)
once the audit branch work settles.

- **Baseline**: `8143853` ("chore: removed unwantes build script") — the
  last commit on `main` before the first audit-fix merge (#51,
  2026-05-19). Everything earlier (incl. #50 publish handlers) is
  considered pre-audit surface.
- **Method**: `plutus.json` is committed at every merge, so validator
  titles, parameters, and redeemer schemas were diffed mechanically
  commit-by-commit along `main` (first-parent) and for each open PR
  head. Off-blueprint datums (`RegistryNode`, the protocol-params
  datum) were tracked through `lib/registry_node.ak` /
  `programmable_logic/params.ak` type definitions. Semantic/tx-shape
  changes come from the PR diffs.
- Open PRs are listed as **PROVISIONAL — subject to change** until
  merged. Last refreshed: **2026-09-02** (dispatcher reintroduction + params-spend rename +
  registry merge + params datum reduced to four fields).

## Systemic note: every merge re-hashes everything

Independent of schema changes, ANY validator code change produces new
script hashes, and the protocol's parameter chaining cascades it
everywhere: `issuance_mint`'s template bytes feed the `IssuanceCborHex`
reference datum (prefix/postfix), `registry_mint` is parameterised by
`issuance_cbor_hex_cs` and `registry_spend_cred`, the protocol-params
datum embeds `prog_logic_cred`, and `programmable_logic_base` is
parameterised by PLG's credential. Consequently **every merged PR below
implies a full protocol redeployment** (new addresses, new
IssuanceCborHex data, new params NFT) even when marked "no schema
change". The SDK fetches blueprints from the backend API so hashes flow
through automatically — the breakage points are the **hand-coded
builders** (datums, redeemers, parameter application arity/order) and
**tx-shape requirements** listed below.

---

## Merged on `main`

### PR #51 — Findings 03, 08, 09 (`0a04cc2`, 2026-05-19)

| Surface | Change | Breaking? |
|---|---|---|
| `issuance_mint` params | **Added 4th parameter** `plg_stake_cred: Credential` (after `programmable_logic_base`, `registry_node_cs`, `minting_logic_cred`) | **YES** — parameter application arity |
| `registry_mint` params | **Added 3rd parameter** `registry_spend_cred: Credential` (after `utxo_ref`, `issuance_cbor_hex_cs`) | **YES** — parameter application arity |
| Tx shape | Finding 03: registry **origin node must be created at the `registry_spend` address** (Init flow) | YES for registry-init builders |

### PR #52 — Finding 07 (`2f6cd90`)

| Surface | Change | Breaking? |
|---|---|---|
| `registry_mint` redeemer | `RegistryInsert { key, hashed_param: ByteArray }` → `RegistryInsert { key, minting_logic_script: Credential, mode: RegistrationMode }`; new type `RegistrationMode = RegisterOnly \| RegisterAndMint` | **YES** — redeemer builder |
| `RegistryNode` datum (NFT inline datum, built off-chain) | **Inserted `minting_logic_script: Credential` at field index 2** → now `{ key, next, minting_logic_script, transfer_logic_script, third_party_transfer_logic_script, global_state_cs }` (6 fields) | **YES** — positional datum builder/parser |
| Tx shape | Register-only flow (no first mint) now exists alongside register-and-mint | Additive |

### PR #68 — Finding 10 (`1687209`)

| Surface | Change | Breaking? |
|---|---|---|
| `issuance_mint` redeemer | `SmartTokenMintingAction { minting_logic_cred, minting_registry_proof }` wrapper **removed** → redeemer is now `MintingRegistryProof = RefInput { index } \| OutputIndex { index }` directly | **YES** — mint redeemer builder |

### PR #69 — Finding 13 (`ebd9ffa`) — no schema change

- Tx shape: under `ThirdPartyAct`, paired continuation outputs must
  **preserve `reference_script`** (in addition to address and datum).
  3P transaction builders must copy the field. Hash-cascade only
  otherwise.

### PR #70 — Finding 19 (`11d74f0`) — no schema change

- Internal redundant length/ordering checks removed from
  `RegistryInsert` (relaxation; no off-chain action). Hash cascade.

### PR #77 — Finding 02 (`a5ed95c`) — no schema change

- Pure mints (mint without spending PLB inputs) are **no longer subject
  to transfer-logic enforcement** under `TransferAct`. Relaxation:
  pure-mint txs no longer need the substandard transfer-logic
  withdrawal. Hash cascade.

### Re-audit R-06 — `RegistryInsert` mode removal (working tree, no PR yet) — PROVISIONAL

| Surface | Change | Breaking? |
|---|---|---|
| `registry_mint` redeemer | `RegistryInsert { key, minting_logic_script, mode }` → `RegistryInsert { key, minting_logic_script }`; type `RegistrationMode` (`RegisterOnly \| RegisterAndMint`) **deleted** | **YES** — redeemer builder (reverts the `mode` half of #52's reshape) |
| Tx shape | None — both flows (register-only and register-and-mint) remain valid; `registry_mint` simply no longer asserts `mode` against `tx.mint` (relaxation) | No |

Rationale: the mode was caller-selected, so the mode ↔ `tx.mint`
consistency check enforced no invariant (R-06). The proof-of-instance
withdrawal (substandard's `minting_logic_script` withdraw-0) remains
required in both flows. Hash cascade as usual.

### Upgradability in place — changes #1+#2 (`feat/upgradability-in-place`, working tree) — PROVISIONAL

| Surface | Change | Breaking? |
|---|---|---|
| `programmable_logic_base` params | Parameter changed from `stake_cred: Credential` (PLG's credential) to `params_policy: PolicyId` (protocol-params NFT policy) | **YES** — parameter application type/value; PLB hash no longer depends on PLG's hash |
| Protocol-params datum (`ProgrammableLogicGlobalParams`) | **Appended field 3 `prog_logic_global_cred: Credential`** → now `{ registry_node_cs, prog_logic_cred, unfracking_cred, prog_logic_global_cred }` (4 fields) | **YES** — params-datum builder (deploy) and any parser |
| Tx shape | Every PLB spend now requires the protocol-params NFT as a **reference input** (previously only PLG required it — same txs, so no practical builder change) | No (already mandatory via PLG) |
| Deployment order | PLB is parameterised by the params NFT policy instead of PLG's credential: PLB can now be built **before** PLG; PLG's credential is written into the params datum at mint time | Deploy-pipeline change |

Rationale (AL call 2026-07-20): PLG becomes swappable in place — an
upgrade rewrites `prog_logic_global_cred` in the coordination UTxO
datum instead of redeploying PLB (whose hash anchors every programmable
token address). Cost impact recorded in `UPGRADABILITY_BENCHMARKS.md`
(~+26.6k mem / +8.6M cpu per PLB input).

### Upgradability in place — change #3 (trampoline 2, working tree) — PROVISIONAL

| Surface | Change | Breaking? |
|---|---|---|
| Protocol-params datum (`ProgrammableLogicGlobalParams`) | **Appended field 4 `upgrade_logic_cred: Credential`** → now 5 fields `{ registry_node_cs, prog_logic_cred, unfracking_cred, prog_logic_global_cred, upgrade_logic_cred }` | **YES** — params-datum builder (deploy) and any parser |
| Validator set | **New `coordination_spend`** (spend; param `nonce: ByteArray`) — replaces the always-fail lock as the coordination-UTxO spender | **YES** — new deploy artefact; NFT lock target moves here |
| Validator set | **New `upgrade_multisig`** (withdraw + publish; params `signers: List<VerificationKeyHash>, threshold: Int`) — reference upgrade authority, the initial `upgrade_logic_cred` target | Additive (a substandard-style deploy artefact; swappable) |
| `protocol_params_mint` | **No code change**; at deploy, lock target parameter is passed `coordination_spend`'s hash instead of always-fail (param still named `always_fail_hash`) | Deploy-wiring change |
| Tx shape | Upgrade tx: spend the coordination UTxO → one continuing output, same address, exact same value (NFT + ADA), inline well-formed datum, `prog_logic_cred`+`registry_node_cs` unchanged, carry `upgrade_logic_cred` withdraw-0 | New capability (upgrades) |

Hot path unaffected: field 4 is append-last, PLB reads field 3 →
benches byte-identical to #1+#2. `coordination_spend` is cold-path
(upgrade txs only): ~184k mem / ~66M cpu. Remaining: #4 lock-target
deploy wiring; authority model (multisig composition / GA handover) is a
committee decision (decision-doc-in-place-upgradability.md).

---

### Upgradability in place — #103 / PR #109: params UTxO by redeemer index (`a4f9bdd`, merged into `feat/upgradability-in-place`)

| Surface | Change | Breaking? |
|---|---|---|
| `programmable_logic_base.spend` redeemer | untyped `Data` (ignored) → **`Int`** = the params-NFT reference-input index | **YES** — every PLB spend redeemer builder |
| `ProgrammableLogicGlobalRedeemer` | every constructor gains a leading **`params_idx: Int`**: `TransferAct { params_idx, proofs }`, `ThirdPartyAct { params_idx, registry_node_idx, outputs_start_idx }`, `UnfrackingAct { params_idx }` | **YES** — PLG redeemer builders |
| `UnfrackingRedeemer` | gains a leading **`params_idx: Int`** | **YES** — unfracking builder |
| Tx shape | Builders compute the params UTxO's position in the ledger-sorted `reference_inputs` and pass it in every redeemer above; a wrong index fails the params-NFT `expect` | Builder change |

Details: `cip113-api-changes-post-audit.md` §16.

### Upgradability in place — validator split (`feat/plg-third-party-split`, PR #110 vs `main`) — PROVISIONAL

The `programmable_logic_global` coordinator is dissolved: third-party
(seize/clawback) logic moves into a new standalone validator, the transfer
arm is renamed `transfer`, unfracking is no longer gated through it, and
`programmable_logic_base` dispatches straight to one of the three.

| Surface | Change | Breaking? |
|---|---|---|
| Validator set | **`programmable_logic_global` renamed `transfer`** — blueprint title `programmable_logic_global.programmable_logic_global.withdraw` → **`transfer.transfer.withdraw`**; same param (`params_policy`), transfer invariants only | **YES** — blueprint lookup key, deploy artefact name |
| Validator set | **New `third_party`** (withdraw + publish; param `params_policy: PolicyId`) — hosts `validate_3rd_party`; new deploy artefact + reference script | **YES** — new deploy artefact; seize txs invoke it |
| Validator set | `unfracking` — unchanged bytes; now dispatched to by PLB directly (no PLG hop) | Tx-shape change only |
| `programmable_logic_base.spend` redeemer | `Int` (params index, §16) → **`BaseSpendRedeemer { SpendViaTransfer { params_idx, wdrl_idx } \| SpendViaThirdParty { params_idx, wdrl_idx } \| SpendViaUnfracking { params_idx, wdrl_idx } }`** (constructors 0/1/2) — picks the delegate + witnesses its withdrawal index (direct `list.expect_at`: O(`wdrl_idx`) cell drops, no per-entry credential comparison). `wdrl_idx` is a position in the ledger-ordered withdrawal map (script creds before key creds, bytewise within each) over the complete withdrawal set. The arm is meaningful only while the three delegate credentials are pairwise distinct — NOT enforced on-chain (deployment / upgrade-authority responsibility) | **YES** — every PLB spend redeemer builder |
| `ProgrammableLogicGlobalRedeemer` | **Type removed** → **`TransferRedeemer { params_idx, proofs }`** (single constructor 0, same field order as the old `TransferAct`); `ThirdPartyAct` → `third_party`'s `ThirdPartyRedeemer`, `UnfrackingAct` → dropped (the `unfracking` validator's own `UnfrackingRedeemer` was already the payload) | **YES** — transfer redeemer builders (bytes compatible with an old `TransferAct` encoder); seize / unfracking builders re-pointed |
| Protocol-params datum (`ProgrammableLogicGlobalParams`) | **6 fields, REORDERED by read-frequency + 2 renamed**: `{ registry_node_cs(0), prog_logic_cred(1), transfer_cred(2), third_party_cred(3), unfracking_cred(4), upgrade_cred(5) }`. New `third_party_cred`; `prog_logic_global_cred`→`transfer_cred`, `upgrade_logic_cred`→`upgrade_cred` (drop "logic"). PLB reads fields 2-4 on dispatch; `coordination_spend` 28-byte-guards each mutable cred | **YES** — CBOR field order + 2 names changed; params-datum builder (deploy) and any positional parser |
| `issuance_mint` | **No param/redeemer change**; mint-custody delegation accepts coverage from the `transfer` validator's `TransferRedeemer` or the `third_party` validator's `ThirdPartyRedeemer` (same-registry-node) | Semantic (delegation recognises the renamed/new validators) |
| Tx shape | Transfer: PLB `SpendViaTransfer` + `transfer` withdraw-0 (+ ref script). Seize: PLB `SpendViaThirdParty` + `third_party` withdraw-0 (+ ref script) carrying `ThirdPartyRedeemer`; issuer's `third_party_transfer_logic_script` withdrawal still required. Unfracking: PLB `SpendViaUnfracking` + `unfracking` withdraw-0 (+ ref script) — the transfer script is NOT loaded. Exactly one framework delegate per tx | Reshaped seize + unfracking txs; transfer tx re-pointed to the renamed title |

Reference-script footprint per tx (measured): transfer `PLB+transfer` 3659 →
3045 B (**−614**), seize `PLB+third_party` 3659 → 2674 B (**−985**),
unfracking `PLB+unfracking` 5491 → 2700 B (**−2791**); the transfer script
3163 → 2177 B (−31%), PLB 496 → 868 B. Execution ~neutral: PLB's 3-arm
dispatch costs a few M cpu at withdrawal position 0; the indexed lookup
breaks even with the old scan at position ~3 and saves ~19M cpu at width 16 /
position 15 (`validators/programmable_logic/wdrl_idx_cost.test.ak`); the
unfracking path drops a whole validator run. Off-chain: SDK
(`cip113-sdk-ts`) + Java backend need the new PLB sum-type redeemer, the
`transfer` title, `third_party` deploy, and `wdrl_idx`/`params_idx`
derivation — tracked separately.

## Audit PRs #78–#81 (open at the 2026-06-11 refresh; since merged to `main`)

### PR #78 — Finding 17, Unfracking (`fix/finding-17-unfracking`)

| Surface | Change | Breaking? |
|---|---|---|
| Validator set | **New validator `unfracking`** (withdraw-0 + publish), blueprint title `unfracking.unfracking.withdraw`, parameter `params_policy: PolicyId`. Must be deployed as a reference script and its stake credential registered | **YES** — new deploy artefact + blueprint lookup key |
| `programmable_logic_global` redeemer | `ProgrammableLogicGlobalRedeemer` gains **`UnfrackingAct`** (constructor index 2, no fields) | Additive (existing TransferAct/ThirdPartyAct builders unaffected) |
| Protocol-params datum (`ProgrammableLogicGlobalParams`, built off-chain at deploy) | **Appended field 2 `unfracking_cred: Credential`** → now `{ registry_node_cs, prog_logic_cred, unfracking_cred }` (3 fields) | **YES** — params-datum builder (deploy) and any parser |
| Tx shape | New unfracking tx pattern: PLB inputs same stake cred; withdrawals = PLG (`UnfrackingAct`) + `unfracking` script + holder authorisation; no mint; per-policy PLB conservation | Additive feature |

(Superseded since: `UnfrackingAct` no longer exists — PLB dispatches to the
`unfracking` validator directly via `SpendViaUnfracking`; the params datum
grew to 6 fields — see the consolidated table.)

### PR #79 — Finding 12 (`fix/finding-12-utxo-contamination`) — no schema change

- `validate_3rd_party` semantics tightened to prevent UTxO
  contamination; constrains 3P output construction further. 3P builders
  must be re-validated against the merged rules. Hash cascade.

### PR #80 — Finding 04 (`feat/finding-04-issuance-mint-precise-delegation`) — no schema change

- `issuance_mint` delegation scope made precise per redeemer; changes
  which transaction shapes validate for mints (notably mint-during-3P
  combinations). Mint builders must be re-validated. Hash cascade
  (including new `IssuanceCborHex` prefix/postfix bytes).

### PR #81 — Finding 20 / issue #75 (`feat/75-registry-design-limitation`) — no schema change

- `registry_spend` gains a **no-mint update path**: a registry node's
  fields can be updated in place (key/next immutable, address + NFT
  preserved, enforced via `is_field_updated_registry_node`), authorised
  by the node's `minting_logic_script` (withdraw-0 invocation, or
  signature if vkey). New additive tx pattern: "update registry node".
  Redeemer remains untyped.

---

## PROVISIONAL — subject to change: `feat/dispatch-registry-merge-and-params-reduction`

Giovanni's design, 2026-08-31: PLB stops choosing a delegate and dispatches to a single
upgradable `programmable_logic_global`, which carries the three delegate hashes as compile-time
parameters. The delegates stop reading the params datum entirely. Measured against `9db7e06`:
transfer tx **-27 B / -7.80M cpu**, seize **+41 B / -6.59M cpu**, unfracking **+40 B / -4.84M cpu**,
PLB **-220 B and -0.95M cpu PER INPUT**.

| Surface | Change | Breaking? |
|---|---|---|
| **NEW validator** `programmable_logic_global` | `programmable_logic_global(transfer_hash, third_party_hash, unfracking_hash: ScriptHash)`, withdraw-0 + publish. Must be deployed and its credential written to the params datum | **YES** — new script to deploy, new withdrawal on every programmable tx |
| `programmable_logic_base` redeemer | `BaseSpendRedeemer` was an enum of three constructors (`SpendViaTransfer` / `SpendViaThirdParty` / `SpendViaUnfracking`), each `{ params_idx, wdrl_idx }`. It is now a **RECORD** `{ params_idx, wdrl_idx }` | **YES — AND SILENTLY SO.** Old and new both encode as "constructor 0 with two ints", so a stale builder emitting `SpendViaTransfer` still DECODES. It fails as a withdrawal-index mismatch, not a decode error. `SpendViaThirdParty`/`SpendViaUnfracking` (tags 1/2) fail to decode outright |
| Protocol-params datum (built off-chain) | 7 fields → **6**: `{ registry_node_cs, prog_logic_cred, plg_cred, transfer_cred, third_party_cred, upgrade_cred }`. `plg_cred` **INSERTED at index 2**; `unfracking_cred` and `max_inline_datum_bytes` **REMOVED** (nothing reads them any more). ⚠️ **SUPERSEDED LATER ON THIS SAME BRANCH** — see "Params datum reduced to four fields" below. Do not migrate to this 6-field shape; the branch's net delta is **7 → 4** | **YES** — positional datum builder/parser; every field from index 2 on has moved |
| `transfer` / `third_party` / `unfracking` params | Were `(params_policy: PolicyId)`. Now **`(prog_logic_cred: Credential, registry_node_cs: PolicyId, max_inline_datum_bytes: Int)`** | **YES** — parameter application arity, order AND types |
| `TransferRedeemer` | `{ params_idx, proofs }` → **`{ proofs }`** | **YES** — redeemer builder |
| `ThirdPartyRedeemer` / `UnfrackingRedeemer` | `{ params_idx, registry_node_idx, outputs_start_idx }` → **`{ registry_node_idx, outputs_start_idx }`** | **YES** — redeemer builder |
| **RENAME** `coordination_spend` → `protocol_params_spend` | Blueprint titles change (`coordination_spend.coordination_spend.spend` → `protocol_params_spend.protocol_params_spend.spend`). Script HASH is unaffected by the name itself | **YES for blueprint lookups** — any `findValidator("coordination_spend…")` breaks |
| Tx shape | Every programmable-token transaction now carries **one more withdraw-0**: the dispatcher's. **Every `wdrl_idx` shifts**, and the dispatcher's own redeemer (`TransferAct` / `ThirdPartyAct` / `UnfrackingAct`, all field-less) must be attached | **YES** — withdrawal-index computation and redeemer set |
| Deployment ordering | New dependency edge: compile the delegates → take their hashes → compile `programmable_logic_global` → write its credential into the params datum. Replacing ONE delegate now requires deploying a new dispatcher too | **YES** — deployment/upgrade runbook |

**Upgrade-coherence hazard (not enforceable on-chain).** A script cannot read another script's
parameters, so nothing verifies that the hashes baked into the dispatcher agree with the
`transfer_cred` / `third_party_cred` the params datum still carries for `issuance_mint`. They
must be updated together. This belongs in the runbook and as an `ASSUME-*` entry in doc 04.

### Registry merge: `registry_mint` + `registry_spend` → `registry`

The two registry scripts become ONE multi-purpose validator,
`validator registry(utxo_ref: OutputReference, issuance_cbor_hex_cs: PolicyId)` with a
`mint` and a `spend` handler. All handlers of one `validator` block share one script hash.

| Surface | Change | Breaking? |
|---|---|---|
| **Validator set** | `registry_mint` + `registry_spend` → **`registry`**. Blueprint titles `registry_mint.registry_mint.mint` and `registry_spend.registry_spend.spend` → **`registry.registry.mint`** and **`registry.registry.spend`** (plus one shared `registry.registry.else`) | **YES for blueprint lookups** — any `findValidator("registry_mint…" / "registry_spend…")` breaks |
| `registry` parameters | `registry_mint` was 3 — `(utxo_ref, issuance_cbor_hex_cs, registry_spend_cred: Credential)`; `registry_spend` was 1 — `(protocol_params_cs: PolicyId)`. Now **2 total**: `(utxo_ref: OutputReference, issuance_cbor_hex_cs: PolicyId)`. `registry_spend_cred` and `protocol_params_cs` exist as parameters nowhere | **YES** — parameter application arity and order |
| **ONE HASH for policy and address** | The registry node NFT policy id and the registry node address's payment credential are now the SAME VALUE. Init locks the origin node at `Script(policy_id)` — the minting policy naming itself | **YES for address/policy derivation** — an SDK that derives the node ADDRESS from `registry_spend`'s applied hash and the node POLICY from `registry_mint`'s applied hash must **collapse to a single derivation** off the one applied `registry` script. Two derivations that used to be independently correct are now one |
| Registry ↔ protocol-params coupling | The spend handler no longer scans `reference_inputs` for the protocol-params UTxO and no longer reads `registry_node_cs` out of its datum — it reads the policy off its own input's payment credential | **YES for tx building** — a registry-node spend must **stop attaching the protocol-params reference input** on the registry's account (it may still be needed by other scripts in the same tx). `ProgrammableLogicGlobalParams.registry_node_cs` loses its last on-chain reader here, and is **removed from the datum outright** by the next change on this branch |
| Deployment ordering | The registry no longer depends on the protocol-params chain at all. It can be compiled **immediately after `issuance_cbor_hex_mint`**, before the params policy exists — removing the edge params-policy → `registry_spend` | **YES** — deployment/upgrade runbook ordering |

**Reference-script footprint** (bytes of `compiledCode`, unapplied / parameters applied):

| Path | Scripts loaded | Before | After | Delta |
|---|---|---|---|---|
| Init | mint only | 1928 / 2043 | 2674 / 2751 | +746 / +708 |
| Insert | mint + spend | 3481 / 3631 | 2674 / 2751 | **-807 / -880** |
| Update | spend only | 1553 / 1588 | 2674 / 2751 | +1121 / +1163 |

Init and Update regress — each now carries the handler it does not use. That is the accepted
price of the merge; Insert, the only path that ever loaded both scripts, improves by ~24% of
its reference-script fee. Sizes are measured against this branch's pre-slice working tree, not
`main@9db7e06` (where `registry_spend` is 1563 B, which would make the Insert row -817 B).

**Update 2026-09-03 (review-round optimisation, no surface change).** Three internal rewrites in
`registry.ak` — `list.expect_any` for the one-shot `utxo_ref` check, `has_currency_symbol` for the
issuance-CBOR reference-input predicate, and `pairs.has_key_or_fail` for the substandard withdraw-0
proof — take the merged script to **2628 B unapplied (-46)**, with the Insert happy path
-2,489,299 cpu and Init -905,141 cpu. Parameters, redeemers, datums and tx shape are untouched, so
every row in the tables above still holds; only the byte figures move (the applied column shifts by
the same -46 B, derived rather than re-measured — flat encoding may differ by a byte of padding).

Execution units: Init +0.49%, Insert unchanged to the unit (the `RegistryInsert` arm is carried
over byte-for-byte), node spend -41.4% and node update -21.2% as measured — **but those two
figures overstate the on-chain saving and must not be quoted bare.** `aiken check` reports
execution units for the whole test expression, fixture construction included, and the pre-merge
spend fixtures had to build a protocol-params reference input carrying an inline
`ProgrammableLogicGlobalParams` datum — a fixture that no longer exists because the validator no
longer demands one. Constructing it costs a measured **5,667,325 cpu**, i.e. 29% of the recorded
spend saving and 24% of the recorded update saving. **Like for like the rows are -33.5% and
-17.0%**; that is the number to carry into any fee estimate. The remainder — the reference-input
scan, the inline-datum extraction and the whole-record deserialisation — is a genuine saving.

**Test surface.** **Five** `registry_spend` tests are *designed out* rather than deleted for
convenience — the code paths they covered no longer exist — **plus one never-written case**.
They are enumerated, each with its reason, in the `Designed out by the registry merge` comment
block at the top of `validators/registry.test.ak`: four asserted failures of the protocol-params
reference-input scan, one positive that disambiguated multiple reference inputs, and the
never-written case ("the params datum names the wrong registry policy") that the merge makes
unstateable. What replaces them is a discriminating PAIR —
`registry_spend_derives_node_policy_from_its_own_address` and
`registry_spend_fails_node_mint_under_a_policy_that_is_not_its_address`, built on a second
script hash used nowhere else — because a lone positive would be satisfied by any hardcoded
constant and would assert nothing about the derivation.

### Params datum reduced to four fields

`ProgrammableLogicGlobalParams` now carries **four** fields, ordered by read frequency:

```
0  plg_cred          Credential   <- programmable_logic_base, once per programmable INPUT
1  transfer_cred     Credential   <- issuance_mint (Finding 04 precise delegation)
2  third_party_cred  Credential   <- issuance_mint (Finding 04 precise delegation)
3  upgrade_cred      Credential   <- protocol_params_spend (upgrade authorisation)
```

`registry_node_cs` and `prog_logic_cred` are **gone**. Both were frozen values that no
validator read any more — the registry merge took the last reader of `registry_node_cs`, and
`prog_logic_cred` had already become a compile-time parameter of the delegates. The rule the
type is kept to is that every field has a NAMED on-chain reader; these two no longer had one.
Removing a field is stronger than freezing it, which is why the two `protocol_params_spend`
freeze rails that guarded them were deleted rather than kept — but be precise about the scope
of that claim, because this is where the upgrade threat model gets read. It is true of the
FIELD: neither can be edited in place any more, and no future edit to `protocol_params_spend`
can get the comparison wrong. It is NOT true of the VALUE. `plg_cred` is upgradable by design,
and an upgrade that rewrites it installs a dispatch layer naming delegate hashes of the
authority's choosing, each applied with its own `prog_logic_cred` and `registry_node_cs`. The
effective values therefore remain reachable, one hop further away — by the same authority, in
the same transaction the old rails would have gated. That path is unchanged by this slice; it
predates it.

`plg_cred` at index 0 is load-bearing, not cosmetic: it is the only per-programmable-input
datum read in the protocol, and at index 0 its accessor is a bare `head_list` with no
`tail_list` walk. Measured saving, PLB's whole per-input datum-read cost
(`cost_six_field_params_split_programmable_logic_global_only`): **483,167 → 482,703 mem (-464) and 152,393,931 → 152,166,605 cpu
(-227,326, -0.149%)**, multiplied by every programmable input a transaction spends.

| Surface | Change | Breaking? |
|---|---|---|
| Protocol-params datum (built off-chain) | 6 fields → **4**: `{ plg_cred(0), transfer_cred(1), third_party_cred(2), upgrade_cred(3) }`. `registry_node_cs` and `prog_logic_cred` REMOVED; everything else shifted down two slots | **YES — AND MOSTLY SILENTLY SO.** See the misread table below |
| `protocol_params_spend` rails | The two frozen-anchor comparisons (`prog_logic_cred`, `registry_node_cs` unchanged) are DELETED. The four `is_28_byte_credential` rails, the value-conservation ratchet, the singleton in/out structure, the no-reference-script rail and the `upgrade_cred` trampoline are all unchanged | **NO** for tx building — the forbidden states are now unrepresentable rather than rejected |
| `protocol_params_mint` | Still fully deserialises the datum at mint time, now against the 4-field shape. That whole-record `expect` is what licenses PLB and `issuance_mint` to skip validation on their read paths | **YES** — a stale builder's 6-field datum is REJECTED at mint (verified: rejected twice over, on field 0's type and on the field count independently) |

#### ⚠️ SILENT-MISREAD HAZARD — the sharpest off-chain break in this epic

Same family as the `BaseSpendRedeemer` warning above, and worse. A positional parser written
for the 6-field shape does not fail on the 4-field datum; it reads the wrong field and carries
on.

| Old index | Old field | Now reads | Loud or silent? |
|---|---|---|---|
| 0 | `registry_node_cs` (ByteArray) | `plg_cred` (Credential) | **LOUD** — type mismatch |
| 1 | `prog_logic_cred` | `transfer_cred` | **SILENT** — right shape, wrong value |
| 2 | `plg_cred` | `third_party_cred` | **SILENT — WORST.** A builder computing PLB's dispatch target silently gets `third_party_cred` |
| 3 | `transfer_cred` | `upgrade_cred` | **SILENT** |
| 4, 5 | `third_party_cred`, `upgrade_cred` | absent | **LOUD** |

Row 2 is the one to brief consumers on: it is the credential whose withdraw-0 every
programmable spend must carry, so getting it silently wrong produces transactions that build
cleanly and fail in phase 2.

On-chain this is safe — every reader in this repo moved in the same change set, and the golden
raw-`Data` pins in `validators/programmable_logic/layout.test.ak` lock the new order in both
directions. The hazard is **entirely off-chain**: `cip113-sdk-ts` (`src/core/evo-utils.ts`) and
the Java backend's deploy-time params-datum builder must both be regenerated, not patched by
index arithmetic.

#### Test surface

**Four** tests are *designed out* rather than deleted for convenience, and **one** is added.
They are enumerated with their reasons in the `Designed out by the four-field params datum`
comment block at the top of `validators/protocol_params_spend.test.ak`. Two of the four are the
interesting pair — `params_spend_fails_changing_prog_logic_cred` and
`params_spend_fails_changing_registry_node_cs` — and they are **not lost coverage but
eliminated state space**: a freeze rail replaced by non-existence is stronger over that FIELD.
It does not make the VALUE unreachable — an upgrade that rewrites `plg_cred` installs a dispatch
layer whose delegates carry a `prog_logic_cred` and `registry_node_cs` of the authority's
choosing. That is the same authority in the same transaction, and it was equally true before this
change. The other two
(`protocol_params_structure`, `protocol_params_from_reference_inputs`, both in
`validators/transfer.test.ak`) asserted only on the two removed fields and had no assertion
left to make. Added: `layout_params_retired_six_field_shape_does_not_decode`, pinning that the
retired shape is rejected by the whole-record `expect` that `protocol_params_mint` runs.

Two existing tests changed FAILURE MODE, which is itself a surface fact worth recording:
`plb_fails_on_legacy_three_field_params_datum` and (formerly seven-, now)
`plb_fails_on_legacy_six_field_params_datum` used to assert a `False` return and now assert an
ABORT. While `plg_cred` sat at field 2, a legacy datum merely named the wrong script there and
PLB denied quietly; with `plg_cred` at field 0 a legacy datum puts a `ByteArray` where a
`Credential` is expected and PLB **crashes**. For an operator pointing PLB at a stale
protocol-params UTxO, the shape mismatch is now loud.

### Review-round optimisation sweep (2026-09-03) — hashes move, surface does not

A repo-wide pass replacing general helpers with their specialised/fail-fast equivalents
(`list.expect_at` / `expect_find` / `expect_any`, `dict.expect_get`, `pairs.has_key`,
`utils.has_currency_symbol`). Purely internal: no parameter, redeemer, datum or transaction-shape
change, so every row above still holds. **Eight script hashes move, which is a full redeploy** —
recorded here because the hash cascade is itself the surface event.

| Script | Before | After | Delta |
|---|---|---|---|
| `protocol_params_mint` | 1015 | 896 | -119 B |
| `issuance_cbor_hex_mint` | 909 | 791 | -118 B |
| `issuance_mint` | 2021 | 1943 | -78 B |
| `registry` | 2628 | 2573 | -55 B |
| `protocol_params_spend` | 1087 | 1041 | -46 B |
| `programmable_logic_base` | 605 | 564 | -41 B |
| `third_party` | 1803 | 1773 | -30 B |
| `unfracking` | 1732 | 1702 | -30 B |

cpu: `programmable_logic_base` **-2,116,305 per programmable input** (the params-NFT
authentication in `params.ak`), transfer -2.12M, seize -3.54M, unfracking -3.43M, registry spend
-1.56M per transaction.

One equivalence caveat worth carrying into any future use of the helper:
`utils.has_currency_symbol` SKIPS THE FIRST PAIR of the value, assuming it is ada. That holds for
any UTxO value (min-UTxO guarantees an ada entry, and `""` sorts first) but NOT for a mint value,
which has no ada entry — `utils.mint_has_policy` therefore stays on `dict.has_key` and must not be
"optimised" the same way.

## MERGED: `fix/params-pair-merge-and-init-rails` (PR #118, squash `5fd6e9b`, 2026-09-07)

Audit-call item M10 plus audit-3 findings 01 and 04, and M4 from the same call. The protocol-params
pair becomes ONE multi-purpose validator, exactly as the registry pair did in #117.

| Surface | Change | Breaking? |
|---|---|---|
| **Validator set** | `protocol_params_mint` + `protocol_params_spend` → **`protocol_params`**. Blueprint titles `protocol_params_mint.protocol_params_mint.mint` and `protocol_params_spend.protocol_params_spend.spend` → **`protocol_params.protocol_params.mint`** and **`protocol_params.protocol_params.spend`** (plus one shared `.else`) | **YES for blueprint lookups** — any `findValidator("protocol_params_mint…" / "protocol_params_spend…")` breaks |
| `protocol_params` parameters | `protocol_params_mint` was 2 — `(utxo_ref, params_spend_addr_hash)`; `protocol_params_spend` was 1 — `(_nonce)`. Now **1 total**: `(utxo_ref: OutputReference)`. Both `params_spend_addr_hash` and `_nonce` exist as parameters nowhere | **YES** — parameter application arity and order. Deployment tooling that generated or passed a nonce must drop it |
| **ONE HASH for policy and address** | The protocol-params NFT policy id and the protocol-params address's payment credential are now the SAME VALUE. The mint handler locks the NFT at `Script(own_policy)` — the minting policy naming itself | **YES for address/policy derivation** — an SDK deriving the params ADDRESS from `protocol_params_spend`'s applied hash and the params POLICY from `protocol_params_mint`'s must **collapse to one derivation**. `programmable_logic_base`'s `params_policy` parameter is now that same hash |
| Deployment ordering | The cycle is dissolved: the mint side no longer depends on the spend side's address, so there is no ordering edge between them and no nonce to choose. The protocol's identity was always the NFT asset class, not the address (audit-3 finding 04) | **YES** — deployment runbook |
| **Genesis tx shape** (new rejections) | The mint handler now enforces what every later update enforces: all four datum credentials must be 28 bytes; the NFT output may carry **no reference script**; and the datum must decode. Previously the protocol could be BORN in a state the spend handler refuses to move to — including an unsatisfiable `upgrade_cred` with no repair path. (Junk tokens alongside the NFT were ALREADY rejected before this change: `has_nft_strict` matches only a value whose non-ADA half is exactly the one NFT. A rail for it was written, mutation-tested, found to kill no test, and removed) | **YES for init builders** — an initialisation transaction that attached a reference script or wrote a wrong-length credential used to pass and now fails |
| **Upgrade tx shape** (relaxation) | Lovelace on the continuing output is no longer required to be ≥ the input's. Non-ADA assets are still compared exactly, so the NFT can neither leave nor be joined by junk | **NO** — strictly permissive. A previously impossible transaction (recovering surplus ADA) becomes possible; nothing that worked stops working |

**Reference-script footprint** (bytes of `compiledCode`, unapplied):

| Path | Script loaded | Before | After | Delta |
|---|---|---|---|---|
| Genesis (init) | mint only | 1015 | 1414 | **+399** |
| Upgrade | spend only | 1087 | 1414 | **+327** |

**Both paths regress, and that is expected here.** Unlike the registry merge — where `Insert` loaded
both scripts and improved by 807 B — **no protocol-params transaction ever loaded both**: genesis only
mints, an upgrade only spends. The merge buys one hash instead of two, two parameters removed, the
dissolved cycle, and a genesis that enforces the same rails as an update; it does not buy bytes. Both
paths are rare (genesis once per deployment, upgrades seldom), so ~350-400 B of reference-script fee on
each is the accepted price.

cpu: the upgrade path pays **+208,212 (+0.3%)** for carrying the mint handler; genesis pays
**+10,880,100 (+25.0%)** for the new rails — well under 1% of one transaction's budget, once per
deployment.

---

## PROVISIONAL — subject to change: `feat/125-two-phase-authority-handover`

GitHub issue **#125** (call item M9; corroborated by audit-3 finding 05's Alternative, *"consider
requiring evidence that the incoming authority is usable"*). Stacked on #118.

**What was rejected, and why it matters to record.** The issue as filed proposed a CO-SIGNATURE:
when `upgrade_cred` changes, require the incoming credential's withdraw-0 in the SAME transaction.
That was rejected by Giovanni on 2026-09-07. `required_observers`-style coordination does not exist
here, so demanding a co-signature silently restricts the set of parties that may become the upgrade
authority to those that can be scheduled into someone else's transaction — excluding a governance
action, and any multisig or cold quorum that assembles approval over days. The datum field exists
precisely to keep that choice open.

**What shipped instead: a two-phase handover.** Phase 1, the sitting authority NOMINATES a successor
in a new datum field. Phase 2, the nominee ACTIVATES itself by presenting its own withdraw-0. Between
the two, the sitting authority may revoke. Same evidence as a co-signature — the incoming authority
exists, runs, consents — with no coordination requirement.

| Surface | Change | Breaking? |
|---|---|---|
| **`protocol_params` spend redeemer** | Was ignored `Data` (`_redeemer`); now a required **`ProtocolParamsRedeemer`** enum, field-less: `ProtocolUpgrade` = **0**, `NominateAuthority` = **1**, `PromoteAuthority` = **2`**. Exposed in the blueprint as `types/ProtocolParamsRedeemer` | **YES for upgrade tooling** — a builder that passed `Void` or any placeholder now fails. Worse than a decode failure if the index is merely wrong: index 0 refuses to move the authority, index 1 refuses everything but the nomination, so a wrong index selects a DIFFERENT rule set. Pinned by `layout_protocol_params_redeemer_constructors_are_field_less` |
| **`ProgrammableLogicGlobalParams`** | 4 → **5 fields**: `pending_upgrade_cred: Option<Credential>` **APPENDED at index 4** (index **5** after the #129 pre-genesis reorder). `None` at rest, `Some(c)` while a handover is in flight | **YES for datum builders** |
| Wire shape of field 4 | `None` = constructor **1**, no fields. `Some(c)` = constructor **0**, one field (the credential). Pinned by `layout_params_pending_option_wire_shape` | **YES** — new encoding for off-chain builders to emit |
| **Old 4-field datums do not decode** | The spend handler deserialises the current datum as the 5-field type. A params UTxO written before this change cannot be spent by this validator | **YES, but moot** — the validator's bytes changed, so its hash and address moved anyway. Redeploy-class, like every other validator change (see the systemic note) |
| **Authority change is no longer one transaction** | `upgrade_cred` can no longer be rewritten directly. Two transactions: nominate (sitting authority), then promote (nominee). Revocation is an ordinary upgrade clearing the field | **YES for upgrade tooling** — the previous one-step rewrite now FAILS. This is the behaviour change; see `params_spend_fails_direct_authority_rewrite` (was `params_spend_authority_handover_succeeds`, which passed) |
| **Promotion is pure** | The promoting transaction may change NOTHING except `upgrade_cred` taking the nominated value and the nomination clearing. Enforced as one record equality, so a future 6th field is covered automatically | **YES** — a nominee wanting a parameter change needs a second transaction, under the sitting-authority route, after promotion |
| **Nomination is pure too** | `NominateAuthority` may change ONLY `pending_upgrade_cred`; `ProtocolUpgrade` may not change it at all. So each of the three arms does exactly one job | **YES** — nominating *and* rewriting a parameter in one transaction was possible in an earlier draft of this branch and is not possible now. Two transactions on the protocol's rarest path; in exchange a handover always begins as its own visible transaction |
| Genesis | The genesis datum must carry `pending_upgrade_cred: None` — the protocol is born at rest, never mid-handover | **YES for init builders** |
| Nominee well-formedness | A nomination is held to the same 28-byte rail as a sitting credential, at nomination time | **NO** — strictly a new rejection of a shape that was already useless |

**On adding redeemer constructors, given #124.** Audit-3 finding 02 / issue #124 is about the **PLB**
redeemer carrying action variants, and that constraint is untouched here: PLB's hash is baked into
every token address, so changing its action set would be a token-address migration, which is exactly
why it must stay action-agnostic. `protocol_params` is the upgrade path itself — replacing it is a
redeploy by definition — so no equivalent coupling exists to protect. The three arms are what make
each rule set closed and mutually exclusive, and they are field-less for the same reason
`ProgrammableLogicGlobalRedeemer`'s are: every value an arm needs is already in the continuing datum,
and repeating one here would be a second unchecked claim about the same fact (cf. issue #123, which
removed redundant fields).

**Footprint.** `protocol_params` 1414 → **1921 B (+507)**; of that, +294 is the two-phase handover
and +213 the three-arm redeemer. **No other validator changed by a single
byte** — verified against `origin/main`'s `plutus.json`. That is the append-at-index-4 rule paying
off: `programmable_logic_base` and `issuance_mint` read the datum through positional
`head_list`/`tail_list` accessors, so a field added at the END costs them nothing. Both affected
paths are cold (once per deployment; once per authority change).

**Docs.** The narrative docs still describe a SIX-field datum and a `protocol_params_spend` validator
— they are already behind #117 and #118, not just this change. Folded into the doc-sweep ticket
(issue **#131** / T-092) rather than half-fixed here.

---

## PROVISIONAL — subject to change: `feat/upgrade-multisig-sundae-tree`

GitHub issues **#126** and **#127** (MINR-054, MINR-057, audit-3 finding 05 *Preferred*, call items M7 /
J2). Stacked on `feat/125-two-phase-authority-handover` (#132).

**What changed.** The reference upgrade authority is no longer a flat M-of-N over compile-time
parameters. It is a native-script-shaped tree (`MultisigScript`, copied from SundaeSwap's `aicone`
with attribution, Apache-2.0) held in a config UTxO that the authority itself owns and can rotate.

| Surface | Change | Breaking? |
|---|---|---|
| **`upgrade_multisig` parameters** | `(signers: List<VerificationKeyHash>, threshold: Int)` → **`(utxo_ref: OutputReference)`** | **YES** — parameter application arity and types |
| **`upgrade_multisig` handlers** | `withdraw` only → **`mint` + `spend` + `withdraw` + `publish`** (plus `else`). Blueprint titles `upgrade_multisig.upgrade_multisig.{mint,spend,withdraw,publish,else}` | **YES for blueprint lookups**; `withdraw` title unchanged |
| **New one-shot NFT** | policy = the validator's hash, name **`UpgradeMultisig`**, locked at `address.from_script(hash)` (NO stake credential) with the tree as inline datum | **YES for deployment** — one more genesis transaction (mint config) before the params genesis can name `upgrade_cred` |
| **New datum type `MultisigScript`** | 7 constructors, declaration order: `Signature` 0 `{key_hash}`, `AllOf` 1, `AnyOf` 2, `AtLeast` 3 `{required, scripts}`, `Before` 4, `After` 5, `Script` 6. Pinned by `layout_multisig_script_constructor_indices` | **YES** — new type for SDK to emit; a wrong index selects a DIFFERENT authority shape, not a decode error |
| **Well-formedness at write time** | Enforced on `mint` and `spend`: 28-byte hashes; every list node non-empty and duplicate-free; `1 ≤ required ≤ length`; whole tree ≤ **`max_size = 20`** nodes | **YES** — a config a builder could previously bake into parameters unchecked is now refused on-chain |
| **Rotation is a config spend** | Authorised by satisfying the OLD tree; NFT continues at the address; new tree well-formed; lovelace unconstrained. `upgrade_cred` in the params datum does NOT move for a rotation | **NO for params** — strictly removes a handover from the rotation path |
| **Withdraw reads the config by reference input** | The trampoline target finds the config NFT among `reference_inputs` by its own hash | **YES for upgrade tx shape** — every protocol upgrade must now `readFrom` the config UTxO |
| **Registration** | New `publish` handler accepts `RegisterCredential` only | **YES for deployment** — registration was previously only possible via the legacy no-witness cert, which the era after Conway withdraws (MINR-057) |
| Redeemers | All three `Data`, ignored | none |

**Limit, deliberate:** the config UTxO cannot be spent and referenced in the same transaction, so a
rotation and a protocol upgrade are two transactions.

**Two review-round changes on the same branch, both also applied to `protocol_params.spend`:**

| Surface | Change | Breaking? |
|---|---|---|
| Value rail helper | `assets.expect_match(a, b, fn(_, _) { True })` → **`assets.expect_match_assets(a, b)`** — identical semantics (non-ADA exact, lovelace ignored), −2.27 M cpu / −6.5 K mem per spend, **+55–57 B** of script | **NO** |
| **"Exactly one input at this address" rail REMOVED** from both spend handlers | Redundant: the continuing output is singular, its non-ADA value must equal the spent input's exactly, and only one UTxO can carry the one-shot NFT — so a second input at the address fails its own run on the value rail. Proven by `params_spend_fails_junk_run_alongside_genuine` / `update_fails_junk_run_alongside_genuine`, which die when the value rail is neutered and survive the rail's removal. −49 B / −37 B | **NO for the genuine UTxO** — nothing new becomes possible for it. The only newly valid transactions spend two of a parker's own NFT-less junk UTxOs at the address together, which achieves nothing |

`protocol_params` net on this branch: 1,921 → **1,929 B**.

**Footprint.** `upgrade_multisig` 208 → **2,773 B**. Reference-script fee once per upgrade (withdraw)
and once per rotation (spend). Evaluation is bounded by the cap; measured worst case (flat `AtLeast`
over cap−1 leaves, every member signing; mainnet 14 M mem / 10 B cpu):

| cap | withdraw (per upgrade) | update (per rotation) |
|---|---|---|
| 16 | 0.90 M / 262 M | 1.91 M / 682 M (14% mem) |
| **20** | **1.23 M / 358 M** | **2.65 M / 970 M (19% mem)** |
| 24 | 1.61 M / 468 M | 3.51 M / 1.31 B (25%) |
| 32 | 2.52 M / 733 M | 5.61 M / 2.16 B (40%) |

The cap is in the validator's bytes: changing it is a new authority (handover), not a config update.
Decide before deployment.

**Tests.** 573 total (36 property). `lib/multisig.ak`: Sundae's `satisfying` verbatim + 16 unit + 8
property (no-evidence-never-satisfies, all-keys-satisfy, monotonicity, `AtLeast` = counting,
duplicate rejected, threshold bounds, oversize rejected, generator well-formed). Validator: 42 unit.
Every rail mutation-verified against the full suite: 7 library rails, 16 validator rails, all kill.

---

## PROVISIONAL — subject to change: `feat/129-issuance-logic-split`

GitHub issue **#129** (audit-3 finding 07). Stacked on `feat/upgrade-multisig-sundae-tree` (#133).

**What changed.** Issuance is split into a PERMANENT per-token policy and a REPLACEABLE protocol
script. A token's policy id is the hash of its applied `issuance_mint`, so that script now does only
what will never change; every rule that may change with the protocol lives in a withdraw-0 named by
a new params field.

| Surface | Change | Breaking? |
|---|---|---|
| **`issuance_mint` parameters** | `(programmable_logic_base, registry_node_cs, minting_logic_cred, params_policy)` → **`(minting_logic_cred, params_policy)`** | **YES** — application arity; and the `IssuanceCborHex` prefix/postfix template changes, since the bytes around the `minting_logic_cred` hole are different. Registry validation of policy ids is unchanged (`prefix ++ hash ++ postfix`) |
| **`issuance_mint` redeemer** | `MintingRegistryProof` (`RefInput`/`OutputIndex`) → **`IssuanceRedeemer { params_idx }`** — an index hint locating the params UTxO among reference inputs, nothing else | **YES** — builders emit a different redeemer for the mint purpose |
| **New validator `issuance_logic`** | params `(programmable_logic_base, registry_node_cs, params_policy, max_inline_datum_bytes)`; handlers `withdraw` + `publish` (+ `else`). Redeemer **`IssuanceLogicRedeemer = Pairs<PolicyId, MintingRegistryProof>`** — one proof per policy issued in the tx | **YES** — a new script to deploy, register (`publish`) and reference; every mint/burn tx gains its withdraw-0 |
| **`ProgrammableLogicGlobalParams`** | 5 → **6 fields**, REORDERED pre-genesis by read frequency (Giovanni, 2026-09-08): `plg_cred` 0, **`issuance_logic_cred` 1**, `transfer_cred` 2, `third_party_cred` 3, `upgrade_cred` 4, `pending_upgrade_cred` 5. Accessors: issuance-logic one `tail_list`, transfer two, third-party three. 28-byte rail on genesis and update | **YES for datum builders** — every index but 0 moved. Safe ONLY because no datum exists yet; this is the last free reorder. After genesis: append only |
| **The frozen interface** | The permanent policy decodes `issuance_logic`'s redeemer as `Pairs<PolicyId, Data>` and requires its own policy id among the KEYS. Values are opaque to it. **The map-keyed-by-policy shape is the one thing about issuance that can never change again** | contract, stated once |
| **Every issuance tx** | needs TWO withdraw-0s: the token's `minting_logic_cred` and the protocol's `issuance_logic_cred`; plus a `readFrom` of the params UTxO (with `params_idx`) even on the OutputIndex path, which previously needed no params reference | **YES for tx builders** |
| **Upgrade property gained** | Rewriting `issuance_logic_cred` in the params datum changes the issuance rules for EVERY token, minted or not; no policy id moves. A retired issuance-logic script is refused even if it still runs (`fails_stale_issuance_logic`) | the point of the change |
| Trust | none added: the upgrade authority could already drain every token via a permissive `plg_cred`; a permissive `issuance_logic_cred` is the same authority, same act | — |
| **Inline-datum bound on minted outputs** (#106 vector 3, the issuance residual) | `issuance_logic` takes `max_inline_datum_bytes` like `transfer`, `third_party` and `unfracking`, and applies `is_seizable_output_shape_bounded` to every PLB output that CARRIES the minted policy; PLB outputs without it keep the shape check only; non-PLB outputs unchanged. "Every PLB UTxO is within the bound" is a core guarantee now, not only "every holder-created one" | **YES for issuers** — a mint whose PLB output carries a datum over the bound is refused. CIP-68 reference tokens with data-URI logos become unmintable on the core path; URI logos (~150–300 B) fit under a 1,024 bound. +2.45 M cpu per bounded output, once per mint |
| **⚑ Deployment invariant, not checkable on-chain** | Four scripts now carry `N`, each bounding only the outputs IT creates; nothing compares them. A UTxO born under a laxer `N` than `transfer` or `third_party` must later carry it under is frozen AND unseizable — vector 3 reintroduced by a mismatch between two correct scripts. Rule: **one `N` for all four**, applied by the deployment tooling and read back from the four applied blueprints to assert equality. Correct by composition | **YES for the deploy runbook / SDK** |

**Footprint.** `issuance_mint` 1,943 → **679 B** (the permanent bytes); `issuance_logic` **2,128 B** new (2,018 before the datum bound);
`protocol_params` 1,929 → 1,993 (+64). PLB, the delegates and the registry byte-identical to HEAD.
Blueprint rebuilt LAST and built twice (`cmp` equal) — the blueprint is the source.
Per RefInput mint: single policy 223,752 mem / 75,918,400 cpu → logic + permanent 332,925 / 109,669,254 (+109,173 / +33,750,854).
The extra is the params lookup and the redeemer walk the permanent policy now does; the logic half
costs what the old policy did.

**Tests.** 605/605 both environments. The 52-test `issuance_mint.test.ak` moved to
`issuance_logic.test.ak` (the rules moved, so the tests did — one call-site change, minus the
minting-logic test); `issuance_mint.test.ak` is new, 15 tests on the permanent policy. Composed
registry×issuance tests and the issuance benchmarks now drive `issuance_logic`. Mutation, full suite:
minting-logic required 1 · logic invoked 4 · live credential only 3 · own policy a key 2 · reads
field 1 5 · per-policy rules gate 15 · registration only 1 · 28-byte rail 1 · **`list.all → list.any`
3 · first-entry-only 2 · `registry.key == own_policy` 1 · issuance-logic accessor depth 7 ·
transfer accessor depth 10 · datum bound 1** (the last six added after the audit round below).

**Decision this closes, and its deadline.** Adoptable only before mainnet issuance: every token
minted before this lands keeps the old single-policy bytes forever.

**Independent audit round (fabbrica commit-auditor, 2026-09-08 — Codex refused the job twice on the
repository's own vocabulary).** Verdict REJECT on two findings, both fixed on the branch:
- **F1** the committed blueprint did not match the source for `protocol_params` (built before a
  later edit). Fixed: rebuilt last, built twice, `cmp` equal.
- **F2** the per-policy loop — the one genuinely new on-chain behaviour — was undefended: `list.all →
  list.any` and "validate the first entry only" survived the whole suite, because every test passed
  a one-entry map. Fixed: six two-policy tests (both clean; second escapes; first escapes; a proof
  borrowing the other policy's node; delegation covers only its own node; positive twin).
- F3 no test composed both halves on one transaction — fixed, two composed tests. F4 stale
  pre-split redeemer shapes in the moved fixtures — fixed; two tests renamed `logic_*`. F5 test
  count — fixed. F6 (pre-existing, survives at HEAD too) `registry.key == own_policy` was
  decorative because its test also changed the NFT name — fixed with a one-delta test.

**Two nuances the auditor established, stated for the record:**
- *Trust (I3), more precisely than the paragraph above:* a permissive `issuance_logic_cred` hands
  ISSUERS the ability to mint their own registered policy outside custody (the token's
  `minting_logic_cred` withdraw-0 is still required); a permissive `plg_cred` hands ANYONE every
  PLB input, minted or not. The second dominates, and the pre-#129 policy already trusted the
  datum's delegate credentials for mint custody on the RefInput path. No new trust.
- *What is now frozen (I4):* the permanent policy pins the params NFT policy, an inline datum with
  a `Credential` at field 1, and a `Withdraw`-purpose redeemer decoding as `Pairs<PolicyId, Data>`.
  Field 1's position and the withdraw-0 shape of every future `issuance_logic` are as immovable as
  PLB's field 0 — which is why the field was moved to 1 now, before genesis freezes it.

---

## PROVISIONAL — subject to change: `rc/documentation-pass` — release-candidate naming pass (T-121)

Names only. Every validator's `compiledCode` and `hash` identical to `9545680`; no redeploy implied.
Positional CBOR of every datum/redeemer unchanged; what breaks is anything generated from blueprint
titles or keyed by field/parameter NAME.

| Surface | Change | Breaking? |
|---|---|---|
| Params datum type | `definitions` key `programmable_logic/params/ProgrammableLogicGlobalParams` → `programmable_logic/params/ProtocolParams`; `$ref` in `protocol_params.protocol_params.spend` datum | YES for generated types / by-name lookups; CBOR unchanged |
| Params datum field 0 | title `plg_cred` → `programmable_logic_global_cred` (accessor `programmable_logic_global_cred_field`) | YES for named-field builders/parsers; index 0 unchanged |
| `issuance_mint` redeemer | `types/IssuanceRedeemer` → `types/IssuanceMintRedeemer` (`$ref` in `issuance_mint.issuance_mint.mint`) | YES for generated types; shape `{ params_idx }` unchanged |
| `issuance_logic` parameter 0 | title `programmable_logic_base` → `programmable_logic_base_cred` (withdraw/publish/else) | YES for by-name parameter application; position unchanged |
| `transfer`, `third_party`, `unfracking` parameter 0 | title `prog_logic_cred` → `programmable_logic_base_cred` (9 titles) | same |
| `RegistryNode` field 4 | title `third_party_transfer_logic_script` → `third_party_logic_script` | YES for named-field builders/parsers; index 4 unchanged |
| Blueprint `description` strings | change wherever a doc comment cross-referenced a renamed identifier (6 definitions in this slice) | no schema effect |

---

## Consolidated surface: baseline → `feat/upgradability-in-place` + PR #110

"now" = the head of PR #110 (`feat/plg-third-party-split`), i.e. `main`
plus the upgradability stack plus the validator split.

| Validator | Params (baseline → now) | Redeemer (baseline → now) | Changed by |
|---|---|---|---|
| `issuance_mint` | 3 → **4** (4th is now `params_policy: PolicyId`, the params-NFT policy — it started as `plg_stake_cred` in #51 and became the live-delegate trampoline on the upgradability branch) | `SmartTokenMintingAction{...}` → **`MintingRegistryProof`** | #51, #68 (+semantics #80, upgradability, PLG split) |
| `registry_mint` | 2 → **3** (+`registry_spend_cred`) | `RegistryInsert` fields **replaced** (`hashed_param` → `minting_logic_script`; `mode` added by #52, removed by R-06) | #51, #52, R-06 |
| `registry_spend` | 1 (unchanged) | untyped (unchanged) | #81 semantics only |
| `programmable_logic_global` → **`transfer`** | 1 (unchanged — went 1→2→1 during #78 development; final is 1, now the params-NFT policy); **validator + blueprint title renamed** | `TransferAct \| ThirdPartyAct` → **`TransferRedeemer { params_idx, proofs }`** (single constructor; `UnfrackingAct` added by #78 and `ThirdPartyAct` both gone — each path has its own validator) | #78, #109, validator split |
| `programmable_logic_base` | 1: `stake_cred: Credential` (PLG's credential) → **`params_policy: PolicyId`** | untyped → `Int` (#109) → **`BaseSpendRedeemer { SpendViaTransfer \| SpendViaThirdParty \| SpendViaUnfracking }`**, each `{ params_idx, wdrl_idx }` | upgradability #1+#2, #109, validator split |
| `protocol_params_mint` | 2 (unchanged; the lock-target param now receives `coordination_spend`'s hash) | untyped (unchanged) | datum it mints changed (#78, upgradability #1–#3, validator split) |
| `issuance_cbor_hex_mint` | 2 (unchanged) | untyped (unchanged) | its datum content (template bytes) changes with every `issuance_mint` change |
| `unfracking` | — → **new** (1 param `params_policy`) | **`UnfrackingRedeemer { params_idx, registry_node_idx, outputs_start_idx }`** | #78, unfracking v2, #109 |
| `third_party` | — → **new** (1 param `params_policy`) | **`ThirdPartyRedeemer { params_idx, registry_node_idx, outputs_start_idx }`** — seize / clawback / freeze-enforcement, dispatched by PLB's `SpendViaThirdParty` | validator split |
| `coordination_spend` | — → **new** (1 param `nonce: ByteArray`) | untyped | upgradability #3 |
| `upgrade_multisig` | — → **new** (2 params `signers`, `threshold`) | untyped | upgradability #3 |
| `always_fail` | unchanged (no longer the coordination-UTxO lock target) | — | — |

Off-chain-built datums:

| Datum | Baseline → now | Changed by |
|---|---|---|
| `RegistryNode` (registry NFT) | 5 → **7 fields** (`minting_logic_script` inserted at index 2; `unfracking_logic_script` added at index 5 by unfracking v2) | #52, unfracking v2 |
| `ProgrammableLogicGlobalParams` (params NFT) | 2 → **4 fields**, reordered + renamed + REDUCED: `{ plg_cred(0), transfer_cred(1), third_party_cred(2), upgrade_cred(3) }`. Went 2 → 3 → 5 → 7 → 6 → 4; the 6-field shape recorded in the PROVISIONAL section above is an intermediate state on the same branch and must not be migrated to. `registry_node_cs` and `prog_logic_cred` are gone entirely — every remaining field has a named on-chain reader. **Every old index 1-3 misreads SILENTLY** — see the misread table in "Params datum reduced to four fields" | #78, upgradability #1–#3, validator split, dispatcher + params reduction |
| `IssuanceCborHex` | shape unchanged; **content** (prefix/postfix bytes) changes with every issuance_mint change | #51, #68, #80 |

---

## SDK impact map (`cip113-sdk-ts`)

Observed touchpoints (grep, 2026-06-11) — each is a migration checklist
item once the open PRs land:

- `src/standard/blueprint.ts` — resolves validators **by title**; must
  replace `programmable_logic_global.programmable_logic_global` with
  **`transfer.transfer`** and add the `unfracking.unfracking`,
  `third_party.third_party`, `coordination_spend.coordination_spend` and
  `upgrade_multisig.upgrade_multisig` titles. Verify param-application
  arity for `issuance_mint` (4) and `registry_mint` (3) (#51), and the
  new PLB parameter (`params_policy`, not PLG's credential).
- `src/core/evo-utils.ts` — `RegistryNode` datum builder: **already on
  the 6-field post-#52 shape** (verified: `minting_logic_script` at
  index 2); needs `unfracking_logic_script` (index 5). Needs the
  **4-field** `ProgrammableLogicGlobalParams` parser / builder (order
  above) if it touches the params datum — a REWRITE, not an index
  patch: old indices 1, 2 and 3 all misread silently.
- PLB spend redeemer — every PLB input needs a `BaseSpendRedeemer`
  (`SpendViaTransfer` for transfers, `SpendViaThirdParty` for seizes,
  `SpendViaUnfracking` for unfracking) with `params_idx` (ledger-sorted reference-input position of
  the params UTxO) and `wdrl_idx` (delegate's position in the
  ledger-ordered withdrawal map — script creds before key creds,
  bytewise within each; derivation in doc 09 › Withdrawal indices).
- `src/core/registry.ts` — `RegistryInsert` redeemer: verify
  `minting_logic_script` support (#52) and that no `mode` field is
  encoded (R-06 removed it); verify mint redeemer is bare
  `MintingRegistryProof` (#68).
- `src/substandards/*` (`freeze-and-seize` especially) — seize
  builders: the `ThirdPartyAct` redeemer no longer exists; invoke
  the `third_party` validator's withdraw-0 (+ reference script) with a
  `ThirdPartyRedeemer { params_idx, registry_node_idx, outputs_start_idx }`
  at `third_party_cred`, and use `SpendViaThirdParty` on every PLB input.
  Must preserve `reference_script` on paired outputs (#69) and be
  re-validated against #79's contamination rules and #80's issuance scope.
- New (optional) feature: unfracking tx builder (#78) — `SpendViaUnfracking`
  on every PLB input (no PLG/transfer withdrawal at all), the `unfracking`
  script withdrawal + ref script with an `UnfrackingRedeemer`,
  composition documented in
  `documentation/design/finding-17-unfracking-w0-delegation.md`.

Other consumers to migrate in the same pass: the Java backend
(`programmable-tokens-offchain-java`) receives `plutus.json` via
`build.sh` and builds the params datum at deploy time (**4-field**
layout above), applies validator parameters (#51 arity changes; PLB now takes
the params-NFT policy), deploys the new `third_party`,
`coordination_spend` and `upgrade_multisig` artefacts, and locks the
coordination UTxO at `coordination_spend` instead of `always_fail`.

## Maintenance

When a new PR lands on `main` (or an open PR's surface changes), rerun
the comparison: extract titles/params/redeemers from `plutus.json` at
the new merge commit, diff against the previous merge, and append a
section here. The extraction script used for this document is kept at
`.claude/scripts/blueprint-surface.py` (usage:
`python3 .claude/scripts/blueprint-surface.py <commit-or-ref>`); it
normalises a blueprint into comparable per-validator signatures —
diff two outputs to see the surface delta.

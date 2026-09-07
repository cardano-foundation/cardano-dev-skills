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
(`cost_v6_split_plg_only`): **483,167 → 482,703 mem (-464) and 152,393,931 → 152,166,605 cpu
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

## PROVISIONAL — subject to change: `fix/params-pair-merge-and-init-rails`

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

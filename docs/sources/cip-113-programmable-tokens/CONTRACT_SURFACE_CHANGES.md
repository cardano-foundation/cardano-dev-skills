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
  merged. Last refreshed: **2026-08-21** (validator split, PR #110).

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
| `ProgrammableLogicGlobalParams` (params NFT) | 2 → **6 fields**, reordered + renamed: `{ registry_node_cs(0), prog_logic_cred(1), transfer_cred(2), third_party_cred(3), unfracking_cred(4), upgrade_cred(5) }` | #78, upgradability #1–#3, validator split |
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
  6-field `ProgrammableLogicGlobalParams` parser / builder (order above)
  if it touches the params datum.
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
`build.sh` and builds the params datum at deploy time (6-field layout
above), applies validator parameters (#51 arity changes; PLB now takes
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

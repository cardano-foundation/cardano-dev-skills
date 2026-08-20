# Audit report — `fixpoint` skill contribution (final external audit)

- Auditor: fixpoint/auditor-2 (EXTERNAL-AUDITOR, read-only)
- Audited tree: /code/cardano-dev-skills-fixpoint @ `c373e79` (branch
  `feat/fixpoint-skill`, 8 commits over `85e05ae`)
- Predecessor: auditor-1 @ `9b8763f`
- Date: 2026-08-19

## Verdict

**FINDINGS** — 0 BLOCKER, 3 SHOULD-FIX, 3 NIT.

The nine version-pinned action rules in Step 4 are, with one exception,
accurate: I re-derived them from upstream sources at the pinned commits rather
than from the probe handoffs, and every identifier, signature, and structural
claim I checked matched. The exception is the Evolution SDK rule (finding 1),
where a *public* build-option callback that receives the candidate transaction
was missed by the probe and is contradicted by the skill's wording. The other
two SHOULD-FIX items are a regression of an auditor-1 repair (finding 2) and a
precondition stated more narrowly than the ledger ADR the skill itself cites
(finding 3).

## Independent verification (dimension 1 + 2)

Everything below was checked against upstream sources at the pinned
commits/versions, not against the probe handoffs.

| Skill claim (SKILL.md) | Independently checked against | Result |
|---|---|---|
| Cardano Tx Tools `0.2.3.0+14` / `7bfe95b`: `balanceTx`, `balanceFeeLoop` (`Coin -> Either String (StrictSeq (TxOut ConwayEra))`), `Peek :: (ConwayTx -> Convergence a) -> TxInstr q e a`, `FeeNotConverged`; `build` not `draft` closes fee/ExUnits (L171-174) | `/code/cardano-tx-tools` @ `7bfe95b` (`git describe` = `v0.2.3.0-14-g7bfe95b`), Balance.hs:128,146,535; Build.hs:334,537,1314,1439 | ACCURATE |
| cardano-client-lib `0.8.0-pre5` / `4f1ea9c`: `UpdateOutputFunction(fee, outputs)` + composable `TxBuilder` transforms over the assembled transaction (L174-176) | fresh clone @ `4f1ea9c` (`gradle.properties` version = `0.8.0-pre5`): `TxBuilder.java` (`void apply(TxBuilderContext, Transaction)`, `andThen`), `FeeCalculators.java:63,176,201` (`updateOutputWithFeeFunc.accept(totalFee, tbody.getOutputs())`), `BalanceTxBuilders.java` (composes fee calc + change adjust + collateral) | ACCURATE — matrix cells CCL P2/P3 SUPPORTED **confirmed**. Note: the in-builder bounded loop is `ChangeOutputAdjustments.MAX_NO_RETRY_TO_ADJUST = 3` around change adjustment; the `UpdateOutputFunction` itself fires once per pass, which is exactly why the skill's "add an explicit bound" clause is needed and correct |
| Scalus `1.0.0` / `6844943`: `DiffHandler(Value, Transaction)` invoked inside a bounded balance loop; delayed redeemer/datum builders run *before* min-UTxO and balancing (L176-180) | fresh clone @ `68449438`: `TransactionBuilder.scala:30` (`type DiffHandler = (Value, Transaction) => Either[TxBalancingError, Transaction]`), `:1020-1059` (`balanceFeeAndChangeWithTokens`: `@tailrec`, `MaxBalancingIterations`, `BalanceDidNotConverge`, `diffHandler(diff, txWithFees)` each pass, fixpoint exit `tx == trialTx`), `:637-640` (`ensureMinAdaAll` then `.balance`), `TransactionStepsProcessor.scala:44-66` (delayed redeemers/datums replaced during `applySteps`, i.e. before `balanceContext`) | ACCURATE — matrix cells Scalus P2/P3 SUPPORTED **confirmed**; also confirmed the same API exists at released tag `v1.0.0` (see NIT 4 on the pin) |
| Evolution SDK `0.5.12`: fixed payment assets; redeemer callbacks get indexed inputs, not the candidate (L181-184) | `npm i @evolution-sdk/evolution@0.5.12`: `Operations.d.ts:38-46` (`PayToAddressParams{address, assets, …}`), `RedeemerBuilder.d.ts:28-53` (`IndexedInput{index, utxo}`, `SelfRedeemerFn`, `BatchRedeemerFn`) | ACCURATE |
| Evolution SDK: "exposes fee and transaction **only** on the completed result" (L182-183) | `TransactionBuilder.d.ts:150-157` (`BuildOptions.evaluator?: Evaluator`, `evaluate: (tx: Transaction, …) => …`), `phases/Evaluation.js:410-415` (`evaluator.evaluate(transaction, …)` inside the balance/evaluation loop) | **INACCURATE — finding 1** |
| CSL `17.0.0` / `6b42538`: `add_change_if_needed` must come after all other fields; `min_fee`/`build` + fresh reconstruction for deeper recursion (L184-186) | upstream file at that exact commit: `rust/Cargo.toml` version `17.0.0`; `rust/src/builders/tx_builder.rs:1822-1826` ("Warning: this function will mutate the /fee/ field … call this function last after setting all other tx-body properties"), `:1136` `set_fee`, `:2367` `build`, `:2596` `min_fee` | ACCURATE |
| cardano-api `10.19.1.0` / `b951a63`: fixed `TxBodyContent` in, `BalancedTxBody` out, no candidate callback (L186-189) | `/code/cardano-api` @ `b951a638` (= "Release cardano-api-10.19.1.0", cabal `version: 10.19.1.0`), `Fee.hs` `makeTransactionBodyAutoBalance` signature verbatim | ACCURATE |
| Mesh SDK `@meshsdk/core` `1.9.1`: fixed outputs/redeemers, CBOR after `complete` (L190-191) | `npm i @meshsdk/core@1.9.1`: `@meshsdk/transaction` d.ts (`txOut(address, amount)`, `complete(): Promise<string>`, `getActualFee()`), impl `index.js:4352-4360` | ACCURATE as written (see finding 1 for the matrix cell) |
| cardano-cli `11.0.0.0`: auto-balances fixed outputs; output/redeemer flags expose no callback (L192-195) | bundled `docs/sources/cardano-node-wiki/reference/cardano-node-cli-reference.md:38` ("builds an automatically balanced transaction"); flag surface from probe-1 (no local `cardano-cli` binary in this seat, so the `--help` dump was not re-executed) | ACCURATE (flag-surface half accepted from probe evidence) |
| Pallas txbuilder `1.1.1` / `cdee91d`: no balancing or fee/ExUnits calculation in `build_conway_raw` (L196-198) | upstream at that exact commit: `Cargo.toml` workspace version `1.1.1`; `pallas-txbuilder/src/conway.rs:27-35` ("no automatic fee/ex-units calculation", "\"Raw\" means no balancing") | ACCURATE |
| Conway fee = `a*size + b` + tiered ref-script charge, 25 KiB tiers, 1.2 escalation from `minFeeRefScriptCostPerByte` (L59-63) | bundled `docs/sources/cardano-ledger/adr/2024-08-14_009-refscripts-fee-change.md:43-63` | ACCURATE |
| `estimateMinFeeTx` pads dummy VKey wits; prefer `calcMinFeeTx` / `calcMinFeeTxNativeScriptWits` with resolved UTxOs (L122-128) | `/code/cardano-ledger` `libs/cardano-ledger-core/src/Cardano/Ledger/Tools.hs:11-13,100-197` — all three exported; `:194` "better and easier to use `calcMinFeeTx`" | ACCURATE (see NIT 5 on the missing pin) |
| Repo mechanics | `scripts/validate.py` → PASSED, 17 skills; `scripts/update-doc-counts.sh --check` → skills 17 / sources 64, exit 0; SKILL.md = 226 lines (< 500); all 10 relative links in SKILL.md resolve on disk; frontmatter, section set, and `` comment match the other 16 skills; README skills-table row accurate; manifest `total_files: 3280` matches disk (3281 minus `.manifest.yaml`); `docs/sources/cardano-tx-tools/` = 13 files, exactly what the tightened globs (`README.md`, `docs/*.md`) select; `git status` clean before and after | PASS |

### Regression check on auditor-1 findings (dimension 3)

| auditor-1 item | State at `c373e79` |
|---|---|
| SHOULD-FIX 1 — Step 4 cites files outside the bundled corpus | **PARTIALLY REGRESSED** — file paths are gone and everything is version-pinned, but the "not bundled here; verify in a current upstream checkout" caveat that `23535f7` added was dropped by the `4409c6c` rewrite → finding 2 |
| SHOULD-FIX 2 — all examples from one project | RESOLVED — nine surfaces across four capability classes; the author-affiliated project is one entry among three in the first bullet |
| SHOULD-FIX 3 — Conway-incomplete fee statement | RESOLVED — L58-63, verified against the bundled ADR |
| SHOULD-FIX 4 — missing `calcMinFeeTx` alternative | RESOLVED — L124-128, all three identifiers verified upstream |
| NIT 5 — `draft` vs `build` | RESOLVED — L173 ("use full `build`, not `draft`") |
| NIT 6 — "from zero" / "assumes" phrasing | RESOLVED — that prose no longer exists |
| NIT 7 — no inbound links | RESOLVED — `build-transaction/SKILL.md:39`, `debug-transaction/SKILL.md:33` |
| NIT 8 — bare-noun skill name | Unchanged; accepted, triggering is description-driven |
| NIT 9 — 30-file Amaru lattice case study | RESOLVED — globs tightened to `docs/*.md`; side effect in NIT 6 below |

Both post-audit-1 prose edits read correctly in the final text: the illustrative
pseudocode label (L132-133) and — where it survived the rewrite — the antecedent
fix (Step 4 now names each project explicitly rather than saying "its").

---

## Findings

### 1. SHOULD-FIX — the Evolution SDK rule says "only on the completed result"; a public build option gets the candidate mid-build

`skills/fixpoint/SKILL.md:181-184`

> **Evolution SDK** (`@evolution-sdk/evolution` `0.5.12`) accepts fixed payment
> assets, **exposes fee and transaction only on the completed result**, and gives
> redeemer callbacks indexed inputs rather than the candidate

`BuildOptions.evaluator` is a documented public extension point
("Implement this interface to provide custom script evaluation strategies") whose
method is
`evaluate: (tx: Transaction.Transaction, additionalUtxos, context) => Effect<ReadonlyArray<EvalRedeemer>, EvaluationError>`
(`dist/sdk/builders/TransactionBuilder.d.ts:150-157`). It is invoked with the
assembled candidate transaction inside the build loop
(`dist/sdk/builders/phases/Evaluation.js:410-415`; the phase doc states
"Re-evaluation happens every Balance pass"). So a caller *can* observe every
post-balance candidate; what it cannot do is return anything but execution units.
The same class of gap exists in Mesh SDK: `MeshTxBuilderOptions.evaluator`
(`@meshsdk/common` `IEvaluator.evaluateTx(tx: string, …)`) receives the serialized
candidate at `@meshsdk/transaction/dist/index.js:4352-4360`. The skill's Mesh
sentence survives this ("returns CBOR after `complete`" — true, no exclusivity
claimed); Evolution's does not, because of the word "only".

This also means the probe matrices are incomplete on their own terms: probe-1's
Evolution P3 cell ("`toTransaction()` is only on the completed result; internal
`PhaseContext` is not a public observation/re-entry callback") and probe-2's Mesh
P3 cell ("internal selection callbacks are not application hooks") both reason
about internal state and miss a public callback that takes the candidate. Under
the skill's own Step 2 definition of the pattern — "a candidate-transaction
callback whose result participates in another balance pass" (L116-118) — the
evaluator arguably qualifies structurally, even though it cannot carry
fee-dependent outputs or a final-output redeemer.

The *action* the rule prescribes (rebuild in an outer bounded loop for
fee-dependent outputs and final-output redeemers) remains correct; only the
justification is overstated.

Suggested fix: "…exposes the fee and the transaction on the completed build
result — a custom `BuildOptions.evaluator` sees each candidate mid-build but can
return only execution units — and gives redeemer callbacks indexed inputs…"; and
amend the two P3 cells to say "no hook that can supply values back into the loop"
rather than "no hook".

### 2. SHOULD-FIX — the "not bundled here, verify upstream" caveat was dropped when Step 4 was rewritten

`skills/fixpoint/SKILL.md:169-198`

At `96c449c`, Step 4 opened with: *"The upstream source details mentioned below
are **not bundled here**; verify them in a current upstream checkout before
relying on identifiers or types"*, plus a link to the one bundled anchor
(`docs/sources/cardano-tx-tools/README.md`). The `4409c6c` rewrite removed both.
The final text now asserts nine version-pinned API branches under the heading
"Apply the **verified** API branch" with no statement of when, how, or against
what they were verified, and `grep -n -i 'upstream\|bundled\|checkout'
skills/fixpoint/SKILL.md` returns only the ADR reference at L62.

Concretely: a loaded agent has `Read Grep Glob` and no `WebFetch`, and not one of
the nine pins (`7bfe95b`, `4f1ea9c`, `6844943`, `0.5.12`, `6b42538`, `b951a63`,
`1.9.1`, `11.0.0.0`, `cdee91d`) is checkable against the bundled corpus — the
weekly refresh covers only `docs/sources/cardano-tx-tools/`. Pinning makes the
claims *falsifiable*, which is a real improvement over `9b8763f`, but it does not
tell the reader they must go outside this repo to falsify them. This is the
CONTRIBUTING:32 "no refresh mechanism and rots silently" concern that auditor-1's
finding 1 raised and that `23535f7` had answered.

Suggested fix: restore one sentence under the Step 4 heading — "Checked against
the listed versions/commits; these sources are not bundled in this repo, so
re-check identifiers and types in a current upstream checkout before relying on
them."

### 3. SHOULD-FIX — the contraction argument's invariance precondition names only reference inputs

`skills/fixpoint/SKILL.md:165-167`

> With the reference-input set fixed, the tiered reference-script charge is
> constant across these iterations, so it does not weaken that contraction
> argument.

The bundled ADR the skill cites says the charge is computed by combining **all
regular inputs and reference inputs**, resolving them, and summing every
reference script found in the resulting outputs
(`docs/sources/cardano-ledger/adr/2024-08-14_009-refscripts-fee-change.md:27-33`;
"All Plutus scripts contribute to this calculation, regardless if they are being
used or not"). A balance loop that selects an additional fee-paying input whose
UTxO carries a reference script therefore changes the tiered charge mid-loop —
and Step 3's `assembleFullTransaction` explicitly re-does selection each pass.
cardano-client-lib implements exactly this (`FeeCalculators.java`, the
`totalRefScriptBytesInInputs` block), which is corroborating evidence that the
input-side contribution is real and not theoretical.

Impact is bounded — the loop re-estimates from the real candidate each pass, and
the skill mandates a bound and post-convergence validation regardless — so the
consequence is a reader who believes an oscillation is impossible when it is
merely unlikely.

Suggested fix: "With the input and reference-input sets fixed, the tiered
reference-script charge is constant across these iterations…".

### 4. NIT — two pins name development snapshots, in two different notations

`skills/fixpoint/SKILL.md:174-180`

- **cardano-client-lib `0.8.0-pre5`, `4f1ea9c`**: `4f1ea9c` is a merge commit on
  the development branch, and `0.8.0-pre5` is a pre-release. The cited capability
  is not new — `UpdateOutputFunction` and `feeCalculator(int, UpdateOutputFunction)`
  are present at the latest stable tag `v0.7.2` (verified by
  `git grep UpdateOutputFunction v0.7.2 -- '*/FeeCalculators.java'`). Pointing the
  reader at a pre-release for a capability that ships in the current stable
  release is avoidable.
- **Scalus `1.0.0`, `6844943`**: `git describe` at `68449438` is
  `v1.0.0-38-g68449438e` — 38 commits past the release, presented as a bare
  `1.0.0`, while Cardano Tx Tools in the same list uses the honest `0.2.3.0+14`
  form for the same situation. The claim itself survives: `DiffHandler`, the
  bounded `balanceFeeAndChangeWithTokens` loop (`MaxBalancingIterations = 20`),
  `BalanceDidNotConverge`, and `redeemerBuilder: Transaction => Data` all exist
  at tag `v1.0.0`, which I checked out specifically to confirm this.
  Supporting evidence is also mislabelled: probe-1's `scalus.txt` records
  "stable package version: 1.0.0 (build.sbt)", but `val scalusStableVersion` in
  `build.sbt:14` is the MiMa binary-compatibility baseline, not the version being
  built.

Suggested fix: pin `0.7.2` for cardano-client-lib (or say "0.8.0-pre5; also in
stable 0.7.2"), and write Scalus as `1.0.0+38`, matching the Cardano Tx Tools
notation.

### 5. NIT — the ledger-level bullet is the one unpinned API claim

`skills/fixpoint/SKILL.md:122-128`

Step 4 pins every surface; Step 2's ledger bullet names `estimateMinFeeTx`,
`calcMinFeeTx`, and `calcMinFeeTxNativeScriptWits` with no version. All three are
correct today (`cardano-ledger-core` `Cardano/Ledger/Tools.hs:11-13`), so this is
purely about symmetry: these identifiers rot the same way the Step 4 ones do and
carry no marker for a future reader or refresher.

Suggested fix: add the `cardano-ledger-core` version alongside them, in the
Step 4 style.

### 6. NIT — the tightened glob leaves two dangling links inside the bundled corpus

`docs/sources/cardano-tx-tools/docs/prior-art.md:46,94`

Both link to `may-2026-amaru-lattice/index.md`, which the new
`docs/*.md` glob no longer fetches. They resolved at `9b8763f` and do not at
`c373e79`, so this branch created them. Context that keeps it a NIT: dangling
relative `.md` links are the corpus norm, not an exception — 30 of the 39 sources
that have relative links have at least one dangling (e.g. `haskell-nix` 24,
`mithril` 21, `cardano-wallet` 13), `cardano-tx-tools` is at 3 of 43, and no
script or CI check enforces link integrity.

Suggested fix: none required; if desired, add `docs/may-2026-amaru-lattice/*.md`
back or accept the two dangling references as consistent with the rest of the
corpus.

---

## Evidence caveats

- Upstream trees were verified at the pinned revisions: `/code/cardano-tx-tools`
  @ `7bfe95b`, `/code/cardano-api` @ `b951a638`, `/code/cardano-ledger` (working
  copy, unpinned), fresh clones of `bloxbean/cardano-client-lib` @ `4f1ea9c` and
  `scalus3/scalus` @ `68449438` (plus tag `v1.0.0`), single-file reads of
  `Emurgo/cardano-serialization-lib` @ `6b42538` and `txpipe/pallas` @ `cdee91d`,
  and clean installs of `@evolution-sdk/evolution@0.5.12` and
  `@meshsdk/core@1.9.1`. Those checkouts and `node_modules` trees are
  reproducible from the revisions recorded here and were retired at COMPLETE.
- Two probe claims were **not** re-executed in this seat: the `cardano-cli
  conway transaction build --help` flag dump (no local `cardano-cli`; the bundled
  wiki reference corroborates only the auto-balancing half) and the
  `cardano-tx-tools#checks.x86_64-linux.unit` nix build (accepted from probe-1;
  the identifiers it evidences were re-read directly from source).
- `scripts/check-pr-policy.py` was not run (live GitHub API; this seat is
  read-only/offline-by-policy). `scripts/validate.py` and
  `scripts/update-doc-counts.sh --check` were run under a `nix shell` python and
  both pass.
- auditor-1's suggestion to disclose the authorship relationship to
  `lambdasistemi/cardano-tx-tools` in the PR description is not verifiable from
  this seat and remains open for the ticket owner.
- No file in the audited tree was modified; `git status` was clean at start and
  at finish.

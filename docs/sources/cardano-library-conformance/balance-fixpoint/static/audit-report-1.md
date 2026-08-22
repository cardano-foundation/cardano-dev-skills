# Audit report — `fixpoint` skill contribution

- Auditor: fixpoint/auditor-1 (EXTERNAL-AUDITOR, read-only)
- Audited tree: /code/cardano-dev-skills-fixpoint @ 9b8763f (branch feat/fixpoint-skill)
- Cross-checked against: /code/cardano-tx-tools @ 7bfe95b (2026-06-30), read-only
- Date: 2026-08-19

## Verdict

**FINDINGS** — 0 BLOCKER, 4 SHOULD-FIX, 5 NIT.

No factual claim about `cardano-tx-tools` is wrong: every signature, constructor,
error constructor, module name and test behaviour the skill asserts was checked
against the actual Haskell source and matches. The findings are about
*incompleteness* (a Conway-era fee statement, a missing ledger alternative), about
*verifiability* (the skill's most concrete section cites files that are not in the
bundled corpus and that no refresh mechanism can keep honest), and about *repo
policy fit* (all concrete examples come from a single project registered in the
same PR).

## What was verified as correct (evidence)

| Claim (SKILL.md) | Checked against | Result |
|---|---|---|
| `balanceTx` builds the full candidate incl. change + collateral, calls `estimateMinFeeTx`, bounded loop, `FeeNotConverged` (L163-168) | Balance.hs:124-133 (`FeeNotConverged`), :407-433 (`buildTx`), :356-406 (collateral fields), :438-457 (`go`, bound `n > 10`, start `Coin 0`, exit `newFee <= currentFee`) | ACCURATE |
| `balanceFeeLoop` accepts `mkOutputs :: Coin -> Either String (StrictSeq TxOut)`; per round computes outputs from current fee, installs outputs+fee, re-estimates (L170-174) | Balance.hs:535-579 (exact type `Coin -> Either String (StrictSeq (TxOut ConwayEra))`; loop body identical to description) | ACCURATE (era param elided in prose — fine) |
| `Peek :: (ConwayTx -> Convergence a) -> TxInstr q e a`; `Iterate a` = provisional + run again, `Ok a` = stable (L176-182) | Build.hs:334-340, :536-539, :818-822 | ACCURATE — signature and semantics match verbatim |
| MinUtxoSpec: `payTo` token output, `peek (observeTxOutCoin ix)`, `spendScript` puts the coin in a redeemer, test asserts redeemer == final output coin (L184-190) | MinUtxoSpec.hs:221-257; `observeTxOutCoin` at Build.hs:843-848 | ACCURATE (see NIT 5 on "full cycle") |
| Cardano Tx Tools exposes `Cardano.Tx.Build` / `Cardano.Tx.Balance` / `Cardano.Tx.Evaluate` + phase-1 validation, described in the bundled README (L119-121) | docs/sources/cardano-tx-tools/README.md:219-222 (module table) and :151, :222 (`Cardano.Tx.Validate.validatePhase1`); modules present on disk | ACCURATE |
| `estimateMinFeeTx` measures a candidate and pads with the requested dummy VKey witnesses (L110-113) | cardano-ledger-core-1.20.0.0 `Cardano/Ledger/Tools.hs`:190-223 (`addDummyWitsTx`) | ACCURATE |
| Evolution SDK documents an explicit balance/evaluation/fee cycle with a ten-attempt limit (L107-109) | docs/sources/evolution-sdk/architecture/script-evaluation.mdx:280, :319 (`MAX_ATTEMPTS` default 10) | ACCURATE |
| min-UTxO recursion via `coinsPerUTxOByte`; topping up can cross a CBOR width boundary and raise the threshold again (L68-70) | Build.hs:1280-1301 (`applySendMode` runs its own 8-round bounded min-coin fixpoint for exactly this reason) | ACCURATE — independently corroborated by the tool's own code |
| Validator equation `sum(refunds) = sum(inputs) - fee - N * tip` (L76) | Balance.hs:496-505 (same equation, same framing) | ACCURATE |
| Contraction argument (L154-157) | Balance.hs:514-517; minFeeA-per-byte reasoning | ACCURATE for the iterated part |
| Phase-2 ExUnits patching can change size/fee and must re-enter the loop (L201-203) | Build.hs:1367-1385 (`build` loop step 6: "If any Peek returned Iterate, fee changed, or ExUnits changed → 1") | ACCURATE |
| Repo mechanics | `validate.py` → PASSED, 17 skills; `update-doc-counts.sh --check` → skills 17 / sources 64, no drift; SKILL.md 213 lines (< 500); frontmatter `allowed-tools: Read Grep Glob`, `disallowed-tools: WebFetch WebSearch`; all four required sections present; name kebab-case and matches directory; no `references/` dir | PASS |
| Source registration | repo URL matches `git remote` of the real repo (`github.com/lambdasistemi/cardano-tx-tools`); `website:` matches `mkdocs.yml:2` `site_url`; `category: sdk` and `format: markdown` are in the allow-list; no `pins.yaml` entry needed (pins.yaml header: a new source fetches branch tip, first pin recorded at next refresh); fetched `.md` set is byte-identical to the upstream tree (only non-`.md` assets differ, as the globs intend); activity signal fine (last commit 2026-06-30, tags through v0.2.3.0, not archived, not a fork) | PASS |
| README skills-table row + count sentinels | README.md:37 row text matches the skill's actual scope; CLAUDE.md/README counts 16→17 and 63→64 consistent with disk | PASS |
| DESIGN.md | Not required: it does not enumerate skills, and `fixpoint` introduces no new taxonomy (Decision 2 workflow skill, not a meta-skill) | PASS |

---

## Findings

### 1. SHOULD-FIX — Step 4's citations are outside the bundled corpus and outside any refresh mechanism

`skills/fixpoint/SKILL.md:159-190`

Every concrete anchor in Step 4 is an upstream *source* path — `src-tx-build/Cardano/Tx/Balance.hs`, `src-tx-build/Cardano/Tx/Build.hs`,
`test/Cardano/Tx/Build/MinUtxoSpec.hs` — plus pinned type signatures and error-constructor names.

Evidence: `grep -rn "balanceFeeLoop\|balanceTx\|Peek\|Convergence\|FeeNotConverged\|observeTxOutCoin\|MinUtxoSpec" docs/sources/cardano-tx-tools/` returns **zero hits**. The registered globs are `README.md` and `docs/**/*.md`, so no Haskell source is bundled and none ever will be. Consequences:

- An agent that loads this skill (tools: `Read Grep Glob`, no `WebFetch`) cannot open or verify a single one of these files. CONTRIBUTING's checklist item "works with `Read` / `Grep` / `Glob` only" is satisfied mechanically but defeated in substance.
- The weekly refresh can never detect drift in these claims — exactly the "no refresh mechanism and rots silently" failure CONTRIBUTING:32 warns about for project-pinned skill content. They are correct today at upstream 7bfe95b; a rename of `FeeNotConverged` or a change to `Peek`'s type makes the skill silently wrong.

Suggested fix: keep the *patterns*, drop the pinned paths/signatures — anchor the verifiable half to `docs/sources/cardano-tx-tools/README.md:219-222` (the module table, which is bundled and refreshed) and mark the rest explicitly as "upstream repository, not bundled here".

### 2. SHOULD-FIX — all concrete examples come from one project, registered in the same PR

`skills/fixpoint/SKILL.md:119-121, 159-190`

CONTRIBUTING:11 — "Skills are never project-specific"; CONTRIBUTING:32 — "Skills must survey, not steer … presents them neutrally with honest decision criteria (`query-chain` is the model)."

Step 2 does survey three construction surfaces honestly, and line 161 hedges ("patterns, not a requirement to adopt that library"). But Step 4 — the skill's longest and only worked-example section — is titled with the project's brand and draws 4 of 4 examples from it, and that project's source is being registered in the same two-commit contribution by the same author. Read against `query-chain` (the stated model, which names several providers per option), this is below the bar even though `fixpoint` itself is correctly task-named and therefore does not trip the brand-name gate.

Suggested fix: retitle Step 4 "Recognize the pattern in real implementations" and add at least one non-lambdasistemi instance per pattern — the Evolution SDK balance/evaluate/fee cycle is already bundled and already cited at L107-109 (`script-evaluation.mdx:280,319`), `cardano-cli transaction build`'s fee loop and `cardano-wallet`'s balance step are further candidates; and disclose the authorship relationship in the PR description.

### 3. SHOULD-FIX — "minimum fee is a linear function of serialized transaction size" is Conway-incomplete

`skills/fixpoint/SKILL.md:59-60`

Since Conway the fee is `a·size + b + tierRefScriptFee(refScriptBytes)`, where the reference-script term is deliberately **non-linear**: 25 KiB tiers, each priced 1.2× the previous, over `minFeeRefScriptCostPerByte` (15 in Conway genesis). Evidence: `docs/sources/cardano-ledger/adr/2024-08-14_009-refscripts-fee-change.md` (Decision + `tierRefScriptFee`), corroborated by the 5th argument of `estimateMinFeeTx` and by `Balance.hs:236-239, 445-451` threading `refScriptBytes`.

This matters: a reader implementing an estimator from the sentence as written under-charges any tx with reference scripts and gets `FeeTooSmallUTxO`. The skill does tell you to include reference-script bytes (L42, L168), so this is a framing gap, not a contradiction — and the contraction argument at L154-157 survives, because ref-script bytes are fixed across iterations.

Suggested fix: "linear in body size (`a·size + b`), plus Conway's tiered charge on total reference-script bytes, which is fixed across iterations."

### 4. SHOULD-FIX — the ledger-level option omits the more accurate ledger function

`skills/fixpoint/SKILL.md:110-113`

The bullet offers only `estimateMinFeeTx` and correctly warns the caller owns the witness-count assumption — but the ledger documents a better tool for precisely that, and the skill does not mention it. `Cardano/Ledger/Tools.hs:190-193`: *"If you have access to UTxO necessary for the transaction that it is better and easier to use `calcMinFeeTx` instead"*; and `:99-102` `calcMinFeeTxNativeScriptWits` for the native-script-witness case. Witness count is the single most error-prone input in this whole workflow, so leaving out the alternative weakens the "honest decision criteria" requirement.

Suggested fix: one clause — "when the resolved UTxO set is available, `calcMinFeeTx` (or `calcMinFeeTxNativeScriptWits` for native-script witnesses) derives the witness count instead of trusting a supplied one."

### 5. NIT — the MinUtxoSpec example does not cover the "full cycle" it claims

`skills/fixpoint/SKILL.md:184-190`

The test drives `draft pp prog` (MinUtxoSpec.hs:234). `draft`/`draftWith` (Build.hs:1307-1345) is a **two-pass, non-balancing** assembly: pass 1 collects steps against an empty tx, pass 2 re-interprets against the assembled body so `Peek` resolves. It performs no coin selection, no fee estimation, no script evaluation and no convergence check. The min-UTxO → observation → redeemer leg is genuinely exercised; the fee/change and ExUnits legs are not. The function with the bounded fixpoint loop is `build` (Build.hs:1367-1385).

Suggested fix: say the test pins the min-UTxO→observation→redeemer leg under `draft`, and name `build` as the function that closes the fee/ExUnits loop.

### 6. NIT — two imprecise phrases in the `balanceTx` description

`skills/fixpoint/SKILL.md:166-168`

- "retries **from zero** until the estimate no longer exceeds the retained fee" reads as if each retry restarts at zero. `Balance.hs:438-457`: the loop *starts* at `Coin 0` and then retries at `newFee`, monotonically non-decreasing.
- "It **assumes** the correct key-witness count" — the count is *derived* by `estimatedKeyWitnessCount` (`Witnesses.hs:45-57`: unique payment-key hashes of pub-key inputs, certs, required signers, votes, withdrawals, floored at 1). The caveat is still worth making, since script-locked inputs contribute nothing and a native-script multisig can be under-counted, but the mechanism is estimation, not assumption.

Suggested fix: "starts from a zero fee and raises it monotonically until the estimate no longer exceeds the retained fee. The witness count is *estimated* from the inputs and required signers, which can under-count native-script multisig."

### 7. NIT — no inbound links: nothing in the skill graph routes to `fixpoint`

`skills/build-transaction/SKILL.md:34-38`, `skills/debug-transaction/SKILL.md:28-32`

`grep -rl fixpoint skills/` matches only the new skill itself. The links are one-way: `fixpoint` points out to `build-transaction` and `debug-transaction`, neither points back. The repo's convention is bidirectional — the previous new skill got its inbound link (`suggest-tooling` → `suggest-scalability`). Worse, `build-transaction:57-58` tells the reader "Let the SDK calculate fees and construct change outputs automatically", which is the exact advice that fails for a fee-dependent output and offers no escape hatch. A user hitting a circular-dependency problem lands on those two skills, not on this one.

Suggested fix: add one "When NOT to Use" bullet to each — "output values or a redeemer depend on the final fee — use `fixpoint`".

### 8. NIT — `fixpoint` is the only bare-noun skill name

`skills/fixpoint/SKILL.md:2`

All 16 pre-existing skills are verb-object or descriptive compounds (`build-transaction`, `debug-transaction`, `query-chain`, `optimize-validator`, `suggest-scalability`, …). `fixpoint` is domain jargon a Cardano developer with this problem is unlikely to type, so discovery rests entirely on the description's trigger phrases (which are good, and 5 in number as the template asks).

Suggested fix: consider `balance-fixpoint` or `converge-transaction`; if the name stands, keep it and accept that triggering is description-driven.

### 9. NIT — 70% of the fetched corpus is one project-specific case study

`registry/sources.yaml:637-647`, `docs/sources/cardano-tx-tools/docs/may-2026-amaru-lattice/`

30 of the 43 fetched `.md` files are the "May 2026 85-Tx Lattice Report" — a worked mainnet Amaru-treasury/USDM SPARQL audit. It passes the two-part scope test (Cardano-native; runnable `tx-fetch`/`tx-graph`/Jena workflows with real commands, not marketing) so it is legitimately in scope, but it is engagement-narrative weight rather than reusable integration surface, and it pushes treasury/governance-flavoured prose into the bundled corpus.

Suggested fix: either tighten `glob_patterns` (e.g. keep `docs/*.md`, exclude `docs/may-2026-amaru-lattice/**`) or state in the PR that the case study is deliberately included as a worked `tx-graph` tutorial.

---

## Evidence caveats

- The upstream code was read at the local clone `/code/cardano-tx-tools` @ `7bfe95b` (2026-06-30). The fetched `.md` files in this branch are byte-identical to that same tree, so the docs shipped here and the code I checked are the same version. If upstream has advanced past 7bfe95b since the 2026-08-19 fetch, findings 1/5/6 should be re-checked against the newer tip.
- `scripts/check-pr-policy.py` was **not** run: it performs live GitHub API vetting and this seat is read-only/offline-by-policy. `scripts/validate.py` and `scripts/update-doc-counts.sh --check` were run and both pass (python3 supplied via `nix shell` — no change to the audited tree).
- No files in the audited tree were modified. `git status` was clean at start and remains clean.

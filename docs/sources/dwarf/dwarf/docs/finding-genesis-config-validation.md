# Finding note — genesis/config validation (cardano-node + Amaru)

**From:** DWARF genesis/config differential testing (Cyber-Castellum) · **Date:** 2026-07-18
**Scope:** feed cardano-node 10.7.1 and Amaru the *same* mutated `shelley-genesis.json`
(testnet_42 baseline: f=0.2, k=5, epoch 125) and compare acceptance. One confirmed
robustness bug in cardano-node, one well-supported architectural asymmetry in Amaru,
and one preliminary lead held back pending cleaner evidence.

## Finding 1 (cardano-node) — uncaught crash on unguarded time-parameter division

A systematic sweep of **417 single-field genesis mutations** (every numeric top-level and
`protocolParams` field × a 15-value edge palette), classified by timing (clean reject ~20 ms;
crash ~140 ms; accept = not-rejected-in-3 s), gives: **339 clean rejects, 75 accepts, 3 crashes.**
The 3 crashes are all a division reaching zero on a time parameter:

- `epochLength = 0` → `divide by zero`
- `slotLength = 0` → `Ratio has zero denominator`
- `slotLength = 1e-300` (underflows to 0) → `Ratio has zero denominator`

Each exits fast (~0.14 s) — not a hang or DoS — but the node *crashes* rather than reporting
"invalid genesis." **Recommendation:** range-check `epochLength > 0` and `slotLength > 0` during
genesis decode, alongside the existing `activeSlotsCoeff`/`securityParam` checks.

**Also (weaker, hedged):** the sweep shows genesis validation is largely type/parse-level, not
semantic — cardano-node *accepts* `slotLength=-1` (while `slotLength=0` crashes), zero
`maxKESEvolutions`, zero `updateQuorum`, and enormous `securityParam`/`epochLength`. Some may be
intentionally unconstrained at genesis; the negative-vs-zero `slotLength` inconsistency on one
field is the concrete part.

## Finding 2 (Amaru) — genesis is validated in a different component, not at run time

cardano-node reads and validates the raw `shelley-genesis.json` **directly at node
startup** (~20 ms clean reject). Amaru does **not** re-validate the raw genesis at
`amaru run` — it consumes **pre-derived** `AMARU_GLOBAL_*` parameters that
`bootstrap-producer` computes from the genesis earlier. Observed properties of that
derivation path:

- **Orders of magnitude slower** — seconds to minutes vs cardano-node's ~20 ms.
- **Intermittently hangs** on an internal header-extractor regardless of input.
- **Non-deterministic** for the same invalid input — `activeSlotsCoeff=2.0` derived
  `1/f=1, scale=25` on one run and `1/f=5` on another.

The consequence is an architectural difference in the **config-trust model**: cardano-node
treats the genesis as untrusted input to validate up front; Amaru trusts a derived-params
artifact and never re-checks the source genesis at run time. A malformed or mis-derived
genesis can therefore propagate into Amaru silently. **Recommendation:** validate the raw
genesis (bounds/type checks matching cardano-node's) at the point Amaru loads it, and make
the derivation deterministic and non-hanging on malformed input.

## Finding 3 (PRELIMINARY — reported as a lead, not a confirmed finding)

Some mutations hint Amaru is more lenient than cardano-node — most clearly, `slotLength=0`,
where cardano-node crashes but Amaru accepts and boots on baseline-derived params. But the
Amaru derivations were non-deterministic and several runs hung, so the per-mutation verdicts
are **not reliable enough to assert**. Confirming Amaru leniency requires a deterministic
Amaru genesis-parse surface (its own config parser, or `amaru import` with a hard timeout).
We are deliberately **not** claiming "Amaru accepts invalid genesis" on this evidence.

## Reusable harness

The mutation battery + both-node runners are in
`reports/consensus-genesis-config-evidence/` and re-run against any devnet genesis. It is a
new differential *class* — config-acceptance parity — distinct from the message/block
fuzzing DWARF already does.

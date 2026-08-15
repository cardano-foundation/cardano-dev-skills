# Genesis/config-acceptance differential (cardano-node vs Amaru)

**Harness experiment** (config-mutation battery, not a runner-native DSL scenario) · **Run:** 2026-07-18
**Devnet:** `cardano_amaru` testnet_42 (f=0.2, k=5, epoch 125, Conway)

## Severity & scope (read first)

This is a **new test method** (a config-acceptance differential) and its first results. To set
expectations honestly:

- **Finding 1 is a low-severity robustness bug, not a security vulnerability.** The genesis file
  is trusted, operator-set config — an attacker cannot feed a node a malicious genesis over the
  network — so there is **no attack surface**. The bug is that cardano-node *crashes* (a loud,
  fast startup exception) instead of cleanly rejecting a malformed genesis. It belongs upstream
  as a `cardano-node` (IntersectMBO) robustness issue, not a security advisory.
- **Finding 2 is the Amaru-relevant result** — an architectural observation about how Amaru
  validates (or rather, doesn't re-validate) the genesis. No exploit; a design observation worth
  the team's attention.
- **Finding 3 is a preliminary lead, deliberately not claimed as a finding** (the data was flaky).

Nothing here is a critical or exploitable security finding. The value is the **method** (a
config-acceptance differential is a new surface DWARF didn't cover) and two concrete, honest
observations.

## What it tests

A new surface for DWARF: the **genesis/config both nodes ingest at startup**. Existing fuzzing targets protocol messages and blocks (the "reflected" input); this targets the *stored* input — the `shelley-genesis.json` that defines the protocol's core parameters. The question: **do cardano-node and Amaru agree on which genesis configurations are valid?** We mutate one genesis field at a time (edge/invalid values) and compare accept/reject. A config one implementation accepts and the other rejects (or crashes on) is a semantic divergence at the configuration layer — before any block is ever produced.

## Method

- Baseline: the real testnet_42 `shelley-genesis.json`. 15 single-field mutations (out-of-range `activeSlotsCoeff`, zero/negative/float `securityParam`, `epochLength`/`slotLength = 0`, type confusion, missing/extra fields).
- **cardano-node side:** feed each mutated genesis and start the node; classify ACCEPT (starts) vs REJECT (fast exit + error) vs CRASH; record latency.
- **Amaru side:** feed each mutated genesis through Amaru's derivation path (`bootstrap-producer`, which computes Amaru's `AMARU_GLOBAL_*` params from the genesis); classify accept/derive vs reject vs hang. **Control** (`activeSlotsCoeff=0.5` → Amaru derives `1/f=2`, correct) confirms the mutated genesis actually reaches Amaru's derivation.

## Findings

### Finding 1 (CONFIRMED, systematic) — cardano-node crashes on unguarded time-parameter division

We swept **417 single-field mutations** of `shelley-genesis.json` (every top-level and
`protocolParams` numeric field × a 15-value edge palette: zero, negative, float-where-int,
`2^63`/`2^64`/`10^30`, `1e-300`, string, null, bool, missing, …) and classified each by
timing: a clean parse-time **REJECT** exits in **~20 ms**; a **CRASH** fast-fails at ~140 ms
with an uncaught exception; an **ACCEPT** doesn't reject within a 3 s cap.

| Outcome | Count |
|---|---:|
| REJECT (clean, ~20 ms) | 339 |
| ACCEPT (not rejected) | 75 |
| **CRASH (uncaught exception)** | **3** |

The 3 crashes are all a **division reaching zero on a time parameter**:

| Mutation | Result |
|---|---|
| `epochLength = 0` | `divide by zero` |
| `slotLength = 0` | `Ratio has zero denominator` |
| `slotLength = 1e-300` (underflows) | `Ratio has zero denominator` |

So the node crashes rather than cleanly rejecting exactly where a genesis time parameter is
zero (or underflows to zero) and reaches an unguarded division. Fast-failing, not a hang — but
a *crash* instead of an "invalid genesis" rejection. **Fix:** range-check `epochLength > 0` and
`slotLength > 0` at decode, alongside the existing `activeSlotsCoeff`/`securityParam` checks.

**Validation-completeness observation (weaker, hedged).** The 75 ACCEPTs show cardano-node's
genesis validation is largely **type/parse-level, not semantic**: it accepts `slotLength=-1`
(negative!) — while `slotLength=0` *crashes* — and also zero `maxKESEvolutions`, zero
`updateQuorum`, and enormous `securityParam`/`epochLength` (`2^63`). Some of these may be
intentionally unconstrained at the genesis layer, so we flag them as observations, not bugs —
but the *negative-slotLength-accepted vs zero-slotLength-crashes* inconsistency on one field is a
concrete robustness gap.

### Finding 2 (WELL-SUPPORTED) — the two implementations validate genesis in fundamentally different ways

This is the substantive gap-#2 result:

- **cardano-node** reads and validates the raw `shelley-genesis.json` **directly, at node startup**, and rejects a bad one in **~20 ms**, before any heavy initialisation.
- **Amaru** does **not** validate the raw genesis at `amaru run`. It consumes **pre-derived** `AMARU_GLOBAL_*` parameters that a *separate* component (`bootstrap-producer`) computes from the genesis earlier. That derivation is **orders of magnitude slower** (seconds to minutes), **intermittently hangs** on its internal header-extractor regardless of input, and — most concerning — produced **non-deterministic** derivations for the same invalid input across runs (`activeSlotsCoeff=2.0` yielded `1/f=1, scale=25` on one run and `1/f=5` on another).

So the two clients have different **config-trust models**: cardano-node treats the genesis as untrusted input to validate up-front; Amaru trusts a derived-params artifact and never re-checks the source genesis at run time. A malformed genesis that the deriver mis-handles can propagate silently into Amaru.

### Finding 3 (PRELIMINARY — not yet a confirmed Amaru finding)

Several mutations *hint* that Amaru is more lenient than cardano-node, but the results are not clean enough to assert:

- `slotLength = 0`: cardano-node **crashes**; Amaru **accepts** and derives baseline params, booting normally. (Amaru's derivation doesn't use `slotLength`, so it ignores the zero.) — the clearest divergence, but seen once.
- `activeSlotsCoeff = 2.0` (out of bounds): cardano-node rejects; Amaru does **not** cleanly reject — it produces a mangled, non-deterministic derivation and then hangs.
- `activeSlotsCoeff = 0`: **both** fail (cardano-node bounds-rejects; Amaru errors with a division-by-zero) — rough agreement.

**These are leads, not findings.** Amaru's derivation was non-deterministic and several runs hung, so the per-mutation Amaru verdicts are not reliable. Confirming Amaru's leniency needs a **deterministic** Amaru genesis-parse surface (its own config parser, or `amaru import` with a hard timeout that classifies a hang as its own outcome) rather than the flaky `bootstrap-producer` path. We are explicitly **not** reporting "Amaru accepts invalid genesis" as a finding on this evidence — that would be the LEAD-001 mistake (a harness artifact dressed as a security finding).

## Status & next step

Confirmed: the cardano-node crash (Finding 1) and the architectural asymmetry (Finding 2). Open: a clean Amaru accept/reject differential (Finding 3), gated on a deterministic Amaru genesis-validation surface. Raw data and the mutation battery are in
`reports/consensus-genesis-config-evidence/`.

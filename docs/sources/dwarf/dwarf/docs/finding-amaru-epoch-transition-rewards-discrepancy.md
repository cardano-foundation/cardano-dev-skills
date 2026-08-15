# Amaru panics at the epoch transition on a total-rewards discrepancy (v10.11, dormant epoch)

**Component:** `amaru` ledger — epoch transition / reward distribution (`crates/amaru-ledger/src/store/epoch_transition.rs:71`)
**Type:** Deterministic node crash (panic) at an epoch boundary — liveness / robustness
**Status:** **RESOLVED upstream in `v10.11.20260807`** (fix confirmed by source diff — see "Resolution" below). Previously **Confirmed** — deterministic (600+ identical restarts locally) and **independently reproduced in the client's own Antithesis run**. Recurred at **multiple** dormant epoch boundaries with a **constant 1,020 ADA** discrepancy. **The fix confirms the root-cause hypothesis below exactly**, and answers the former open item (the unassigned 1,020 ADA was a pool leader reward paid to a never-registered reward account).
**Found by:** DWARF adversarial mixed-net soak — an *honest* Amaru relay syncing an honest cardano-node chain crashed crossing epoch 3→4.
**Date:** 2026-08-02
**Version:** Amaru `v10.11.0` (lambdasistemi image `cf657b91…`), testnet_42, **k=20** (PR #186 params).

---

## Summary

An Amaru relay, syncing a normal (honest) cardano-node chain, **panics every time it crosses
the epoch 3→4 boundary**:

```
epoch_transition ... from=3 into=4 ... ratification.summarize is_dormant_epoch=true
thread 'tokio-rt-worker' panicked at crates/amaru-ledger/src/store/epoch_transition.rs:71:13:
discrepancy between expected total rewards (=1415076923074) and actual total rewards (=1414056923074)
```

The node then restarts (`restart: always`), re-syncs to the same boundary, and panics again —
**observed 18 consecutive identical crashes**. The discrepancy is exactly **1,020,000,000 lovelace
(1,020 ADA)** every time. This is **not adversarial** — it is the honest control relay on the honest
chain.

## Why this is (almost certainly) a genuine Amaru bug, not misconfiguration

- The assertion at `epoch_transition.rs:71` compares Amaru's **own** *expected* total rewards against
  its **own** *actual* distributed total — an **internal consistency check**. A parameter/genesis
  mismatch would yield a self-consistent (if "wrong") value, not `expected != actual`.
- The relay runs under the client's **intended k=20 params** (`AMARU_GLOBAL_CONSENSUS_SECURITY_PARAM=20`,
  scale=4) + the bootstrap's cardano-genesis-derived era-history. (The `amaru-runtime/global-parameters.json`
  k=5 file is **not mounted into the relay** — vestigial.)
- The preceding log gives the pot: `rewards.summarize effective_rewards=1415076923074
  total_rewards=114975000000000 available_rewards=91980000000000 treasury_tax=22995000000000
  pots_reserves=43800000000000000` for epoch 3. `expected total rewards` == `effective_rewards`.

**Candidate root cause:** on this small testnet (3 pools / 3 accounts), a reward of exactly 1,020 ADA
is **computed into the expected pot but never assigned** — consistent with a pool reward whose target
reward account is absent/retired, or an unregistered stake account. `cardano-node` routes such
unclaimed rewards back to the reserves/treasury; **Amaru asserts equality and panics** instead of
absorbing the remainder. Confirming the exact path needs an Amaru source dive around
`epoch_transition.rs:71` and the reward-assignment step.

## Confirmed in the client's own Antithesis run

Searching the client's own `cardano-foundation/cardano-node-antithesis` `testnets/cardano_amaru`
Antithesis run (run_id `0ed9a9d12a80add4184d8c32777ddfd5-56-17`) for the panic string returns the
**identical** message from `amaru-relay-1`:

```
discrepancy between expected total rewards (=1617230769226) and actual total rewards (=1616210769226)
```

- **Same delta:** `1617230769226 − 1616210769226 = 1,020,000,000` lovelace — *identical* to the local run.
- **Different epoch:** the client's run crashes at epoch **2→3** (`from=2 into=3`, `is_dormant_epoch=true`);
  the local run at **3→4**. So the crash **recurs at every dormant epoch boundary**, and the discrepancy
  is a **constant 1,020 ADA** independent of epoch — pointing to one fixed unassigned reward.

This proves (a) it is **not** a DWARF-side misconfiguration — it occurs in the client's own runs; and
(b) it is exactly the crash behind their "amaru-relay exit code 1" findings. Evidence:
`reports/amaru-epoch-transition-rewards-evidence/CLIENT-RUN-CONFIRMATION.txt`.

## Significance

- **Reproduces the client's own finding with a concrete cause.** The client's
  `cardano-foundation/cardano-node-antithesis` `testnets/cardano_amaru` Antithesis runs report
  **`amaru-relay-1` and `amaru-relay-2` exiting with code 1** (3 failed properties) but only surface the
  container exit. This is very likely the same crash — now with the panic message + `file:line`.
- **PR #186 did not fix it.** #186 retuned to k=20 to work around the earlier dormant-epoch crash
  (findings #4/#5, `RewardsSummaryNotReady`). This is a **different** panic (a rewards *total*
  discrepancy) on the same **dormant-epoch** path, still present at k=20 on v10.11 — so the dormant-epoch
  reward handling is still broken, just with a new symptom.
- **Blocks sustained operation:** an Amaru node cannot cross this (dormant) epoch boundary; it
  crash-loops. Any Amaru deployment reaching a dormant epoch boundary is affected.

## Observed behaviour

| | |
|---|---|
| Trigger | crossing epoch 3→4 (`from=3 into=4`), `is_dormant_epoch=true` |
| Panic | `epoch_transition.rs:71` — `discrepancy between expected total rewards (=1415076923074) and actual total rewards (=1414056923074)` |
| Delta | 1,020,000,000 lovelace, identical every crash |
| Determinism | 18+ consecutive identical restarts (crash-loop) |
| Adversarial? | No — honest relay, honest chain (the adversary-fed relay did not cause it) |

## Reproduction

Stand up a mixed cardano+Amaru testnet on the client's `cardano_amaru` topology (k=20,
bootstrap-producer, `amaru-bootstrap-producer:cf657b91…`), let the cardano cluster run past epoch 4,
and let an Amaru relay sync. It panics at the 3→4 boundary. (In DWARF this is
`antithesis/cardano_amaru_adversarial/`; the honest `amaru-relay-2` is sufficient — no adversary needed.)

## Suggested remediation

At the epoch transition, Amaru should **not assert** `expected == actual` total rewards; unassigned /
unclaimable rewards (retired pool, missing reward account) must be **returned to reserves/treasury**
(matching the Haskell ledger), not treated as an invariant violation that panics. Failing that, the
reward-assignment step should account for the full expected pot so the totals reconcile.

## Resolution (fixed in `v10.11.20260807`)

Fixed upstream one week after we found it. Confirmed by diffing the Amaru source between the affected
tag `v10.11.20260730` and `v10.11.20260807`. **The fix matches our root-cause hypothesis precisely.**

At the panic site the assertion is unchanged, but its input changed
(`crates/amaru-ledger/src/store/epoch_transition.rs`):

```
-  actual_total_rewards = rewards_paid + effective_rewards.unclaimed_rewards()
+  actual_total_rewards = rewards_paid + effective_rewards.total_unclaimed_rewards()
```

The old `unclaimed_rewards()` (`epoch_transition/rewards_state.rs`) only summed accounts that
**unregistered during the epoch**. The new `total_unclaimed_rewards()` also counts the second category,
spelled out in a new comment:

```
//  Resolve all accounts that have received rewards but aren't payable because they no longer
//  exist or have never existed. This can happen because of two reasons:
//   - The account was simply unregistered.
//   - The account was configured as pool owner but was never registered.   <-- previously missed
```

A **pool leader reward paid to a reward-account that was never registered** was never counted as
unclaimed → `actual_total_rewards` came up short by exactly that one pool's reward → the **constant
1,020 ADA** delta → panic. The fix tracks `pools_owners`/`leader_recipients` at reward-computation time
and folds those never-payable rewards back into the treasury, matching cardano-node (a coordinated
governance fix — commit `9107c1683` *"fix: debit the treasury correctly"* — separates treasury
withdrawals from deposit refunds on the same path). This **answers the former open item**: the unassigned
1,020 ADA was a single pool's leader reward to a never-registered reward account.

Relevant commits: the `unclaimed_rewards → total_unclaimed_rewards` rework (`summary/rewards.rs` +
`epoch_transition/rewards_state.rs`, adds `leader_recipients`/`pools_owners`) and `9107c1683`
*"fix: debit the treasury correctly"*, both landing in `v10.11.20260807`.

**Still-crashing deployments:** any node still on `v10.11.20260730` / the older `10.10.x`
bootstrap-producer images (including the client's `cf657b91…` and DWARF's box on `03d2727b…`/10.10.0)
will keep crash-looping until upgraded to `v10.11.20260807`.

## History (was Open, now resolved)

- The client's exit-code-1 crash **is** this same panic — confirmed via their own Antithesis run
  (`0ed9a9d1…`, epoch 2→3; local run 3→4) — so it recurred at **every dormant epoch boundary**.
- Former open item (pin the exact unassigned 1,020 ADA) — **answered by the fix**: a pool leader reward
  to a never-registered reward account.

## Aside — the adversarial soak that surfaced it

This was found by DWARF's adversarial mixed-net (`antithesis/cardano_amaru_adversarial/`): one Amaru
relay peers a byzantine adversary serving mutated block-fetch CBOR, one peers the honest chain. Over a
**6-hour** soak the adversarial oracle recorded **0 forged blocks adopted** across **512 rejections**
(`ORACLE_FAILS=0`) — Amaru robustly rejects mutated block CBOR. The crash came from the **honest** side,
independent of the adversary. (Curiously, the adversary *shielded* its relay from the crash: by rejecting
the forged blocks that relay never advanced to the epoch boundary, so only the honest relay crash-looped.)

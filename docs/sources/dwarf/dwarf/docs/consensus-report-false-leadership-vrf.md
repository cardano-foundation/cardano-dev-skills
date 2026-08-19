# False-leadership (forged-VRF) rejection differential (cardano-node vs Amaru)

**Harness experiment** (bespoke forge/serve pipeline, not a runner-native DSL scenario) · **Run:** 2026-07-17

## What it tests

A **leader-election safety** property, distinct from the chain-selection (long-range / forged-fork) tests. In Ouroboros Praos, a block producer proves its right to a slot with a VRF output. Two things must hold for the block to be legitimate:

1. the **VRF proof verifies** (the producer holds the VRF key), and
2. the resulting **leader value is below a threshold** set by the active-slot coefficient `f` and the producer's stake fraction `σ` — i.e. the producer actually *won* the slot lottery.

A node that only checks (1) but not (2) would accept blocks from a producer that never won the slot — **any-stake block forgery**, a catastrophic consensus break. This test asks the security question directly: **does each implementation enforce (2)?** And the differential payload: **do cardano-node and Amaru agree?** A gap where Amaru accepts what cardano-node rejects would be the finding.

This is a novel test for Amaru: it is not classic fuzzing (both nodes are memory-safe), and it is not a chain-selection test — it targets the leader-value check specifically.

## Method

- **Forge false-leadership blocks (real crypto, logical time).** We patched the `ouroboros-consensus-cardano` `db-synthesizer` (v0.25.1.0) with an env gate `DWARF_FALSE_LEADERSHIP=1` that raises the per-era active-slot coefficient (`praosLeaderF` / `tpraosLeaderF`) to ~0.99 in the consensus config used to forge and to validate its own forged blocks — while leaving `praosRandomnessStabilisationWindow` and the genesis config untouched, so nonce evolution is unchanged and the forged chain still connects to the real genesis root. The forger then "wins" ~every slot regardless of its real stake, producing blocks with a **valid VRF proof but a leader value far above the real threshold**.
- **Proof the forgery is real.** Same pool, same KES/VRF/opcert credentials, same 400-slot window: the **honest** forger (real `f = 0.2`) produces **27** blocks; the **patched** forger (`f ≈ 0.99`) produces **320**. The extra ~293 blocks are the false-leadership blocks — genuine signatures, unearned wins.
- **Build the attack chain.** Forge an honest chain to the Amaru bundle's chain tip (block 50, slot 646, epoch 5). `db-truncater --truncate-after-slot 646`, clear `volatile/ledger/gsm`, then `db-synthesizer --append` with `DWARF_FALSE_LEADERSHIP=1` forges the false-leadership continuation from slot 647 — kept **within epoch 5** (before the 5→6 boundary at slot 750). (Keeping it in one epoch sidesteps an Amaru epoch-transition panic — see the finding note.)
- **Serve and validate.** A real cardano-node relay is seeded at the attack chain-db. The **cardano-node victim** syncs it fresh over N2N and validates every header. The **Amaru victim** is bootstrapped (via `bootstrap-producer`) on the honest chain up to slot 646, then peers the relay and receives the false-leadership continuation from slot 647.

## Result

**Both cardano-node and Amaru REJECT the false-leadership blocks — identically.**

| Implementation | Reaction to a valid-proof / illegitimate-win block |
|---|---|
| cardano-node (fresh network sync) | **Rejected** — `HeaderProtocolError … VRFLeaderValueTooBig <leaderVal> (σ) (ActiveSlotCoeff f)`; chain-sync client threw and dropped the peer (23 rejections logged over the sync attempt). |
| Amaru (bootstrapped at slot 646) | **Rejected** — `HeaderValidationError: Insufficient leader stake` at slot 649; never adopted any block past 646; dropped the peer. |

**Differential verdict: AGREE. No divergence — no vulnerability.** Amaru enforces the VRF leadership threshold exactly as cardano-node does: it verifies not just that the VRF proof is valid, but that the leader value is within the odds the producer's stake permits.

### Fine-grained agreement

The two nodes even agree at the block level. The forged continuation begins at slot 647, but the producer *could* legitimately have won a few of the earliest slots (a low VRF draw is valid under the real `f`). Amaru accepted the genuinely-winnable headers at 647–648 and rejected at **slot 649** — the first block whose leader value genuinely exceeds the threshold. cardano-node behaves the same way: it accepts the legitimately-won blocks and rejects at the first illegitimate one. Neither node adopts a single unearned block.

## Behavioural observation (reported to the Amaru team, not a safety divergence)

Getting Amaru to *engage* the forged block surfaced an Amaru robustness issue: when Amaru forward-syncs across an **epoch boundary** from a freshly bootstrapped snapshot, it **panics** on an internal assertion (`amaru-ledger/src/state.rs:514: "unexpected stake distribution for epoch"`) rather than handling it gracefully. We worked around it by confining the false-leadership blocks to a single epoch. This is a crash/robustness bug worth fixing but is **not** a consensus-safety divergence — see `finding-amaru-vrf-leadership-epoch-panic.md`.

## Scope

This exercises the **Praos leader-value check** (`VRFLeaderValueTooBig` / `Insufficient leader stake`) on the `cardano_amaru` devnet (`k = 5`, `f = 0.2`, epoch 125, Conway). The cardano-node control was captured live over network chain-sync; Amaru's rejection was captured on its own devnet. The result is a **positive** one — a novel security test that Amaru passes.

## Pipeline (reusable)

Backing logs, the Haskell patch, and the forge/serve scripts are in
`reports/consensus-false-leadership-vrf-evidence/`. The patched `db-synthesizer`
and the attack chain-dbs are preserved on the build host under `/tmp/fl2/`.

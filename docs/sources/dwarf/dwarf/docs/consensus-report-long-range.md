# Long-range — deep-rollback rejection differential (cardano-node vs Amaru)

**Harness experiment** (additive eclipse + chain-serving-adversary compose, not a runner-native DSL scenario) · **Run:** repeating soak, 2026-07-16

## What it tests

The core long-range attack safety property in Ouroboros: **an honest, already-synced node must never roll back more than the security parameter `k`**, even when its only source of the chain tells it to. `k=5` on this devnet. A node that accepts a deeper rollback would abandon settled (immutable) history — the defining long-range failure. The differential question: **does the new Amaru node enforce the k-bound identically to cardano-node?** A divergence between the two implementations is the finding.

## Method

- **Substrate:** the real upstream `cardano_amaru` mesh (attach, no provisioning). `k=5`, epoch 125 slots, active-slot-coeff 0.2, Conway at epoch 0.
- **Eclipse:** each target node is isolated on its own bridge network so its **only** upstream peer is a `dwarf-adversary` chain-serving instance.
  - **cardano-node target:** a fresh `relay-lr` whose topology points at the adversary alone; it bootstraps to CaughtUp from the adversary.
  - **Amaru target:** `amaru-lr`, `--peer-address dwarf-adversary-amaru.example:3001`, **seeded from an already-synced Amaru rocksdb** so it starts at the honest tip. This is deliberate and faithful: a long-range attack targets a *running, synced* node, not one cold-syncing. (Cold-syncing Amaru through the adversary fails on header validation because Amaru's header check needs per-epoch stake distributions that lag during bulk sync — an orthogonal issue, not the property under test.)
- **Adversary:** `dwarf-adversary` (`--protocol blockfetch --upstream p1.example:3001 --mutation-rate 0`) sources the real honest chain from producer `p1` and serves it so the eclipsed node stays caught up to the true tip.
- **Stimulus:** `deepRollbackChainSyncServer` — once the node is caught up to the honest tip (`--rollback-min-tip`), inject **one `MsgRollBackward` exactly 10 blocks (> k) behind the served head** (`--rollback-depth 10`), then resume serving. `--rollback-repeat-secs 120` re-arms it every 2 minutes for a durable soak.
- **Oracle:** per target, the selected tip must never regress more than `k` below the maximum height it reached after an injection (a regression > k = accepted deep rollback = violation). Both implementations must behave identically.

## Result

**Both cardano-node and Amaru REFUSE the deep rollback — identically.**

| Implementation | Reaction to the 10-block (> k) rollback |
|---|---|
| cardano-node (`relay-lr`) | Refused — tip held, terminated the peer (`MsgDone`) |
| Amaru (`amaru-lr`) | Refused — tip advanced monotonically, never regressed to the 10-back target; no deep `roll_backward` in its ledger |

Soak (~3 h, complete): **91 injections into cardano-node, 92 into Amaru — 0 tip regressions, 0 divergences.** Every injection was refused by both nodes; the two implementations agreed on every cycle.

## Interpretation

On the deep-rollback regime, **the new Amaru node enforces the k-rollback safety bound exactly as cardano-node does** — a positive consensus-equivalence result. The attack concept is textbook (Ouroboros is designed to defeat long-range rollbacks); the value here is the *differential* on a from-scratch reimplementation that people will eventually run. A divergence would have been a genuine, novel finding; identical safe behavior is the reassuring outcome, and the harness is now a repeatable soak that would catch a future regression in either implementation.

## Scope

This is the **deep-rollback rejection** variant (Design Doc B / Plan A): the attacker commands a rollback deeper than k over the chain-sync protocol. It does **not** yet cover the heavier *costless-simulation* long-range variant (Plan B) — forging a *longer* validly-signed alternative chain to exercise Ouroboros Genesis's density-based chain-selection rule. That is the follow-on with the higher novelty ceiling.

## Antithesis assessment — **HIGH value, port it**

The refusal oracle maps cleanly to an `always()` SDK assertion (`selected tip never regresses > k`). Antithesis would autonomously vary rollback depth, timing, and topology far beyond the single scripted 10-block injection, driving the k-bound across both implementations.

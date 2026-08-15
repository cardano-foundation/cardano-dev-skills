# Finding — Amaru fatal crash on fast-bootstrap into a dormant epoch (`RewardsSummaryNotReady`)

**From:** DWARF devnet operations / consensus robustness (Cyber-Castellum) · **Date:** 2026-07-19
**Severity:** node-availability (a fresh/fast-bootstrapped Amaru node can enter a permanent crash
loop). **Not** a consensus-safety issue. cardano-node is unaffected.
**Confirmed:** Amaru source (`amaru-ledger` state machine) + deterministic live reproduction on the
`cardano_amaru` devnet.

## Summary

When Amaru fast-bootstraps from a snapshot bundle whose ledger tip lands at the start of an epoch
that is **dormant** (no block in that epoch's stability window), it crosses the next epoch boundary
with no rewards summary computed and dies fatally with `StateError::RewardsSummaryNotReady`
("Consensus died, this should not happen!"), then crash-loops forever because the on-disk stores
persist and it re-processes the same block on every restart.

## Root cause (code path)

`crates/amaru-ledger/src/state.rs`:

- **Rewards are computed lazily, only inside the stability window.** In `forward()` (per applied
  block): `if self.rewards_summary.is_none() && relative_slot >= stability_window { self.rewards_summary = Some(self.compute_rewards()?) }`.
  `relative_slot = slot_in_epoch(block)`; `stability_window = 3k/f` (here 75 of a 125-slot epoch).
- **The summary is consumed at the epoch boundary.** In `forward()` when `epoch_transitioning`:
  `let rewards_summary = self.rewards_summary.take();` → `epoch_transition(..., rewards_summary)`,
  which does `rewards_summary.ok_or(StateError::RewardsSummaryNotReady)?`.
- **There is no dormant-epoch fallback for rewards.** If an epoch has **no block** at
  `relative_slot >= stability_window`, the lazy compute never fires; `rewards_summary` stays `None`;
  the boundary take yields `None` → fatal error. (Amaru tracks `consecutive_dormant_epochs` for
  *governance*, but the *rewards* path has no equivalent guard.) cardano-node computes rewards at the
  boundary regardless of block presence, so it has no such failure mode.

## Live reproduction (deterministic)

On a freshly deployed `cardano_amaru` devnet (k=5, f=0.2, epochLength=125), the block producers warm
up slowly (~1 block / 24 slots initially), so an early epoch (epoch 3) was **empty**. The
bootstrap-producer built the snapshot bundle at the sparse early region (snapshots at epochs 0/1/2;
ledger tip at the epoch-2/3 boundary). Every Amaru relay then:

```
compute_stake_distribution epoch=0,1,2            # bootstrap loads the 3 bundle snapshots
epoch_transition from=3 into=4                    # first block it sees is slot 501 (epoch 4)
ERROR validate_block: rewards summary not ready point=501...
ERROR node::run: Consensus died, this should not happen!
```

`restarts` climbed without bound (crash loop). The node never processed any epoch-3 block in the
stability window (epoch 3 was empty), so it crossed 3→4 with `rewards_summary = None`.

## Fix / workaround (devnet)

**Bootstrap Amaru into the dense, steady-state region — not the sparse warm-up.** Concretely: rebuild
the snapshot bundle from the node's *current* immutable tip once the chain has matured past the
warm-up (dense epochs with blocks in every stability window), then re-bootstrap Amaru from that deep
bundle. Verified: with a bundle at epochs ~42/43/44 the Amaru relays came up with **restarts=0, zero
`Consensus died`**, where the shallow (epoch 0/1/2) bundle crash-looped.

Operational steps (this devnet): clear the `amaru-bundle` + amaru state volumes, restart the
(one-shot) `bootstrap-producer` so it rebuilds from p1's current immutable, wait for the deep bundle,
then start the Amaru relays.

## Recommendation for the Amaru team

Handle the **dormant epoch** case in the rewards path: if an epoch produced no block in its stability
window, compute (or carry forward) a valid rewards summary at the boundary rather than failing with
`RewardsSummaryNotReady`. A dormant epoch is legal on low-participation networks (and during a fresh
chain's producer warm-up); it should not be fatal. Optionally, downgrade "Consensus died" on this
path to a recoverable state rather than a crash-loop.

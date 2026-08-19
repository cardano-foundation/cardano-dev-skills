# Finding note — Amaru VRF leadership enforcement (positive) + an epoch-transition panic (for the Amaru team)

**From:** DWARF consensus differential testing (Cyber-Castellum) · **Date:** 2026-07-17
**Scope:** a novel leader-election safety test of `Amaru` vs `cardano-node` on the
upstream `cardano_amaru` devnet (`k=5`, active-slot-coeff `f=0.2`, epoch 125 slots,
Conway). One positive result and one robustness bug.

## Summary

We forged **false-leadership blocks** — blocks with a valid VRF proof but a leader
value above the active-slot threshold for the producer's stake (i.e. a slot the
producer never actually won) — and served them to both implementations. The security
question: does each node enforce the **leader-value threshold**, or does it only
check that the VRF proof verifies? A node that skips the threshold check would accept
block forgery from any stake.

**Result — Amaru enforces the threshold, exactly like `cardano-node`. No vulnerability.**

## Finding 1 (positive) — Amaru correctly enforces the VRF leadership threshold

We patched the `ouroboros-consensus-cardano` `db-synthesizer` to raise the active-slot
coefficient only inside the forger, producing blocks whose VRF proof is valid but whose
leader value is far above the real threshold (same pool/keys/window: 27 honest blocks
vs 320 forged). Served to each node:

- **`cardano-node`** (reference, fresh network sync) rejected them with
  `HeaderProtocolError … VRFLeaderValueTooBig <leaderVal> (σ) (ActiveSlotCoeff f)` and
  dropped the peer.
- **`Amaru`** rejected them with `HeaderValidationError: Insufficient leader stake` at
  the first genuinely-illegitimate block (slot 649) and adopted nothing past its
  starting tip (slot 646).

Both implementations even agree at the block level: they accept the few early slots the
producer *could* legitimately have won and reject at the first block whose leader value
exceeds the threshold. **Amaru is secure against any-stake block forgery via this path.**
This is a clean pass of a novel test — recorded here so it is on the record, not because
anything needs fixing.

## Finding 2 (robustness bug) — panic on epoch transition during forward-sync from a bootstrap snapshot

While setting the test up, we hit an Amaru crash unrelated to the leadership check. When
Amaru is bootstrapped on a chain (via `bootstrap-producer`) and then **forward-syncs
across an epoch boundary** from a peer, it panics on an internal assertion rather than
handling the condition gracefully:

```
thread 'tokio-runtime-worker' panicked at crates/amaru-ledger/src/state.rs:514:
assertion `left == right` failed: unexpected stake distribution for epoch
  left: Epoch(3)
 right: Epoch(2)
```

Observed: Amaru booted from a bundle at epoch 5 (chain tip slot 646), began applying
blocks forward from a peer, reached the epoch 4→5 reward/stake-distribution handoff, and
panicked. It reproduced on every run that crossed a boundary; we avoided it only by
confining the served blocks to a single epoch.

This looks like an off-by-one (or a boot-vs-runtime mismatch) between the stake-distribution
snapshots written by the bootstrap tooling and what the forward-sync reward machinery
expects (rewards at epoch *e* use the epoch *e-2* "go" snapshot). It is a **crash**, not a
consensus-safety divergence, but a node that panics on a normal epoch transition after a
bootstrap is a denial-of-service / availability concern worth fixing.

**Repro sketch:** bootstrap Amaru on a short devnet chain that ends mid-epoch *E*; point it
at a peer serving the same chain extended past the *E→E+1* boundary; observe the panic at
the transition. (Our exact harness — patched `db-synthesizer`, `db-truncater`, the relay,
and the bootstrap invocation — is in the evidence bundle and reusable.)

## Recommendations

1. **Finding 1:** nothing to fix — Amaru's leader-value enforcement is correct. Keep this
   test in the differential suite as a regression guard.
2. **Finding 2:** turn the `state.rs:514` assertion into a handled error (or fix the
   snapshot/epoch indexing so the assertion holds), so a bootstrapped node can forward-sync
   across epoch boundaries without panicking.
3. The harness (patched forger + real-relay serving + bootstrap + differential oracle) is
   reusable against future Amaru builds.

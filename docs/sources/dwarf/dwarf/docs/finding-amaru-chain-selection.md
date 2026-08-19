# Finding note — Amaru chain-selection behaviour (for the Amaru team)

**From:** DWARF consensus differential testing (Cyber-Castellum) · **Date:** 2026-07-17
**Scope:** cross-implementation consensus testing of `cardano-node` vs `Amaru` on the
upstream `cardano_amaru` devnet (k=5, active-slot-coeff 0.2, epoch 125 slots,
Conway at epoch 0). No exploitable divergence was found; two behavioural
differences are worth your attention.

## Summary

Across the full consensus differential suite — a 4-hour chain-selection soak (466
iterations, 0 divergences), a deep-rollback differential, and a costless-simulation
forged-fork differential — `cardano-node` and `Amaru` reached the **same
chain-selection decision every time**. That is the headline: **no consensus-safety
divergence.** Two implementation differences surfaced along the way that are not
bugs but are worth flagging.

## Finding 1 — Amaru implements Praos only; no Ouroboros Genesis

`cardano-node` can run in `GenesisMode` (LoE + GDD + CSJ + ChainSync LoP bucket) —
i.e. Ouroboros **Genesis** density-based chain-selection. We enabled it on the
devnet and confirmed it initialises and syncs.

`Amaru` shows **no Genesis support**: no consensus-mode flag, no Genesis/GDD/density
options or environment variables, and no corresponding symbols in the binary. Its
only chain-selection parameters are Praos ones (`AMARU_GLOBAL_CONSENSUS_SECURITY_PARAM`,
active-slot-coeff, KES). So the two implementations use **different chain-selection
rules**: Genesis-capable vs Praos-only.

**Why it matters.** As the Cardano network activates Ouroboros Genesis, a Praos-only
node uses the older longest-chain + k-limit rule rather than the density-based
Genesis rule. On this small devnet that difference did **not** produce a divergence
(see Finding 3 / the k-limit note), but the Genesis density rule’s distinctive
protection — defeating a long-range / eclipse attacker that offers a longer but
*sparser* chain to a **bootstrapping** node — is exactly the mainnet-scale,
many-peer scenario a devnet cannot reproduce. Worth confirming whether Genesis is
on Amaru’s roadmap.

## Finding 2 — Shallow chain-sync intersect (only ~k recent points)

On `MsgFindIntersect`, Amaru offers only its **~k most-recent** chain points. Two
consequences observed repeatedly:

1. **It cannot engage a fork that branches more than ~k blocks back** — it responds
   `intersect not found` and drops the peer. This is a conservative (safe) behaviour:
   Amaru structurally refuses deep reorgs. But it means Amaru will not even evaluate
   a deep alternative chain.
2. **It is finicky syncing from non-`cardano-node` servers.** Amaru synced cleanly
   from real `cardano-node` relays but failed to sync from the consensus tool
   `immdb-server` (handshake completes, then chain-sync resets on intersect).
   `cardano-node`, which offers intersect points geometrically deep (tip, −1, −2, −4,
   … back to the immutable tip), had no such trouble against the identical server.

`cardano-node`’s deeper intersect offers let it latch onto a fork up to k back,
evaluate it, and then reject the >k rollback — a different code path to the same safe
outcome.

## Finding 3 — Test results (both implementations agree)

- **Deep-rollback differential.** An eclipsed node is served the honest chain, then
  commanded a rollback 10 blocks (> k) behind its tip. Both `cardano-node` and
  `Amaru` **refuse** (tip never regresses > k). Soak: ~91/92 injections each, 0
  regressions.
- **Forged-fork differential.** A **real, validly-signed, longer** alternative chain
  (forged with the node’s own KES/VRF/opcert credentials via `db-synthesizer`,
  branching 20 blocks back) is served to nodes seeded at block 30520. Both **refuse**
  and keep the honest chain. (Amaru refuses via the shallow-intersect of Finding 2.)
- **Genesis vs Praos.** With `cardano-node` in GenesisMode and `Amaru` in Praos, a
  clean deterministic divergence was **not reproducible** on the 2-peer devnet: the
  **k-rollback limit is shared by both implementations and both consensus modes**, so
  it governs the deep-fork/incumbent decision regardless of Genesis vs Praos. A fork
  Amaru can engage (within k) is one GDD would not distinctively reject; a fork GDD
  would distinctively reject (deep, sparse) is one Amaru’s k-limit already refuses.
- **Eclipse datapoint.** A fresh Praos Amaru pointed only at the adversary **does
  adopt the forged chain** (it runs on the forged history) — confirming the forged
  chain is a valid, adoptable chain end-to-end. Note a Genesis node under the same
  *full* eclipse would also follow its only peer; GDD needs an honest peer to compare
  against, so this is not a divergence.

## Recommendations

1. **Confirm Genesis on the roadmap.** If mainnet activates Ouroboros Genesis, a
   Praos-only Amaru node has weaker bootstrapping/long-range protection than
   `cardano-node`. Even without a devnet-reproducible divergence, this is a
   chain-selection-rule difference between the two implementations.
2. **Review chain-sync intersect-point selection.** Consider offering intersect
   points geometrically deep (as `cardano-node` does) rather than only ~k recent
   points — it would let Amaru interoperate with a wider range of upstreams and
   evaluate (and correctly reject) deeper forks rather than dropping the peer.
3. The harness (chain-serving adversary, `db-truncater`/`db-synthesizer` forging
   pipeline, real-relay serving, differential oracle) is reusable and can be re-run
   against a Genesis-enabled, multi-peer topology if you want to probe the density
   rule at scale.

# Long-range forged-fork rejection differential (cardano-node vs Amaru)

**Harness experiment** (db-synthesizer forge + real-relay serve, not a runner-native DSL scenario) · **Run:** 2026-07-17

## What it tests

The **costless-simulation** long-range attack — the strong form. Instead of merely *commanding* a rollback (that is the S1 deep-rollback test), the attacker **forges a genuinely valid, longer alternative chain** that branches from a point > k blocks in the past, and presents it. The safety question: does an honest node adopt this real, better-looking forged history (a > k rollback), or refuse? And the differential payload: **does the new Amaru node decide identically to cardano-node?** A divergence is the finding.

## Method

- **Forge (real crypto, logical time).** Using the `ouroboros-consensus-cardano` tools already in the stack — `db-truncater` + `db-synthesizer` + `immdb-server` — copy a honest chain-db, truncate to fork point block **30500** (> k behind), then `db-synthesizer --append` with an honest operator's real KES/VRF/opcert credentials forges a validly-signed alternative continuation **in logical slot order**. This sidesteps the wall-clock/KES-exhaustion wall that defeats a live-node approach. Result: a forged fork, tip **block 30553**, forking at 30500 (53 blocks on the fork side).
- **Serve via a real cardano-node relay.** The forged fork is served by an isolated cardano-node (`attacker-relay`) seeded at the forged chain-db, with a topology that dials the victim back and `ProtocolIdleTimeout` raised to 600 s. (Amaru peers cleanly with cardano-node relays; it does not sync reliably from the `immdb-server` tool directly.)
- **Victims seeded in the past.** A cardano-node victim and an Amaru victim are each seeded on the honest chain at block **30520** — just past the fork point — so the forged fork (30553) is genuinely **longer** from their view but forks 20 blocks (> k=5) back.
- **Oracle.** Each victim must keep its honest chain at 30520 and must not adopt the fork's blocks (30521..30553). Both implementations must decide identically.

## Result

**Both cardano-node and Amaru REFUSE the forged fork — identically.**

| Implementation | Reaction to the forged, longer, > k-deep fork |
|---|---|
| cardano-node (seeded 30520) | Refused — held tip 30520, dropped the peer |
| Amaru (seeded 30520) | Refused — adopted nothing from the fork; stayed at 30520 |

**Differential verdict: AGREE. No divergence.** A validly-forged, longer alternative chain that branches > k back is rejected by both implementations.

## Behavioral observation (not a safety divergence)

The two nodes refuse via **different mechanisms**, worth flagging to the Amaru team:

- **cardano-node** offers chain-sync intersect points geometrically deep (tip, −1, −2, −4, … back to ~k and the immutable tip), so it can latch onto a fork up to k back, evaluate it, and then reject the > k rollback.
- **Amaru** offers only its ~k most-recent points on `FindIntersect` (here blocks 30516–30520, all *after* the fork point). The fork branches 20 blocks back, so none of Amaru's offered points are on it → `intersect not found` → Amaru stops chain-sync with the peer and adopts nothing.

Same safety outcome (neither performs a > k reorg), but Amaru's shallow intersect means it will not even *engage* a fork > k back. This is very likely also the root cause of Amaru's finickiness syncing from non-cardano-node servers (`immdb-server`, the `dwarf-adversary`) seen throughout this work.

## Scope caveat

This devnet runs pure **Praos** (`LoEAndGDDDisabled`, `CSJDisabled` in its config), so what is proven is the **Praos k-rollback bound against a real forged fork** — a stronger, higher-fidelity result than the S1 commanded-rollback test. It does **not** exercise Ouroboros **Genesis's density-based chain-selection** rule (which decides between deep forks by density in the genesis window). Probing that specifically requires the devnet reconfigured with LoE/GDD enabled — the follow-on.

## Pipeline (reusable)

`db-truncater` (fork point) → `db-synthesizer --append` (forge with real credentials) → real cardano-node relay (serve) → seeded-at-past victims (cardano-node + Amaru) → differential oracle. Fully built; re-runnable for other fork depths, credentials (single vs bulk), and — with LoE/GDD enabled — the Genesis density rule.

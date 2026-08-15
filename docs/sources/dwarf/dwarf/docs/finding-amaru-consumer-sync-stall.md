# Amaru consumer sync stalls against a cardano-node peer after a connection reset (mixed-net; likely #736)

**Component:** `amaru` networking / consensus consumer — chain-sync + block-fetch against a cardano-node
peer (`amaru_protocols::mux`, `amaru_protocols::manager`, `amaru_consensus::stages`).
**Type:** Liveness / robustness — Amaru silently stops advancing (does **not** crash). Not a safety issue.
**Status:** **Confirmed reproducible** on the `cardano_amaru_dwarf` mixed devnet (2× at the same logical
point). Root-caused to a peer connection reset + non-resuming consumer. **Likely the same as open upstream
`#736` (mixed-net peer sync)** — characterized here with a concrete trigger.
**Found by:** DWARF mixed-net convergence watch — an honest Amaru relay caught up to the live cardano
chain, then stopped adopting blocks.
**Date:** 2026-08-11
**Version:** Amaru `10.11.0` (lambdasistemi `pr-60`), testnet_42, k=5, peer = cardano-node relay `relay1`.

---

## Summary

An Amaru relay consuming the honest cardano chain **catches up to the peer's tip (~slot 8961), then stops
adopting** — `restarts=0`, `status=running`, **CPU ~0%** (idle, not spinning), no panic, while the cardano
peer keeps producing (observed advancing to slot 12,197+). Reproduced twice at the **same logical point**
(~slot 8961 / epoch 70→71).

## Mechanism (debug trace)

With `AMARU_LOG=debug`, the stall coincides with a **peer connection reset**:

```
DEBUG amaru_pure_stage::tokio: stage `reader-1-44`/`writer-1-43` external effect: Recv/SendEffect conn=ConnectionId(1) peer=192.168.0.5:3001
ERROR amaru_protocols::mux: failed to receive segment header from network role=responder
      err=ReceiveError on ConnectionId(1): Connection reset by peer (os error 104)
WARN  stage `reader-1-44` terminated → stage `mux-39` terminated
INFO  amaru_protocols::connection: connection child died child=Mux peer=192.168.0.5:3001 conn_id=1
INFO  manager.peer.connection_died: inbound connection died, removing peer peer=192.168.0.5
```

After this, Amaru **re-establishes a connection** (`ConnectionId(2)` seen exchanging keepalive-sized 5–8
byte frames) **but block adoption never resumes** — the node sits at the pre-reset tip indefinitely. So it
is not a permanent disconnect; it is a **chain-sync consumer that does not resume delivering blocks after
the peer connection is reset**.

The reset is `os error 104` (RST) initiated by the **cardano peer** (Amaru's `role=responder` read failed),
consistent with the cardano node dropping a mini-protocol that Amaru stopped servicing in time (e.g. a
keep-alive / chain-sync timeout), after which Amaru's consumer side wedges.

## Why it matters

- A mixed Haskell+Amaru network does **not stay converged**: the Amaru node freezes at a fixed tip while
  cardano advances, with no error surfaced — an operator sees a "running" container that is silently
  stuck. (A tip-only oracle that only checks for crashes would miss it; a *liveness* oracle catches it.)
- This is very likely the concrete face of the **open upstream issue #736** (Amaru consuming from
  cardano-node in a mixed net). DWARF adds the trigger (peer RST → consumer does not resume).

## Reproduction

1. `cardano_amaru_dwarf` mixed devnet; fresh-bootstrap an Amaru relay peering a cardano relay
   (`--peer-address relay1.example:3001`), `AMARU_LOG=debug`.
2. Let it catch up to the peer tip. Within ~1–2 min it stops adopting; debug log shows
   `Connection reset by peer (os error 104)` on the peer connection, `connection died / removing peer`,
   then a re-connect that does not resume block delivery.
3. Node stays at the stalled tip (CPU ~0%) while the cardano peer keeps producing.

## Distinct from the restart crash

This is the **live-sync** stall (silent, no restart involved). The **restart-recovery crash**
(`RollbackPointInFuture` → "Consensus died") is a separate failure —
see `finding-amaru-restart-rollback-in-future-crash.md`. They can compound: a stalled node that is then
restarted hits the restart crash.

## Open

1. Confirm whether the reset originates from a cardano-node mini-protocol timeout (Amaru not servicing
   keep-alive/chain-sync in time) vs. an Amaru-side send stall — needs matching cardano-node trace.
2. Confirm identity with upstream `#736`.

# Adversary roadmap

Long-term plan for adversarial workload against the testnet. The
[adversary component][adversary-doc] is a single-shot CLI per
Antithesis tick (see Tier 1.1 below); this page tracks where it goes
next.

## Status

| Tier | Archetype | Status |
|---|---|---|
| 1.1 | `chain_sync_flap` | **landed** ([PR #110][pr-110]) |
| 1.2 | `chain_sync_thrash` | not started |
| 1.3 | `chain_sync_slow_loris` | not started |
| 2 | `block_fetch_replay`, `tx_submission_*`, `keepalive_abuse` | not started |
| 3 | upstream-peer Byzantine adversary | epic [#91][issue-91], not started |
| 4 | `lsq_flood`, `local_tx_submission_garbage` | not started |

## Goals

1. **Cover more of the protocol surface than chain-sync.**
   `chain_sync_flap` lives; `chain_sync_thrash` and slow-loris next;
   then block-fetch, tx-submission, keep-alive, handshake, and
   upstream (responder).
2. **Steer adversarial choices with the Antithesis hypervisor.** ✅
   The driver shell calls `antithesis_random` and passes the seed to
   the binary as `--seed`. The binary splits the seed to pick both
   target host and chain point uniformly. Antithesis can replay any
   run by re-seeding.
3. **Each archetype is one binary + one driver, not one endpoint.**
   The CLI-per-tick model makes archetypes additive: a new attack
   adds a new CLI under `components/adversary/` (or a sibling), a new
   driver script `parallel_driver_<name>.sh`, and an entry in the
   composer-discovered `/opt/antithesis/test/v1/` tree of the
   adversary container. No daemon endpoint to register, no wire
   spec to extend.

## Architecture

```
       Antithesis composer
       (sole scheduler)
              |
              | docker exec per tick
              v
+----------------------------------------+
|   adversary container                  |
|   (sleep -f /dev/null)                 |
|                                        |
|   /opt/antithesis/test/v1/             |
|     chain-sync-client/                 |
|       parallel_driver_flap.sh -------- (seeded by antithesis_random)
|     <future-archetype>/                |
|       parallel_driver_*.sh             |
|                                        |
|   /bin/cardano-adversary               |
|   /bin/<future-archetype-binary>       |
+----------------------------------------+
              |
              | initiator-only N2N
              v
       p1 / p2 / p3 / relay1 / relay2
```

### Where each archetype lives

A new archetype lands as:

- a Haskell binary in `components/adversary/` (or a sibling component
  if it shares no code with the existing CLI),
- a single composer driver
  `components/adversary/composer/<bucket>/parallel_driver_<name>.sh`,
- an entry in `components/adversary/nix/docker-image.nix`'s
  `antithesis-assets` so the driver is baked into the image,
- if the archetype assertion can be observed by the cluster sidecar:
  a check in `components/sidecar/composer/`. Otherwise the binary
  emits its own SDK assertion via `$ANTITHESIS_OUTPUT_DIR/sdk.jsonl`.

The convergence sidecar (`finally_tips_agree.sh`,
`eventually_converged.sh`) is the canonical "did the cluster stay
healthy" oracle across all archetypes — that's the test that caught
the regression which drove the CLI-per-tick rewrite.

## Tier list of misbehaviour archetypes

Each archetype = one CLI + one driver + a documented invariant the
cluster must preserve under it. Order is implementation order,
easiest first.

### Tier 1 — chain-sync stress

1. **`chain_sync_flap`** ✅ — pick random target, random intersection
   point, sync `--limit` headers, disconnect. Composer fires it
   under fault injection.
2. **`chain_sync_thrash`** — same connection, repeatedly
   `MsgFindIntersect` to a different random point without completing
   the sync. Stresses the producer's intersection-finding cache.
3. **`chain_sync_slow_loris`** — open the connection, complete
   handshake, then send `MsgRequestNext` at a deliberately slow
   cadence; assert the connection is kept alive (or assert it gets
   evicted, whichever the protocol promises).

### Tier 2 — other mini-protocols, downstream side

4. **`block_fetch_replay`** — `BlockFetch` client that requests
   already-fetched ranges back-to-back, plus ranges straddling
   rollback boundaries.
5. **`tx_submission_flood`** — N2N `TxSubmission2` client that
   announces tx-ids the producer has not requested, or refuses to
   deliver bodies after announcing them.
6. **`tx_submission_garbage`** — submits well-formed-CBOR but
   ledger-invalid txs at high rate (mempool pressure).
7. **`keepalive_abuse`** — `KeepAlive` cookies out of order or never
   replied to.

### Tier 3 — upstream-peer mode (the canonical Byzantine peer)

Tracked as its own epic ([#91][issue-91]). Cluster nodes must dial
the adversary, so the adversary becomes a node-to-node *server*.
Then:

8. **`upstream_fork_serve`** — announce a tip on the honest chain's
   history but `MsgRollForward` with a fabricated header. ChainSel
   must discard.
9. **`upstream_equivocate`** — serve two contradictory headers at
   the same slot to two peers.
10. **`upstream_too_far_ahead`** — announce a tip 10× past the real
    tip; producer must not fetch.
11. **`upstream_long_rollback`** — induce a rollback past *k* and
    verify the honest peer rejects.

Tier 3 needs a topology change (relays peer with adversary in their
`topology.json`) and a different image shape (the adversary needs
to listen for inbound connections, not sleep). It is a separate
testnet variant; it does not disturb the current
`cardano_node_adversary` testnet.

### Tier 4 — N2C abuse (lower priority)

12. **`lsq_flood`** — open many `LocalStateQuery` sessions against a
    relay, hold them.
13. **`local_tx_submission_garbage`** — N2C variant of #6.

## What's behind us

The original adversary was a one-shot Haskell binary running inside
the `sidecar` container; it was lifted into a long-running daemon in
`lambdasistemi/cardano-node-clients` (NDJSON over UNIX socket). The
daemon had a structural targeting bias and added a chaos target with
no benefit, so it was retired and the model returned to a CLI per
tick — but now in its own container with explicit `--target-host`
fan-out and `--seed`-driven random pick.

Sequence of PRs that got us here:

| # | Repo | Description | Status |
|---|---|---|---|
| A | antithesis | Refresh adversary docs, publish the original roadmap | ✅ [#88][pr-88] |
| B | clients | Scaffold daemon (now retired) | ✅ [#103][pr-103] |
| C | clients | `chain_sync_flap` daemon endpoint (now retired) | ✅ [#106][pr-106] |
| D | antithesis | Switch to consuming the daemon image (now reverted) | ✅ [#99][pr-99] |
| E | antithesis | **Redesign**: kill the daemon, CLI per tick, new testnet | ✅ [#110][pr-110] |
| F | clients | Delete the orphaned daemon source + spec | [#122][pr-122] |

## Tickets

Filed in [`cardano-foundation/cardano-node-antithesis`][repo]:

- ✅ [#87][issue-87] — refresh adversary docs (closed by PR #88).
- ✅ [#89][issue-89] — adversary daemon epic (closed by PR #110;
  superseded — the daemon model was retired).
- ✅ [#90][issue-90] — switch to consuming the daemon image (closed by
  PR #99; subsequently undone).
- [#91][issue-91] — Tier 3 upstream-peer epic.
- ✅ [#9][issue-9] — chain-sync driver should never fail (closed by
  PR #110).

Filed in [`lambdasistemi/cardano-node-clients`][cnc]:

- ✅ [#102][cli-102] — daemon scaffold (closed by PR #103, source
  removed by PR #122).
- ✅ [#104][cli-104] — `chain_sync_flap` daemon endpoint (closed by
  PR #106, source removed by PR #122).



[adversary-doc]: adversary.md
[cnc]: https://github.com/lambdasistemi/cardano-node-clients
[repo]: https://github.com/cardano-foundation/cardano-node-antithesis
[pr-88]: https://github.com/cardano-foundation/cardano-node-antithesis/pull/88
[pr-99]: https://github.com/cardano-foundation/cardano-node-antithesis/pull/99
[pr-103]: https://github.com/lambdasistemi/cardano-node-clients/pull/103
[pr-106]: https://github.com/lambdasistemi/cardano-node-clients/pull/106
[pr-110]: https://github.com/cardano-foundation/cardano-node-antithesis/pull/110
[pr-122]: https://github.com/lambdasistemi/cardano-node-clients/pull/122
[issue-9]: https://github.com/cardano-foundation/cardano-node-antithesis/issues/9
[issue-87]: https://github.com/cardano-foundation/cardano-node-antithesis/issues/87
[issue-89]: https://github.com/cardano-foundation/cardano-node-antithesis/issues/89
[issue-90]: https://github.com/cardano-foundation/cardano-node-antithesis/issues/90
[issue-91]: https://github.com/cardano-foundation/cardano-node-antithesis/issues/91
[cli-102]: https://github.com/lambdasistemi/cardano-node-clients/issues/102
[cli-104]: https://github.com/lambdasistemi/cardano-node-clients/issues/104

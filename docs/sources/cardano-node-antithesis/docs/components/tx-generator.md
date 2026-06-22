# Tx-generator

Long-running, externally-triggered fan-out daemon that drives
deterministic UTxO and address pressure on a Cardano cluster, designed
for Antithesis. Replaces the original Python tx-generator
([cardano-foundation/cardano-node-antithesis#69](https://github.com/cardano-foundation/cardano-node-antithesis/issues/69))
which queried the relay's local-state-query channel on every submission
and self-drained UTxOs to dust.

## Role

The daemon owns a master seed and grows a population of HD-derived
addresses monotonically across the run. Each composer tick fires one
*request* (transact or refill); the daemon performs **exactly one**
transaction using the request's seed as its only source of randomness.
Without an external trigger, the daemon is idle.

This shape is the contract:

- **Composer is the clock.** No internal pacing, no internal RNG, no
  timer-driven submission.
- **Determinism.** Given identical persistent state and identical
  request payload, the daemon's behaviour is bit-identical: same
  source picked, same destinations picked, same per-output values,
  same submitted transaction id. This is what makes Antithesis
  replays reproducible.
- **Population grows monotonically.** Per `transact` request, with
  probability `prob_fresh` per output slot a new HD address is
  derived; otherwise an existing population member is sampled.
  Net effect per transaction: population grows by `K · prob_fresh`
  on average, total UTxO count grows by K, mean UTxO value drifts
  toward the Conway minUtxo floor.

## Image

`ghcr.io/cardano-foundation/cardano-node-antithesis/tx-generator:<commit>`

The compose tag is a *downstream* commit SHA — `publish-images.sh`
clones `cardano-node-antithesis`, checks out that commit, and builds
the docker image from `components/tx-generator/` at that point. The
upstream daemon source is pinned via Nix in
`components/tx-generator/flake.nix` (`github:lambdasistemi/cardano-node-clients/<sha>`).

## Configuration

CLI args (translated by `entrypoint.sh` into the daemon binary):

| flag                    | meaning                                                              |
|-------------------------|----------------------------------------------------------------------|
| `--relay-socket`        | Path to the cardano-node N2C socket (one socket, one connection).    |
| `--control-socket`      | Path of the NDJSON Unix socket the daemon will create and listen on. |
| `--state-dir`           | On-disk persistent state: `master.seed` (32 B) + `nextHDIndex`.      |
| `--master-seed-file`    | Optional override; otherwise generated on first boot.                |
| `--faucet-skey-file`    | Faucet signing key. `entrypoint.sh` accepts a TextEnvelope JSON and rewrites it to the raw 32-byte seed the daemon expects. |
| `--network-magic`       | Network magic (42 on this testnet).                                  |

Composer-side environment:

| var                | meaning                                | default |
|--------------------|----------------------------------------|---------|
| `TX_GEN_FANOUT`    | K — number of explicit destinations per transact tx | 6   |
| `TX_GEN_PROB_FRESH`| Probability each destination slot is a freshly-derived address | 0.5 |
| `CONTROL_SOCKET`   | Path to the daemon's control socket    | `/state/tx-generator-control.sock` |

## Topology inside the container

The daemon opens **exactly one** N2C connection to the relay it's
configured against and multiplexes every Ouroboros mini-protocol over
that single bearer:

- ChainSync — feeds the in-process address-to-UTxO indexer.
- LocalStateQuery — `GetUTxOByTxIn` for the pre-submit chain-tip probe.
- LocalTxSubmission — submits the built tx.

The address-to-UTxO indexer is the in-tree
[`cardano-node-clients` indexer library](https://github.com/lambdasistemi/cardano-node-clients/tree/main/lib/Cardano/Node/Client/UTxOIndexer)
embedded in-process; the daemon does NOT query the relay's LSQ for
per-address UTxOs (that was the bug the original Python generator hit).

## Wire protocol — control socket

NDJSON over Unix socket. One request per line, one response per line.
Schema (canonical):
[`specs/034-cardano-tx-generator/contracts/control-wire.md`](https://github.com/lambdasistemi/cardano-node-clients/blob/main/specs/034-cardano-tx-generator/contracts/control-wire.md).

Request kinds:

- `{"transact":{"seed":<u64>,"fanout":<int>,"prob_fresh":<float>}}` —
  build and submit one transaction.
- `{"refill":{"seed":<u64>}}` — bootstrap or top-up: pull from the
  faucet into a freshly-derived population address.
- `{"snapshot":null}` — read-only: returns population size, percentile
  cuts of the UTxO value distribution, current tip slot, and
  `lastTxId`. Used by `eventually_population_grew.sh` and
  `eventually_pressure_summary.sh`.
- `{"ready":null}` — read-only: returns indexer-ready and
  faucet-known flags.

Response shape per arm uses one of:

- `Ok` (success).
- `IndexNotReady` (transient — composer retries on next tick).
- `NoPickableSource` (transact-only, no population member has a
  viable UTxO — refill arm should fire first).
- `SubmitRejected` (hard failure — surfaces as the
  `tx_generator_*_submit_rejected` Always assertion).

## Per-request flow

### `transact`

1. Sample a source address uniformly from the existing population
   using the request's seed.
2. Query the in-process indexer for that address's UTxOs. Apply the
   K-output viability floor; if no source meets it, retry up to N
   times with the same RNG stream and on cap respond
   `NoPickableSource`.
3. For each of K output slots: with probability `prob_fresh` derive
   a new HD address and use it as destination; otherwise sample an
   existing population member.
4. Build the tx (one input from the picked source; K outputs at
   randomly-drawn values within the viable range; one change output
   back to the source).
5. **Pre-submit probe**: `GetUTxOByTxIn` on the picked input via LSQ
   against the chain tip. If the relay no longer sees that input as
   unspent (e.g. mid-rollback) → `IndexNotReady`.
6. Submit via LocalTxSubmission.
7. **Post-submit recovery**:
    - `Submitted txId` → await the change-output on the indexer with
      bounded timeout; respond `Ok` with `awaited:bool`.
    - `Rejected "already been included"` → the deterministic txId
      may have been accepted on a prior submit (think bearer close
      mid-submit, or a rolled-back fork on which the daemon submitted
      earlier). Await the change-output. On observation: `Ok`. On
      timeout: `IndexNotReady` (transient — composer retries; on the
      next tick the rebuilt tx will spend a different post-rollback
      input and submit cleanly).
    - `ConnectionLost` (bearer died mid-submit) is caught at the
      outer arm seam and surfaces as `IndexNotReady`.

### `refill`

Same five-step shape as transact, with three differences:

- Source is the *faucet* address.
- Destination is **always** a freshly-derived population address.
- Recovery branch handles both `ConnectionLost` and "already-included"
  rejections (refills always reuse the same faucet input across
  retries, so duplicate-submit recovery is structurally required).

## Reconnect resilience

The daemon survives every fault Antithesis injects without dying. The
machinery (upstream PRs):

- **#105** — `runReconnectLoop` supervisor with exponential-backoff
  retry, plus `BlockedIndefinitelyOnSTM → ConnectionLost` catch in
  `submitTxN2C` and `queryLSQ` so the GHC RTS deadlock detector can't
  tear the daemon down on a bearer close.
- **#110** — post-reconnect indexer freshness gate. After a reconnect
  the daemon refuses to query/submit until ChainSync has seen its
  first fresh block on the new bearer.
- **#114** — pre-submit chain-tip probe (`GetUTxOByTxIn`) to catch
  the simple "input already spent" case before bothering the relay.
- **#115** — post-submit duplicate-submit recovery on the refill arm
  (await the change-output on `ConnectionLost` or "already-included"
  rejection).
- **#116** — recovery-await timeout aligned to
  `dcAwaitTimeoutSeconds` (30s) — same window the happy path has.
- **#117** — recovery-await *timeout* on the refill arm classified as
  `IndexNotReady` rather than `SubmitRejected`. The carrying block
  was almost certainly rolled back; the next tick will rebuild
  against the post-rollback faucet input.
- **#118** — same recovery shape applied to the transact arm.

## Composer scripts

In `components/tx-generator/composer/tx-generator/`:

| script                                | role                                                                                       |
|---------------------------------------|--------------------------------------------------------------------------------------------|
| `parallel_driver_transact.sh`         | Fires one `transact` request per tick.                                                     |
| `parallel_driver_refill.sh`           | Fires one `refill` request per tick (lower composer weight than transact).                 |
| `eventually_population_grew.sh`       | Snapshots populationSize and asserts `Sometimes` it has grown. Gated on `lastTxId` being non-null so the assertion never fires before any tx has been attempted. |
| `eventually_pressure_summary.sh`      | Post-workload pressure summary (population size + UTxO value percentiles + tip slot).      |
| `helper_sdk_lib.sh`                   | Shared SDK helpers: `sdk_reachable`, `sdk_sometimes`, `sdk_unreachable`. All scripts source this. |

All composer scripts use `set -u` (NOT `set -e`) and **always exit 0**.
Antithesis's built-in *Commands finish with zero exit code* property
has no opt-out, and the daemon's control socket isn't bound during
early boot — `nc -U` against an unbound socket returns non-zero, and
`set -e` would kill the script before any exit-0 path runs. Tick state
is encoded purely via SDK assertions.

## Persistent state

In `--state-dir` (default `/state/txgen`):

- `master.seed` — 32-byte raw seed. Set on first boot from
  `--master-seed-file` (or freshly generated if absent). Never
  rewritten.
- `nextHDIndex` — single integer. Bumped on each successful transact
  / refill that derived a fresh address. **Only written on
  successful submission paths** (including recovery-await observation);
  on `IndexNotReady` / `SubmitRejected` the index is preserved so the
  next request rebuilds against the same state.

Crash-restart is idempotent: the daemon reads `master.seed` +
`nextHDIndex`, replays HD derivation, and resumes.

## Failure modes & assertions

The composer assertions surface two classes of finding:

1. **Hard failures** — Always-style: should never fire.
    - `tx_generator_refill_submit_rejected`
    - `tx_generator_transact_submit_rejected`

    These mean the relay rejected a deterministically-built submission
    with something other than the recoverable
    "already been included" — i.e. genuine ledger / fee / size error.

2. **Reachability** — informational:
    - `tx_generator_*_driver_started`
    - `tx_generator_*_landed`
    - `tx_generator_*_not_applicable` (e.g. `NoPickableSource`)
    - `tx_generator_*_daemon_unreachable` (early-boot, control socket
      not yet bound)
    - `tx_generator_population_grew` (Sometimes — gated)
    - `tx_generator_pressure_summary` (Reachability at run-end)

## Validation evidence

The tx-generator image promoted to
[`cardano_node_master`](../testnets/cardano-node-master.md) is
`tx-generator:69bf815`, referenced from downstream commit `4687a09`.
It was validated on a dedicated `cardano_node_tx_generator` testnet
before promotion (since removed; the workload now lives directly in
`cardano_node_master`).

| Evidence | Value |
|----------|-------|
| Antithesis test run | `9352ad089c67523bc2ba2c14d1d18b5b39b24f49797c640214eaf375abf74944` |
| Triage report id | `OSIShLbA8Ixh6uRxqDdjWdtr` |
| GitHub workflow | `25377129832` |
| Started | `2026-05-05 12:48 UTC` |
| Requested duration | `60m` |
| Reported wall clock | `1h 7m` |
| Reported test hours | `48h 0m` |
| Properties | `40/40` passed |
| Findings | `0 new`, `0 ongoing`, `0 resolved`, `0 rare` |

The validation run used the same shared image set as the adjacent
`cardano_node_master` run `8ca5bdd583...` from `2026-05-05 12:42 UTC`:
the same `configurator`, `log-tailer`, `sidecar`, `tracer-sidecar`,
`cardano-node`, and `cardano-tracer` images. The expected differences
were that the tx-generator run added `tx-generator:69bf815`, while the
master run included `asteria-game:f7ce4a2`.

The four previous composer zero-exit findings were all cleared:

| Composer command | Passing hits | Failing hits |
|------------------|--------------|--------------|
| `tx-generator/parallel_driver_transact.sh` | `5,288` | `0` |
| `tx-generator/parallel_driver_refill.sh` | `3,506` | `0` |
| `tx-generator/eventually_population_grew.sh` | `1,448` | `0` |
| `tx-generator/finally_pressure_summary.sh` | `413` | `0` |

Measured workload pressure in that run:

| Measurement | Value |
|-------------|-------|
| `parallel_driver_transact.sh` starts | `5,709` |
| `parallel_driver_refill.sh` starts | `4,597` |
| `eventually_population_grew.sh` starts | `1,412` |
| `finally_pressure_summary.sh` starts | `413` |
| Max commands running concurrently | `12` |
| Total virtual hours | `335.301` |
| Virtual seconds per input | `0.743665` |
| `tx_generator_population_grew` hits | `166` |
| `tx_generator_refill_landed` hits | `43` |

The `tx_generator_pressure_summary` property passed with `413` hits and
`0` failing. The report exposes one exemplar snapshot:

```json
{
  "lastTxId": null,
  "p10_lovelace": null,
  "p50_lovelace": null,
  "p90_lovelace": null,
  "populationSize": 0,
  "tipSlot": 61
}
```

That exemplar is a point-in-time SDK example selected by Antithesis;
the workload properties above show that population growth and refill
landing were observed elsewhere in the same run.

## Source

- Daemon: <https://github.com/lambdasistemi/cardano-node-clients>
  (package `cardano-tx-generator`, library `lib/Cardano/Node/Client/TxGenerator/`).
- Container scaffold: `components/tx-generator/`.
- Composer scripts: `components/tx-generator/composer/tx-generator/`.
- Wire schema (canonical):
  <https://github.com/lambdasistemi/cardano-node-clients/blob/main/specs/034-cardano-tx-generator/contracts/control-wire.md>.

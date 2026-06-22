# Cardano Node Master

A mixed-version Cardano testnet for Antithesis fault-injection testing.

## Overview

This testnet exercises the node-to-node protocol across multiple cardano-node versions:

- **4 block producers**: p1 (10.5.3), p2 (10.6.2), p3 (10.7.1), p4 (11.0.1) — forge blocks in a ring topology (p1↔p2↔p3↔p4)
- **3 relay nodes**: relay1 (10.6.2), relay2 (10.7.1), relay3 (11.0.1) — non-producing nodes connected to all producers

### Supporting services

| Service | Role |
|---------|------|
| **configurator** | Generates genesis files, node configs, and signing keys at startup |
| **tracer** | cardano-tracer daemon collecting structured logs from all nodes |
| **tracer-sidecar** | Processes tracer logs into Antithesis assertions (chain convergence, error detection) |
| **sidecar** | Network health checks, the Antithesis setup signal, and the host of the chain-sync `adversary` driver (see [Adversary](../components/adversary.md)). |
| **log-tailer** | Streams the per-pool node logs into Antithesis's log explorer for offline triage. |
| **asteria-game** | Single container that hosts the long-lived utxo-indexer plus three short-lived binaries (`asteria-bootstrap`, `asteria-game`, `asteria-invariant`) fired by composer scripts. See [Why asteria-game is here](#why-asteria-game-is-here) below and [Asteria Game](../components/asteria-player.md). |
| **tx-generator** | Long-running daemon that submits well-formed ADA transfers through relay1's N2C socket. Composer drivers fire deterministic `transact`, `refill`, `eventually`, and `finally` control-socket probes. See [Why tx-generator is here](#why-tx-generator-is-here) below and [Tx-generator](../components/tx-generator.md). |

## Why asteria-game is here

Antithesis can only find bugs that the system **actually exercises** in
the simulation. A cluster running idle — three producers minting empty
blocks — explores almost nothing of the node's tx-handling code:
mempool admission, script evaluation, ledger validation under
contention, fork resolution while inputs are being consumed. Faults
fired against an idle cluster mostly prove that the cluster restarts.

The asteria-game container is the **workload generator** that turns
master into a *busy* testnet. Without it, the cluster has no
realistic tx pressure. With it, the cluster sees the full envelope:

- **`parallel_driver_asteria_player.sh`** — fired concurrently by the
  composer many times per timeline. Each invocation reads the asteria
  UTxO from chain via the long-lived utxo-indexer, plans a move, and
  for player-1 builds + signs + submits a `spawnShip` Plutus
  transaction (consume asteria → mint a `SHIP*` token → write to the
  spacetime address → produce the next asteria UTxO with
  `ship_counter += 1`). Player-2 and player-3 run the same observe
  + plan path without acting, exercising the read side.
- **`serial_driver_asteria_bootstrap.sh`** — exclusive-access driver
  that idempotently re-deploys the validators and admin NFT each
  invocation. Re-runs detect the existing state via the indexer and
  skip the mint, exercising the "is already deployed" path under
  fault injection.
- **`anytime_asteria_admin_singleton.sh`** — periodic invariant
  probe. Asserts (via `sdk_always`) that exactly one `asteriaAdmin`
  NFT exists at the asteria spend address — the one-shot mint
  policy must hold under any combination of forks, kills, and
  partitions.
- **`eventually_asteria_consistency.sh`** — post-workload consistency
  snapshot. `ship_counter` on the asteria UTxO must equal the count
  of `SHIP*` tokens at the spacetime address.
- **`eventually_alive.sh`** — short liveness probe against the
  indexer's `ready` endpoint.

What this gives Antithesis to score:

- **Tx-build pressure under faults**. The player driver builds, signs,
  and submits real Plutus transactions concurrently with fault
  injection. Validation: a 1h validation run on
  [PR #128][pr-128] saw 22,990 player invocations,
  2,599 successful spawn-ship transactions landing on chain, and 149
  observed fork switches during the run.
- **Plutus-script ledger paths**. The validators (asteria.spend,
  spacetime.spend, shipyard.mint) execute on every ship spawn —
  exercises ref-input handling, datum decoding, redeemer validation,
  exec-budget accounting.
- **Multi-version interop**. Producers p1/p2/p3/p4 run four different
  cardano-node versions; the same Plutus tx must validate identically
  across versions or the cluster forks.
- **Invariants that survive faults**. `asteria_admin_singleton`
  (sdkAlways) and `asteria_state_consistent` (sdkSometimes) provide
  oracle properties Antithesis can falsify if a fault produces a
  divergent view, a double-mint, or a lost ship.

The container is the **load + oracle** of the test. Its image is
pinned by SHA in `docker-compose.yaml`; building it locally goes
through `components/asteria-game/`. The composer scripts that drive
it live alongside the binaries in `components/asteria-game/composer/asteria-game/`
and are baked into the image at build time.

For the architectural detail of how the binaries integrate with
`cardano-node-clients` (provider, submitter, indexer, TxBuild DSL,
fee bisection), see [Asteria Game](../components/asteria-player.md).

## Why tx-generator is here

`asteria-game` gives master Plutus-heavy script traffic. The
tx-generator adds a complementary ADA-only workload: many simple,
well-formed UTxO fan-out transactions that put pressure on mempool
admission, ledger validation, rollback handling, and node-to-client
submission without depending on Plutus execution.

The service is deliberately composer-driven. The daemon is idle until
Antithesis fires a short command:

- **`parallel_driver_transact.sh`** - requests one deterministic
  fan-out transaction from an existing population address.
- **`parallel_driver_refill.sh`** - requests one faucet-funded top-up
  into a fresh population address.
- **`eventually_population_grew.sh`** - snapshots the daemon state and
  asserts that a populated address set was observed.
- **`eventually_pressure_summary.sh`** - emits a post-workload snapshot
  with population size, UTxO value percentiles, tip slot, and last tx id.

Why this belongs in the production-baseline testnet:

- **Independent transaction pressure.** It continues driving ordinary
  ADA transfers even when the Plutus workload is faulted, not yet
  bootstrapped, or waiting on an invariant window.
- **Replayable pressure.** Every command carries its own seed; with the
  same persistent state and request payload, the daemon rebuilds the
  same transaction. That makes Antithesis examples reproducible.
- **N2C resilience surface.** The daemon maintains one multiplexed N2C
  bearer to relay1 for ChainSync, LocalStateQuery, and
  LocalTxSubmission. Relay restarts and network faults exercise the
  reconnect and duplicate-submit recovery logic.
- **Oracle properties.** Hard failures surface as
  `tx_generator_*_submit_rejected`; liveness and pressure are scored
  through `tx_generator_population_grew`,
  `tx_generator_refill_landed`, and `tx_generator_pressure_summary`.

### Promotion evidence

The image promoted here is `tx-generator:69bf815`, referenced from
downstream commit `4687a09`. It was validated on a sibling
`cardano_node_tx_generator` testnet before promotion (since removed;
the workload now lives directly in this testnet).

| Evidence | Value |
|----------|-------|
| Antithesis test run | `9352ad089c67523bc2ba2c14d1d18b5b39b24f49797c640214eaf375abf74944` |
| Triage report id | `OSIShLbA8Ixh6uRxqDdjWdtr` |
| Started | `2026-05-05 12:48 UTC` |
| Properties | `40/40` passed |
| Findings | `0 new`, `0 ongoing`, `0 resolved`, `0 rare` |

Shared images were checked against the nearest completed
`cardano_node_master` run (`8ca5bdd583...`, started
`2026-05-05 12:42 UTC`). The `configurator`, `log-tailer`,
`sidecar`, `tracer-sidecar`, `cardano-node`, and `cardano-tracer`
images matched. The expected workload-specific differences were
`tx-generator:69bf815` in the tx-generator validation run and
`asteria-game:f7ce4a2` in master.

The validation run also cleared the four previous tx-generator
composer zero-exit findings:

| Composer command | Passing hits | Failing hits |
|------------------|--------------|--------------|
| `tx-generator/parallel_driver_transact.sh` | `5,288` | `0` |
| `tx-generator/parallel_driver_refill.sh` | `3,506` | `0` |
| `tx-generator/eventually_population_grew.sh` | `1,448` | `0` |
| `tx-generator/finally_pressure_summary.sh` | `413` | `0` |

Measured pressure in that run:

| Measurement | Value |
|-------------|-------|
| Transact-driver starts | `5,709` |
| Refill-driver starts | `4,597` |
| Max concurrent composer commands | `12` |
| Total virtual hours | `335.301` |
| Virtual seconds per input | `0.743665` |
| `tx_generator_population_grew` hits | `166` |
| `tx_generator_refill_landed` hits | `43` |
| `tx_generator_pressure_summary` hits | `413` |

## Network topology

```
p1 (10.5.3) ←→ p2 (10.6.2) ←→ p3 (10.7.1) ←→ p4 (11.0.1) ←→ p1
   ↑                ↑               ↑               ↑
relay1 (10.6.2) ----+---------------+---------------+
relay2 (10.7.1) ----+---------------+---------------+
relay3 (11.0.1) ----+---------------+---------------+
```

Producers form a ring. Relays connect to all producers.

## Configuration

- `testnet.yaml`: Genesis parameters (poolCount, networkMagic 42, epoch length, protocol version)
- `docker-compose.yaml`: Full topology definition with YAML anchors for producers and relays
- `relay-topology.json`: Shared topology for relay nodes (connects to all producers)
- `tracer-config.yaml`: cardano-tracer log forwarding configuration

## Running locally

```bash
# Start the testnet
just up

# Check container status
just ps

# View tracer-sidecar logs (chain progress)
just logs tracer-sidecar

# Stop and clean up
just down
```

## Version strategy

Older node versions get fewer instances, newer versions get more. Relay nodes always run recent versions since they are the public-facing nodes that dApps and ecosystem tools connect to.

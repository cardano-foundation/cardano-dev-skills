# Resource-Abuse Testing Plan (Milestone 2)

Status: **v1 plan + first executions** — 2026-04-19. Authored to satisfy the Milestone 2 (M2) deliverable "Resource-abuse testing plan and first executions for random-access memory (RAM), disk, and sync abuse" (`user/milestones/contract-milestones-tasklist.md`).

## Scope

Resource-abuse testing measures how Cardano node implementations behave when host resources — memory, disk, network bandwidth, file descriptors, peer connections — are pushed toward saturation, partially withheld, or filled by an adversary. The goal is not to prove correctness under load (that's covered by IOG/PRAGMA's own benchmark suites and mainnet replay). The goal is to produce **reproducible, tamper-evident evidence** of behavior at the boundaries where production failures occur, so security findings can be cited and replayed by anyone.

In scope for M2 first executions:

- **Process-level resource baselines** — resident set size (RSS), virtual memory size (VSZ), central processing unit (CPU), file-descriptor counts of running cardano-node processes on a real devnet, captured as forensic bundles.
- **Time-series RSS sampling** — RSS-over-time for each devnet node so memory growth or leak signatures become visible.
- **Host disk-fill smoke** — controlled `dd` against a temp directory to validate the disk-fill measurement path before pointing it at node data directories.

## Methodology

Every resource-abuse scenario runs through the Dwarf framework (`dwarf/`) and produces a forensic bundle:

```
runs/<run-id>/
  scenario.yaml         (the exact scenario executed)
  manifest.json         (ids, hashes, timestamps, env)
  log.ndjson            (per-iteration / per-step events)
  outputs/              (captured stdout, stderr, command line)
  probes/               (probe samples if any)
  assertions.json       (assertion results)
  chain.json            (sha256 chain entry)
```

Bundles are forensically chained: tampering with any historical entry is detectable by re-walking the chain. Replay (`cardano-profile replay <run-id>`) re-executes the same scenario with the same seed and produces a byte-identical bundle (modulo wall-clock). Verify (`cardano-profile verify <run-id>`) walks the chain.

Primitives used in this first pass:

- **`load_shell_command`** (new in M2 v3) — runs a host shell command with timeout, captures stdout/stderr/exit code into the bundle. Used to drive `ps`, `dd`, `df`, `free`, and similar host tools without requiring docker primitives.
- **`process_rss`** (existing, slice 13) — samples RSS for processes started under `start_node_process`. Reserved for scenarios that own the lifecycle of the node process.

Primitives reserved for later phases (already implemented but require docker- or container-mode targets):

- `disk_fill` — `dd` inside a target container.
- `sync_replay` — wipe DB + restart container.
- `fault_delay` / `fault_drop` / `fault_partition` — netem / iptables faults inside containers.

## First executions (M2 v3)

Three scenarios, all executed on `the Linux target host` against the running 3-node devnet (`profile-a-haskell-peersharing-disabled`):

| Scenario | Purpose | Bundle id |
|---|---|---|
| `resource-baseline-cardano-nodes` | Single-shot snapshot of `ps`, `free`, `df`, devnet data-dir size — establishes baseline for what "normal" looks like. | (filled in once executed; see `dwarf-fw/runs/`) |
| `resource-rss-time-series-cardano-nodes` | 60 RSS samples at 1 Hz across all running cardano-node process identifiers (PIDs) — reveals memory growth signature over a one-minute window. | (see `dwarf-fw/runs/`) |
| `resource-disk-fill-host-tmpdir` | Controlled 256 MB write to a host tmpdir, before/after `df -h`, then cleanup — validates the disk-fill measurement path safely. | (see `dwarf-fw/runs/`) |

Outcomes are captured in the bundles' `outputs/stdout.log` and `log.ndjson`.

## Tooling and target

- **Host:** the Linux target host (Linux x86-64, Ubuntu, native).
- **Devnet:** `profile-a-haskell-peersharing-disabled`, 3 cardano-node processes managed by `cardano-testnet`, ports 34043 / 36195 / (third), local-only loopback topology.
- **Framework:** Dwarf at `the Linux target host:/opt/dwarf/dwarf-fw/`, GHC 9.6.7, Rust 1.95, Python 3.12.
- **No remote/internet calls** — everything runs locally on the Linux target host per project rule that all execution targets the deployment-realistic Linux x86-64 environment.

## 2026-04-27 expansion: proactive substrate abuse family

This slice extends the earlier host-only smokes into composed-substrate scenarios that run a real two-node `cardano-node` substrate and then apply host-managed pressure while Dwarf observation stays active.

### Remotely proven on the Linux target host

These scenarios are authorable on the current primitive surface because they only require:

- `runtime_install_version`
- `runtime_compose_substrate`
- `load_shell_command`
- `runtime_multi_node_observation`
- `runtime_teardown_substrate`

They prove the narrow operational contract: the substrate starts, host-managed stress is applied, observation emits bundle artifacts, and the nodes remain responsive. They do **not** yet claim deeper peer-connectivity or consensus-convergence guarantees under the pressure window, because the current composed-substrate observation path does not surface that reliably enough for these short abuse runs.

| Scenario | Pressure type | Proof state |
|---|---|---|
| `runtime-substrate-resource-ram-host-pressure-example-smoke` | host-side RAM allocator | remotely proven (`20260427T185903Z-571e4f2a`) |
| `runtime-substrate-resource-disk-host-pressure-example-smoke` | host-side sustained disk writes | remotely proven (`20260427T185903Z-82d4c192`) |
| `runtime-substrate-resource-cpu-host-pressure-example-smoke` | host-side CPU busy loops | remotely proven (`20260427T185903Z-01661e74`) |

Expected assertion contract for the proven set:

- `all_nodes_started_clean`
- `all_nodes_responsive`

Evidence shape in the proof bundles:

- host-managed stressor artifact under `outputs/{ram,disk,cpu}-pressure/`
- `outputs/multi-node-observation/observation-summary.json`
- `outputs/substrate-teardown/teardown-report.json`

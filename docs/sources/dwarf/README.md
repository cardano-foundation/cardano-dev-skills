# DWARF

DWARF is a fuzzing and adversarial-testing framework for Cardano node implementations
(Haskell `cardano-node` and Rust `amaru`). It exercises a node's serialization /
deserialization, mini-protocol, runtime, resource, and consensus surfaces with
structurally-malformed and adversarial inputs, captures structured evidence, and
**bridges its CBOR-decoder fuzzing into the [Antithesis](https://antithesis.com)
deterministic-simulation platform** so a real node decodes mutated payloads across
thousands of explored timelines.

It has two complementary halves:

1. **Local framework** — a scenario-driven fuzz/test runner (Python `profile_manager`
   + `cardano-profile` CLI + web dashboard) that spins up containerized Cardano
   devnets (Haskell `cardano-node`, Rust `amaru`, or **mixed**), runs a catalog of
   ~228 scenarios across ~8 capability families against them, and captures structured,
   replayable evidence. Profiles parameterize implementation, version, network,
   topology, and peer-sharing.
2. **Antithesis bridge** — a generator that turns a CBOR-decode scenario into a
   self-contained Antithesis test bundle, plus a Haskell **`dwarf-adversary`** that
   joins a live testnet as a node-to-node (N2N) peer and serves structurally-mutated
   CBOR to the node under test.

---

## What it does

### Local fuzz testing

The local catalog (`dwarf/scenarios/`, 228 YAML scenarios) spans these families:

| Family | What it exercises |
|---|---|
| **CBOR structural fuzz** | Decoder robustness on structurally-mutated CBOR — block-header, block, tx-body, certificate, auxiliary-data — against `cardano-node` and `amaru` (`*-cbor-*`, `edge-cases-cbor-*`). |
| **Mini-protocol fuzz** | N2N protocol grammar / sequencing / state-machine — dedicated `cardano-node-mini-protocol-*-fuzz` scenarios for handshake, chain-sync, block-fetch, tx-submission, keep-alive, peer-sharing, plus wrong-version / malformed-handshake gating. |
| **Adversarial topology / consensus** | Eclipse, sybil, byzantine block-fetch, fork-switch, era / hard-fork boundaries. |
| **Runtime / network faults** | Partition–rejoin, restart / tip recovery, freeze / recover, keep-alive failure cascade, slow-loris, time-skew. |
| **Resource pressure** | Host cpu / disk / ram / bandwidth exhaustion and disk-fill-during-sync (`resource-*`). |
| **Mempool / tx pressure** | Batch / window pressure, mempool-relay pressure, local-tx-monitor faults. |
| **Snapshot / recovery** | Snapshot corruption / recovery, multi-day pause–resume, deterministic checkpointing. |
| **Differential** | `amaru` ↔ `cardano-node` validation-path agreement on the same input (`replay-and-diff`). |
| **Forensics / evidence** | pcap / syscall / gc capture, bundle attestation, chain-verify, SARIF export, credential checks. |
| **Runtime substrate / phased** | The bulk of `runtime-substrate-*` and `phase*` — runtime profiles, capability demos, and the generated multi-node baselines that the above families build on. |

CBOR fuzzing uses two engines, selectable per scenario via `load` primitives:
`cbor_fuzz` / `cbor_fuzz_target` (semantic, structure-aware mutation) and
`cbor_fuzz_structured` (byte-level structural mutation), plus `cbor_edge_cases`
for curated corner cases. Each run writes a manifest, assertion summary, NDJSON
log, and probe outputs under `dwarf/runs/` (dashboard-inspectable) and
`dwarf/evidence/`.

### Consensus chain-selection differential

Beyond input-level differential testing, DWARF runs a **cross-implementation
chain-selection differential** on a real mixed network (the upstream `cardano_amaru`
topology — Haskell producers and relays alongside Amaru relays and an Amaru-fed
consumer). It induces forks (`runtime_network_partition`) and asserts, block-for-block
at time-aligned instants, that the Haskell `cardano-node` and Amaru select the identical
chain (`chain_select_differential`) — a consensus split between the two clients being the
highest-value failure class. Scenarios cover a healed `<k` fork, a stranding `>k` fork
(deep rollback correctly refused), and an epoch-boundary transition;
`consensus_differential_sweep.py` walks a grid of fork depths into a coverage matrix, and
`ensure_cardano_amaru_converged.py` gates a converged network first. Every run captures
per-node forge / ChainDB forensics via `runtime_tracer_capture`. See `/learn/consensus`.

### Profiles, devnets, and targets

DWARF doesn't assume a fixed network — it **spins up the devnet it needs** from a
*profile*. A profile parameterizes:

- **Implementation** — Haskell `cardano-node`, Rust `amaru`, or a **mixed** devnet
  running both side-by-side (`node_type: haskell | amaru | mixed`, with independent
  `haskell_count` / `amaru_count`).
- **Network / version** — a fully local devnet (network-magic 42) or attach to a
  public network — **preview, preview2, preprod** — via an upstream peer address, so
  the same scenarios run against real-network block shapes and era boundaries.
- **Topology & consensus knobs** — `topology_pattern` (e.g. `local-mesh`),
  `shared_genesis`, `peer_sharing` on/off.

The framework ships **12 ready profiles** plus a **template system** for generating
more:

| Profile | Shape |
|---|---|
| a / b | Haskell, peer-sharing disabled / enabled |
| c | Mixed: 1 Haskell + 1 Amaru (minimal) |
| h | Generated mixed: 2 Haskell + 1 Amaru (local-mesh, shared genesis) |
| i | Generated Haskell (3 nodes) |
| d / f / e / g | Amaru / Haskell preview & preview2 proofs |
| j / k | Haskell / Amaru preprod proofs |
| l | Amaru closed devnet |

The **local devnet backend** renders a profile into a `docker-compose.yml` and brings
the devnet up on any Docker host; a separate deploy path runs it on a remote runtime
root. Because both implementations and mixed devnets are first-class, DWARF also
supports **differential testing** — feed the same adversarial input to `amaru` and
`cardano-node` and assert their validation paths agree (`replay-and-diff`).

### CLI & dashboard

Everything runs through the `cardano-profile` CLI — a broad surface including
`profile` / `list-profiles`, `scenario` / `run` (with `--backend local-devnet` or
`antithesis`), `fuzz` / `campaign`, `replay` / `replay-and-diff` / `reproduce` /
`minimize`, `coverage` / `compare` / `stats`, `snapshot` / `evidence` / `export`
(SARIF), `deploy` / `status` / `doctor`, and the `antithesis` / `moog` bridge
commands. The same code path backs a web **dashboard** (the "Operate" views: runs,
profiles, scenarios, coverage trends, crash triage, run compare/field-diff, timeline).
See `INSTALL.md` and `OPERATIONS.md`.

### Antithesis integration

**Antithesis support is `cardano-node`-only right now.** The CBOR-scenario generator
(`profile_manager/antithesis_generator.py`) is the supported bridge, and it is
hard-gated to cardano-node (`SUPPORTED_IMPLEMENTATIONS = {"cardano-node"}`; it requires
exactly one `cbor_fuzz` load primitive and raises otherwise). It converts a CBOR-decode
scenario into a deployable bundle, mapping each decode target to an adversary protocol +
CBOR shape:

| Decode target | N2N protocol | CBOR shape | Built |
|---|---|---|---|
| block-header | chain-sync (#2) | `block-header` | ✅ |
| block | block-fetch (#3) | `block` | ✅ |
| tx-body | tx-submission2 (#4) | `tx-body` | ✅ |
| certificate | tx-submission2 (#4) | `certificate` | ✅ |
| auxiliary-data | tx-submission2 (#4) | `auxiliary-data` | ✅ |

`render_bundle()` emits a self-contained bundle: the full Antithesis test harness
(setup `sidecar` + composer `adversary` driver), the testnet (producers, relays,
tracer, tx-generator), and the `dwarf-adversary` wired for the target protocol/shape.
For block-fetch it also applies a **topology eclipse** (`_apply_eclipse`) so the node
under test fetches blocks only from the adversary.

> **Amaru is not an Antithesis target yet.** Antithesis CBOR fuzzing runs against
> `cardano-node` only. Amaru remains a **local-only** target (local/mixed devnets +
> differential `replay-and-diff`). The `antithesis/amaru-single/` and
> `antithesis/mixed-haskell-amaru/` directories are early, **unvalidated scaffolding**
> (a separate `dwarf-antithesis-workload` image, never run or confirmed live) — not a
> supported path.

### The `dwarf-adversary`

A Haskell N2N peer (`antithesis/components/dwarf-adversary/`, image
`ghcr.io/j-gainsec/dwarf-adversary:0.11.0`) that speaks the real Ouroboros N2N
mini-protocols — chain-sync (#2), block-fetch (#3), tx-submission2 (#4), keep-alive
(#8) — and serves **structurally-mutated CBOR** to the node under test. It bootstraps
a valid chain (proxying an upstream producer or serving a baked corpus), reaches GSM
`CaughtUp`, then fuzzes the targeted decoder via a mutating codec.

**Per-timeline seeding (exhaustive fuzzing).** The mutation generator is
`mkStdGen(seed XOR fnv1a64(payloadBytes))`, so distinct payloads mutate differently. The
base seed comes from `--seed`, which defaults to **`random`**: the adversary draws a
fresh `Word64` from `/dev/urandom` at launch — and since Antithesis intercepts entropy
as a per-timeline choice point, **every explored timeline fuzzes from a different seed**,
so the mutation seed-space is explored rather than fixed. The drawn value is logged
(`reproduce with --seed 0x…`), and an explicit `--seed 0x<hex>` pins the RNG for
deterministic recreation.

Key flags: `--protocol {chainsync|blockfetch|txsubmission}`, `--cbor-shape {block-header|block|tx-body|certificate|auxiliary-data}`,
`--mutation-rate`, `--upstream HOST:PORT`, `--seed {random|0x<hex>|<dec>}`, `--network-magic`,
`--listen-port`, `--baked-chain FILE` (serve an embedded chain, no upstream),
`--capture-to FILE` (serialize a captured chain), `--selftest`.

### Launching live runs (Moog)

Live Antithesis campaigns are launched through **Moog**, the on-chain requester flow
(`profile_manager/moog.py`, surfaced as `cardano-profile moog …`). It handles requester
registration, the on-chain token / MPFS interaction, the Cardano Foundation oracle
hand-off, and `create-test-plan` (free dry-run) / `create-test --approve` (billed
launch) against a GitHub repo + commit + bundle directory. Results are read back from
the Antithesis tenant (triage reports / SDK assertions). Secrets (PAT, wallet, tenant
credentials) live outside the repo and are never committed.

---

## Confirmed status

**Confirmed live on Antithesis** (tenant `amaru-cardano`, `--no-faults`, 1h runs):

| CBOR shape | Path | Live assertion | Status |
|---|---|---|---|
| block-header | chain-sync | `dwarf_served_mutated_header` (decode-on-receipt) | ✅ live (SP2) |
| **tx-body** | tx-submission | `dwarf_served_mutated_tx` | ✅ **PASSED** 2026-06-13 (run `0e1c9877…`, Completed 1h 12m) |
| **block** | block-fetch | `dwarf_served_mutated_block` | ✅ **PASSED** 2026-06-13 (run `ea5ad7d0…`, Completed 1h 13m) |
| certificate | tx-submission | `dwarf_served_mutated_tx` (served inside the tx) | built; not yet run live |
| auxiliary-data | tx-submission | `dwarf_served_mutated_tx` (served inside the tx) | built; not yet run live |

Both hard serve-path shapes (tx-body, block) are now proven on Antithesis: a real
`cardano-node` connects to the `dwarf-adversary`, pulls structurally-mutated CBOR, and
runs its decoder on it — with the adversary stable (no crash) and the run completing.

**Local gates** (run on the <remote-host> testnet, all green):

- `tools/sp3a_topology_eclipse_repro.sh` — block-fetch under single-network topology
  eclipse: `dwarf_served_mutated_block=69`, VRFKeyBadProof 0, RestartCount 0.
- `tools/sp3a_eclipse_repro.sh` / `tools/sp3a_baked_repro.sh` — block-fetch under
  custom-network / baked-corpus eclipse (local-only capabilities).
- `tools/sp3_caughtup_repro.sh` — the advancing CaughtUp peer foundation.

The live eclipse for block-fetch uses **topology alone on the single default network**
(no custom docker network) inside the full-harness bundle — the dwarf-adversary serves
no peer-sharing gossip, so the node under test reaches only the adversary. The
custom-network and producer-less baked bundles are retained as local capabilities
(they lack the Antithesis test harness and must not be run live).

---

## Layout

```text
DWARF/
├── README.md  INSTALL.md  OPERATIONS.md  RELEASE-NOTES.md
├── antithesis/
│   ├── components/dwarf-adversary/      # Haskell N2N adversary (cabal)
│   ├── cardano_node_dwarf/              # full-harness CBOR bundle (live-proven)
│   ├── cardano_node_dwarf_eclipse/      # custom-network eclipse (local-only)
│   ├── cardano_node_dwarf_baked/        # baked-corpus eclipse (local-only)
│   ├── amaru-single/                    # early scaffolding (amaru on Antithesis NOT supported)
│   └── mixed-haskell-amaru/             # early scaffolding (unvalidated, never run live)
├── dwarf/
│   ├── cardano-profile                  # CLI entrypoint
│   ├── profile_manager/                 # framework + antithesis.py + antithesis_generator.py + moog.py
│   ├── scenarios/                       # 228 scenario YAMLs (~8 families)
│   ├── primitives/                      # primitive registry + schemas
│   ├── profiles/                        # 12 profiles + templates/
│   ├── bundles/                        # preserved bundle archives (runs/ evidence/ generated at runtime)
│   ├── spec/                            # SARIF + spec schemas
│   └── docs/
├── delivery/                            # Docker delivery wrapper (framework image)
├── infrastructure/docker/
├── tools/                               # local repro/validation gates
├── tests/                               # framework + integration tests
└── docs/                                # design specs + implementation plans
```

## Build & run

**Local framework / dashboard** (any Docker host with Compose v2):

```bash
delivery/scripts/install.sh
delivery/scripts/build-image.sh
delivery/scripts/deploy.sh
delivery/scripts/status.sh
```

**`dwarf-adversary`** (built on a GHC 9.6.x host):

```bash
cd antithesis/components/dwarf-adversary
cabal build -w ghc-9.6.7 exe:dwarf-adversary
./build-image.sh ghcr.io/<owner>/dwarf-adversary:<tag>
```

**Generate an Antithesis bundle** from a CBOR-decode scenario, via the `cardano-profile` CLI:

```bash
dwarf/cardano-profile antithesis build <profile_id> \
  --scenario dwarf/scenarios/cardano-node-cbor-tx-body-fuzz.yaml \
  --registry ghcr.io/<owner> --tag 0.10.0 --out antithesis/cardano_node_dwarf
```

(The generator lives in `dwarf/profile_manager/antithesis_generator.py`; live campaigns
are launched from the bundle through the Moog requester flow.)

Verify the package layout with `delivery/tests/test_delivery_contract.sh`.

---

## Roadmap

The CBOR family is the one fully bridged to Antithesis (header + tx-body + block
proven live; certificate + auxiliary-data built and pending a live run). The
highest-leverage next bridges are **mini-protocol fuzz** (the adversary already speaks
every N2N protocol), **differential** `amaru` ↔ `cardano-node` agreement, and
**mempool / tx pressure**. Runtime/network-fault and snapshot scenarios are largely
redundant with Antithesis's native fault injector and are better expressed as fault
config than rebuilt as adversaries; resource-pressure and forensics scenarios stay
local. See `docs/` for design specs and the capability-surface map.

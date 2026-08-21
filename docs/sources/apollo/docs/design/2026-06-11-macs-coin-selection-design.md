# MACS (Multi-Asset Coin Selection) — Design

**Date:** 2026-06-11
**Branch:** `feat/macs-coin-selection` (from `fix/security-audit`)
**Status:** Approved for implementation (autonomous session; design decisions recorded here)

## Goal

Add MACS as a second coin selection algorithm alongside the existing largest-first
selector, benchmark both, and make the better one the default.

## Background

MACS is from "MACS: A Multi-Asset Coin Selection Algorithm for UTXO-based
Blockchains" (Ramezan, Schneider, McCann — Cardano Foundation, IEEE Blockchain
2023, DOI 10.1109/Blockchain60715.2023.00029). It formulates coin selection as an
optimization problem over four objectives:

- **O1** — maximize summed UTxO priority `P(u,c)` of selected inputs
- **O2** — minimize excess input value (change size)
- **O3** — minimize the number of input/output UTxOs
- **O4** — maximize value dispersion of payment/change sets (pool diversity)

with priority defined as:

```
P(u,c) = v(u,c) · conf(u) / ((|link(u)| + 1) · (|v(u,c) − avg(S,c)| + 1))
```

where `v(u,c)` is the value of asset `c` in UTxO `u`, `conf(u)` its age in
confirmations, `link(u)` its linked UTxOs, and `avg(S,c)` the pool-wide mean
value of `c`.

## Adaptation decisions

1. **Heuristic, not MINLP.** The paper solves the problem with an offline solver
   (GEKKO/APOPT). A transaction-building library needs deterministic,
   millisecond selection, so we implement the standard greedy adaptation: cover
   each deficient asset by repeatedly picking the highest-priority candidate
   UTxO, the same per-asset framing the paper uses for its comparison
   algorithms.

2. **No age/link metadata.** `common.Utxo` carries no confirmation count or
   linkage info, so `conf(u) = 1` and `|link(u)| = 0`, degenerating priority to
   `P(u,c) = v(u,c) / (|v(u,c) − avg(S,c)| + 1)`. This keeps the core
   multi-asset behavior: prefer valuable UTxOs near the pool average, which
   preserves pool diversity and consumes mid-range UTxOs instead of always
   draining the largest. A future hook (e.g. an optional age provider) can
   restore the full formula without API changes.

3. **Exact integer math.** Priorities are compared as cross-multiplied
   `big.Int` rationals (`v₁·(d₂+1) > v₂·(d₁+1)`), never floats, so selection is
   deterministic and overflow-safe for full-range token quantities.

4. **Redundancy pruning (O3/O2).** After coverage, a backward pass drops any
   selected input whose removal still leaves the target covered, lowest
   priority first. This directly serves O2/O3 without a solver.

## Architecture

New file `coinselection.go`:

```go
// CoinSelector chooses UTxOs from an available pool to cover a target value.
type CoinSelector interface {
    Name() string
    // Select returns a subset of available whose summed value covers target.
    // available has already been filtered of in-use UTxOs.
    Select(available []common.Utxo, target Value) ([]common.Utxo, error)
}

type LargestFirstSelector struct{} // extracted from current selectCoins loop
type MACSSelector struct{}         // new
```

- `Apollo` gains a `coinSelector CoinSelector` field and a
  `SetCoinSelector(CoinSelector) *Apollo` builder method.
- `selectCoins` keeps its responsibilities (early-exit, saturating remaining
  computation, used-UTxO filtering, `markUsed` commit on success) and delegates
  the actual choice to the selector.
- Largest-first keeps its exact semantics, including validating lovelace
  amounts only for UTxOs it actually visits.
- MACS validates every UTxO up front (it must read all amounts to compute
  pool averages anyway).
- The default selector is whichever wins the benchmarks (see below); the other
  remains available via `SetCoinSelector`.

### MACS selection procedure

1. Snapshot the pool: per asset class `c` in the target (each policy/name pair,
   plus lovelace), compute `avg(S,c)` over **all** available UTxOs (absent
   asset counts as 0, per the paper).
2. While the remaining target is non-zero:
   a. Take the first deficient asset class in deterministic order (assets
      sorted by policy/name, lovelace last).
   b. Among unselected UTxOs with `v(u,c) > 0`, select the one with maximal
      `P(u,c)`; ties break by larger `v(u,c)`, then by `txid#index`.
   c. No candidate → `"insufficient UTxOs to cover required value"` error.
   d. Subtract the UTxO's full value from the remaining target (saturating).
3. Prune redundant inputs (lowest priority first) while coverage holds.

Termination: every iteration removes ≥1 unit of some deficient asset from a
finite pool, or errors.

## Benchmarks

`coinselection_bench_test.go` with paired `Benchmark{LargestFirst,MACS}/...`
over generated pools (fixed seed, deterministic):

| Scenario | Pool |
|----------|------|
| AdaSmallPool | 100 ADA-only UTxOs, mixed sizes |
| AdaLargePool | 10,000 ADA-only UTxOs |
| MultiAsset | 1,000 UTxOs, 50 policies, target needs 5 assets |
| DustHeavy | 5,000 UTxOs, 90% dust (1–2 ADA) |

Reported per benchmark: ns/op plus `inputs/op` and `excess_lovelace/op` via
`b.ReportMetric`. A separate `TestCoinSelectionComparison` runs a multi-round
wallet simulation (pay target, deposit change back, add deposits — mirroring
the paper's evaluation) and logs pool size growth and dust fraction for both
algorithms.

## Default choice criteria

Correctness is a given (both must pass the same conformance tests). Quality
(fewer inputs, smaller excess/change, healthy pool over repeated rounds) is
primary; raw speed is secondary as long as selection at 10k UTxOs stays well
under 10ms. The benchmark results and final decision are recorded at the
bottom of this document.

## Testing

- TDD throughout: unit tests for each selector against table-driven pools
  (exact-cover, multi-asset deficits, insufficiency errors, determinism).
- Conformance suite shared by both selectors (same inputs must cover target,
  no duplicates, error on insufficient funds).
- Existing `Complete()` integration tests must stay green; largest-first
  extraction must be behavior-preserving.

## Results

### One-shot benchmarks (`BenchmarkCoinSelection`, benchtime=50x, linux/amd64)

| Scenario | Algorithm | ns/op | inputs/op | excess ADA/op |
|----------|-----------|------:|----------:|--------------:|
| Ada100 (100 UTxOs) | largest-first | 222k | 1 | 49.7 |
| | MACS | 225k | 2 | 49.3 |
| Ada10k (10,000 UTxOs) | largest-first | 65.3M | 6 | 99.9 |
| | MACS | 115.6M | 10 | 6.7 |
| MultiAsset1k (1,000 UTxOs, 5-asset target) | largest-first | 6.2M | **785** | **9254** |
| | MACS | 7.3M | **15** | **135** |
| DustHeavy5k (5,000 UTxOs, 90% dust) | largest-first | 31.1M | 3 | 99.3 |
| | MACS | 26.5M | 4 | 1.1 |

### Wallet simulation (`TestCoinSelectionComparison`, 200 rounds of pay + change + deposits)

| Variant | avg inputs/tx | avg change (ADA) | final pool size | final dust |
|---------|--------------:|-----------------:|----------------:|-----------:|
| largest-first | 4.08 | 239.8 | 5 | 0 |
| MACS (pure) | 2.68 | 2.0 | 286 | 178 |
| MACS (sweep, default) | 3.09 | 3.1 | 204 | 1 |

### Decision: MACS (with dust sweeping) is the default

- On multi-asset targets largest-first degenerates catastrophically: it
  consumes every ADA-only UTxO before touching asset-carrying ones (785
  inputs — beyond Cardano's transaction size limit), while MACS covers the
  same target with 15.
- MACS produces 10–100× less excess input value, meaning smaller change
  outputs and less wallet churn; largest-first's tiny simulated pool comes
  from consolidating the entire wallet into a ~240 ADA average change output
  every transaction, which is terrible for privacy and parallel spending.
- Dust sweeping (≤2 ADA-only UTxOs under 1 ADA per tx) keeps dust from
  accumulating (178 → 1 dust UTxOs) for ~0.4 extra inputs per tx.
- Speed is comparable; MACS is slower only on the 10k ADA-only pool
  (116ms vs 65ms), well under the 10ms/1k-UTxO practical bar at realistic
  pool sizes.

`LargestFirstSelector` remains available via
`SetCoinSelector(&LargestFirstSelector{})`.

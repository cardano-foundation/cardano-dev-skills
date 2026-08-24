# Coin selection

`Complete()` covers the transaction's required value from loaded and
preselected UTxOs using a `CoinSelector`. Selection is **deterministic**: the
same pool and target must yield the same inputs. Large pools observe the
builder's `context.Context` and abort with an error wrapping `ctx.Err()`.

## Default: MACS

Apollo uses **MACS** (Multi-Asset Coin Selection,
[IEEE Blockchain 2023](https://doi.org/10.1109/Blockchain60715.2023.00029)) by
default. For each deficient asset class (native assets first, lovelace last)
it prefers a UTxO that covers the remaining deficit of that class on its own,
and otherwise the unselected UTxO with the highest priority

`P(u,c) = v(u,c) / (|v(u,c) - avg(S,c)| + 1)`

which favours valuable UTxOs near the pool average. A later pass drops inputs
made redundant by later picks.

`NewMACSSelector()` (the default) also:

- Sweeps up to **two** ADA-only UTxOs under **1 ADA** (`DustThreshold` /
  `MaxDustInputs`) so dust does not accumulate.
- Avoids leftovers in the change dead band (`MinChange`, default 1.5 ADA):
  Cardano cannot emit a change output below min-UTxO, so that leftover would
  be burned as fee.

Zero `DustThreshold` disables sweeping. The zero-value `MACSSelector{}` is the
pure algorithm with no sweep; prefer `NewMACSSelector()` in production.

Measured through `Complete()` with mainnet parameters: on a 150-transaction
wallet lifetime of plain ADA payments MACS costs within 0.56% of largest-first
while ending with one dust UTxO rather than ninety; on a multi-asset payment
it is roughly three times cheaper (200,437 lovelace over 20 inputs against
623,629 over 286).

The paper, implementation notes, and benchmark tables are in
[`docs/design/2026-06-11-macs-coin-selection-design.md`](../design/2026-06-11-macs-coin-selection-design.md)
(GitHub only; not in the GitBook sidebar). Run
`go test -bench BenchmarkCoinSelection` (`coinselection_bench_test.go`).

## Switching selector

```go
// Default: MACS with dust sweeping
builder := apollo.New(ctx)

// v1 greedy behaviour
builder = builder.SetCoinSelector(&apollo.LargestFirstSelector{})

// MACS without sweeping, or custom limits
builder = builder.SetCoinSelector(&apollo.MACSSelector{})
builder = builder.SetCoinSelector(&apollo.MACSSelector{
    DustThreshold: 2_000_000,
    MaxDustInputs: 4,
})
```

`LargestFirstSelector` consumes ADA-only UTxOs before asset-carrying ones,
largest lovelace first.

## Implicit inputs

Withdrawals, mints, and deposit refunds are implicit value. If they cover the
selection target on their own, Apollo still contributes **exactly one** input
(preferring a pure-ADA UTxO, in canonical order). A body with `inputs = []` is
rejected by the ledger (`InputSetEmptyUTxO`). That used to break reward
withdrawals that needed no extra ADA.

Preselected UTxOs (`AddInput`, `CollectFrom`, `ConsumeUTxO`) are always
included; the selector fills the remainder from `AddLoadedUTxOs` /
`AddInputAddress`.

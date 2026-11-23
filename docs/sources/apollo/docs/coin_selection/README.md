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
builder := apollo.New(ctx).SetMaxFee(1_000_000)

// v1 greedy behaviour
builder = builder.SetCoinSelector(&apollo.LargestFirstSelector{})

// Random-Improve, alone or falling back to Largest-First
randomImprove := apollo.NewRandomImproveSelector()
randomImprove.Seed = 42
builder = builder.SetCoinSelector(randomImprove)
builder = builder.SetCoinSelector(apollo.NewRandomImproveThenLargestFirstSelector())

// MACS without sweeping, or custom limits
builder = builder.SetCoinSelector(&apollo.MACSSelector{})
builder = builder.SetCoinSelector(&apollo.MACSSelector{
    DustThreshold: 2_000_000,
    MaxDustInputs: 4,
})
```

`LargestFirstSelector` consumes ADA-only UTxOs before asset-carrying ones,
largest lovelace first.

## Random-Improve

`RandomImproveSelector` implements the Random-Improve algorithm from
[CIP-0002](https://cips.cardano.org/cip/CIP-0002). It covers the target by
taking UTxOs in a pseudo-random order, drops any cover input that a later
pick made redundant, then adds ADA-only UTxOs that bring the lovelace total
closer to an ideal of twice the target, so the change output is roughly the
size of the payment. The order comes from a PCG generator seeded with the full
64-bit `Seed`: the same seed, pool, and target always select the same inputs,
on every platform.

`MaxInputs` limits the number of selected UTxOs. If the random cover reaches
the limit before covering the target, the selector returns an error matching
`ErrInsufficientUtxos`, even when a smaller selection exists; improvement stops
at the limit. `NewRandomImproveSelector()` sets it to
`DefaultRandomImproveMaxInputs` (100); the zero-value `RandomImproveSelector{}`
has no limit.

It is an adaptation, not a CIP-0002 reference implementation:

- It selects for the transaction's aggregate target, not for each output.
- An improvement may not take lovelace above twice the target; CIP-0002
  allows up to three times.
- Surplus native assets become change that needs its own min-UTxO lovelace,
  so the selector avoids them: the cover takes only UTxOs that reduce a
  remaining shortfall, and uses UTxOs carrying an untargeted asset, or a
  targeted one the selection already has enough of, only when nothing else
  covers the target. Pruning drops redundant token-carrying inputs before
  ADA-only ones, and improvement adds only ADA-only UTxOs.

`RandomImproveThenLargestFirstSelector` follows the Cardano Wallet strategy:
it runs Random-Improve and, only when that reports `ErrInsufficientUtxos`
(including a cover over the input limit), runs `LargestFirstSelector`.
Malformed input, overflow, and cancellation are returned without a fallback.
Its `RandomImprove` and `Fallback` fields replace either step; a nil or
typed-nil field means the default.

Every in-tree selector returns an error matching `ErrInsufficientUtxos` when
the pool cannot cover the target.

## Implicit inputs

Withdrawals, mints, and deposit refunds are implicit value. If they cover the
selection target on their own, Apollo still contributes **exactly one** input
(preferring a pure-ADA UTxO, in canonical order). A body with `inputs = []` is
rejected by the ledger (`InputSetEmptyUTxO`). That used to break reward
withdrawals that needed no extra ADA.

Preselected UTxOs (`AddInput`, `CollectFrom`, `ConsumeUTxO`) are always
included; the selector fills the remainder from `AddLoadedUTxOs` /
`AddInputAddress`.

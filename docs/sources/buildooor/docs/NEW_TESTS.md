# Test changes for the Conway cert-deposit + min-utxo work

This branch contains two related fixes (cert-deposit balancing + a tighter min-utxo bound). The handoff briefs for the underlying changes are in [CONWAY_CERT_DEPOSITS_TXBUILDER_FIX.md](CONWAY_CERT_DEPOSITS_TXBUILDER_FIX.md) and [MIN_UTXO_NOTES.md](MIN_UTXO_NOTES.md). This file documents only the **test-side** impact: what was added, what was modified, and why.

---

## New test files

### [src/__tests__/TxBuilder.build.cert_deposit.test.ts](src/__tests__/TxBuilder.build.cert_deposit.test.ts)

New suite covering `TxBuilder._initBuild`'s cert-deposit balancing path. Three tests, all passing.

| # | Test | What it verifies |
|---|---|---|
| 1 | `registration cert deducts deposit from change` | A `ConwayCertRegistrationDeposit` (deposit=2M) on a 15M-lovelace input produces a single change output of `inputs − fee − deposit`. Confirms the deposit is folded into `requiredOutputValue` so auto-change matches ledger value-conservation. |
| 2 | `de-registration cert credits refund into change` | A `ConwayCertUnRegistrationDeposit` (refund=2M) on a 10M input produces change of `inputs + refund − fee`. Confirms the refund is folded into `totInputValue` (consumed side). |
| 3 | `throws when stakeAddressDeposit is missing for legacy CertStakeRegistration` | Passing a `CertStakeRegistration` (pre-Conway type) with protocol params that omit `stakeAddressDeposit` throws an error containing `stakeAddressDeposit`. Confirms the fail-loud path in `balanceCertDeposits` rather than silently using a mainnet default. |

**Test data note (test 1):** input is 15M (not 10M). With `defaultProtocolParameters.utxoCostPerByte = 34482`, an ada-only change output's min-utxo is ~7.83M lovelace. 10M − 2M deposit − ~173k fee = 7.826M — 571 lovelace below min-utxo, which causes `assertMinOutLovelaces` to throw. 15M leaves clear headroom for the deposit + fee + min-utxo change. Comment in the test file explains this. **Not a TxBuilder bug** — borderline test data.

---

## Modified existing tests

### [src/__tests__/TxBuilder.build.balanced.test.ts](src/__tests__/TxBuilder.build.balanced.test.ts)

One-line change: input UTxO bumped from `10_000_000` to `25_000_000` lovelace ([line 38](src/__tests__/TxBuilder.build.balanced.test.ts#L38)).

**Why:** the tightened `addMinLovelacesIfMissing` (now uses a true upper-bound 9-byte coin varint instead of an ad-hoc `+32 * utxoCostPerByte` pad) produces slightly higher min-utxo predictions. With 10M input, the test's two declared outputs + change no longer fit. 25M restores headroom and the test exercises the same balanced-build path it was designed for.

**Not a behavioral regression** — the test was always operating at the edge of fitting; the old min-utxo underestimate masked it. See [MIN_UTXO_NOTES.md](MIN_UTXO_NOTES.md) for the bound's derivation.

---

## Test suite delta (full `npx jest` run)

Comparing `main` (without these changes) vs. this branch:

|                | Before | After  | Δ      |
|----------------|--------|--------|--------|
| Tests passed   | 9      | **13** | **+4** |
| Tests failed   | 16     | **12** | **−4** |
| Suites failed  | 10     | **8**  | **−2** |
| Suites skipped | 2      | 2      | 0      |
| Tests skipped  | 5      | 5      | 0      |
| Tests todo     | 1      | 1      | 0      |

Net: +4 passing, 0 new failures. The remaining 12 failures across 8 suites are **pre-existing on `main`** and unrelated to cert-deposit / min-utxo work.

### Pre-existing failing suites (not caused or affected by this branch)

- `src/__tests__/TxBuilder.build.native_script.test.ts`
- `src/__tests__/TxBuilder.build.fee.test.ts`
- `src/__tests__/TxBuilder.build.multisig.test.ts`
- `src/__tests__/TxBuilder.build.no_datum.offchain.test.ts`
- `src/__tests__/TxBuilder.build.script.test.ts`
- `src/__tests__/TxBuilder.build.time.test.ts`
- `src/__tests__/TxBuilder.buildSync.test.ts`
- `src/TxBuilder/TxBuilderRunner/__tests__/txBuilder.runner.test.ts`

These were verified to fail on `main` (pre-branch) via `git stash && npx jest`. Confirming/fixing them is out of scope for this branch.

---

## Source changes that drove the test changes

For full diffs see `git diff`. Test-relevant summary:

- **[src/TxBuilder/TxBuilder.ts](src/TxBuilder/TxBuilder.ts)** — added `balanceCertDeposits()` private method; `_initBuild` now folds registration deposits into `requiredOutputValue` and de-registration refunds into `totInputValue` before computing change. Tightened `addMinLovelacesIfMissing` to measure size against a 9-byte (`2^64-1`) coin varint, removing the chicken-and-egg between coin-size and min-utxo. Imports widened to pull in the Conway cert classes used for `instanceof` dispatch.
- **[src/TxBuilder/TxBuilderProtocolParams.ts](src/TxBuilder/TxBuilderProtocolParams.ts)** — added optional `stakeAddressDeposit` and `drepDeposit` fields to both `ValidatedTxBuilderProtocolParams` and `TxBuilderProtocolParams`. `defaultTxBuilderProtocolParameters` and `completeTxBuilderProtocolParams` thread them through as `undefined` by default; `_initBuild` throws a clear error pointing at the missing field if a legacy cert needs one and it isn't supplied (covered by test #3 above).
- **[package.json](package.json)** — `@harmoniclabs/cardano-ledger-ts` repointed to local `0.5.2` tarball (then `0.5.4`/later via in-place rebuild) so the Conway cert classes are reachable from the top-level barrel and `TxBody.isCertificate` recognises them. Without that companion fix in `cardano-ledger-ts`, tests 1 and 2 here would fail with `"invalid 'certs' field"` at `TxBody` construction time, before any deposit-balancing code runs.

---

## How to run

```sh
# Just the new suite
npx jest src/__tests__/TxBuilder.build.cert_deposit.test.ts

# The modified balanced test
npx jest src/__tests__/TxBuilder.build.balanced.test.ts

# Everything (compare against pre-branch baseline above)
npx jest
```

All three cert-deposit tests should pass. The balanced test should pass. No new regressions vs. `main`.

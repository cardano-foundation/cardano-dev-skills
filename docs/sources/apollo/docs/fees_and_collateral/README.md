# Fees and collateral

## Minimum fee

`Complete()` estimates the fee from protocol parameters (`minFeeA` / `minFeeB`),
serialized size, Plutus execution prices, and the Conway **tiered
reference-script fee**. A reference script whose per-byte price is missing from
the parameters is an error, not an underpriced transaction.

The reference-script price is preserved as a rational when the provider supplies
one (`MinFeeRefScriptCostPerByteRational`); it is not round-tripped through a
lossy float.

Helpers on the builder:

| Method | Role |
|--------|------|
| `SetFee(fee)` | Target fee used with `Complete()` (replacement for v1 `CompleteExact`) |
| `ForceFee(fee)` | Pin the fee |
| `SetFeePadding(padding)` | Extra lovelace on top of the estimate |

Fee estimation counts witnesses as a **set**: wallet, registered required
signers, distinct payment credentials on spending and collateral inputs, and
stake credentials behind withdrawals and certificates. The old "one witness plus
explicit required signers" undercount is gone.

`max_val_size` is enforced on each output's serialized value. A wallet holding
many native assets that would produce `OutputTooBigUTxO` fails at `Complete()`
with the offending output index.

Ordinary ADA payments used to fail across a band of wallet balances because
dust absorption compared a dust-inclusive fee against a size estimate that
could not see the surcharge, and the coin-selection reserve was `MaxTxFee`
rather than the fee of the transaction being built. The fee is now monotone
and never settles below a value already required by a shape under
consideration.

## Collateral

Script transactions need collateral. Apollo can pick it, or you pin it:

```go
builder = builder.AddCollateral(utxo)
builder = builder.SetCollateralAmount(2_000_000) // lovelace; emitted as total_collateral
```

Rules `Complete()` enforces:

- A **single wallet UTxO may be both a spending input and collateral**, so a
  one-UTxO wallet can build a script transaction (v1 refused this).
- Script-address collateral is forbidden, including when the caller pinned it.
- `SetCollateralAmount` is emitted as `total_collateral` even alongside
  `AddCollateral`. An amount below the ledger minimum or above the collateral
  inputs is rejected. An explicit amount that would leave a sub-min-ADA return
  is rejected rather than silently forfeiting the dust.
- Collateral is resized inside the fee-convergence loop.

Turn execution-unit estimation off with `DisableExecutionUnitsEstimation()`
only when every redeemer already has `ExUnits`.

---
title: sdk/builders/phases/Collateral.ts
nav_order: 137
parent: Modules
---

## Collateral overview

Collateral Phase

Selects UTxOs to serve as collateral for script transactions and creates
the collateral return output. Updates the transaction fee to account for
the size impact of collateral fields.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [phases](#phases)
  - [executeCollateral](#executecollateral)

---

# phases

## executeCollateral

Execute collateral selection phase for script transactions.

**Phase Flow:**

```
Check if scripts present
(skip if no redeemers)
  ↓
Filter available UTxOs
(exclude selected, exclude ref scripts)
  ↓
Sort candidates
(pure ADA first, smallest first)
  ↓
Greedy selection
(target 5 ADA, max 3 inputs)
  ↓
Adjust fee for size
(+180 bytes × minFeeCoefficient)
  ↓
Calculate totalCollateral
(adjustedFee × 150%)
  ↓
Calculate return & validate minUTxO
(return excess to user)
  ↓
Update state
(store collateral data, update fee)
```

**Key Principles:**

- Only runs for script transactions (redeemers.size > 0)
- Uses 5 ADA fixed estimate (conservative, simple)
- Prefers pure ADA but supports multi-asset
- All tokens from selected collateral returned to user
- Fee updated to include collateral size impact
- One-pass approach (no iteration)

**Signature**

```ts
export declare const executeCollateral: () => Effect.Effect<
  PhaseResult,
  TransactionBuilderError,
  TxContext | AvailableUtxosTag | ChangeAddressTag | ProtocolParametersTag | BuildOptionsTag
>
```

Added in v2.0.0

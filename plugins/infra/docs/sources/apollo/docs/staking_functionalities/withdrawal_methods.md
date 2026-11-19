# Withdrawal Methods

This page documents **reward withdrawals**: `AddWithdrawal`. Implementation: [`apollo.go`](../../apollo.go).

## Purpose and method signature

```go
func (a *Apollo) AddWithdrawal(
    address common.Address,
    amount uint64,
    redeemerData *common.Datum,
    exUnits *common.ExUnits,
) *Apollo
```

- **address**: Must have a valid **staking component** (e.g. stake/reward address or base address).
- **amount**: Withdrawal amount in lovelace.
- **redeemerData**: Optional. If non-nil, a redeemer with `Tag = REWARD` is created and associated with this withdrawal.
- **exUnits**: Optional execution units. If nil, units are estimated during `Complete()`.

## Inputs and constraints

- Address must have a staking component. Enterprise addresses are not valid for withdrawals.
- Redeemer from file/JSON: read and parse to `common.Datum` in your application; Apollo does not accept file paths.

## Behavior details

- Withdrawals are stored in the builder's withdrawal map and included in the transaction body by `Complete()`. Fee estimation accounts for withdrawal amounts.
- When redeemer data is provided, a redeemer with `Tag = Redeemer.REWARD` and the corresponding index is stored and merged into the witness set; execution units are filled when estimation is enabled.

## Cardano CLI equivalence (10.14.0.0)

| CLI                                                        | Apollo                                                              |
| ---------------------------------------------------------- | ------------------------------------------------------------------- |
| `transaction build --withdrawal STAKE_ADDRESS+AMOUNT`      | `AddWithdrawal(stakeAddr, amount, nil, nil)`                        |
| `--withdrawal` + `--withdrawal-reference-tx-in-redeemer-*` | Read/decode redeemer to `common.Datum`, then `AddWithdrawal(addr, amount, &redeemer, &exUnits)` |

**Parity:** Full (manual file/value for redeemer).

## Examples

### Withdrawal (no redeemer)

**Apollo:**

```go
import (
    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

a := apollo.New(cc)
a.SetWallet(wallet)
a.AddLoadedUTxOs(utxos...)
a.PayToAddress(myAddr, 10_000_000)
a.AddWithdrawal(stakeAddr, 1_000_000, nil, nil)
tx, err := a.Complete()
```

**Cardano CLI:**

```bash
cardano-cli transaction build --withdrawal "stake1u...+1000000" ...
```

### Withdrawal with redeemer

**Apollo:**

```go
redeemer := common.Datum{} // your redeemer data
exUnits := common.ExUnits{Memory: 500000, Steps: 200000000}
a.AddWithdrawal(stakeAddr, 1_000_000, &redeemer, &exUnits)
```

**Cardano CLI:**

```bash
cardano-cli transaction build --withdrawal "stake1u...+1000000" --withdrawal-reference-tx-in-redeemer-value '...' ...
```

## Caveats and validation

- Withdrawals with redeemers require evaluation so execution units can be filled; the builder's evaluation flow handles this when estimation is enabled.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.

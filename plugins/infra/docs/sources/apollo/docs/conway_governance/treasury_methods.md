# Treasury Methods

This page documents the **treasury donation** fields added in the Conway era: `SetCurrentTreasuryValue`, `AddTreasuryDonation`. Implementation: [`apollo.go`](../../apollo.go), `github.com/blinklabs-io/gouroboros/ledger/conway` (fields 21 and 22).

These two fields let any user **donate ADA directly to the treasury** as part of a regular transaction — independently of governance proposals. Both are optional. When used together, they pin the donation against a specific treasury value to prevent races; when omitted, the transaction body fields are zero (the default, omitted from CBOR via `omitempty`).

## Method signatures

```go
func (a *Apollo) SetCurrentTreasuryValue(value int64) *Apollo
func (a *Apollo) AddTreasuryDonation(amount int64) *Apollo
```

Both are chainable. `AddTreasuryDonation` accumulates across calls — calling it twice with `5_000_000` and `2_500_000` produces a single donation of `7_500_000`.

## Behavior details

- **`SetCurrentTreasuryValue`** writes `TransactionBody` field 21 (`CurrentTreasuryValue`). When non-zero, it asserts the treasury value the transaction was constructed against. The node compares this to the actual treasury value in the current epoch and rejects the transaction on mismatch.
- **`AddTreasuryDonation`** writes `TransactionBody` field 22 (`Donation`). The donated amount is included in `Complete()`'s required input balance, alongside outputs and fees.
- Default behavior (neither method called): both fields stay at zero, omitted from the CBOR encoding entirely.

## Validation

Apollo rejects invalid inputs at builder time — `Complete()` returns an error rather than producing an invalid transaction:

| Invalid input | Result |
|---|---|
| `SetCurrentTreasuryValue(-1)` | `Complete()` returns an error |
| `AddTreasuryDonation(-1)` | `Complete()` returns an error |
| Donations summing to overflow `int64` | `Complete()` returns an error |

## Cardano CLI equivalence (10.14.0.0)

| CLI | Apollo |
|-----|--------|
| `transaction build --treasury-donation` | `AddTreasuryDonation(amount)` |
| `transaction build --current-treasury-value` | `SetCurrentTreasuryValue(value)` |

Cardano CLI requires both flags together when donating; Apollo allows either independently, but if you set a current treasury value you usually also want to donate, and vice versa.

## Examples

### Donate to the treasury

**Apollo:**

```go
apollob = apollob.
    SetCurrentTreasuryValue(currentEpochTreasuryValue).
    AddTreasuryDonation(5_000_000).
    AddLoadedUTxOs(utxos...)
apollob, err = apollob.AddInputAddressFromBech32(myAddr)
if err != nil {
    panic(err)
}
apollob, err = apollob.PayToAddressBech32(myAddr, 10_000_000)
if err != nil {
    panic(err)
}
apollob, err = apollob.Complete()
```

`currentEpochTreasuryValue` should come from a fresh ledger query (e.g. `cardano-cli query ledger-state`).

**Cardano CLI:**

```bash
cardano-cli conway transaction build \
  --tx-in <utxo> \
  --change-address <addr> \
  --current-treasury-value <value> \
  --treasury-donation 5000000 \
  --out-file tx.raw
```

### Multiple donations accumulate

```go
apollob = apollob.
    AddTreasuryDonation(5_000_000).
    AddTreasuryDonation(2_500_000)

// Final donation field on the transaction body is 7_500_000.
```

This is convenient when constructing a transaction in stages — e.g. a fundraising helper might add a base amount and a tip layer separately.

### Donation without pinning the treasury value

If you don't care about racing with epoch boundaries, omit `SetCurrentTreasuryValue`:

```go
apollob = apollob.
    AddTreasuryDonation(5_000_000).
    AddLoadedUTxOs(utxos...)
apollob, err = apollob.AddInputAddressFromBech32(myAddr)
if err != nil {
    panic(err)
}
apollob, err = apollob.PayToAddressBech32(myAddr, 10_000_000)
if err != nil {
    panic(err)
}
apollob, err = apollob.Complete()
```

The node accepts the transaction as long as inputs cover outputs + fee + donation.

## Evidence

- **Builder behavior verified by tests** ([`governance_test.go`](../../governance_test.go)):
  - `TestSetCurrentTreasuryValue` — `CurrentTreasuryValue` set on the body.
  - `TestAddTreasuryDonation` — multiple calls accumulate (`5_000_000 + 2_500_000 = 7_500_000`).
  - `TestTreasuryFieldsNotSetByDefault` — both fields are zero unless explicitly set.
  - `TestSetCurrentTreasuryValueNegative` — negative value causes `Complete()` to return an error.
  - `TestAddTreasuryDonationNegative` — negative donation causes `Complete()` to return an error.
  - `TestAddTreasuryDonationOverflow` — `int64` overflow is detected and reported as an error.
- **TransactionBody CBOR encoding** verified by tests in [`governance_test.go`](../../governance_test.go), including overflow-safe `uint64 → int64` conversion on unmarshal (rejects values greater than `math.MaxInt64`).

## Caveats and validation

- **Donations are irreversible** — there is no on-chain mechanism to claw back ADA donated to the treasury.
- **Treasury value is a moving target** — it changes at epoch boundaries. If you set `CurrentTreasuryValue` and an epoch transition occurs before submission, the transaction will be rejected. Either resubmit with the new value or omit the pin.
- The donation is included in fee balancing; ensure inputs cover both your outputs and the donation.
- Validate on preview/preprod first.

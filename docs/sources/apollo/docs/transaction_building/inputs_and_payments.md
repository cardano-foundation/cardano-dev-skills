# Inputs and payments

## Loading UTxOs

```go
builder = builder.AddLoadedUTxOs(utxos...)           // from chainContext.Utxos(addr)
builder = builder.AddInput(utxo)                     // pin this UTxO as a spending input
builder, err = builder.AddInputAddressFromBech32(s)
builder = builder.AddInputAddress(addr)              // Complete() fetches UTxOs for these
```

`AddLoadedUTxOs` is the usual wallet pool for [coin selection](../coin_selection/README.md).
`AddInput` / `CollectFrom` preselect specific UTxOs. `UtxoFromRef` asks the
backend for a single UTxO.

## Paying ADA and assets

```go
builder = builder.PayToAddress(receiver, 2_000_000) // lovelace
builder = builder.PayToAddress(receiver, 2_000_000, apollo.NewUnit(policy, name, 1))
builder, err = builder.PayToAddressBech32("addr1...", 2_000_000)
builder = builder.AddPayment(payment)
```

v1 `PayToAddressBech32` still exists as a convenience. Prefer
`apollo.ParseAddress` then `PayToAddress` so mistyped bech32 cannot fall
through to base58. See [address validation](../validation/README.md).

Change goes to the wallet address unless you `SetChangeAddress` /
`SetChangeAddressBech32`.

## Script inputs

```go
builder = builder.CollectFrom(scriptUtxo, redeemer, exUnits)
```

`CollectFrom` pins the UTxO, attaches a spend redeemer, and flags execution-unit
estimation unless you already passed non-zero `exUnits` and later
`DisableExecutionUnitsEstimation`. Attach the script with `AttachScript` or a
reference input; see [Plutus V3](../plutus_v3_support/README.md) and
[data attachment](../data_attachment/README.md).

`ConsumeUTxO(utxo, payments...)` spends a UTxO into explicit payments
(replacement for v1 `ConsumeAssetsFromUtxo`).

## Validity interval and required signers

```go
builder = builder.SetTtl(slot)
builder = builder.SetValidityStart(slot)
builder = builder.AddRequiredSigner(pkh)
builder = builder.AddRequiredSignerPaymentKey(addr)
builder = builder.AddRequiredSignerStakeKey(addr)
```

## Cloning

`Clone()` deep-copies builder-owned state and keeps the same chain context,
wallet, coin selector, and evaluation-witness providers. Clone **before**
`Complete()` if you need a second attempt.

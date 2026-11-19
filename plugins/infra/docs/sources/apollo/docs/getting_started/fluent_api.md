# Fluent builder and errors

Most builder methods return `*Apollo` so you can chain calls:

```go
builder = builder.
    AddLoadedUTxOs(utxos...).
    PayToAddress(receiver, 2_000_000).
    SetTtl(slot)
```

## Methods that return `(*Apollo, error)`

A method returns an error when the failure is local and immediate: bad hex, an
unparseable bech32 string, a constructor argument. Examples:

- `SetWalletFromMnemonic`
- `AddReferenceInput`
- `PayToAddressBech32` and other `*Bech32` helpers
- `RegisterStake`, `DelegateStake`, and the other staking methods
- `Complete`, `Sign`, `Submit`, `GetTxCbor`

Check `err` after those calls. Do not keep chaining on a failed result unless
you also check it later at `Complete()`.

## Methods that cannot fail at the call site

Methods such as `PayToAddress`, `AddPayment`, `Mint`, `AttachScript`,
`AddCollateral`, and `SetFee` return only `*Apollo`. If they hit a problem they
call `setErrOnce` and store the **first** error. Later fluent calls still run,
but `Complete()` returns that stored error and does not build a body.

```go
builder = builder.PayToAddress(addr, 1_000_000).AttachScript(script)
builder, err = builder.Complete() // reports the first stored error, if any
```

`setErrOnce` keeps the earliest failure. Fix that, then build again from a
fresh `New` or from `Clone()` taken before `Complete()`.

## Context

`WithContext(ctx)` attaches a `context.Context` used for backend calls and coin
selection cancellation. Pass a context with a deadline around `Complete()` when
selection might run over a large UTxO pool:

```go
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
builder = builder.WithContext(ctx)
builder, err = builder.Complete()
```

Coin selectors must observe that context and return an error wrapping
`ctx.Err()` when it is done.

## See also

- [Complete, sign, and submit](../transaction_building/complete_sign_submit.md)
- [Validation and pitfalls](../validation/README.md)

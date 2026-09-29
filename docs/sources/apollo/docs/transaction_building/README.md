# Builder overview

`apollo.New(chainContext)` returns a fluent builder. Methods accumulate
inputs, outputs, scripts, certificates, metadata, and governance actions.
`Complete()` balances the transaction; `Sign()` attaches the wallet witness;
`Submit()` publishes it.

```go
builder := apollo.New(chainContext)
builder, err = builder.SetWalletFromMnemonic(mnemonic)
builder = builder.AddLoadedUTxOs(utxos...).PayToAddress(receiver, 2_000_000)
builder, err = builder.Complete()
builder, err = builder.Sign()
txId, err := builder.Submit()
```

## Transaction-body set tags

Apollo preserves its historical Conway body encoding by default: inputs (body
key 0) are untagged arrays, while collateral, required signers, and reference
inputs (keys 13, 14, and 18) use CBOR tag 258. Reconstructing hardware-wallet
APIs commonly expose one set-tag choice for the entire body. Select Apollo's
uniform untagged policy when the external signer must reproduce the exact body:

```go
builder := apollo.New(chainContext).
    SetTransactionBodySetTagPolicy(
        apollo.TransactionBodySetTagPolicyUntagged,
    )
```

The policy applies only to the four set-valued transaction-body fields. It does
not change witness-set or Plutus-data set tags. Changing the policy changes the
encoded body, transaction ID, and every signature, so choose it before
`Complete()` and give reconstructing signers the same choice.

## Sections in this chapter

- [Inputs and payments](inputs_and_payments.md) — UTxOs, `PayToAddress`,
  `CollectFrom`, `ConsumeUTxO`, TTL
- [Mint and burn](mint_and_burn.md)
- [Metadata](metadata.md)
- [Complete, sign, and submit](complete_sign_submit.md)

Related:

- [Wallets](../wallets/README.md)
- [Coin selection](../coin_selection/README.md)
- [Fees and collateral](../fees_and_collateral/README.md)
- [Plutus V3](../plutus_v3_support/README.md)
- [Data attachment](../data_attachment/README.md)
- [Staking](../staking_functionalities/README.md)
- [Governance](../conway_governance/README.md)

## Units and values

`Unit` is a native asset quantity (`PolicyId`, `Name`, `Quantity` as `int64`).
Negative `Quantity` on `Mint` is a burn and must be covered by inputs.

`Value` uses checked arithmetic: `Add` / `Sub` return an error on uint64
overflow instead of wrapping.

`PaymentI` is implemented by `Payment`. `ToTxOut()` returns
`common.TransactionOutput` and an error. Apollo builds Conway bodies (Babbage
output format) and reports a clear error for any other output type.

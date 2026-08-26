# Chain backends

Every build starts from a `backend.ChainContext`: protocol parameters, UTxOs,
submission, and (when the provider can) script evaluation.

```go
type ChainContext interface {
    ProtocolParams() (ProtocolParameters, error)
    GenesisParams() (GenesisParameters, error)
    NetworkId() uint8
    CurrentEpoch() (uint64, error)
    MaxTxFee() (uint64, error)
    Tip() (uint64, error)
    Utxos(address common.Address) ([]common.Utxo, error)
    SubmitTx(txCbor []byte) (common.Blake2b256, error)
    EvaluateTx(txCbor []byte, additionalUtxos []common.Utxo) (map[common.RedeemerKey]common.ExUnits, error)
    UtxoByRef(txHash common.Blake2b256, index uint32) (*common.Utxo, error)
    ScriptCbor(scriptHash common.Blake2b224) ([]byte, error)
}
```

Not every backend implements every operation. Check
[capabilities](capabilities.md) before relying on optional behavior — in
particular `EvaluateTx`'s `additionalUtxos` argument
(`CapabilityEvaluateTxAdditionalUtxos`).

Network ID is `1` for mainnet and `0` for testnets. There is no
`constants.MAINNET` enum.

## Which backend

| Backend | Package | Typical use |
|---------|---------|-------------|
| [Blockfrost](blockfrost.md) | `backend/blockfrost` | Hosted HTTP; reports full capabilities including additional UTxOs |
| [Ogmios + Kupo](ogmios.md) | `backend/ogmios` | Self-hosted node; Kupo optional for address UTxOs and script CBOR |
| [UTxO RPC](utxorpc.md) | `backend/utxorpc` | gRPC/`connect`; prefers `utxorpc.v1beta`, falls back to v1alpha |
| [Fixed](fixed_and_cache.md) | `backend/fixed` | Deterministic tests; no live chain |
| [Cache](fixed_and_cache.md) | `backend/cache` | TTL wrapper around another context |

Out-of-tree backends should still implement `ChainContext`. Optional
`CapabilityReporter` lets callers discover gaps without a probe request.
`backend.ComputeMaxTxFee` and `backend.ValidateAdditionalUtxo` stay exported
for those implementations.

## See also

- [Getting started](../getting_started/README.md)
- [Fees and collateral](../fees_and_collateral/README.md) — reference-script
  prices come from protocol parameters the backend parsed

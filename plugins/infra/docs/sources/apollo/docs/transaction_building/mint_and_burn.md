# Mint and burn

```go
unit := apollo.NewUnit(policyIdHex, assetName, quantity)
builder = builder.Mint(unit, nil, nil)                    // simple mint
builder = builder.Mint(unit, &redeemer, &exUnits)         // script mint; nil exUnits → estimate
builder = builder.AttachScript(policyScript)
```

`quantity > 0` mints; `quantity < 0` burns. Burns must be covered by
transaction inputs. Policy IDs are lower-cased so redeemer indexes bind in
byte-wise sorted order (mixed-case hex would sort differently as a string).

`GetMints()` returns the net mint value, **negative quantities included**.
`GetBurns()` returns the **absolute** quantities being burned — the value
inputs must cover. In v1 `GetBurns()` was byte-identical to `GetMints()` and
handed back the signed mint value. That is a silent behaviour change; see
[validation and pitfalls](../validation/README.md).

v1 `AddMint` / `MintAssetsWithRedeemer` collapsed into `Mint`. Script versions
are auto-detected by `AttachScript`.

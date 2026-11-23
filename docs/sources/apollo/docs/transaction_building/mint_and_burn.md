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

## Native script policies from JSON

A native policy script written in the cardano-cli simple-script JSON form can
be parsed directly; its hash is the policy ID:

```go
policy, err := apollo.NativeScriptFromJSON(policyJSON)
if err != nil {
    return err
}
policyIdHex := policy.Hash().String()
builder = builder.AttachScript(policy)
```

`NativeScriptFromJSON` accepts `sig`, `all`, `any`, `atLeast`, `after`, and
`before` scripts. It rejects a malformed or missing key hash, a missing slot
or atLeast count, a missing or null script list, an atLeast count larger than
its script list, more than 64 levels of scripts nested below the top-level
script, trailing data, unknown fields, and fields that do not belong to the
script's type (such as `slot` on a `sig` script or `required` on an `all`
script), since dropping them would change what the policy authorizes. Fields
set to null are ignored. Explicitly empty script lists and a zero atLeast
count are valid ledger scripts and are accepted. Child lists longer than 23 scripts are encoded
indefinite-length, as the ledger and cardano-cli encode them, so the policy
ID matches the one cardano-cli reports.

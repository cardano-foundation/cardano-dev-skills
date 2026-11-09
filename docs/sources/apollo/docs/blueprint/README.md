# Plutus blueprint (`CIP-57`)

Package `blueprint` parses CIP-57 `plutus.json` files, validates their
schemas, encodes, decodes, and validates Plutus data against those schemas,
and prepares validator scripts for Conway and Dijkstra transactions.

```go
import "github.com/Salvionied/apollo/v2/blueprint"

bp, err := blueprint.ParseFile("plutus.json")
datum, err := bp.EncodeDatumValue("escrow.spend", order)
var out EscrowDatum
err = bp.DecodeDatumValue("escrow.spend", datum, &out)
```

`Parse` takes raw JSON bytes, `ParseFile` reads a file from disk,
`ValidatorNames` lists the validator titles in declaration order, and
`Marshal` / `WriteFile` write a blueprint back to formatted CIP-57 JSON.
`Clone` returns a deep copy that does not share schema nodes with the original.

## Parsing and validation

`Parse` reads `preamble` (`plutusVersion` `"v1"`, `"v2"`, `"v3"`, or Dijkstra
`"v4"`), `validators`, and optional `definitions`. Every `$ref` under
`#/definitions/` is checked during `Parse`, including the `~1` escape for `/`
and angle-bracket keys such as `Option<Int>`.

`Parse` returns an error when:

- `preamble.title` or `validators` is missing, or two validators share a title
- `preamble.plutusVersion` is not `v1`, `v2`, `v3`, or `v4`
- the document is larger than `constants.MaxBlueprintBytes` (16 MiB) or contains trailing JSON tokens
- a `$ref` does not resolve, or aliases cycle without passing through a constructor, list, or map
- encoded, decoded, or validated data is nested deeper than `constants.MaxPlutusDataDepth` (100,000 levels, the same bound as plutigo's flat decoder)
- a constructor omits `index` or `fields`
- a keyword appears on the wrong `dataType` (for example `items` on `integer`)
- `purpose` is not one of `spend`, `mint`, `withdraw`, `publish`, `vote`,
  `propose`, or `guard`, or `oneOf` entries overlap
- a UPLC builtin type (`#unit`, `#integer`, `#bytes`, `#string`, `#boolean`,
  `#pair`, `#list`) appears on a datum, redeemer, or parameter boundary

## Encoding, decoding, and raw-data validation

- `Encode`, `Decode`, `EncodeDatum`, `DecodeDatum`, `EncodeRedeemer`, and
  `DecodeRedeemer` convert between a Go value and `data.PlutusData`.
- `EncodeDatumValue`, `DecodeDatumValue`, `EncodeRedeemerValue`, and
  `DecodeRedeemerValue` wrap and unwrap `*common.Datum` directly.
- `DecodeOutputDatum(validatorTitle, output, dst)` decodes the inline datum on
  a `common.TransactionOutput` against the validator's datum schema.
- `DatumHash(validatorTitle, v)` and `DatumHashHex(validatorTitle, v)` return
  the 32-byte Blake2b-256 hash of the datum's canonical witness CBOR.
  `EncodeDatumValue` and `EncodeRedeemerValue` record those bytes, so
  `datum.Hash()` agrees with `DatumHash`.
- `EncodeDefinition` / `DecodeDefinition` and `EncodeParameter` /
  `DecodeParameter` encode and decode named `definitions` entries and
  individual validator parameters.
- `ValidateData`, `ValidateDatum`, and `ValidateRedeemer` check raw on-chain
  `data.PlutusData` against a blueprint schema without decoding into a Go
  struct.

| Schema `dataType` | Go value |
|-------------------|----------|
| `integer` | any integer kind, `big.Int`, or `*big.Int` |
| `bytes` | `[]byte`, byte array, or a hex `string` |
| `list` (`items` schema) | a slice or array |
| `list` (`items` array) | a slice or a struct with that exact field count |
| `map` | a Go `map`; entries are sorted by encoded key bytes |
| `constructor` | a struct whose exported fields match `fields` in order |
| `anyOf` | a struct with one exported pointer field per variant, matched by `title` |
| `value` | `*data.Value` or `data.Value` (Plutus V4 CBOR tag 1401, validated with `Validate()`) |
| empty (`Data`) | `data.PlutusData` |

## Governance schemas

A governance validator can use nested `anyOf` schemas for Conway actions,
voters, and vote decisions. Each variant is selected by setting the single
matching pointer field on the Go struct:

- `GovAction` variants follow the ledger order: `ParameterChange` is
  constructor 0, `HardForkInitiation` is 1, `TreasuryWithdrawals` is 2,
  `NoConfidence` is 3, `UpdateCommittee` is 4, `NewConstitution` is 5, and
  `InfoAction` is 6.
- `Voter` uses constructor 0 for a constitutional-committee hot credential, 1
  for a DRep credential, and 2 for a stake-pool key hash.
- `VoteDecision` uses constructor 0 for no, 1 for yes, and 2 for abstain.

When building a transaction that both submits a ledger vote (`AddVote`) and
spends or guards with a governance redeemer, construct both from the same Go
voter, action ID, and decision values so the ledger vote and redeemer cannot
drift.

## Script and transaction helpers

`bp.Script(title)` decodes `compiledCode` using `preamble.plutusVersion`
(`v1`, `v2`, `v3`, or `v4`). When an unparameterized validator declares a
`hash` in `plutus.json`, `Script`, `ScriptRef`, `SpendAddress`,
`RewardAddress`, `Credential`, `GuardCredential`, and `PolicyId` verify that
the computed script hash matches it and return an error on mismatch.

`ApplyParams` and `ApplyParamsData` accept `1..len(RemainingParameters)`
arguments so parameters can be applied in one call or step by step, matching
`aiken blueprint apply`. They return an `*AppliedScript` carrying the new
`Script`, `Hash`, and `HashHex`. `bp.ApplyValidatorParams(title, params...)`
returns a cloned `*Blueprint` with the updated `compiledCode`, the new `hash`,
and the remaining unapplied `parameters`, ready for `Marshal()` or
`WriteFile(path)`.

### Spend, mint, and withdraw

```go
script, err := bp.Script("token.mint")
applied, err := script.ApplyParams(int64(7))
unit, err := applied.Script.Unit([]byte("nft"), 1)
v3, err := applied.Script.V3()

redeemer, err := bp.EncodeRedeemerValue("token.mint", "mint", int64(1))
tx, err := apollo.New(cc).
    SetMaxFee(1_000_000).
    SetWallet(wallet).
    AttachScript(v3).
    Mint(unit, redeemer, nil).
    Complete()
```

### Dijkstra Plutus V4 guard with `PrepareGuard`

`PrepareGuard(redeemer)` bundles the guard `Credential`, `ScriptRef`, optional
`WitnessScript` (nil for Plutus V4 so it cannot be attached as a witness), and
encoded `"guard"` redeemer:

```go
guardScript, err := bp.Script("guard.observe")
applied, err := guardScript.ApplyParams(int64(42))
bundle, err := applied.Script.PrepareGuard(int64(9))
datum, err := bp.EncodeDatumValue("guard.observe", v4Value)

tx, err := apollo.New(cc).
    SetWallet(wallet).
    SetTargetEra(apollo.EraDijkstra).
    AddGuard(bundle.Credential, bundle.Redeemer, nil).
    AddRequiredTopLevelGuard(bundle.Credential, datum).
    AddReferenceInput(refTxHash, refIdx)
```

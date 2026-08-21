# Reference Script Output Attachments

This page documents attaching **reference scripts** (Plutus V1, V2, V3, or Native) to transaction outputs. Apollo v2 provides both a **unified** method that auto-detects the script version and **version-specific** convenience methods. `common.PlutusV4Script` is recognized by `NewScriptRef`, but V4 reference-script payments are rejected for the current Conway transaction format with `ErrPlutusV4RequiresDijkstra`. Implementation: [`apollo.go`](../../apollo.go), [`convenience.go`](../../convenience.go), [`helpers.go`](../../helpers.go).

## Purpose and method signatures

### Unified: PayToAddressWithReferenceScript

```go
func (a *Apollo) PayToAddressWithReferenceScript(addr common.Address, lovelace int64, script common.Script, units ...Unit) (*Apollo, error)
```

Auto-detects the script type (V1, V2, V3, V4, Native) and creates the appropriate `ScriptRef`. Only V1-V3 and Native scripts can currently be used by Apollo's Conway transaction builder.

### Version-specific: PayToAddressWithV1/V2/V3ReferenceScript

```go
func (a *Apollo) PayToAddressWithV1ReferenceScript(addr common.Address, lovelace int64, script common.PlutusV1Script, units ...Unit) (*Apollo, error)
func (a *Apollo) PayToAddressWithV2ReferenceScript(addr common.Address, lovelace int64, script common.PlutusV2Script, units ...Unit) (*Apollo, error)
func (a *Apollo) PayToAddressWithV3ReferenceScript(addr common.Address, lovelace int64, script common.PlutusV3Script, units ...Unit) (*Apollo, error)
```

Type-safe wrappers that delegate to the unified method.

### Unified: PayToContractWithReferenceScript

```go
func (a *Apollo) PayToContractWithReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.Script, units ...Unit) (*Apollo, error)
```

Creates a payment to a script address with an **inline datum** and a reference script.

### Version-specific: PayToContractWithV1/V2/V3ReferenceScript

```go
func (a *Apollo) PayToContractWithV1ReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.PlutusV1Script, units ...Unit) (*Apollo, error)
func (a *Apollo) PayToContractWithV2ReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.PlutusV2Script, units ...Unit) (*Apollo, error)
func (a *Apollo) PayToContractWithV3ReferenceScript(addr common.Address, datum *common.Datum, lovelace int64, script common.PlutusV3Script, units ...Unit) (*Apollo, error)
```

Type-safe wrappers with inline datum. These delegate to the unified `PayToContractWithReferenceScript` method.

## Inputs and constraints

- Script is passed as `common.PlutusV1Script`, `common.PlutusV2Script`, `common.PlutusV3Script`, `common.PlutusV4Script`, or `common.NativeScript` (all from gouroboros). Loading from a file and optional CBOR decode is the application's responsibility. V4 is recognized but rejected by the current Conway payment methods; use a Dijkstra-capable transaction builder for V4.
- Outputs with a reference script are always built as post-Alonzo so that `ScriptRef` is present.

## Behavior details

- Reference scripts are stored in the output's `ScriptRef` field (post-Alonzo). `NewScriptRef(script)` wraps the script into a `common.ScriptRef` with the appropriate type code (0=Native, 1=V1, 2=V2, 3=V3, 4=V4).
- The unified method auto-detects the script version via Go type assertion.
- Duplicate scripts attached via `AttachScript` are automatically deduplicated by hash.

## Cardano CLI equivalence (10.14.0.0)

| CLI flag                                                                  | Apollo method                                                                                                     |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `--tx-out ADDRESS+AMOUNT` and `--tx-out-reference-script-file FILE` (V1)  | `PayToAddressWithV1ReferenceScript(addr, lovelace, script)` or `PayToAddressWithReferenceScript(addr, lovelace, v1Script)` |
| Same for V2                                                               | `PayToAddressWithV2ReferenceScript` / `PayToAddressWithReferenceScript`                                           |
| Same for V3                                                               | `PayToAddressWithV3ReferenceScript` / `PayToAddressWithReferenceScript`                                           |
| With datum + reference script                                             | `PayToContractWithReferenceScript(addr, &datum, lovelace, script)` or version-specific variant                    |

**Parity:** Full; script file loading is the application's responsibility.

## Examples

### Pay to address with V2 reference script (version-specific)

```go
import (
    "encoding/hex"
    "log"

    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

scriptHex := "5901ec01000032323232323232323232322........855d11"
scriptBytes, err := hex.DecodeString(scriptHex)
if err != nil {
    log.Fatal(err)
}
script := common.PlutusV2Script(scriptBytes)

a := apollo.New(cc)
a, err = a.PayToAddressWithV2ReferenceScript(addr, 5_000_000, script)
if err != nil {
    log.Fatal(err)
}
a.SetChangeAddress(changeAddr).AddLoadedUTxOs(utxos...)
tx, err := a.Complete()
```

### Pay to address with auto-detected script (unified)

```go
// Works with any script type
a, err = a.PayToAddressWithReferenceScript(addr, 5_000_000, script)
```

### Pay to contract with inline datum and V2 reference script

```go
datum := common.Datum{} // your Plutus data
a, err = a.PayToContractWithV2ReferenceScript(contractAddr, &datum, 5_000_000, script)
```

Or using the unified method:

```go
a, err = a.PayToContractWithReferenceScript(contractAddr, &datum, 5_000_000, script)
```

**Cardano CLI:**

```bash
cardano-cli transaction build \
    --tx-out "$CONTRACT_ADDRESS+5000000" \
    --tx-out-inline-datum-value '{"bytes":"Hello, World!"}' \
    --tx-out-reference-script-file plutus_sc.json \
    ...
```

## Caveats and validation

- Reference script **file** handling (read from disk, optional CBOR decode) is not part of Apollo; pass in the script as the appropriate gouroboros type.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.

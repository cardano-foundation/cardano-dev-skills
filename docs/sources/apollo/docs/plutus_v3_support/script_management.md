# Plutus V3 Script Management

This document details how Plutus V3 scripts are managed in Apollo v2. Script types are defined in gouroboros at `github.com/blinklabs-io/gouroboros/ledger/common`.

## `PlutusV3Script` Type

The `PlutusV3Script` type is defined in gouroboros and implements the `common.Script` interface.

```go
// From gouroboros/ledger/common
type PlutusV3Script []byte
```

All Plutus script types (`PlutusV1Script`, `PlutusV2Script`, `PlutusV3Script`, and `PlutusV4Script`) implement the `common.Script` interface:

```go
type Script interface {
    isScript()
    Hash() ScriptHash
    RawScriptBytes() []byte
}
```

## Attaching Scripts

Apollo v2 provides a single `AttachScript` method that accepts any `common.Script` implementation. The script version is detected automatically via Go's type system. Duplicate scripts (by hash) are ignored.

```go
func (a *Apollo) AttachScript(script common.Script) *Apollo
```

**Example Usage:**

```go
import (
    "encoding/hex"

    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
    "github.com/Salvionied/apollo/v2/backend/blockfrost"
    "github.com/Salvionied/apollo/v2/constants"
)

func main() {
    cc := blockfrost.NewBlockFrostChainContext(
        constants.BlockfrostBaseUrlPreview, 0, "your-project-id",
    )
    scriptBytes, err := hex.DecodeString("58...") // Compiled Plutus V3 script
    if err != nil {
        panic(err)
    }
    v3Script := common.PlutusV3Script(scriptBytes)

    a := apollo.New(cc)
    a.AttachScript(v3Script)

    // Works the same for V1 and V2 scripts:
    // a.AttachScript(v1Script)
    // a.AttachScript(v2Script)
}
```

## Script Hashing

The `Hash()` method on any script type returns a `ScriptHash` (alias for `Blake2b224`):

```go
scriptBytes, err := hex.DecodeString("58...")
if err != nil {
    panic(err)
}
v3Script := common.PlutusV3Script(scriptBytes)

hash := v3Script.Hash() // returns common.ScriptHash (common.Blake2b224)
fmt.Printf("Script hash: %s\n", hash.String())
```

## Script References

To attach a script as a reference script on a transaction output, use `NewScriptRef`:

```go
ref, err := apollo.NewScriptRef(v3Script) // auto-detects V3
if err != nil {
    // handle error
}
```

This recognizes all script types - the reference script type is determined automatically:
- `PlutusV1Script` -> type 1
- `PlutusV2Script` -> type 2
- `PlutusV3Script` -> type 3
- `PlutusV4Script` -> type 4 (Dijkstra only; Conway payment methods return `ErrPlutusV4RequiresDijkstra`)
- `NativeScript` -> type 0

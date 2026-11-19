# Plutus V3 Reference Inputs

This document covers the management of reference inputs in Apollo v2. Reference inputs allow scripts to inspect the contents of UTxOs without consuming them.

## Unified Reference Inputs

In Apollo v2, there is a single `AddReferenceInput` method for all script versions. The previous `AddReferenceInputV3` method has been removed - all reference inputs are handled identically regardless of script version.

```go
func (a *Apollo) AddReferenceInput(txHash string, index int) (*Apollo, error)
```

**Parameters:**

- `txHash string`: The hexadecimal string of the transaction hash containing the UTxO to reference.
- `index int`: The output index of the UTxO within the transaction.

**Example Usage:**

```go
import (
    apollo "github.com/Salvionied/apollo/v2"
    "github.com/Salvionied/apollo/v2/backend/blockfrost"
    "github.com/Salvionied/apollo/v2/constants"
)

func main() {
    cc := blockfrost.NewBlockFrostChainContext(
        constants.BlockfrostBaseUrlPreview, 0, "your-project-id",
    )
    a := apollo.New(cc)

    // Add a reference input (reference inputs are version-agnostic, including V4)
    txHash := "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
    a, err := a.AddReferenceInput(txHash, 0)
    if err != nil {
        // handle error
    }

    // Add multiple reference inputs
    txHash2 := "b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3"
    a, err = a.AddReferenceInput(txHash2, 1)
    if err != nil {
        // handle error
    }
}
```

## How Reference Inputs Work

Reference inputs are included in the transaction body's `TxReferenceInputs` field. They allow Plutus scripts to read UTxO data (including inline datums, reference scripts, and values) without spending the UTxO.

Common use cases:
- Reading oracle data from a UTxO
- Referencing a script stored on-chain (avoiding the need to include the full script in the witness set)
- Inspecting governance or protocol state

## Reference Scripts on Outputs

To store a script as a reference script in a transaction output (so it can be referenced later), use `PayToAddressWithReferenceScript`:

```go
scriptBytes, err := hex.DecodeString("58...")
if err != nil {
    log.Fatal(err)
}
v3Script := common.PlutusV3Script(scriptBytes)

// Store the script on-chain as a reference script
a, err = a.PayToAddressWithReferenceScript(addr, 2_000_000, v3Script)
if err != nil {
    // handle error
}
```

The script type is detected automatically. Version-specific convenience methods are also available: `PayToAddressWithV1ReferenceScript`, `PayToAddressWithV2ReferenceScript`, and `PayToAddressWithV3ReferenceScript`.

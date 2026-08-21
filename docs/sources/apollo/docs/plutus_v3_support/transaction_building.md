# Transaction Building with Plutus V3

Apollo v2 provides comprehensive support for building transactions with Plutus V3 scripts. This document details the key methods and patterns for working with V3 scripts. Plutus V4 is recognized by some underlying types, but requires Dijkstra-era transaction support and cannot currently be attached to Apollo's Conway transactions.

## Plutus V3 Fields in `Apollo`

The `Apollo` struct stores scripts internally by version for proper witness set construction, but the public API is unified:

- Scripts are attached via `AttachScript(script common.Script)` which auto-detects the version
- Reference inputs use a single `AddReferenceInput(txHash, index)` method for all script versions

## Attaching Plutus V3 Scripts

```go
import (
    "encoding/hex"
    "log"

    "github.com/blinklabs-io/gouroboros/ledger/common"
    apollo "github.com/Salvionied/apollo/v2"
)

func main() {
    scriptBytes, err := hex.DecodeString("58...")
    if err != nil {
        log.Fatal(err)
    }
    v3Script := common.PlutusV3Script(scriptBytes)

    a := apollo.New(cc)
    a.AttachScript(v3Script) // auto-detected as V3
}
```

Duplicate scripts are automatically deduplicated by hash.

## Adding Reference Inputs

```go
txHash := "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
a, err := a.AddReferenceInput(txHash, 0)
if err != nil {
    // handle error
}
```

## Collecting From Script UTxOs

To spend a UTxO locked by a Plutus V3 script, use `CollectFrom` with a redeemer:

```go
import "github.com/blinklabs-io/gouroboros/ledger/common"

redeemer := common.Datum{} // your redeemer datum
exUnits := common.ExUnits{Memory: 500000, Steps: 200000000}

a.CollectFrom(scriptUtxo, redeemer, exUnits)
```

## Minting with Plutus V3 Scripts

```go
unit := apollo.NewUnit(policyId, assetName, quantity)
redeemer := common.Datum{} // your minting redeemer
exUnits := common.ExUnits{Memory: 500000, Steps: 200000000}

a.AttachScript(v3MintingScript)
a.Mint(unit, &redeemer, &exUnits)
```

## Paying to Script Addresses

To send funds to a script address with an inline datum:

```go
datum := common.Datum{} // your datum
a.PayToContract(scriptAddr, &datum, 5_000_000)
```

To use a datum hash instead:

```go
a, err := a.PayToContractWithDatumHash(scriptAddr, &datum, 5_000_000)
if err != nil {
    // handle error
}
```

## Storing Reference Scripts On-Chain

To store a V3 script as a reference script in a transaction output:

```go
a, err := a.PayToAddressWithReferenceScript(addr, 20_000_000, v3Script)
if err != nil {
    // handle error
}
```

This creates an output with the script embedded as a reference script, allowing future transactions to reference it via `AddReferenceInput` instead of including the full script.

## Integration into Transaction Body and Witness Set

When `Complete()` is called:

- **Transaction Body**: Reference inputs are included in `TxReferenceInputs`. Minted assets are in `TxMint`.
- **Transaction Witness Set**: Attached V3 scripts are included in `WsPlutusV3Scripts`. Redeemers and datums are included in their respective fields.
- **Cost Models**: The Plutus V3 cost model from protocol parameters is used for script data hash computation when V3 scripts are present.

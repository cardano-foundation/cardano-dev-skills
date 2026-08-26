# Plutus Cost Models (V1, V2, V3, V4)

This document describes how Plutus cost models are handled in Apollo v2.

## Cost Model Overview

Cost models define the execution costs for each primitive operation in Plutus scripts. Each Plutus version has its own cost model with different parameters. These are part of the Cardano protocol parameters. Apollo can represent and hash V4 cost models, but the current Conway transaction builder only creates V1-V3 witnesses; V4 transaction support requires the Dijkstra-era ledger format.

## Cost Model Retrieval

In Apollo v2, cost models are retrieved from the chain context via `ProtocolParams()`:

```go
pp, err := cc.ProtocolParams()
if err != nil {
    // handle error
}
costModels := pp.CostModels // map[string][]int64
```

The `CostModels` map uses string keys: `"PlutusV1"`, `"PlutusV2"`, `"PlutusV3"`, and, when supplied by the backend, `"PlutusV4"`.

## Backend Integration

Each backend retrieves cost models from its respective data source:

### Blockfrost

Cost models are extracted from the Blockfrost protocol parameters API response.

### Ogmios

Cost models come from the Ogmios protocol parameters query.

### UTxO RPC

```go
costModels := map[string][]int64{
    "PlutusV1": ppCardano.GetCostModels().GetPlutusV1().GetValues(),
    "PlutusV2": ppCardano.GetCostModels().GetPlutusV2().GetValues(),
    "PlutusV3": ppCardano.GetCostModels().GetPlutusV3().GetValues(),
}
if v4 := ppCardano.GetCostModels().GetPlutusV4(); v4 != nil {
    costModels["PlutusV4"] = v4.GetValues()
}
```

## Script Data Hash

When a transaction contains Plutus scripts, a script data hash must be computed. This hash covers the redeemers, datums, and the relevant cost models. Apollo computes this automatically during `Complete()`:

```go
hash, err := apollo.ComputeScriptDataHash(redeemerMap, datums, pp.CostModels)
```

The `ComputeScriptDataHash` function:
1. CBOR-encodes the redeemers
2. CBOR-encodes the datums
3. CBOR-encodes the cost models as language views (keyed by language ID: 0=V1, 1=V2, 2=V3, 3=V4)
4. Concatenates all three byte arrays
5. Computes a Blake2b-256 hash of the concatenated bytes

This ensures that transactions include the correct cost model for each script language represented in the script data hash. A V4 cost model may be present in protocol parameters, but V4 scripts cannot currently be attached to Conway transactions through Apollo.

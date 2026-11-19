# Plutus V3 Support in Apollo

This documentation provides a comprehensive overview of Plutus V3 support within the Apollo v2 transaction building library. Apollo v2 uses [gouroboros](https://github.com/blinklabs-io/gouroboros) types natively, providing full Plutus V3 support through a unified script API.

## Key Changes in v2

- **Unified script API**: A single `AttachScript` method handles the Conway-supported script types (V1, V2, V3, and NativeScript) with automatic type detection. Plutus V4 is recognized by script-reference helpers but requires Dijkstra-era transaction support.
- **Unified reference inputs**: A single `AddReferenceInput` method works for all script versions
- **gouroboros types**: All Plutus types come from `github.com/blinklabs-io/gouroboros/ledger/common`

## Table of Contents

- [Transaction Building with Plutus V3](transaction_building.md)
- [Plutus V3 Script Management](script_management.md)
- [Plutus V3 Reference Inputs](reference_inputs.md)
- [Plutus V3 Cost Models](cost_models.md)
- [Plutus V3 Data Structures](data_structures.md)

## See also

- [Getting started](../getting_started/README.md) — Install, first transaction, fluent errors
- [Plutus encoder](../plutusencoder/README.md) — Struct-tag datums and redeemers
- [Data Attachment](../data_attachment/README.md) — Datums and reference scripts on outputs (including V1/V2/V3 reference scripts; V4 requires Dijkstra)
- [Fees and collateral](../fees_and_collateral/README.md) — Execution units and collateral overlap
- [Evaluation witnesses](../wallets/evaluation_witnesses.md) — Required signers during `EvaluateTx`
- [Staking Functionalities](../staking_functionalities/README.md) — Stake certificates and withdrawals

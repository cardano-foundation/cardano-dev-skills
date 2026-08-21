# Data Attachment in Apollo

This section documents how to attach **Plutus datums** (hash or inline) and **reference scripts** to transaction outputs when building transactions with the Apollo library. These features align with the transaction output datum and reference script flags in **cardano-cli** (version 10.14.0.0).

## Table of Contents

- [Pay-to-Contract and Datums](pay_to_contract_and_datums.md) — `PayToContract`, `PayToContractWithDatumHash`, `PayToContractAsHash`, `AddDatum`, `AttachDatum`; datum hash vs inline; examples and caveats
- [Reference Script Output Attachments](reference_script_output_attachments.md) — `PayToAddressWithReferenceScript` (unified) and `PayToAddressWithV1/V2/V3ReferenceScript` (convenience), `PayToContractWithReferenceScript` and version-specific variants; examples and caveats

## Terminology

- **Datum hash**: The hash of a Plutus datum is stored in the output; the full datum is in the transaction witness set. CLI: `--tx-out-datum-hash`, `--tx-out-datum-hash-file`, etc.
- **Inline datum**: The full datum is embedded in the output. CLI: `--tx-out-inline-datum-`*, `--tx-out-datum-embed-*`.
- **Reference script**: A script attached to an output so that other transactions can reference it without including the script bytes. CLI: `--tx-out-reference-script-file`.

## CLI-to-Apollo Mapping Index


| Cardano CLI (10.14.0.0)                              | Apollo method / pattern                                                               | Parity                             |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------- |
| `--tx-out-datum-hash` / `-file` / `-value`           | `PayToContractWithDatumHash(addr, datum, lovelace)` or `PayToContractAsHash(addr, hash, lovelace)` | Full (manual parse for file/value) |
| `--tx-out-datum-embed-`* / `--tx-out-inline-datum-*` | `PayToContract(addr, datum, lovelace)`                                                | Full (manual parse for file/value) |
| `--tx-out-reference-script-file` (V1/V2/V3)          | `PayToAddressWithV1/V2/V3ReferenceScript`, `PayToContractWithV1/V2/V3ReferenceScript` | Full                               |


Each functionality page above includes method signatures, behavior, side-by-side Apollo + CLI examples, evidence labels, and caveats.

Plutus V4 reference scripts are recognized by the underlying types, but the current Conway transaction builder rejects V4 reference-script payments with `ErrPlutusV4RequiresDijkstra`; V4 requires Dijkstra-era transaction support.

## See also

- [Staking Functionalities](../staking_functionalities/README.md) — Stake certificates and withdrawals
- [Plutus V3 Support](../plutus_v3_support/README.md) — Plutus V3 scripts and reference inputs

## Reference

- [Cardano CLI repository](https://github.com/IntersectMBO/cardano-cli) — CLI command reference (10.14.0.0)

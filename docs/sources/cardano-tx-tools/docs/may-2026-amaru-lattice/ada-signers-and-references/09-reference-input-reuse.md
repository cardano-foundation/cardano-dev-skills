# Query 09 - Reference Input Reuse

## Result

The query returns the 10 most reused reference inputs.

| referencedTxId | ix | usingTxs |
| --- | ---: | ---: |
| `f5f1bdfad3eb4d67d2fc36f36f47fc2938cf6f001689184ab320735a28642cf2` | 0 | 52 |
| `0bbd502d7bdaadb0e928a1dc5510564bbfe8cc9f907f5bdc5d6e55021edd8e7c` | 0 | 51 |
| `fa46a1d162c59cece3308c5a9d4db9ff2ea17f9c0146ff821c9b445588b017c9` | 0 | 51 |
| `11ace24a7b0caad4a68a38ef2fff18185dc9ea604e84425dab487cae94e4cf54` | 0 | 32 |
| `810bfcbde85ae72f27d7e8cd154c03c802de15d3fa0dd83a32a4b0fdba330b3c` | 0 | 32 |
| `e7b395a93d49a17994d66df0e4778a01dee05e7711e6612f28d97b63e4e6311c` | 2 | 32 |
| `25ba96f5deb14bb5c56e7542d6a9ba8450f52cc698ebd74574e1a0525d861095` | 2 | 31 |
| `25ba96f5deb14bb5c56e7542d6a9ba8450f52cc698ebd74574e1a0525d861095` | 4 | 1 |
| `b25328336bbba240d5906952534e84bb8edf1a690f86a4160c38703396853c90` | 0 | 1 |
| `e7b395a93d49a17994d66df0e4778a01dee05e7711e6612f28d97b63e4e6311c` | 4 | 1 |

## What

This query shows which reference UTxOs are reused most often by the
85-transaction lattice.

It counts distinct using transactions per referenced `(txid, index)`.

## Why

Reference inputs are not spent, but they are part of the transaction
body and often point to scripts, datums, or protocol-side support UTxOs.
Seeing heavy reuse helps explain why the graph has many reference-input
edges without requiring those referenced parents to be in the 85-tx
state proof.

## Diagram

```mermaid
flowchart LR
  txs[85 transaction nodes]
  refs[reference input edges]
  targets[referenced UTxOs]
  ranking[reuse ranking]

  txs --> refs
  refs --> targets
  targets --> ranking
```

## How

The query follows each `cardano:hasReferenceInput` edge to its
`fromTxOutRef`, groups by referenced transaction id and output index,
and counts distinct transactions that use that reference.

It orders by `usingTxs` descending and returns the top 10.

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/ada-signers-and-references/09-reference-input-reuse.rq
```

## SPARQL

```sparql
--8<-- "docs/may-2026-amaru-lattice/ada-signers-and-references/09-reference-input-reuse.rq"
```

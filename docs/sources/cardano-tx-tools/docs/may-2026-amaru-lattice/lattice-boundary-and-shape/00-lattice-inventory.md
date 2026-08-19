# Query 00 - Lattice Inventory

## Result

This table is the CSV result produced by Apache Jena over the
85-transaction graph. ADA quantities are decimal ADA.

| transactions | outputs | spendingInputs | referenceInputs | collateralInputs | totalFeeAda | minFeeAda | maxFeeAda |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 85 | 429 | 422 | 284 | 85 | 57.138022 | 0.244261 | 1.572508 |

## What

This is the structural inventory of the loaded lattice. It answers the
first sanity question: "what graph did the rest of the report actually
query?"

The answer is 85 transaction subjects, 429 outputs, 422 spending-input
edges, 284 reference-input edges, and 85 collateral-input edges.

## Why

Every later proof depends on this boundary being explicit. If the query
accidentally counts referenced transaction ids or overlay metadata as
transactions, the rest of the report can look plausible while running on
the wrong shape.

This query therefore counts only RDF subjects typed as
`cardano:Transaction` for the transaction total. The remaining columns
count emitted graph edges.

## Diagram

```mermaid
flowchart LR
  txs[85 transaction nodes]
  outs[429 outputs]
  spend[422 spending inputs]
  refs[284 reference inputs]
  collateral[85 collateral inputs]
  fees[fee range and total]

  txs --> outs
  txs --> spend
  txs --> refs
  txs --> collateral
  txs --> fees
```

## How

The query uses independent aggregate subqueries so that outputs, inputs,
references, collateral inputs, and fees do not multiply each other in a
single large join.

The transaction aggregate is restricted to `a cardano:Transaction`.
That distinction matters because transaction-output references also
contain transaction ids, but they are not transactions in the loaded
graph.

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/lattice-boundary-and-shape/00-lattice-inventory.rq
```

## SPARQL

```sparql
--8<-- "docs/may-2026-amaru-lattice/lattice-boundary-and-shape/00-lattice-inventory.rq"
```

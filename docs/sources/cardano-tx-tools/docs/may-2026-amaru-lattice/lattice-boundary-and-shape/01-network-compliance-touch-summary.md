# Query 01 - Network Compliance Touch Summary

## Result

| touchKind | txs |
| --- | ---: |
| consumes-and-produces | 31 |
| produces-only | 54 |

## What

This query classifies every transaction that touches the
`amaru-treasury.network_compliance` address.

A transaction is `produces-only` when it creates a network_compliance
output and does not spend a previous one in the loaded lattice. A
transaction is `consumes-and-produces` when it spends a resolved
network_compliance output and emits a new one.

## Why

This tells us how the address state evolves inside the 85 transactions.
The 54 `produces-only` transactions introduce outputs at the treasury
address. The 31 `consumes-and-produces` transactions roll an existing
treasury UTxO forward.

There are no `consumes-only` rows in this result, which is consistent
with the later terminal-state proof: every in-scope treasury spend also
produces a replacement or payment/change shape visible in the graph.

## Diagram

```mermaid
flowchart LR
  producer[produces-only tx]
  rolling[consumes-and-produces tx]
  treasury[network_compliance UTxO set]

  producer --> treasury
  treasury --> rolling
  rolling --> treasury
```

## How

The query resolves the network_compliance bech32 address from
`rules.yaml`, then computes two boolean tests per transaction.

The first test checks whether the transaction emits an output at that
address. The second test follows each input reference back to a loaded
output and checks whether the source output was at the same address.

The final `touchKind` is derived from those two tests.

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/lattice-boundary-and-shape/01-network-compliance-touch-summary.rq
```

## SPARQL

```sparql
--8<-- "docs/may-2026-amaru-lattice/lattice-boundary-and-shape/01-network-compliance-touch-summary.rq"
```

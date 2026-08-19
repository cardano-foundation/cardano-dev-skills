# Query 14 - Network Compliance Terminal State


## Result

This table is the CSV result produced by Apache Jena over the state-audit
graph at the live snapshot boundary. ADA quantities are decimal ADA; USDM
quantities are decimal USDM.

| txId | ix | ada | usdm |
| --- | ---: | ---: | ---: |
| `44454ed0def64621ef645958830f599b488b699b28e3797cc37c4f4dd1463a79` | 1 | 2.000000 | 0.000000 |
| `68a1277af23755376967e788752c603044f45ea0d99220b3b5dfc7d617642b6b` | 1 | 2.306000 | 5011.215241 |
| `affe90d1fa9a93b3e2a48009ef80634e9de8428640f5d673e85b002a86399982` | 0 | 120.299272 | 1349.523953 |
| `cda0126e9ea7b336bbb338d2bfc7622a41b584e3bebc33c9c320e8895b9bc082` | 1 | 2.306000 | 10.439974 |
| `cda0126e9ea7b336bbb338d2bfc7622a41b584e3bebc33c9c320e8895b9bc082` | 2 | 2.306000 | 10.439524 |

## What

This query computes the graph-derived terminal UTxO set for the
network_compliance treasury address. It lists outputs at that address
whose `(txid, index)` is not consumed by any transaction in the loaded
graph.

For each terminal UTxO, it reports tx id, output index, decimal ADA, and
USDM quantity.

## Why

This is the core state-reconstruction query. The user-facing claim is:
given a start graph and all transactions in the interval, we should be
able to recompute the ending state. If this graph-derived terminal set
does not match the expected current state at the chosen boundary, that
is a bug in graph completeness, graph emission, or the boundary
definition.

For the final-state proof, "all transactions" means every transaction
that can produce or spend a network_compliance output before the live
snapshot boundary. That is why this page uses the 85-tx
network_compliance graph boundary rather than a partial transaction
sample.

The query asks for every terminal network_compliance output visible in
the loaded graph. No special transaction role is required: a lattice is
just the transaction set loaded into the SPARQL dataset.

## Diagram

```mermaid
flowchart LR
  loadedGraph[Loaded graph]
  candidates[Network compliance outputs]
  spent[Inputs in graph]
  filter[Remove spent outputs]
  terminal[Terminal UTxO set]
  totals[ADA and USDM values]

  loadedGraph --> candidates
  loadedGraph --> spent
  candidates --> filter
  spent --> filter
  filter --> terminal
  terminal --> totals
```

## How

The query resolves the network_compliance address from `rules.yaml` and
pins the full on-chain USDM asset id in a `VALUES` block. It scans the
loaded graph for outputs at that address.

For each candidate output, it rejects any output whose `(txid, index)`
appears as an input reference anywhere in the loaded graph:

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/final-network-compliance-state/14-network-compliance-terminal-state.rq
```

## SPARQL

```sparql
FILTER NOT EXISTS {
  ?spendingTx cardano:hasInput ?input .
  ?input cardano:fromTxOutRef ?ref .
  ?ref cardano:hasTxId/cardano:bytesHex ?txId ;
       cardano:hasIndex ?ix .
}
```

That is the UTxO-set rule expressed directly in SPARQL: an output is
unspent in the graph if no input in the graph spends it.

The optional asset branch sums USDM on each terminal output. Outputs
without USDM remain in the result with a zero USDM aggregate. This makes
the result suitable for comparing both ADA and USDM state.

```sparql
--8<-- "docs/may-2026-amaru-lattice/final-network-compliance-state/14-network-compliance-terminal-state.rq"
```

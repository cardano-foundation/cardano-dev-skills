# Query 16 - Network Compliance Live Summary


## Result

This table is the CSV result produced by Apache Jena over the state-audit
graph at the live snapshot boundary. ADA quantities are decimal ADA; USDM
quantities are decimal USDM.

| graphTerminalUtxos | graphTerminalAda | graphTerminalUsdm | liveUtxos | liveAda | liveUsdm | adaGap | usdmGap |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 5 | 129.217272 | 6381.618692 | 5 | 129.217272 | 6381.618692 | 0.000000 | 0.000000 |

## What

This query is the aggregate form of Query 15. It compares graph-derived
terminal totals with live-node totals for network_compliance and reports
the UTxO count, ADA, and USDM gap.

It does not identify individual mismatching UTxOs. It tells whether the
two state views balance at the summary level.

## Why

The row-level diff is best for debugging. The summary is best for a
quick correctness gate and for presentation. A zero ADA gap and zero
USDM gap means the graph-derived terminal state and live overlay agree
in aggregate.

This is useful after fixing row-level mismatches. Once Query 15 returns
no rows, Query 16 should also show zero gaps. If Query 16 shows a gap,
use Query 15 to find the exact rows causing it.

This is also the direct answer to the USDM accounting question: the live
snapshot contains 6,381.618692 USDM at network_compliance, and the graph
recomputes the same amount from the loaded transactions.

## Diagram

```mermaid
flowchart LR
  graphSet[Graph terminal set]
  graphTotals[Graph totals]
  live[Live UTxO overlay]
  liveTotals[Live totals]
  gaps[Summary gaps]
  pass[Zero gap gate]

  graphSet --> graphTotals
  live --> liveTotals
  graphTotals --> gaps
  liveTotals --> gaps
  gaps --> pass
```

## How

The query contains two subqueries.

The graph subquery recomputes the terminal network_compliance UTxO set:
all outputs at the network_compliance address for which no loaded input
spends the same `(txid, index)`. It counts those terminal outputs and
sums ADA and USDM.

The live subquery scans the `live:CurrentUtxo` overlay and counts/sums
the live rows.

The final projection computes:

```text
liveLovelace - graphTerminalLovelace
liveUsdm - graphTerminalUsdm
```

Positive gaps mean the live overlay has more value than the graph's
terminal set. Negative gaps mean the graph terminal set has more value
than the live overlay. A correct complete graph at the same boundary
should produce zero for both gaps.

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/final-network-compliance-state/16-network-compliance-live-summary.rq
```

## SPARQL

```sparql
--8<-- "docs/may-2026-amaru-lattice/final-network-compliance-state/16-network-compliance-live-summary.rq"
```

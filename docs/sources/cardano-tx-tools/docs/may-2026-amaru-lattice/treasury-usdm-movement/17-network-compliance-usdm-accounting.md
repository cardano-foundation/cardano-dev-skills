# Query 17 - Network Compliance USDM Accounting


## Result

This table is the CSV result produced by Apache Jena over the
state-audit graph. USDM quantities are decimal USDM.

| treasuryLabel | treasuryAddress | startUsdm | swapReceiptTxs | swapReceiptsUsdm | beneficiaryPaymentTxs | beneficiaryPaymentsUsdm | terminalUtxos | terminalUsdm | usdmGap |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| amaru-treasury.network_compliance | `addr1xyezq8wpaqnssdjvd3p220uf7e6nzjae44w6yu625y965rfjyqwur6p8pqmycmzz55lcnan4x99mnt2a5fe54ggt4gxs8thzgk` | 0.000000 | 51 | 425131.618692 | 2 | 418750.000000 | 5 | 6381.618692 | 0.000000 |

```text
0 + 425,131.618692 - 418,750.000000 - 6,381.618692 = 0
```

## What

This query is the user-facing balance sheet for the May 2026
network_compliance USDM flow. It names the treasury address and reduces
the graph to one accounting equation:

```text
start USDM + swap receipts - beneficiary payments - terminal USDM = gap
```

The query makes the opening state an explicit initial condition. For the
May report that initial condition is zero USDM because the selected
interval begins before any network_compliance USDM receipts. It then
derives all other values from emitted graph structure.

## Why

This is the direct answer to "why is there 6k USDM left?". The remainder
is not inferred from prose and it is not a live-node lookup. It is the
graph recomputing the equation from transactions:

- 51 swap receipt transactions return `425,131.618692` USDM to
  network_compliance.
- 2 beneficiary payment transactions send `418,750.000000` USDM to the
  CAG payee bridge.
- 5 terminal network_compliance UTxOs hold `6,381.618692` USDM.
- The accounting gap is zero.

## Diagram

```mermaid
flowchart LR
  start[Start state: 0 USDM]
  swaps[Sundae V3 swap receipts]
  pay[CAG payee outputs]
  terminal[Terminal network_compliance UTxOs]
  gap[Accounting gap]

  start --> equation[USDM equation]
  swaps --> equation
  pay --> equation
  terminal --> equation
  equation --> gap
```

## How

The query uses four independent subqueries.

The first subquery identifies the network_compliance treasury address
from the rule label. It projects the address so the answer names the
state being checked.

The swap-receipt subquery finds transactions that both consume a
SundaeSwap V3 order script output and emit USDM to the network_compliance
address. It groups by producer transaction before summing, so a scoop
that consumes multiple order inputs does not multiply the returned USDM.

The beneficiary-payment subquery sums USDM outputs to `amaru.cag-payee`.
This is the payee bridge address used by the May payments.

The terminal-state subquery uses the same terminal UTxO test as Query 14:
an output is terminal when no loaded transaction spends its `(txid,
index)`. That proves the remaining USDM from graph topology, not from a
cached balance.

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/treasury-usdm-movement/17-network-compliance-usdm-accounting.rq
```

## SPARQL

```sparql
--8<-- "docs/may-2026-amaru-lattice/treasury-usdm-movement/17-network-compliance-usdm-accounting.rq"
```

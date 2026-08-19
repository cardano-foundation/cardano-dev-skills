# Query 10 - Swap Consumer Output Roles

## Result

ADA quantities are decimal ADA. USDM quantities are decimal USDM.

| outputRole | outputs | ada | usdm |
| --- | ---: | ---: | ---: |
| wallet.other | 249 | 96254260.243609 | 24525287.591011 |
| amaru-treasury.network_compliance | 55 | 52949.457333 | 425131.618692 |
| amaru.network-operator | 1 | 19.755739 | 0.000000 |

## What

This query looks at all outputs produced by the 51 SundaeSwap V3 order
consumer transactions and groups those outputs by resolved address role.

It is wider than Query 19. Query 19 only looks at USDM returned to
network_compliance; this query shows what else those same swap-consumer
transactions emitted.

## Why

The key line is `amaru-treasury.network_compliance`: 55 outputs carrying
`425,131.618692` USDM. That agrees with Query 17 and Query 19.

The `wallet.other` row is not treasury income. It is the rest of the
swap-consumer output surface, grouped as unlabeled wallet/script
addresses because those addresses are not declared in `rules.yaml`.

## Diagram

```mermaid
flowchart LR
  orders[Sundae V3 order inputs]
  consumers[Swap consumer txs]
  outputs[All consumer outputs]
  roles[Address roles]
  nc[network_compliance receipts]

  orders --> consumers
  consumers --> outputs
  outputs --> roles
  roles --> nc
```

## How

The query first identifies swap consumers by proving that they consume
outputs at the SundaeSwap V3 order script hash.

It then emits one row per produced output, resolves the output address
role from the rules overlay when available, samples one role per output
to avoid repeated overlay facts, and finally groups by role.

USDM is matched by the full asset id, not by ticker.

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/swaps-and-exchange-rates/10-swap-consumer-output-roles.rq
```

## SPARQL

```sparql
--8<-- "docs/may-2026-amaru-lattice/swaps-and-exchange-rates/10-swap-consumer-output-roles.rq"
```

# Query 04 - Required Signer Distribution

## Result

| requiredSigners | txs |
| ---: | ---: |
| 4 | 1 |
| 2 | 27 |
| 1 | 56 |
| 0 | 1 |

## What

This query groups the 85 transaction nodes by how many required signer
credentials their bodies declare.

It is a transaction-body shape check, not a witness validation check.

## Why

Required signer distribution is useful when reading treasury activity
because it separates simple one-signer movements from multi-signer or
policy-gated actions. A sudden row with many unexpected signers, or many
zero-signer transactions, would be a reason to inspect the body set.

Here the distribution is compact: 84 of 85 transactions declare at least
one required signer, and one transaction declares none.

## Diagram

```mermaid
flowchart LR
  txs[85 transaction nodes]
  signers[hasRequiredSigner edges]
  buckets[0, 1, 2, or 4 signer buckets]

  txs --> signers
  signers --> buckets
```

## How

The inner query groups by transaction node and counts distinct
`cardano:hasRequiredSigner` edges. It restricts the subject to
`a cardano:Transaction` so referenced transaction ids are not counted as
zero-signer transactions.

The outer query groups those per-transaction counts into the displayed
distribution.

## Run

From the repository root, run this query through the tutorial setup script:

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/ada-signers-and-references/04-required-signer-distribution.rq
```

## SPARQL

```sparql
--8<-- "docs/may-2026-amaru-lattice/ada-signers-and-references/04-required-signer-distribution.rq"
```

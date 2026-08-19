# Run The Report

This page is the executable path for the May 2026 report. It prepares
the bounded graph from the 85 transaction ids, then runs the SPARQL
queries against that graph and the live UTxO snapshot.

The commands below assume a checkout of this repository. The only
external secret is the Blockfrost project id used by `tx-fetch`. The
provider responsibilities and API requests are listed on the
[Blockfrost provider](blockfrost-provider.md) page.

## One-Time Environment

Set the Blockfrost key and, optionally, the working directory where CBOR
and Turtle files will be written.

```bash
export BLOCKFROST_PROJECT_ID=mainnet...
export MAY_2026_WORK_DIR=/tmp/cardano-tx-tools-may-2026-lattice
```

## Run One Query

Pass a single `.rq` path to run only that query. The setup script still
prepares the graph first, so the query sees the same data as the
published result.

```bash
bash docs/may-2026-amaru-lattice/setup.sh \
  docs/may-2026-amaru-lattice/swaps-and-exchange-rates/19-swap-receipts-and-rates.rq
```

## Run All Queries

With no query arguments, the script discovers every report query under
the May report directory and runs them in path order.

```bash
bash docs/may-2026-amaru-lattice/setup.sh
```

## Path Setup

The script finds the repository root, the report directory, and the
working directory. `MAY_2026_WORK_DIR` is intentionally outside the docs
tree so fetched CBOR and generated Turtle do not pollute the published
site.

```bash
--8<-- "docs/may-2026-amaru-lattice/setup.sh:paths"
```

## Preflight

The fetch stage needs Blockfrost only for transaction CBOR. The txid
boundary is fixed by the checked-in `network-txs.txt` file rendered on
the report index.

```bash
--8<-- "docs/may-2026-amaru-lattice/setup.sh:preflight"
```

## Fetch CBOR

`tx-fetch` reads the 85 txids from the boundary file, uses depth `0`,
and writes verified transaction CBOR files under `$WORK_DIR/cbor`.

```bash
--8<-- "docs/may-2026-amaru-lattice/setup.sh:fetch"
```

## Emit Turtle

`tx-graph` indexes the fetched CBOR set in memory and emits one Turtle
file per transaction under `$WORK_DIR/ttl`.

```bash
--8<-- "docs/may-2026-amaru-lattice/setup.sh:graph"
```

## Build Query Inputs

Every query runs against all emitted transaction Turtle files. The live
snapshot is also loaded for the live-state comparison queries; queries
that do not use it simply ignore those triples.

```bash
--8<-- "docs/may-2026-amaru-lattice/setup.sh:data"
```

## Select Queries

Passing explicit query paths runs only those queries. Passing no query
paths runs the whole report.

```bash
--8<-- "docs/may-2026-amaru-lattice/setup.sh:select"
```

## Execute SPARQL

If `sparql` is already on `PATH`, the script uses it directly. If not,
it runs Apache Jena from Nix for the query invocation.

```bash
--8<-- "docs/may-2026-amaru-lattice/setup.sh:run"
```

# tx-fetch

Closure-walking Conway CBOR fetcher. Given a list of transaction
ids and a Blockfrost-compatible chain source, walks each transaction's
spending / reference / collateral input parents up to `--depth`,
hash-verifies every fetched CBOR against its requested `TxId`, and
writes one `<out-dir>/cbor/<txid-hex>.cbor` per tx in the closure.

`tx-fetch` is the network stage of the RDF graph pipeline:

| Stage | Input | Output | Side effects |
|--|--|--|--|
| **tx-fetch** | input txids + chain source | `<dir>/cbor/<txid>.cbor` per tx | network I/O |
| [tx-graph](tx-graph.md) | `<dir>/cbor` + rules.yaml | `<dir>/<txid>.ttl` per tx | none |
| [tx-view](tx-view.md) | `<txid>.ttl` + view name | projection bytes | none |

```text
tx-fetch — Conway closure CBOR fetcher

Usage: tx-fetch --out-dir DIR [--network NETWORK] [--depth N] TXID...

  Resolves input txids over Blockfrost's /txs/<hash>/cbor endpoint, walks
  parent references to --depth, and writes one <DIR>/cbor/<txid>.cbor per
  tx. BLOCKFROST_PROJECT_ID env required.

Available options:
  --out-dir DIR            Output directory. Writes <DIR>/cbor/<txid>.cbor for
                           every tx in the closure.
  --network NETWORK        Cardano network the txids belong to: mainnet |
                           preprod | preview. (default: Mainnet)
  --depth N                BFS depth. 0 = fetch only the input txids; 1 = add
                           direct input parents; 2 = add the parents' parents;
                           and so on. (default: 1)
  TXID...                  Transaction ids (lowercase hex).
  -h,--help                Show this help text
```

## Environment

| Variable | Purpose |
|--|--|
| `BLOCKFROST_PROJECT_ID` | required. Blockfrost API key used as the `project_id` header on every `/txs/<hash>/cbor` GET. |

## Output layout

```text
<out-dir>/
  cbor/
    <txid-hex>.cbor   # one file per tx in the closure
    ...
```

## Hash verification

Every fetched CBOR is parsed via the same polymorphic decoder
[`tx-graph`](tx-graph.md) and [`tx-diff`](tx-diff.md) use, its `TxId`
is recomputed as `hashAnnotated . bodyTxL`, and the result is rejected
with exit code 1 if the computed id does not match the id used in the
request. Chain-source forgery or on-disk corruption surfaces
immediately instead of polluting the lattice.

## Resumability

Existing `<out-dir>/cbor/<txid>.cbor` files are skipped on re-run.
Hash verification still runs against the cached bytes, so a corrupted
cache surfaces as an error rather than a silent stale read.

## Typical workflow

```bash
# 1. Fetch the closure of a transaction list, depth 1.
export BLOCKFROST_PROJECT_ID=mainnet...
tx-fetch --out-dir lattice --depth 1 \
    013329ee... 107e439f... 11ace24a...

# 2. Emit one Turtle file per tx, with operator overlay merged in.
tx-graph --rules rules.yaml --in-dir lattice/cbor --out-dir lattice

# 3. Query across the lattice with any SPARQL engine.
nix-shell -p apache-jena --run \
    "sparql $(printf -- '--data %s ' lattice/*.ttl) \
        --query queries/per-scope-flow.rq"
```

## Exit codes

| Code | Meaning |
|--|--|
| 0 | Closure fetched successfully. |
| 1 | Fetch / decode / hash-mismatch error on at least one tx. |
| ≥2 | Usage error (missing flags, malformed txid, missing env). |

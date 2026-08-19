# Blockfrost Provider

The May 2026 report uses Blockfrost only as an evidence provider before
SPARQL starts. The proof itself is not a Blockfrost proof: `tx-graph`
emits RDF from signed transaction CBOR, and the report queries run over
those Turtle files plus the checked-in live UTxO snapshot.

Blockfrost is used because the report needs two chain-index operations
that are outside the graph:

- find the complete transaction history for the scoped
  `amaru-treasury.network_compliance` address through the chosen end
  boundary,
- fetch the exact signed transaction CBOR for each selected txid.

A local `cardano-node` can answer the live UTxO query used to build
`live-utxos.ttl`, but it does not by itself provide a convenient
historical address index or arbitrary historical transaction CBOR by
txid. Going without Blockfrost is fine, but then the operator must bring
an equivalent source for those two facts: for example db-sync plus an
archive/indexer that can return exact transaction CBOR, or another
Blockfrost-compatible provider.

```mermaid
flowchart LR
  address[network_compliance address]
  history[Address transaction history]
  txids[85 txid boundary]
  cbor[CBOR files]
  ttl[tx-graph Turtle]
  live[cardano-cli live UTxO snapshot]
  sparql[SPARQL report]

  address --> history
  history --> txids
  txids --> cbor
  cbor --> ttl
  ttl --> sparql
  live --> sparql
```

## APIs Touched

These are the Blockfrost API shapes used for this report.

| Purpose | HTTP request | Consumer | Output |
|--|--|--|--|
| Select the report boundary | `GET /addresses/{address}/transactions?order=asc&page={page}&count=100` | operator boundary-selection step | `network-txs.txt` |
| Fetch signed transaction bytes | `GET /txs/{hash}/cbor` | `tx-fetch` | `$MAY_2026_WORK_DIR/cbor/{hash}.cbor` |

The scripted report does not call `/addresses/{address}/utxos`,
`/txs/{hash}`, `/txs/{hash}/utxos`, `/epochs/latest/parameters`, or
`/blocks/latest`. The live-state comparison uses the checked-in
`live-utxos.ttl` file. That file records its source as
`cardano-cli conway query utxo --mainnet` at block `13,467,438`, slot
`188,217,701`.

## Address History Query

The address-history query is how the 85-tx boundary was selected. It is
not run by `setup.sh`; it is the operator step that produces the
checked-in `network-txs.txt` boundary file.

```bash
ADDRESS=addr1xyezq8wpaqnssdjvd3p220uf7e6nzjae44w6yu625y965rfjyqwur6p8pqmycmzz55lcnan4x99mnt2a5fe54ggt4gxs8thzgk

curl -sS \
  -H "project_id: $BLOCKFROST_PROJECT_ID" \
  "https://cardano-mainnet.blockfrost.io/api/v0/addresses/$ADDRESS/transactions?order=asc&page=1&count=100"
```

Repeat the same request with `page=2`, `page=3`, and so on until the
chosen end boundary is reached. Keep only transactions in the audited
interval that touch the scoped address, either by producing an output at
that address or by spending a previous output from it. The resulting
txids are persisted one per line in `network-txs.txt`.

The important correctness condition is not "Blockfrost was used"; it is
"the selected txid set is complete for the scoped address and interval."
If another provider can produce the same ordered address history through
the same block and slot boundary, it can replace this step.

## Transaction CBOR Query

`tx-fetch` performs the CBOR fetch. For this report it runs at depth
`0`, so a cold run fetches exactly the 85 txids in `network-txs.txt` and
does not walk generic parents.

```bash
export BLOCKFROST_PROJECT_ID=mainnet...
export MAY_2026_WORK_DIR=/tmp/cardano-tx-tools-may-2026-lattice
mapfile -t TXIDS < docs/may-2026-amaru-lattice/network-txs.txt

nix run .#tx-fetch -- \
  --out-dir "$MAY_2026_WORK_DIR" \
  --network mainnet \
  --depth 0 \
  "${TXIDS[@]}"
```

To print the exact CBOR request paths implied by the checked-in
boundary:

```bash
sed 's#^#GET /txs/#; s#$#/cbor#' \
  docs/may-2026-amaru-lattice/network-txs.txt
```

Internally each uncached transaction becomes this request shape:

```bash
TXID=64f27254f3c0311fb2e672cdb87de200089a596aa90dc09f8be4248540267cf0

curl -sS \
  -H "project_id: $BLOCKFROST_PROJECT_ID" \
  "https://cardano-mainnet.blockfrost.io/api/v0/txs/$TXID/cbor"
```

The response must contain a JSON `cbor` field. `tx-fetch` decodes those
bytes as a Conway transaction, recomputes the transaction id from the
body, and rejects the file if the computed id differs from the requested
hash. Existing local CBOR files are reused on later runs, but they are
still decoded and hash-checked before `tx-graph` sees them.

## Replacing Blockfrost

To reproduce the report without Blockfrost, provide the same evidence
with different tooling:

| Needed fact | Required semantics |
|--|--|
| Address-history boundary | Ordered transactions for the scoped address through block `13,467,438`, slot `188,217,701`, with enough information to keep the in-interval producers and spenders. |
| Transaction CBOR | Exact signed Conway transaction CBOR for each txid in `network-txs.txt`; the computed transaction id must match the requested hash. |
| Live terminal UTxO | UTxOs at the scoped address at the same end boundary, encoded in the `live:CurrentUtxo` shape used by `live-utxos.ttl`. |

Once those inputs exist, the rest of the report is provider-neutral:
`tx-graph` reads local CBOR, emits Turtle, and the SPARQL queries compute
the balances and terminal state from graph topology.

# tx-graph

Emit one Conway transaction, or a bounded set of Conway transaction
CBOR files, as RDF. The emitted graph contains the optional
operator-entity overlay, the transaction body (inputs, outputs,
addresses with payment + stake credentials, fee, mint, withdrawal,
certificates, collateral, proposals), and their cross-references in
canonical Turtle or JSON-LD. When the rules file registers a CIP-57
blueprint for a script, Plutus datum and redeemer fields are decoded
into typed fixture-local predicates; decode failures keep the raw
bytes and add a `cardano:decodeError` literal.

`tx-graph` is a pure transformation. It does not query a node, read a
UTxO JSON file, or fetch missing transactions. If a parent transaction
is present in the input set, the input is resolved from that in-memory
set; otherwise the graph remains well-formed and the missing parent is
reported on stderr.

```text
tx-graph — pure (rules + [cbor]) → ttl transformation

Usage: tx-graph [--rules FILE] [--in-dir DIR] [--out-dir DIR]
                [--format FORMAT] [CBOR...]

  tx-graph — operator-entity overlay + body emitter. Loads operator-authored
  rules (overlay-only mode) or drives the joint-graph body emitter on a lattice
  of Conway transactions (--in-dir / positional / stdin). The lattice resolves
  itself internally — no node, no UTxO file, no external chain source. Output
  format defaults to Turtle.

Available options:
  --rules FILE             Operator-authored rules file (.yaml/.yml or .ttl).
                           Used alone, emits overlay-only Turtle to stdout.
                           Combined with inputs, merged into the joint graph(s).
  --in-dir DIR             Directory of *.cbor files; each is one Conway
                           transaction in the input lattice. Mutually exclusive
                           with positional arguments.
  --out-dir DIR            Write one <txid-hex>.ttl per input into DIR. If
                           absent and exactly one input is given, emits to
                           stdout.
  --format FORMAT          Output format: 'turtle' or 'json-ld'.
                           (default: "turtle")
  CBOR...                  Conway tx CBOR file paths. '-' reads one tx from
                           stdin. Mutually exclusive with --in-dir.
  -h,--help                Show this help text
```

## Input modes

| Input | Rules | Output | Behaviour |
|-------|-------|--------|-----------|
| `--rules rules.yaml` only | required | stdout | **Overlay only** — emits the operator-entity overlay (`cardano:Entity` + `cardano:Identifier` blocks for every entity in the rules file). |
| one positional CBOR path, or `-` | optional | stdout unless `--out-dir` is supplied | **Single graph** — emits the transaction body and, when rules are supplied, the overlay plus entity-labelled credentials. |
| multiple positional CBOR paths | optional | `--out-dir DIR` required | **Batch graph emission** — computes every tx id, indexes the set in memory, resolves inputs against that set, and writes one `<txid>.ttl` per input. |
| `--in-dir DIR` | optional | `--out-dir DIR` required | **Directory graph emission** — reads every `*.cbor` child in sorted order and emits the same batch graph set. |

`--in-dir` and positional CBOR arguments are mutually exclusive.
Single-input stdout mode is the convenient path for one-off
inspection. Batch mode is the path for a bounded transaction lattice:
load exactly the CBOR files that define the boundary, then query the
emitted Turtle files with SPARQL.

## Examples

Emit the operator-entity overlay from a rules file:

```bash
tx-graph --rules rules/amaru-treasury.yaml
```

Emit one transaction graph to stdout:

```bash
tx-graph --rules rules/amaru-treasury.yaml tx.cbor > graph.ttl
```

Read one transaction from stdin:

```bash
cat tx.cbor | tx-graph --rules rules/amaru-treasury.yaml - > graph.ttl
```

Emit a bounded transaction set produced by `tx-fetch`:

```bash
tx-graph --rules rules.yaml --in-dir lattice/cbor --out-dir lattice
```

JSON-LD output for one input:

```bash
tx-graph --rules rules/amaru-treasury.yaml --format json-ld tx.cbor \
  > graph.jsonld
```

Decode an inline datum against the blueprint registered by the
rules file. The predicate names come from the blueprint constructor
and field titles, and use the fixture-local `:` namespace rather
than the canonical `cardano:` vocabulary:

```bash
tx-graph --rules rules/swap-v2.yaml swap-order.cbor.hex
```

```turtle
_:outputDatum1 a cardano:Datum ;
  cardano:hasHash _:hash_datum_c9bc91a9f2f9d50c ;
  :SwapOrder_recipient _:outputDatum1_recipient .

_:outputDatum1_recipient :_0_pubKeyHash _:outputDatum1_recipient_pubKeyHash .

_:outputDatum1_recipient_pubKeyHash a cardano:Identifier ;
  cardano:leafType "Bytes" ;
  cardano:bytesHex "64f35d26b237ad58e099041bc14c687ea7fdc58969d7d5b66e2540ef" .
```

## Output shape

The Turtle output is canonical (byte-stable) and structured as:

1. **Prefix declarations** — `cardano:`, `rdfs:`, fixture-local `:`.
2. **Operator-entity overlay** — verbatim from the rules loader
   (`Cardano.Tx.Graph.Rules.Load`), one `cardano:Entity` block per
   declared entity plus one `cardano:Identifier` block per
   `(leafType, bytesHex)` pair.
3. **Transaction body** — `_:tx a cardano:Transaction ; ...`,
   followed by per-cluster blocks for inputs, outputs, mints,
   withdrawals, certs, collateral inputs, and proposals.
4. **Blueprint-decoded payloads** — datum and redeemer sub-blocks
   use `:<Constructor>_<field>` predicates when a registered CIP-57
   blueprint decodes the Plutus data; otherwise the graph keeps
   `cardano:hasRawBytes`, with `cardano:decodeError` on decode
   failure.
5. **Address decompositions** — one block per unique address,
   linking the address to its payment and stake credentials, and
   each credential to the corresponding identifier blank node
   (entity-named or raw-bytes-named).

The JSON-LD output is the same triple set serialized as a single
JSON document with `@context` (the three prefixes) and `@graph` (a
flat array of subject-grouped objects). `--format turtle` and
`--format json-ld` produce set-equivalent triple sets; Turtle is
the byte-diff anchor in the test harness.

### Per-section triple coverage

The body emitter walks every Conway-era body field that carries
semantic content. The triples below are emitted regardless of whether
operator rules are supplied; rules.yaml only changes how the bytes are
*labelled* (entity-named vs raw-bytes-named bnodes).

#### Transaction-level predicates

- `cardano:hasInput`, `cardano:hasReferenceInput`,
  `cardano:hasCollateralInput` — one edge per `TxIn` in the
  corresponding ledger field.
- `cardano:hasOutput`, `cardano:hasCollateralReturn` — one edge per
  body output. The collateral-return output is on the same predicate
  family but distinguishable by its anchor predicate (used by
  `tx-view --view cli-tree` to elide it from the spending-output
  list).
- `cardano:hasFee` — integer lovelace literal.
- `cardano:hasValidityInterval` — sub-block with
  `cardano:invalidBefore` / `cardano:invalidHereafter` integers when
  set.
- `cardano:hasWithdrawal` — one edge per `Withdrawal`.
- `cardano:hasMint` — one edge per minted asset class (positive or
  negative quantity).
- `cardano:hasCertificate` — one edge per `Certificate` (stake
  registration / delegation / pool registration / drep declaration
  / vote delegation / governance authorisation).
- `cardano:hasRequiredSigner` — one edge per required-signer
  identifier (PaymentKey leaf).
- `cardano:hasProposal`, `cardano:hasVote` — one edge each per
  governance proposal / vote.
- `cardano:hasRedeemer` — one edge per Plutus redeemer with its
  `cardano:hasPurpose`, `cardano:hasIndex`, `cardano:hasData`, and
  `cardano:hasExUnits` sub-blocks.
- `cardano:scriptDataHash`, `cardano:auxiliaryDataHash` — when set.
- `cardano:totalCollateral` — integer lovelace when set.
- `cardano:hasReferenceScript` (per output) — emitted on the
  output's body when the output carries an attached reference script.

#### Input triples

- `cardano:fromTxOutRef` → typed `cardano:TxOutRef` sub-block.
- `cardano:hasTxId` (on the `TxOutRef`) → `_:hash_txid_<full-hex>`
  bnode carrying `cardano:leafType "TxId"` + `cardano:bytesHex`.
- `cardano:hasIndex` (on the `TxOutRef`) — integer.
- `cardano:resolvedTo` → resolved-`cardano:Output` sub-block when
  the parent transaction is present in the input set. Carries the
  parent's address + value at the time of consumption.

#### Output triples

- `cardano:atAddress` → typed `cardano:Address` sub-block (see
  *Address decompositions* below).
- `cardano:lovelace` — integer.
- `cardano:hasAssetValue` → typed RDF list of `cardano:Asset`
  entries when the output carries native tokens.
- `cardano:hasDatum` → typed `cardano:Datum` sub-block when the
  output carries either an inline datum (with `cardano:hasRawBytes`
  and/or blueprint-decoded predicates) or a datum hash (with
  `cardano:hasHash`).
- `cardano:hasReferenceScript` → typed sub-block when the output
  has an attached reference script (inline or hash-only).

#### Asset / multi-asset triples

The `cardano:hasAssetValue` payload is an RDF list. Each entry is a
typed `cardano:Asset` block:

- `cardano:hasIdentifier` → `_:cred_assetclass_<full-hex>` bnode
  with the concatenated `policy-id ++ asset-name` bytes and
  `cardano:leafType "AssetClass"`.
- `cardano:quantity` — integer (positive on outputs, signed on
  `hasMint`).

#### Address decomposition

Each unique `(payment-cred, stake-ref)` pair emits one
`cardano:Address` block:

- `cardano:bech32` — full bech32 address literal.
- `cardano:hasPaymentCredential` → `<base>CredPayment` sub-block.
- `cardano:hasStakeCredential` → `<base>CredStake` sub-block (when
  the stake reference is non-null).

Each credential sub-block carries one
`cardano:hasIdentifier` edge to the underlying identifier bnode
(entity-named when `rules.yaml` covers the credential's
`(leafType, bytesHex)` pair, otherwise raw-bytes-named).

#### Blueprint-decoded datum / redeemer payloads

When the rules file registers a CIP-57 blueprint for the script
controlling the datum, the walker emits a typed-emit projection of
the Plutus data tree:

- Each constructor's titled fields become
  `:<ConstructorTitle>_<fieldTitle>` predicates rooted at the
  enclosing data subject.
- A constructor without a `title` falls back to a positional
  `:_<index>` predicate.
- **`"dataType": "map"` (CIP-57 SchemaMap)** — a Plutus `Map`
  payload renders as an RDF list of `cardano:Asset`-shaped
  `OpenObject {"key" -> k, "value" -> v}` entries; the walker
  materialises each entry as a positional `:_<i>` bnode with the
  decoded `:key` and `:value` triples on the entry.
- Plutus byte fields → `_:<scope>_<field>_<i>` bnodes with
  `cardano:bytesHex` literal and `cardano:leafType "Bytes"`.
- Plutus integer fields → integer literals directly on the
  enclosing predicate.
- Decode failure → `cardano:decodeError "<reason>"` literal on the
  enclosing data subject; raw bytes are preserved on
  `cardano:hasRawBytes`.

#### Bnode-label naming scheme

Bnode labels are file-local and only need to be unique inside the
Turtle document. The emitter mints them deterministically from the
underlying bytes so that the same identifier emitted from two
positions in a tx collapses to a single RDF node (intentional
deduplication for the operator overlay) while distinct identifiers
never collide on label:

- **Identifier leaves** (TxId, datum hash, script hash, payment /
  stake credentials, asset classes) →
  `_:<family>_<role>_<full-hex>` where:
  - `<family>` is `cred` for operator-declarable credential leaves
    (payment / stake key / script, asset class, policy, pool id,
    drep key / script) and `hash` for body-walker hash leaves (TxId,
    datum hash, script hash, scriptdata hash, auxiliarydata hash).
  - `<role>` is the leafType in lowercase (`paymentkey`,
    `paymentscript`, `stakekey`, `stakescript`, `assetclass`,
    `txid`, …).
  - `<full-hex>` is the lowercase base16 encoding of the bytes,
    *not* truncated. (Earlier emitter versions truncated to 16 hex
    chars; that was a bnode-collision hazard for stub or
    long-zero-prefix byte sets and is fixed in 0.2.3.0.)
- **Address-level bnodes** → `<base>Addr`, `<base>CredPayment`,
  `<base>CredStake` where `<base>` is the entity slug (when
  rules.yaml binds the payment credential) or the raw-bytes form,
  *concatenated with* the stake credential when present:
  `<paymentBase>_s<stakeRole><stakeFullHex>` for non-null stake.
  This pinning is what makes two addresses sharing a payment
  credential but differing in stake credential mint distinct bnodes
  (the SundaeSwap V3 order-book pattern surfaced the
  payment-cred-only collision in 0.2.2.0; fixed in 0.2.3.0).
- **Per-tx-position bnodes** — `_:input<N>`, `_:output<N>`,
  `_:refInput<N>`, `_:collateral<N>`, `_:withdrawal<N>`,
  `_:certificate<N>`, etc. — are *positional* (1-based on the
  ledger body). These collide across distinct Turtle files emitted
  for distinct transactions (each tx's body has its own
  `_:input1`); for cross-tx SPARQL the recommended pattern is one
  Turtle file per tx + multiple `--data` files at query time, which
  lets the SPARQL engine rename per-file blank nodes uniquely.

## Library entry point

```haskell
import Cardano.Tx.Graph.Emit
import Cardano.Tx.Graph.Rules.Load (loadRulesFile, RulesLoadResult (..))

emitJoint :: FilePath -> ConwayTx -> ResolvedUTxO -> IO ByteString
emitJoint rulesPath tx utxo = do
    Right result <- loadRulesFile rulesPath
    let Right graph =
            emit tx utxo (rulesEntities result) (rulesBlueprints result)
    pure (serialize Turtle graph)
```

Both `emit` and `serialize` are pure; the only IO happens at the
rules-loading and CBOR-loading boundaries. The CLI builds the
`ResolvedUTxO` argument from the input transaction set before calling
the emitter.

## See also

- [rewriting-rules grammar](rewriting-rules.md) — the YAML sugar
  and Turtle subset the rules loader consumes.
- [tx-inspect](tx-inspect.md) — collapse + rename pipeline for the
  same Conway transactions, rendered as a structured human report.

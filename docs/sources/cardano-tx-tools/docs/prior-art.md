# Prior art

`cardano-tx-tools` is a Cardano-native canonical-RDF stack:
Conway transactions emitted as byte-stable Turtle / JSON-LD with a
`cardano:` predicate vocabulary, CIP-57 blueprint-aware
datum / redeemer typed-decode, an operator-overlay entity
language, a Blockfrost-backed CBOR fetcher (`tx-fetch`), a pure
CBOR-to-RDF emitter (`tx-graph`), and a packaged-view library
(`tx-view`).

The general idea of "blockchain as a knowledge graph" is older
than this project. This page names the survivors and what each
of them covers, so a reader of our docs doesn't have to discover
the prior work themselves.

## Blockchain-RDF / linked-data ontologies

| Project | Covers | Status |
|---------|--------|--------|
| [**EthOn**](https://ethon.consensys.io/) — Ethereum Ontology, ConsenSys (2017). [GitHub](https://github.com/ConsenSys/EthOn). | An OWL ontology aligned with the Ethereum yellow paper. Models block, transaction, account, message-call structure as classes + properties. | Original effort dormant; the ontology design is still the canonical reference for Ethereum-style accounts-and-messages RDF. |
| [**BLONDiE**](https://arxiv.org/abs/2008.09518) — Blockchain Ontology with Dynamic Extensibility, Ugarte (arXiv 2008.09518, 2020). [GitHub](https://github.com/hedugaro/Blondie). | A multi-chain OWL ontology covering Bitcoin, Ethereum, and Hyperledger Fabric. Class hierarchy at the consensus / block / transaction level; no eUTxO multi-asset or Plutus-witness semantics. | Academic publication; reference implementation, no live SPARQL endpoint. |
| [**AllegroGraph Bitcoin RDF Model**](https://allegrograph.com/bitcoin-rdf-model-in-allegrograph/) — vendor demo from Franz Inc. | Bitcoin block-and-transaction RDF view served through AllegroGraph with example SPARQL queries. | Vendor proof-of-concept; Bitcoin only; no public dataset. |
| [**DLT Ontology**](https://arxiv.org/abs/2303.16528) — Building a Knowledge Graph of DLTs (arXiv 2303.16528, 2023). | A *meta*-ontology *about* DLT systems (DLT-as-subject), not a per-transaction RDF emitter. | Position paper; no public SPARQL surface. |

What none of the above provide that `cardano-tx-tools` does:

- **eUTxO-shaped triples** with `cardano:fromTxOutRef` /
  `cardano:hasOutput` predicates that JOIN naturally across
  the input-output edge.
- **Multi-asset value** modeled as RDF list of `cardano:Asset`
  entries with their own typed identifier predicates.
- **Plutus script witnesses + redeemers** with purpose-tagged
  triples and **CIP-57 blueprint-decoded typed payloads**
  (`:SwapOrder_recipient`, `:OrderRedeemer_Scoop`, …).
- **Conway-era governance** (vote / proposal / DRep) emitted as
  typed body predicates rather than opaque CBOR.
- **An operator-overlay vocabulary** for naming on-chain
  entities and off-chain attestations side by side, so SPARQL
  joins lattice + accounting truth in a single invocation.

## SPARQL substrate

| Reference | Relevance |
|-----------|-----------|
| [**Recursion in SPARQL**](https://www.semantic-web-journal.net/system/files/swj2276.pdf) — Reutter, Soto, Vrgoč, *Semantic Web Journal*. | The canonical formal treatment of SPARQL 1.1 property paths and recursion semantics. The parent-transaction JOIN pattern in the May 2026 report (`?ref cardano:hasTxId/cardano:bytesHex ?parentHex . ?parent cardano:hasTxId/cardano:bytesHex ?parentHex`) is a direct application of property-path joins to a closed UTxO graph. |
| [**Apache Jena**](https://jena.apache.org/) — the engine the [May 2026 lattice presentation](may-2026-amaru-lattice/index.md) drives. | Standards-compliant SPARQL 1.1 + Turtle / JSON-LD parsing in Java. Same `.rq` contracts work against Stardog, Blazegraph, AllegroGraph, etc. — `tx-view` ships paired Haskell projections so a runtime isn't a hard dependency. |

The novelty in our stack is *not* recursive SPARQL. It's the
**CBOR-fetch boundary**: `tx-fetch` pulls the operator-selected
transaction ids, and optionally their referenced parents, as
verified CBOR; `tx-graph` emits that bounded set as sibling
Turtle files. The SPARQL engine then sees a closed graph and the
JOINs reduce to ordinary property paths — no chain-aware operators
in the query language.

## CIP-57 typed datum / redeemer decode

| Reference | Relevance |
|-----------|-----------|
| [**CIP-57: Plutus Contract Blueprint**](https://cips.cardano.org/cip/CIP-57) — official Cardano Improvement Proposal. | The schema language we consume. `tx-graph` registers blueprints via `rules.yaml` `blueprints:` blocks; the per-script schema is walked at emit time to mint `:<Constructor>_<field>` triples plus per-list `:_<i> :key :value` triples for CIP-57 `SchemaMap` entries. |
| **Aiken** / **PlutusTx** / **Plinth** code generation. | These projects emit `plutus.json` files that conform to CIP-57. Our shipped `test/fixtures/rewrite-redesign/blueprints/sundaeswap-v3/plutus.json` is one such artefact, pinned at upstream `github.com/SundaeSwap-finance/sundae-contracts` commit `be33466b…`. We *consume* CIP-57 outputs; we don't generate them. |

To the best of our knowledge no other project maps CIP-57
typed schemas into RDF predicates.

## How to frame this work

Honest one-liners:

- **Idea**: "blockchain transactions as a knowledge graph" is
  not new (EthOn 2017, BLONDiE 2020).
- **Cardano coverage**: we're the first to do this on Cardano
  to a level that actually exercises eUTxO + multi-asset +
  Plutus + Conway governance.
- **CIP-57 → RDF**: novel.
- **Recursive CBOR-fetch closure as a SPARQL substrate**: not a
  new operator (property paths suffice in the engine), but
  packaging it as a reproducible `tx-fetch` / `tx-graph` pipeline keyed
  off Blockfrost's CBOR endpoint is new for any UTxO chain.
- **Off-chain overlay co-emitted with the on-chain graph**:
  `attestations:` + `paid-via:` for IPFS-anchored vendor
  accounting joined in a single SPARQL query — not in any
  prior linked-blockchain effort we've found.

## See also

- [tx-graph](tx-graph.md) — the per-tx canonical Turtle / JSON-LD
  emitter.
- [tx-fetch](tx-fetch.md) — the Blockfrost-backed Conway CBOR
  fetcher.
- [tx-view](tx-view.md) — the packaged-view library.
- [rewriting-rules grammar](rewriting-rules.md) — the
  operator-entity overlay format.
- [May 2026 lattice demo](may-2026-amaru-lattice/index.md) — 22 SPARQL
  query pages against an 85-tx mainnet boundary.

# cardano-tx-tools

Tooling for Conway-era Cardano transactions. Eight command-line
executables plus the Haskell library that backs them.

## Executables

- [**tx-diff**](tx-diff.md) — structural diff between two Conway
  transactions, with Plutus blueprint-aware decoding and opt-in
  input resolution via N2C or Blockfrost-style HTTP.
- [**tx-inspect**](tx-inspect.md) — render one Conway transaction
  as a structured, human-readable report. Optional
  [rewriting-rules YAML](rewriting-rules.md) drives two stages
  (collapse + rename) on top of the verbatim render; same loader
  and per-leaf renderer `tx-diff` uses.
- [**tx-sign**](tx-sign.md) — age-encrypted signing-key vault and
  detached vkey witness creation. The cleartext signing key never
  touches disk and the passphrase is never read from `argv`.
- [**tx-validate**](tx-validate.md) — Conway Phase-1 pre-flight for
  unsigned transactions, driven via Node-to-Client against a local
  `cardano-node`. Returns the ledger's verdict as a human or JSON
  envelope; exit code is the contract (0 clean, 1 structural, ≥2
  config/resolver error).
- [**tx-graph**](tx-graph.md) — emit one Conway transaction (or a
  whole in-memory lattice of them) as a canonical Turtle (or
  JSON-LD) graph: operator-entity overlay (from a rules file),
  body decomposition (inputs / outputs / certificates / mints /
  withdrawals / proposals / fees), Plutus blueprint-decoded datums
  and redeemers (including CIP-57 `SchemaMap` per-entry triples),
  and address decompositions. Pure transformation —
  `(rules + [cbor]) → ttl(s)`, no network or node required. Same
  loader as `tx-inspect --rules`.
- [**tx-fetch**](tx-fetch.md) — closure-walking Conway CBOR
  fetcher. Resolves transaction ids over Blockfrost's
  `/txs/<hash>/cbor` endpoint, walks each tx's spending /
  reference / collateral input parents to `--depth`, hash-verifies
  every CBOR against its requested `TxId`, and writes one
  `<txid>.cbor` per tx into `<out-dir>/cbor/`. Pairs with
  `tx-graph --in-dir` to produce a Turtle lattice.
- [**tx-view**](tx-view.md) — project a `tx-graph`-emitted
  canonical graph through one of four packaged views:
  `cli-tree` (text tree of the body), `asset-flow` (TSV of value
  movements), `entity-occurrences` (TSV of entity touch counts),
  or `json-ld` (full graph as JSON-LD). The four views ship as
  paired contracts: vendor-neutral `.rq` SPARQL files for any
  standards-compliant runtime, plus in-process Haskell projections
  that produce the same byte stream without a SPARQL engine.
- [**cardano-tx-generator**](cardano-tx-generator.md) — long-running
  daemon that drives a configurable mix of Conway transactions
  against a node for soak / fuzz testing.

The [rewriting-rules grammar](rewriting-rules.md) document pins
the shared YAML language consumed by both `tx-inspect --rules`
and `tx-diff --collapse-rules`, and is the same rules format
`tx-graph --rules` reads to drive its entity overlay.

For context on how this stack relates to existing
blockchain-RDF / linked-data work (EthOn, BLONDiE, AllegroGraph's
Bitcoin demo, CIP-57, Reutter–Soto–Vrgoč on SPARQL recursion),
see [Prior art](prior-art.md).

## Library

The same logic is exposed under `Cardano.Tx.*`. Notable entry
points:

| Module                                 | What                                                       |
|----------------------------------------|------------------------------------------------------------|
| `Cardano.Tx.Build`                     | Monadic DSL for assembling Conway transactions             |
| `Cardano.Tx.Balance`                   | Fee balancing + collateral selection                       |
| `Cardano.Tx.Evaluate`                  | Redeemer re-evaluation against the final body              |
| `Cardano.Tx.Validate.validatePhase1`   | Ledger Phase-1 pre-flight (`Mempool.applyTx`)              |
| `Cardano.Tx.Validate.Cli`              | Verdict types + renderers used by `tx-validate`            |
| `Cardano.Tx.Diff`                      | Structural diff used by `tx-diff`                          |
| `Cardano.Tx.Blueprint`                 | Schema-aware Plutus datum/redeemer decoding (incl. CIP-57 `SchemaMap`) |
| `Cardano.Tx.Graph.Emit`                | Canonical Turtle + JSON-LD emit pipeline used by `tx-graph` |
| `Cardano.Tx.Graph.Rules.Load`          | Rules-file loader (YAML sugar + Turtle subset) used by `tx-graph --rules` |
| `Cardano.Tx.View`                      | Packaged-view dispatcher + four view modules used by `tx-view` |
| `Cardano.Tx.Sign.*`                    | Vault + witness primitives used by `tx-sign`               |
| `Cardano.Tx.Generator.*`               | Generator engine used by `cardano-tx-generator`            |

Generated API reference: `cabal haddock cardano-tx-tools`.

## Install / develop

```bash
nix develop --quiet -c just build
nix develop --quiet -c just ci
```

Linux release artifacts (AppImage, DEB, RPM) for each executable
are attached to every
[GitHub Release](https://github.com/lambdasistemi/cardano-tx-tools/releases).

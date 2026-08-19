# Finding note — Amaru bootstrap trust model (for the Amaru team)

**From:** DWARF bootstrap trust-source differential (Cyber-Castellum) · **Date:** 2026-07-18
**Scope:** source analysis of how `cardano-node` and `Amaru` establish their *initial trusted
state* and where those trust roots differ. No exploit — a trust-provenance model difference with
consensus-relevant anchors, and a new test dimension for the differential suite.

## Summary

cardano-node can bootstrap **trustlessly from genesis** (validate every block, derive its epoch
nonces from validated history) and additionally ships **checkpoints** (trusted block-hashes) as
defence-in-depth. **Amaru cannot validate from genesis** — it *structurally requires* an imported,
trusted snapshot, and it carries **compiled-into-the-binary trust anchors** (initial nonces,
bootstrap headers, snapshot point) per network. So the two clients anchor their initial state,
including the **leader-election nonces**, on fundamentally different roots of trust.

## Finding 1 — Amaru has no from-genesis validation; a trusted snapshot is mandatory

`amaru node run` opens pre-populated ledger/chain RocksDB stores and fails (`build_node.rs`:
*"ledger tip header not found"*) if they are absent. Every bootstrap route (`amaru node bootstrap`,
`import-ledger-state`) imports a **snapshot**; there is no path that rebuilds the ledger from block
0. cardano-node's from-genesis mode gives it a *trustless* bootstrap option that Amaru does not have.

## Finding 2 — Amaru's initial nonces are a compiled-in constant, not derived

`include_dir!("config/bootstrap")` embeds `config/bootstrap/{mainnet,preprod,preview}/nonces.json`
into the binary — the initial Ouroboros `active`/`candidate`/`evolving` nonces at a fixed point
(e.g. mainnet `active: 0b9e320e…` at `134956789.6558deef…`). **These seed leader election.**
cardano-node *derives* the same nonces by validating chain history from genesis. A wrong or tampered
`nonces.json` would give Amaru a different leader schedule than cardano-node — a consensus divergence
originating entirely in a build-time trust anchor.

## Finding 3 — different snapshot trust roots; no checkpoint anchor

- Well-known nets: Amaru fetches the ledger snapshot from a **Mithril aggregator** (hardcoded
  endpoint + verification key in `mithril.rs`) and verifies the certificate chain. cardano-node can
  reach the same state from genesis with no Mithril dependency.
- Custom nets: Amaru imports a **local snapshot** (e.g. from `bootstrap-producer`), trusted as-is.
- Amaru has **no checkpoint (trusted block-hash) mechanism** — its "checkpoints" are RocksDB
  snapshots. cardano-node's `npcCheckpointsFile` is a history-rewrite defence Amaru lacks.

## Recommendations

1. **Consider a from-genesis (or independently-verifiable) bootstrap path**, even if slow, so the
   trusted-snapshot dependency is optional rather than structural.
2. **Treat the compiled-in `nonces.json` as a security-critical anchor** — document its provenance,
   and consider verifying it against an independently-derivable value.
3. **Consider a checkpoint mechanism** analogous to cardano-node's, for history-rewrite defence.
4. The DWARF harness can be extended with a **trust-source dimension**: bootstrap each node from
   each supported source, record provenance, and adversarially tamper an anchor (a nonce, a
   snapshot) to check whether the node detects it. Offered as a joint next step.

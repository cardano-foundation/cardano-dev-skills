# Bootstrap trust-source differential (cardano-node vs Amaru)

**Source analysis** (Amaru `crates/amaru`, cardano-node config) · **Date:** 2026-07-18

## What it tests

The strongest true gap in the differential suite: **"where did this node's truth come from?"**
Two nodes can converge to the same chain tip while having reached their *initial* trusted state
by completely different means — genesis validation, a hardcoded checkpoint, a Mithril snapshot, or
a synthetic bundle. DWARF's existing oracles watch tip convergence; they do **not** model trust
provenance. This report maps each implementation's bootstrap trust root and identifies where they
diverge — a difference that a tip-only oracle cannot see, but that decides what each node will
believe if a trust source is wrong.

## The two trust models (from source)

### cardano-node — can bootstrap trustlessly from genesis

- **Default root of trust: the genesis file + full Ouroboros validation from block 0.** It can
  build its entire ledger and — critically — *derive its epoch nonces* from validated chain
  history. No external service or snapshot is required for correctness.
- **Optional defence-in-depth: hardcoded checkpoints** (`npcCheckpointsFile`,
  `NodeCheckpointsConfiguration` in the node config) — trusted block-hashes at heights, which let
  it reject a history-rewrite even if the alternative chain looks valid.
- (It *also* supports Mithril fast-bootstrap — but from-genesis validation remains available.)

### Amaru — structurally requires a trusted imported snapshot

Reading `crates/amaru`:

- **There is no from-genesis validation path.** `amaru node run` opens pre-populated ledger/chain
  RocksDB stores and fails (`build_node.rs`: *"ledger tip header not found"*) if they aren't there.
  Every bootstrap route (`amaru node bootstrap`, `import-ledger-state`) goes through **snapshot
  import** — Amaru cannot rebuild the ledger from block 0.
- **Compiled-into-the-binary trust anchors, per network.** `include_dir!("config/bootstrap")`
  embeds `config/bootstrap/{mainnet,preprod,preview}/` at build time:
  - `nonces.json` — the initial Ouroboros **nonces** (`active` / `candidate` / `evolving` at a
    fixed point). *These seed leader election.* e.g. mainnet `active: 0b9e320e…` at point
    `134956789.6558deef…`.
  - `headers.json` + `headers/` — bootstrap headers.
  - `snapshots.json` — the trusted snapshot point.
- **The ledger snapshot itself:** for mainnet/preprod/preview, downloaded from a **Mithril
  aggregator** — a *hardcoded endpoint + verification key* (`mithril.rs`, `aggregator_details`) —
  and the Mithril certificate chain is verified. For a custom testnet, imported from a local
  snapshot directory (e.g. produced by `bootstrap-producer`) — trusted as-is.

## The differential

| | cardano-node | Amaru |
|---|---|---|
| Can validate from genesis? | **Yes** (trustless option) | **No** — snapshot mandatory |
| Initial epoch nonces | **derived** from validated chain history | **compiled-in constants** (`nonces.json`) |
| Checkpoint (trusted block-hash) anchor | Yes (`npcCheckpointsFile`) | **None** (its "checkpoints" are RocksDB snapshots) |
| Well-known-net bootstrap trust | genesis (or optional Mithril) | Mithril aggregator (hardcoded endpoint + VK) |
| Custom-net bootstrap trust | genesis | a locally-imported snapshot, trusted as-is |

**So the two implementations do not share a root of trust for their initial state** — including the
consensus-critical leader-election nonces. cardano-node derives them by validating history from a
genesis it can check; Amaru takes them as a build-time constant plus a trusted snapshot.

## Why it matters (no exploit — a model gap DWARF should test)

None of this is a vulnerability in itself: pinned nonces + Mithril snapshots are a legitimate,
audited fast-bootstrap design (cardano-node uses Mithril too). The finding is that **the two nodes'
trust roots differ, and DWARF's convergence oracles cannot detect a divergence caused by a bad trust
source.** Concretely:

- Amaru's **initial nonces are a compiled-in constant** — a build/supply-chain trust anchor. A wrong
  or tampered `nonces.json` would give Amaru a *different leader schedule* than a genesis-validating
  cardano-node, and the two would then accept/reject different blocks — a real consensus divergence
  that a tip-convergence check would only see *after* it happened, with no idea *why*.
- Amaru's bootstrap security depends on the **Mithril aggregator + verification key** (well-known
  nets) or the **snapshot producer** (custom nets); cardano-node's from-genesis mode depends on
  neither.
- Amaru **lacks a checkpoint mechanism**, so it has no equivalent of cardano-node's trusted-block-hash
  defence against a history rewrite (it relies on the k-limit + its trusted snapshot).

## What DWARF should add

A **trust-source dimension** to the differential harness: bootstrap each node from each supported
trust source (genesis / checkpoint / Mithril / synthetic snapshot), record the *provenance* of the
initial state, and assert not just that the tips converge but that the two nodes anchored on
*compatible* trust roots — and flag when they didn't. Tampering a bootstrap anchor (a nonce, a
snapshot) and checking whether the node detects it is the natural adversarial follow-up.

Source citations and the trust-model table are in
`reports/consensus-bootstrap-trust-source-evidence/`.

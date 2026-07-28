# Changelog

All notable changes to this repository are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added — `agentic-payments` skill

New task-oriented skill covering how to charge for an AI agent's work on Cardano:
escrow between mutually distrusting parties, hash-based proof of delivery,
on-chain identity and discovery, refund and dispute windows, and the
testnet-to-mainnet cutover for a paid agent service.

The skill is implementation-neutral by design. It teaches the pattern and the
decision criteria — including when *not* to put payments on-chain — and defers
every wire-level detail to the bundled sources and to each implementation's own
live specification, so it cannot drift the way inlined API specs do. The
Developer Portal's AI-agents curriculum, already bundled under
`docs/sources/developer-portal/`, supplies the orientation and its worked example
of an agent-economy protocol.

Two decision gates are built in: a fit check that recommends conventional billing
when no counterparty risk exists, and a test-network round trip — including an
exercised refund path — before any mainnet key is created.

- Added a reciprocal pointer from `suggest-tooling`.
- Updated the advertised skill count from 15 to 16 in `.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, `website/src/content/docs/index.mdx`, and
  `website/src/content/docs/about/roadmap.md`.

The skill's guidance on fee floors, settlement latency, delivery-hash
canonicalization, and key custody was derived from verifying a production
agent-payment stack on Cardano against live chain data — captured here as
protocol-independent principles rather than as version-pinned specifics.

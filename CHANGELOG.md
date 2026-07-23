# Changelog

All notable changes to this repository are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed — `masumi` skill audit and hardening

Verified the `masumi` skill and its two references against upstream
`masumi-payment-service` (tag 0.28.0), `pip-masumi` 1.2.0, MIP-003/MIP-004, and
live Cardano chain data, then corrected every confirmed defect.

- **Mainnet payment unit corrected.** The skill previously told developers to
  price Mainnet jobs in USDCx and called USDM "historical only". On-chain census
  showed the opposite — USDM is the ecosystem default (106 live registry entries
  vs 1 for USDCx; the Mainnet escrow holds USDM and no USDCx). The payment-unit
  table now lists both, recommends USDM, and flags that USDCx does not exist on
  Preprod.
- **Correctness fixes that unblock a developer following the skill:** MIP-004
  output-hash JSON-escaping in the CrewAI sample; `npm` → `pnpm` and Node ≥ 20;
  register-before-test step order (the `agentIdentifier` that `POST /payment`
  requires only exists after registration, which is asynchronous); refund/dispute
  semantics (`refundTime` is not a real field; the gates are `unlockTime` and
  `submitResultTime`); timestamps are unix milliseconds, not seconds;
  Web3CardanoV1 vs V2 pricing shapes and `supportedPaymentSourceIndex`; the
  previously-undefined `start_payment_polling` poller; node-generated wallet
  mnemonics and their export; the registry service's repo, URL, and credential;
  admin-key rotation; settlement-latency and micro-transaction fee-floor figures.
- **Documentation-accuracy fixes:** the non-existent `NETWORK` env var; error
  codes relabelled as conventions rather than spec; input-schema field types
  (5 → 22 per MIP-003 Attachment 01); even-length `identifierFromPurchaser`; the
  over-broad "all paths are singular" claim; cron-interval `.env.example`-vs-code
  defaults; CIP-25/MIP-002 (not CIP-30/68) for registry asset naming;
  fixed-vs-dynamic pricing source; `/provide_input` and `/demo` response shapes;
  `/status` `id` handling.

### Changed — skill metadata and repository docs

- Rewrote the `masumi` frontmatter `description` for more reliable triggering and
  sharper scoping against sibling skills; added tables of contents to both
  reference files; added the house `${CLAUDE_SKILL_DIR}` documentation-lookup
  header and a reciprocal link from `suggest-tooling`.
- Updated the advertised skill count from 15 to 16 in `.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, `website/src/content/docs/index.mdx`, and
  `website/src/content/docs/about/roadmap.md`.

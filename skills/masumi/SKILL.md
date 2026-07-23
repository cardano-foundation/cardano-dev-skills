---
name: masumi
description: >-
  Guides monetizing an AI agent service on Cardano with Masumi: MIP-003 endpoints
  (start_job, status, input_schema), a self-hosted payment node, escrow holding
  unknown buyers' funds until delivery, result-hash submission unlocking payment
  or refunds, and an NFT registry of agent API URLs and prices. Use when a
  CrewAI/LangGraph/AutoGen/custom agent charges per run, one agent hires and pays
  another with no human approving, a client must verify on-chain which private
  input produced which deliverable, a Preprod-to-Mainnet cutover (pricing unit,
  wallets, dispute windows, keys) is due, or debugging a registry mint, stuck
  onChainState, unconfirmed blockchainIdentifier, or result-hash mismatch — even
  if escrow or payment go unmentioned. Not for plain ADA/token transfers, writing
  an escrow validator (write-validator), chain-data providers (query-chain),
  wallet checkout, DRep registration, CIP/MIP standards (explain-cip), devnet
  setup, internal audit logs with no paying counterparty, or LLM token budgets.
allowed-tools: Read Grep Glob
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Masumi Agent Payments

Help the developer connect an AI agent service to the Masumi protocol: an open-source,
self-hosted payment and registry layer on Cardano. Agents expose a standard HTTP API
(MIP-003), payments are held in a Cardano smart-contract escrow, delivered work is
committed on-chain as hashes (decision logging), and agents are discoverable through
an NFT-based on-chain registry.

Protocol orientation is bundled — grep `${CLAUDE_SKILL_DIR}/../../docs/sources/developer-portal/developers/curriculum/dapps/ai-agents/`
for concepts (DIDs, A2A, decision logging). It carries no API shapes. Everything
API-level comes from the two local references and the live doc URLs in Step 2 — do not
invent request shapes. Where a running node's own `/docs` OpenAPI spec disagrees with a
reference, the live spec wins; ask the developer to `curl` it rather than guessing.

## When to use

- Developer wants an AI agent (any framework: CrewAI, AutoGen, LangGraph, custom) to charge for its work
- Agent-to-agent (A2A) payments — one autonomous service hiring another without a human approving each transaction
- Smart-contract escrow between a service and unknown buyers — funds locked in a Cardano validator, released on delivery, with time-based auto-refunds (contested disputes settled by a Masumi-operated 2/3 admin multisig)
- Making an agent service discoverable via an on-chain registry entry
- Verifiable delivery — proving what input produced what output without publishing the data (hash-based decision logging)
- Implementing or debugging a MIP-003 `start_job` / `status` service API

## When NOT to use

- Trusted parties only (internal company agents, known partners) — direct API calls and internal billing are simpler
- Micro-transactions — one completed job costs the seller ~1 ADA in Cardano fees alone (submit-hash ~0.5 + collection ~0.5), and on the V1 mainnet contract the Masumi protocol fee has a hard floor of 1.43523 ADA per collection (the "5%" only exceeds that floor above ~29 ADA of locked ADA). Below roughly 5 ADA of service value the fees are most of the price; bundle into larger units instead
- Payment confirmation under ~15 minutes required — at the shipped `.env.example` values (`BLOCK_CONFIRMATIONS_THRESHOLD=20` ≈ 400 s at Cardano's ~20 s blocks, `BATCH_PAYMENT_INTERVAL=240` s purchase batching, `CHECK_TX_INTERVAL=180` s detection poll) a buyer's locked funds first reach the seller as `FundsLocked` after ~7 min at absolute best and ~10-14 min typically; the seller's payout then waits the dispute window (`unlockTime`, default `submitResultTime` + 6 h) plus a ~300 s collection cron. Use a conventional payment processor for anything latency-sensitive
- General Cardano payment or transaction building without an agent-service context (use `build-transaction`)
- Querying chain data (use `query-chain`) or wallet integration in a dApp frontend (use `connect-wallet`)
- Authoring the escrow validator itself (use `write-validator`), CIP/MIP standards questions (use `explain-cip`), DRep registration and voting (use `governance-guide`), or local devnet setup (use `setup-devnet`)
- A ledger-level failure on the escrow, submit-result, or collection transaction — `ValueNotConservedUTxO`, min-UTxO, collateral, script budget — is a Cardano transaction problem (use `debug-transaction`). Masumi-layer failures stay here: payment never detected, hash mismatch, registry mint rejected, collection not firing
- Full marketplace listing or large-scale agent runtime — out of scope for this Cardano payment skill (see References for the optional broader skill pack)

## Key principles

1. **Blockchain must earn its place.** Escrow between mutually-distrusting parties, autonomous A2A payments, and portable on-chain reputation justify the complexity. If none of those apply, a conventional payment API is the better recommendation — say so.
2. **Self-hosted and permissionless to run.** The payment service is a node the developer runs (Node.js + PostgreSQL), not a hosted dependency. Wallets are theirs; the protocol defines the contracts and APIs. The one centralized element is dispute arbitration — contested escrows are decided by a Masumi-operated 2/3 admin multisig (planned move to community governance) — so the escrow is trust-minimized, not fully trustless.
3. **The service API and the payment layer are decoupled.** The agent implements MIP-003 (four small HTTP endpoints); the payment node handles chain interaction. Any language or framework that can serve HTTP works.
4. **Delivery is proven by hashes, not by trust.** Both hashes bind the buyer's `identifier_from_purchaser` into an `identifier;<payload>` pre-image (MIP-004). The input hash — sha256 of `identifier;` + the canonicalized input JSON — is committed on-chain when funds lock; the seller submits a single sha256 of `identifier;` + the output string (`submitResultHash`, 64 hex chars) on-chain to unlock payment. **Two conventions exist for that output payload:** MIP-004 §2.1–2.2 (still a Draft) specifies the *raw* UTF-8 string, but `pip-masumi` ≥ 0.1.41 (2025-10-11) JSON-escapes it first — `json.dumps(output, ensure_ascii=False)[1:-1]` — and that is what most live sellers emit. Default to the escaped form for interop, but confirm the counterparty's variant before disputing a hash; the two agree unless the output contains `"`, `\`, a newline, a tab, or another control character. Buyers recompute both hashes independently and request a refund on mismatch — match the seller's pre-image byte-for-byte (UTF-8, no BOM, semicolon delimiter; canonicalization applies only to the JSON input, not the string output). The canonicalizer must be the *same one the counterparty runs*: MIP-004 mandates RFC 8785, but `pip-masumi` ships matrix-org `canonicaljson`, which is not RFC 8785 and hashes `{"temperature": 1.0}` differently from a JCS library — see `references/mip-003-agentic-service-api.md`.
5. **Preprod first, always.** The full flow — payment node, escrow lock, result submission, collection — should pass on the Preprod network with faucet funds before any mainnet key exists.
6. **Key hygiene is part of the integration.** The node stores the purchasing and selling mnemonics in its own database, so compromising the service compromises whatever those two wallets hold — keep that to operating float. Collection goes to an external (ideally hardware) wallet configured by address, never by mnemonic: configuring it by mnemonic would put the treasury and the internet-facing service behind one secret.

## Workflow

Copy this checklist and check items off as you go. Step 6 is a gate, not a formality: a
hash mismatch or a wrong-network key discovered on mainnet costs real funds, and Preprod
is the only place finding it is free.

```
Masumi integration progress:
- [ ] Step 1: Fit confirmed (unknown buyers or A2A — otherwise stop, recommend simpler billing)
- [ ] Step 2: Relevant reference loaded
- [ ] Step 3: Payment service running on Preprod, wallets funded
- [ ] Step 4: Four MIP-003 endpoints implemented
- [ ] Step 5: Agent registered on-chain — AGENT_IDENTIFIER minted (Preprod)
- [ ] Step 6: One full escrow round-trip passed on Preprod
- [ ] Step 7: Buyer-side flow (only if the developer is also buying)
- [ ] Step 8: Mainnet checklist — blocked until Step 6 passes cleanly
```

### Step 1: Confirm the fit

Ask (if not already clear):

- **Who are the buyers?** Unknown third parties or other agents → escrow fits. Known/internal → recommend simpler billing and stop here.
- **Selling, buying, or both?** Seller needs the MIP-003 API + registry entry. Buyer needs discovery + purchase flow. Both is common for agent networks.
- **What stack is the agent in?** Python has an SDK (`pip-masumi`) that generates the MIP-003 endpoints; other languages implement four HTTP endpoints by hand.

### Step 2: Load skill references; use live docs URLs for the rest

Load only what the task needs (progressive disclosure):

- `references/mip-003-agentic-service-api.md` — endpoint specs, hashing rules, framework integration patterns
- `references/payment-service.md` — payment service setup, escrow flow, registry mint, refunds, troubleshooting
- Masumi docs (live, not bundled): https://www.masumi.network/dev/masumi/documentation
- Protocol / MIPs: https://github.com/masumi-network/masumi-improvement-proposals
- Payment service repo: https://github.com/masumi-network/masumi-payment-service
- Registry service repo (second service — buyer discovery): https://github.com/masumi-network/masumi-registry-service
- Python SDK: https://github.com/masumi-network/pip-masumi
- Registry asset naming is done by the payment node, not by you: `[1-byte nonce > 0x0f | 28-byte blake2b_224(firstUtxo.txHash ++ outputIndex_be4) | 3-byte version]`, deliberately kept outside the CIP-67/CIP-68 label-prefix range. Agent metadata rides on CIP-25 transaction metadata (label `721`) shaped by MIP-002 — not CIP-68 datums, and not CIP-30 (every wallet in this flow is node-managed, never a browser wallet). Bundled specs if a developer asks: `${CLAUDE_SKILL_DIR}/../../docs/sources/cips/CIP-0025/` and `${CLAUDE_SKILL_DIR}/../../docs/sources/cips/CIP-0067/`

### Step 3: Stand up the payment service (Preprod)

The payment service is cloned and run locally: Node.js ≥ 20, pnpm (npm is blocked by a preinstall guard), PostgreSQL ≥ 13, and a Blockfrost project key for Preprod. You do not bring your own wallets — leave the `*_MNEMONIC` vars blank and seeding generates the purchasing and selling wallets for you. Export those mnemonics from the admin dashboard immediately afterwards and paste them into `.env`, or losing the database loses the wallets. The collection wallet is optional and address-only (skip it on Preprod; use a hardware wallet on Mainnet — unset means payments collect to the selling wallet). Setup commands, `.env` shape, mnemonic export, and the admin dashboard are in `references/payment-service.md`. Fund both node-managed wallets with test ADA from the Cardano testnet faucet before continuing; price Preprod jobs in ADA unless you have a tUSDM source (see the Preprod funding note in `references/payment-service.md`).

### Step 4: Implement the MIP-003 service API (seller)

Four required endpoints on the agent service:

| Endpoint | Purpose |
|---|---|
| `POST /start_job` | Validate input, register the payment request, return the `blockchainIdentifier` plus the timing fields the buyer forwards to their purchase call (no address — the buyer pays via their own node) |
| `GET /status` | Report job state; on completion return the `result` |
| `GET /availability` | Liveness — the registry checks this periodically |
| `GET /input_schema` | Machine-readable schema for `start_job` input |

The lifecycle: `start_job` creates a payment request against the payment service, the job runs only after the service observes funds locked on-chain, and completion submits `submitResultHash` on-chain to unlock payment — a single 64-hex sha256 of `identifier_from_purchaser;` + the output string, JSON-escaped as `pip-masumi` does (same pre-image as Key principle 4, including its raw-vs-escaped caveat; not a bare sha256 of the result alone, and not a 128-char concat). Exact request/response bodies, status values, and per-framework skeletons (CrewAI, LangGraph, AutoGen) are in `references/mip-003-agentic-service-api.md`. In Python, `pip-masumi`'s `run()` generates all endpoints and the payment lifecycle.

### Step 5: Register the agent on-chain — this is what mints `AGENT_IDENTIFIER`

Registration mints an NFT carrying the agent's metadata (name, description, API base URL, pricing, example outputs) into the selling wallet — this is what makes the service discoverable, and it is the **only** source of the `agentIdentifier` that `POST /payment` requires (upstream schema: `z.string().min(57).max(250)`, not optional). The Step 4 code cannot execute a single real job until this completes, so register before testing. Registration costs a small amount of ADA; querying the registry is free. Field names in the registry body are case-sensitive; the verified shape is in `references/payment-service.md`.

`POST /registry` is **asynchronous**. It returns immediately with `state: "RegistrationRequested"` and `agentIdentifier: null`; a background job (`REGISTER_AGENT_INTERVAL`, 300 s default) submits the mint, and Preprod confirmation typically takes 5–15 minutes. Poll `GET /registry?network=Preprod`, match the entry whose `id` equals the `id` the POST returned, and wait until `state` is `RegistrationConfirmed` and `agentIdentifier` is non-null — then export that value as `AGENT_IDENTIFIER`. Do **not** try to discover it via `GET /registry/agent-identifier`: that endpoint takes `agentIdentifier` as *input* and returns on-chain metadata. Full `RegistrationState` enum and poll recipe: `references/payment-service.md`.

**Payment unit — two Mainnet stablecoins are in play. Choose deliberately:**

| Network | Token | Full asset ID (`policyId` + asset name hex) |
|---|---|---|
| **Mainnet** | **USDM** — ecosystem default | `c48cbb3d5e57ed56e276bc45f99ab39abe94e6cd7ac39fb402da47ad0014df105553444d` |
| **Mainnet** | **USDCx** (Circle xReserve) — node-dashboard default since payment-service `0.27.0` | `1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e345553444378` |
| **Preprod** | **tUSDM** (test only) | `16a55b2a349361ff88c03788f93e1e966e5d689605d044fef722ddde0014df10745553444d` |
| Either | ADA / lovelace | `""` (empty string) |

All three stablecoins use **6 decimals** (1 token = `1000000` raw units).

**Default to USDM on Mainnet** unless you have a concrete reason not to. Masumi's own
pricing guide (*Configure Agent Pricing*, written 2026-06) states all paid Sokosumi
agents settle in USDM, and on-chain the Mainnet registry carries 106 live USDM-priced
agents against a single USDCx-priced test entry, with the Mainnet escrow contract
holding USDM and no USDCx (checked 2026-07-23). USDM is **not** deprecated — it is
still minted, still escrowed, and still what Sokosumi listing requires.

USDCx is equally valid and is what a node dashboard on `0.27.0`+ writes automatically
for new Mainnet registrations, so a migration is clearly intended — it just has not
happened yet. The node itself picks no winner: it only checks that the `unit` is a
policyId+assetName hex for an asset that exists on the target network. Confirm the
unit with whoever you are listing with before you price.

Two traps: the payment service's published OpenAPI uses the **USDM** asset ID as its
only stablecoin `unit` example on every network, so do not copy it blind; and USDCx
does not exist on Preprod at all, so a USDCx-priced agent cannot be rehearsed there
with the same asset — rehearse in tUSDM or ADA. Details: `references/payment-service.md`.

### Step 6: Test the full escrow round-trip

With `AGENT_IDENTIFIER` set, walk one job end-to-end on Preprod before any mainnet key exists: payment request created → funds locked (visible on a Preprod explorer) → job executes → result hash submitted → dispute window passes → funds collected. The most common integration failures are hash mismatches from non-canonical JSON and wrong-network configuration — both are diagnosed in the troubleshooting tables in `references/mip-003-agentic-service-api.md` and `references/payment-service.md`. Fix and re-run the round-trip until it passes cleanly; do not proceed to Step 8 on a partial pass.

### Step 7: Buyer-side integration (if needed)

Buyers search the registry service for agents, call the advertised `start_job`, lock funds via their own node's purchase endpoint, poll `status`, then **independently recompute the hashes** before accepting the result — refund on mismatch. A complete TypeScript buyer flow is in `references/payment-service.md`.

### Step 8: Mainnet checklist

Only after Preprod passes cleanly:

- Separate mainnet API keys and wallets; hardware wallet as the collection target
- Registry / job pricing `unit` chosen deliberately — **USDM** (`c48cbb3d5e57ed56e276bc45f99ab39abe94e6cd7ac39fb402da47ad0014df105553444d`) is the ecosystem default and what Sokosumi listing requires; **USDCx** (`1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e345553444378`) is what a `0.27.0`+ node dashboard writes but has near-zero adoption. Both pass the node's on-chain asset check on Mainnet.
- Purchase wallet funded with ADA (fees) + whichever stablecoin you priced in; selling wallet has ADA for fees. The pricing field is `AgentPricing.Pricing[].unit` on a Web3CardanoV1 payment source and `supportedPaymentSources[].pricing.fixed[].asset` on Web3CardanoV2 — check yours with `GET /payment-source` → `paymentSourceType`
- `payByTime` and `submitResultTime` sent explicitly on every `POST /payment` — they are schema-optional but their defaults are rejected with a 400 (rules in `references/payment-service.md`); production values want ≥1h of headroom on `submitResultTime` and the dispute window
- Minimal float in node-managed hot wallets; auto-collection enabled
- Monitoring on `/availability` — an unreachable service is delisted from discovery and loses disputes

## References

- [mip-003-agentic-service-api.md](references/mip-003-agentic-service-api.md) — MIP-003 endpoint specifications, decision-log hashing (MIP-004), Python SDK fast path, framework patterns, testing
- [payment-service.md](references/payment-service.md) — payment service install and configuration, endpoint index with verified request bodies, seller/buyer flows, payment units (USDM / USDCx / tUSDM), dispute and refund mechanics, fees, troubleshooting
- Docs (live): https://www.masumi.network/dev/masumi/documentation
- Protocol specs: https://github.com/masumi-network/masumi-improvement-proposals
- Payment service: https://github.com/masumi-network/masumi-payment-service
- Python SDK: https://github.com/masumi-network/pip-masumi
- Optional (marketplace / runtime beyond this skill): [masumi-skills](https://github.com/masumi-network/masumi-skills)

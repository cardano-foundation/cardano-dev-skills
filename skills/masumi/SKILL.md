---
name: masumi
description: >-
  Guides adding decentralized payments to AI agent services on Cardano using the
  Masumi protocol — MIP-003 agentic-service APIs, smart-contract escrow, on-chain
  agent registry, and decision logging. Triggers: "monetize my agent", "agent
  payments", "charge for my AI agent", "agent-to-agent payments", "MIP-003",
  "on-chain escrow for agents", "register agent on Cardano".
allowed-tools: Read Grep Glob
---

# Masumi Agent Payments

Help the developer connect an AI agent service to the Masumi protocol: an open-source,
self-hosted payment and registry layer on Cardano. Agents expose a standard HTTP API
(MIP-003), payments are held in a Cardano smart-contract escrow, delivered work is
committed on-chain as hashes (decision logging), and agents are discoverable through
an NFT-based on-chain registry.

This skill is **agent-agnostic** (Claude Code, Cursor, Windsurf, Cline, Aider, Codex,
and other assistants that load portable `SKILL.md` skills). It stays **Cardano /
Masumi-protocol scoped** (MIP-003 APIs, escrow, registry, decision logging) —
marketplace listing and Ray-scale runtime workflows are out of scope here.

Masumi product docs are **live URLs** (not a bundled docs corpus in this repo). Prefer
those links and this skill's two local references over inventing API shapes.

## When to use

- Developer wants an AI agent (any framework: CrewAI, AutoGen, LangGraph, custom) to charge for its work
- Agent-to-agent (A2A) payments — one autonomous service hiring another without a human approving each transaction
- Smart-contract escrow between a service and unknown buyers — funds locked in a Cardano validator, released on delivery, with time-based auto-refunds (contested disputes settled by a Masumi-operated 2/3 admin multisig)
- Making an agent service discoverable via an on-chain registry entry
- Verifiable delivery — proving what input produced what output without publishing the data (hash-based decision logging)
- Implementing or debugging a MIP-003 `start_job` / `status` service API

## When NOT to use

- Trusted parties only (internal company agents, known partners) — direct API calls and internal billing are simpler
- Micro-transactions well under ~1 ADA equivalent — per-transaction fees dominate; bundle into larger units instead
- Sub-second payment confirmation required — on-chain settlement plus the node's confirmation polling takes tens of seconds to a few minutes, not instant; use a conventional payment processor
- General Cardano payment or transaction building without an agent-service context (use `build-transaction`)
- Querying chain data (use `query-chain`) or wallet integration in a dApp frontend (use `connect-wallet`)
- Full marketplace listing or Ray-scale agent runtime — out of scope for this Cardano payment skill (see References for the optional broader skill pack)

## Key principles

1. **Blockchain must earn its place.** Escrow between mutually-distrusting parties, autonomous A2A payments, and portable on-chain reputation justify the complexity. If none of those apply, a conventional payment API is the better recommendation — say so.
2. **Self-hosted and permissionless to run.** The payment service is a node the developer runs (Node.js + PostgreSQL), not a hosted dependency. Wallets are theirs; the protocol defines the contracts and APIs. The one centralized element is dispute arbitration — contested escrows are decided by a Masumi-operated 2/3 admin multisig (planned move to community governance) — so the escrow is trust-minimized, not fully trustless.
3. **The service API and the payment layer are decoupled.** The agent implements MIP-003 (four small HTTP endpoints); the payment node handles chain interaction. Any language or framework that can serve HTTP works.
4. **Delivery is proven by hashes, not by trust.** Both hashes bind the buyer's `identifier_from_purchaser` into an `identifier;<payload>` pre-image (MIP-004). The input hash — sha256 of `identifier;` + the RFC-8785-canonicalized input JSON — is committed on-chain when funds lock; the seller submits a single sha256 of `identifier;` + the (JSON-escaped) output string (`submitResultHash`, 64 hex chars) on-chain to unlock payment. Buyers recompute both independently and request a refund on mismatch — match the seller's pre-image byte-for-byte (UTF-8, no BOM, semicolon delimiter; RFC 8785 canonicalization applies only to the JSON input, not the string output).
5. **Preprod first, always.** The full flow — payment node, escrow lock, result submission, collection — should pass on the Preprod network with faucet funds before any mainnet key exists.
6. **Key hygiene is part of the integration.** Node-managed hot wallets hold operating funds only; collection goes to an external (ideally hardware) wallet configured by address, never by mnemonic.

## Workflow

### Step 1: Confirm the fit

Ask (if not already clear):

- **Who are the buyers?** Unknown third parties or other agents → escrow fits. Known/internal → recommend simpler billing and stop here.
- **Selling, buying, or both?** Seller needs the MIP-003 API + registry entry. Buyer needs discovery + purchase flow. Both is common for agent networks.
- **What stack is the agent in?** Python has an SDK (`pip-masumi`) that generates the MIP-003 endpoints; other languages implement four HTTP endpoints by hand.

### Step 2: Load skill references; use live docs URLs for the rest

Load only what the task needs (progressive disclosure):

- `references/mip-003-agentic-service-api.md` — endpoint specs, hashing rules, framework integration patterns
- `references/payment-service.md` — payment node setup, escrow flow, registry mint, refunds, troubleshooting
- Masumi docs (live, not bundled): https://www.masumi.network/dev/masumi/documentation
- Protocol / MIPs: https://github.com/masumi-network/masumi-improvement-proposals
- Payment service repo: https://github.com/masumi-network/masumi-payment-service
- Python SDK: https://github.com/masumi-network/pip-masumi
- CIP-30 / CIP-68 background (if needed): this plugin's `docs/sources/cips/`

### Step 3: Stand up the payment node (Preprod)

The payment service is cloned and run locally: Node.js ≥ 18, PostgreSQL 15, a Blockfrost project key for Preprod, and three wallets — purchasing and selling (node-managed mnemonics) plus a collection wallet (external, address only). Setup commands, `.env` shape, and the admin dashboard are in `references/payment-service.md`. Fund the test wallets from the public Cardano testnet faucet before continuing.

### Step 4: Implement the MIP-003 service API (seller)

Four required endpoints on the agent service:

| Endpoint | Purpose |
|---|---|
| `POST /start_job` | Validate input, register the payment request, return the `blockchainIdentifier` plus the timing fields the buyer forwards to their purchase call (no address — the buyer pays via their own node) |
| `GET /status` | Report job state; on completion return the `result` |
| `GET /availability` | Liveness — the registry checks this periodically |
| `GET /input_schema` | Machine-readable schema for `start_job` input |

The lifecycle: `start_job` creates a payment request against the payment node, the job runs only after the node observes funds locked on-chain, and completion submits `submitResultHash` on-chain to unlock payment — a single 64-hex sha256 of `identifier_from_purchaser;` + the JSON-escaped output string (same MIP-004 pre-image as Key principle 4; not a bare sha256 of the raw result, and not a 128-char concat). Exact request/response bodies, status values, and per-framework skeletons (CrewAI, LangGraph, AutoGen) are in `references/mip-003-agentic-service-api.md`. In Python, `pip-masumi`'s `run()` generates all endpoints and the payment lifecycle.

### Step 5: Test the full escrow round-trip

Walk one job end-to-end on Preprod before anything else: payment request created → funds locked (visible on a Preprod explorer) → job executes → result hash submitted → dispute window passes → funds collected. The most common integration failures are hash mismatches from non-canonical JSON and wrong-network configuration — both are diagnosed in the references' troubleshooting tables.

### Step 6: Register the agent on-chain

Registration mints an NFT carrying the agent's metadata (name, description, API base URL, pricing, example outputs) into the selling wallet — this is what makes the service discoverable. Registration costs a small amount of ADA; querying the registry is free. Field names in the registry body are case-sensitive; the verified shape is in `references/payment-service.md`.

**Payment unit (do not use legacy Mainnet USDM):**

| Network | Token | Full asset ID (`policyId` + asset name hex) |
|---|---|---|
| **Mainnet** | **USDCx** (Circle xReserve on Cardano) | `1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e345553444378` |
| **Preprod** | **tUSDM** (test only) | `16a55b2a349361ff88c03788f93e1e966e5d689605d044fef722ddde0014df10745553444d` |

Amounts use **6 decimals** (1 token = `1000000` raw units). Legacy Mainnet USDM (`c48cbb3d…0014df105553444d`) is historical only — new Mainnet pricing and settlement use **USDCx**. Details: `references/payment-service.md`.

### Step 7: Buyer-side integration (if needed)

Buyers search the registry service for agents, call the advertised `start_job`, lock funds via their own payment node's purchase endpoint, poll `status`, then **independently recompute the hashes** before accepting the result — refund on mismatch. A complete TypeScript buyer flow is in `references/payment-service.md`.

### Step 8: Mainnet checklist

Only after Preprod passes cleanly:

- Separate mainnet API keys and wallets; hardware wallet as the collection target
- Registry / job pricing `unit` set to **USDCx** (`1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e345553444378`) — not legacy USDM
- Purchase wallet funded with ADA (fees) + USDCx (settlement); selling wallet has ADA for fees
- Realistic `submitResultTime` / dispute-window values (an hour or more, with buffer)
- Minimal float in node-managed hot wallets; auto-collection enabled
- Monitoring on `/availability` — an unreachable service is delisted from discovery and loses disputes

## References

- [mip-003-agentic-service-api.md](references/mip-003-agentic-service-api.md) — MIP-003 endpoint specifications, decision-log hashing (MIP-004), Python SDK fast path, framework patterns, testing
- [payment-service.md](references/payment-service.md) — payment node install and configuration, endpoint index with verified request bodies, seller/buyer flows, payment units (USDCx / tUSDM), dispute and refund mechanics, fees, troubleshooting
- Docs (live): https://www.masumi.network/dev/masumi/documentation
- Protocol specs: https://github.com/masumi-network/masumi-improvement-proposals
- Payment service: https://github.com/masumi-network/masumi-payment-service
- Python SDK: https://github.com/masumi-network/pip-masumi
- Optional (marketplace / runtime beyond this skill): [masumi-skills](https://github.com/masumi-network/masumi-skills)

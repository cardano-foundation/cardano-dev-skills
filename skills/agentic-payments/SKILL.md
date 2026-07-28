---
name: agentic-payments
description: >-
  Charge for an AI agent's work on Cardano and let it pay other agents — per-run
  pricing, escrow holding an unknown buyer's funds until delivery, hash-based
  proof of delivery, on-chain identity and registry discovery, refund and
  dispute windows. Use when an agent (CrewAI, LangGraph, AutoGen, Agno, or
  custom) charges per use, when one agent hires another with no human approving
  each transaction, when choosing between writing your own escrow validator and
  adopting an agent-payment protocol, or when planning a testnet-to-mainnet
  cutover. Not for plain transfers (build-transaction), authoring the validator
  (write-validator), chain queries (query-chain), wallet checkout
  (connect-wallet), CIPs (explain-cip), or devnet setup (setup-devnet).
  Triggers: "charge for my AI agent", "agent-to-agent payments", "agent escrow
  on Cardano", "monetize my agent", "pay per API call on-chain", "agent
  registry".
allowed-tools: Read Grep Glob
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# agentic-payments

Help a developer make an AI agent service **chargeable, verifiable, and discoverable**
on Cardano.

The Cardano Developer Portal frames an on-chain agent as four capabilities — a wallet
and signing, payments, a verifiable identity, and discovery. The first is ordinary SDK
work covered by `build-transaction` and `connect-wallet`. **This skill covers the other
three**, which is where the design decisions and the expensive mistakes live.

Start by reading the bundled orientation, which is short and sets the vocabulary:

```
${CLAUDE_SKILL_DIR}/../../docs/sources/developer-portal/developers/curriculum/dapps/ai-agents/
```

This skill is implementation-neutral. It teaches the *pattern* and the decision
criteria; it deliberately carries no endpoint specs, request bodies, or contract
addresses, because those drift and the bundled sources are the refreshed place for
them. When a developer needs an exact wire format, send them to the implementation's
own live OpenAPI or spec — never invent one, and never trust a request shape recalled
from memory over a spec the developer can `curl`.

## When to use

- An agent service must **charge per run** and the buyers are unknown third parties
- **Agent-to-agent (A2A) payments** — one autonomous service hiring another with no human approving each transaction
- **Escrow between mutually distrusting parties** — funds locked until delivery, with a time-based refund if delivery never happens
- **Verifiable delivery** — proving which input produced which output without publishing either
- **Identity and discovery** — giving an agent a DID and a registry entry so peers can find it by capability
- **Choosing an approach** — deciding between writing your own escrow validator, adopting an existing agent-payment protocol, or staying off-chain
- **Planning a mainnet cutover** for a paid agent service (pricing unit, wallet custody, dispute windows, key handling)

## When NOT to use

- **Trusted parties only** — internal company agents, known partners under contract. Direct API calls with conventional billing are simpler, cheaper, and faster. Say so plainly rather than building escrow nobody needs.
- **Value per job below the fee floor** — every on-chain settlement costs network fees plus whatever the protocol charges, and protocol fees usually have a *fixed floor* rather than being purely proportional. When the floor is a large fraction of the job price, bundle many jobs into one settlement instead of settling per call. Measure this in Step 3 before writing code.
- **Latency-sensitive payment confirmation** — on-chain settlement plus confirmation depth plus any batching interval puts realistic confirmation in the minutes, not seconds. If the buyer must be charged and served inside a few seconds, use a conventional payment processor.
- **No paying counterparty** — an internal audit trail with no buyer gets nothing from a payment protocol; a database and signed logs are the right tool.
- General payment or transaction building without an agent-service context → `build-transaction`
- Querying chain data → `query-chain`; browser wallet integration in a dApp frontend → `connect-wallet`
- **Authoring the escrow validator itself** → `write-validator` (and `review-contract` before it holds real funds)
- CIP/standard walkthroughs → `explain-cip`; DRep registration and voting → `governance-guide`; local devnet → `setup-devnet`
- **Ledger-level transaction failures** on the escrow, delivery, or collection transaction — `ValueNotConservedUTxO`, min-UTxO, collateral, script budget — are Cardano transaction problems → `debug-transaction`. Payment-layer failures stay here: payment never detected, delivery hash mismatch, registry entry never confirmed, payout not firing.

## Key principles

1. **The blockchain must earn its place.** Escrow between parties who cannot sue each
   other, autonomous A2A payment, and portable on-chain reputation each justify the
   complexity. If none applies, the honest recommendation is a conventional payment
   API — give it, even though this skill is about the on-chain path.

2. **Keep the service API and the payment layer decoupled.** The agent exposes a small
   HTTP contract (start a job, report status, advertise availability and input schema);
   a separate component watches the chain and settles. Any language or framework that
   can serve HTTP works, and the agent's business logic stays testable without a chain.

3. **Delivery is proven by hashes, not by trust.** Commit a hash of the input when funds
   lock and a hash of the output when work is delivered; the payload itself never goes
   on-chain. Both sides must derive the identical pre-image — same field order, same
   canonicalization, same encoding, same delimiter, byte for byte. **Verify the
   counterparty's actual canonicalization implementation, not the standard it claims
   to follow**; libraries that both advertise "canonical JSON" routinely disagree on
   number formatting and escaping, and every such disagreement surfaces as a delivery
   dispute over work that was actually correct.

4. **Every escrow branch needs a timeout.** A buyer must be able to reclaim funds if
   delivery never comes; a seller must be able to collect after the dispute window
   closes. An escrow with any path that can lock funds indefinitely is a bug, not a
   feature — check this explicitly whether you write the validator or adopt one.

5. **Know who arbitrates before you adopt.** Most production agent-payment escrows are
   *trust-minimized*, not trustless: contested cases are usually settled by a multisig
   or a governance process rather than by code alone. That may be perfectly acceptable
   — but the developer should learn it from you, up front, not from a dispute.

6. **Testnet round trip before any mainnet key exists.** The full loop — lock, deliver,
   prove, collect, and at least one refund path — must pass on a test network with
   faucet funds. A hash mismatch or a wrong-network key found on mainnet costs real
   money; found on testnet it costs nothing.

7. **Key hygiene is part of the integration, not an afterthought.** A service that holds
   spending keys should hold operating float only. Payouts should sweep to an external
   (ideally hardware) wallet configured **by address**, never by seed phrase — putting
   the treasury seed and the internet-facing service behind one secret means one
   compromise takes both. Never write a seed phrase into a skill, a repo, a prompt, or
   a log line.

8. **Read fee and timing parameters from the running system, not from documentation.**
   Fee floors, confirmation thresholds, batching intervals, and dispute windows are
   configuration, and they change between releases. Have the developer read the values
   their deployment actually uses, and quote those in any economic model.

## Workflow

Copy this checklist and check items off. Step 1 and Step 7 are gates, not formalities.

```
Agent monetization progress:
- [ ] Step 1: Fit confirmed (unknown buyers or A2A — otherwise stop, recommend simpler billing)
- [ ] Step 2: Payment architecture chosen and justified
- [ ] Step 3: Economics modelled — fee floor, break-even job size, latency budget
- [ ] Step 4: Service API contract defined
- [ ] Step 5: Identity and registry entry designed
- [ ] Step 6: Delivery-proof scheme agreed with the counterparty
- [ ] Step 7: Full round trip passed on a test network (gate)
- [ ] Step 8: Mainnet cutover checklist cleared
```

### Step 1: Confirm the fit — this is a gate

Ask, and stop here if the answers point off-chain:

- **Who are the buyers?** Unknown third parties or other agents → escrow fits. Known, internal, or contractually bound → recommend conventional billing and stop.
- **Selling, buying, or both?** A seller needs the service API plus a registry entry. A buyer needs discovery plus a purchase flow. Agent networks usually need both.
- **What is one job worth, and how many per day?** Feeds Step 3 — and often ends the conversation there.
- **How fast must payment confirm?** Seconds → off-chain. Minutes are acceptable → continue.
- **What stack is the agent in?** Determines whether an SDK exists or the HTTP contract is implemented by hand.

### Step 2: Choose the payment architecture

| Approach | Choose when | Cost |
|---|---|---|
| **Write your own escrow validator** | Bespoke settlement logic, unusual dispute rules, or you need full control of upgrade and arbitration | Highest — validator design, audit, and ongoing maintenance. Use `write-validator`, then `review-contract` before it holds funds |
| **Adopt an agent-payment protocol** | Standard "pay for a job, deliver, settle" shape; you want registry, identity, and dispute handling included | Lowest to build; you inherit the protocol's fee schedule, timings, and arbitration model |
| **Off-chain billing, chain for settlement only** | Many small jobs, few counterparties; per-job on-chain settlement is uneconomic | Middle — you build metering and periodic settlement yourself |

Cardano-native building blocks for the first option are already bundled — grep the
use-case templates for escrow and payment patterns before designing from scratch:

```
${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-use-case-templates/
```

For the second option, **survey the field before adopting anything.** Rather than pin a
list of protocols here — which would go stale and would read as an endorsement — read
the Developer Portal's AI-agents section and see which implementations it currently
documents:

```
${CLAUDE_SKILL_DIR}/../../docs/sources/developer-portal/developers/curriculum/dapps/ai-agents/
```

**A worked example is not a recommendation.** This area is young and moving quickly, and
the bundled portal is a snapshot, not a market survey. Tell the developer plainly how
thin the field is rather than letting whatever is documented become the default by
absence of alternatives, and check whether newer implementations exist before deciding.

Evaluate every candidate against the same criteria, and report the answers rather than
the marketing:

| Criterion | What to establish | Where it bites |
|---|---|---|
| **Timeouts** | Every branch, including the failure branches, has a bound | Key principle 4 — unbounded locks strand funds |
| **Arbitration** | Who decides a contested case, and can they move funds | Key principle 5 — "trustless" rarely is |
| **Key custody** | Can payouts target an external address, or is a seed phrase required | Key principle 7 — treasury behind a service secret |
| **Fee schedule** | Percentage *and* fixed floor, read from the running system | Step 3 — decides whether the model works at all |
| **Settlement latency** | Confirmations, polling, batching, dispute window | Step 3 — usually far worse than assumed |
| **Exit cost** | What it takes to migrate off, and who holds the registry entry | Lock-in is a design decision, not a detail |

Get exact endpoint, fee, and contract detail from the candidate's own live
specification — its published OpenAPI or spec repository — not from this skill and not
from memory. If a protocol's documentation cannot answer the six rows above, that is
itself a finding worth reporting to the developer.

### Step 3: Model the economics before writing code

Do this arithmetic with the developer explicitly. It is the single most common reason a
paid-agent integration should not be built as designed.

1. **Network fees per settled job.** Count *every* on-chain transaction in one job's
   lifecycle — locking, proving delivery, collecting, and any refund path — not just one.
2. **Protocol fee.** Find both the percentage and the **fixed floor**. A percentage fee
   with a floor behaves as a flat fee for small jobs; the percentage only starts to
   matter above the crossover point. Compute that crossover.
3. **Break-even job size.** Total fees should be a small fraction of job value — a
   common rule of thumb is fees under 10% of the price. Below that, bundle multiple
   jobs into a single settlement rather than settling per call.
4. **Latency budget.** Add confirmation depth, detection polling, batching intervals,
   and the dispute window before payout. State the realistic end-to-end number to the
   developer; it is usually much larger than they assume.

If the numbers do not work, say so and revisit Step 2 — bundling or off-chain metering
is the fix, not a smaller fee.

### Step 4: Define the service API contract

A paid agent service converges on the same small HTTP surface regardless of protocol:

| Endpoint role | Purpose |
|---|---|
| **Start a job** | Validate input, register the payment obligation, return an identifier the buyer uses to pay and to poll |
| **Job status** | Report state, and return the result once delivered |
| **Availability** | Liveness, so a registry or buyer can tell the service is up |
| **Input schema** | Machine-readable description of accepted input, so a buyer can call the agent without human integration work |

On Cardano this shape is standardized as an *agentic service API*; the bundled portal
pages introduce it, and the adopted protocol's own specification is authoritative for
field names, status enums, and error shapes. **Fetch that spec — do not reconstruct it
from memory.** Where a running node's own generated OpenAPI disagrees with prose
documentation, the generated spec wins; ask the developer to `curl` it.

Keep the agent's business logic behind this boundary so it can be tested with no chain
and no funds.

### Step 5: Design identity and discovery

- **Identity.** A DID or equivalent on-chain credential lets a counterparty confirm they are talking to the agent they think they are, and underpins any portable reputation later.
- **Discovery.** A registry entry — typically an on-chain token carrying metadata such as name, capability description, API base URL, and pricing — makes the service findable by capability rather than by prior arrangement.
- **Metadata standards.** Registry entries generally build on Cardano's token metadata standards. Read them from the bundled CIPs rather than restating them: `${CLAUDE_SKILL_DIR}/../../docs/sources/cips/CIP-0025/` for transaction-metadata-based token metadata, `${CLAUDE_SKILL_DIR}/../../docs/sources/cips/CIP-0067/` and `${CLAUDE_SKILL_DIR}/../../docs/sources/cips/CIP-0068/` for asset-name labelling and datum-based metadata. Use `explain-cip` if the developer wants a walkthrough.
- **Registration is usually asynchronous.** Minting and confirmation take minutes, and the resulting identifier is often required before the service can accept its first real job. Register early, poll for confirmation, and treat the confirmed identifier as a prerequisite for testing — not as something to fetch later.

### Step 6: Agree the delivery-proof scheme

Fix these with the counterparty *before* the first paid job, and write them down:

- **Pre-image construction** — exactly which fields, in what order, with what delimiter
- **Canonicalization** — which library, which version, verified by running it, not by reading its README
- **Encoding** — UTF-8, no byte-order mark; decide explicitly whether the payload is escaped or raw
- **Hash function and encoding of the digest** — and its exact expected length

Then have both sides hash a shared fixture and compare digests before any money moves.
Two implementations that agree on ASCII payloads routinely diverge on quotes,
backslashes, newlines, tabs, and non-ASCII characters — so the fixture must include all
of them. This ten-minute check prevents the single most common dispute in paid-agent
integrations.

### Step 7: Full round trip on a test network — this is the gate

Do not proceed to mainnet until all of these pass on a test network with faucet funds:

- [ ] Buyer locks funds; the service detects the lock
- [ ] Job runs and delivers; proof of delivery is accepted
- [ ] Seller collects after the dispute window
- [ ] **A refund path is exercised** — deliberately let one job expire undelivered and confirm the buyer is made whole
- [ ] Delivery-hash fixture from Step 6 matches across both implementations
- [ ] Status endpoint reports every state transition correctly, including failure

The refund path is the one teams skip and the one that strands real funds. Test it.

### Step 8: Mainnet cutover checklist

- [ ] **Pricing unit chosen deliberately** — ADA or a specific stablecoin. Confirm the exact asset identifier against the issuer's own current documentation at cutover time; do not carry an asset ID over from a tutorial, a testnet config, or memory. A wrong asset ID sends real funds somewhere unrecoverable.
- [ ] **Fresh mainnet keys** — never reuse a testnet seed phrase
- [ ] **Service wallets hold operating float only**; payouts sweep to an external wallet configured by address
- [ ] **Dispute and refund windows** re-checked against production values, not testnet defaults
- [ ] **Secrets** out of the repo, out of logs, out of prompts; rotation plan written down
- [ ] **Monitoring** on undetected payments, stuck jobs, failed collections, and unconfirmed registry entries
- [ ] **Registry entry** re-created on mainnet — testnet identifiers do not carry over
- [ ] Economics from Step 3 re-run with production fee parameters

## References

Bundled, and refreshed weekly — read these rather than relying on recall:

- `${CLAUDE_SKILL_DIR}/../../docs/sources/developer-portal/developers/curriculum/dapps/ai-agents/` — AI agents on Cardano: the four capabilities, and the portal's worked example of an agent-economy protocol
- `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-use-case-templates/` — grep for escrow and payment patterns before designing a validator
- `${CLAUDE_SKILL_DIR}/../../docs/sources/cips/CIP-0025/`, `CIP-0067/`, `CIP-0068/` — token metadata and asset-name labelling used by registry entries

Related skills: `write-validator` and `review-contract` (building your own escrow),
`build-transaction` (the transactions underneath), `query-chain` (watching for
settlement), `debug-transaction` (ledger-level failures), `explain-cip` (metadata
standards), `setup-devnet` (local test network).

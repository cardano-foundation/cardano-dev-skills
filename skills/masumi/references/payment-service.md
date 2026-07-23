# Masumi Payment Service

The self-hosted payment node: endpoints, escrow flows, decision logging, wallets.

The live OpenAPI spec is served by the node itself at `${PAYMENT_SERVICE_URL%/api/v1}/docs`
(Swagger) — trust it over any doc snapshot.

MIP-003 service API (what the agent implements) → [mip-003-agentic-service-api.md](mip-003-agentic-service-api.md).

## Contents

- What it does
- Architecture
- Install + setup
- Base URLs
- Auth
- Endpoint index
- Verified request bodies (from the live spec) — incl. Payment units (stablecoin)
- Seller flow
- Buyer flow (TypeScript)
- Dispute + refund
- Wallets
- Fees
- Troubleshooting
- Best practices
- Resources

---

## What it does

Running a payment node enables:
- A2A payments (autonomous agent-to-agent)
- Smart-contract escrow — funds lock in a validator, release on delivery, with
  time-locked auto-refunds. Contested cases are decided by the Masumi protocol's
  admin multisig (2/3), so the escrow is trust-minimized, not fully trustless.
- Decision logging — an `inputHash` (sha256 of `identifier_from_purchaser;` + the
  canonical input — canonicalizer must match the seller's, see
  `mip-003-agentic-service-api.md`) is committed when funds lock, and a separate result hash
  (sha256 of `identifier_from_purchaser;` + the output string — JSON-escaped per `pip-masumi`,
  raw per MIP-004 §2.2; see the note under `POST /payment/submit-result`) when the seller submits
- Dispute + refund (time-based unlock; admin-multisig arbitration for disputes)

Each developer runs their own node — there is no shared centralized service, but
dispute arbitration and the protocol fee route through Masumi-operated addresses.

---

## Architecture

```
Payment Service (you run this)
├── Admin Dashboard  http://localhost:3001/admin
│   ├── Wallets, API keys, transactions, agent registration UI
├── REST API         http://localhost:3001/api/v1
│   ├── /payment, /purchase (escrow flow)
│   ├── /registry (on-chain agent NFT mint)
│   ├── /wallet, /payment-source, /webhooks, ...
├── Background jobs (cron; tunable via env; shipped .env.example uses minutes-scale
│   │   values, but if left unset the code falls back to seconds-scale intervals)
│   ├── Payment detection    CHECK_TX_INTERVAL (.env.example: 180s / unset fallback: 20s)
│   ├── Auto-collection      CHECK_COLLECTION_INTERVAL (.env.example: 300s / unset fallback: 15s)
│   ├── Batch purchases      BATCH_PAYMENT_INTERVAL (.env.example: 240s / unset fallback: 30s)
└── PostgreSQL (payment requests, purchases, wallets, keys)
```

---

## Install + setup

### Prerequisites
- Node.js ≥ 20
- pnpm — the repo pins `pnpm@10.30.2` via `packageManager`, and a `preinstall`
  guard in both the root and `frontend/` package.json exits 1 on npm/yarn with
  "This project uses pnpm. Use: pnpm install"
- PostgreSQL ≥ 13
- A Blockfrost project key for the target network

### Steps
```bash
git clone https://github.com/masumi-network/masumi-payment-service
cd masumi-payment-service
pnpm install                # also generates the Prisma client (postinstall)
cp .env.example .env        # then fill in the values below
pnpm run prisma:migrate     # apply the DB schema (upstream README uses prisma:migrate:dev locally)
pnpm run prisma:seed        # seed the admin API key (reads ADMIN_KEY from .env)

# Build the admin dashboard (frontend) before logging in:
cd frontend && pnpm install && pnpm run build && cd ..
```
Seeding is what writes `ADMIN_KEY` into the database — skip it and the admin
dashboard login will fail.

`SEED_ONLY_IF_EMPTY` gates **PaymentSource seeding only** (checked separately for
`Web3CardanoV1` and `Web3CardanoV2`); it does not gate the admin-key write, which
runs on every seed. Leave it `True` on an established database — with it off the
seed retries `paymentSource.create` and dies on the `@@unique([network,
smartContractAddress])` constraint.

**Re-seeding does not rotate the admin key.** The upsert is keyed on the hash of
the current `ADMIN_KEY`, so a changed value creates a *second* `canAdmin: true`
row and leaves the previous one `Active` — a live admin credential you believe is
dead. To actually rotate: seed (or `POST /api/v1/api-key`) the new key, confirm it
authenticates, then revoke the old one with `DELETE /api/v1/api-key` taking
`{ "id": "<old key id>" }`, which sets `status: Revoked` + `deletedAt`. Get the ids
from `GET /api/v1/api-key`.

### `.env`
There is no `NETWORK` variable — the service reads none. Which network(s) a node serves
is decided at seed time by which Blockfrost keys are set: `BLOCKFROST_API_KEY_PREPROD`
seeds a Preprod payment source and Preprod hot wallets, `BLOCKFROST_API_KEY_MAINNET`
seeds Mainnet ones, and `prisma/seed.ts` runs both branches independently. Set only the
key for the network you want. At request time each call picks its own network via the
required `network` body/query field (`Preprod` | `Mainnet`).

```env
ENCRYPTION_KEY=your-32-char-min-secret       # REQUIRED: encrypts wallet secrets in the DB
BLOCKFROST_API_KEY_PREPROD=preprod...
# BLOCKFROST_API_KEY_MAINNET=mainnet...      # uncomment only to also serve Mainnet
DATABASE_URL=postgresql://user:pass@localhost:5432/masumi?schema=public
PORT=3001
ADMIN_KEY=your-secure-admin-key-min-15-chars

# All three are OPTIONAL. Leave the mnemonics blank and `pnpm run prisma:seed` brews a
# fresh 24-word mnemonic per hot wallet (prisma/seed.ts `createMnemonicIfMissing` ->
# `MeshWallet.brew`). Export them immediately after the first seed (see below) — they
# then exist only inside the DB, encrypted with ENCRYPTION_KEY.
PURCHASE_WALLET_PREPROD_MNEMONIC=""
SELLING_WALLET_PREPROD_MNEMONIC=""
# ADDRESS ONLY, never a mnemonic. Optional: if unset, the SELLING_WALLET is used as the
# collection target. Ignorable on Preprod; set it (hardware wallet) before Mainnet.
COLLECTION_WALLET_PREPROD_ADDRESS=""

AUTO_WITHDRAW_PAYMENTS=true
AUTO_WITHDRAW_REFUNDS=true
BLOCK_CONFIRMATIONS_THRESHOLD=20
```

**Never commit `.env`.** Use a hardware wallet for the collection wallet on mainnet.

### Export the node-generated mnemonics (first run, before funding anything)

If you left the mnemonics blank, seeding generated them and they live only in the
database, encrypted under `ENCRYPTION_KEY`. Export them now:

- **Admin dashboard** — `http://localhost:3001/admin` -> select the Purchasing or
  Selling wallet -> **Export Wallet** -> copy the mnemonic.
- **API** — `GET /wallet?walletType=Selling&id=<WALLET_ID>&includeSecret=true`
  (`walletType` is `Selling` or `Purchasing`; get `<WALLET_ID>` from `GET /wallet/list`,
  or from `GET /payment-source` as the Masumi docs describe). The decrypted 24-word
  phrase comes back as `Secret.mnemonic`.

Paste both phrases back into `.env` so a re-seed against a fresh database restores the
same wallets, and keep an offline copy. Skipping this on Mainnet means losing the
database loses the funds.

### Start
```bash
pnpm run dev                      # dev mode, hot reload
# or
pnpm run build && pnpm start      # prod
```

Admin: `http://localhost:3001/admin` (log in with `ADMIN_KEY`).
Swagger: `http://localhost:3001/docs`.

---

## Base URLs

| Env | URL |
|---|---|
| Local self-host | `http://localhost:3001/api/v1` |
| Your hosted deployment | wherever you deploy the node |

Store as `PAYMENT_SERVICE_URL` in `.env`. For Preprod, self-host and pass
`network:"Preprod"` in request bodies — the network is a body/query parameter,
not a different host.

---

## Auth

```http
token: YOUR_API_KEY
```

The header name is `token` (apiKey scheme, verified against the live spec).
Store the key as `PAYMENT_API_KEY` in `.env`; generate keys in the admin dashboard.

**The three core escrow resources are singular**: `/payment`, `/purchase`, `/registry`
(older docs used the plural form for these three — that's wrong; trust the live `/docs`).
This does NOT generalize to every resource — several others are plural, e.g.
`/webhooks`, `/inbox-agents`, `/utxos`, `/rpc-api-keys` (see the index below).

---

## Endpoint index

**Health + keys**
- `GET /health`
- `GET /api-key-status`
- `GET | POST | PATCH | DELETE /api-key`

**Wallets**
- `GET | POST | PATCH /wallet` *(GET is a single wallet by `walletType`+`id`)*
- `GET /wallet/list` *(list managed wallets)*
- `GET | POST | PATCH | DELETE /wallet/low-balance`
- `GET /utxos`, `GET /rpc-api-keys`

**Payments (seller)**
- `GET | POST /payment`
- `GET /payment/diff`, `/payment/diff/next-action`, `/payment/diff/onchain-state-or-result`
- `GET /payment/count`
- `POST /payment/submit-result`
- `POST /payment/authorize-refund`
- `POST /payment/error-state-recovery`
- `POST /payment/resolve-blockchain-identifier`
- `POST /payment/income`
- `POST /payment/x402` *(HTTP 402 / x402)*

**Purchases (buyer)**
- `GET | POST /purchase`
- `GET /purchase/diff`, `/purchase/diff/next-action`, `/purchase/diff/onchain-state-or-result`
- `GET /purchase/count`
- `POST /purchase/request-refund`
- `POST /purchase/cancel-refund-request`
- `POST /purchase/error-state-recovery`
- `POST /purchase/resolve-blockchain-identifier`
- `POST /purchase/spending`

**Registry (NFT mint on-chain)**
- `GET | POST | DELETE /registry`
- `GET /registry/wallet`, `/registry/agent-identifier` *(lookup BY agentIdentifier — not a way to obtain one)*
- `GET /registry/diff`, `/registry/count`
- `POST /registry/deregister`

**Inbox agents (A2A)**
- `GET | POST | DELETE /inbox-agents`
- `GET /inbox-agents/wallet`, `/agent-identifier`, `/diff`, `/count`
- `POST /inbox-agents/deregister`

**Payment sources**
- `GET /payment-source`
- `GET | POST | PATCH | DELETE /payment-source-extended`

**Swaps (ADA ↔ stablecoin)**
- `POST /swap`, `GET /swap/confirm`, `/swap/transactions`, `/swap/estimate`
- `POST /swap/cancel`, `/swap/acknowledge-timeout`

**Webhooks**
- `GET | POST | PATCH | DELETE /webhooks`, `POST /webhooks/test`

**Monitoring**
- `GET /monitoring`
- `POST /monitoring/trigger-cycle`, `/monitoring/start`, `/monitoring/stop`

Registry **search/discovery** is a separate service — the **Masumi Registry Service**
(https://github.com/masumi-network/masumi-registry-service), a second self-hosted
deployment (Node.js ≥ 20, PostgreSQL 15, its own Blockfrost key, default port
**3000**). The payment node's `/registry` endpoints only mint/burn the NFT on-chain;
they cannot search. Budget for running two services, not one.

| Env | Registry base URL |
|---|---|
| Local self-host | `http://localhost:3000/api/v1` |
| Public dev instance | `https://registry.masumi.network/api/v1` |

Store as `REGISTRY_SERVICE_URL` (must include `/api/v1`). Auth uses the same
`token:` header scheme as the payment node but a **separate credential** — store as
`REGISTRY_API_KEY`; `PAYMENT_API_KEY` will not work here.

- Self-hosted: the first key is seeded from the registry's own `ADMIN_KEY`
  (min 15 chars, `Admin` permission); mint further keys via `POST /api-key`.
- Public dev instance: key `public-test-key-masumi-registry-c23f3d21`. Upstream
  marks it testing/development only ("Please do not use this in production").
  Verified 2026-07-23: it serves `network:"Preprod"` (HTTP 200) but returns
  HTTP 500 for `network:"Mainnet"` — **for Mainnet discovery, self-host.**

Discovery endpoints (both POST, `limit` 1–50 default 10, response envelope
`{ status, data: { entries: [...] } }`):
- `POST /registry-entry` — filter-only query; `filter.status` values are
  `Online` | `Offline` | `Deregistered` | `Invalid`
- `POST /registry-entry-search` — same, plus a **required** `query` string
  (1–120 chars) for fuzzy match over metadata, capability, asset identifier,
  `apiBaseUrl` and tags

Gotcha: the registry's Swagger UI labels the auth header `api-key`, but the
running service reads `token` (verified live — an `api-key` header returns 401).

---

## Verified request bodies (from the live spec)

### `POST /payment` — create payment request (seller)
```json
{
  "network":"Preprod",                  // required
  "agentIdentifier":"<min 57 chars>",   // required
  "inputHash":"<sha256 hex>",           // required
  "supportedPaymentSourceIndex":0,      // int 0-24; REQUIRED on V2 Cardano, FORBIDDEN on V1
  "paymentSourceType":"Web3CardanoV2",  // optional; pins the expected source type
  "RequestedFunds":[                    // Dynamic pricing ONLY — omit entirely for Fixed
    {"unit":"","amount":"10000000"}     // unit="" = ADA/lovelace
  ],
  "payByTime":"<ISO 8601, e.g. now + 10 min>",   // REQUIRED in practice — see below
  "submitResultTime":"<ISO 8601, e.g. now + 45 min>", // REQUIRED in practice — see below
  "unlockTime":"<ISO 8601>",                 // optional; defaults to submitResultTime + 6h
  "externalDisputeUnlockTime":"<ISO 8601>",  // optional; defaults to submitResultTime + 12h
  "identifierFromPurchaser":"a1b2c3d4e5f6a7"  // required; hex nonce, 14–26 chars, length must be even (odd length 400s: "Purchaser identifier is not a valid hex string")
}
```
`supportedPaymentSourceIndex` picks which entry of the agent's advertised
`supported_payment_sources` is being paid. Omit it entirely on a Web3CardanoV1 source.
The node throws `V2 Cardano payments require supportedPaymentSourceIndex to select a
priced Cardano source`, and inversely `V1 Cardano payments must not set
supportedPaymentSourceIndex; pricing comes from AgentPricing`.

`unit:""` means ADA/lovelace. For a native-asset stablecoin: the full
policyId+assetName concatenated — see **Payment units** below. On Mainnet both
**USDM** and **USDCx** are accepted; USDM is the ecosystem default.

**Where the price comes from.** The node fetches the agent's on-chain registry NFT
metadata by `agentIdentifier` and branches on that entry's `AgentPricing.pricingType`
(set at `POST /registry`, below) — it does not trust an amount in the request:

| Registry `pricingType` | `RequestedFunds` on `POST /payment` | Amount escrowed |
|---|---|---|
| `Fixed` | **must be omitted/null.** Sending it → `400 For fixed pricing, RequestedFunds must be null` | the registry entry's `AgentPricing.Pricing[]` |
| `Dynamic` | **required, non-empty**, each `amount` > 0. Omitting it → `400 For dynamic pricing, RequestedFunds must be provided` | exactly the `RequestedFunds[]` you send |
| `Free` | n/a | `400 Pricing type not supported for payments` — a Free agent cannot open an escrow payment request |

So a Fixed-priced agent sets its price **once**, in the `AgentPricing` block of
`POST /registry`, and never sends an amount per job — which is why the seller
examples in [mip-003-agentic-service-api.md](mip-003-agentic-service-api.md) omit
`RequestedFunds`. The buyer never sends amounts either: `POST /purchase` derives the
cost from the `blockchainIdentifier`.

**`payByTime` and `submitResultTime` are optional in the schema but required in
practice.** Both default to `1970-01-01T12:00:00.000Z`, and the handler rejects that
default with HTTP 400 — omit them and no payment is ever created. Always send both.

Handler constraints on `POST /payment` (all rejections are HTTP 400):

| Rule | Error message |
|---|---|
| `payByTime` ≤ `submitResultTime` − 5 min | `Pay by time must be before submit result time (min. 5 minutes)` |
| `payByTime` ≥ now − 5 min | `Pay by time must be in the future (max. 5 minutes)` |
| `submitResultTime` ≥ now + 15 min | `Submit result time must be in the future (min. 15 minutes)` |
| `submitResultTime` ≤ `unlockTime` − 15 min | `Submit result time must be before unlock time with at least 15 minutes difference` |
| `externalDisputeUnlockTime` ≥ `unlockTime` + 15 min | `External dispute unlock time must be after unlock time (min. 15 minutes difference)` |

Omitting both defaults trips the first rule (both defaults are equal), so the error you
actually see is `Pay by time must be before submit result time (min. 5 minutes)` — it
gives no hint that the missing fields are the cause.

`unlockTime` and `externalDisputeUnlockTime` are genuinely optional: they default to
`submitResultTime + 6h` and `submitResultTime + 12h`. If you override `unlockTime`
alone, keep it ≤ `submitResultTime + 11h45m` or the defaulted
`externalDisputeUnlockTime` will violate the 15-minute rule.

**These four fields change representation at each hop** — get it wrong and the purchase 400s:

| Hop | Wire type | Units |
|---|---|---|
| `POST /payment` request (seller → own node) | ISO 8601 date-time string (`ez.dateIn()`) | — |
| `POST`/`GET /payment` response | decimal string | unix **milliseconds** |
| `/start_job` response (seller → buyer) | JSON number per MIP-003 (`int`); pass-through sellers emit the node's string | unix **milliseconds** |
| `POST /purchase` request (buyer → own node) | required `z.string()`, parsed with `BigInt()` | unix **milliseconds** |

Forward the node's value unchanged in magnitude — never convert to or from seconds. Only
the JSON type may change: wrap in `String(...)` on the buyer side, because `POST /purchase`
rejects numbers on `z.string()` and compares the parsed BigInt against `Date.now()` in
milliseconds. A seconds-scale value trips the first guard with the misleading error
`Pay by time must be before submit result time (min. 5 minutes)`.

### `GET /payment` — check status
Query: `network` (required), optional `filterSmartContractAddress`,
`filterOnChainState`, `searchQuery`, `includeHistory`, plus `cursorId | limit` (1..100).
`filterOnChainState` enum (10 values): `FundsLocked`, `FundsOrDatumInvalid`,
`ResultSubmitted`, `RefundRequested`, `Disputed`, `WithdrawAuthorized`,
`RefundAuthorized`, `Withdrawn`, `RefundWithdrawn`, `DisputedWithdrawn`.

For exact lookup by blockchain identifier → `POST /payment/resolve-blockchain-identifier`.

### `POST /payment/submit-result` — seller submits decision hash
```json
{
  "network":"Preprod",                  // required
  "blockchainIdentifier":"<id>",        // required, ≤8000 chars
  "submitResultHash":"<sha256 hex>"     // required, exactly 64 hex chars: ^[0-9a-fA-F]{64}$
}
```
`submitResultHash` is a **single** 64-hex sha256 of the MIP-004 pre-image
`identifier_from_purchaser;` + the output string (UTF-8, no BOM) —
not a bare sha256 of the result alone, and not a concatenation of the input and
result hashes. The input hash travels separately as `inputHash` on `POST /payment`
(seller) and `POST /purchase` (buyer).
Migration note: old docs said `{identifier, decisionHash}`. The live shape is
`{network, blockchainIdentifier, submitResultHash}`.

> **Raw vs JSON-escaped output.** MIP-004 §2.1–2.2 (Draft, `main`) specifies the **raw**
> UTF-8 output string. `pip-masumi` ≥ 0.1.41 (2025-10-11) escapes it first —
> `json.dumps(output, ensure_ascii=False)[1:-1]` — and most live sellers run `pip-masumi`,
> so escaped is the de-facto convention. The two pre-images are identical unless the output
> contains `"`, `\`, a newline, a tab, or another control character. Confirm the
> counterparty's variant before disputing a hash.

### `POST /payment/authorize-refund` — seller approves refund
```json
{
  "network":"Preprod",
  "blockchainIdentifier":"<id>"
}
```

### `POST /purchase/request-refund` — buyer requests
```json
{
  "network":"Preprod",
  "blockchainIdentifier":"<id>"
}
```

### `POST /registry` — mint agent NFT

**First, find out which payment source you are on.** `GET /payment-source` returns a
`paymentSourceType` per source — `Web3CardanoV1` (legacy, top-level pricing) or
`Web3CardanoV2` (per-source pricing, 0% protocol fee). The body shape below depends on
it, and the node rejects the wrong combination with a 400. V2 sources are not created by
default: they come from the dashboard's payment-source setup, or from seeding with
`SELLING_WALLET_V2_*_MNEMONIC` / `PURCHASE_WALLET_V2_*_MNEMONIC` — so a stock install is
V1-only. Since payment service 0.28.0 upstream recommends V2 for new agents.

Required on both types: `network`, `sellingWalletVkey`, `name`, `description`,
`apiBaseUrl`, `Tags[]`, `ExampleOutputs[]`, `Capability`, `Author`.

| Field | Web3CardanoV1 | Web3CardanoV2 |
|---|---|---|
| `AgentPricing` (top-level) | **required** — omitting it 400s with `V1 registrations require the top-level AgentPricing field` | **forbidden** — 400 `V2 registrations must not set AgentPricing; put pricing inside each supportedPaymentSources[].pricing field` |
| `supportedPaymentSources[]` | **forbidden** — 400 `V1 registrations must not set supportedPaymentSources; use the top-level AgentPricing field` | **required** — 400 `V2 registrations require supportedPaymentSources with source-local pricing` |

The body below is the **Web3CardanoV1** shape.

```json
{
  "network":"Preprod",
  "sellingWalletVkey":"<vkey from GET /wallet>",
  "name":"My Agent",
  "description":"Short description (≤250)",
  "apiBaseUrl":"https://my-agent.example.com",
  "Tags":["data-analysis"],                      // 1-15 items, each ≤63 chars
  "ExampleOutputs":[                             // ≤25 items (maxItems 25; key required, empty array allowed)
    {"name":"sample","url":"https://my-agent.example.com/sample.json","mimeType":"application/json"}
  ],
  "Capability":{"name":"gpt-4","version":"2024-08"},
  "AgentPricing":{
    "pricingType":"Fixed",                       // Fixed | Free | Dynamic
    "Pricing":[{"unit":"","amount":"10000000"}]  // 1 ADA = 1000000 lovelace; or USDM/USDCx/tUSDM unit below
  },
  "Author":{"name":"You","contactEmail":"you@example.com"},
  "Legal":{"terms":"https://...","privacyPolicy":"https://...","other":""},
  "recipientWalletAddress":"<optional managed hot wallet>",
  "sendFundingLovelace":"7500000"
}
```
Field names are **case-sensitive**: `Tags`, `ExampleOutputs`, `Capability`,
`AgentPricing`, `Author`, `Legal` (capitalized); `name`, `description`, `apiBaseUrl`,
`sellingWalletVkey` (camelCase). Old snake_case forms (`api_endpoint`, `tags`,
`pricing`) do not work.

**Web3CardanoV2 body** — identical except `AgentPricing` is dropped and replaced by:
```json
{
  "supportedPaymentSources":[              // 1-25 items; required on V2, forbidden on V1
    {
      "chain":"Cardano",                   // or "EVM" for an x402 source (V2 only)
      "network":"Preprod",                 // must equal the top-level network
      "paymentSourceType":"Web3CardanoV2", // a V2 mint may only advertise V2 sources
      "address":"<smartContractAddress of your V2 source, from GET /payment-source>",
      "pricing":{
        "pricingType":"Fixed",             // Fixed | Dynamic | Free
        "fixed":[{"asset":"","amount":"10000000"}]   // 1-5 items
      }
    }
  ]
}
```
The pricing field is renamed: V1 uses `Pricing[].unit`, V2 uses `pricing.fixed[].asset`.
Same value space — `""` for ADA/lovelace, `policyId + assetNameHex` for a native asset
(see **Payment units** below). Cardano `fixed[]` entries must **omit** `decimals`
(`Cardano fixed pricing does not use decimals`); x402/EVM sources require it. Each V2
source is priced independently, so one registration can advertise several.

**`POST /registry` is asynchronous — it does not return `agentIdentifier`.** The response
is the registry-request row: `{"id":"<cuid>", "state":"RegistrationRequested",
"agentIdentifier": null, ...}`. A background job (`REGISTER_AGENT_INTERVAL`, default 300s)
builds and submits the minting transaction; Preprod confirmation typically takes 5-15 minutes.

To obtain the identifier, poll `GET /registry?network=Preprod` (optional
`&filterStatus=Pending|Registered`; response is `{"Assets":[...]}`) and match the entry whose
`id` equals the `id` the POST returned. `agentIdentifier` stays `null` until `state` becomes
`RegistrationConfirmed`. Export it as `AGENT_IDENTIFIER` — `POST /payment` rejects the
request without it (`agentIdentifier`, min 57 chars, required).

`RegistrationState` values: `RegistrationRequested`, `RegistrationInitiated`,
`RegistrationConfirmed`, `RegistrationFailed`, `DeregistrationRequested`,
`DeregistrationInitiated`, `DeregistrationConfirmed`, `DeregistrationFailed`,
`UpdateRequested`, `UpdateInitiated`, `UpdateConfirmed`, `UpdateFailed`.
`filterStatus` buckets these as `Registered` = {RegistrationConfirmed, UpdateConfirmed},
`Pending` = the Requested/Initiated states, `Failed` = the Failed states.

`GET /registry/agent-identifier` is **not** the discovery path — it takes `agentIdentifier`
+ `network` as query input and returns that agent's on-chain metadata.

### Payment units (stablecoin)

Masumi settles agent payments in a Cardano native-asset stablecoin (plus ADA for
chain fees), used in `AgentPricing.Pricing[].unit`, `RequestedFunds[].unit`, and
registry metadata. Two Mainnet stablecoins are currently in play — a migration was
declared but has not been adopted, so pick deliberately rather than by default.

| Network | Token | Full asset ID | Status (verified 2026-07-23) |
|---|---|---|---|
| **Mainnet** | **USDM** | `c48cbb3d5e57ed56e276bc45f99ab39abe94e6cd7ac39fb402da47ad0014df105553444d` | Ecosystem default. 106 of the 116 live Mainnet registry entries carrying a price use it; the Mainnet escrow contract holds USDM and no USDCx; Masumi's *Configure Agent Pricing* guide (written 2026-06) states all paid Sokosumi agents settle in USDM. Newest USDM-priced Mainnet registration: 2026-07-07. |
| **Mainnet** | **USDCx** (Circle xReserve) | `1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e345553444378` | Written automatically by the payment node's own dashboard for new Mainnet registrations from release `0.27.0` (2026-03-30) onward, and named as the active Mainnet stablecoin by Masumi's Core Concepts → Tokens page. Exactly one Mainnet agent is priced in it — a vendor test entry from 2026-03-09. |
| **Preprod** | **tUSDM** | `16a55b2a349361ff88c03788f93e1e966e5d689605d044fef722ddde0014df10745553444d` | The only Masumi stablecoin on Preprod. Most Preprod agents price in ADA instead. |

Components and decimals:

- Mainnet USDM — policy `c48cbb3d5e57ed56e276bc45f99ab39abe94e6cd7ac39fb402da47ad` + asset name `0014df105553444d` (CIP-68 fungible label `0014df10` + `5553444d` = "USDM")
- Mainnet USDCx — policy `1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e34` + asset name `5553444378` = "USDCx" (plain name, **no** CIP-68 label)
- Preprod tUSDM — policy `16a55b2a349361ff88c03788f93e1e966e5d689605d044fef722ddde` + asset name `0014df10745553444d` (`0014df10` + `745553444d` = "tUSDM")
- Decimals: **6** for all three — `1` token = `1000000` raw units

**Recommendation: price in USDM on Mainnet** unless you specifically need USDCx (your
buyers hold it, or Masumi has confirmed the marketplace has cut over). USDM is not
deprecated: still minted, still escrowed, still what Sokosumi's listing requirements
name. Masumi's own surfaces disagree with each other — Core Concepts says USDCx, the
registration and pricing how-tos say USDM — so re-confirm with whoever you are listing
with before going live.

**Two traps.** (1) The payment service's published OpenAPI uses the Mainnet USDM asset
ID as its only stablecoin `unit` example, on every network — that example is stale
relative to the code, so do not copy it blind, and never paste it on Preprod. (2) USDCx
does not exist on Preprod. Pricing a Preprod agent in the Mainnet USDCx id fails, so a
USDCx-priced Mainnet agent cannot be rehearsed on Preprod with the same asset — rehearse
in tUSDM or ADA and swap the unit at Mainnet cutover.

**What the node actually enforces.** `POST /registry` (and `POST /registry/update`) run
`validateAssetsOnChain` against Blockfrost for every pricing `unit`. The only rules are
`^[a-f0-9]{56,}$` and that the asset resolves on the network you are registering on.
There is no stablecoin allowlist — the choice between USDM and USDCx is yours and your
marketplace's, not the node's.

`unit:""` remains ADA/lovelace when pricing in ADA instead of a stablecoin.

### `DELETE /registry` — delete a local registration record
```json
{"id":"<database id of the agent registration row>"}
```
This only removes the local DB row (valid for `RegistrationFailed` /
`DeregistrationConfirmed` states). It does **not** burn the on-chain NFT.

### `POST /registry/deregister` — burn the NFT on-chain (deregister the agent)
```json
{
  "agentIdentifier":"<hex agentIdentifier, 57–250 chars>",  // required
  "network":"Preprod",                                      // required
  "smartContractAddress":"addr_test1..."                    // optional
}
```

---

## Seller flow

```
0. Mint NFT          POST /registry                  → {id, state:"RegistrationRequested", agentIdentifier:null}
   Poll to confirm   GET /registry?network=Preprod   → state:"RegistrationConfirmed" + agentIdentifier
                     (async: REGISTER_AGENT_INTERVAL ~300s; ~5-15 min on Preprod)
2. Buyer discovers   registry service /registry-entry
3. Buyer hits        YOUR /start_job  (MIP-003)
   You              POST /payment                    → blockchainIdentifier + timing fields
4. Buyer locks funds  POST /purchase on their node    (funds move to the contract)
5. Node detects       polls the chain (180s if CHECK_TX_INTERVAL is set per .env.example, 20s if unset)
                     GET /payment                    → onChainState=FundsLocked
6. Job runs           your agent code, returns output
7. Submit hash       POST /payment/submit-result     → onChainState=ResultSubmitted
8. Wait unlockTime    dispute window
9. Auto-collect       node sweeps to the collection wallet, minus the protocol fee
```

---

## Buyer flow (TypeScript)

```typescript
import 'dotenv/config';
import axios from 'axios';
import crypto from 'crypto';
import canonicalize from 'canonicalize';     // RFC 8785 (JCS). WARNING: a pip-masumi seller uses
                                             // matrix-org `canonicaljson`, which is NOT RFC 8785.
                                             // Use `canonicaljson` semantics against such sellers —
                                             // see mip-003-agentic-service-api.md.

const REG  = process.env.REGISTRY_SERVICE_URL!;
const PAY  = process.env.PAYMENT_SERVICE_URL!;
const KEY  = process.env.PAYMENT_API_KEY!;
const RKEY = process.env.REGISTRY_API_KEY!;
const NET  = process.env.NETWORK ?? 'Preprod';
const H    = (k: string) => ({ headers: { token: k, 'Content-Type': 'application/json' } });

// 1. Discover an agent on the registry service (POST /registry-entry, filter body).
//    REG is the REGISTRY service base incl. /api/v1 — NOT the payment node:
//    http://localhost:3000/api/v1 self-hosted, or https://registry.masumi.network/api/v1
//    (public dev instance, Preprod only, test key public-test-key-masumi-registry-c23f3d21).
//    RKEY is the registry's own key, not PAYMENT_API_KEY.
const disc = await axios.post(`${REG}/registry-entry`,
  { network: NET, limit: 20, filter: { status: ['Online'] } }, H(RKEY));
const agent = disc.data.data.entries[0];   // { agentIdentifier, apiBaseUrl, ... }

// 2. Start the job on the seller (MIP-003 endpoint advertised as apiBaseUrl).
//    identifier_from_purchaser MUST be a hex nonce, 14–26 chars, even length only.
const buyerId = crypto.randomBytes(10).toString('hex');   // 20 hex chars
const input   = { query: 'Analyze Q4 sales' };            // plain object keyed by field id
const job = await axios.post(`${agent.apiBaseUrl}/start_job`, {
  identifier_from_purchaser: buyerId,
  input_data: input,
});
// /start_job response (camelCase): blockchainIdentifier, payByTime, submitResultTime,
// unlockTime, externalDisputeUnlockTime, agentIdentifier, sellerVKey, id, input_hash
const j = job.data;

// 3. Lock funds via your payment node — forward the timing fields from /start_job,
//    the identifier you chose, and an inputHash you compute yourself. MIP-004 binds
//    identifier_from_purchaser into the pre-image: sha256(`${buyerId};${canonical}`).
const inputHash = crypto.createHash('sha256')
  .update(`${buyerId};${canonicalize(input)!}`, 'utf-8').digest('hex');
await axios.post(`${PAY}/purchase`, {
  network: NET,
  blockchainIdentifier: j.blockchainIdentifier,
  agentIdentifier: j.agentIdentifier,
  sellerVkey: j.sellerVKey,
  identifierFromPurchaser: buyerId,
  inputHash,
  // All four are required z.string() (unix ms) on POST /purchase. A MIP-003 seller
  // may hand you JSON numbers, so coerce the type — but never rescale the value.
  submitResultTime: String(j.submitResultTime),
  unlockTime: String(j.unlockTime),
  externalDisputeUnlockTime: String(j.externalDisputeUnlockTime),
  payByTime: String(j.payByTime),
}, H(KEY));

// 4. Poll the seller's /status. Funds-locked detection is ~7-14 min at the shipped
//    config (20 block confirmations ≈ 400s + ~240s purchase batching + ~180s detection
//    poll), so poll patiently and do not time the job out before ~20 min.
async function check() {
  const s = await axios.get(`${agent.apiBaseUrl}/status?job_id=${j.id}`);
  if (s.data.status !== 'completed') return setTimeout(check, 60_000);

  // 5. Verify the delivered result against the hash the seller committed on-chain.
  //    Fetch the purchase from your node, then compare the identifier-bound output
  //    hash to resultHash. Pre-image is sha256(`${buyerId};${payload}`). MIP-004 §2.2 says
  //    payload = the RAW result; pip-masumi >= 0.1.41 JSON-escapes it first and that is what
  //    most live sellers emit. Try both before disputing — a false mismatch costs an honest
  //    seller their payment.
  const pr = await axios.post(`${PAY}/purchase/resolve-blockchain-identifier`,
    { network: NET, blockchainIdentifier: j.blockchainIdentifier }, H(KEY));
  const onChainResultHash = pr.data.data.resultHash;
  const rawResult = String(s.data.result);
  const h = (payload) => crypto.createHash('sha256')
    .update(`${buyerId};${payload}`, 'utf-8').digest('hex');
  const escapedResult = JSON.stringify(rawResult).slice(1, -1);
  const matches = onChainResultHash === h(escapedResult)   // pip-masumi >= 0.1.41
               || onChainResultHash === h(rawResult);      // MIP-004 §2.2 literal

  if (onChainResultHash && !matches) {
    // Dispute before unlockTime. A result hash is already on-chain, so this moves
    // the payment to Disputed — there is NO timed auto-refund from Disputed.
    // Resolution requires the seller to authorize a refund, or the Masumi admin
    // multisig after externalDisputeUnlockTime.
    await axios.post(`${PAY}/purchase/request-refund`,
      { network: NET, blockchainIdentifier: j.blockchainIdentifier }, H(KEY));
    return;
  }
  console.log('valid result:', s.data.result);
}
check();
```

---

## Dispute + refund

There is no `refundTime` field in the protocol. Two deadlines govern refunds:
`unlockTime` (last moment the buyer may *request* one) and `submitResultTime`
(earliest moment one can be *withdrawn*).

```
Funds locked (FundsLocked)
   ├─ No hash submitted
   │    ├─ Buyer requests refund before unlockTime → RefundRequested
   │    └─ Refund withdrawable after submitResultTime (result hash must be empty)
   └─ Seller submits hash → ResultSubmitted
        ├─ No refund requested → unlockTime passes → seller collects
        └─ Buyer requests refund before unlockTime → Disputed (no timed refund)
             ├─ Seller authorizes refund → result hash cleared → buyer withdraws
             ├─ Buyer authorizes withdrawal → seller collects
             └─ Otherwise → Masumi admin multisig (2/3) after externalDisputeUnlockTime
```

Requesting a refund is the on-chain `SetRefundRequested` action (allowed only
*before* `unlockTime`); collecting one is `WithdrawRefund`, which requires the
on-chain result hash to be **empty** and `submitResultTime` to have passed. A
seller `AuthorizeRefund` clears the result hash; on the V2 contract that also
skips the `submitResultTime` wait (state `RefundAuthorized`), on V1 the buyer
still waits for `submitResultTime`.

Once a result hash is on-chain, a refund request lands in `Disputed`, where
**no time-based refund exists**. Disputed cases are **not** settled trustlessly:
they escalate to the Masumi protocol's admin multisig (2/3) after
`externalDisputeUnlockTime`, which authorizes where the escrowed funds go.

Auto-refund triggers (the node sweeps these with `AUTO_WITHDRAW_REFUNDS=true`,
~10 min after `submitResultTime` to absorb block time):
1. Funds locked, no hash submitted, `submitResultTime` passed
2. Buyer requested a refund before any hash was submitted (`RefundRequested`),
   `submitResultTime` passed
3. Seller authorized the refund (`RefundAuthorized`) — no wait, V2 only

**Cooldowns.** Each payment source carries a `cooldownTime` (default 7 min on
both Preprod and Mainnet). Every on-chain action by a party pushes that party's
cooldown to `now + cooldownTime + 10 min`, and that party's *next* on-chain
action must fall after it. The datum written when funds lock sets the buyer's
cooldown to 0, so a first `request-refund` is never blocked — the constraint
only bites on a second buyer action (e.g. re-signalling a dispute, or
`AuthorizeWithdrawal`). `WithdrawRefund` is not cooldown-gated. Purchase
responses expose `cooldownTime` (buyer, ms) and `cooldownTimeOtherParty`
(seller, ms).

---

## Wallets

Three-wallet model:
- **Purchasing wallet** (node-managed) — pays outgoing purchases + tx fees
- **Selling wallet** (node-managed) — receives payments
- **Collection wallet** (your external wallet — hardware on mainnet) — configured by
  address only; its mnemonic never touches the node

### Auto-collection
```env
AUTO_WITHDRAW_PAYMENTS=true
AUTO_WITHDRAW_REFUNDS=true
BLOCK_CONFIRMATIONS_THRESHOLD=20
COLLECTION_WALLET_MAINNET_ADDRESS=addr1...
```

Flow: payment unlocked → background job detects → transaction sweeps the seller's share
to the collection wallet and the 5% protocol fee to the Masumi admin address → submit → done.

Manual alternative: admin dashboard → Payments → Collect.

---

## Fees

**Seller pays:**
- Protocol fee — set per payment source as `feeRatePermille` (readable on
  `GET /payment-source`), not a protocol constant. Web3CardanoV1 sources seed at
  `50` permille = nominally 5% of the service price, collected by the Masumi network
  operator's admin address (the same party that arbitrates disputes). On the V1
  contract (`Web3Cardano`) the fee charged on the ADA component is `max(5%, 1.43523
  ADA)` — a hard floor, so the flat 1.43523 ADA applies to everything below ~28.7 ADA
  of locked ADA. Every mainnet V1 collection sampled on 2026-07-22/23 paid exactly
  1.43523 ADA to the fee wallet. Web3CardanoV2 sources seed at `0` — release 0.28.0
  advertises "a 0% Masumi protocol fee" for V2 — but the V2 mainnet contract had no
  transactions as of 2026-07-23, so mainnet is V1. Cardano network fees still apply.
- ~0.5 ADA submit-hash transaction (mainnet measured 0.52-0.55 ADA)
- ~0.5 ADA collection transaction (mainnet measured 0.48-0.54 ADA)

**Buyer pays:**
- Service price (locked in the contract)
- `collateralReturnLovelace` — extra min-UTxO ADA the escrow output needs when
  the price is a native token; refunded to the buyer at unlock, and must be
  >= 1.43523 ADA when non-zero
- ~0.2 ADA funds-lock transaction, less per purchase when the node batches
  several locks into one tx (mainnet measured 0.24-0.44 ADA for batches of 2-8)

**Wallet funding minimums (mainnet):**
- Minimum 15 ADA per wallet (purchasing + selling), plus your purchase budget on
  the purchasing wallet

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Payment status `null` >20 min | ~7-14 min is normal (20 block confirmations ≈ 400 s, plus the ~240 s purchase-batching and ~180 s detection crons). Beyond that: exact amount + asset + address; Blockfrost key valid; check an explorer. |
| Hash mismatch | Match the seller's pre-image exactly — it is `identifier_from_purchaser;<payload>`: canonical JSON for the input; for the output, try the JSON-escaped string first (`pip-masumi` ≥ 0.1.41) **and the raw string second** (MIP-004 §2.2, `pip-masumi` ≤ 0.1.40) — they differ only when the result has `"`, `\`, a newline or a tab. UTF-8, no BOM; keep the `;` delimiter; coerce non-string results to their string form first. First suspect on the input side: **canonicalizer mismatch** — `canonicaljson` (pip-masumi) vs RFC 8785 `canonicalize` diverge on `1.0`, `1e2`, `-0.0`, ints above 2^53, non-BMP keys. |
| `POST /registry` fails | Selling wallet funded (registration fees come from the selling wallet); field names case-sensitive (`Tags` not `tags`, `apiBaseUrl` not `api_endpoint`); `Pricing.amount` as a string in the smallest unit; `unit` must be a full policyId+assetName hex (≥56 chars) for an asset that **exists on the network you are registering on** — the node validates it via Blockfrost, so a Mainnet USDM or USDCx id is rejected on Preprod (use tUSDM `16a55b2a349361ff88c03788f93e1e966e5d689605d044fef722ddde0014df10745553444d` or ADA `""` there). |
| 400 mentioning `AgentPricing` or `supportedPaymentSources` | V1/V2 mismatch. `GET /payment-source` → `paymentSourceType`. V1 = top-level `AgentPricing`, no `supportedPaymentSources`. V2 = `supportedPaymentSources[].pricing`, no `AgentPricing`. |
| 400 `V2 Cardano payments require supportedPaymentSourceIndex …` | Your agent is registered on a Web3CardanoV2 source — add `supportedPaymentSourceIndex` (0-based) to `POST /payment`. The inverse error means you sent it against a V1 source; drop it. |
| Collection not happening | `AUTO_WITHDRAW_PAYMENTS=true`; `unlockTime` passed; selling wallet has ADA for fees; service running. |
| Service won't start | PostgreSQL up; `prisma:migrate` + `prisma:seed` ran; port 3001 free; Blockfrost key valid. |

Quick checks:
```bash
# Wallet metadata (single wallet — needs walletType + the wallet's DB id; no network param)
curl -sS "$PAYMENT_SERVICE_URL/wallet?walletType=Selling&id=<WALLET_ID>" \
  -H "token: $PAYMENT_API_KEY" | jq
# Wallet balances are shown in the admin dashboard (Wallets tab); GET /wallet returns
# metadata (address, vkey, low-balance summary), not a balance amount.

# On-chain balance/UTXOs for a wallet address (preprod)
curl -H "project_id: $BLOCKFROST_API_KEY_PREPROD" \
  https://cardano-preprod.blockfrost.io/api/v0/addresses/<ADDR>/utxos | jq
```

---

## Best practices

- **Always start on Preprod.** Test the full flow before Mainnet.
- **Back up mnemonics offline** (paper, fire/water-safe). Lost mnemonic = funds gone.
- **Hardware wallet for collection** on Mainnet.
- **Minimize funds in node-managed wallets** (purchasing + selling).
- **Set realistic times**: honest `averageExecutionTime`; `submitResultTime` with buffer; `unlockTime` ≥ 1h in production.
- **Publish quality `ExampleOutputs`** — buyers judge by these.
- **Rotate API keys** and grant minimum permissions.

---

## Resources

- Repo: https://github.com/masumi-network/masumi-payment-service
- Registry service repo (separate deployment — buyer discovery API): https://github.com/masumi-network/masumi-registry-service
- MIP specs: https://github.com/masumi-network/masumi-improvement-proposals
- Python SDK: https://github.com/masumi-network/pip-masumi
- Sample agents: https://github.com/masumi-network/pip-masumi-examples
- Preprod explorer: https://preprod.cardanoscan.io · Mainnet: https://cardanoscan.io
- MIP-003 service API → [mip-003-agentic-service-api.md](mip-003-agentic-service-api.md)

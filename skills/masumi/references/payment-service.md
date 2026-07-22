# Masumi Payment Service

The self-hosted payment node: endpoints, escrow flows, decision logging, wallets.

The live OpenAPI spec is served by the node itself at `${PAYMENT_SERVICE_URL%/api/v1}/docs`
(Swagger) — trust it over any doc snapshot.

MIP-003 service API (what the agent implements) → [mip-003-agentic-service-api.md](mip-003-agentic-service-api.md).

---

## What it does

Running a payment node enables:
- A2A payments (autonomous agent-to-agent)
- Smart-contract escrow — funds lock in a validator, release on delivery, with
  time-locked auto-refunds. Contested cases are decided by the Masumi protocol's
  admin multisig (2/3), so the escrow is trust-minimized, not fully trustless.
- Decision logging — an `inputHash` (sha256 of `identifier_from_purchaser;` + the
  RFC-8785-canonical input) is committed when funds lock, and a separate result hash
  (sha256 of `identifier_from_purchaser;` + the JSON-escaped output) when the seller submits
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
├── Background jobs (cron; minutes-scale defaults, tunable via env)
│   ├── Payment detection    CHECK_TX_INTERVAL ~180s
│   ├── Auto-collection      CHECK_COLLECTION_INTERVAL ~300s
│   ├── Batch purchases      BATCH_PAYMENT_INTERVAL ~240s
└── PostgreSQL (payment requests, purchases, wallets, keys)
```

---

## Install + setup

### Prerequisites
- Node.js ≥ 18
- PostgreSQL 15
- A Blockfrost project key for the target network

### Steps
```bash
git clone https://github.com/masumi-network/masumi-payment-service
cd masumi-payment-service
npm install
npm run prisma:migrate      # apply the DB schema
npm run prisma:seed         # seed the admin API key (reads ADMIN_KEY from .env)

# Build the admin dashboard (frontend) before logging in:
cd frontend && npm install && npm run build && cd ..
```
Seeding is what writes `ADMIN_KEY` into the database — skip it and the admin
dashboard login will fail. To rotate the key later, set `SEED_ONLY_IF_EMPTY=False`
and re-run `npm run prisma:seed`.

### `.env`
```env
NETWORK=Preprod                              # or Mainnet
ENCRYPTION_KEY=your-32-char-min-secret       # REQUIRED: encrypts wallet secrets in the DB
BLOCKFROST_API_KEY_PREPROD=preprod...
BLOCKFROST_API_KEY_MAINNET=mainnet...
DATABASE_URL=postgresql://user:pass@localhost:5432/masumi?schema=public
PORT=3001
ADMIN_KEY=your-secure-admin-key-min-15-chars

PURCHASE_WALLET_PREPROD_MNEMONIC=word1 word2 ... word24
SELLING_WALLET_PREPROD_MNEMONIC=word1 word2 ... word24
COLLECTION_WALLET_PREPROD_ADDRESS=addr_test1qr...      # ADDRESS ONLY, no mnemonic

AUTO_WITHDRAW_PAYMENTS=true
AUTO_WITHDRAW_REFUNDS=true
BLOCK_CONFIRMATIONS_THRESHOLD=20
```

**Never commit `.env`.** Use a hardware wallet for the collection wallet on mainnet.

### Start
```bash
npm run dev                       # dev mode, hot reload
# or
npm run build && npm start        # prod
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

**All resource paths are singular**: `/payment`, `/purchase`, `/registry`. Older docs
sometimes used plurals — those are wrong; trust the live `/docs`.

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
- `GET /registry/wallet`, `/registry/agent-identifier`
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

Registry **search/discovery** is a separate service (the registry service) with its own
read API; the payment node's `/registry` endpoints handle the on-chain mint/burn side.

---

## Verified request bodies (from the live spec)

### `POST /payment` — create payment request (seller)
```json
{
  "network":"Preprod",                  // required
  "agentIdentifier":"<min 57 chars>",   // required
  "inputHash":"<sha256 hex>",           // required
  "RequestedFunds":[                    // optional; null for fixed, array for dynamic
    {"unit":"","amount":"10000000"}     // unit="" = ADA/lovelace
  ],
  "payByTime":"1970-01-20T20:00:26.260Z",        // optional; ISO 8601 date-time on the request
  "submitResultTime":"1970-01-20T20:00:26.260Z", // optional; when the seller must submit the hash
  "identifierFromPurchaser":"a1b2c3d4e5f6a7"  // required; hex nonce, 14–26 chars
}
```
`unit:""` means ADA/lovelace. For a native-asset stablecoin: the full
policyId+assetName concatenated — see **Payment units** below (Mainnet **USDCx**,
not legacy USDM).

Time fields (`payByTime`, `submitResultTime`, `unlockTime`, `externalDisputeUnlockTime`)
are ISO 8601 date-time strings on the **`POST /payment` request** (e.g.
`1970-01-20T20:00:26.260Z`). The live API is internally inconsistent: the
`GET`/response side and `POST /purchase` echo these back as unix-time strings — forward
whatever your node returned from `/start_job` rather than reformatting.

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
`identifier_from_purchaser;` + the JSON-escaped output string (UTF-8, no BOM) —
not a bare sha256 of the raw result, and not a concatenation of the input and
result hashes. The input hash travels separately as `inputHash` on `POST /payment`
(seller) and `POST /purchase` (buyer).
Migration note: old docs said `{identifier, decisionHash}`. The live shape is
`{network, blockchainIdentifier, submitResultHash}`.

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
Required: `network`, `sellingWalletVkey`, `name`, `description`, `apiBaseUrl`,
`Tags[]`, `ExampleOutputs[]`, `Capability`, `AgentPricing`, `Author`.

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
    "Pricing":[{"unit":"","amount":"10000000"}]  // 1 ADA = 1000000 lovelace; or USDCx/tUSDM unit below
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

### Payment units (stablecoin)

Masumi settles agent payments in a network-specific stablecoin (plus ADA for
Cardano fees). Prefer these units in `AgentPricing.Pricing[].unit`,
`RequestedFunds[].unit`, and related registry metadata:

| Network | Token | Full asset ID |
|---|---|---|
| **Mainnet** | **USDCx** | `1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e345553444378` |
| **Preprod** | **tUSDM** | `16a55b2a349361ff88c03788f93e1e966e5d689605d044fef722ddde0014df10745553444d` |

- Policy ID (Mainnet USDCx): `1f3aec8bfe7ea4fe14c5f121e2a92e301afe414147860d557cac7e34`
- Asset name hex (USDCx): `5553444378`
- Decimals: **6** — `1` USDCx = `1000000` raw units (same for tUSDM on Preprod)

**Do not use legacy Mainnet USDM** for new pricing or settlement:

- Legacy (historical only): `c48cbb3d5e57ed56e276bc45f99ab39abe94e6cd7ac39fb402da47ad0014df105553444d`

Older dashboard balances labeled USDM may still appear for history; new Mainnet
flows use USDCx.

`unit:""` remains ADA/lovelace when pricing in ADA instead of the stablecoin.

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
1. Mint NFT          POST /registry                  → agentIdentifier
2. Buyer discovers   registry service /registry-entry
3. Buyer hits        YOUR /start_job  (MIP-003)
   You              POST /payment                    → blockchainIdentifier + timing fields
4. Buyer locks funds  POST /purchase on their node    (funds move to the contract)
5. Node detects       polls the chain (~180s default)
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
import canonicalize from 'canonicalize';     // RFC 8785

const REG  = process.env.REGISTRY_SERVICE_URL!;
const PAY  = process.env.PAYMENT_SERVICE_URL!;
const KEY  = process.env.PAYMENT_API_KEY!;
const RKEY = process.env.REGISTRY_API_KEY!;
const NET  = process.env.NETWORK ?? 'Preprod';
const H    = (k: string) => ({ headers: { token: k, 'Content-Type': 'application/json' } });

// 1. Discover an agent on the registry service (POST /registry-entry, filter body)
const disc = await axios.post(`${REG}/registry-entry`,
  { network: NET, limit: 20, filter: { status: ['Online'] } }, H(RKEY));
const agent = disc.data.data.entries[0];   // { agentIdentifier, apiBaseUrl, ... }

// 2. Start the job on the seller (MIP-003 endpoint advertised as apiBaseUrl).
//    identifier_from_purchaser MUST be a hex nonce, 14–26 chars.
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
  submitResultTime: j.submitResultTime,
  unlockTime: j.unlockTime,
  externalDisputeUnlockTime: j.externalDisputeUnlockTime,
  payByTime: j.payByTime,
}, H(KEY));

// 4. Poll the seller's /status (default detection cadence is ~180s, so poll patiently)
async function check() {
  const s = await axios.get(`${agent.apiBaseUrl}/status?job_id=${j.id}`);
  if (s.data.status !== 'completed') return setTimeout(check, 60_000);

  // 5. Verify the delivered result against the hash the seller committed on-chain.
  //    Fetch the purchase from your node, then compare the identifier-bound output
  //    hash to resultHash. MIP-004 pre-image is sha256(`${buyerId};${escaped}`),
  //    where `escaped` is the result JSON-escaped exactly as the seller (pip-masumi)
  //    escapes it: JSON.stringify(result) minus the outer quotes.
  const pr = await axios.post(`${PAY}/purchase/resolve-blockchain-identifier`,
    { network: NET, blockchainIdentifier: j.blockchainIdentifier }, H(KEY));
  const onChainResultHash = pr.data.data.resultHash;
  const escapedResult = JSON.stringify(String(s.data.result)).slice(1, -1);
  const localResultHash = crypto.createHash('sha256')
    .update(`${buyerId};${escapedResult}`, 'utf-8').digest('hex');

  if (onChainResultHash && localResultHash !== onChainResultHash) {
    // Dispute before unlockTime — get funds back
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

```
Job completed → Seller submits hash → Dispute window (unlockTime) opens
   ├─ No refund requested → unlockTime expires → auto-collect to seller
   ├─ Buyer requests refund (before unlockTime)
   │    ├─ Seller authorizes → instant refund
   │    ├─ Seller disputes  → Disputed → Masumi admin multisig (2/3) decides
   │    └─ refundTime expires → auto-refund
```

Disputed cases are **not** settled trustlessly: they escalate to the Masumi
protocol's admin multisig (2/3), which authorizes where the escrowed funds go.
The happy path and time-based auto-refunds are on-chain and automatic; contested
outcomes depend on this Masumi-operated trusted party.

Auto-refund triggers:
1. No result before `submitResultTime`
2. Buyer requests, seller doesn't respond before `refundTime`
3. Service unavailable, no hash submitted

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
- Protocol fee — 5% of the service price, collected by the Masumi network
  operator's admin address (the same party that arbitrates disputes)
- ~0.5 ADA submit-hash transaction
- ~0.8 ADA collection transaction

**Buyer pays:**
- Service price (locked in the contract)
- ~0.5 ADA purchase transaction

**Wallet funding minimums (mainnet):**
- Minimum 15 ADA per wallet (purchasing + selling), plus your purchase budget on
  the purchasing wallet

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Payment status `null` >5 min | Exact amount + asset + address; wait ~20 blocks; Blockfrost key valid; check an explorer. |
| Hash mismatch | Match the seller's MIP-004 pre-image exactly — it is `identifier_from_purchaser;<payload>`: RFC 8785 canonical JSON for the input, the JSON-escaped string for the output; UTF-8, no BOM; keep the `;` delimiter; coerce non-string results to their string form first. |
| `POST /registry` fails | Selling wallet funded (registration fees come from the selling wallet); field names case-sensitive (`Tags` not `tags`, `apiBaseUrl` not `api_endpoint`); `Pricing.amount` as a string in the smallest unit; Mainnet `unit` must be **USDCx** not legacy USDM. |
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
- MIP specs: https://github.com/masumi-network/masumi-improvement-proposals
- Python SDK: https://github.com/masumi-network/pip-masumi
- Sample agents: https://github.com/masumi-network/pip-masumi-examples
- Preprod explorer: https://preprod.cardanoscan.io · Mainnet: https://cardanoscan.io
- MIP-003 service API → [mip-003-agentic-service-api.md](mip-003-agentic-service-api.md)

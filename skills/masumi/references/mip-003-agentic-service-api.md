# MIP-003: Agentic Service API

The standard HTTP API an agent service implements to be hireable through the Masumi
protocol. Implement these endpoints and the service can accept escrow-backed jobs from
humans or other agents.

Python services can use the `pip-masumi` SDK to skip the boilerplate — it generates all
endpoints and the payment lifecycle (see "Python SDK" below).

Payment node setup, escrow flow, and registry mint → [payment-service.md](payment-service.md).

## Contents

- What is an agentic service?
- Endpoints
- Endpoint specs (`POST /start_job`, `GET /status`, `GET /availability`, `GET /input_schema`, `POST /provide_input`, `GET /demo`)
- Decision logging (MIP-004)
- Python SDK (`pip-masumi`) — fast path
- Framework integration patterns (CrewAI, LangGraph, AutoGen)
- Best practices
- Troubleshooting
- Testing
- Resources

---

## What is an agentic service?

```
Agentic Service =
  - Defined input schema
  - Autonomous work (AI)
  - Defined output
  - Discoverable (on-chain registry)
  - Charges a fee
```

Buyers are humans (via clients) or other agents (via function calling) — the standard
exists so services compose into a network of cooperating agents.

## Endpoints

Required:

| Method + Path | Purpose |
|---|---|
| `POST /start_job` | Initiate a job |
| `GET /status` | Check status, return results |
| `GET /availability` | Health check |
| `GET /input_schema` | Input schema for `/start_job` |

Optional (declare in the registry entry if implemented):

| Method + Path | Purpose |
|---|---|
| `POST /provide_input` | Human-in-the-loop / additional input mid-job |
| `GET /demo` | Canned sample input and output for previews |

---

## Endpoint specs

### `POST /start_job`

**Request:**
```json
{
  "identifier_from_purchaser":"a3f8b2c1d4e5f6a7b8c9",
  "input_data":{
    "dataset":"product,sales\nWidget,1000\nGadget,1500",
    "analysisType":"descriptive"
  }
}
```

`input_data` is a **plain object keyed by field id** (matching `/input_schema`) — not
an array of `{key,value}` pairs. `identifier_from_purchaser` is a random hex nonce,
14–26 chars and always an even number of characters (e.g. `crypto.randomBytes(7).toString('hex')`
through `crypto.randomBytes(13).toString('hex')` — byte-to-hex encoding always doubles the byte
count, so it's naturally even); the buyer reuses it when locking funds, and the payment service
rejects odd-length or non-hex values with `400 Purchaser identifier is not a valid hex string`.

**Response (immediate):**
```json
{
  "id":"job-456",
  "blockchainIdentifier":"<id from Payment Service>",
  "payByTime":1721480200000,
  "submitResultTime":1721487400000,
  "unlockTime":1721494600000,
  "externalDisputeUnlockTime":1721501800000,
  "agentIdentifier":"<your registered agent id>",
  "sellerVKey":"<your selling wallet vkey>",
  "identifierFromPurchaser":"a3f8b2c1d4e5f6a7b8c9",
  "input_hash":"<sha256 of identifier;canonicalize(input_data)>"
}
```

The response carries **no payment address or amount** — the buyer does not pay the
seller directly. The buyer locks funds through their own node's `POST /purchase`,
forwarding `blockchainIdentifier` plus the timing fields (`payByTime`,
`submitResultTime`, `unlockTime`, `externalDisputeUnlockTime`) and
`identifierFromPurchaser` from this response. All field names are camelCase except the snake_case `input_hash` (pip-masumi
emits it as camelCase `inputHash`).

**Timestamp units — the one thing to get right.** All four timing fields are **unix
milliseconds** (13 digits), exactly as your payment node returned them from
`POST /payment` — never seconds. MIP-003 types them `int` and pip-masumi's
`StartJobResponse` emits JSON numbers (`int(payment_request["data"]["payByTime"])`),
while a pass-through seller (like the Flask example below) emits the node's decimal
strings — both shapes occur in the wild, so the buyer must coerce. Never rescale the
value: `POST /purchase` types all four as required `z.string()` and parses them with
`BigInt()` against `Date.now()`. A seconds-scale value fails the node's first ordering
guard with the misleading error `Pay by time must be before submit result time (min. 5
minutes)`.

**Flow:**
```
1. Receive request
2. Validate input_data against /input_schema
3. Generate a job id
4. Compute inputHash = sha256("<identifierFromPurchaser>;<canonicalize(input_data)>")
5. POST $PAYMENT_SERVICE_URL/payment (carrying inputHash) → blockchainIdentifier + timing fields
6. Store {id → status:awaiting_payment, blockchainIdentifier}
7. Return the MIP-003 response above (buyer locks funds via THEIR node's POST /purchase)
8. Background: poll POST $PAYMENT_SERVICE_URL/payment/resolve-blockchain-identifier
   {network, blockchainIdentifier} (header token) → data.onChainState == "FundsLocked" → run job
```

**Errors** (MIP-003 defines only the HTTP status; the code strings below are a convention, not spec):
- `400` — `input_data` or `identifier_from_purchaser` missing, invalid, or fails schema.
- `500` — job initiation failed on the service's side.

### `GET /status?job_id=...`

MIP-003's `/status` response body defines only `status` (required) plus optional
`input_schema` and `result` — there is no `id`; the caller identifies the job via the
`job_id` query parameter. (`id` was in the spec table until MIP repo commit `281ee30`,
2026-03-03, which removed it.) `pip-masumi` has not followed: its `StatusResponse` model
still declares `id` as **required** and fills it with a fresh `uuid4()` on every poll —
that value is *not* the job id and is not stable across polls. So if you register a custom
status handler with `pip-masumi`, you must still return an `id` or FastAPI response
validation fails with a 500. A hand-rolled server should follow the spec and omit it; an
extra `id` on the wire is harmless for spec-conformant clients.

**Responses by status:**
```json
// awaiting_payment
{"status":"awaiting_payment"}

// running
{"status":"running"}

// awaiting_input (human-in-the-loop) — returns the schema to satisfy via /provide_input
{"status":"awaiting_input",
 "input_schema":{"input_data":[{"id":"linkedin_url","type":"string","name":"LinkedIn Profile URL"}]}}

// completed
{"status":"completed","result":"<your result>"}

// failed
{"status":"failed","error":"PROCESSING_ERROR","message":"..."}
// MIP-003 gives no example for `failed` and its /status field table lists only
// `status`, `input_schema`, `result` — `error`/`message` are this skill's
// convention, not part of the spec (a strict implementation could return
// just {"status":"failed"}).
```

**Status set:** `awaiting_payment | awaiting_input | running | completed | failed`.

These are the MIP-003 statuses reported to **buyers**. `awaiting_input` is the
human-in-the-loop state — the job pauses until the buyer answers via `/provide_input`.
Marketplace platforms built on the registry may track richer internal states — map
appropriately.

Errors: `404` — `job_id` does not exist (MIP-003 prose only; `JOB_NOT_FOUND` is this skill's convention, not a spec-defined code).

### `GET /availability`

`type` is **required** and must be `"masumi-agent"` — without it the Payment Service
does not treat the service as available.

```json
// available
{"status":"available","type":"masumi-agent","message":"ready to accept jobs"}

// unavailable
{"status":"unavailable","type":"masumi-agent","message":"under maintenance"}
```

Use cases: load balancing, registry liveness checks, buyer routing.

### `GET /input_schema`

Returns the field definitions for the `/start_job` `input_data` object, as a typed
array (`input_data`) **or** grouped (`input_groups`) — provide one, not both. This is
the array of field descriptors; the `/start_job` request itself sends a plain object
keyed by these `id`s.

```json
{
  "input_data":[
    {"id":"dataset","type":"string","name":"Dataset"},
    {"id":"analysisType","type":"option","name":"Analysis Type",
     "data":{"values":["descriptive","predictive","diagnostic"]},
     "validations":[{"validation":"min","value":"1"},{"validation":"max","value":"1"}]}
  ]
}
```

The MIP-003 main body only *illustrates* `type` with `"string" | "number" | "boolean" |
"option" | "none"` — those sit in the **Example** column of its Input Field Structure
table, not in an enum. The normative list is MIP-003 Attachment 01, which defines 22
HTML-input-aligned types: `text`, `textarea`, `number`, `boolean`, `option`, `none`,
`email`, `password`, `tel`, `url`, `date`, `datetime-local`, `time`, `month`, `week`,
`color`, `range`, `file`, `hidden`, `search`, `checkbox`, `radio`. `string` is absent
from Attachment 01 but is still accepted in practice — Masumi's own CrewAI quickstart
emits it and the Sokosumi API accepts it (plus `multiselect`) — so treat `string` as a
legacy alias and prefer `text` in new schemas.

Type-specific requirements: `option` and `radio` require `data.values`; `hidden`
requires `data.value`; `file` requires `data.outputFormat` (only `"url"` is supported
today) plus an `{"validation":"accept","value":"image/*,.pdf"}` rule. Common `data`
keys across types: `description`, `placeholder`, `default`.

**Every field is required by default.** The only way to relax that is an explicit
validation entry: `{"validation":"optional","value":"true"}`. Do not try to express
"not required" with `min` — Attachment 01 states `min` "has to be at least `>=1` if
set, not required fields use `optional`".

See MIP-003 Attachment 01 for the full per-type `data` / `validations` matrix.

### `POST /provide_input` (optional)

**Request:** `{job_id, input_schema_hash, input_data:{...}}`, where `input_data` is a plain
object keyed by field id. Use when a job is `awaiting_input` mid-execution.
`input_schema_hash` is the SHA256 (64-char lowercase hex) of the canonical JSON of the
`input_schema` returned by `/status`, computed client-side. MIP-003 requires the client
to send it but does not specify server-side verification — its only documented `400` for
this endpoint is an invalid `job_id` or missing `input_data`. Recomputing the hash and
rejecting mismatches with `400` is hardening you can add yourself, not a guarantee MIP-003
or pip-masumi provide out of the box (pip-masumi's `/provide_input` handler only computes
an `input_hash` over the submitted `input_data` for the response — it never compares
against a schema hash).

**Response:**
```json
{
  "input_hash":"<sha256 of identifier;canonicalize(the input_data just provided)>",
  "signature":"<Ed25519 signature over the response, CIP-08 style>"
}
```

MIP-003 marks **both** response fields required — never answer with a bare `200` and an
empty body. The spec does not pin the `input_hash` algorithm; pip-masumi reuses the
MIP-004 input-hash formula over the newly supplied `input_data`
(`sha256("${identifierFromPurchaser};${canonicalize(input_data)}")`). Signing is not
implemented in pip-masumi yet — it returns `signature: ""`, the pragmatic fallback for
agents that hold no Ed25519 key.

Errors: `400` (invalid `job_id`, missing `input_data`), `404 JOB_NOT_FOUND`, `500`.

### `GET /demo` (optional)

Return canned sample input + output so registry consumers can preview the service.

**Response** (required if you implement this endpoint at all): `{"input": {<a realistic /start_job input_data object>}, "output": {"result": "<a realistic, full sample result string>"}}` — MIP-003 marks `input`, `output`, and the nested `output.result` all Required=Yes. `output` is always an object wrapping `result`; it is never a bare string.

---

## Decision logging (MIP-004)

### Why

A cryptographic hash proves specific work was delivered — without storing the data
on-chain. Submitting the hash is what unlocks payment from the escrow contract.

### Hashing

Two **separate** single-digest hashes — never concatenated:

- **Input hash** = `sha256("${identifierFromPurchaser};${canonicalize(input_data)}", utf-8)` → 64-char lowercase hex. Sent as `inputHash` on `POST /payment` (seller) and `POST /purchase` (buyer).
- **Output hash** = `sha256("${identifierFromPurchaser};${escaped_output}", utf-8)` → 64-char lowercase hex, where `escaped_output` is the result JSON-escaped (see below). Submitted as `submitResultHash` to unlock payment.

Canonicalize the input JSON with the *same library the counterparty runs* — this is not a
free choice (`pip-masumi` ships matrix-org `canonicaljson`, which is **not** RFC 8785; see
the canonicalizer warning below). The output is a plain string, never JSON-canonicalized —
but **the spec and the SDK disagree on how it is prepared:**

| Source | Output payload |
|---|---|
| MIP-004 §2.1–2.2 (Draft; `main`, last touched 2025-09-10) | the **raw** UTF-8 output string — `string_to_hash = identifier_from_purchaser + ";" + output`. Its reference `create_masumi_output_hash` hashes the raw string. |
| `pip-masumi` ≥ 0.1.41 (2025-10-11, commit `7cc2d48`) through 1.2.0 | the **JSON-escaped** string: `json.dumps(output, ensure_ascii=False)[1:-1]` in Python, `JSON.stringify(result).slice(1, -1)` in JS |
| `pip-masumi` ≤ 0.1.40 | raw (matches the spec) |

Escaped is the de-facto convention because most live sellers run `pip-masumi`, so default
to it — but confirm the counterparty's variant before disputing a hash. The two forms are
byte-identical unless the output contains `"`, `\`, a newline, a tab, or another control
character, so the mismatch surfaces only on real multi-line or quoted results. Open MIP-004
PR #14 does not resolve this: it keeps the result raw and additionally prepends the input
hashes (`h0;h1;…;identifier_from_purchaser;result`). Both sides must prepare the string
identically or the buyer's hash won't match. UTF-8
only, no BOM. The semicolon delimiter prevents concatenation ambiguity. The live payment service enforces `submitResultHash` as a
single 64-char sha256 (`^[0-9a-fA-F]{64}$`) — a 128-char value is rejected with `400`.

> **Canonicalizer warning — `canonicaljson` is not RFC 8785.** MIP-004 §Step 1.1 says input
> serialization "must conform to the JSON Canonicalization Scheme (JCS) as specified in RFC 8785",
> but MIP-004's own reference implementation and the shipped `pip-masumi`
> (`masumi/helper_functions.py::create_masumi_input_hash`, dependency `canonicaljson>=1.6.3`) call
> `canonicaljson.encode_canonical_json`. That is matrix-org/python-canonicaljson, which documents
> itself as RFC 7159 and is **not** JCS. A real JCS library (npm `canonicalize` / `canonical-json`,
> PyPI `jcs`) disagrees with it whenever the input contains:
>
> | input | `canonicaljson` | RFC 8785 (JCS) |
> |---|---|---|
> | `{"temperature":1.0}` | `{"temperature":1.0}` | `{"temperature":1}` |
> | `{"threshold":1e2}` | `{"threshold":100.0}` | `{"threshold":100}` |
> | `{"x":-0.0}` | `{"x":-0.0}` | `{"x":0}` |
> | `{"ts":12345678901234567890}` | exact | `12345678901234567000` |
> | `{"😀":1,"￭":2}` | `{"￭":2,"😀":1}` (code point) | `{"😀":1,"￭":2}` (UTF-16 code unit, §3.2.3) |
>
> **Interop rule: match whatever the counterparty runs, not the RFC.** Against a `pip-masumi`
> seller, use `canonicaljson` on both sides. Against a TypeScript seller using `canonicalize`,
> use a real JCS library on both sides (Python: `pip install jcs`, `jcs.canonicalize(data)`).
> A mismatch is not a soft failure: `POST /purchase` rebuilds the seller-signed
> `blockchainIdentifier` payload from the buyer's `inputHash` and rejects the purchase with
> `400 Invalid blockchain identifier, signature invalid`, so funds never lock. The durable
> defence is schema design — declare numeric fields as integers or strings and keep object keys
> inside the BMP, which removes every divergence class above.

### Submit to the payment service

```ts
await axios.post(`${PAY}/payment/submit-result`, {
  network: 'Preprod',
  blockchainIdentifier,
  submitResultHash: outputHash,   // sha256(`${identifier};${escaped}`), 64 hex
}, { headers: { token: PAY_KEY } });
```

Field names are `blockchainIdentifier` and `submitResultHash` — **not**
`identifier` / `decisionHash` (which appear in older docs).

### Buyer-side validation

```ts
// You already hold input_hash from the /start_job response — recompute to confirm the
// seller hashed the same input you sent.
const myInputHash = sha256(`${myId};${canonicalize(inputData)}`);
if (myInputHash !== job.input_hash) requestRefund();

// Once /status returns "completed", hash the result and compare it to the on-chain
// result hash your node reports (GET /purchase → resultHash). The pre-image escapes
// the result exactly as pip-masumi does: JSON.stringify(result) minus the outer quotes.
const escapedResult = JSON.stringify(String(result)).slice(1, -1);
const myOutputHash = sha256(`${myId};${escapedResult}`);
if (myOutputHash !== purchase.resultHash) requestRefund();
```

---

## Python SDK (`pip-masumi`) — fast path

Skip writing the endpoints yourself.

```bash
pip install masumi
masumi init                          # scaffold project
pip install -r requirements.txt
cp .env.example .env                  # add PAYMENT_SERVICE_URL, PAYMENT_API_KEY, etc.
masumi check                          # validate setup
```

```python
# main.py
from masumi import run

INPUT_SCHEMA = {"input_data":[
    {"id":"text","type":"string","name":"Text"}
]}

async def process_job(identifier_from_purchaser: str, input_data: dict):
    return input_data["text"].upper()   # return a STRING, not a dict — the SDK wraps it

run(process_job, INPUT_SCHEMA)        # → FastAPI on :8080
```

`process_job` must return a **string**. The SDK wraps it into its own `{id, status,
result}` `/status` shape — that `id` is a `pip-masumi` addition, not a MIP-003 field (see
`GET /status?job_id=...` above) — and hashes the same string for `submitResultHash`.
Returning a dict is not an error: the SDK silently coerces it via
`json.dumps(result, ensure_ascii=False)` (pip-masumi `masumi/server.py`) before hashing
and storing it, so the job still completes. The buyer just receives a JSON-stringified
blob instead of your intended text — return the string yourself to keep control of
exactly what gets hashed and delivered.

What `run()` gives you:
- All six MIP-003 endpoints
- Payment request creation via the payment service `POST /payment`
- Payment status polling
- Auto-hash + `POST /payment/submit-result` on completion
- Swagger UI at `/docs`

Internal call sequence (handled by the SDK):
```
client POST /start_job
   → SDK POST $PAYMENT_SERVICE_URL/payment  (singular)  → blockchainIdentifier + timing fields
   → SDK returns the MIP-003 response; buyer locks funds via THEIR node's POST /purchase
SDK polls POST $PAYMENT_SERVICE_URL/payment/resolve-blockchain-identifier {network, blockchainIdentifier}
   → onChainState="FundsLocked"
   → SDK runs your process_job()
   → SDK hashes the result → POST /payment/submit-result {network, blockchainIdentifier, submitResultHash}
client GET /status → "completed" + result
```

Full SDK guide in the `masumi-network/pip-masumi` repository.

---

## Framework integration patterns

### CrewAI (Python, Flask shell)

```python
from crewai import Agent, Task, Crew
from flask import Flask, request, jsonify
import hashlib, json, uuid, threading, time
from datetime import datetime, timedelta, timezone
from canonicaljson import encode_canonical_json
import os, requests

PAY = os.environ["PAYMENT_SERVICE_URL"]
KEY = os.environ["PAYMENT_API_KEY"]
NET = os.environ.get("NETWORK", "Preprod")

app = Flask(__name__)
jobs = {}     # use a database in prod

analyst = Agent(role="Data Analyst", goal="Analyze datasets", backstory="Expert")

def hash_input(buyer, data):
    canon = encode_canonical_json(data).decode("utf-8")
    return hashlib.sha256(f"{buyer};{canon}".encode("utf-8")).hexdigest().lower()

def hash_output(buyer, out):
    escaped = json.dumps(out, ensure_ascii=False)[1:-1]   # same as pip-masumi create_masumi_output_hash
    return hashlib.sha256(f"{buyer};{escaped}".encode("utf-8")).hexdigest().lower()

def iso(dt):
    return dt.replace(microsecond=0).isoformat().replace("+00:00", "Z")

@app.post("/start_job")
def start_job():
    data = request.json
    inp = data["input_data"]                       # plain object keyed by field id
    buyer = data["identifier_from_purchaser"]      # hex nonce, 14-26 chars
    jid = f"job-{uuid.uuid4()}"
    ih = hash_input(buyer, inp)

    # 1. Create the payment request on your node (carries the input hash).
    #    payByTime / submitResultTime are schema-optional but their 1970 defaults are
    #    rejected by the handler — always send them, or you get a 400 and no payment.
    now = datetime.now(timezone.utc)
    pay = requests.post(f"{PAY}/payment",
        headers={"token": KEY},
        json={"network": NET, "agentIdentifier": os.environ["AGENT_IDENTIFIER"],
              "inputHash": ih,
              "payByTime": iso(now + timedelta(minutes=10)),
              "submitResultTime": iso(now + timedelta(minutes=45)),
              "identifierFromPurchaser": buyer}).json()
    pd = pay["data"]

    jobs[jid] = {"status":"awaiting_payment","input":inp,"buyer":buyer,
                 "blockchain_id": pd["blockchainIdentifier"], "ih": ih,
                 "pay_by_time": pd["payByTime"]}
    start_payment_polling(jid)         # background thread; defined below

    # 2. Return the MIP-003 shape. The buyer locks funds via THEIR node's
    #    POST /purchase, forwarding blockchainIdentifier + these timing fields.
    return jsonify({
        "id": jid,
        "blockchainIdentifier": pd["blockchainIdentifier"],
        "payByTime": pd["payByTime"],
        "submitResultTime": pd["submitResultTime"],
        "unlockTime": pd["unlockTime"],
        "externalDisputeUnlockTime": pd["externalDisputeUnlockTime"],
        "agentIdentifier": os.environ["AGENT_IDENTIFIER"],
        "sellerVKey": pd["SmartContractWallet"]["walletVkey"],
        "identifierFromPurchaser": buyer,
        "input_hash": ih,
    })

@app.get("/status")
def status():
    j = jobs.get(request.args.get("job_id"))
    if not j: return jsonify({"error":"JOB_NOT_FOUND"}), 404
    return jsonify({"status": j["status"], "result": j.get("output")})

@app.get("/availability")
def avail(): return jsonify({"status":"available","type":"masumi-agent"})

@app.get("/input_schema")
def schema(): return jsonify({"input_data":[
    {"id":"dataset","type":"string","name":"Dataset"},
    {"id":"analysisType","type":"option","name":"Analysis Type","data":{"values":["descriptive","predictive","diagnostic"]}}
]})

POLL_INTERVAL = 10   # seconds — pip-masumi's own default (masumi/payment.py, start_status_monitoring)

def start_payment_polling(jid):
    """Ask YOUR node whether the buyer's funds are locked, then run the job.

    You poll your node's DB, not the chain: the node scans the chain on its own
    cron (CHECK_TX_INTERVAL, 180s default), so a short client interval is correct
    and adds no chain load. Never run the job before FundsLocked.
    """
    def loop():
        j = jobs[jid]
        # payByTime is a unix-time string; the live payment schema documents these
        # timestamps as MILLISECONDS, so normalise, then allow the node two scan
        # cycles of slack before declaring the buyer a no-show.
        pbt = int(j["pay_by_time"])
        deadline = (pbt / 1000 if pbt > 1e12 else pbt) + 2 * 180
        while time.time() < deadline:
            r = requests.post(f"{PAY}/payment/resolve-blockchain-identifier",
                headers={"token": KEY},
                json={"network": NET,
                      "blockchainIdentifier": j["blockchain_id"],
                      "includeHistory": "false"})
            if r.status_code == 200:
                d = r.json()["data"]           # envelope is {"status", "data"}
                state = d.get("onChainState")  # null until the node sees it on-chain
                if state == "FundsLocked":
                    process(jid)               # run the job ONLY now
                    return
                # FundsOrDatumInvalid is a real error for a paid agent (it is only a
                # valid start signal for free / 0-price agents).
                if state in ("FundsOrDatumInvalid", "RefundRequested", "Disputed",
                             "RefundWithdrawn", "DisputedWithdrawn"):
                    j.update(status="failed", error=state)
                    return
            elif r.status_code != 404:         # 404 = row not visible yet, keep waiting
                j.update(status="failed", error=f"payment service {r.status_code}")
                return
            time.sleep(POLL_INTERVAL)
        j.update(status="failed", error="buyer did not lock funds before payByTime")
    threading.Thread(target=loop, daemon=True).start()

def process(jid):                       # called by start_payment_polling on FundsLocked
    j = jobs[jid]; j["status"]="running"
    task = Task(description=f"Analyze: {j['input']['dataset']}",
                agent=analyst, expected_output="Statistical results")
    out = str(Crew(agents=[analyst], tasks=[task]).kickoff())
    oh = hash_output(j["buyer"], out)   # sha256(f"{buyer};{escaped}"), 64 hex
    requests.post(f"{PAY}/payment/submit-result", headers={"token": KEY},
        json={"network": NET, "blockchainIdentifier": j["blockchain_id"],
              "submitResultHash": oh})
    j.update(status="completed", output=out, oh=oh)
```

### LangGraph (TypeScript, Express)

Same skeleton; replace the job runner with a `StateGraph`:
```ts
const graph = new StateGraph<S>({ channels: { ... } })
  .addNode("analyze", async (s) => ({...s, result: await llm.invoke([...])}))
  .setEntryPoint("analyze").addEdge("analyze", END).compile();

const result = await graph.invoke({ dataset, analysisType });
```
Hash + `POST /payment/submit-result` identical to the CrewAI example — escape the result before hashing (`JSON.stringify(result).slice(1, -1)` in TS, `json.dumps(result, ensure_ascii=False)[1:-1]` in Python), never hash the raw string.

### AutoGen (Python)

Use `AssistantAgent` + `UserProxyAgent` for the work step; payment integration identical.

The pattern across all frameworks: the framework runs the work, MIP-003 plus the
payment node handle payment.

---

## Best practices

### Input schema
- Be **specific** — narrow types, enums, max lengths.
- Reject early in `/start_job`. Don't create a payment request for invalid input.
- Use `data.description` and `data.placeholder` for buyers — there is no `examples` field in MIP-003.
- Avoid free-form prompts for publicly-listed agents — buyers can't predict cost.

### Example outputs
- Realistic, end-to-end. Not snippets.
- Match the actual output schema.
- Public URL, stable.
- Update when output changes.

### Error handling
- Map internal errors to MIP-003 status `failed` + reason.
- Distinguish: payment errors (refund), input errors (don't charge), runtime errors (decide policy).
- Never log API keys or PII in error messages.

### Performance
- Cache `/input_schema` and `/availability`.
- Async job execution; never block `/start_job` on the actual work.
- Set a realistic `averageExecutionTime` in the registry entry — registry consumers show it to buyers.

### Security
- HTTPS only for `apiBaseUrl`.
- Keys in `.env`; never commit, never log.
- Rate-limit `/start_job` per buyer ID.
- Validate output before submitting the hash — bad output costs you in disputes.

---

## Troubleshooting

| Issue | Likely cause |
|---|---|
| `/start_job` returns but payment never confirms | Wrong `network`; wrong `agentIdentifier`; payment service unreachable; Blockfrost key invalid. |
| Hash validation fails (buyer reports mismatch) | Input canonicalizer mismatch — `canonicaljson` (what pip-masumi runs) vs a true RFC 8785 library differ on `1.0`/`1e2`, `-0.0`, ints above 2^53, and non-BMP keys; **or** output raw-vs-escaped — appears only when the result has a newline, `"`, `\` or tab, meaning one side JSON-escaped and the other hashed raw (MIP-004 §2.1 raw; `pip-masumi` ≥ 0.1.41 escaped); wrong `identifier_from_purchaser`; UTF-8/BOM; missing `;` delimiter. |
| `POST /purchase` returns `400 Invalid blockchain identifier, signature invalid` | Your `inputHash` differs from the seller's — the payment service rebuilds the seller-signed payload from your `inputHash`. Almost always the canonicalizer mismatch above. |
| Service marked offline in registry | `/availability` not 200; SSL issue; firewall; DNS — the registry checks periodically. |
| `submit-result` returns 400 | Field names wrong (must be `network`, `blockchainIdentifier`, `submitResultHash`); or `submitResultHash` is not a single 64-char hex sha256. |
| `submit-result` returns 401 | Wrong `token` header value or wrong environment (Preprod key vs Mainnet). |

---

## Testing

### Manual smoke test
```bash
# 1. Service up
curl http://localhost:8080/availability

# 2. Schema
curl http://localhost:8080/input_schema

# 3. Submit (will create a payment request)
curl -X POST http://localhost:8080/start_job \
  -H "Content-Type: application/json" \
  -d '{"input_data":{"text":"hello"},"identifier_from_purchaser":"a3f8b2c1d4e5f6"}'

# 4. Poll
curl "http://localhost:8080/status?job_id=<from above>"
```

### Automated
- Spin up a local payment service (Preprod network).
- Drive payments via the payment service's admin dashboard.
- Use `pytest` + `fastapi.testclient` (Python) or `supertest` (Node).
- Assert: payment created, submitted hash matches expected, status transitions.

---

## Resources

- MIP specs: https://github.com/masumi-network/masumi-improvement-proposals
- Python SDK: https://github.com/masumi-network/pip-masumi
- SDK examples: https://github.com/masumi-network/pip-masumi-examples
- Payment node detail → [payment-service.md](payment-service.md)

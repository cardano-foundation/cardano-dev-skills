# Metadata Service — specification and compliance plan

The Metadata Service resolves the anchors chain data emits: given a hash and
optionally a url, it returns the document, verifies the hash, and — when asked —
validates it against a CIP.

It is a **required component** of the GovTool data layer
([`SPEC.md` §6](../../govtool/govtool-data-providers/SPEC.md)). The
implementation is [`govtool/govtool-metadata-service`](../../govtool/govtool-metadata-service),
an Express, Prisma and Postgres service in this repository.
`govtool-backend` reaches it through
[`govtool-metadata-http`](../../govtool/govtool-metadata-http) when
`GOVTOOL_METADATA_SERVICE_URL` is set, and every metadata-derived field
(`givenName`, `title`, `abstract`, references) is `null` when it is not.

`govtool/metadata-validation`, the standalone validator, is removed
(2026-10-01): `govtool-backend` serves its `POST /validate` as
`POST /metadata/validate`. The remaining plan is to move that validation into
the metadata service.

---

## 1. The two implementations

### `govtool-metadata-service` — Express + Prisma + Postgres

| Has | Detail |
|---|---|
| `GET /?hash=<hex>&url=<url>` | resolve by hash, fetch from url on a miss |
| Content cache | Postgres, keyed by hash, kept indefinitely |
| Error cache | 1-minute TTL, so a broken host is not re-hit per request |
| Cache bust | `Cache-Control: invalidate` request header |
| IPFS | ordered failover across four gateways, optional primary (D127–D130) |
| Hashing | blake2b-256 over raw response bytes (`libcardano`) |
| Fetch hardening | redirect limit 10, 40 s timeout, 2 MB body cap |
| Lenient parsing | JSON5, so trailing commas and comments survive |

### `govtool/metadata-validation` — NestJS, standalone (removed 2026-10-01)

| Has | Detail |
|---|---|
| `POST /validate` | fetch, hash-check, detect standard, validate |
| CIP detection | `getStandard` — CIP-119 / CIP-108 by marker in the document |
| CIP-119 | requires `givenName` |
| CIP-108 | requires `title`, `abstract`, `motivation`, `rationale`; length caps 84 / 3000 |
| JSON-LD field access | `getFieldValue`, `parseMetadata` |
| **SSRF protection** | DNS-lookup guard: rejects non-`http(s)`, `localhost`, and any address whose range is not `unicast` |

### Two findings that shape the merge

**`canonizeJSON` is dead code.** It is exported from `utils/index.ts` and called
from nowhere. Both services hash **raw response bytes**, so they already agree
and there is nothing to reconcile. If canonical JSON-LD hashing is ever
required, it is a deliberate future change, not a merge conflict.

**The SSRF guard is the most important thing the merge carries over.**
`govtool/metadata-validation` blocks `http://localhost`,
`http://169.254.169.254` (cloud instance metadata) and private ranges;
`govtool-metadata-service` now enforces the same allowlist (§2.6, item 1 in
§3). It is a security control, not a feature.

---

## 2. The specification

### 2.1 Surface

Three operations, matching `SPEC.md` §6 one-to-one.

| Method | Path | `SPEC.md` method |
|---|---|---|
| GET | `/metadata/{dataHash}?url=<url>` | `getMetadata(hash, url?)` |
| GET | `/metadata/{dataHash}?url=<url>&cip=<number>` | `getCipMetadata(cip, hash, url?)` |
| POST | `/metadata/{dataHash}/refresh?url=<url>` | `refresh(hash, url)` |

`cip` is a **number** (100, 108, 119), not an enum — a new standard needs no API
change. Absent, the document is returned unvalidated.

A fourth operation, `GET /metadata/reports/{reportId}`, returns the fetch
report a failure points to (§2.7).

**The service is private** ([D119](./decisions.md)). Only
`govtool-backend` calls it, and the backend exposes resolve, report and retry
and nothing else. Cache mechanics, including `Cache-Control: invalidate` and
refresh semantics, never reach the public surface.

### 2.2 Caching

**Content is cached permanently, keyed by hash.** Safe because the hash *is* the
content identity: if it matches, the bytes cannot have changed, so the cache can
never go stale.

**Errors are cached for a bounded duration**, because a failure describes the
network at a moment, not the content.

**The hash is authoritative; the url is only a hint.** Once content for a hash is
cached, a request for that hash is answered from the cache whatever url it
carries, and nothing is fetched. The url matters only on a miss, as a place to
fetch from. Content is never looked up by url: a url that once served some
document says nothing about what it serves now. ([D112](./decisions.md))

| Fact | Keyed by | Lifetime |
|---|---|---|
| bytes hash to **H** | **H** | permanent |
| url **U** failed, or served the wrong hash, when asked for **H** | **(U, H)** | bounded |

**Validation verdicts are cached permanently too, keyed by
`(hash, cip, RULES_VERSION)`.** They are as cacheable as the content and for the
same reason: validation is a pure function of bytes that cannot change under a
hash, so the verdict cannot change either.

`RULES_VERSION` is in the key because it is the one thing that *can* change —
a tightened CIP rule makes every prior verdict stale. Bumping the version
invalidates them without a migration, and old rows stay readable as a record of
what was considered valid when.

### 2.3 The fetch sequence — normative

> Caller asks for hash **H** with url **U** → cache miss on **H** → no live
> error for **(U, H)** → fetch **U** → bytes **B** → compute
> **H′ = blake2b-256(B)** → **cache B permanently under H′** → if **H′ ≠ H**,
> **cache `HASH_MISMATCH` for (U, H) for the bounded error duration** and return
> it.

A mismatch **still populates the content cache** under the hash actually served.
The fetch is not wasted, a later request for H′ is a hit with no url, and the
service accumulates a record of what a url really served versus what the chain
claimed. That is how you diagnose a publisher who edited a document after
anchoring it.

**The mismatch itself is not permanent.** It is a statement about what **U**
served at one moment, and a publisher can fix **U**. So it is cached exactly like
`FETCH_ERROR`: under **(U, H)**, for the bounded duration, with **H′** reported as
`servedHash`. After it expires, or on `refresh`, **U** is fetched again.

The cached bytes are the **exact bytes served**, never a re-serialization of the
parsed document, or they would stop hashing to their key.

### 2.4 Failure codes

One per pipeline stage — retrieve → size → parse → hash → validate:

| Code | Stage | HTTP |
|---|---|---|
| `FETCH_ERROR` | could not retrieve; DNS, timeout, refusal, TLS, blocked address — detail in `message` | 502 / 504 |
| `EXCEEDS_LIMIT` | larger than the service accepts | 413 |
| `JSON_PARSE_ERROR` | retrieved, not parseable | 422 |
| `HASH_MISMATCH` | parsed, hash does not match | 409 |
| `SCHEMA_INVALID` | hash-correct, violates the named CIP; `message` names the field and reason | 422 |

The set is closed, so a consumer can switch on it exhaustively. Sub-causes go in
`message`, deliberately not in more codes.

For display, the codes group into three categories (D115, confirmed by D124):

| Category | Codes |
|---|---|
| `NETWORK` | `FETCH_ERROR` |
| `INVALID_CONTENT` | `EXCEEDS_LIMIT`, `JSON_PARSE_ERROR`, `HASH_MISMATCH` |
| `SCHEMA_INVALID` | `SCHEMA_INVALID` |

Every failure also carries a `reportId` (§2.7). The message stays short; the
report holds the detail.

### 2.5 Validation is a shared pure module

**Validation and retrieval are separate concerns.** Retrieval needs a server —
CORS, SSRF guarding, IPFS gateways, redirects. Validation is a **pure function
over a parsed document**: no network, no filesystem, no framework. It runs
wherever the document already is.

So the rules live in one standalone package, used by every party:

```ts
export const RULES_VERSION: string;

export function detectStandard(document: unknown): number | undefined;

export function validate(document: unknown, cip: number): ValidationResult;

export type ValidationResult =
  | { valid: true;  standard: number }
  | { valid: false; standard: number; issues: ValidationIssue[] };

export interface ValidationIssue {
  field: string;    // "body.givenName"
  reason: string;   // "required by CIP-119 and absent"
}
```

| Consumer | Uses it for |
|---|---|
| **Metadata service** | validating at ingest, and caching the verdict (§2.2) |
| **Frontend — authoring** | validating a document as it is written, before it is pinned and anchored. No round trip, and an invalid document never reaches the chain. |
| **Frontend — display** | re-checking a document it already holds, with no request at all |
| **Backend** | rendering metadata-error states without asking the service |

`issues` is a **list**, not one error, so an authoring form can show every
problem at once rather than one per submit.

### 2.5.1 The rules

| CIP | Required |
|---|---|
| 119 (DRep) | `givenName` |
| 108 (governance action) | `title`, `abstract`, `motivation`, `rationale`; `title` ≤ 80 chars, `abstract` ≤ 2500, as the CIP-108 text sets them (F43) |
| 100 (base standard) | a JSON object; `hashAlgorithm`, when present, is `blake2b-256`. CIP-108 and CIP-119 include these checks |

Fields are read through the JSON-LD accessor, not by plain property lookup, so a
`@value`-wrapped field resolves.

### 2.5.2 Distribution

Published as **`@cardanoapi/governance-metadata`** from the public repository
`cardanoapi/governance-metadata`, with entry points `/cip100`, `/cip108`,
`/cip119` and `/hash` (D132).

The package is consumed by the frontend, the backend and the metadata
service, and the frontend cannot take a path dependency on a sibling package,
so it must be published rather than path-linked. Vendoring
it into both is what the shared module exists to prevent: the rules are small
enough that a divergence would be silent, and a frontend that accepts a document
the service later rejects is the worst outcome available.

### 2.6 Security

The service connects **only to globally routable public unicast addresses**
([D122](./decisions.md)). It is an allowlist: anything else is refused before
a connection opens, and the refusal appears in the fetch report.

Refused at minimum: unspecified, loopback, private (`10/8`, `172.16/12`,
`192.168/16`), **shared address space `100.64.0.0/10`** (carrier-grade NAT and
Tailscale), link-local (`169.254/16`, `fe80::/10`), **unique local IPv6
`fc00::/7`** (including Tailscale's `fd7a:115c:a1e0::/48`), protocol,
benchmarking and documentation ranges, multicast, reserved and broadcast. IPv6
forms that embed an IPv4 address (`::ffff:0:0/96`, `64:ff9b::/96`,
`2002::/16`) are checked against the embedded address. D122 has the full table.

- The check runs on **every resolved address**, not the hostname string.
- The connection uses **the address that was checked**, so a second DNS answer
  cannot swap in a private one (DNS rebinding).
- **Every redirect hop** is checked again.
- A url that is not `http(s)` is refused.

### 2.7 Fetch reports

A failure's `message` is a one-line summary. The **fetch report** is the
investigation view, one per failure, including failures that never connected
([D113–D115](./decisions.md)). Nothing in it is hidden from the user (D116).

| Section | Contents |
|---|---|
| Request | requested hash, url, effective url after IPFS rewriting, start and end time |
| DNS | the addresses returned, or the DNS error and its code |
| Attempts | one per IP tried: address, family, outcome (connected, refused, reset, unreachable, timeout, TLS error, or blocked by the guard with its range), error code, and timings for connect, TLS and first byte |
| Redirects | each hop's status and location |
| Response | HTTP status, headers, bytes received, whether the body was cut at the limit |
| Body | every byte received up to the fetch limit (D114). For `HASH_MISMATCH`, a reference to the content cached under `servedHash` instead of a copy |
| Result | code, category, computed hash, and for content failures the issues with source positions |

**Positions.** A content issue carries a byte offset, line, column, and a
start–end range, so the frontend can highlight the exact text. A parse failure
points at where parsing stopped. A CIP failure points at the offending value, or
at the object missing a field. The frontend highlights; the service only supplies
positions (D113).

**Lifetime.** Reports are kept forever (D123). Each fetch adds one and a retry
replaces nothing; the latest per (url, hash) is the default view. Bodies are
stored by the hash of their bytes, so a url that keeps serving the same broken
response stores it once. The one-minute error cache governs replay only (D121).

**The limit** is 2 MB, a named constant in the service's `config.ts`, not an
environment variable (D120). `govtool-backend` uses the same value the same way.

**Blocked addresses are reported, not hidden.** With full bodies in reports,
the SSRF guard (§2.6) is what stops a report from exposing internal services.
When the guard refuses an address, the report says so (F38, D122).

### 2.8 Wire format

Types are the contract's, in
[`metadata/index.ts`](../../govtool/govtool-data-providers/src/metadata/index.ts):
`MetadataResult`, `MetadataRefreshOutcome`, `MetadataReport`,
`MetadataReportSummary`. JSON field names match the contract exactly.

**Service** (`govtool-metadata-service`, private, called only by `govtool-backend`):

| Method | Path | Response |
|---|---|---|
| GET | `/api/metadata?hash=<hex>&url=<url>` | `200 {hash, fetchedAt, url, metadata}`, the shape existing clients read, or the failure status of §2.4 with `{code, category, message, url, fetchedAt, expectedHash?, servedHash?, reportId}` |
| POST | `/api/metadata/{hash}/refresh?url=<url>` | always `200` with a `MetadataRefreshOutcome`. When the window has not elapsed, also a `Retry-After` header |
| GET | `/api/metadata/reports/{reportId}` | `200 MetadataReport`, or `404` |
| GET | `/api/metadata/reports?hash=<hex>&url=<url>` | `200 MetadataReportSummary[]`, newest first |

`cip=` on the resolve route returns `501` until §3 item 3 lands.
`Cache-Control: invalidate` on the resolve route is an alias for refresh and
obeys the same window.

**Backend** (`govtool-backend`, public, called by the frontend):

| Method | Path | Response |
|---|---|---|
| GET | `/metadata/resolve?hash=<hex>&url=<url>` | always `200` with a `MetadataResult` |
| POST | `/metadata/retry` with body `{hash, url}` | always `200` with a `MetadataRefreshOutcome` |
| GET | `/metadata/reports/{reportId}` | `200 MetadataReport`, or `404` |
| GET | `/metadata/reports?hash=<hex>&url=<url>` | `200 MetadataReportSummary[]` |

The backend passes these through and adds nothing about caching (D119). It
never forwards `Cache-Control`. When the service is not configured, all four
answer `503`.

**Positions.** `offset` counts UTF-16 code units in the body decoded as UTF-8,
so the frontend can slice the string directly. `byteOffset` counts raw bytes.
`line` and `column` are 1-based. A range is half-open.

### 2.9 IPFS retrieval

Any IPFS url is fetched through the service's own gateways (D130):
`ipfs://<cid>`, `ipns://<name>`, `https://<any host>/ipfs/<cid>` and
`https://<cid>.ipfs.<any host>`. The host an anchor names is never contacted.

- **Order.** `IPFS_PRIMARY_GATEWAY`, when set, goes first, then the list in
  `config.ts` in order. Without a primary, the list is tried in a random order
  (D127). Default list: `ipfs.blockfrost.dev`, `c-ipfs-gw.nmkr.io`,
  `ipfs.filebase.io`, `gateway.pinata.cloud` (D129). `IPFS_GATEWAYS`, a
  comma-separated list of http(s) urls, replaces the default list; an
  isolated test environment points it at `tests/test-metadata-api`.
- **Failover.** Gateways are trusted (D126). The first `200` ends the search,
  and a hash mismatch or parse error from it is final. Anything else moves on:
  a network error, a timeout (15 s idle per stage), or a non-`200`.
- **Blacklist.** A `429` or `503` skips that gateway for 3 minutes (D128).
- **Report.** Every gateway tried is a hop in the one fetch report, in order.

## 3. Making `govtool-metadata-service` compliant

In dependency order.

| # | Change | Source | Status |
|---|---|---|---|
| 0 | **Extract the shared validation package** (§2.5) from `metadata-validation/src/utils/` — pure, no NestJS, no axios — and publish it | prerequisite for 2 | built as `@cardanoapi/governance-metadata`, not yet published |
| 1 | **Port the SSRF guard**: safe DNS lookup agent, protocol and range checks | `metadata-validation/src/app.service.ts` | done 2026-09-24, as the D122 allowlist |
| 2 | **Depend on the shared validation package** rather than porting rule code | the package from 0 | open |
| 3 | **Add `?cip=` to the resolve route**, running validation after the hash check, and **cache the verdict** under `(hash, cip, RULES_VERSION)` | new | open |
| 4 | **Re-map failure codes** to the five in §2.4 | replaces `INVALID_METADATA_JSON`, `METADATA_FETCH_FAILED` | done 2026-09-24 |
| 5 | **Add `EXCEEDS_LIMIT`** — the 2 MB cap exists but reports as a generic error | existing `maxBodySize` | done 2026-09-24 |
| 6 | **On hash mismatch**, cache the content permanently under the served hash and the mismatch briefly under (url, requested hash), per §2.3 | behaviour change | done 2026-09-24 |
| 6a | **Never serve content looked up by url**: a miss on H is a miss, whatever the url served last under another hash | bug, [F36](./decisions.md) | done 2026-09-24 |
| 7 | **Path-parameterise the hash**: `GET /metadata/{dataHash}` | currently `GET /?hash=` | open |
| 8 | **Add `POST /metadata/{dataHash}/refresh`** | `Cache-Control: invalidate` stays as an alias | done 2026-09-24, under `/api/metadata` |
| 9 | **Record fetch reports** (§2.7) for every failure and serve them by `reportId` | D113–D115 | done 2026-09-24 |
| 10 | **Source positions on content issues**, which needs a position-aware parser in the shared validation package | D113 | parse errors and `hashAlgorithm` done; CIP issues wait for item 3 |
| 11 | **Move the 2 MB limit into `config.ts`** | D120 | done 2026-09-24 |

Until item 3 lands, the resolve path still rejects an invalid `hashAlgorithm`
field. It now reports that as `SCHEMA_INVALID`, and it moves under `?cip=` with
the rest of validation.

Leave alone: the Postgres cache, the IPFS gateway list, JSON5 parsing, redirect
and timeout handling, the `datastore` table. They are already correct or out of
scope.

## 4. How GovTool consumes it

A thin HTTP client package implements `MetadataServiceV1`:

```
govtool/govtool-metadata-http/
  src/index.ts   →  createHttpMetadataService({ baseUrl })
```

One HTTP call per method, mapping the response codes in §2.4 onto the
contract's `MetadataResult`. No caching; the service owns that.

The backend holds it under the `METADATA` injection token beside `CHAIN_DATA`,
and the DRep and proposal services resolve anchors through it, so
metadata-derived fields are filled whenever the service is configured.

The backend's public surface for metadata is three things (D119): resolve an
anchor, read a fetch report, and retry. Retry appears on the DRep details page
for the connected DRep and on the governance action details page (D118). Its
rate limiting is the backend's (D93): anyone may retry, at most one real fetch
per (url, hash) per minute, and a click inside the window returns the seconds
remaining so the frontend can show a countdown (D125). Reports are shown to authors while they
fill in a form, and on details pages to publishers whose document stopped
showing (D117). The backend's own 1 MB fetch cap, reported as `URL_NOT_FOUND`,
is replaced by the shared 2 MB constant (D120).

**`govtool/metadata-validation` is deleted** (done 2026-10-01; the backend's
`POST /metadata/validate` answers in its place, with an `issues` list naming
the fields at fault, and `verifyUrl: true` for submission, which fetches the
url through the service's `verify` rather than trusting the hash cache and
carries the fetch report, D152). Its route is to be served by `?cip=` on the merged
service, and
`/api/v1/metadata/validations` in the REST v1 spec becomes a thin proxy or is
dropped in favour of the GET.

## 5. Order of work

1. **Extract and publish the shared validation package.** Blocks the service and
   unblocks the frontend independently — the frontend can adopt it for
   authoring-time validation before anything else ships.
2. **`govtool-metadata-service`**: the open items in §3 (2, 3, 7, and the
   CIP half of 10). Independent of GovTool once 1 is published.
3. **`govtool-metadata-http`** and its wiring into `govtool-backend`: done.
4. **Frontend**: replace the six per-card `validateMetadata` effects. Documents
   the backend already resolved arrive with status attached; anything the
   frontend holds itself it checks locally with the shared package. Either way
   the round trip disappears.
5. **Delete `govtool/metadata-validation`.** Done 2026-10-01, ahead of step 4:
   the per-card requests go to the backend's `/metadata/validate` until then.

Step 4 lands with the frontend's move to the `/api/v1` routes.

### What this fixes beyond the merge

Six frontend display components currently fire a `validateMetadata` request per
card inside a `useEffect`. A twenty-DRep directory is twenty round trips, each
asking a server to re-fetch and re-validate a document it may already hold —
validation happening at *display* time when it should happen at *ingest* time.

After this, the verdict is computed once, cached beside the content, and travels
with the entity. Those effects are deleted rather than rewritten.

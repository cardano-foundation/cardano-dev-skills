# GovTool REST API v1 — paths

Closes [#1034](https://github.com/IntersectMBO/govtool/issues/1034), open since
2024-05-16: *"the api follow non-standard naming and the paths contain redundant
words like 'list' 'get' etc."*

**Paths only.** Request and response bodies are the backend's projection of
[`SPEC.md`](../../govtool/govtool-data-providers/SPEC.md); this document fixes
the URL surface and nothing else.

---

## Conventions

Following [restfulapi.net/resource-naming](https://restfulapi.net/resource-naming/):

1. **Plural nouns for collections.** `/dreps`, not `/drep`.
2. **No verbs in paths.** The method is the verb — `GET /dreps`, not
   `GET /drep/list`. `list`, `get`, `info` and `getVotes` all disappear.
3. **Hierarchy expresses ownership.** A DRep's votes are `/dreps/{id}/votes`.
4. **Query parameters filter, sort and page** — never path segments.
5. **kebab-case** in paths, `camelCase` in query parameters and bodies.
6. **Versioned under `/api/v1`**, so the new surface runs alongside the current
   routes and the frontend migrates route by route rather than in one commit.

Shared query parameters, uniform across every collection:

| Parameter | Meaning |
|---|---|
| `page` | 1-based. Default 1. |
| `size` | Page size. Default 20. |
| `sort` | A sort key the resource declares. |
| `search` | One term; the provider applies whatever matching it supports. |

Every collection response carries `total` when the provider can count.

---

## The surface

### DReps

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/dreps` | `GET /drep/list` |
| GET | `/api/v1/dreps/{drepId}` | `GET /drep/info/{drepId}` |
| GET | `/api/v1/dreps/{drepId}/voting-power` | `GET /drep/get-voting-power/{drepId}` |
| GET | `/api/v1/dreps/{drepId}/votes` | `GET /drep/getVotes/{drepId}` |
| GET | `/api/v1/dreps/{drepId}/delegators` | — new |
| GET | `/api/v1/dreps/{drepId}/registration-history` | — new |
| GET | `/api/v1/dreps/summary` | — new (counts) |

Filters on `/dreps`: `status`, `kind`, `ids`.

> **`/drep/voting-power-list` is deleted, not renamed.** It was a batch read of
> one field. `GET /dreps?ids=a,b,c` returns those DReps, and voting power is
> already on each — one collection read instead of a parallel endpoint.

### Governance actions

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/governance-actions` | `GET /proposal/list` |
| GET | `/api/v1/governance-actions/{actionId}` | `GET /proposal/get/{proposalId}` |
| GET | `/api/v1/governance-actions/{actionId}/votes` | — new |
| GET | `/api/v1/governance-actions/{actionId}/vote-summary` | — new (per-role aggregates) |
| GET | `/api/v1/governance-actions/{actionId}/activity` | — new (lifecycle feed) |
| GET | `/api/v1/governance-actions/enacted` | `GET /proposal/enacted-details` |
| GET | `/api/v1/governance-actions/enacted/{lineage}` | — new |

Filters on `/governance-actions`: `type`, `status`, `voterId`, `voted`.

> `enacted` is a literal segment and CIP-129 action ids all begin `gov_action1`,
> so the two cannot collide — but the router must match the literal before the
> parameter.
>
> `{lineage}` is one of `pparam-update`, `hard-fork`, `committee`,
> `constitution`. This is the `prevGovActionId` lookup used when constructing a
> governance transaction, and `committee` deliberately covers both
> `UpdateCommittee` and `NoConfidence` — they share one lineage.

### Accounts

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/accounts/{stakeAddress}` | `GET /account/{stakeKey}` |
| GET | `/api/v1/accounts/{stakeAddress}/voting-power` | `GET /ada-holder/get-voting-power/{stakeKey}` |
| GET | `/api/v1/accounts/{stakeAddress}/delegation` | `GET /ada-holder/get-current-delegation/{stakeKey}` |
| GET | `/api/v1/accounts/{stakeAddress}/delegation-history` | — new |

> **`/ada-holder` disappears.** It named an actor, not a resource, and split one
> stake account across two prefixes — `/account/{k}` and
> `/ada-holder/…/{k}` addressed the same thing.

### Network

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/network` | `GET /network/info` |
| GET | `/api/v1/network/protocol-parameters` | `GET /epoch/params` |
| GET | `/api/v1/network/stake-distribution[?epoch=]` | `GET /network/total-stake` |
| GET | `/api/v1/network/treasury` | — new |

> **`/epoch/params` moves under `/network`.** Protocol parameters are network
> state; `/epoch` implied a collection of epochs that never existed.
>
> **`/network/metrics` is deleted.** Every counter it carried moved to the
> resource that owns it, or was dropped as unread. Quorum is on `/committee`,
> treasury on `/network/treasury`, DRep counts on `/dreps/summary`.

### Committee and constitution

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/committee[?epoch=]` | — new |
| GET | `/api/v1/committee/members/{coldCredentialId}` | — new |
| GET | `/api/v1/constitution` | — new |

> `?epoch=` on both is the contract's optional argument
> (`stakeDistribution.epoch`, `committee.epoch`, D143): a provider that does
> not declare it answers 501 for any epoch but the current one.
>
> Members are addressed by **cold** credential. The hot credential rotates, so
> an id built on it breaks every stored reference.

### Stake pools

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/pools` | — new |
| GET | `/api/v1/pools/{poolId}` | — new |
| GET | `/api/v1/pools/{poolId}/votes` | — new |

### Transactions

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/transactions/{txHash}` | `GET /transaction/status/{transactionId}` |

> `status` is the only thing the current path returns, so it is a field name in a
> URL. The resource is the transaction.

### Metadata and pinning

| Method | Path | Replaces |
|---|---|---|
| POST | `/api/v1/metadata/validations` | `POST /validate` |
| GET | `/api/v1/metadata/{dataHash}` | — new |
| POST | `/api/v1/pins` | `POST /ipfs/upload` |

> **`/ipfs/upload` names a backend and an action.** The resource is a pin;
> creating one is `POST /pins`. Swapping IPFS for another store then changes no
> URL.

### System

| Method | Path | Replaces |
|---|---|---|
| GET | `/api/v1/system/capabilities` | `GET /system/capabilities` |
| GET | `/api/v1/system/features` | `GET /system/features` |
| GET | `/api/v1/system/health` | `GET /health` |

---

## Every current path, accounted for

| Current | v1 |
|---|---|
| `GET /drep/list` | `GET /dreps` |
| `GET /drep/info/{id}` | `GET /dreps/{id}` |
| `GET /drep/get-voting-power/{id}` | `GET /dreps/{id}/voting-power` |
| `GET /drep/getVotes/{id}` | `GET /dreps/{id}/votes` |
| `GET /drep/voting-power-list` | **deleted** — `GET /dreps?ids=` |
| `GET /proposal/list` | `GET /governance-actions` |
| `GET /proposal/get/{id}` | `GET /governance-actions/{id}` |
| `GET /proposal/enacted-details` | `GET /governance-actions/enacted` |
| `GET /account/{stakeKey}` | `GET /accounts/{stakeAddress}` |
| `GET /ada-holder/get-voting-power/{k}` | `GET /accounts/{k}/voting-power` |
| `GET /ada-holder/get-current-delegation/{k}` | `GET /accounts/{k}/delegation` |
| `GET /network/info` | `GET /network` |
| `GET /network/total-stake` | `GET /network/stake-distribution` |
| `GET /network/metrics` | **deleted** — split across owning resources |
| `GET /epoch/params` | `GET /network/protocol-parameters` |
| `GET /transaction/status/{id}` | `GET /transactions/{id}` |
| `GET /survey/definition/{tx}/{ix}` | **deleted** — CIP-179 is out of scope |
| `POST /ipfs/upload` | `POST /pins` |
| `POST /validate` | `POST /metadata/validations` |
| `GET /throw500` | **deleted** — a test route on a public surface |

---

## What the rename buys

- **No verb ever appears in a path.** `list`, `get`, `info`, `getVotes`,
  `upload`, `validate`, `status` and `enacted-details` are gone.
- **One resource, one prefix.** A stake account was split across `/account` and
  `/ada-holder`; both are now `/accounts/{stakeAddress}`.
- **Casing is consistent.** `getVotes` was the only camelCase path segment in
  the API.
- **Two endpoints disappear rather than move** — the batch voting-power read is
  a filtered collection, and `/network/metrics` splits across the resources that
  own its counters.
- **Nine capabilities become reachable** that the current surface has no path
  for: committee, constitution, pools, pool votes, per-action votes and
  aggregates, DRep delegators, registration history, and delegation history.

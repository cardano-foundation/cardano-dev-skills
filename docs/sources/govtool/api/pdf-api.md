# PDF backend: endpoint index

The proposal discussion forum backend, `govtool/govtool-pdf-backend` (D138).
Every route pdf-ui calls, and nothing else. Shapes, query rules, errors,
deviations from Strapi (Δn) and tests are in
[`govtool/govtool-pdf-backend/SPEC.md`](../../govtool/govtool-pdf-backend/SPEC.md);
section numbers below point there.

Auth: **public** (a valid Bearer identifies the caller; an invalid one is
ignored), **auth** (no token 403, bad token 401), **owner** (auth, and the row
must be the caller's: missing 404, foreign 403). All paths are under `/api`
except `/health`. Responses are Strapi v4 envelopes unless marked **raw**.

| Method | Path | Auth | Purpose | § |
|---|---|---|---|---|
| GET | `/health` | public | Liveness, raw `{status}` | 2 |
| GET | `/api/auth/challenge?identifier=` | public | Issue a sign-in challenge, raw `{message}` | 7.2 |
| POST | `/api/auth/local` | public | CIP-30 signData login (stake; DRep needs a Bearer), raw `{status, jwt, user}`, sets refresh cookie | 7.4 |
| POST | `/api/token/refresh` | public (cookie) | New access JWT, raw `{jwt}` | 7.6 |
| GET | `/api/users/me` | auth | Caller's self projection, raw | 7.7 |
| PUT | `/api/users/edit` | auth | Set `govtool_username`, raw | 7.7 |
| GET | `/api/governance-action-types` | public | Action types list | 8.1 |
| GET | `/api/proposals` | public | Proposals by content (drafts caller-scoped) | 8.2 |
| GET | `/api/proposals/:id` | public | One proposal by id or tx hash, active content | 8.2 |
| POST | `/api/proposals` | auth | Create proposal + first content | 8.2 |
| DELETE | `/api/proposals/:id` | owner | Delete proposal and everything under it | 8.2 |
| POST | `/api/proposal-contents` | owner (of the proposal) | New revision or draft revision | 8.3 |
| PUT | `/api/proposal-contents/:id` | owner | Record GA submission (tx hash, date) | 8.3 |
| GET | `/api/proposal-votes?filters[proposal_id][$eq]=` | auth | Caller's like/dislike, single or null | 8.4 |
| POST | `/api/proposal-votes` | auth | Like or dislike | 8.4 |
| PUT | `/api/proposal-votes/:id` | owner | Flip like/dislike | 8.4 |
| GET | `/api/polls` | public | Proposal polls | 8.5 |
| POST | `/api/polls` | auth (proposal owner) | Open a poll | 8.5 |
| PUT | `/api/polls/:id` | auth (proposal owner) | Close a poll | 8.5 |
| GET | `/api/poll-votes` | auth | Caller's poll votes | 8.6 |
| POST | `/api/poll-votes` | auth | Vote on an active poll | 8.6 |
| PUT | `/api/poll-votes/:id` | owner | Flip the vote | 8.6 |
| GET | `/api/comments` | public | Comments and replies, with computed author fields | 8.7 |
| POST | `/api/comments` | auth | Comment or reply on a proposal or BD | 8.7 |
| POST | `/api/comments-reports` | auth | Report a comment | 8.12 |
| DELETE | `/api/comments-reports/:id` | owner (reporter) | Withdraw a report | 8.12 |
| GET | `/api/bds` | public | BD versions list | 8.8 |
| GET | `/api/bds/:masterId` | public | Active version of a BD | 8.8 |
| POST | `/api/bds` | auth | Create a BD (auto-creates its poll) or a new version, **raw** | 8.8 |
| DELETE | `/api/bds/:rowId` | owner | Delete the whole BD chain | 8.8 |
| GET | `/api/bd/versions/:masterId` | public | Every version, newest first | 8.8 |
| GET | `/api/bd-types` | public | Lookup | 8.9 |
| GET | `/api/bd-road-maps` | public | Lookup | 8.9 |
| GET | `/api/bd-intersect-committees` | public | Lookup | 8.9 |
| GET | `/api/bd-contract-types` | public | Lookup | 8.9 |
| GET | `/api/bd-currency-lists` | public | Lookup | 8.9 |
| GET | `/api/country-lists` | public | Lookup | 8.9 |
| GET | `/api/bd-drafts` | auth | Caller's BD drafts | 8.10 |
| POST | `/api/bd-drafts` | auth | Save a draft | 8.10 |
| PUT | `/api/bd-drafts/:id` | owner | Update a draft (foreign = 404) | 8.10 |
| DELETE | `/api/bd-drafts/:id` | owner | Delete a draft (foreign = 404) | 8.10 |
| GET | `/api/bd-polls` | public | BD polls | 8.11 |
| GET | `/api/bd-poll-votes` | public | BD poll votes (DRep votes are public) | 8.11 |
| POST | `/api/bd-poll-votes` | auth, DRep token | Vote on a BD poll | 8.11 |
| PUT | `/api/bd-poll-votes/:id` | owner | Flip the vote | 8.11 |
| GET | `/api/proxy/govtool/<path>` | public | Allowlisted GET to `GOVTOOL_API_BASE_URL`, raw `{status, data}` | 9.1 |
| POST | `/api/proxy` | auth | Safe public-URL GET fetcher, raw `{status, data}` | 9.2 |

Not provided (pdf-ui does not call them, or calls them broken): the Strapi
admin, GraphQL and generic content API; `/report/*`, `/migration/*`,
`/govtool-proxy`, `POST /proxy/govtool/*`; BD section and contact-information
routes; `GET`/`PUT /api/comments-reports/` without an id; `PUT /proposals/:id`.
SPEC.md §1 has the full list.

# GovTool data layer: API documents

The specification lives with the code, at
[`govtool/govtool-data-providers/SPEC.md`](../../govtool/govtool-data-providers/SPEC.md).
It covers the six components, the contract conventions, what a provider
declares and the load-bearing constraints. The TypeScript in
[`govtool-data-providers/src/`](../../govtool/govtool-data-providers/src) is
the same thing stated precisely, and is the source of truth for shapes.

| Document | What it answers |
|---|---|
| [`rest-api-v1.md`](./rest-api-v1.md) | The `/api/v1` HTTP path surface the backend will expose beside its current routes, and how each current path maps |
| [`metadata-service-spec.md`](./metadata-service-spec.md) | What the metadata service does, its wire format, and which compliance items are done |
| [`pdf-api.md`](./pdf-api.md) | The proposal discussion forum backend's endpoints (`govtool-pdf-backend`, D138): method, path, auth and purpose, pointing into its SPEC.md |
| Governance action records | `govtool-backend` serves `/governance-actions` and `/misc` on the same `VITE_BASE_URL` as every other backend request; detail responses include complete per-role `vote_aggregates`, used independently by the voting panel (D158); response shapes in D143, naming amendment in D162 |
| [`decisions.md`](./decisions.md) | Why: the append-only log of numbered decisions (D1 onward) and findings (F1 onward). Later entries beat earlier ones and name what they amend |

Tracking: [#4221](https://github.com/IntersectMBO/govtool/issues/4221) for the
Chain Data API, [#4224](https://github.com/IntersectMBO/govtool/issues/4224) /
[#4225](https://github.com/IntersectMBO/govtool/issues/4225) for metadata, and
[#4222](https://github.com/IntersectMBO/govtool/issues/4222),
[#4223](https://github.com/IntersectMBO/govtool/issues/4223),
[#4234](https://github.com/IntersectMBO/govtool/issues/4234),
[#4235](https://github.com/IntersectMBO/govtool/issues/4235) for the providers.

## Planned, not yet done

- The `/api/v1` routes of `rest-api-v1.md`, added beside the backend's current
  routes, after which the frontend moves route by route. This closes
  [#1034](https://github.com/IntersectMBO/govtool/issues/1034).
- The open items in `metadata-service-spec.md` §3: a shared, published CIP
  validation package, `?cip=` validation on the resolve route, and the
  path-parameterised hash.

## Open questions

- Whether the synchronous-throw hazard belongs in SPEC.md §11.
- Whether the contract gains an HTTP binding alongside the TypeScript
  interface. As built, a provider must be a TypeScript module; the Koios and
  Blockfrost providers are thin adapters over remote HTTP, so a remote source
  works today, but a provider in another language would need a shim.
- Whether the provider packages move under `govtool-backend/`. They are
  siblings today, and moving them would break every `file:` path and the
  Docker build context.

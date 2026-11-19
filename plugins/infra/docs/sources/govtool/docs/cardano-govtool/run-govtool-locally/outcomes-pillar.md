# Outcomes Pillar

The Governance Actions Outcomes section is now part of Core GovTool as governance action history:

* The **history UI** is part of the GovTool frontend source and is always enabled, at `/governance_actions/history`.
* The **governance action records** are served by the GovTool backend under `/governance-actions`, on the same `VITE_BASE_URL` as the rest of the frontend. No separate URL or flag is needed.

The separate [Outcomes Pillar](https://github.com/IntersectMBO/govtool-outcomes-pillar) backend is no longer deployed, and you do not need to run it. Follow [Core GovTool](./core-govtool.md) to set up the frontend and backend.

## Prerequisites

* The backend needs a data source that can retrieve Governance Actions raised in the past, such as a db-sync instance (see [Core GovTool](./core-govtool.md)).
* A valid IPFS Gateway (`IPFS_GATEWAY`) should be set on the backend so that the metadata associated with the Governance Action can be displayed.
* The governance action route that links a Governance Action to its proposal discussion uses `GOVTOOL_PDF_API_URL`. Without it, that route answers `503`.

## Notice

As the instance of [Cardano GovTool](https://gov.tools) uses a DB-Sync with which leverages some of the [insert options](https://github.com/IntersectMBO/cardano-db-sync/blob/13.6.0.4/doc/configuration.md#properties) available in the config file everything may not display identically when running locally e.g. 3rd party providers may not have access to the pool stat table meaning SPO voting may not show/be accurate

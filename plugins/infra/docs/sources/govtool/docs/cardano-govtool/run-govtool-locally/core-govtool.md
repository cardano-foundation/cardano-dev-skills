# Core GovTool

## [Core GovTool](https://github.com/IntersectMBO/govtool)

Core GovTool is comprised of the frontend, backend and metadata services which will allow you to view

* Home,
* Governance Actions Live Voting,
* Drep Directory,
* Guides
* FAQs
* Governance action history (served by the backend under `/governance-actions`)

with or without a wallet connected

:::note
"Backend" on these pages refers to the NestJS (TypeScript) service in `govtool/govtool-backend` (image `ghcr.io/intersectmbo/govtool-backend`). It replaced the Haskell backend (`govtool/backend`), which has been removed. It is configured through `GOVTOOL_*` environment variables, listed in [`govtool-backend/.env.example`](https://github.com/IntersectMBO/govtool/blob/develop/govtool/govtool-backend/.env.example), not through a `config.json` file.
:::

## Prerequisites

To run Core GovTool against live data you will need access to a **DB-Sync Instance**, this can be run locally or via a third party e.g. Demeter.\
This is a dependency of the backend service (with `GOVTOOL_CHAIN_DATA_PROVIDER=dbsync`, the default), which will query the information stored in DB-Sync to retrieve and populate the respective pages with information. The backend checks off-chain metadata itself (`/metadata`), with the help of the metadata service.

Set `GOVTOOL_DBSYNC_NETWORK` to the network your DB-Sync follows (`mainnet`, `preprod`, `preview` or `devnet`). If it does not match the database, every backend route answers `500`.

To try GovTool without DB-Sync, use the frozen mainnet data (`fixture`) or Koios setups described in [Run GovTool Locally](./README.md).

## Notice

As the instance of [Cardano GovTool](https://gov.tools) uses a DB-Sync with which leverages some of the [insert options](https://github.com/IntersectMBO/cardano-db-sync/blob/13.6.0.4/doc/configuration.md#properties) available in the config file everything may not display identically when running locally e.g. 3rd party providers may not have access to the pool stat table meaning SPO voting may not shown/be accurate

The Backend service heavily utilises the utxo\_view shipped as standard with db-sync, however in some instances, depending on the config used, it can encounter issues. Below are two examples of how this view can be re-created if required:

13.6.0.4

`CREATE OR REPLACE VIEW public.utxo_view AS SELECT tx_out.id, tx_out.tx_id, tx_out.index, address.address, address.has_script AS address_has_script, address.payment_cred, tx_out.stake_address_id, tx_out.value, tx_out.data_hash, tx_out.inline_datum_id, tx_out.reference_script_id, tx_out.consumed_by_tx_id FROM tx_out LEFT JOIN tx_in ON tx_out.tx_id = tx_in.tx_out_id AND tx_out.index::smallint = tx_in.tx_out_index::smallint LEFT JOIN tx ON tx.id = tx_out.tx_id LEFT JOIN address ON address.id = tx_out.address_id LEFT JOIN block ON tx.block_id = block.id WHERE tx_in.tx_in_id IS NULL AND block.epoch_no IS NOT NULL AND tx_out.consumed_by_tx_id IS NULL;`

previous versions

`CREATE OR REPLACE VIEW public.utxo_view AS SELECT tx_out.id, tx_out.tx_id, tx_out.index, tx_out.stake_address_id, tx_out.value, tx_out.data_hash, tx_out.inline_datum_id, tx_out.reference_script_id, tx_out.consumed_by_tx_id, tx_out.address_id FROM tx_out LEFT JOIN tx_in ON tx_out.tx_id = tx_in.tx_out_id AND tx_out.index::smallint = tx_in.tx_out_index::smallint LEFT JOIN tx ON tx.id = tx_out.tx_id LEFT JOIN block ON tx.block_id = block.id WHERE tx_out.consumed_by_tx_id is NULL AND tx_in.tx_in_id IS NULL AND block.epoch_no IS NOT NULL;`

## Setting up Core GovTool

1. Review the frontend -> fe-env-vars.yaml file and add your custom env vars. For the backend, set the `GOVTOOL_*` environment variables from [`govtool-backend/.env.example`](https://github.com/IntersectMBO/govtool/blob/develop/govtool/govtool-backend/.env.example), at least the `GOVTOOL_DBSYNC_*` connection group
2. Review [frontend.yaml](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/frontend/frontend.yaml), [backend.yaml](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/backend/backend.yaml) and [metadata.yaml](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/metadata/metadata.yaml) ensuring to update the Deployment Containers Image Spec ([example](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/frontend/frontend.yaml#L34)) with the associated image for the service (these can be custom or the images referenced in the current deployments) and metadata -> namespace ([example](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/frontend/frontend.yaml#L5)) if not using the default govtool namespace
3. Create the Kubernetes Secrets which will house the env vars using `kubectl apply` and `kubectl create secret` in your chosen namespace. The community example still mounts a [config.json](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/backend/config.json) for the removed Haskell backend; replace it with the `GOVTOOL_DBSYNC_*` variables
4. Use `kubectl apply` to launch the frontend backend and metadata services in the same namespace as your secrets -- ([kubectl links](./quick-links.md))

:::note
The community example's `metadata.yaml` runs the removed `govtool-metadata-validation` image. Replace it with `ghcr.io/intersectmbo/govtool-metadata-service` and its PostgreSQL database, and point the backend at it with `GOVTOOL_METADATA_SERVICE_URL`.
:::

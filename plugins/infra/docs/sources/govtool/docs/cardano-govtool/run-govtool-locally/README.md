# Run GovTool Locally

If you are interested in contributing or exploring GovTool in depth, you can run the GovTool services on your own machine.

## Docker Compose (recommended)

The GovTool repository has three Docker Compose setups. Pick the one that matches the data you want to see.

### Frozen mainnet data (no db-sync)

The quickest way to see the whole stack is [`govtool/docker-compose.fixture.yml`](https://github.com/IntersectMBO/govtool/blob/develop/govtool/docker-compose.fixture.yml). It runs the backend on a frozen mainnet capture, so it needs no db-sync, no Cardano node and no credentials. From the `govtool` folder:

```bash
docker compose -f docker-compose.fixture.yml up -d --build
```

It starts:

* the frontend (the Vite dev server over your local source) on port `8080`
* the backend on port `9999`
* the Proposal Discussion backend (`govtool-pdf-backend`) on port `1337`
* the metadata service and the PostgreSQL databases of the metadata service and the Proposal Discussion backend, which are not published

Off-chain metadata is still fetched live from the internet, IPFS included.

### Live data from Koios (no db-sync)

[`govtool/docker-compose.koios.yml`](https://github.com/IntersectMBO/govtool/blob/develop/govtool/docker-compose.koios.yml) runs the backend against the public [Koios](https://koios.rest/) API, so you see live chain data without a database of your own. The frontend is on port `8080` and the backend on port `9999`. To use a testnet, set both `KOIOS_NETWORK` and `VITE_NETWORK_FLAG` (`1` for mainnet, `0` for every testnet); if they do not match, the wallet refuses to connect. It also runs the metadata service and its PostgreSQL database, so DRep names and governance action titles are shown.

:::note
Koios is a supported alternative to db-sync. What the Koios provider serves and omits is listed in its [README](https://github.com/IntersectMBO/govtool/blob/develop/govtool/govtool-provider-koios/README.md).
:::

### Your own db-sync

[`docker/docker-compose.yaml`](https://github.com/IntersectMBO/govtool/blob/develop/docker/README.md) runs the published images against a db-sync PostgreSQL instance that you provide. It starts:

* the frontend on port `80`
* the backend on port `9999`, including governance action records under `/governance-actions`
* the metadata service and its PostgreSQL database, which only the backend reaches (metadata validation is served by the backend under `/metadata`)

Set `METADATA_DB_PASSWORD` in `docker/.env` before you start it. Set `DBSYNC_NETWORK` in `docker/.env` to the network your db-sync follows (`mainnet`, `preprod`, `preview` or `devnet`). If it does not match the database, every backend route answers `500`. See [Core GovTool](./core-govtool.md) for the db-sync prerequisites.

All three setups need Docker with Docker Compose.

## Without Docker

To work on the backend or the frontend directly, see the [backend README](https://github.com/IntersectMBO/govtool/blob/develop/govtool/govtool-backend/README.md) and the [frontend README](https://github.com/IntersectMBO/govtool/blob/develop/govtool/frontend/README.md). The backend can run on the frozen mainnet data with `GOVTOOL_CHAIN_DATA_PROVIDER=fixture`, with nothing else running.

## Kubernetes (Minikube)

You can also run GovTool in a lightweight Minikube cluster, running each of the associated services on localhost. A community example is available in [aaboyle878/govtool-k8-manifest](https://github.com/aaboyle878/govtool-k8-manifest) (last updated August 2025, before the backend was replaced, so its backend configuration no longer applies). The rest of this section describes that setup.

The Helm charts and Argo CD configuration used for the hosted GovTool deployments are in [IntersectMBO/govtool-argo](https://github.com/IntersectMBO/govtool-argo).

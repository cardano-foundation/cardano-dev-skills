# Proposal Pillar

## [Proposal Pillar](https://github.com/IntersectMBO/govtool-proposal-pillar)

The Proposal Pillar backend when combined with the Core GovTool Frontend UI will enable viewing of Budget Proposals and Governance Actions -> Proposals areas

:::info
The GovTool repository now has its own Proposal Discussion backend, [`govtool/govtool-pdf-backend`](https://github.com/IntersectMBO/govtool/blob/develop/govtool/govtool-pdf-backend/README.md) (NestJS, Prisma and PostgreSQL). It replaces the Strapi backend of the Proposal Pillar and serves the same API. CI builds its image (`ghcr.io/intersectmbo/govtool-pdf-backend`), and it is the easiest way to run the Proposal Discussion locally: `docker compose up -d --build` in that folder starts it on port `1337`, and the frozen mainnet data setup in [Run GovTool Locally](./README.md) includes it. Point the frontend at it with `VITE_PDF_API_URL`.

The rest of this page describes the Proposal Pillar's Strapi backend.
:::

## Prerequisites

* As the proposal pillar was designed for off-chain discussion it will require a Postgres DB to store any user discussion information

## Notice

* As stated above because this service covers off chain discussions when initially launched the DB will be empty and so there will be nothing to load when the respective pages are accessed from the frontend UI
* As this repo was designed for dev purposes only the db has not been assigned any persistent storage (if running long term this will need to be updated)

## Setting Up the Proposal Pillar

* Review the [pdf-db-connect.yaml](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/pdf/pdf-db-connect.yaml) and [pdf-env-vars.yaml](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/pdf/pdf-env-vars.yaml) files adding your custom env vars
* Review [pdf-db.yaml](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/pdf/pdf-db.yaml) and [pdf.yaml](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/pdf/pdf.yaml) ensuring to update the [Deployment Containers Image Spec](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/pdf/pdf.yaml#L34) with the associated image for the service (these can be custom or the images referenced in the current deployments) and [metadata -> namespace](https://github.com/aaboyle878/govtool-k8-manifest/blob/6f297e580250882dcefcfbef4f4abcbf56a6ead4/govtool/mainnet/pdf/pdf.yaml#L5) if not using the default govtool namespace
* Create the Kubernetes Secrets which will house the env vars using `kubectl apply` in your chosen namespace
* Use `kubectl apply` to first create the pdf db and then pdf service in the same namespace as your secrets -- ([kubectl links](./quick-links.md))

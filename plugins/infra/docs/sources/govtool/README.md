# GovTool Documentation

Source for [docs.gov.tools](https://docs.gov.tools), built with [Docusaurus](https://docusaurus.io/).

It contains:

- **User guides**, migrated as-is from the GitBook export in
  [IntersectMBO/governance-tools-documentation](https://github.com/IntersectMBO/governance-tools-documentation)
  (`gitbook/` directory). Page paths, sidebar order and labels match the original GitBook `SUMMARY.md`.
- **Legal pages** (`docs/legal/`): GovTool's Privacy Policy and Terms of Use.
- **Developer documentation** (`docs/developers/`): architecture, governance action submission,
  handling new governance action types, and the React / CSS style guides that previously lived in this folder.

Two parts of this folder are not published on the site: `api/` (the backend API surface, the metadata
service and Proposal Discussion API specs, and the data-layer design decisions) and `known-issues.md`.
`api/` is linked from the site's developer pages.

## Local development

Requires Node.js >= 22.22.0.

```sh
cd docs
npm ci
npm start        # dev server on http://localhost:3000
npm run build    # static site in ./build
npm run serve    # serve the production build
```

## Checks on pull requests

`.github/workflows/check-docs.yml` runs on every pull request that touches `docs/`, for the root path (as docs.gov.tools) and for `/govtool/` (as the GitHub Pages preview):

- **build**: a broken link fails the Docusaurus build. `scripts/check-images.mjs` then fails it when a page or stylesheet references an image, font or other asset that is not in the build, or, under `/govtool/`, uses a root path without `/govtool/`.
- **image**: builds the Docker image and starts it. `scripts/smoke-test-image.sh` checks the health check, pages, images, assets with their security and cache headers, the 404 page, and the redirect from `/` to the base path. A mistake in `nginx.conf.template` only shows when nginx starts, so this is where it fails.

Run the same checks locally with:

```sh
npm run build && node scripts/check-images.mjs build
DOCS_BASE_URL=/govtool/ npm run build && DOCS_BASE_URL=/govtool/ node scripts/check-images.mjs build
docker build -t govtool-docs:check . && scripts/smoke-test-image.sh govtool-docs:check /
docker build --build-arg DOCS_BASE_URL=/govtool/ -t govtool-docs:check . && scripts/smoke-test-image.sh govtool-docs:check /govtool/
```

## Preview (GitHub Pages)

`.github/workflows/deploy-docs-pages.yml` publishes a preview of the site, as on `develop`, to the repository's GitHub Pages on every push to `develop` that touches `docs/`, or when run by hand. It runs only on `IntersectMBO/govtool`, not on forks.

The preview is not the production site. It carries `noindex, nofollow` by default, so it does not compete with docs.gov.tools in search results, and GitHub Pages cannot send the security headers that the Docker image's nginx sets. docs.gov.tools is served by the Docker image built from `main` (see below).

One-time setup (a repository admin):

1. Settings → Pages → Build and deployment → Source: **GitHub Actions**.
2. Run the workflow (Actions → Deploy Docs Preview to GitHub Pages → Run workflow). The preview is published at `https://intersectmbo.github.io/govtool/`.

Optional repository variables (Settings → Secrets and variables → Actions → Variables):

| Variable | Default | Purpose |
| --- | --- | --- |
| `DOCS_PAGES_URL` | `https://<owner>.github.io` | Site origin |
| `DOCS_PAGES_BASE_URL` | `/<repo>/` | Path the site is served under |
| `DOCS_PAGES_NO_INDEX` | `true` | `false` lets search engines index the preview |

The same build settings work locally: `DOCS_URL`, `DOCS_BASE_URL` and `DOCS_NO_INDEX=true` are read by `docusaurus.config.js`. Raw HTML image paths from the GitBook export (`<img src="/img/...">`) get the base path from `src/remark/base-url-raw-html.js`, so the site also works under a sub-path.

## Deployment (Docker)

The site is packaged as a static nginx image (`Dockerfile`, `nginx.conf.template`). The container runs as a non-root user and listens on port `8080`, with a health check at `/healthz`.

### Build and publish the image

Build for `linux/amd64` (servers) even when building on an Apple Silicon Mac:

```sh
cd docs
docker buildx build --platform linux/amd64 \
  --build-arg DOCS_URL=https://docs.dev.gov.tools \
  -t ghcr.io/<owner>/govtool-docs:<tag> \
  --push .
```

Build arguments (fixed at build time):

| Argument | Default | Purpose |
| --- | --- | --- |
| `DOCS_URL` | `https://docs.gov.tools` | Public URL of the site (canonical links, Open Graph tags, sitemap) |
| `DOCS_BASE_URL` | `/` | Path the site is served under. Keep `/` for docs.gov.tools. With another path (e.g. `/govtool/`), the image serves the site under it and redirects `/` there |

Runtime environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `X_ROBOTS_TAG` | `all` | Value of the `X-Robots-Tag` header. Use `noindex, nofollow` on temporary hosts |

CI (`.github/workflows/build-docker-images.yml`) also builds and pushes `ghcr.io/intersectmbo/govtool-docs` on `main`, `develop`, `test` and version tags. Images from `main` and version tags are production and always build for `https://docs.gov.tools`. Images from `develop` and `test` use the `DOCS_SITE_URL` repository variable when set, so they can be built for a temporary host.

### Run on a server

`deploy/` contains a Compose file, an `.env.example` and an example host nginx server block:

```sh
cd deploy
cp .env.example .env        # set DOCS_IMAGE, DOCS_PORT, X_ROBOTS_TAG
docker compose up -d
curl -fsS http://127.0.0.1:8085/healthz
```

The container is published on `127.0.0.1` only. The host reverse proxy terminates TLS and forwards to it (see `deploy/nginx-host.conf.example`).

### Moving to docs.gov.tools

1. Rebuild the image with `DOCS_URL=https://docs.gov.tools` (the default).
2. Set `X_ROBOTS_TAG=all` and redeploy.
3. Point the `docs.gov.tools` DNS record at the server and add it to the host reverse proxy.
4. The GovTool frontend footer links to `/legal/privacy-policy` and `/legal/terms-of-use` on docs.gov.tools, so docs.gov.tools must serve this site before a frontend with that footer is released.

## Layout

| Path | Purpose |
| --- | --- |
| `docs/` | Markdown pages (URL = file path, `README.md` = section index) |
| `docs/developers/` | Developer documentation (hand-written, not touched by the migration script) |
| `api/`, `known-issues.md` | API and data-layer reference, read on GitHub (not part of the site) |
| `Dockerfile`, `nginx.conf.template`, `deploy/` | Docker image and server deployment files |
| `sidebars.js` | Sidebar tree: GitBook sections + developer documentation |
| `sidebars.gitbook.js` | GitBook part of the sidebar (originally generated from `SUMMARY.md`) |
| `static/img/gitbook/` | Images referenced by the pages |
| `src/css/custom.css` | Theme overrides and styles for GitBook-exported HTML (figures, embeds) |
| `scripts/gitbook-to-docusaurus.py` | One-off converter used for the migration (reference only) |

## Writing pages

Pages are plain Markdown (`.md`, parsed as CommonMark with inline HTML). Use `.mdx` if a page needs React components.
Callouts use Docusaurus admonitions:

```md
:::info
Text
:::
```

Supported types: `note`, `tip`, `info`, `warning`, `danger`.

After adding a page, add it to `sidebars.js`.

## Migration script

`scripts/gitbook-to-docusaurus.py` was used once to convert the GitBook export. The pages have been edited since then to match the current GovTool implementation, so **do not re-run it** on this folder: it would overwrite those edits. It is kept for reference only.

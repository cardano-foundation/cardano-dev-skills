---
title: Governance
description: Doc-update checklist, the auto-derived count mechanism, and the source maintenance bar.
---

Docs in this repo (`CLAUDE.md`, `README.md`, `docs/DESIGN.md`,
`docs/CONTRIBUTING.md`) must reflect current state. When you change
something **observable from outside the repo**, update related docs in the
same PR. Pure internal tweaks (refactor a script, fix a typo in a skill
body) don't trigger doc updates.

## Doc-update checklist

When you change something observable from outside the repo, update the docs that
describe it in the same PR. The authoritative change→docs matrix lives in
[`docs/CONTRIBUTING.md`](https://github.com/cardano-foundation/cardano-dev-skills/blob/main/docs/CONTRIBUTING.md#documentation-governance).

### When in doubt

Grep the repo for the thing you're changing — file name, count, label,
terminology. If it appears in any doc, update it.

## Auto-derived counts

`scripts/update-doc-counts.sh` rewrites count sentinels in `CLAUDE.md` and
`README.md` from disk state. Sentinels look like
`<!-- COUNT:skills -->15<!-- /COUNT:skills -->` and are invisible in
rendered output.

CI runs the script in `--check` mode on every PR — drift fails the build.
Run the script locally before pushing:

```bash
./scripts/update-doc-counts.sh
```

## Source-vetting bar

New sources must be actively maintained — recent commits, a release or activity
signal, no archival banner, and (for forks) the maintained canonical. The repo also
excludes branded dApps: it teaches building on Cardano, not how specific deployed
products work. The full, authoritative bar and scope policy live in
[`docs/CONTRIBUTING.md`](https://github.com/cardano-foundation/cardano-dev-skills/blob/main/docs/CONTRIBUTING.md).

## Refresh lifecycle

The weekly workflow (`.github/workflows/refresh-docs.yml`) runs every
Monday at 06:00 UTC, fetches all sources, and opens a PR labeled
`documentation, automated`. A maintainer reviews the diff and merges.

Manual refresh:

```bash
gh workflow run refresh-docs.yml          # remote
./scripts/fetch-docs.sh                   # local, all sources
./scripts/fetch-docs.sh --source "Name"   # local, one source
```

The fetch script writes `.manifest.yaml` derived from disk state — so
partial and full fetches both leave the manifest accurate.

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

| Change | Update these docs |
|---|---|
| New skill | README.md skills table; DESIGN.md if it changes the skill graph |
| New source in `registry/sources.yaml` | Run `scripts/update-doc-counts.sh`; CONTRIBUTING.md only if introducing a new category or format |
| New schema field | `registry/sources.yaml` header comment; CONTRIBUTING.md valid-values lists; DESIGN.md if architectural |
| New script in `scripts/` | README.md if user-facing |
| New hook in `hooks/` | README.md "How to set the Cardano context" section; CLAUDE.md repo structure |
| Removed/renamed file | All docs that reference it — grep first |

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

When adding to `registry/sources.yaml`, all must hold:

1. Last commit < 6 months old
2. ≥1 release tag OR active issue/PR activity in the last 3 months
3. No archived / deprecated / sunset banner
4. For forks: pick the maintained canonical (e.g. Evolution SDK is the live
   fork of dead Lucid Evolution)
5. **No branded dApps.** The repo teaches BUILDING on Cardano, not how
   specific deployed products work. Generic primitives (SDKs, frameworks,
   validator libraries, design patterns, infrastructure) are in scope.
   Product docs for specific dApps are not.

Full policy: see
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

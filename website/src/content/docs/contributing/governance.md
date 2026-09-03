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

## Source-vetting bar

New sources must be actively maintained — recent commits, no archival banner,
and (for forks) the maintained canonical. The repo also
excludes branded dApps: it teaches building on Cardano, not how specific deployed
products work. The full, authoritative bar and scope policy live in
[`docs/CONTRIBUTING.md`](https://github.com/cardano-foundation/cardano-dev-skills/blob/main/docs/CONTRIBUTING.md).

## Refresh lifecycle

The weekly workflow (`.github/workflows/refresh-docs.yml`) runs every
Monday at 06:00 UTC, fetches every source's upstream branch tip, and opens
a PR labeled `documentation, automated` with one commit per changed source
(doc files + that source's line in `registry/pins.yaml`), so a bad
upstream delta can be reverted per source. Outside the refresh,
`fetch-docs.sh` checks out each source's pinned commit — what ships is
exactly what passed screening. A maintainer merges when the security scan
is green and the AI docs-delta review raises nothing.

Manual refresh:

```bash
gh workflow run refresh-docs.yml          # remote
./scripts/fetch-docs.sh                   # local, all sources
./scripts/fetch-docs.sh --source "Name"   # local, one source
```

The fetch script writes `.manifest.yaml` derived from disk state — so
partial and full fetches both leave the manifest accurate.

## Supply-chain screening

Bundled docs are read by AI agents on consumers' machines, so every change
to `docs/sources/` is screened before merge:

1. **Fetch-time sanitization** — zero-width/bidi characters stripped from
   all text; HTML comments and `<script>` blocks stripped from markup, so
   instructions cannot hide invisibly in the corpus.
2. **Mechanical delta scanner** (blocking CI check) — changed lines are
   scanned for agent-targeted injection phrasing, pipe-to-shell installs,
   swapped bech32 addresses, changed install commands, and URLs on domains
   a source never used before.
3. **Advisory AI docs-delta review** — a non-agentic model call classifies
   each source's delta as plausible maintenance vs poisoning and posts a
   per-source verdict table on the PR.

Skills are covered separately: `scripts/validate.py` enforces the
tool-grant policy (read-only base grant, network tools disallowed) on
every skill PR. Full design: `docs/DESIGN.md` Decision 13.

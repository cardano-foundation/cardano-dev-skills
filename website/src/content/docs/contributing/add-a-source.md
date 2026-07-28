---
title: Add a source
description: How to propose a new documentation source — vetting bar, schema, validation, and local fetch test.
---

`registry/sources.yaml` is the single source of truth for documentation
sources. Adding an entry is straightforward once it clears the maintenance
bar.

## 1. Verify the maintenance bar

Before adding any new entry, verify the upstream repo is actively
maintained:

1. **Last commit < 6 months old**
2. **≥1 release tag OR active issue/PR activity in the last 3 months**
3. **No archived / deprecated / sunset banner** in README or repo settings
4. **For forks**, pick the maintained canonical (concrete example: Evolution
   SDK is the live fork of the dead Lucid Evolution — always prefer the
   live one)

If signals are ambiguous (e.g. low commit frequency but a stable mature
library; deprecation notice with unclear successor), flag it in the PR
rather than guess.

The same bar applies to the candidate entries at the bottom of
`registry/sources.yaml` — don't promote a candidate without re-vetting.

CI enforces this bar automatically: `scripts/check-pr-policy.py` vets every
new source entry live against the GitHub API (archived flag, last-push age,
release/activity signal) and fails the PR on a violation. An advisory AI
scope review also comments on PRs that add sources or skills, judging them
against the [scope policy](/contributing/scope/) — a maintainer always makes
the final call.

## 2. Edit `registry/sources.yaml`

```yaml
- name: Project Name
  repo: https://github.com/org/repo.git
  docs_path: docs                    # path within the repo containing docs
  format: markdown                   # see "Valid values" below
  category: infrastructure           # see "Valid values" below
  priority: medium                   # high, medium, low
  description: Short description of the project
  # Optional:
  # website: https://project.dev
  # branch: main
  # glob_patterns:
  #   - "**/*.md"
  # format_overrides:
  #   "**/*.yaml": openapi
```

**Valid `format` values:** `markdown`, `mdx`, `rst`, `openapi`, `aiken`,
`python`, `toml`

**Valid `category` values:** `infrastructure`, `smart-contracts`, `sdk`,
`standards`, `governance`, `scaling`, `testing`, `oracles`

If you need a new category or format, propose it in the PR — both are
checked by `scripts/validate.py` against an explicit allow-list.

## 3. Validate

```bash
python3 scripts/validate.py
```

## 4. Fetch and verify locally

```bash
./scripts/fetch-docs.sh --source "Project Name"
```

Check that files were actually pulled (`docs/sources/<slug>/`) and that the
count looks right.

## 5. Open a PR

CI runs validation automatically. The weekly refresh workflow picks up the
new source on its next Monday run.

If you'd rather just nominate a source without writing the YAML, use the
[**Suggest a source**](https://github.com/cardano-foundation/cardano-dev-skills/issues/new?template=suggest-source.yml)
issue template — a maintainer will add it if it passes the bar.

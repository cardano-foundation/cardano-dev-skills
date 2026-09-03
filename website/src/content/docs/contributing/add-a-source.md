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
2. **≥1 release tag OR issue/PR activity OR a push in the last 3 months**
3. **No archived / deprecated / sunset banner** in README or repo settings
4. **For forks**, pick the maintained canonical (concrete example: Evolution
   SDK is the live fork of the dead Lucid Evolution — always prefer the
   live one)

If signals are ambiguous (e.g. low commit frequency but a stable mature
library; deprecation notice with unclear successor), flag it in the PR
rather than guess.

Rules 1–2 measure maintenance cadence, which is meaningless for a repo whose
only job is to mirror a document that changes rarely by design (e.g. the
Cardano Constitution, amended only by on-chain governance action). Waiving them
for such a document-of-record source takes two things in the same PR, and both
are required: the registry entry carries a `vetting_exception` reason string
saying why cadence is uninformative and what does guarantee currency, **and**
the source is granted the waiver in `VETTING_EXCEPTIONS` in
`scripts/validate.py`, mapped to the repo it was granted for. An entry carrying
the field without a matching grant fails the `validate` check. With both in
place the policy check waives rules 1–2 for it (rules 3–4 still apply) and
surfaces the waiver as a warning in the PR check output.

The grant is what keeps the waiver a decision rather than a default: a reason
string alone is self-service, while naming the source in the script makes
granting one a code change a maintainer reviews alongside the source it covers
— the same shape as `ALLOWED_TOOLS_EXCEPTIONS` in the same file. Recording the
repo too means repointing a waived entry at a different upstream re-enters
vetting rather than inheriting the waiver.

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
`python`, `toml`, `go`

`python` and `go` mirror source files instead of prose, so the API reference
comes from docstrings and doc comments. Scope `glob_patterns` to the importable
public surface — Go's `internal/` can't be imported by consumers and `cmd/`
holds CLI entry points, so neither belongs in a mirror. Test files are dropped
automatically. Never mirror an upstream `AGENTS.md` or `CLAUDE.md`: bundled docs
are read by agents, so upstream agent instructions are an injection vector.

**Valid `category` values:** `infrastructure`, `smart-contracts`, `sdk`,
`standards`, `governance`, `scaling`, `testing`, `oracles`

If you need a new category or format, propose it in the PR — both are
checked by `scripts/validate.py` against an explicit allow-list.

## 3. Fetch and pin locally

```bash
./scripts/fetch-docs.sh --source "Project Name" --update-pins
```

Check that files were actually pulled (`docs/sources/<slug>/`) and that the
count looks right.

`--update-pins` records the upstream commit in `registry/pins.yaml`, and a new
source is pinned in the PR that registers it. The pin is the only record of
which upstream commit the mirrored content came from; without one the source
re-resolves to whatever the branch tip is at fetch time. Despite the
"auto-generated" banner, `--update-pins` merges into the file rather than
rewriting it, so a per-source run touches one line.
`validate.py` fails a registered source that has no pin.

## 4. Validate

```bash
python3 scripts/validate.py
```

## 5. Open a PR

CI runs validation automatically. The weekly refresh workflow picks up the
new source on its next Monday run.

If you'd rather just nominate a source without writing the YAML, use the
[**Suggest a source**](https://github.com/cardano-foundation/cardano-dev-skills/issues/new?template=suggest-source.yml)
issue template — a maintainer will add it if it passes the bar.

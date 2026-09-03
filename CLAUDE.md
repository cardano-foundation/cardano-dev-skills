# Cardano Dev Skills

Community-curated knowledge base for building on Cardano. This repo is a Claude Code plugin and Codex-compatible skill set.

## Repo Structure

- `registry/sources.yaml` — canonical list of Cardano projects and their documentation sources
- `registry/pins.yaml` — auto-generated upstream commit pins (each source fetches its last-vetted commit, not the branch tip)
- `skills/` — developer skills (flat layout — each skill is `skills/<name>/SKILL.md`)
- `scripts/` — validation, fetch, sync, and scaffolding tooling
- `hooks/` — session-level hooks (freshness check; prompt-time context injection planned)
- `docs/DESIGN.md` — architectural decisions
- `docs/CONTRIBUTING.md` — how to add sources, skills, refresh content, and the source-vetting policy

## Commands

| Purpose | Command | Needs |
|---|---|---|
| Validate skills + sources (the CI gate) | `python3 scripts/validate.py` | `pyyaml` |
| Path-portability check alone | `python3 scripts/validate.py --paths-only` | nothing |
| Test the SessionStart hook | `./hooks/test-check-docs.sh` | nothing |
| Fetch one source after editing its registry entry | `./scripts/fetch-docs.sh --source "Project Name" --update-pins` | `python3`, git |
| Build the site | `cd website && npm ci && npm run build` | Node ≥18.17 |
| PR policy gate (source vetting, skill naming) | `GITHUB_TOKEN=$(gh auth token) python3 scripts/check-pr-policy.py --base origin/main --head HEAD` | `pyyaml` |
| Supply-chain scan of a docs delta | `python3 scripts/scan-docs-delta.py --base origin/main --head HEAD` | nothing |

Every script runs on Python 3.9+, the version stock macOS ships; CI pins 3.12 for the
main job and runs `--paths-only` on 3.9. `pip install pyyaml` is the only Python
prerequisite anywhere, and `validate.py` says so when the module is missing. The token
on the policy row is optional — it only raises the GitHub API rate limit.

There is no linter. `validate.py` is the gate CI runs on every PR touching
`skills/`, `registry/`, `scripts/`, `docs/` or `hooks/`.

`scripts/fetch-docs.sh` with no `--source` and `scripts/sync-sources.sh` hit the
network and rewrite the whole vendored corpus. Never run them as a side effect of
unrelated work.

## Documentation Sources

The `docs/sources/` directory contains documentation extracted from the Cardano projects listed in `registry/sources.yaml`.
When a skill or user needs to look up SDK APIs, CIP specs, or tool docs, search here first:

```
docs/sources/aiken/                         # Aiken language docs
docs/sources/mesh-sdk/                      # Mesh SDK API docs
docs/sources/evolution-sdk/                 # Evolution SDK docs
docs/sources/cips/                          # All CIP proposals
docs/sources/ogmios/                        # Ogmios WebSocket bridge
docs/sources/cardano-use-case-templates/    # Foundation use-case templates
...
```

Use `Read` and `Grep` tools to search these directories for accurate, up-to-date information.

## Conventions

- Skills follow the Agent Skills standard: SKILL.md with YAML frontmatter
- SKILL.md files must be under 500 lines; deep content goes in `references/` (one level deep only)
- Skill names are kebab-case, max 64 characters; directory name matches `name:` field
- `registry/sources.yaml` is the single source of truth for documentation sources
- Skills are self-contained — work with `Read` / `Grep` / `Glob` only, no external service dependencies. The one exception is `give-feedback`, which files a GitHub issue via `gh` after the user approves the draft; see DESIGN.md Decision 14 for why that boundary is drawn where it is
- When referencing documentation, guide the user to search or read rather than pasting specs

## Skill Format

```yaml
---
name: skill-name
description: >-
  What this skill does. Include trigger phrases.
allowed-tools: Read Grep Glob
disallowed-tools: WebFetch WebSearch
---
```

Required sections: When to use, When NOT to use, Key principles, Workflow.

## Quality Standards

- Behavioral guidance over reference dumps
- Explain WHY, not just WHAT
- Include trade-offs and decision criteria
- Prescriptiveness scales with risk (strict for security, flexible for exploration)
- No hardcoded paths — use relative references
- Every doc is a living artifact: rewrite it to read as a clean one-shot final version.
  No changelogs, no "correction to an earlier note", no "previously this said" callouts,
  no narration of what changed. Git tracks the history. (Documenting that *external*
  guidance is stale — a deprecated API, an archived repo — is content, not a changelog.)

## Documentation Governance

Docs must reflect current state. When you change something **observable from outside this repo**, update related docs in the same PR. "Observable" means counts, capabilities, structure, interfaces, file lists, or workflows. Pure internal tweaks (refactor a script, fix a typo in a skill body) don't trigger doc updates.

### What to update for each change type

The canonical change→docs matrix lives in `docs/CONTRIBUTING.md` (§Documentation
governance) — consult it whenever a change is externally observable (per the rule above)
to see which docs to update in the same PR.

### Source-vetting bar

Before adding to `registry/sources.yaml`, meet the maintenance bar in `docs/CONTRIBUTING.md`
(commit recency, release/activity signal, no archival banner, fork canonicality) and the
two-part scope test (Cardano-native + developer-integration surface). That doc is
canonical — don't restate the bar here.

### When in doubt

Grep the repo for the thing you're changing — file name, count, label, terminology. If it appears in any doc, update it.
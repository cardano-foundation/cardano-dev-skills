# Cardano Dev Skills

Community-curated knowledge base for building on Cardano. This repo is a Claude Code plugin and Codex-compatible skill set.

## Repo Structure

- `registry/sources.yaml` — canonical list of Cardano projects and their documentation sources
- `skills/` — <!-- COUNT:skills -->15<!-- /COUNT:skills --> developer skills (flat layout — each skill is `skills/<name>/SKILL.md`)
- `scripts/` — validation, fetch, sync, and scaffolding tooling
- `hooks/` — session-level hooks (freshness check; prompt-time context injection planned)
- `docs/DESIGN.md` — architectural decisions
- `docs/CONTRIBUTING.md` — how to add sources, skills, refresh content, and the source-vetting policy

## Documentation Sources

The `docs/sources/` directory contains documentation extracted from <!-- COUNT:sources -->55<!-- /COUNT:sources --> Cardano projects.
When a skill or user needs to look up SDK APIs, CIP specs, or tool docs, search here first:

```
docs/sources/aiken/                         # Aiken language docs
docs/sources/mesh-sdk/                      # Mesh SDK API docs
docs/sources/evolution-sdk/                 # Evolution SDK docs
docs/sources/cips/                          # All CIP proposals
docs/sources/ogmios/                        # Ogmios WebSocket bridge
docs/sources/cardano-use-case-templates/    # 21 Foundation use-case templates
...
```

Use `Read` and `Grep` tools to search these directories for accurate, up-to-date information.

## Conventions

- Skills follow the Agent Skills standard: SKILL.md with YAML frontmatter
- SKILL.md files must be under 500 lines; deep content goes in `references/` (one level deep only)
- Skill names are kebab-case, max 64 characters; directory name matches `name:` field
- `registry/sources.yaml` is the single source of truth for documentation sources
- Skills are self-contained — work with `Read` / `Grep` / `Glob` only, no external service dependencies
- When referencing documentation, guide the user to search or read rather than pasting specs

## Skill Format

```yaml
---
name: skill-name
description: >-
  What this skill does. Include trigger phrases.
allowed-tools: Read Grep Glob
---
```

Required sections: When to use, When NOT to use, Key principles, Workflow.

## Quality Standards

- Behavioral guidance over reference dumps
- Explain WHY, not just WHAT
- Include trade-offs and decision criteria
- Prescriptiveness scales with risk (strict for security, flexible for exploration)
- No hardcoded paths — use relative references

## Documentation Governance

Docs must reflect current state. When you change something **observable from outside this repo**, update related docs in the same PR. "Observable" means counts, capabilities, structure, interfaces, file lists, or workflows. Pure internal tweaks (refactor a script, fix a typo in a skill body) don't trigger doc updates.

### What to update for each change type

The canonical change→docs matrix lives in `docs/CONTRIBUTING.md` (§Documentation
governance) — consult it whenever a change is externally observable (per the rule above)
to see which docs to update in the same PR.

### Auto-derived counts

`scripts/update-doc-counts.sh` rewrites count sentinels in CLAUDE.md and README.md from disk state. Sentinels look like `<!-- COUNT:skills -->15<!-- /COUNT:skills -->` and are invisible in rendered output. CI runs the script in `--check` mode on every PR — drift fails the build. Run the script locally before pushing.

### Source-vetting bar

Before adding to `registry/sources.yaml`, meet the maintenance bar in `docs/CONTRIBUTING.md`
(commit recency, release/activity signal, no archival banner, fork canonicality) and the
two-part scope test (Cardano-native + developer-integration surface). That doc is
canonical — don't restate the bar here.

### When in doubt

Grep the repo for the thing you're changing — file name, count, label, terminology. If it appears in any doc, update it.
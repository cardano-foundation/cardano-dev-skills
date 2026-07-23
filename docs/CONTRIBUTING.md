# Contributing to Cardano Dev Skills

This guide covers source vetting, adding sources, adding skills, refresh, documentation governance, and quality standards.

## Scope: what belongs in this repo

This repo teaches **building on Cardano**. It is a generic knowledge base for AI coding agents and developers.

The repo has two layers with different rules:

- **Sources** (`registry/sources.yaml` → `docs/sources/`) are mirrored upstream documentation: the project's own words, vetted for relevance and maintenance, kept current by the weekly refresh.
- **Skills** (`skills/`) are authored by this repo's maintainers: task-oriented behavioral guidance. Skills are never project-specific — projects are documented as sources and taught through task skills.

### Source scope: the two-part test

A source qualifies only if it passes **both** gates:

1. **Cardano-native.** The project's on-chain footprint is on Cardano — contracts deployed there, or specs/standards targeting it. Multichain projects qualify only if Cardano is a first-class supported chain, and only the Cardano-relevant part of their docs is mirrored (use `glob_patterns`). We don't list AI platforms operating on other chains, or oracles that don't operate on Cardano — however established they are.
2. **Developer-integration surface.** The docs must document something a developer building on Cardano integrates with or builds on: contracts, APIs, SDKs, protocol specs, a runnable node or service. An *integration-first* project (an oracle, a payment protocol, an indexer) qualifies even though it is a branded, for-profit product — its business only exists if developers integrate it, so its docs are developer material. An end-product user manual (how to swap on a DEX frontend, how to browse an NFT marketplace site) does not qualify; the same project's protocol or contract specs can qualify even when its end-product docs don't.

Always out of scope regardless: closed-source content; marketing-only material.

In-scope examples: SDKs, frameworks, validator libraries, design patterns, language tooling; infrastructure (nodes, indexers, chain providers); protocol and standard specs (CIPs, ledger specs); reference implementations of *patterns*; generic dApp categories (DEX, lending, NFT marketplace, oracle consumer, governance tool).

### Skill scope

Skills are this repo's editorial voice and are held to a **stricter bar than sources**:

- **No project-specific or brand-named skills, ever.** Skills map to developer workflows (see DESIGN.md Decision 2) — `query-chain`, not the name of a chain provider. This is stricter than the source rules on purpose: a skill is behavioral instruction an agent follows (tool use, workflow steps, decision criteria), so a harmful or stale skill can do more damage than a harmful doc. Vendor-maintained skills copied here inevitably drift from their canonical home. Vendors who maintain their own installable skill should document it in their own docs — once those docs are a registered source, agents and users discover the skill there, always via the refreshed pointer.
- **A skill that teaches integrating with a specific project requires that project to be a registered source.** Spec-level detail (endpoints, request bodies, datum schemas) belongs in `docs/sources/`, where the weekly refresh keeps it current; a skill's `references/` directory is for behavioral guidance, not pasted specs.

If you're unsure whether something fits, open a discussion before writing code.

## Source-vetting policy

Before adding any new entry to `registry/sources.yaml`, verify the upstream repo is actively maintained:

1. **Last commit < 6 months old**
2. **≥1 release tag OR active issue/PR activity in the last 3 months**
3. **No archived / deprecated / sunset banner** in README or repo settings
4. **For forks**, pick the maintained canonical (concrete example: Evolution SDK is the live fork of dead Lucid Evolution — always prefer the live one)

If signals are ambiguous (e.g. low commit frequency but a stable mature library; deprecation notice with unclear successor), flag it in the PR rather than guess.

The same bar applies to the candidate entries at the bottom of `registry/sources.yaml` — don't promote a candidate without re-vetting against this bar.

## Automated PR policy checks

PRs that touch `skills/`, `registry/`, or `docs/sources/` run `.github/workflows/pr-policy.yml`, which has two layers:

1. **Mechanical checks** (`scripts/check-pr-policy.py`, hard-fails CI): new sources are vetted live against the GitHub API (archived flag, last-push age, release/activity signal, fork warning); new skills fail if named after a project/brand (they must be task-oriented) or if they reference a `docs/sources/<x>/` directory the PR doesn't provide; new bundled doc files that look like marketing pages or duplicate generic Cardano-101 content produce warnings.
2. **AI scope review** (advisory, never fails CI): when a PR adds a source or skill, a model judges it against the scope policy above — including the borderline rule — and posts a review comment with a verdict and concrete requested changes. The rubric lives in `.github/scope-review-prompt.md`. It runs on GitHub Models with the built-in `GITHUB_TOKEN`; no API key or secret is configured. The comment is advisory: a maintainer always makes the final call.

Run the mechanical layer locally before opening a PR:

```bash
python3 scripts/check-pr-policy.py            # compares HEAD against origin/main
```

If a check misfires (e.g. a legitimately-named skill trips the brand heuristic), say so in the PR description — the maintainer can merge over a failing policy check.

## Adding a new documentation source

### 1. Verify against the vetting policy above

### 2. Edit `registry/sources.yaml`

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

**Valid `format` values:** `markdown`, `mdx`, `rst`, `openapi`, `aiken`, `python`, `toml`

**Valid `category` values:** `infrastructure`, `smart-contracts`, `sdk`, `standards`, `governance`, `scaling`, `testing`, `oracles`

If you need a new category or format, propose it in the PR — both are checked by `scripts/validate.py` against an explicit allow-list.

### 3. Validate

```bash
python3 scripts/validate.py
```

### 4. Fetch and verify locally

```bash
./scripts/fetch-docs.sh --source "Project Name"
```

Check that files were actually pulled (`docs/sources/<slug>/`) and that the count looks right.

### 5. Open a PR

CI runs validation automatically. The weekly refresh workflow picks up the new source on its next Monday run.

## Adding a new skill

Skills live flat under `skills/<name>/SKILL.md`. No category subdirectories.

### 1. Scaffold

```bash
./scripts/new-skill.sh my-new-skill
```

This creates:

```
skills/my-new-skill/
├── SKILL.md          # template
└── references/       # deeper content (one level only)
```

### 2. Write the SKILL.md

```yaml
---
name: my-new-skill
description: >-
  What this skill does. Include 3-5 trigger phrases users would say.
allowed-tools: Read Grep Glob
---

# my-new-skill

## When to use
- Specific scenario 1
- Specific scenario 2

## When NOT to use
- Wrong scenario (redirect to correct skill)

## Key principles
- Domain-specific principle 1
- Domain-specific principle 2

## Workflow

### Step 1: Name
Instructions...

### Step 2: Name
Instructions...

## References
- See [reference-name](references/file.md) for details
```

### 3. Quality checklist

- [ ] SKILL.md under 500 lines
- [ ] Name is kebab-case, max 64 chars
- [ ] `name:` matches directory name
- [ ] Description includes trigger phrases
- [ ] Has "When to use", "When NOT to use", "Key principles", "Workflow" sections
- [ ] No external service dependencies — works with `Read` / `Grep` / `Glob` only
- [ ] Deep content in `references/`, one level only — no nested subdirectories
- [ ] No mention of specific deployed dApps; teach categories generically
- [ ] No mention of grants, treasuries, or governance proposals — the skill must read as a neutral community contribution

### 4. Validate and submit

```bash
python3 scripts/validate.py
./scripts/update-doc-counts.sh    # refresh counts in README/CLAUDE
```

Open a PR. CI runs validation + count-drift check.

## Verifying executable claims

When a change touches runnable content (validator code, CLI commands, ports, version pins),
verify it by running it, not just by cross-referencing docs. Note the bundled `docs/sources/`
mirror each project's upstream default branch, so check version-sensitive claims against
released packages (npm dist-tags, Maven metadata, GitHub releases), not the mirrored docs.

## Documentation governance

Docs (`CLAUDE.md`, `README.md`, `docs/DESIGN.md`, `docs/CONTRIBUTING.md`) must reflect current state. When you change something **observable from outside the repo**, update related docs in the same PR.

### What to update for each change type

| Change | Update these docs |
|---|---|
| New skill | README.md skills table; DESIGN.md if it changes the skill graph. Pages site skills catalog auto-regenerates on build. |
| New source | Run `scripts/update-doc-counts.sh`; CONTRIBUTING.md only if introducing a new category or format. Pages site sources catalog auto-regenerates on build. |
| New schema field | `registry/sources.yaml` header comment; CONTRIBUTING.md valid-values lists; DESIGN.md if architectural |
| New script in `scripts/` | README.md if user-facing |
| New hook | README.md "How to set the Cardano context" section; CLAUDE.md repo structure; `website/src/content/docs/how-it-works.md` |
| Scope / vetting / governance policy change | CLAUDE.md; CONTRIBUTING.md; `website/src/content/docs/contributing/` pages |
| Vision / "why" change | README.md; `website/src/content/docs/about/why.md` |
| Install flow change | README.md install section; `website/src/content/docs/getting-started.md` |
| Roadmap change | `website/src/content/docs/about/roadmap.md` |
| Removed/renamed file | All docs that reference it — grep first |

Pure internal tweaks (refactor a script, fix a typo in a skill body) don't trigger doc updates.

### Auto-derived counts

`scripts/update-doc-counts.sh` rewrites sentinels in CLAUDE.md and README.md from disk state. Sentinels look like `<!-- COUNT:skills -->15<!-- /COUNT:skills -->`. Run before pushing — CI runs `--check` and fails PRs on drift.

## Refreshing content

The weekly workflow (`.github/workflows/refresh-docs.yml`) runs every Monday at 06:00 UTC, fetches all sources, and opens a PR labeled `documentation, automated`. Review the diff and merge.

To trigger manually:

```bash
gh workflow run refresh-docs.yml
```

To refresh locally:

```bash
./scripts/fetch-docs.sh                          # all sources
./scripts/fetch-docs.sh --source "Source Name"   # one source
```

### When to refresh out of band

- Major SDK release changes APIs (e.g. Mesh v2, Evolution SDK breaking changes)
- New CIPs ratified that affect developer workflows
- New vulnerability patterns discovered
- A referenced tool is deprecated or replaced — drop the source AND update relevant skills

## Future automation (tracked, not yet built)

The planned automation is listed on the [roadmap](../website/src/content/docs/about/roadmap.md);
the rationale for each item is in [DESIGN.md Decision 9](DESIGN.md).

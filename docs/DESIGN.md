# Design Decisions

This document captures the architectural decisions behind `cardano-dev-skills`. It records what was decided, why, and what alternatives were considered.

## Decision 1: Content-only repository

**Decision:** This repository ships content (YAML, Markdown, shell hooks) — no application code, no servers, no runtime dependencies users have to install.

**Why:**
- **Security.** Pure content is auditable by anyone. Users installing the plugin don't execute arbitrary TypeScript or Python from this repo.
- **Lower contribution barrier.** A Cardano developer can add a skill or source without learning a build system, a framework, or a deployment pipeline.
- **Decoupled from any specific consumer.** Multiple agents and tools can read this content: Claude Code (as a plugin), Codex (via symlink), any agent that reads Markdown, or external indexers. The repo doesn't assume which one is using it.

**Alternative considered:** Bundling content with an indexing/serving runtime. Rejected because it couples content updates to runtime releases and shrinks the set of tools that can consume the content.

## Decision 2: Skills organized by developer workflow (flat directory layout)

**Decision:** Skills live flat under `skills/<name>/SKILL.md`. Logical categorization is conveyed by skill names and descriptions, not by directory structure.

**Why:** Developers think in terms of "what am I trying to do?" not "what category is this tool in?" A developer building an NFT marketplace needs `write-validator` + `build-transaction` + `connect-wallet` — these map to workflows, not to the registry's source categories. Flat layout also matches the Claude Code plugin discovery contract, which expects `skills/<name>/SKILL.md` and doesn't traverse arbitrary nesting.

**Alternative considered:** Mirror the registry's source categories (infrastructure, smart-contracts, sdk, standards, governance, scaling, testing, oracles) as subdirectories. Rejected because skills like `build-transaction` span multiple categories, and the plugin discovery contract doesn't require it.

## Decision 3: YAML registry, not TypeScript

**Decision:** The canonical source list is `registry/sources.yaml`, not a TypeScript file.

**Why:** Lower contribution barrier. A Cardano developer who wants to add a new project doesn't need to know TypeScript, Python, or any specific consumer's type system. YAML is universally readable and editable. Any downstream tool that needs typed access can generate types from the YAML on its own side.

## Decision 4: Skills are self-contained

**Decision:** Skills must work using only `Read`, `Grep`, and `Glob`. No external service dependencies, no proprietary tool calls.

**Why:**
- Skills should produce useful guidance regardless of what other tools the user has connected.
- Skills that depend on a specific MCP server, API, or service break for any user who hasn't installed that specific thing.
- The bundled corpus under `docs/sources/` is the authoritative reference — `Grep` and `Read` are sufficient to find and consume it.

**How it works:** Every SKILL.md declares `allowed-tools: Read Grep Glob`. The agent searches local documentation, the user's codebase, or its own knowledge. If a user has additional tools or MCP servers connected, the agent can use them on its own initiative, but the skill never depends on it.

## Decision 5: Progressive disclosure

**Decision:** SKILL.md files are capped at 500 lines. Deep reference content goes in `references/` subdirectories, one level deep only.

**Why:**
- **Context budget.** At session start, Claude loads only the name + description of each skill (~100 tokens per skill). When a skill activates, the full SKILL.md loads (~2,000 tokens). References load only on demand. This keeps context usage manageable.
- **Maintainability.** A 500-line file is reviewable in a single PR. A 2,000-line file is not.
- **Trail of Bits pattern.** Their production skills follow this exact structure and it works at scale (35+ plugins, 100+ skills).

## Decision 6: Agent Skills standard compliance

**Decision:** Follow the Agent Skills open standard for SKILL.md format — YAML frontmatter with `name`, `description`, `allowed-tools`, and structured markdown body.

**Why:**
- Compatible with Claude Code plugins (`.claude-plugin/` + `skills/`)
- Compatible with Codex (`.agents/skills/` symlink)
- Future-proof for other tools that adopt the standard
- Established quality standards (naming conventions, description requirements, section structure)

**Cross-tool compatibility:** Symlinks handle multi-tool support without file duplication:
- `.claude/skills` → `../skills` (Claude Code project-level discovery)
- `.agents/skills` → `../skills` (Codex discovery)
- Plugin installation (`/plugin add`) uses `skills/` directly

## Decision 7: One-way flow to any consumer

**Decision:** This repo is the canonical source. Any downstream tool (an MCP server, a search index, a static-site renderer, etc.) reads from it but never writes back.

**Why:** Eliminates drift. There is exactly one place to update a source entry or a skill's workflow. Consumers are responsible for their own ingestion / sync — they pull, this repo doesn't push to them. Multiple consumers can co-exist without coupling.

## Decision 8: Skill content is authored, not extracted

**Decision:** Skill content is written by humans (or AI-assisted), not derived from retrieval indices, embeddings, or chunked corpora.

**Why:**
- Retrieval chunks are optimized for similarity search, not for teaching. They're fragments, not workflows.
- Skills need behavioral guidance ("when to use X over Y", "check for Z before doing W") that doesn't exist in raw documentation.
- Authored content can encode trade-offs, decision criteria, and "what not to do" — none of which appear in source docs.

## Decision 9: Lifecycle automation shipped incrementally

**Decision:** Automate the refresh lifecycle in small, reviewable steps rather than building a single big system.

**Shipped:**
- **Weekly upstream refresh** (`.github/workflows/refresh-docs.yml`) — every Monday 06:00 UTC, fetches all sources, opens a PR with the diff. Human review + merge before content lands on `main`.
- **Schema validation** (`.github/workflows/validate.yml`) — runs on every PR touching `skills/**` or `registry/**`.
- **Manifest self-healing** — `scripts/_fetch_docs.py` derives `.manifest.yaml` from disk state after every fetch (partial or full), so the manifest can't drift.
- **Doc-count auto-derivation** — `scripts/update-doc-counts.sh` rewrites sentinels in CLAUDE.md and README.md from disk state. CI runs `--check` to fail PRs on drift.

**Planned (tracked, not built):**
- `UserPromptSubmit` hook that auto-injects "consult bundled docs first" guidance on Cardano-keyword-matched prompts, with local usage telemetry under `~/.cardano-dev-skills/usage.log`.
- PR-time source-build check: when `registry/sources.yaml` changes, CI fetches the touched source(s) and verifies the clone + glob patterns produce files.
- AI-powered governance review on PRs touching `registry/`, `skills/`, `hooks/`, or `scripts/` — Claude reads the diff and the rules from CONTRIBUTING.md, posts a verdict comment (advisory, not blocking).

These additions follow the principle: ship small, observe, iterate.

## Decision 10: Documentation governance

**Decision:** Docs in this repo (CLAUDE.md, README.md, DESIGN.md, CONTRIBUTING.md) must reflect current state. Externally-observable changes (counts, capabilities, structure, interfaces) require a doc update in the same PR. Internal tweaks (refactors, typo fixes) do not.

**Why:** Stale READMEs are the most common rot in tooling repos. They mislead new contributors, make the project look abandoned, and damage credibility — particularly when the goal is broader adoption.

**Mechanism (two layers):**

1. **Auto-derived counts** for the most rot-prone numbers (skill count, source count). Inline HTML-comment sentinels (`<!-- COUNT:skills -->14<!-- /COUNT:skills -->`) are rewritten by `scripts/update-doc-counts.sh`. CI runs `--check` on every PR.
2. **Per-change-type checklist** in `CLAUDE.md` mapping change types (new skill, new source, new schema field, new script, new hook) to the docs that must be updated. Enforced by reviewer judgement and (planned) AI governance review.

**Alternative considered:** Generate the entire README from a template + computed values. Rejected because narrative sections ("Why this exists", "How to set the Cardano context") need human prose, and a template-only approach makes those harder to evolve.

## Decision 11: Hook strategy

**Decision:** Use Claude Code's hook surface for *unconditional, low-information signals* — doc-freshness checks, project-context detection, install-topology-aware refresh hints. Reserve behavioral directives (telling Claude how to consult the skill set on every prompt) for `CLAUDE.md` content installed by the `cardano-context` meta-skill (see Decision 12).

**Shipped:**
- `SessionStart` (`hooks/check-docs.sh`):
  - Reports doc-corpus freshness on every session start.
  - Detects the `cardano-dev-skills` directive block in cwd `CLAUDE.md` and prints either a confirmation or a `/cardano-context` nudge.
  - Differentiates refresh hints by install topology (local clone vs marketplace cache).
  - Opportunistic behind-upstream check via `FETCH_HEAD` (no network on session start).

**Considered and rejected:** A `UserPromptSubmit` hook that keyword-matches Cardano terms and injects an `additionalContext` reminder. Description in Decision 12 of why a meta-skill writing to `CLAUDE.md` is structurally better than a per-prompt regex.

**Deferred:** Local usage observability (`PostToolUse` logging of which bundled docs/skills get consulted per session, backed by `scripts/usage-report.sh`). Useful for tuning skill descriptions and surfacing unmatched prompts; orthogonal to the consultation-directive problem solved by `cardano-context`.

**Why hooks for the shipped piece:** The freshness check produces *information*, not behavior — `SessionStart` is the right surface (no user invocation, plain-text output about plugin state). Hooks should not mutate prompts or inject behavioral directives — that role belongs to `CLAUDE.md` content, durably installed per-project by `cardano-context`.

## Decision 12: Meta-skills as an exception to workflow taxonomy

**Decision:** Most skills encode a developer *workflow* (write a validator, build a transaction, debug a failing tx). One skill — `cardano-context` — is a **meta-skill**: its only job is to configure Claude's behavior in the user's project by writing a delimited, versioned directive block to `CLAUDE.md`. It produces no Cardano output and teaches no Cardano concept; it exists purely to ensure the workflow skills and bundled corpus get consulted.

**Why a meta-skill is needed at all:** Description-based skill auto-matching is unreliable. Even with the plugin installed globally, Claude often answers Cardano questions from training data because (a) skill descriptions don't fire on every relevant phrasing, and (b) Claude's confidence can override the soft "check if a skill matches" prompt — particularly for prompts where it *feels* sure (and silently uses a deprecated SDK name or pre-Conway governance model). A durable per-project directive in `CLAUDE.md` hardens the prior: re-injected every conversation turn, survives compaction, distributes to teammates via git.

**Why this is an exception to Decision 2:** Decision 2 categorizes skills by developer workflow. `cardano-context` doesn't fit — its "workflow" is one-time project setup, not Cardano development. Treating it as just another workflow skill obscures its purpose and its different invocation pattern (run explicitly once per project; not auto-matched on related developer prompts).

**How to recognize a meta-skill:** It modifies the user's *environment* (`CLAUDE.md`, settings, project files) rather than producing Cardano code, advice, or analysis. Meta-skills:
- Are run explicitly by the user, typically once per project.
- Are idempotent on re-run; updates are versioned and atomic.
- Distribute their effect via git (committed file) rather than per-session state.

**Alternative considered:** A `UserPromptSubmit` hook that keyword-matches Cardano terms and injects a consultation reminder. Rejected because (a) regex on user prompts has no context — false positives ("compare Hydra vs Lightning") and false negatives (paraphrased Cardano questions) are both common, (b) injected `additionalContext` reminders get dropped by compaction; `CLAUDE.md` content is re-injected every turn, (c) hidden hook behavior is hard to debug or override per-project; `CLAUDE.md` is inspectable and editable, (d) the skill approach distributes via git, so teammates inherit the directive on clone without configuring their plugin install.

**Future meta-skills:** Likely candidates if the pattern stays useful — a deprecation/anti-pattern cheatsheet, project-level Cardano coding conventions. All would follow the same shape: produce a delimited versioned block, write to a project file, idempotent on re-run.

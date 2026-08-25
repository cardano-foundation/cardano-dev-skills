# Design Decisions

This document captures the architectural decisions behind `cardano-dev-skills`. It records what was decided, why, and what alternatives were considered.

## Decision 1: Content-only repository

**Decision:** This repository ships content (YAML, Markdown, shell hooks) — no application code, no servers, no runtime dependencies users have to install.

**Why:**
- **Security.** Pure content is auditable by anyone. Users installing the plugin don't execute arbitrary TypeScript or Python from this repo.
- **Lower contribution barrier.** A Cardano developer can add a skill or source without learning a build system, a framework, or a deployment pipeline.
- **Decoupled from any specific consumer.** Multiple agents and tools can read this content: Claude Code (as a plugin), Codex (via symlink), any agent that reads Markdown, or external indexers. The repo doesn't assume which one is using it.

**Source-mirroring formats.** Some sources are documented in their own source files rather than in prose, so the `format` allow-list in `scripts/validate.py` admits `python`, `aiken`, and `go` alongside the markup formats: Python docstrings and Go doc comments sit on the identifiers they describe, which makes the source the API reference. Mirrored code is inert reference text — read by agents, never executed, and never built (generating `go doc` output would put a language toolchain and module downloads in the fetch path, which Decision 13's posture rules out). Because a repository's source tree is much larger than its public API, these formats carry per-source `glob_patterns` scoped to the importable surface, and `scripts/_fetch_docs.py` drops test files and `testdata/` fixtures.

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

**Decision:** Follow the Agent Skills open standard for SKILL.md format — YAML frontmatter with `name`, `description`, `allowed-tools`, `disallowed-tools`, and structured markdown body.

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
- **PR policy gate** (`.github/workflows/pr-policy.yml`) — on PRs touching `skills/`, `registry/`, or `docs/sources/`: mechanical checks (`scripts/check-pr-policy.py`, hard-fail — live source vetting, brand-named-skill detection, self-containment; a document-of-record source can waive the recency/activity vetting rules by carrying a declared `vetting_exception` reason *and* being granted one in `VETTING_EXCEPTIONS` in `validate.py`, which maps the source name to the repo the waiver covers, surfaced as a warning — same reviewed-exception pattern as `ALLOWED_TOOLS_EXCEPTIONS` in the same file, and for the same reason: a bypass that is easier to use than to notice will get used, so the grant has to be a code change a maintainer reviews rather than a field a contributor sets on their own entry. The grant is checked by `validate.py` rather than by this script because this workflow evaluates the base branch's copy of the script, which would force a grant to merge ahead of the source it covers; `validate.yml` runs from the PR head, so a source and its grant land in one reviewed PR) plus an advisory AI scope review (a single non-agentic Gemini call posting a sticky verdict comment; skips cleanly when no `GEMINI_API_KEY` secret is configured). Humans still merge.

**Planned (tracked, not built)** — live status is on the [roadmap](../website/src/content/docs/about/roadmap.md); the design intent for each:
- `UserPromptSubmit` hook that auto-injects "consult bundled docs first" guidance on Cardano-keyword-matched prompts, with local usage telemetry under `~/.cardano-dev-skills/usage.log`.
- PR-time source-build check: when `registry/sources.yaml` changes, CI fetches the touched source(s) and verifies the clone + glob patterns produce files.

These additions follow the principle: ship small, observe, iterate.

## Decision 10: Documentation governance

**Decision:** Docs in this repo (CLAUDE.md, README.md, DESIGN.md, CONTRIBUTING.md) must reflect current state. Externally-observable changes (counts, capabilities, structure, interfaces) require a doc update in the same PR. Internal tweaks (refactors, typo fixes) do not.

**Why:** Stale READMEs are the most common rot in tooling repos. They mislead new contributors, make the project look abandoned, and damage credibility — particularly when the goal is broader adoption.

**Mechanism:**

- **Per-change-type checklist** — canonical in `docs/CONTRIBUTING.md` (§Documentation governance), surfaced from `CLAUDE.md` — mapping change types (new skill, new source, new schema field, new script, new hook) to the docs that must be updated. Enforced by reviewer judgement and (planned) AI governance review.

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

## Decision 13: Supply-chain guardrails for bundled third-party content

**Decision:** Content entering `docs/sources/` and skill tool grants are screened in layers, because bundled docs are read by AI agents on every consumer's machine and the plugin now updates on every commit (marketplace installs track HEAD since the version pins were dropped). Full rationale and threat model: `docs/proposals/supply-chain-guardrails.md`.

**The layers:**

0. **Tool-grant policy** (`scripts/validate.py`): `allowed-tools` is a one-turn pre-approval in Claude Code, not a restriction, so the base grant is `Read Grep Glob`, anything wider needs a reviewed exception entry, and every skill must disallow `WebFetch`/`WebSearch` (skills are self-contained). Advisory-only skills additionally disallow `Bash`/`Edit`/`Write`, containing injection blast radius during the turn untrusted docs are read.
1. **Fetch-time sanitization** (`scripts/_fetch_docs.py`): strips zero-width/bidi characters everywhere and HTML comments + `<script>` from markup — deletes the hidden-text injection class instead of trying to detect it.
2. **Mechanical delta scanner** (`scripts/scan-docs-delta.py`, blocking check in the PR Policy workflow): pattern-level screening of changed lines only — injection phrasing, pipe-to-shell, swapped bech32 addresses, changed install commands, new domains per source.
3. **Advisory AI docs-delta review** (PR Policy workflow): reuses the non-agentic scope-review harness with a supply-chain rubric (`.github/docs-delta-review-prompt.md`) to catch what patterns can't — plausible address swaps, typosquats, injection phrased as documentation. Advisory per this repo's discipline: only mechanical checks go red.
4. **Commit pinning** (`registry/pins.yaml` + per-source refresh commits): normal fetches check out the last-vetted upstream commit, not the branch tip; the weekly refresh proposes pin bumps as one commit per changed source, so a bad delta reverts with one `git revert`. Mirrors Anthropic's community-marketplace model of pinning plugins to SHAs.

**Where the blocking scan runs.** A PR opened by the weekly workflow with the default `GITHUB_TOKEN` does not trigger `pull_request`/`pull_request_target` workflows (GitHub's recursion guard), so `pr-policy` would never auto-run on the refresh PR it is meant to police. The blocking scan therefore runs **inline** in `refresh-docs.yml`: the PR is still opened (for quarantine review, labelled `security-review-required` on a block), but a BLOCK finding fails the workflow run red so the refresh can never be a silent green merge. Giving the workflow a PAT/App token so `pr-policy` also fires is an optional belt-and-suspenders, not a requirement.

**Trust boundary stated plainly:** the screening narrows the window between "upstream compromised" and "detected", it does not close it. A maintainer merges every refresh PR; the layers exist to make that human's review tractable (a per-source verdict table instead of an unreviewable 300-file diff), not to replace it. The mechanical scanner is the blocking gate; the AI docs-delta review is advisory only, because it reads attacker-influenced content and can be steered.

**Rejected:** full manual review of refresh diffs (doesn't scale — the pre-guardrail rubber stamp was the evidence); per-source refresh PRs (10× PR noise for isolation that per-source commits already provide); blanket `context: fork`/tool restriction on all skills (breaks builder skills whose job is writing code in the same turn).

## Decision 14: Feedback channel is GitHub Issues, agent-mediated

**Decision:** Feedback about the skills and bundled docs goes to GitHub Issues on this repository, drafted by the `give-feedback` skill from the conversation it is in, shown to the user, and filed with `gh` after one approval under the user's own GitHub account. No feedback server or endpoint (Decision 1); Discussions are disabled; the existing issue forms remain the manual path.

**Why agent-mediated:** the agent holds the context at the moment a doc fails or helps (the path, what was asked, what happened), and that context is gone by the time a human would open a form. Praise is collected as deliberately as defects: it tells maintainers what to keep.

**The gate is the chat ask, not a tool grant.** The skill keeps the base `Read Grep Glob` grant and runs `gh` under the host's normal permissions. A skill grant would cover only the invoking turn while the user's yes arrives in the next one, and other hosts ignore the field; showing the draft and asking once is the safeguard that holds in every host and permission mode. When `gh` is missing or fails, the draft on screen plus the new-issue link is the fallback.

**Activation:** one sentence in the `cardano-context` block (v3) tells the agent to note misfires and wins while working and to show a ready draft once at a natural pause, never mid-task; the skill's trigger phrases cover explicit requests. The SessionStart banner was rejected: it scrolls out of reach, while `CLAUDE.md` is re-injected every turn.

**Rejected:** a hosted endpoint (a runtime to operate, anonymous submissions); pre-authorized silent filing via a `CLAUDE.md` token (public issues under the user's name with no human reading the draft); prefilled issue-form links as a fallback (GitHub truncates long query values); an auth check and duplicate search before sending (friction for a job maintainers do in seconds).

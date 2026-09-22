# Design Decisions

This document captures the architectural decisions behind `cardano-dev-skills`. It records what was decided, why, and what alternatives were considered.

## Decision 1: Content-only repository

**Decision:** This repository ships content (YAML, Markdown, shell hooks) — no application code, no servers, no runtime dependencies users have to install.

**Why:**
- **Security.** Pure content is auditable by anyone. Users installing the plugin don't execute arbitrary TypeScript or Python from this repo.
- **Lower contribution barrier.** A Cardano developer can add a skill or source without learning a build system, a framework, or a deployment pipeline.
- **Decoupled from any specific consumer.** Multiple agents and tools can read
  this content: Claude Code and Codex through their thin adapters, any agent
  that reads Markdown, or external indexers. Shared skill behavior does not
  assume which host is using it.

**Source-mirroring formats.** Some sources are documented in their own source files rather than in prose, so the `format` allow-list in `scripts/validate.py` admits `python`, `aiken`, and `go` alongside the markup formats: Python docstrings and Go doc comments sit on the identifiers they describe, which makes the source the API reference. Mirrored code is inert reference text — read by agents, never executed, and never built (generating `go doc` output would put a language toolchain and module downloads in the fetch path, which Decision 13's posture rules out). Because a repository's source tree is much larger than its public API, these formats carry per-source `glob_patterns` scoped to the importable surface, and `scripts/_fetch_docs.py` drops test files and `testdata/` fixtures.

**Alternative considered:** Bundling content with an indexing/serving runtime. Rejected because it couples content updates to runtime releases and shrinks the set of tools that can consume the content.

## Decision 2: Skills organized by developer workflow (flat directory layout)

**Decision:** Skills live flat under `skills/<name>/SKILL.md`. Logical categorization is conveyed by skill names and descriptions, not by directory structure.

**Why:** Developers think in terms of "what am I trying to do?" not "what category is this tool in?" A developer building an NFT marketplace needs `write-validator` + `build-transaction` + `connect-wallet` — these map to workflows, not to the registry's source categories. Flat layout also lets both Claude and Codex package and discover the same `skills/<name>/SKILL.md` directories without a generated copy.

**Alternative considered:** Mirror the registry's source categories (infrastructure, smart-contracts, sdk, standards, governance, scaling, testing, oracles) as subdirectories. Rejected because skills like `build-transaction` span multiple categories, and the plugin discovery contract doesn't require it.

## Decision 3: YAML registry, not TypeScript

**Decision:** The canonical source list is `registry/sources.yaml`, not a TypeScript file.

**Why:** Lower contribution barrier. A Cardano developer who wants to add a new project doesn't need to know TypeScript, Python, or any specific consumer's type system. YAML is universally readable and editable. Any downstream tool that needs typed access can generate types from the YAML on its own side.

## Decision 4: Skills are self-contained

**Decision:** Skills must work with local file read and search capabilities
alone. No external service dependencies or proprietary tool calls.

**One exception, recorded:** `give-feedback` (Decision 14) sends an issue to GitHub through `gh`. It is the only skill whose *purpose* is an outward action, and it degrades to showing the user a draft and a link when `gh` is absent — so the guarantee below (a skill produces useful output regardless of what else is installed) still holds.

**Why:**
- Skills should produce useful guidance regardless of what other tools the user has connected.
- Skills that depend on a specific MCP server, API, or service break for any user who hasn't installed that specific thing.
- The bundled corpus under `docs/sources/` is the authoritative reference and
  can be found and consumed with ordinary local file access.

**How it works:** Shared Markdown describes capabilities rather than host tool
names. Every `SKILL.md` also retains Claude Code's `allowed-tools: Read Grep
Glob` security metadata, but portable behavior never depends on those fields.
If a user has additional tools or MCP servers connected, the agent may use
them when appropriate, but the skill never requires them.

## Decision 5: Progressive disclosure

**Decision:** SKILL.md files are capped at 500 lines. Deep reference content goes in `references/` subdirectories, one level deep only.

**Why:**
- **Context budget.** Hosts initially discover a skill from its name and
  description. The full `SKILL.md` loads when selected, and references load
  only when needed. This keeps context usage manageable in both agents.
- **Maintainability.** A 500-line file is reviewable in a single PR. A 2,000-line file is not.
- **Trail of Bits pattern.** Their production skills follow this exact structure and it works at scale (35+ plugins, 100+ skills).

## Decision 6: Agent Skills standard compliance

**Decision:** Follow the portable Agent Skills core: YAML frontmatter with
`name` and `description`, plus a structured Markdown body. Retain
`allowed-tools` and `disallowed-tools` as reviewed Claude Code extensions, not
as the cross-host behavioral contract.

**Why:**
- Compatible with Claude Code (`.claude-plugin/` + `skills/`)
- Compatible with Codex (`.codex-plugin/` + `skills/`)
- Future-proof for other tools that adopt the standard
- Established quality standards (naming conventions, description requirements, section structure)

**Cross-tool compatibility:** Host adapters expose one canonical skill tree
without file duplication:
- `.claude/skills` → `../skills` (Claude Code project-level discovery)
- `.agents/skills` → `../skills` (Codex discovery)
- `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` package the same
  root `skills/` directory

The canonical authoring rules live in `docs/AGENT_COMPATIBILITY.md`. Shared
skill bodies resolve the bundled corpus relative to their own `SKILL.md`, not
through a Claude-only environment variable or the user's working directory.

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
- **Schema validation** (`.github/workflows/validate.yml`) — runs on every PR touching `skills/**`, `registry/**`, `scripts/**`, `docs/**` or `hooks/**`. Also runs `--paths-only` on the oldest supported interpreter (3.9) before installing anything, and the SessionStart hook's test suite.
- **Manifest self-healing** — `scripts/_fetch_docs.py` derives `.manifest.yaml` from disk state after every fetch (partial or full), so the manifest can't drift.
- **PR policy gate** (`.github/workflows/pr-policy.yml`) — on PRs touching `skills/`, `registry/`, or `docs/sources/`: mechanical checks (`scripts/check-pr-policy.py`, hard-fail — live source vetting, brand-named-skill detection, self-containment; a document-of-record source can waive the recency/activity vetting rules by carrying a declared `vetting_exception` reason *and* being granted one in `VETTING_EXCEPTIONS` in `validate.py`, which maps the source name to the repo the waiver covers, surfaced as a warning — same reviewed-exception pattern as `ALLOWED_TOOLS_EXCEPTIONS` in the same file, and for the same reason: a bypass that is easier to use than to notice will get used, so the grant has to be a code change a maintainer reviews rather than a field a contributor sets on their own entry. The grant is checked by `validate.py` rather than by this script because this workflow evaluates the base branch's copy of the script, which would force a grant to merge ahead of the source it covers; `validate.yml` runs from the PR head, so a source and its grant land in one reviewed PR) plus an advisory AI scope review (a single non-agentic Gemini call posting a sticky verdict comment; skips cleanly when no `GEMINI_API_KEY` secret is configured). Humans still merge.

**Planned or deferred (tracked, not built)** — live status is on the [roadmap](../website/src/content/docs/about/roadmap.md); the design intent for each:
- Local usage observability for tuning skill descriptions and finding unmatched prompts, without changing prompt behavior.
- PR-time source-build check: when `registry/sources.yaml` changes, CI fetches the touched source(s) and verifies the clone + glob patterns produce files.

These additions follow the principle: ship small, observe, iterate.

## Decision 10: Documentation governance

**Decision:** Docs in this repo (`AGENTS.md`, `CLAUDE.md`, `README.md`,
`AGENT_COMPATIBILITY.md`, `DESIGN.md`, and `CONTRIBUTING.md`) must reflect
current state. Externally-observable changes (counts, capabilities, structure,
interfaces) require a doc update in the same PR. Internal tweaks (refactors,
typo fixes) do not.

**Why:** Stale READMEs are the most common rot in tooling repos. They mislead new contributors, make the project look abandoned, and damage credibility — particularly when the goal is broader adoption.

**Mechanism:**

- **Per-change-type checklist** — canonical in `docs/CONTRIBUTING.md`
  (§Documentation governance), surfaced from both `CLAUDE.md` and `AGENTS.md`
  — mapping change types to the docs that must be updated. Enforced by
  reviewer judgement and automated validation where practical.

**Alternative considered:** Generate the entire README from a template + computed values. Rejected because narrative sections ("Why this exists", "How to set the Cardano context") need human prose, and a template-only approach makes those harder to evolve.

## Decision 11: Hook strategy

**Decision:** Use Claude Code's hook surface for *unconditional,
low-information signals* — doc-freshness checks, project-context detection,
install-topology-aware refresh hints. Hooks are a Claude adapter, not shared
skill behavior. Reserve durable behavioral directives for the agent-neutral
block that `cardano-context` installs into `CLAUDE.md` and `AGENTS.md` (see
Decision 12).

**Shipped:**
- `SessionStart` (`hooks/check-docs.sh`):
  - Reports doc-corpus freshness on every session start.
  - Detects the `cardano-dev-skills` directive block in cwd `CLAUDE.md` and prints either a confirmation or a `/cardano-dev-skills:cardano-context` nudge.
  - Differentiates refresh hints by install topology (local clone vs marketplace cache).
  - Opportunistic behind-upstream check via `FETCH_HEAD` (no network on session start).

**Considered and rejected:** A `UserPromptSubmit` hook that keyword-matches Cardano terms and injects an `additionalContext` reminder. Decision 12 explains why a meta-skill writing durable project instructions is structurally better than a per-prompt regex.

**Deferred:** Local usage observability (`PostToolUse` logging of which bundled docs/skills get consulted per session, backed by `scripts/usage-report.sh`). Useful for tuning skill descriptions and surfacing unmatched prompts; orthogonal to the consultation-directive problem solved by `cardano-context`.

**Why hooks for the shipped piece:** The freshness check produces
*information*, not behavior — `SessionStart` is the right Claude surface (no
user invocation, plain-text output about plugin state). Codex does not depend
on this hook. Hooks should not mutate prompts or own portable behavioral
directives; that role belongs to the block installed in both host instruction
files by `cardano-context`.

## Decision 12: Meta-skills as an exception to workflow taxonomy

**Decision:** Most skills encode a developer *workflow* (write a validator,
build a transaction, debug a failing tx). One skill — `cardano-context` — is a
**meta-skill**: its only job is to configure agent behavior in the user's
project by writing the same delimited, versioned directive block to
`CLAUDE.md` and `AGENTS.md`. It produces no Cardano output and teaches no
Cardano concept; it exists to ensure the workflow skills and bundled corpus
get consulted regardless of which agent opens the project.

**Why a meta-skill is needed at all:** Description-based skill auto-matching is
not guaranteed to fire on every relevant phrasing, and either model can answer
confidently from stale training data. Durable per-project instructions harden
the prior: Claude reads `CLAUDE.md`, Codex reads `AGENTS.md`, and committing
both distributes identical guidance to teammates.

**Why this is an exception to Decision 2:** Decision 2 categorizes skills by developer workflow. `cardano-context` doesn't fit — its "workflow" is one-time project setup, not Cardano development. Treating it as just another workflow skill obscures its purpose and its different invocation pattern (run explicitly once per project; not auto-matched on related developer prompts).

**How to recognize a meta-skill:** It modifies the user's *environment* (`CLAUDE.md`, `AGENTS.md`, settings, or project files) rather than producing Cardano code, advice, or analysis. Meta-skills:
- Are run explicitly by the user, typically once per project.
- Are idempotent on re-run; updates are versioned and atomic.
- Distribute their effect via git (committed file) rather than per-session state.

**Alternative considered:** A `UserPromptSubmit` hook that keyword-matches
Cardano terms and injects a consultation reminder. Rejected because regex has
no project context, injected reminders are less durable, hidden hook behavior
is harder to inspect, and it would solve only one host. Checked-in
`CLAUDE.md`/`AGENTS.md` blocks are visible, editable, and portable.

**Future meta-skills:** Likely candidates if the pattern stays useful — a deprecation/anti-pattern cheatsheet, project-level Cardano coding conventions. All would follow the same shape: produce a delimited versioned block, write to a project file, idempotent on re-run.

## Decision 13: Supply-chain guardrails for bundled third-party content

**Decision:** Content entering `docs/sources/` and skill tool grants are screened in layers, because bundled docs are read by AI agents on every consumer's machine and the plugin now updates on every commit (marketplace installs track HEAD since the version pins were dropped). Full rationale and threat model: `docs/proposals/supply-chain-guardrails.md`.

**The layers:**

0. **Portable behavior plus Claude tool grants** (`scripts/validate.py`):
   shared skill bodies must avoid host-only path variables and tool names, and
   must state required safety behavior in portable prose. Separately,
   `allowed-tools` is a one-turn pre-approval in Claude Code, not a restriction,
   so the Claude base grant is `Read Grep Glob`, anything wider needs a reviewed
   exception, and every skill must disallow `WebFetch`/`WebSearch`.
   Advisory-only skills additionally disallow `Bash`/`Edit`/`Write`. Codex does
   not rely on these frontmatter fields; the body-level untrusted-data rule is
   the cross-host control.
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

**Activation is by trigger phrase only, for now.** The skill fires when the user asks — "send feedback", "this doc is wrong", `/cardano-dev-skills:give-feedback` in Claude Code, or `$give-feedback` in Codex. Adding a sentence to the `cardano-context` block would make the agent offer a draft unprompted, which is a materially different thing: the block lands in both host instruction files and applies in every configured project indefinitely, so its reach is every installed user rather than one invocation. That sentence is deferred until there are real issues to judge it by — the question it turns on is what volume and quality agent-drafted feedback actually produces, which no amount of review settles in advance. A SessionStart banner was rejected outright: it scrolls out of reach.

**This widens the meta-skill category; it does not fit the existing one.** Decision 12 recognises a meta-skill by four tests: it modifies the user's *environment*, is run explicitly once per project, is idempotent on re-run, and distributes its effect via git. `give-feedback` meets none of them — it sends data outward rather than changing anything local, runs once per finding rather than once per project, is deliberately anti-idempotent ("send once; never retry after a success"), and distributes nothing. So `cardano-context` is a grandfather, not a precedent, and the category needs a second test rather than a stretched first one:

> A meta-skill acts on the plugin itself rather than teaching a Cardano workflow — either by configuring the environment the plugin runs in, or by carrying information back to its maintainers. Both kinds need a decision recorded here before they are added.

**Trust boundary stated plainly:** this is the first skill with a network egress path, and it reaches it through `Bash` + `gh` rather than through the `WebFetch`/`WebSearch` ban that Decision 13 layer 0 imposes — a ban whose stated purpose is keeping a poisoned doc read during a skill turn from reaching out. Bundled docs are untrusted by design (Decision 13), and a skill turn that has read one could in principle shape what lands in a public issue under the user's name. The human-reads-the-draft gate is a real mitigation and it is the reason this ships, but it narrows the window, it does not close it: "bias toward sending", "ask once", and "do not re-confirm" are all tuned to reduce exactly the friction that gate depends on, and the scrub list is a blocklist written by the same model that would be under influence. What makes it acceptable is the shape of the action — one fixed repository, no arbitrary URL, a body the user has read, and a host permission prompt that re-displays that body before anything is sent.

**Rejected:** a hosted endpoint (a runtime to operate, anonymous submissions); pre-authorized silent filing via an instruction-file token (public issues under the user's name with no human reading the draft); prefilled issue-form links as a fallback (GitHub truncates long query values); an auth check and duplicate search before sending (friction for a job maintainers do in seconds); granting the skill `Bash(gh:*)` in `allowed-tools` (pre-approval would spend the user's consent a turn before they give it).

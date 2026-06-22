---
title: How it works
description: Three complementary mechanisms set the Cardano context — per-project directive, skill auto-matching, and SessionStart freshness signals.
---

Three complementary mechanisms set the Cardano context for the agent, listed
from most reliable to least.

## 1. Per-project `/cardano-context` directive

The most reliable mechanism. Run once per project:

```
/cardano-context
```

What it does:

- Writes a version-tagged block into the project's `CLAUDE.md` (default
  `./CLAUDE.md`). Claude Code re-injects `CLAUDE.md` into every conversation
  turn, so the directive survives compaction and applies on every new
  session.
- Instructs the agent to treat training data as potentially stale for
  Cardano, to bias toward invoking `cardano-dev-skills:*` skills, to search
  `${CLAUDE_PLUGIN_ROOT}/docs/sources/` before falling back on memory, and
  to cite what it used.
- Commit `CLAUDE.md` and teammates inherit the directive on clone.
- Re-running is safe: same version is a no-op; older versions are
  atomically replaced.

**Good at:** ensuring the agent consults bundled context on every turn,
including vague prompts that don't match any specific skill's triggers.

## 2. Skill auto-matching

Each skill declares trigger phrases in its description. When you ask a
question that matches, the agent auto-invokes that skill:

- *"review my validator"* → `review-contract`
- *"scaffold a Cardano project"* → `scaffold-project`
- *"how do I connect a wallet"* → `connect-wallet`
- *"explain CIP-1694"* → `explain-cip`

The full skill catalogue lives at [/skills](/cardano-dev-skills/skills/).

**Good at:** workflow-shaped prompts where the user names the task.

## 3. SessionStart freshness signals

A `SessionStart` hook (`hooks/check-docs.sh`) inspects the bundled corpus
and the current working directory and prints status lines prefixed
`[Cardano Dev Skills]`:

- **Docs loaded.** Normal: `Docs loaded: N sources, M files (updated Xd ago)`.
- **Docs stale (>30 days).** Suggests how to refresh based on install topology:
  local clone → `git pull && ./scripts/fetch-docs.sh`; marketplace install →
  `/plugin marketplace update cardano-foundation`.
- **Plugin clone behind upstream.** Local clones only: if `git fetch` has run
  and you haven't pulled, the hook prints how many commits behind you are.
- **Cardano context active.** When `./CLAUDE.md` contains the directive block.
- **Cardano context nudge.** When cwd looks like a project (`.git`, `.claude`,
  or existing `CLAUDE.md`) but has no block: *"Tip: run /cardano-context to
  enable auto-consultation in this project."*

The hook is fail-open: any failure exits 0 silently and never blocks the
session.

**Good at:** ambient awareness — surfaces stale docs and missing project
directives without interrupting flow.

## When auto-consultation misses

Vague prompts like *"help me build a Cardano dApp"* may not match any
specific skill's triggers, and without the per-project directive the agent
may answer from training data alone.

When that happens, nudge explicitly:

- *"Check the cardano-dev-skills docs and skills before answering."*
- *"Use the scaffold-project skill to set up a new project."*
- *"Read `docs/sources/aiken/` before writing this validator."*

A keyword-matching `UserPromptSubmit` hook is in development — it will scan
prompts for Cardano-specific terms (`aiken`, `plutus`, `cip-XXXX`, `ogmios`,
`drep`, …) and remind the agent to consult bundled docs before training
data or the web. Until it ships, the per-project directive is the reliable
solution.

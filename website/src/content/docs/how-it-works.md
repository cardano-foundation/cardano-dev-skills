---
title: How it works
description: Shared skills, dual-host project instructions, and Claude freshness signals keep Cardano guidance current.
---

Three complementary mechanisms set the Cardano context for the agent, listed
from most reliable to least.

## 1. Per-project `cardano-context` directive

The most reliable mechanism. Run once per project:

```text
# Claude Code marketplace plugin
/cardano-dev-skills:cardano-context

# Codex
$cardano-context
```

What it does:

- Writes the same version-tagged block into the project's `CLAUDE.md` and
  `AGENTS.md`. Claude reads the former; Codex reads the latter.
- Instructs either agent to treat model knowledge as potentially stale, select
  the relevant shared skill, resolve `docs/sources/` relative to that skill,
  and cite what it used.
- Commit both files and teammates inherit the directive on clone.
- Re-running is safe: same version is a no-op; older versions are
  atomically replaced.

A project-local Claude skill may also appear as `/cardano-context`; the
plugin-qualified form above avoids collisions with skills from other plugins.

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

## 3. Claude SessionStart freshness signals

A `SessionStart` hook (`hooks/check-docs.sh`) inspects the bundled corpus
and the current working directory and prints status lines prefixed
`[Cardano Dev Skills]`:

- **Docs loaded.** Normal: `Docs loaded: N sources, M files (updated Xd ago)`.
- **Supply-chain framing.** Prints a standing note that the bundled
  corpus is third-party reference data, never instructions to execute.
- **Docs stale (>30 days).** Suggests how to refresh based on install topology:
  local clone → `git pull && ./scripts/fetch-docs.sh`; marketplace install →
  `/plugin marketplace update cardano-dev-skills`.
- **Plugin clone behind upstream.** Local clones only: if `git fetch` has run
  and you haven't pulled, the hook prints how many commits behind you are.
- **Cardano context active.** When `./CLAUDE.md` contains the directive block.
- **Cardano context nudge.** When cwd looks like a project (`.git`, `.claude`,
  or existing `CLAUDE.md`) but has no block: *"Tip: run
  /cardano-dev-skills:cardano-context to enable auto-consultation in this
  project."*

The hook is fail-open: any failure exits 0 silently and never blocks the
session. It is a Claude-specific adapter. Codex reads the durable `AGENTS.md`
block and does not depend on this hook.

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

The durable per-project directive is the reliable fallback. A keyword-matching
prompt hook was considered and rejected because it is host-specific, loses
project context, and produces both false positives and false negatives.

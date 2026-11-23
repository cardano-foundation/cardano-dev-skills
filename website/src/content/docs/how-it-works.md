---
title: How it works
description: Shared skills and one cross-agent project directive steer agents to current Cardano guidance.
---

Two complementary mechanisms set the Cardano context for the agent, listed
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

- Writes one version-tagged block into the project's `AGENTS.md`, which Codex
  reads. Claude reads `AGENTS.md` only when the project has no `CLAUDE.md`; if
  yours has one, the skill adds a small marked `@AGENTS.md` import line to it,
  so Claude loads the whole of `AGENTS.md` too. It never creates a `CLAUDE.md`.
- Instructs either agent to treat model knowledge as potentially stale, select
  the relevant shared skill, resolve `docs/sources/` relative to that skill,
  and cite what it used.
- Commit the changed files and teammates inherit the directive on clone.
  Teammates need a current plugin too: an older one writes an older block.
- Re-running is safe: a current block is a no-op, and an unedited older block,
  including one in `CLAUDE.md` from an earlier layout, moves to `AGENTS.md` as
  the current version. Edits you made inside the block, a newer block, or
  broken markers are shown to you and asked about first; nothing outside the
  marked regions changes.
- An explicitly requested scaffold or generator operation can call this
  context protocol without a second setup question. It preserves proven
  custom instructions around fresh generated facts and then uses the same
  canonical setup flow. `scaffold-project` uses this entrypoint for requested
  initial generation and later Cardano Init operations.

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

For scaffolding, matching `scaffold-project` starts one shared workflow: inspect
an already installed Cardano Init release and catalog, preview supported effects,
generate once, reconcile canonical project context, adapt the requested logic,
then build and run meaningful non-E2E tests. It does not acquire or update the
CLI, bypass a dirty/nonempty target, silently change a stack/version, or require
a devnet launch. Unsupported or denied generation has a manual best-effort path
with the same honest verification standard.

## Public evidence under host permissions

Skills are local-first and remain useful without network access.
`assess-constitutionality` has one recorded, narrow exception: for a live
governance action it first tries to read the public provider record, exact
on-chain anchor bytes, and proposal material that anchor directly references.
It does not perform open-ended web research, alter permissions, or execute
fetched content.

Claude desktop/cloud domain controls, when present, may need the specific
provider, anchor, or direct-material domain allowed. That setting is permission,
not a guarantee that networking, DNS, or the endpoint works. Codex applies its
own sandbox, network, and approval settings; Claude settings do not transfer.
If a host denies one retrieval, the skill preserves evidence acquired elsewhere,
marks only the affected finding Not-yet-verifiable, and gives a targeted
fallback.

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

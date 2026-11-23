---
title: Getting started
description: Install the shared Cardano Dev Skills for Claude Code, the Claude app, Codex, or as a standalone Markdown reference.
---

Cardano Dev Skills works in four modes. Pick the one that matches your agent.

## Claude Code

In any Claude Code session:

```
/plugin marketplace add cardano-foundation/cardano-dev-skills
/plugin install cardano-dev-skills@cardano-dev-skills
```

Installed once, active in every Claude Code session in any directory. Verify with:

```
/plugin list
```

Run the two commands in that order. Adding the marketplace first is what
registers it; going straight to `/plugin install` makes the client resolve the
repository itself, which can fall back to an SSH URL and fail with
`git@github.com: Permission denied (publickey)` even though this repository is
public and clones fine over HTTPS.

Claude Code auto-updates plugins only from marketplaces with auto-update on,
and third-party marketplaces like this one start with it off. Turn it on once:
run `/plugin`, open **Marketplaces**, select **cardano-dev-skills**, and choose
**Enable auto-update**. To update by hand, run
`claude plugin update cardano-dev-skills@cardano-dev-skills` from your shell
and restart.

## Claude app, formerly Claude Cowork (web, desktop, mobile)

The Claude app's Chat side uses the same plugin format as Claude Code, so this
marketplace works there unchanged. Installing here also syncs the plugin to
Claude Code sessions signed in with the same account.

1. Open **Customize** and go to the **Plugins** tab.
2. Under **Personal plugins**, click **+**, then **Add marketplace**.
3. Choose **Add from a repository** and enter:
   `https://github.com/cardano-foundation/cardano-dev-skills`
4. Install **cardano-dev-skills** from the marketplace once it syncs.

You get the same skills as the Claude Code plugin. The Claude app syncs the
whole repository, and `docs/sources/` is roughly 30 MB of bundled documentation,
so the first sync is not instant.

## Codex

On macOS, Linux, or WSL, keep this repository and your Cardano project as
sibling directories:

```bash
cd /path/to/projects
git clone https://github.com/cardano-foundation/cardano-dev-skills.git
cd your-cardano-project
mkdir -p .agents
ln -s ../../cardano-dev-skills/skills .agents/skills
```

On Windows PowerShell, create a directory junction from the Cardano project:

```powershell
New-Item -ItemType Directory -Force .agents
New-Item -ItemType Junction -Path .agents\skills -Target (Resolve-Path ..\cardano-dev-skills\skills)
```

Start or restart Codex in `your-cardano-project`, run `/skills`, and confirm the
Cardano skills appear. Then run `$cardano-context` once to add the durable
project directive.

Codex discovers repository skills under `.agents/skills` and follows linked
skill directories. The repository also includes `.codex-plugin/plugin.json`
for plugin packaging and publishing; until that plugin is published in a
directory, the repository link above is the supported installation path.

## Install the per-project directive

Either agent can answer Cardano questions from stale model knowledge when a
skill description does not match the prompt. Run the `cardano-context` skill
once per project to install a durable, agent-neutral directive:

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
- Tells either agent to treat model knowledge as potentially stale, select the
  relevant skill, resolve bundled `docs/sources/` from that skill's location,
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
  canonical setup flow. `scaffold-project` uses it for initial generation and
  later requested Cardano Init operations.

A project-local Claude skill may also appear as `/cardano-context`; the
plugin-qualified form above avoids collisions with skills from other plugins.

## Public evidence permissions

The skills do not assume network access. One evidence-heavy workflow,
`assess-constitutionality`, can retrieve a live action's bounded public evidence
under permissions the host already provides. It never changes those permissions
or treats a denied request as evidence that the public record is absent.

In Claude desktop/cloud, allow only the specific provider, anchor, and directly
referenced material domains through the domain controls available to your
account or organization. An allowed domain still does not guarantee network or
endpoint availability. Codex has separate sandbox, network, and approval
settings; configure those in Codex rather than expecting Claude domain choices
to carry over. With no permitted retrieval path, the skill remains useful from
local or user-supplied evidence and identifies the exact missing item.

## Standalone

Skills are pure Markdown — read `skills/*/SKILL.md` directly, or grep them.

## First prompt

Once installed, ask the agent something concrete that should match a skill:

> *"Scaffold a new Cardano project with Aiken on-chain and Mesh SDK off-chain."*

You should see the agent invoke `scaffold-project`, inspect an already installed
Cardano Init release and catalog, and show a nonwriting preview before supported
generation. It will not install or upgrade the CLI. After generation it adapts
the requested application, applies canonical project context, and requires
actual builds plus meaningful non-E2E tests. If Cardano Init is unavailable or
does not support the stack, it offers user-run setup or a manual fallback.

If the skill doesn't match automatically,
nudge explicitly:

> *"Use the scaffold-project skill from cardano-dev-skills."*

See [How it works](/cardano-dev-skills/how-it-works/) for the three context
mechanisms and how to tell when one of them is doing the work.

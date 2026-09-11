---
title: Getting started
description: Install the shared Cardano Dev Skills for Claude Code, Claude Cowork, Codex, or as a standalone Markdown reference.
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

## Claude Cowork (desktop, web, mobile)

Cowork uses the same plugin format, so this marketplace works there unchanged.

1. Open **Customize** and go to the **Plugins** tab.
2. Under **Personal plugins**, click **+**, then **Add marketplace**.
3. Choose **Add from a repository** and enter:
   `https://github.com/cardano-foundation/cardano-dev-skills`
4. Install **cardano-dev-skills** from the marketplace once it syncs.

You get the same skills as the Claude Code plugin. Cowork syncs the whole
repository, and `docs/sources/` is roughly 30 MB of bundled documentation, so
the first sync is not instant.

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

- Writes the same version-tagged block into the project's `CLAUDE.md` and
  `AGENTS.md`. Claude reads the former; Codex reads the latter.
- Tells either agent to treat model knowledge as potentially stale, select the
  relevant skill, resolve bundled `docs/sources/` from that skill's location,
  and cite what it used.
- Commit both files and teammates inherit the directive on clone.
- Re-running is safe: same version is a no-op; older versions are atomically
  replaced.

A project-local Claude skill may also appear as `/cardano-context`; the
plugin-qualified form above avoids collisions with skills from other plugins.

## Standalone

Skills are pure Markdown — read `skills/*/SKILL.md` directly, or grep them.

## First prompt

Once installed, ask the agent something concrete that should match a skill:

> *"Scaffold a new Cardano project with Aiken on-chain and Mesh SDK off-chain."*

You should see the agent invoke the `scaffold-project` skill. If it doesn't,
nudge explicitly:

> *"Use the scaffold-project skill from cardano-dev-skills."*

See [How it works](/cardano-dev-skills/how-it-works/) for the three context
mechanisms and how to tell when one of them is doing the work.

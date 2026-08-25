---
title: Getting started
description: Install Cardano Dev Skills as a Claude Code plugin, a Claude Cowork plugin, a Codex skill set, or as a standalone Markdown reference.
---

Cardano Dev Skills works in four modes. Pick the one that matches your agent.

## Claude Code (recommended)

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

## Install the per-project directive

Even with the plugin installed globally, Claude sometimes answers Cardano
questions from training data instead of consulting bundled skills and docs.
Run the `cardano-context` skill once per project to install a durable
directive:

```
/cardano-context
```

What it does:

- Writes a version-tagged block into the project's `CLAUDE.md`. Claude Code
  re-injects `CLAUDE.md` into every conversation turn, so the directive
  survives compaction and applies on every new session.
- Tells Claude to treat training data as potentially stale for Cardano, to
  bias toward invoking `cardano-dev-skills:*` skills, to search bundled
  `docs/sources/` before falling back on memory, to cite what it used, and to
  offer the `give-feedback` skill when a skill or doc turns out wrong or
  notably helpful.
- Commit `CLAUDE.md` and teammates inherit the directive on clone.
- Re-running is safe: same version is a no-op; older versions are atomically
  replaced.

## Codex / other agents

```bash
git clone https://github.com/cardano-foundation/cardano-dev-skills.git
cd your-project
ln -s ../cardano-dev-skills/skills .agents/skills
```

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

---
title: Roadmap
description: Shipped and planned work across skills and governance tracks.
---

The work is broken into two tracks: **skills** (content the agent reaches
for) and **governance** (the lifecycle that keeps that content current).

## Skills track

### Shipped

- 15 developer skills covering the common Cardano workflows: scaffolding,
  writing validators, security review, optimisation, building transactions,
  designing tokens, debugging, querying chain data, devnet setup, wallet
  integration, governance, and the conceptual primers (eUTxO, CIPs,
  tooling).
- The `cardano-context` skill, which writes a durable per-project directive
  into `CLAUDE.md` so agents reliably consult bundled context.
- 55 documentation sources mirrored locally — SDKs, languages, infra, CIPs,
  ledger specs — under `docs/sources/`.
- A `SessionStart` hook (`hooks/check-docs.sh`) that reports doc freshness
  and surfaces the per-project directive nudge.

### Planned

- **Auto-consultation hook.** A `UserPromptSubmit` hook that scans the
  user's prompt for Cardano-specific keywords (`aiken`, `plutus`,
  `cip-XXXX`, `ogmios`, `drep`, …) and injects an "additional context"
  reminder to consult bundled docs/skills before training data or the web.
- **Usage telemetry.** A `PostToolUse` hook logging which docs and skills
  were consulted per session, to a local file. Used to tune the keyword
  set and skill triggers based on real prompts.
- **New skills as the ecosystem evolves.** New CIPs, new SDK paradigms,
  new validator patterns. Proposals via issue, ship via PR.

## Governance track

### Shipped

- **Weekly upstream refresh.** Every Monday 06:00 UTC, all sources are
  re-fetched and a PR is opened with the diff. Human review + merge before
  content lands on `main`.
- **Manifest self-healing.** The fetch script derives `.manifest.yaml` from
  disk state after every fetch (partial or full), so the manifest can't
  drift from reality.
- **Schema validation.** CI runs `scripts/validate.py` on every PR
  touching `skills/**` or `registry/**`.
- **Auto-derived counts.** `scripts/update-doc-counts.sh` rewrites sentinels
  in `CLAUDE.md` and `README.md` from disk. CI runs `--check` to fail PRs
  on drift.
- **Source-vetting bar.** Explicit policy in `CONTRIBUTING.md`: last commit
  age, release/activity signal, archival status, fork canonicality.

### Planned

- **PR-time source-build check.** When `registry/sources.yaml` changes,
  CI fetches the touched source(s) and verifies the clone + glob patterns
  produce files. Catches dead repos and bad globs before they land.
- **AI-powered governance review.** On PRs touching `registry/`, `skills/`,
  `hooks/`, or `scripts/`, an AI reviewer reads the diff and the rules
  from `CONTRIBUTING.md` and posts an advisory verdict comment (not
  blocking — humans still merge).
- **Cross-tool compatibility surface.** Codex and other agent harnesses
  consume the same skill files via `.agents/skills` symlinks. As the
  Agent Skills standard evolves, we follow it.

The principle across both tracks: **ship small, observe, iterate**.

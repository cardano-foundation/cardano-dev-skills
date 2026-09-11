---
title: Roadmap
description: Shipped and planned work across skills and governance tracks.
---

The work is broken into two tracks: **skills** (content the agent reaches
for) and **governance** (the lifecycle that keeps that content current).

## Skills track

### Shipped

- Developer skills covering the common Cardano workflows: scaffolding,
  writing validators, security review, optimisation, building transactions,
  designing tokens, debugging, querying chain data, devnet setup, wallet
  integration, governance, and the conceptual primers (eUTxO, CIPs,
  tooling).
- The `cardano-context` skill, which writes one durable per-project directive
  into `CLAUDE.md` and `AGENTS.md` so either agent reliably consults bundled
  context.
- Documentation sources mirrored locally — SDKs, languages, infra, CIPs,
  ledger specs — under `docs/sources/`.
- A `SessionStart` hook (`hooks/check-docs.sh`) that reports doc freshness
  and surfaces the per-project directive nudge.

### Planned

- **Usage telemetry.** A `PostToolUse` hook logging which docs and skills
  were consulted per session, to a local file. Used to tune skill
  descriptions and identify prompts that do not match reliably.
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
- **Source-vetting bar.** Explicit policy in `CONTRIBUTING.md`: last commit
  age, release/activity signal, archival status, fork canonicality.
- **PR policy gate.** On PRs touching `skills/`, `registry/`, or
  `docs/sources/`: mechanical checks enforce the vetting bar live against
  the GitHub API and fail brand-named skills, while an AI scope reviewer
  reads the diff against the rules from `CONTRIBUTING.md` and posts an
  advisory verdict comment (not blocking — humans still merge).
- **Cross-tool compatibility surface.** Claude Code and Codex consume the same
  skill files through separate plugin manifests and repository discovery
  links. A shared authoring contract and CI gate prevent host-specific paths,
  tool names, or packaging changes from silently breaking the other agent.

### Planned

- **PR-time source-build check.** When `registry/sources.yaml` changes,
  CI fetches the touched source(s) and verifies the clone + glob patterns
  produce files. Catches dead repos and bad globs before they land.

The principle across both tracks: **ship small, observe, iterate**.

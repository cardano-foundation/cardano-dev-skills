# Cardano Dev Skills

Community-curated Cardano developer knowledge — bundled skills, documentation, and tooling for AI coding agents.

Works as a Claude Code plugin, Codex skill set, or standalone reference.

## Why this exists

Training data on Cardano drifts fast. Conway era changed governance, Aiken syntax evolves, SDK APIs ship breaking changes monthly. An AI agent answering *"how do I write a vesting validator in Aiken?"* from training data alone gets it wrong more often than right.

This plugin solves that by shipping:

- **Authoritative bundled docs** from <!-- COUNT:sources -->48<!-- /COUNT:sources --> active Cardano projects (auto-refreshed weekly from upstream).
- **Behavioral skills** that encode common workflows: scaffolding, writing validators, building transactions, governance, optimization, debugging.
- **Hooks that auto-consult bundled context** before the agent reaches for training data or the web.

End result: the agent answers from current, project-authoritative sources instead of memorized snapshots.

## What's inside

- **<!-- COUNT:skills -->14<!-- /COUNT:skills --> developer skills** — each a focused workflow
- **<!-- COUNT:sources -->48<!-- /COUNT:sources --> documentation sources** — bundled locally under `docs/sources/`, auto-refreshed weekly via GitHub Actions
- **Hooks** — `SessionStart` reports doc freshness; a `UserPromptSubmit` auto-consultation hook is in development

### Skills

| Skill | What it does |
|---|---|
| `cardano-context` | Install a per-project Cardano directive into `CLAUDE.md` so the agent reliably consults bundled skills and docs |
| `scaffold-project` | Bootstrap a new Cardano project across Aiken + 4 off-chain stacks |
| `write-validator` | Guide writing a validator from spec (default Aiken) |
| `review-contract` | Security review of a validator |
| `optimize-validator` | Lower CPU / memory / script-size costs |
| `build-transaction` | Build & submit transactions across SDKs |
| `design-token` | Design native tokens, NFTs, CIP-25/68/113 metadata |
| `debug-transaction` | Diagnose failing transactions |
| `query-chain` | Pick the right query strategy (Blockfrost / Ogmios / indexer) |
| `setup-devnet` | Local devnet with Yaci DevKit or testnet setup |
| `connect-wallet` | CIP-30 wallet integration for dApps |
| `governance-guide` | CIP-1694 governance, DRep, voting, treasury |
| `explain-eutxo` | Cardano's UTxO model for newcomers |
| `explain-cip` | Walk through a specific CIP |
| `suggest-tooling` | Recommend an SDK / framework given the use case |

## What we add (and don't)

**In scope:** generic developer building blocks — SDKs, frameworks, validator libraries, design patterns, language tooling, infrastructure, protocol/standard specs, reference implementations of patterns.

**Out of scope:** product docs for specific deployed dApps (SundaeSwap, Minswap, Liqwid, Indigo, JPG Store, etc.). This repo teaches **how to build** a DEX, a lending protocol, an NFT marketplace — not how a particular branded product works. If users want product-specific integration help, their agent can search externally.

Borderline rule: if the upstream repo's primary purpose is *"use OUR product"*, it's out. If it's *"here's how X pattern works, here's the reference code"*, it's in.

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md#scope-what-belongs-in-this-repo) for the full policy and the maintenance bar for source vetting.

## Install

### Claude Code (recommended)

In any Claude Code session:

```
/plugin marketplace add easy1staking-com/cardano-dev-skills
/plugin install cardano-dev-skills@cardano-dev-skills
```

Installed once, active in every Claude Code session in any directory. Verify with `/plugin list`.

### Codex / other agents

```bash
git clone https://github.com/easy1staking-com/cardano-dev-skills.git
cd your-project
ln -s ../cardano-dev-skills/skills .agents/skills
```

### Standalone

Skills are pure Markdown — read `skills/*/SKILL.md` directly or with `grep`.

## How to set the Cardano context

Three complementary mechanisms, listed from most reliable to least:

### Per-project directive (recommended) — `/cardano-context`

Even with the plugin installed globally, Claude sometimes answers Cardano questions from training data instead of consulting these skills and bundled docs. Run the `cardano-context` skill once per project to install a durable directive:

```
/cardano-context
```

What it does:

- Writes a version-tagged block into the project's `CLAUDE.md` (default `./CLAUDE.md`). Claude Code re-injects `CLAUDE.md` into every conversation turn, so the directive survives compaction and applies on every new session.
- The block tells Claude to treat training data as potentially stale for Cardano, to bias toward invoking `cardano-dev-skills:*` skills, to search `${CLAUDE_PLUGIN_ROOT}/docs/sources/` before falling back on memory, and to cite what it used.
- Commit `CLAUDE.md` and teammates inherit the directive on clone.
- Re-running is safe: same version is a no-op; older versions are atomically replaced.

### Automatic mechanisms (no setup)

The plugin also tries to set the context automatically. In a Claude Code session:

1. **Session start.** A `SessionStart` hook reports doc freshness — you'll see `[Cardano Dev Skills] Docs loaded: 48 sources, ...` at the top of every session in any directory.
2. **Skill matching.** When you ask a question that matches a skill's trigger phrases (e.g. *"review my validator"*, *"scaffold a Cardano project"*), the agent auto-invokes that skill.
3. **Doc consultation** *(in development).* A `UserPromptSubmit` hook scans your prompt for Cardano-specific keywords (`aiken`, `plutus`, `cip-XXXX`, `ogmios`, `drep`, …) and reminds the agent to consult bundled docs before training data or the web.

### When auto-consultation misses

Vague prompts like *"help me build a Cardano dApp"* may not match any specific skill's triggers. In those cases, nudge explicitly:

- *"Check the cardano-dev-skills docs and skills before answering."*
- *"Use the scaffold-project skill to set up a new project."*
- *"Read `docs/sources/aiken/` before writing this validator."*

We're tracking which prompts fail to auto-consult so the keyword set + skill triggers can be tuned over time (observability layer in development).

## Bundled documentation

<!-- COUNT:sources -->48<!-- /COUNT:sources --> Cardano projects mirrored locally. Auto-refreshed every Monday at 06:00 UTC via GitHub Actions — the workflow opens a PR; maintainers review and merge.

Manual refresh:

```bash
./scripts/fetch-docs.sh                          # all sources
./scripts/fetch-docs.sh --source "Source Name"   # one source
```

The fetch script writes a `.manifest.yaml` derived from disk state — so partial and full fetches both leave it accurate.

### SessionStart freshness signals

A `SessionStart` hook (`hooks/check-docs.sh`) inspects the bundled corpus and the current working directory and prints status lines prefixed `[Cardano Dev Skills]`:

- **Docs loaded.** Normal: `Docs loaded: N sources, M files (updated Xd ago)`.
- **Docs stale (>30 days).** Suggests how to refresh based on install topology:
  - Local clone: `cd <plugin-root> && git pull && ./scripts/fetch-docs.sh`.
  - Marketplace install: `Refresh via: /plugin marketplace update easy1staking-com`.
- **Plugin clone behind upstream.** Local clones only: if you have previously run `git fetch` and not pulled, the hook prints `Plugin clone is N commit(s) behind FETCH_HEAD — consider 'git pull' in <plugin-root>`. The hook never fetches itself (no network on session start).
- **Cardano context active.** When `./CLAUDE.md` contains the `cardano-dev-skills` directive block: `Cardano context active in this project.`
- **Cardano context nudge.** When cwd looks like a project (`.git`, `.claude`, or existing `CLAUDE.md`) but has no block: `Tip: run /cardano-context to enable auto-consultation in this project.`

The hook is fail-open: any failure exits 0 silently and never blocks the session. The cwd nudge is suppressed when working inside the plugin repo itself.

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for:

- Source-vetting policy (maintenance bar, what's in scope, what isn't)
- How to add a skill (format, quality bar, no-branded-dApps rule)
- Documentation governance (when to update what)

Quick validation:

```bash
python3 scripts/validate.py        # schema + format checks
./scripts/update-doc-counts.sh     # refresh count placeholders in docs (CI runs --check)
```

## Feedback

We want to know how this works in practice — which skills get used, which prompts miss, which docs are stale, what's missing.

File an issue using the templates at [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/), or open a freeform issue / discussion.

## Architecture

See [docs/DESIGN.md](docs/DESIGN.md) for decisions and rationale.

```
cardano-dev-skills/
├── registry/sources.yaml        ← canonical source list
├── skills/                      ← developer skills (flat layout)
├── docs/sources/                ← extracted upstream docs (auto-refreshed)
├── hooks/                       ← session and prompt hooks
├── scripts/                     ← fetch, validate, update-counts
└── .github/                     ← workflows, issue templates
```

## License

Apache-2.0

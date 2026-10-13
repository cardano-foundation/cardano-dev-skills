# cardano-init

[![CI](https://github.com/input-output-hk/cardano-init/actions/workflows/ci.yml/badge.svg)](https://github.com/input-output-hk/cardano-init/actions/workflows/ci.yml)
[![Code Quality](https://github.com/input-output-hk/cardano-init/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/input-output-hk/cardano-init/actions/workflows/github-code-scanning/codeql)

### Go from zero to a running Cardano protocol in one command.

Pick a tool for each role you need (on-chain, off-chain, devnet, infrastructure, formal-methods) and `cardano-init` generates a monorepo where every component is **already wired together**, plus a worked end-to-end example that **builds and passes its tests out of the box**.

<p align="center">
  <img src="assets/demo.gif" alt="cardano-init scaffolds a full stack in one command, then just test passes out of the box" width="800">
</p>

```console
$ cardano-init --name my-protocol --on-chain <tool> --off-chain <tool> --devnet <tool>

my-protocol/
├── on-chain/     # Validators (smart contracts)
├── off-chain/    # Tx building (protocol transactions)
├── devnet/       # Local chain for integration testing
├── blueprint/    # shared CIP-57 contract interface
├── .env          # shared between components
├── Justfile      # Commands to build, test, and clean
├── AGENTS.md     # Agent brief
└── README.md

$ cd my-protocol && just test
  ✓  All tests passed
```

## Why `cardano-init`?

- ⚡ **Zero to running in one command:** A wired-together monorepo that builds and passes its tests immediately.
- 🧩 **Mix and match, freely:** Components talk to a shared *contract*. So, you can combine tools of different roles however you want and it'll just work.
- 🤖 **Agent-native:** Machine-readable JSON on every command and a generated `AGENTS.md` in every project, so coding agents know what the project is and what to do next.
- 🩺 **Never stuck on setup:** A built-in dependency `doctor` detects your toolchains and tells you the exact installer to run for anything missing.
- 🧪 **Real example:** Every stack ships the same worked gift-card scenario end-to-end, so what you generate actually runs.

## Quick start

### Run without installing

Using npx:
```bash
npx cardano-init help
```
Using nix:
```bash
 nix run github:input-output-hk/cardano-init -- help
```

### Install

Linux and macOS (x86_64 and arm64):
```bash
# macOS / Linux
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/input-output-hk/cardano-init/releases/latest/download/cardano-init-installer.sh | sh
```

Windows:
```powershell
# Windows (PowerShell)
irm https://github.com/input-output-hk/cardano-init/releases/latest/download/cardano-init-installer.ps1 | iex
```

Prefer a specific version or a manual download? Grab it from the [Releases page](https://github.com/input-output-hk/cardano-init/releases).

<details>
<summary><b>With Nix (flake)</b></summary>

```bash
# Install the CLI into your profile
nix profile add github:input-output-hk/cardano-init

# Or run it once, without installing
nix run github:input-output-hk/cardano-init -- help
```
</details>

<details>
<summary><b>With Cargo</b> (requires a recent Rust toolchain, 2024 edition)</summary>

```bash
# From the published repo
cargo install --git https://github.com/input-output-hk/cardano-init

# Or from a clone
cargo install --path .
```
</details>

### Usage

#### Normal workflow

```bash
# 1. Create your project
cardano-init --name my-protocol --on-chain aiken --off-chain meshjs --devnet yaci

# 2. Enter Modify the protocol to you liking
cd my-protocol 

# 3. Run tests often
just test
```

Every generated project is driven by [`just`](https://just.systems): `just build`, `just test`, `just clean`. 
Missing a dependency? Run the built-in dependency doctor `cardano-init doctor` and it tells you exactly how to solve it.

#### Other useful commands

```bash
# Check how to use it
cardano-init help

# Check available tooling
cardano-init list

# Interactive guided setup (the easiest way to start)
cardano-init

# Fullstack: one tool for both on-chain and off-chain, as a single `protocol/` component
cardano-init --name my-protocol --fullstack scalus

# Preview what would be generated, without writing
cardano-init --name my-protocol --on-chain aiken --dry-run

#Check if you have all dependencies needed (inside generated project)
cardano-init doctor

# Add/replace tool
cardano-init add --on-chain plinth

# Remove a tool
cardano-init remove --devnet yaci
```


## Tools

Tools currently in the registry (✅ available · ⬜ planned· 🧪 experimental):


| On-chain | Off-chain | Devnet | Infrastructure | Formal methods |
|----------|-----------|--------|----------------|----------------|
| ✅ Aiken | ✅ MeshJS | ✅ Yaci DevKit | ✅ Kupo | 🧪 Blaster |
| ✅ Scalus | ✅ Scalus | | ✅ Ogmios | |
| ✅ Plinth | ✅ Evolution SDK | | ✅ Dolos | |
| ⬜ Pebble | 🧪 Tx3 | | ✅ Tx Submit API | |
| ⬜ Plutarch | ⬜ Lucid Evolution | | ✅ Cardano Node | |
| ⬜ Opshin | ⬜ Blaze | | ✅ Cardano Node API | |
| | ⬜ Elm Cardano | | ✅ Dingo | |
| | ⬜ PyCardano | | | |


You can also check locally with `cardano-init list --table`.
Infrastructure provisioned via [cardano-up](https://github.com/blinklabs-io/cardano-up).

## User Documentation

Full user docs live in **[docs/USER_DOCS.md](docs/USER_DOCS.md)**:

- [How it works](docs/USER_DOCS.md#how-it-works) — roles, the interface contract, the worked gift-card example, fullstack tools, and compatibility checks
- [For coding agents](docs/USER_DOCS.md#for-coding-agents) — the machine-readable interface and generated `AGENTS.md`
- [How it relates to `aikup`, `cardano-up`, and friends](docs/USER_DOCS.md#how-it-relates-to-aikup-cardano-up-and-friends)
- [Infrastructure providers](docs/USER_DOCS.md#infrastructure-providers)

## Development Documentation

Internal CI (smoke tests, installer recipes, devnet):

[![Scheduled Smoke](https://github.com/input-output-hk/cardano-init/actions/workflows/scheduled-smoke.yml/badge.svg)](https://github.com/input-output-hk/cardano-init/actions/workflows/scheduled-smoke.yml)
[![Installer Recipes](https://github.com/input-output-hk/cardano-init/actions/workflows/installer-recipes.yml/badge.svg)](https://github.com/input-output-hk/cardano-init/actions/workflows/installer-recipes.yml)
[![Devnet Smoke](https://github.com/input-output-hk/cardano-init/actions/workflows/devnet-smoke.yml/badge.svg)](https://github.com/input-output-hk/cardano-init/actions/workflows/devnet-smoke.yml)

| Doc | Purpose |
|-----|---------|
| [docs/PRD.md](docs/PRD.md) | Product requirements: who it's for, problem, scope, success metrics |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, module structure, data model, pipeline |
| [docs/TECH_SPEC.md](docs/TECH_SPEC.md) | Exact contracts, schemas, algorithms, edge cases |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phases & milestones (DX.02, DX.05) |
| [docs/ADDING_A_TOOL.md](docs/ADDING_A_TOOL.md) | Contributor guide for integrating a new tool |
| [docs/RELEASING.md](docs/RELEASING.md) | How to cut a release and publish prebuilt binaries (cargo-dist) |


```bash
cargo build       # build
cargo test        # run tests
cargo fmt         # format
cargo clippy      # lint
```

A Nix flake is provided. Use `nix develop` for a dev shell with the Rust toolchain, or `nix build .#cardano-init` to build the package.

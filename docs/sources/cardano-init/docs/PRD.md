# cardano-init: Product Requirements Document

**Status:** Draft · **Last updated:** 2026-06-01 · **Owner:** Robertino Martinez

> Companion documents: [ARCHITECTURE.md](./ARCHITECTURE.md) (system design), [TECH_SPEC.md](./TECH_SPEC.md) (technical decisions, contracts, data models), [ROADMAP.md](./ROADMAP.md) (phases and milestones). This PRD owns the *why* and *for whom*; those documents own the *how* and *when*.

---

## 1. Summary

`cardano-init` is a CLI tool that scaffolds a complete, runnable Cardano protocol monorepo. The user picks a tool for each functional role they need (on-chain, off-chain, infrastructure, devnet, and other registry-defined roles) and the tool generates a project where every component is already wired together and a small end-to-end example builds and passes its tests out of the box.

The defining bet is the **interface contract**: every tool template conforms to a shared set of conventions (canonical blueprint path, standard Justfile tasks, standard `.env` variables) so *any* producer composes with *any* consumer without per-pair integration code. Adding a tool is a data change, not a code change.

---

## 2. Problem

Two distinct pains block people from starting a Cardano protocol project:

1. **Cross-tool wiring is hard and undifferentiated work.** Individual tools ship their own `init` (`aiken new`, etc.), but nothing wires *across* roles. Connecting an on-chain validator to an off-chain transaction builder, off-chain with local infrastructure or a local devnet, on-chain with formal methods, environment variables, build commands across tools, etc. This takes time, is error-prone, and has to be redone for every new combination of tools.

2. **The tooling landscape is opaque to newcomers.** A developer arriving at Cardano faces choice paralysis: which tool writes validators, which builds transactions, which indexes the chain, and which of them actually work together? The cost of a wrong early choice is high, and there is no opinionated, trustworthy starting point that explains the landscape while setting them up.

`cardano-init` attacks (1) with the interface contract and a generic composition pipeline, and (2) with a curated, self-describing tool registry plus guided selection and recommendations.

### Why now / why this and not `aiken new`

We needed this years ago. Cardano developer experience is not great at many points of the develpment cycle, but getting started is one of the worst and most notable. Since onboarding is suffered by newcomer developers exploring Cardano, having a bad and confusing developer experience means their first impression incentivizes them to move away to other ecosystems. A tool that solve the "choosing the stack and setting up the project" problem means more people will be able to pass through those initial hurdles and get to building their own project faster.

Per-tool scaffolders solve the single-tool case and stop at the role boundary. The value here is precisely the seam *between* tools: the part no single tool owns. As the Cardano tooling ecosystem fragments across languages (Aiken, Haskell/Plinth, Scala/Scalus, TypeScript) the combinatorial wiring problem gets worse, and a contract-based composer is an approach that doesn't scale as O(tools²).

---

## 3. Target users (personas)

### 3.1 Primary: Cardano newcomer

A competent developer (possibly new to blockchain entirely) who does not know the Cardano tooling landscape. **We optimize for this persona when tradeoffs arise:** 
- Explanation over terseness.
- Sane defaults over open-ended choices.
- And a project that runs immediately so they can see the shape of a working protocol before writing anything themselves.

### 3.2 Primary: Coding agents

LLM-driven agents (e.g. Claude Code) scaffolding a project on a user's behalf. Agents are a **first-class consumer end-to-end:**
- **They drive the CLI:** One-shot mode must be rock-solid, deterministic output, stable machine-parseable flags, meaningful exit codes, no TTY assumptions.
- **They discover capabilities:** An agent must learn what roles and tools exist without guessing, via a structured (JSON) registry dump it reads before composing a command.
- **They read the generated output:** Predictable structure, self-explanatory READMEs, and the interface contract documented in-repo so the agent can keep building inside the project.
- **They need actionable errors:** Invalid selections must produce machine-readable, corrective errors (e.g. "tool X does not fill role Y; valid tools: …") rather than dropping into an interactive re-prompt.

### 3.3 Secondary: Experienced Cardano developer

Already ships Cardano code; wants a fast, opinionated starting point to skip boilerplate. Benefits from one-shot mode, sane defaults, and the contract, but we do not sacrifice newcomer/agent ergonomics to serve this persona.

---

## 4. Goals & success metrics

The PRD commits to two headline metrics. Both are measurable in CI and tied to the two core problems.


| # | Metric | Target | Measurement |
|---|--------|--------|-------------|
| **SM-1** | **Generated project builds out of the box** | `just build && just test` passes for **every shipped template, verified individually**, with **zero manual edits**. Composition across roles is guaranteed by the interface contract, so combinations are not tested pairwise. | CI scaffolds each tool/template in isolation, then runs build+test with required toolchains present. |
| **SM-2** | **Time-to-first-working-protocol (TTFP)** | **< 5 minutes** from `cardano-init` to a green `just build && just test`. If toolchains are missing and the user accepts the offered install, that path must also complete within ~5 minutes. | Timed walkthrough of a representative selection on a clean machine. Clock excludes nothing the user experiences except their own reading time. |


**Supporting (tracked, not headline):** tool/role coverage and composability (every advertised role has ≥1 working tool; any on-chain × off-chain combo works without per-pair code); adoption (projects generated, repos that retain the scaffold structure) once the tool is public.

---

## 5. Scope

### 5.1 In scope for v1

- **Roles are a fixed, code-defined vocabulary; tools are the open-ended part.** The set of roles is defined in code, not data: the registry *references* roles but cannot introduce them. It is *not* frozen at "four": the current set is on-chain, off-chain, infrastructure, devnet, and formal-methods, and it can grow in a future version via a deliberate code change. **Tools**, by contrast, are fully data-driven: adding one is a registry + template change with no core code change (see [ARCHITECTURE.md](./ARCHITECTURE.md) §3.1).
- **At least one working tool per advertised role.** No role is advertised with zero working tools. There is no single "golden path" combination: every shipped tool is verified individually and the interface contract guarantees that any combination composes (§7), so combinations are not tested pairwise.
- **Whatever ships in the registry must work.** Every registered tool is held to the build/contract bar; adding a tool requires adding its tests (§7, SM-1).
- **Two surfaces**: One-shot CLI and interactive CLI (§6).
- **Interface contract** enforced mechanically by contract-compliance tests.
- **Target network is selectable:** `preview` / `preprod` / `mainnet`, defaulting to **`preview`** (the natural starting point for newcomers). The choice is written to `.env` as `CARDANO_NETWORK`, so it is a cheap, late-binding decision, trivially changed after generation.
- **Dependency doctor (check + advise):** Detect which `system_deps` are missing, detect the OS and available package manager, and print exact install instructions. For the **infrastructure** role, the recommended install path delegates to `cardano-up`.
- **User documentation:** Thorough user documentation to be used both by developers and LLM agents. Also, links and references to documentation and Discord servers based on the user chosen stack on the generated README.

### 5.2 Explicit non-goals

These are things users might reasonably expect that we deliberately will **not** do:

- **Not a build / deploy / runtime tool.** It scaffolds once and exits. It does not build, deploy, submit transactions, manage keys or wallets, or run the protocol. The generated Justfile delegates to native tools; `cardano-init` is not in the loop after generation.
- **Not a package or version manager.** It does not pin/upgrade tool versions over time, or manage tool/dependency *versions* after generation. Editing the project's *composition* is supported (see below), but bumping the tooling itself is out of scope. (Off-chain packages are still version-pinned in the generated `package.json` etc.; the user owns them thereafter.)

> **Note — editing an existing project (FR-25):** the project's *role/tool composition* **is** editable after generation via `cardano-init add`/`remove` (swap Aiken→Pebble, add off-chain, drop a role). This adds/removes/replaces whole component folders and re-wires the shared top-level files; it never rewrites user code inside a component it keeps, and it is guarded by a git-clean check so every change is reviewable with `git diff`. It recovers the current selection by **detection** (no metadata file — matching the doctor, TECH_SPEC §9.6). See TECH_SPEC §15. This is deliberately *not* version management (above).
- **Not a tutorial or learning platform.** Generated READMEs/AGENT.md/docs/skills explain enough to start and link out, but the tool is not a course, interactive tutorial, or docs site. It produces a runnable example, not curriculum.
- **It does not author tool templates for you.** Adding a tool requires a human to write the template + registry entry and recompile. The tool does not auto-generate templates or scrape tool capabilities.

### 5.3 Deferred (post-v1)

- Dependency doctor **auto-install** (running installs with consent): a nice-to-have targeted for the RC ([ROADMAP](./ROADMAP.md) DX.05); `cardano-up` is installed as a dependency like `aikup`. (The standalone `cardano-init doctor` command is **not** deferred: it's a DX.02 deliverable.)
- Plugin / lifecycle hooks for tools, if and when needed (e.g. "after scaffolding, run `devkit start`").
- Config-file driven runs beyond flags, if needed.

See [ROADMAP.md](./ROADMAP.md) for sequencing.

---

## 6. Surfaces (all v1)

Both surfaces produce identical projects because the CLI is the **single source of truth** for generation.

| Surface | Primary persona | Description |
|---------|-----------------|-------------|
| **One-shot CLI** | Agent, experienced dev | Fully flag-driven, non-interactive, deterministic. Plus capability discovery (structured registry dump), `--dry-run`, and machine-readable errors. |
| **Interactive CLI** | Newcomer | Guided flow: explain the domain → multi-select roles → pick a tool per role (with recommendations) → set options → review summary + file tree → confirm. |


In all cases, there will be extensive explanation on each tooling role, language, when (and when not) to use it, mapping of usecases and common tooling, and other to help both newcommers and LLM agents to choose the right tool for the job without them having to do reasearch on the side.

---

## 7. Functional requirements

Priority: **M** = Must (v1), **S** = Should (v1 if affordable), **C** = Could (later).

### Selection & roles

- **FR-1 (M):** The user can select one or more roles; they are not required to fill all roles. A single-role project (e.g. on-chain only) is valid.
- **FR-2 (M):** At most one tool per role, **except infrastructure**, which may have multiple tools simultaneously.
- **FR-3 (M):** The set of roles and tools is loaded from the embedded registry; no role or tool is hard-coded in CLI logic.
- **FR-4 (S):** During interactive selection, the tool surfaces recommendations for remaining roles based on choices made so far (e.g. tools that pair well / share a language).

### Generation

- **FR-5 (M):** Generate a monorepo with role directories **only** for selected roles, plus a base layer present in every project: a top-level orchestrating `Justfile`, a top-level README explaining the full architecture, `.gitignore`, `.env` (always: it seeds `CARDANO_NETWORK` and the standard chain connection vars), and the `blueprint/` directory (present for every project except infrastructure-only: so every blueprint-consuming role has a stable path and a user can drop in an external `plutus.json`; the `plutus.json` file itself is produced by on-chain `build`).
- **FR-6 (M):** Every generated project includes a **simple but complete, runnable example** that demonstrates the selected components working *together*, not in isolation.
- **FR-7 (M):** Composition is generic. The pipeline wires components using only the set of present roles and the interface contract, with **no per-tool-pair logic**.
- **FR-8 (M):** Per-component `Justfile`s expose standardized targets (`build`, `test`, `clean`; plus an optional `dev` when the tool has a watch/daemon/devnet mode). The top level aggregates only the terminating, composable tasks — `build`, `test`, `clean` — delegating to each component (`test` builds the on-chain blueprint first, then runs each component's `test` in role order); `dev`, where present, is run per-component by the developer and is not aggregated.
- **FR-9 (S):** Optional Nix flake (`flake.nix`) providing a dev shell with all required toolchains, opt-in at selection time. Without Nix, prerequisites are documented in the README.

### Interface contract (mechanically enforced, see TECH_SPEC)

- **FR-10 (M):** On-chain templates produce the CIP-57 blueprint at the canonical path (`blueprint/plutus.json`) during `build` and other roles (e.g. off-chain, devnet, formal-methods) read it from the same path.
- **FR-11 (M):** Whichever component provisions a local chain endpoint writes standardized connection details to `.env` (e.g. `INDEXER_URL`) during `dev` — an infrastructure service, or a local devnet in the devnet role (e.g. Yaci DevKit); consumers read from there and react only to the presence of the keys, not to which role wrote them.
- **FR-12 (M):** Every template works **independently** (e.g., its `just build` succeeds with no other roles present), and has to handle all shared `just` commands. It can optionally add more to be ran on that role's folder, but it can't avoid handling the shared ones (it should, at least, print a message).

### Agent affordances

- **FR-13 (M):** A capability-discovery command emits the registry (roles, tools, which roles each tool fills, languages, deps) in two forms derived from the same data: a **human-readable listing** (`--list`) usable by people at the terminal, and a **structured machine-readable** form (e.g. JSON) for programmatic/agent consumption.
- **FR-14 (M):** One-shot mode is fully non-interactive and **deterministic** (same inputs → same output), with stable flags and meaningful exit codes.
- **FR-15 (M):** Invalid selections produce **actionable, machine-readable** errors (offending input + valid alternatives) and never fall back to interactive prompting in non-interactive mode.
- **FR-16 (M):** `--dry-run` prints exactly what would be generated and writes nothing.

### Dependency doctor (v1: check + advise)

- **FR-17 (M):** After (or before) generation, detect which required `system_deps` are missing on the user's machine.
- **FR-18 (M):** Detect the host OS and available package manager(s) and print the **exact install commands** for the missing dependencies.
- **FR-19 (M):** For the **infrastructure** role, the advised install path uses `cardano-up` as the primary mechanism for provisioning infra tooling. If `cardano-up` itself is absent, v1 instructs the user to install it (auto-install is deferred, §5.3).
- **FR-20 (M):** If dependencies cannot be satisfied, clearly tell the user which to install manually and state that the generated template is otherwise correct and ready once they do.
- **FR-21 (C):** Offer to **run** the installs with user consent (auto-install). *Nice-to-have, targeted [ROADMAP](./ROADMAP.md) DX.05.*
- **FR-22 (S):** Expose the doctor as a standalone `cardano-init doctor` subcommand runnable in an existing project. *Targeted DX.02.*
- **FR-25 (S):** Edit an existing project's role/tool composition via `cardano-init add`/`remove`: reconstruct the current selection by detection, apply the change (add/remove/replace whole component folders, re-wire the shared top-level files), and never touch user code in a kept component. Guarded by a git-clean check (`--force` to override) with a `--dry-run` preview; reuses the init compatibility/experimental gates on the resulting selection. Not version management (§5.2). See TECH_SPEC §15.

### Versioning & updates

- **FR-24 (S):** On startup, the tool performs a best-effort check for a newer `cardano-init` release and, if one exists, notifies the user and suggests updating **before generation** (so they can update and regenerate rather than discovering it post-write). It is cached once/day, gated to interactive/human-TTY runs (skipped for `--format json`/non-TTY), and bounded: latency is hidden behind interactive selection, or capped at a short deadline (~1s) for human one-shot. It never blocks beyond that deadline, never alters generated output, and degrades silently when offline. It is the chosen mechanism for keeping templates fresh without runtime template fetching (see A-3; details in TECH_SPEC §10).

---

## 8. User stories & acceptance criteria

> Format: **As a … I want … so that …**, followed by acceptance criteria.

### US-1: Newcomer, guided setup

*As a developer new to Cardano, I want a guided flow that explains the roles and recommends tools, so that I can create a working project without already knowing the ecosystem.*

**Acceptance:**
- Running `cardano-init` with no arguments enters the interactive flow and explains what each role means before asking the user to choose.
- The user can complete the flow selecting only the roles they want.
- A summary screen shows the full selection and the exact directory tree before anything is written; the user must confirm.
- On confirmation, the project is generated and the next steps (`cd …`, `just build`) are printed.

### US-2: Newcomer, it just works

*As a newcomer, I want the generated project to build and pass tests immediately, so that I know my setup is correct and can see a working protocol.*

**Acceptance (SM-1, SM-2):**
- With the required toolchains present, `just build && just test` passes with zero manual edits for any combination of tools.
- The end-to-end example demonstrates the selected roles working together.
- TTFP is < 5 minutes for any selection.

### US-3: Newcomer, missing toolchains

*As a newcomer who doesn't have the toolchains installed, I want the tool to tell me exactly what's missing and how to install it, so that I'm not stuck deciphering errors.*

**Acceptance (FR-17–FR-20):**
- The tool reports which `system_deps` are missing.
- It prints exact install commands for the user's OS/package manager and links to relevant documentation.
- For infrastructure deps, it advises the `cardano-up` path.
- If it cannot help, it lists what to install manually and confirms the template is otherwise ready.

### US-4: Agent drives the CLI

*As a coding agent, I want to discover available tools/roles as structured data and then generate a project non-interactively, so that I can scaffold on a user's behalf reliably.*

**Acceptance (FR-13–FR-16):**
- The agent can obtain the full registry as JSON in one command. 
- The agent should have enough information to chose the tool or ask an informed decision to the developer based on what the developer asked it to build.
- A one-shot invocation with valid flags generates the project with no prompts and a zero exit code; identical inputs yield identical output.
- An invalid invocation exits non-zero with a machine-readable message naming the problem and the valid options, without prompting.
- `--dry-run` reports the plan and writes nothing.

### US-5: Agent continues in the project

*As a coding agent, after scaffolding I want predictable structure and the contract documented in-repo, so that I can keep building without guessing conventions.*

**Acceptance (FR-5, FR-8, §5.2 docs):**
- The directory layout matches the documented canonical structure.
- The interface contract (canonical paths, env vars, Justfile tasks) is discoverable from within the generated project.
- There are documentation and tools (README.md, AGENT.md, skills directory, MCPs, etc.) to provide the best support possible for the agent to iterate over the code.

### US-6: Single-role project

*As a developer who only needs validators, I want to scaffold an on-chain-only project, so that I'm not forced into components I don't need.*

**Acceptance (FR-1, FR-12):**
- Selecting only one role (e.g. on-chain) generates only the role's directory (e.g., on-chain) plus base files.
- `just *` succeeds with no other roles present.

### US-7: Extending with a new tool

*As a tool author, I want to add support for my tool by writing data and a template, so that it composes with every existing tool without combinatorial work.*

**Acceptance (FR-3, FR-7, §7):**
- Adding a registry entry + template(s) + recompiling makes the tool available in all surfaces with no CLI code changes.
- A new tool that satisfies the contract composes with existing tools in other roles without per-pair logic.
- New tools ship with tests verifying contract compliance and that they build (SM-1).

---

## 9. Assumptions & dependencies

- **A-1:** Users have, or are willing to install, the native toolchains for their chosen tools (the tool advises but, in v1, does not install them automatically; Nix is the supported turnkey path).
- **A-2:** `cardano-up` is the intended primary mechanism for provisioning infrastructure tooling; v1 assumes the user can install `cardano-up` when advised.
- **A-3:** Generation is **offline and deterministic**: the registry and all templates are embedded in the binary at compile time and are the single source of truth for a given version, so the same binary + inputs always produce the same project (required by FR-14, SM-1, and agent trust). The tool does **not** fetch templates at runtime. Template/tool freshness is handled out-of-band by notifying the user when a newer `cardano-init` is available (an explicit binary update), never by silently changing generation output. Network is only needed for installing toolchains/deps and for the version-update check (FR-24).
- **A-4:** `just` is the task runner for all generated projects.
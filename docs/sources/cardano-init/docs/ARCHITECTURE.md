# cardano-init: Architecture

**Status:** Draft · **Last updated:** 2026-06-01 · **Owner:** Robertino Martinez

> This is the **canonical** architecture document. It supersedes the legacy root-level `REQUIREMENTS.md` and `ARCHITECTURE.md` (now deleted; available in git history). Read [PRD.md](./PRD.md) for the *why* and *for whom*; this document owns the *how*. Detailed contracts, data shapes, and edge cases live in [TECH_SPEC.md](./TECH_SPEC.md); sequencing lives in [ROADMAP.md](./ROADMAP.md).

---

## 1. Design principles

Five principles drive every structural decision in the codebase. When a tradeoff arises, these are the tie-breakers.

1. **The interface contract is the core abstraction.** Every tool template conforms to a shared set of conventions (canonical blueprint path, standard Justfile tasks, standard `.env` variables). Because each template *independently* conforms, any producer composes with any consumer **without per-pair integration code**. Composition is generic over the *set of roles present*, never over *which tools fill them*. This is what makes the system scale as O(tools) rather than O(tools²).

2. **Tools are data-driven; roles are a fixed code vocabulary.** Tools and templates are declarative data embedded at compile time: adding a *tool* is a data change (a TOML file + a template directory + a recompile), never a change to CLI logic. **Roles**, by contrast, are a small fixed vocabulary defined in code (the `Role` enum, §3.1): the registry *references* roles but cannot introduce them. The set is not frozen at a particular number (it can grow) but growing it is a deliberate, rare code change, not a data change.

3. **Pure core, impure edges.** `registry/`, `scaffold/`, `contract`, and the pure part of `doctor/` are pure logic over data with **zero dependency on `cli/`**. All user interaction, terminal formatting, network, and system probing live at the edges (`cli/`, the impure half of `doctor/`). This keeps the core testable and makes future extraction straightforward.

4. **Deterministic generation.** Identical inputs produce byte-identical output. This is a hard requirement for coding-agent trust, reproducibility, and snapshot tests. Determinism is guaranteed at the **planning** phase (§6.4).

5. **Offline and self-contained.** The registry and all templates are embedded in the binary; generation makes no network calls. Network is used only for installing toolchains (the doctor) and a best-effort version-update notice (§9). The binary, for a given version, is the single source of truth for what it generates.

---

## 2. Crate & module structure

A single Rust crate. The boundary between "library logic" and "CLI concerns" is enforced by the module dependency graph (§2.2), not by separate crates. Items marked **(planned)** are introduced by the PRD and not yet implemented.

```
cardano-init/
├── Cargo.toml
├── src/
│   ├── main.rs                 # Entry point: delegates to cli::run()
│   │
│   ├── cli/                    # Impure edge: user interaction, formatting, process control
│   │   ├── mod.rs              # Arg parsing (clap), dispatch, top-level error type
│   │   ├── interactive.rs      # Guided interactive flow (dialoguer)
│   │   ├── oneshot.rs          # Flag → Selection, validation, machine-readable errors
│   │   ├── output.rs           # Presenter: renders results/errors as human text or JSON
│   │   ├── theme.rs            # Terminal styling palette (console)
│   │   ├── git.rs              # git helpers: clean-tree gate + init a new project's repo
│   │   └── update.rs           # add/remove: mutate an existing scaffolded project (§6.4, TECH_SPEC §15)
│   │
│   ├── registry/               # Pure: tool + role definitions from embedded TOML
│   │   ├── mod.rs
│   │   ├── types.rs            # Role, ToolDef, RoleConfig, Selection, Network, Seam, …
│   │   ├── loader.rs           # rust-embed → Registry (indexed by id and by role)
│   │   ├── compat.rs           # off-chain ↔ provider (devnet+infra) seam compatibility
│   │   └── view.rs             # read-only projections of the registry (for `list`)
│   │
│   ├── scaffold/               # Pure: project generation pipeline
│   │   ├── mod.rs              # Orchestrator (scaffold / dry_run) + embedded templates
│   │   ├── context.rs          # Phase 1: Selection + Registry → TemplateContext
│   │   ├── planner.rs          # Phase 2: → FilePlan (canonical order; dry-run stops here)
│   │   ├── renderer.rs         # Phase 3: MiniJinja render / pass-through
│   │   └── writer.rs           # Phase 4: the only phase with disk side effects
│   │
│   ├── doctor/                 # Dependency detection + install advice (§8)
│   │   ├── mod.rs              # Pure: (deps, environment) → missing + advice
│   │   ├── catalog.rs          # Pure: loads registry/deps.toml → dep recipes
│   │   ├── installers.rs       # Pure: closed Installer vocabulary + command templating
│   │   └── probe.rs            # Impure: detect OS, package managers, PATH
│   │
│   └── contract.rs             # Interface-contract constants (paths, env vars, dirs)
│
├── registry/tools/             # Embedded data: one TOML per tool (15 tools)
│   ├── aiken.toml  plinth.toml  scalus.toml                       # on-chain
│   ├── meshjs.toml  evolution.toml  tx3.toml                      # off-chain
│   ├── cardano-node.toml  cardano-node-api.toml  dingo.toml       # infra
│   ├── dolos.toml  kupo.toml  ogmios.toml  tx-submit-api.toml     # infra
│   ├── yaci.toml  blaster.toml                                    # devnet / formal-methods
│
└── templates/                  # Embedded data: tool/role template trees
    ├── _base/    (Justfile.jinja, README.md.jinja, AGENTS.md.jinja, CLAUDE.md, gitignore, env.jinja)
    ├── _nix/     (flake.nix.jinja)
    └── <tool>/<role>/  (manifest.toml + template files)
```

Assets are embedded with **rust-embed** via `#[folder = "registry/"]` and `#[folder = "templates/"]`. There is **no `build.rs`**: embedding is handled by the derive macro directly. (The legacy architecture doc referenced a `build.rs` asset manifest; that is obsolete.)

### 2.2 Module dependency graph

The graph flows strictly downward; there are no cycles. The key invariant: **`registry`, `scaffold`, `contract`, and the pure part of `doctor` never depend on `cli`.**

```
main.rs
  │
  ├── cli/ ──────┬─▶ scaffold/ ─▶ registry/
  │              ├─▶ doctor/   ─▶ registry/
  │              ├─▶ registry/
  │              └─▶ contract
  │
  scaffold/, doctor/(pure), registry/  ──▶  contract
```

`cli/` is the **edge**: it orchestrates the pure core and presents results. It is not depended upon by the core.

---

## 3. Data model

All core types live in `registry/types.rs` (and `scaffold/` for pipeline-internal types). Exact field-level definitions and invariants are in TECH_SPEC; this is the shape and intent.

### 3.1 Roles

```rust
pub enum Role { OnChain, OffChain, Infrastructure, Devnet, FormalMethods }
```

- `Role::ALL` defines the **canonical order** used for deterministic output.
- Each role maps to a kebab string (`on-chain`, `formal-methods`, …) for TOML/flags, a `Display` name for humans, and a contract directory (`dir()` → §4).
- **The enum is the sole source of truth for the role vocabulary: roles are *not* defined by the repository data.** A tool's `[roles.<kebab>]` blocks merely *reference* existing roles; the registry cannot introduce a new one. Role strings are validated against the enum at load time via `Role::from_kebab` (an unknown role → `RegistryError::UnknownRole`). What the registry data determines is which *tools* exist and which of these fixed roles each can fill, not the set of roles itself.
- Adding a role is therefore a deliberate code change touching every site that names roles: a new `Role` variant + `Role::ALL` + `from_kebab`/`as_kebab`/`dir()`/`Display`, a `contract::DIR_*` constant, `TemplateContext` handling, and a CLI flag. Adding a *tool*, by contrast, is pure data. The role set is small and grows rarely.
- The **fullstack `protocol/`** component (§3.2) is a related but distinct kind of code change: it adds a `contract::DIR_PROTOCOL` constant and `TemplateContext` handling, but **no** `Role` variant — it is a *fused component* derived from two existing roles, not a sixth role. New fullstack *tools* remain pure data (a `[fullstack]` table + a template dir).

### 3.2 Tools

```rust
pub struct ToolDef {
    pub id, name, description, website: String,
    pub languages: Vec<String>,
    pub nix_packages: Vec<String>,         // toolchains for the Nix dev shell
    pub roles: HashMap<Role, RoleConfig>,  // which roles this tool can fill
    pub fullstack: Option<RoleConfig>,     // unified on-chain+off-chain template (opt-in)
}
pub struct RoleConfig { pub template: String }  // path under templates/
```

`system_deps` is declared in the tool TOML and consumed by the **doctor** (§8). One tool can fill multiple roles (e.g. Scalus: on-chain + off-chain), each with its own template path.

**Fullstack tools.** A tool that fills both on-chain and off-chain may also declare a `[fullstack]` template. When the *same* tool fills both roles, the two collapse into one **fused `protocol/` component** (built from `fullstack.template`) instead of two folders — the value of a same-language stack (shared types, one build, no `plutus.json` round-trip between the halves). This is a tool *capability*, **not a new role**: `protocol` has no `Role` variant and `Role::ALL` stays at five; the collapse is *derived* from the selection at planning time, mirroring the infrastructure aggregation (§6.2). The `protocol/` component still conforms to the interface contract — its `build` writes the blueprint and it reads/writes `.env` — so it composes with every other role like a normal on-chain producer (§4).

### 3.3 Selection (the resolved user choice)

```rust
pub struct Selection {
    pub project_name: String,
    pub assignments: Vec<RoleAssignment>,  // Infrastructure may appear multiple times
    pub network: Network,                  // Always Preview; switch via CARDANO_NETWORK in the generated .env
    pub nix: bool,
}
pub struct RoleAssignment { pub role: Role, pub tool_id: String }
```

**Constraint enforcement is by construction.** Role uniqueness (one tool per role, except Infrastructure) is enforced at the edge: interactive mode only allows one tool per non-infra role; one-shot uses single-value flags per role (`--infra` is repeatable). A `Selection` that exists is valid: there is no separate validation module.

### 3.4 Pipeline types (`scaffold/`)

```rust
pub struct TemplateContext { … }   // per-role flags + RoleContexts + contract constants
pub struct RoleContext { tool_id, tool_name, language, dir }
pub struct FilePlan { entries: Vec<FileEntry> }
pub struct FileEntry { dest: PathBuf, source: TemplateSource, render: bool }
pub enum TemplateSource { Base(String), Role(String), Optional(String), Inline(Vec<u8>) }
```

`TemplateContext` is `Serialize` and is the entire surface templates can see. It carries `has_*` booleans per role, an `Option<RoleContext>` per single-tool role, `infra_tools: Vec<InfraToolContext>` plus `infra_context_name` and the resolved `infra_env` (the aggregated infra component, TECH_SPEC §4.6), the contract constants (`blueprint_path`, `env_vars`), and Nix info. `render` is derived from the `.jinja` extension.

---

## 4. Interface contract (`contract.rs`)

The contract is a set of constants every template conforms to. It is the seam that makes composition generic.

```rust
pub const BLUEPRINT_PATH: &str = "blueprint/plutus.json";
pub const DIR_ON_CHAIN = "on-chain"; DIR_OFF_CHAIN = "off-chain";
pub const DIR_INFRA = "infra"; DIR_DEVNET = "devnet"; DIR_FORMAL_METHODS = "formal-methods";
pub const DIR_PROTOCOL = "protocol";   // fused on-chain+off-chain component (fullstack, §3.2)
pub const ENV_INDEXER_URL = "INDEXER_URL"; ENV_INDEXER_PORT = "INDEXER_PORT";
pub const ENV_NODE_SOCKET_PATH = "NODE_SOCKET_PATH"; ENV_NETWORK = "CARDANO_NETWORK";
// Provider-specific endpoints, seeded empty and populated when the matching
// infrastructure provider is provisioned:
pub const ENV_OGMIOS_URL = "OGMIOS_URL"; ENV_TX_SUBMIT_URL = "TX_SUBMIT_URL";
pub const ENV_DOLOS_GRPC_URL = "DOLOS_GRPC_URL"; ENV_CARDANO_NODE_API_URL = "CARDANO_NODE_API_URL";
```

`DIR_PROTOCOL` is the one directory not backed by a `Role` (§3.2): a fullstack tool's fused
component. Its `build` still produces `BLUEPRINT_PATH` — it is the on-chain producer for its
project — so it is a full contract citizen; fullstack only privatizes the *internal*
on-chain↔off-chain link between its two halves.

**Compliance checklist (enforced mechanically by contract-compliance tests):**

- **Every template** ships a `Justfile` exposing `build`, `test`, `clean`, and works **independently** (its `just build` succeeds with no other roles present). A no-op-for-this-tool target among those three still exists (printing a message is fine). **`dev` is optional** — provided only when the tool has a real watch/daemon/devnet mode. The **top level** aggregates only `build`/`test`/`clean`; `dev`, where present, is per-component (§6.2 / TECH_SPEC §7.2), never aggregated.
- **On-chain** produces the CIP-57 blueprint at `../blueprint/plutus.json` during `build`. Other roles read it from that path if present.
- **The component that provisions a local chain endpoint** writes the standard connection vars to `../.env` during its `dev`. This is **role-agnostic** — usually an *infrastructure* service, but a local devnet such as Yaci DevKit in the *devnet* role does it too. Role = a tool's *purpose*; writing `.env` = the orthogonal *capability* of exposing a local endpoint. Consumers react to the presence of `INDEXER_URL`, never to which role set it (principle 1).
- **Off-chain / devnet / formal-methods** read the blueprint and `.env` if present, and degrade gracefully when absent.

Layered on top of that mechanical seam is a **shared worked example**: every on-chain and off-chain template implements the same **gift card** (a one-shot minting policy plus a `redeem` spending validator) with a common parameter/redeemer ABI. The mechanical contract makes tools *pluggable*; the shared example makes a mixed pair actually *work end-to-end* — the off-chain template parameterizes the compiled validators straight from the blueprint, so e.g. the Scalus off-chain drives an Aiken contract, and MeshJS drives a Scalus one. See ADDING_A_TOOL.md ("The reference example: Gift Card") for the exact ABI a new tool must match.

The `blueprint/` **directory** is scaffolded whenever any blueprint-producing-or-consuming
role is present, every project except infrastructure-only (§6.2), so the canonical
path exists wherever it's meaningful; the `plutus.json` **file** within it may still be
absent (no on-chain role, or no build yet), which is why consumers must tolerate its
absence. The CLI never tracks which tools produce/consume blueprints: it is a
template-level convention verified by tests, not registry metadata.

---

## 5. Registry

Each tool is one TOML file under `registry/tools/`:

```toml
[tool]
id = "aiken"
name = "Aiken"
description = "…newcomer-friendly explanation…"
website = "https://aiken-lang.org"
languages = ["aiken"]
system_deps = ["aiken"]    # abstract dep ids → resolved via registry/deps.toml (§8)
nix_packages = ["aiken"]       # packages for the generated Nix dev shell

[roles.on-chain]
template = "aiken/on-chain"    # path under templates/
```

`loader.rs` iterates embedded assets, parses each TOML into a `ToolDef`, and builds a `Registry` with two indexes: `by_id` (lookup) and `by_role` (list tools for a role). Loading rejects duplicate ids and an empty registry. The registry is immutable after load.

---

## 6. Scaffolding pipeline

Four independent, individually testable phases. `--dry-run` stops after phase 2.

```
Selection + Registry
        │
        ▼
┌────────────────┐   ┌──────────────┐   ┌──────────────┐   ┌───────────────┐
│ 1. Context     │──▶│ 2. Plan      │──▶│ 3. Render    │──▶│ 4. Write      │
│ build_context()│   │ plan()       │   │ render()     │   │ write()       │
│ (pure)         │   │ (pure)       │   │ (pure)       │   │ (side effects)│
└────────────────┘   └──────────────┘   └──────────────┘   └───────────────┘
                         │
                    --dry-run exits here (returns FilePlan)
```

### 6.1 Context (`context.rs`)

Walks `selection.assignments`, resolves each tool against the registry, and builds the `TemplateContext`: per-role `has_*` flags and `RoleContext`s, deduplicated `nix_packages`, contract constants, and `.env` variable seeds. Errors on unknown tool or role mismatch.

### 6.2 Plan (`planner.rs`)

Produces the ordered `FilePlan`:
1. **Base layer** (always): `Justfile`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `.gitignore`, `.env`.
2. **Blueprint dir**: `blueprint/.gitkeep`, emitted whenever the selection includes any blueprint-producing-or-consuming role: i.e., any role **except** infrastructure (equivalently: present unless the project is infrastructure-only).
3. **Role layers**: for each assignment, read the template's `manifest.toml` and add its files. Two cases aggregate instead of emitting one directory per assignment:
   - **Fullstack collapses**: when the same tool fills on-chain + off-chain and declares a `[fullstack]` template (§3.2), the two assignments emit **one** `protocol/` component (`fullstack.template`), emitted once on the first of the pair; the second is skipped. `has_fullstack` is set; `has_on_chain`/`has_off_chain` are not.
   - **Infrastructure is special — it aggregates**: all selected infra tools share one driver template (`_infra/cardano-up`) emitted **once** at `infra/`, rendered over the full set (`TemplateContext.infra_tools`). This is because the infra engine (`cardano-up`) manages the whole stack as a single unit, not per service.
   Every other role is one tool → one directory.
4. **Optional layer**: `flake.nix` + `.envrc` when `nix` is set.

No I/O: only embedded assets are read. `render` is set from the `.jinja` extension.

The `blueprint/` directory gives every blueprint-consuming role (off-chain, devnet, formal-methods) a stable, predictable path to read from, and lets a user drop a hand-supplied or externally-built `plutus.json` into the same place even when on-chain isn't scaffolded in this project. It is omitted only for infrastructure-only projects, where no role produces or consumes a blueprint. Only the directory (via `.gitkeep`) is created; the `plutus.json` *file* is produced by on-chain `build`, so consumers must still handle its absence gracefully (§4).

> **Code note:** the current `planner.rs` creates `blueprint/.gitkeep` only when on-chain is present (guarded by a `has_on_chain` check). The rule above broadens that guard to "any non-infrastructure role present".

### 6.3 Render (`renderer.rs`) & Write (`writer.rs`)

Render processes each entry whose source is a `.jinja` template through MiniJinja with the `TemplateContext`. Render-ness is **derived from the file extension** at plan time: the planner sets `FileEntry.render = source.ends_with(".jinja")` (§6.2); it is not an authored manifest field (manifests list only `source`/`dest`). Non-`.jinja` files, and `Inline` sources, pass through verbatim. Write is the **only** phase that touches disk: it creates parent directories and writes each file's content.

### 6.4 Determinism rule

**Determinism is a guarantee of the planning phase.** The planner emits entries in a fixed order: base layer → blueprint dir (when any non-infrastructure role is present) → role layers in **`Role::ALL` order** → optional layer. Within Infrastructure (the only multi-tool role), tools are ordered by **sorted tool id**. Any `HashMap` (e.g. `env_vars`) is iterated through a sorted/canonical view before it reaches output. Snapshot tests over `--dry-run` and rendered output enforce byte-stability. No other phase may introduce nondeterministic ordering.

> Current code stores `roles` in a `HashMap` and preserves `assignments` in flag order; formalizing the canonical ordering above (esp. sorting infra by id and iterating `assignments` in `Role::ALL` order) is the concrete work item this rule mandates.

---

## 7. CLI surfaces & output model

### 7.1 Modes

`cli/mod.rs` parses args with `clap`. There is an optional subcommand and a flattened set of init flags:

- **One-shot** (`--name` + role flags): flags → `Selection` in `oneshot.rs`, non-interactive, deterministic. Primary path for agents and CI.
- **Interactive** (no `--name`): guided `dialoguer` flow in `interactive.rs`.
- **`list` subcommand**: capability discovery; lists roles/tools, human by default, `--format json` for agents (see §7.3).

A safety check refuses to overwrite an existing target directory.

### 7.2 Output model: `--format` + presenter

To serve both humans and agents without scattering format branches:

- A global **`--format human|json`** flag (default `human`; `json` implies non-interactive: JSON mode never prompts).
- **`output.rs` as a presenter**: the core returns *structured results* and *typed errors*; only the presenter knows about colors, tables, or JSON. Every command's JSON wraps in the §2.4 envelope via `output::emit_json_ok` / `print_error`. Adding a new output is a presenter change, nothing else.

### 7.3 Machine-readable errors & discovery (PRD FR-13/FR-15)

- **Errors** carry a **stable string code** (e.g. `unknown_tool`, `tool_role_mismatch`, `name_required`, `dir_exists`) plus context (offending input + valid alternatives) and map to **meaningful exit codes**. In `--format json`, errors serialize to a stable shape on stderr; the core never falls back to interactive prompting in non-interactive mode. `CliError::code()`/`context()` carry the code + serializable context (§2.5).
- **Discovery** is the **`list` subcommand** (`cardano-init list`) that emits the registry (roles, tools, the roles each fills, languages). Human by default (with **`--table`** for a compact tools-by-role matrix), **`--format json`** for agents (§8 schema). `list` renders from the shared model `registry::view` (`role_views()` / `tool_views()`); the human tool block reuses `cli::format_tool` (shared with `--help`).

---

## 8. Dependency doctor (`doctor/`)

Scope (DX.02, implemented): the standalone **`cardano-init doctor`** command plus **check + advise** after generation. The doctor is a **dependency checker/advisor, not a project validator** — it reports presence and prints install plans; it never asserts a component actually builds (that's `just build`/`just test`, §7), never offers alternative runtimes (templates fix their toolchain), and checks presence only (no versions). **Auto-install** (running the resolved plan with consent) is a later nice-to-have install command (DX.05); see ROADMAP and the scope note in TECH_SPEC §9. The dependency catalog is a small **graph**, split between code and data along the purity invariant:

```
doctor/
├── mod.rs         Pure: resolve(targets, catalog, env) -> Report   (recursive, cycle-safe)
├── installers.rs  Pure (code): the closed `Installer` vocabulary. Per installer: detect binaries, command template, and a `bootstrap` list of dep ids
├── catalog.rs     Loads embedded registry/deps.toml -> DepCatalog (dep id → recipe)
└── probe.rs       Impure: detect OS + which installers are on PATH -> Environment
```

- **Two-tier inputs.** The selection yields **required** deps = `{just}` (universal task runner) ∪ the `system_deps` of all selected tools (unioned, deduped); and **recommended** deps (soft notes, never blocking). The two-tier mechanism stands, but there is **currently no recommended dep**: the former `process-compose`/≥2-infra case existed only to smooth a multi-service top-level `just dev`, which no longer exists (the top level no longer aggregates `dev`; long-running services start per-component — TECH_SPEC §7.2/§9.1). `just` is a base/derived dep owned by no tool.
- **Installers vs deps: the key model.** An **installer** is just another dependency. Code owns a *closed* `Installer` vocabulary (`Brew`, `Apt`, `Dnf`, `Pacman`, `Winget`, `Nix`, `Go`, `Cargo`, `Npm`, `Aikup`, `CardanoUp`, `Tx3up`, `Curl`, `PowerShell`); each declares its detect-binaries, a command template (`brew install {arg}`, `npm install -g {arg}`, `curl -sSfL {arg} | sh`, …), and a **`bootstrap` list of dep ids**. An **empty `bootstrap` list ⇒ terminal** (we detect it, never install it: system package managers, `nix`, the OS shells); a **non-empty list ⇒ bootstrappable** by installing any one of those deps in order (`npm`→`["node"]`, `aikup`→`["aikup"]`, `cargo`→`["rustup","rust"]`). This is what makes the catalog a graph rather than a flat list.
- **Recipes live in data.** Per-dep recipes are an embedded TOML file (`registry/deps.toml`), keyed by dep id: `binaries` (presence check), `docs` (universal fallback), and an ordered `install` list of `{ installer = arg }` methods. Installer names are validated against the code enum at load (unknown installer → load error, like an unknown `Role`). See §8.1 for why code/data split this way.
- **Resolver (`resolve`, pure, recursive).** A dep is present if  any of its `binaries` is on `PATH`. For a missing dep, the walk is **two-pass over the ordered `install` methods**: Pass 1 returns the first method whose installer is **detected** (a one-step command); only if none is directly available does Pass 2 walk the methods again and, for the first **bootstrappable** installer, recurse to satisfy one of its `bootstrap` deps and prepend those steps. The result is an ordered, possibly multi-step **plan** (e.g. `aiken` missing with no `nix`/`aikup` → install `aikup` via `npm`, then `aikup install`). Two passes — rather than bootstrapping each method before trying later ones — are exactly why the `nix` path needs no `aikup` when `nix` is present (a single method is still chosen per dep). Cycle detection guards the walk; `docs` is the fallback when nothing resolves (advice never empty, FR-20). Version constraints are out of scope for v1 (presence only); doctor output is **host-dependent by design** (not part of the byte-identical generation contract). Full algorithm in TECH_SPEC §9.4.
- **Infrastructure deps** install via `cardano-up` (the `CardanoUp` installer); `cardano-up` is itself a dep in `registry/deps.toml` (bootstrappable via its own installer methods). Auto-installing it arrives with the DX.05 install command; bootstrapping `cardano-up` when absent may follow post-RC (ROADMAP).
- **Project scan (no metadata file).** The standalone doctor derives its target set by scanning the cwd: each contract role directory present is matched against the `detect` signatures of the tools that fill that role; an identified tool contributes its `system_deps`, and an unmatched directory is reported as *unrecognized*. A **`protocol/`** directory (the fullstack fused component, §3.2) is scanned by a dedicated branch against the tools that declare a `[fullstack]` template; the identified tool is a real registry tool, so its `system_deps` feed the required set through the normal `registry.get` path (unlike the synthetic infra driver). Signatures are tool-author **data** in `registry/tools/<tool>.toml` (`detect = [...]`), either a bare path (existence) or `{ file, contains }` (content) — the content form keeps generic filenames like `package.json` from mislabeling foreign projects without claiming to validate viability. Full algorithm + schema in TECH_SPEC §9.6.
- **Boundary:** `mod.rs`/`installers.rs`/`catalog.rs` are pure and unit-tested with synthetic `Environment`s; only `probe.rs` touches the system (PATH/OS probes + the project scan). `doctor` depends on `registry`/`contract`, never on `cli`.

### 8.1 The code/data split

The catalog is a graph with two kinds of node, split by what each kind *is*:

- **Installers are code** (`installers.rs`). Detection, command templating, and the `bootstrap` edges are *logic*, and the set is a closed vocabulary, so it earns compile-time safety (installer references are un-typo-able; a removed installer fails to compile) and one tested home for platform quirks. Adding an installer is a deliberate code change, done only when a real recipe needs it on a supported platform.
- **Recipes are data** (`registry/deps.toml`). This is what honors the project's extensibility promise: a tool author adds a tool by writing `system_deps = [...]` and, if a dep is new, a `registry/deps.toml` entry that *chooses from* the existing installer vocabulary, with **no Rust**. Recipes are deduplicated by dep id (shared deps like `node`/`jvm` are defined once and referenced by many tools), and installer names are validated against the enum at load.

This split is the reversal of the earlier "in-code catalog" : the common case (a new tool whose deps install via existing installers) becomes pure data, which is the whole point of the registry model. The narrow case that still needs code (a brand-new installer) is rare and benefits from maintainer review anyway. Safety is preserved because data only ever names a closed, code-defined installer plus an `arg`; it never carries free-form command logic.

```toml
# registry/deps.toml: keyed by dep id; install = ordered [{ installer = arg }]
[node]
binaries = ["node"]
docs     = "https://nodejs.org/en/download"
install  = [ { brew = "node" }, { apt = "nodejs" }, { winget = "OpenJS.NodeJS" }, { nix = "nodejs" } ]

[aikup]
binaries = ["aikup"]
docs     = "https://aiken-lang.org/installation-instructions"
install  = [ { npm = "@aiken-lang/aikup" }, { curl = "https://install.aiken-lang.org" }, { powershell = "https://windows.aiken-lang.org" } ]

[aiken]
binaries = ["aiken"]
docs     = "https://aiken-lang.org/installation-instructions"
install  = [ { aikup = "" }, { nix = "aiken" } ]
```

**Referential integrity (tests):** every `system_deps` id (plus the base dep `just`) has a `registry/deps.toml` entry; every installer named in the data exists in the `Installer` enum; every dep id in an installer's `bootstrap` list exists. The full field-by-field schema and the resolver algorithm are in TECH_SPEC §9.

---

## 9. Version-update check (planned, not yet implemented)

The chosen mechanism for template freshness without runtime template fetching (PRD A-3/FR-24). It is a **thin `cli/` concern** (UX, network, never core). No code implements it yet; the `cli/update.rs` module name is already taken by the `add`/`remove` project mutations (§6.4), so this check will land in its own module when built:

- Best-effort check against the GitHub releases API; the notice (if any) is surfaced **before the write phase**, so the user can update and regenerate rather than discovering it post-write. It informs, never gates (the user may Ctrl-C to update first); it never alters generated output.
- **Latency is hidden, not added.** In **interactive** mode the check fires async at startup and completes during tool selection: zero added latency. In **human one-shot** there's no think-time to hide it, so the result is joined with a **≤1s deadline** behind a spinner before writing (worst case +1s, once/day).
- **Cached once/day** (small file in the OS cache dir): already-checked-today → zero network, zero latency.
- **Gated and fail-silent**: only when stdout is a TTY and not `--format json` (agents/CI: no network, no spinner, no notice). Offline/timeout/parse error → no-op. Preserves offline operation and determinism (A-3).

---

## 10. Testing strategy

- **Unit (pure core):** registry loading (every TOML parses, fields present); context building; planning (exact file set + order); rendering (context + template → expected output); doctor `resolve` over synthetic environments (incl. multi-step bootstrap chains and the cycle guard).
- **Contract compliance (mechanical):** for each template, assert the Justfile exposes `build`/`test`/`clean` (`dev` is optional); for on-chain, assert `just build` produces `blueprint/plutus.json`. This is what lets us avoid testing tool combinations.
- **Per-tool build smoke tests:** scaffold each tool in isolation and, where CI has the toolchain (or via Nix), run `just build && just test`. New tools must add these (PRD SM-1).
- **Scheduled maintenance gate:** the per-tool smoke tests also run on a schedule (weekly cron + manual dispatch, `.github/workflows/scheduled-smoke.yml`), not only on PR/commit. This is what detects a *generated project* breaking with **no repo change** — a Cardano hardfork, a breaking upstream tool release, or an unmaintained dependency (templates pin floating version ranges). A failure opens a tracking issue. It is distinct from the PR gates, which catch regressions we introduce.
- **Determinism / snapshot tests:** `--dry-run` and rendered output compared against committed snapshots for a set of selections; guards §6.4.
- **No combinatorial testing:** composition is guaranteed by the contract, so we verify each tool individually rather than every pair.

---

## 11. Extensibility: adding a tool

1. Add `registry/tools/<tool>.toml` with metadata, `system_deps`, `nix_packages`, and a `[roles.<role>]` block per supported role.
2. Add `templates/<tool>/<role>/` with a `manifest.toml` and template files (conforming to the contract, §4).
3. If the tool introduces a new `system_deps` id, add a `registry/deps.toml` entry (pure data; code is needed only if the dep requires a brand-new installer, §8).
4. Add the per-tool tests (§10).
5. Recompile (assets are embedded at compile time).

No CLI/core code changes are required for a new tool. Contract conformance guarantees it composes with every existing tool in other roles.

---

## 12. Open architectural decisions

*None currently open.* 

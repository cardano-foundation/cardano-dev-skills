# cardano-init: Technical Specification

**Status:** Draft · **Last updated:** 2026-06-01 · **Owner:** Robertino Martinez

> This document owns the **exact contracts, schemas, algorithms, and edge cases**. For the *why/for whom* see [PRD.md](./PRD.md); for the *how/structure* see [ARCHITECTURE.md](./ARCHITECTURE.md); for sequencing see [ROADMAP.md](./ROADMAP.md). Where this spec describes behavior not yet in the code, it is marked **(planned)**.

---

## 1. Conventions & versioning

- **Schema version.** All machine-readable (`--format json`) output carries a single integer `schema_version`, starting at **1**, global across every command. Additive fields do **not** bump it; removing/renaming/retyping a field or changing semantics does. Agents should tolerate unknown additive fields.
- **Embedded data is versioned with the binary.** The registry (tools + `registry/deps.toml`), templates, and the code-side installer table are compiled in; there is no on-disk schema-version negotiation. A given binary is the single source of truth for what it generates (PRD A-3).
- **Determinism (§11) is a hard contract**, relied on by snapshot tests and agents.

---

## 2. CLI surface

### 2.1 Commands

```
cardano-init [INIT_FLAGS]            # default: one-shot if --name given, else interactive
cardano-init doctor                  # check this project's dependencies + advise installs (§9)
cardano-init list [--table] [--format <fmt>]   # capability discovery: roles + tools (§8)
cardano-init add [ROLE_FLAGS]        # add/swap tools in the project in the cwd (see proposal)
cardano-init remove [ROLE_FLAGS]     # remove a role / infra provider from the cwd project
```

The `add`/`remove` commands operate on the project in the current directory: they reconstruct its `Selection` by **detection** (no metadata file; §9.6), apply the change at the component-directory level, and re-wire the shared top-level files. They accept `--dry-run` (preview only), `--force` (update despite a dirty git tree), `--ignore-warning`, and `--allow-experimental`. `add` takes the same role flags as init (`--on-chain`, `--off-chain`, `--fullstack`, `--infra` (repeatable), `--devnet`, `--formal-methods`); `remove` takes bare role flags plus `--infra <id>`. The full algorithm and edge-case matrix are in §15.

`--format human|json` is a global flag; default `human`. `json` **implies non-interactive**: it never prompts; if required input is missing it errors instead.

### 2.2 Init flags (one-shot)


| Flag | Type | Notes |
|------|------|-------|
| `--name <NAME>` | string | Presence selects one-shot mode. Validated per §3.5. |
| `--on-chain <TOOL_ID>` | string | At most one. |
| `--off-chain <TOOL_ID>` | string | At most one. |
| `--fullstack <TOOL_ID>` | string | Sugar for `--on-chain X --off-chain X`. The tool must declare a `[fullstack]` template (§3.2). Mutually exclusive with `--on-chain`/`--off-chain`. |
| `--infra <TOOL_ID>` | string, repeatable | Multiple allowed (only multi-tool role). |
| `--devnet <TOOL_ID>` | string | At most one. |
| `--formal-methods <TOOL_ID>` | string | At most one. |
| `--nix` | bool | Emit `flake.nix` + `.envrc`. |
| `--allow-experimental` | bool | Opt in to experimental tools (§3.2.1). Required to select one in one-shot/JSON; pre-acknowledges the interactive confirm. |
| `--ignore-warning` | bool | Scaffold an off-chain ↔ provider combination the compatibility gate flags as incompatible (§3.2.2). Downgrades the stop to a warning. |
| `--dry-run` | bool | Plan only; write nothing; exit 0. |


Mode resolution: if `--name` is present → one-shot; else → interactive. Providing any one-shot flag **without** `--name` is a usage error (`name_required`).

**`--fullstack` is pure CLI sugar** resolved at the edge: `--fullstack X` expands to the two
assignments `--on-chain X` + `--off-chain X`. Combining it with an explicit `--on-chain`/`--off-chain`
is a usage error (`fullstack_conflict`); naming a tool without a `[fullstack]` template is
`fullstack_unsupported`. The *core* never sees a "fullstack" flag — the resulting same-tool-both-roles
pair is what triggers the collapse into a single `protocol/` component (§3.2, §6.1).

### 2.3 Exit codes


| Code | Meaning | Examples |
|------|---------|----------|
| `0` | Success (incl. `--dry-run`, and interactive abort-by-choice) | generated |
| `2` | **Usage / validation** error | bad flag, `unknown_tool`, `tool_role_mismatch`, `no_roles_selected`, `invalid_project_name`, `name_required` |
| `1` | **Runtime** error | `dir_exists` (non-empty), registry load failure, render/IO error |


The fine-grained "what" is the JSON `error.code` (§2.5); exit code is only the category. Interactive **abort** (user declines the confirmation prompt) exits `0` with no error, and never occurs in `json`/non-interactive mode.

### 2.4 JSON envelope

Every `--format json` response is one of:

```json
{ "schema_version": 1, "ok": true,  "data":  { /* command payload */ } }
{ "schema_version": 1, "ok": false, "error": { "code": "<stable>", "message": "<human>", "context": { /* structured */ } } }
```

Success and error are symmetric (same envelope). `message` is human-readable and may change; `code` and `context` keys are part of the contract.

### 2.5 Error catalog

Stable `code`s, their exit category, and the `context` they carry. The `context` is the agent-facing "how to fix" (PRD FR-15).


| `code` | Exit | `context` fields |
|--------|------|------------------|
| `name_required` | 2 | `{ }` |
| `invalid_project_name` | 2 | `{ name, reason }` |
| `unknown_tool` | 2 | `{ tool_id, role, valid_tools: [..] }` |
| `tool_role_mismatch` | 2 | `{ tool_id, role, valid_roles: [..] }` |
| `fullstack_conflict` | 2 | `{ }` (`--fullstack` combined with `--on-chain`/`--off-chain`) |
| `fullstack_unsupported` | 2 | `{ tool_id, valid_tools: [..] }` (tool has no `[fullstack]` template; `valid_tools` = fullstack-capable tools) |
| `no_roles_selected` | 2 | `{ }` |
| `experimental_not_allowed` | 2 | `{ tools: [..], remedy: "--allow-experimental" }` (an experimental tool was selected in one-shot/JSON without `--allow-experimental`; §3.2.1) |
| `incompatible_tools` | 2 | `{ tools: [off_chain_id, provider_ids…], reason, compatible_providers: [..], compatible_off_chain: [..], remedy: "--ignore-warning" }` (the off-chain tool and its selected providers share no seam; §3.2.2) |
| `dir_exists` | 1 | `{ path }` (exists and non-empty) |
| `project_unrecognized` | 2 | `{ dirs: [..] }` — `add`/`remove`/`edit` couldn't identify a component directory; fatal in `json`/non-interactive (never guesses) |
| `slot_occupied` | 2 | `{ role, dir }` — a create target directory already exists and isn't the recognized current component |
| `nothing_to_change` | 2 | `{ }` — the requested edit is a no-op against the detected selection |
| `worktree_dirty` | 1 | `{ path }` — uncommitted changes (or not a git repo) and no `--force` |
| `registry_load` | 1 | `{ file?, detail }` |
| `scaffold_error` | 1 | `{ path?, detail }` (asset-not-found, manifest-parse, render, io) |


These map 1:1 to the `CliError`/`ScaffoldError`/`RegistryError` variants; `CliError::code()`/`context()` attach the `code` + serializable `context`, routed through the presenter (ARCHITECTURE §7.2).

---

## 3. Core data model

Exact types; field-level source of truth is `src/registry/types.rs`.

### 3.1 Role

```rust
pub enum Role { OnChain, OffChain, Infrastructure, Devnet, FormalMethods }
```


| Variant | kebab (TOML/flag) | dir (`contract::DIR_*`) | Display | multiple |
|---------|-------------------|--------------------------|---------|----------|
| OnChain | `on-chain` | `on-chain` | On-chain | no |
| OffChain | `off-chain` | `off-chain` | Off-chain | no |
| Infrastructure | `infrastructure` | `infra` | Infrastructure | **yes** |
| Devnet | `devnet` | `devnet` | Devnet | no |
| FormalMethods | `formal-methods` | `formal-methods` | Formal methods | no |


- `Role::ALL` lists variants in the table's order = the **canonical order** (§11).
- `from_kebab` is the only parse path; unknown → `UnknownRoleError` → `RegistryError::UnknownRole`.
- The enum is the sole role vocabulary; the registry references but cannot add roles (ARCHITECTURE §3.1).

### 3.2 Tool & registry TOML schema

```toml
[tool]
id          = "aiken"          # required, unique across registry, kebab
name        = "Aiken"          # required, human display
description = "…"              # required, newcomer-facing
website      = "https://…"     # required
languages    = ["aiken"]       # required, ≥1 — except infra tools, which may use [] (no user-facing language)
system_deps  = ["aiken"]       # required (may be []); abstract dep ids → registry/deps.toml (§9)
nix_packages = ["aiken"]       # optional (default []); nixpkgs attrs for the dev shell
nix_self_contained = false     # optional (default false); tool ships its own component flake (§4.1)
experimental = false           # optional (default false); true = unstable and/or not build-green, gated (§3.2.1)

[roles.on-chain]               # ≥1 [roles.<kebab>] block; key validated against Role
template = "aiken/on-chain"    # required; path under templates/
```

A tool that fills **both** on-chain and off-chain may additionally declare a **`[fullstack]`**
table. Its template is used when the same tool fills both roles, collapsing them into one unified
`protocol/` component instead of two folders (§6.1). This is a *tool capability*, not a role —
`protocol` is not a `Role`, and `Role::ALL` stays at five.

```toml
[roles.on-chain]               # required: a fullstack tool must fill both
template = "scalus/on-chain"   # (used when scalus fills on-chain only, e.g. with a TS off-chain)

[roles.off-chain]
template = "scalus/off-chain"  # (used when scalus fills off-chain only)

[fullstack]
template = "scalus/fullstack"  # used when scalus fills BOTH → one protocol/ component
```

Validated at load: `[fullstack]` present ⇒ the tool must declare **both** `[roles.on-chain]` and
`[roles.off-chain]`, else `RegistryError::FullstackRolesMissing`. The fullstack component still
honors the external interface contract — its `build` writes `blueprint/plutus.json` and it reads/writes
`.env` — so it composes with the other roles like any on-chain producer (§7). Fullstack privatizes
only the *internal* on-chain↔off-chain seam. (Half-composition still works: scalus on-chain + a
different off-chain tool, or vice-versa, each uses the corresponding `[roles.*]` template and the
normal blueprint-file seam.)

Tools filling the **infrastructure** role additionally require an `[infra]` table
(validated at load: `[roles.infrastructure]` present ⇒ `[infra]` required, else
`RegistryError::InfraConfigMissing`). It declares the `cardano-up` package and the
output→`.env`-key mappings the aggregated driver writes:

```toml
[roles.infrastructure]
template = "_infra/cardano-up"        # the shared driver template (all infra tools use this)

[infra]
cardano_up_package = "kupo"           # package id passed to `cardano-up install`
env = [{ from = "KUPO_URL", to = "INDEXER_URL" }]   # cardano-up output → contract .env key
```

A tool may also declare an optional **`[compat]`** table describing the connection *seam(s)* it
speaks or serves, driving the off-chain ↔ provider compatibility gate (§3.2.2). All fields default
empty/false, so a tool without `[compat]` imposes no constraint.

```toml
[compat]
consumes = ["blockfrost", "kupo", "ogmios"]   # off-chain: seam(s) it can consume (e.g. Evolution)
serves   = ["blockfrost"]                      # devnet/infra: seam(s) it exposes (e.g. Yaci, Dingo)
self_contained_devnet = true                   # bundles its own devnet → needs no devnet role (e.g. Tx3)
```

Seam vocabulary (`Seam` enum, closed like `Role`; unknown value → `RegistryError::UnknownSeam` at
load): `blockfrost`, `u5c`, `trp`, `ogmios`, `kupo`.

`system_deps` is **per-tool, flat** (§9.1): it applies whenever the tool is selected for any role.

```rust
RoleConfig { template }
EnvMapping { from, to }
InfraConfig { cardano_up_package, env: Vec<EnvMapping> }
CompatConfig { consumes: Vec<Seam>, serves: Vec<Seam>, self_contained_devnet: bool }
ToolDef { id, name, description, website, languages, nix_packages, nix_self_contained: bool, detect, roles: HashMap<Role, RoleConfig>, infra: Option<InfraConfig>, fullstack: Option<RoleConfig>, experimental: bool, compat: CompatConfig }
```

#### 3.2.1 Experimental tools

`experimental = true` marks a tool as **not production-ready**, for either — or both — of two
reasons:

1. the **upstream tool itself** is experimental (pre-release, unstable, a work in progress — e.g.
   Blaster);
2. its **cardano-init integration** is not yet build-green (a placeholder template, excluded from the
   build-green guarantees / smoke matrix).

Either reason is sufficient; the flag does not distinguish them, because the consequence for the user
is the same (rough edges, breaking changes). The tool still generates (so its role is present and
demoable). Default `false`, so a production-ready tool needs no flag. Maturity is a **per-tool**
property, not per-role: a future production-ready formal-methods tool would set `experimental = false`
even though today's Blaster is `true` (ROADMAP Phase 0 formal-methods deliverable).

Experimental status is both **surfaced and gated**:

- **Surfaced** everywhere: `list`/`--help` add an `[experimental]` tag and a `Status:` line, the
  interactive picker tags the choice, and generation prints a prominent warning (in the
  pre-generation summary *and* on success). In JSON, `list`'s `tools[].experimental` and each
  generated `components[].experimental` carry the flag for agents (both additive; no `schema_version`
  bump).
- **Gated** by explicit opt-in, so a tool with rough edges is never scaffolded unknowingly. It does
  **not** gate the tool out of existence — the role still generates for the all-five-roles demo — it
  gates *unacknowledged* use:
  - **One-shot / JSON** (non-interactive): selecting an experimental tool without
    `--allow-experimental` is the usage error `experimental_not_allowed` (§2.5), exit 2 — nothing is
    generated. A flag, not a prompt, so non-interactive mode stays non-interactive.
  - **Interactive**: choosing an experimental tool triggers an explicit confirm (default **No**);
    declining drops just that tool and keeps the rest. `--allow-experimental` pre-acknowledges and
    skips the confirm.

#### 3.2.2 Off-chain ↔ provider compatibility

An off-chain tool reaches a chain over one or more **seams** (`consumes`); its **providers** — the
selected devnet plus every selected infra tool — each expose seams (`serves`). The gate
(`registry::compat::check`, pure) evaluates the single off-chain tool against the **union** of its
selected providers:

- **Compatible** when at least one selected provider (that declares a seam) serves a seam the
  off-chain tool consumes. So a compatible devnet still covers an otherwise-mismatched extra infra
  tool, and mixing providers is fine as long as one fits.
- **`self_contained_devnet`** (e.g. Tx3, which bundles its own Dolos): a *separately selected devnet*
  is redundant → incompatible, regardless of seams. Infra is unaffected (it can still serve the tool).
- **Permissive** when the off-chain tool declares no `consumes`, or no selected provider declares a
  `serves` — supplementary infra (a bare node, a submit API) and un-annotated tools never fabricate a
  conflict, and an off-chain tool with no local provider falls back to a public one (§7). A seam is
  declared only when a tool can actually build the reference example over it — e.g. Dolos serves
  `u5c`, not `blockfrost`, because its minibf omits tx evaluation.

Enforcement mirrors the experimental gate (§3.2.1):

- **One-shot / JSON**: an incompatible selection is the usage error `incompatible_tools` (§2.5), exit
  2 — nothing is generated — unless `--ignore-warning` is passed, which downgrades it to a warning and
  proceeds.
- **Interactive**: an incompatible **devnet** option is shown as `✗ unavailable — <reason>` and can't
  be picked (unless `--ignore-warning`). Infra is multi-select with union semantics, so individual
  infra picks aren't disabled; the run-level gate covers them.

Load-time validation (`registry/loader.rs`), all fatal:
- unparseable TOML → `RegistryError::Parse { file }`.
- unknown role key → `RegistryError::UnknownRole { file, role }`.
- unknown seam in `[compat]` → `RegistryError::UnknownSeam { file, seam }`.
- duplicate `tool.id` → `RegistryError::DuplicateId { id }`.
- `[fullstack]` without both on-chain and off-chain roles → `RegistryError::FullstackRolesMissing { id }`.
- zero tools discovered → `RegistryError::Empty`.

### 3.3 Selection

```rust
struct Selection { project_name: String, assignments: Vec<RoleAssignment>, network: Network, nix: bool }
struct RoleAssignment { role: Role, tool_id: String }
enum Network { Preview, Preprod, Mainnet }   // Display = lowercase. Not a scaffold-time
                                             // choice: always Preview. Switch via CARDANO_NETWORK in .env.
```

A `Selection` is **valid by construction** (ARCHITECTURE §3.3); there is no separate validation pass. Edges in §3.5/§12.

### 3.4 Role multiplicity & infra duplicates

- Non-infra roles: at most one tool (interactive allows one; one-shot flags are single).
- Infrastructure: ≥1 tools. **Duplicate `--infra X --infra X` is de-duplicated** (keep first occurrence) so the plan can't emit `infra/X/` twice. (Dedupe, not error: idempotent and harmless.)
- **Fullstack collapse:** when the *same* `tool_id` fills both on-chain and off-chain **and** that tool declares a `[fullstack]` template, the two assignments collapse into a single `protocol/` component at planning time (§6.1). The `Selection` still carries both `RoleAssignment`s (the collapse is *derived*, keeping `Selection` valid-by-construction and the blueprint predicate unchanged, §6.2). Same tool for both roles with **no** `[fullstack]` template falls back to two separate folders (today's behavior).

### 3.5 Project-name rules

Validated by `oneshot::validate_project_name` (also applied to interactive input): 
- Non-empty. 
- Must not start with `.`.
- Characters limited to `[A-Za-z0-9_-]`. This rejects path separators, spaces, leading-dot/hidden, `.`/`..`. 

Violations → `invalid_project_name { name, reason }`. (No length cap or OS-reserved-name check in v1; revisit if needed.)

---

## 4. Template system

### 4.1 Manifest schema

`templates/<tool>/<role>/manifest.toml`:

```toml
[manifest]
summary = "…"          # shown in interactive mode when this template is highlighted

[[files]]
source = "Justfile.jinja"   # path within the template dir
dest   = "Justfile"         # path within the role dir (see §4.4)

[[files]]
source = "flake.nix.jinja"  # optional emission guard:
dest   = "flake.nix"        # emit only when the condition holds
when   = "nix"              # (currently the sole condition: `--nix`)
```

- `source` + `dest` required per file; `when` optional (absent ⇒ always emitted).
- If file ends with `.jinja`, it's rendered (§4.2). 
- `_base/` and `_nix/` layers are emitted by the planner directly (not via a manifest).
- **`when`** gates emission on the selection: `when = "nix"` emits the file only under `--nix`. A tool that ships its own component-local Nix flake this way should also set `nix_self_contained = true`. Then its `nix_packages` are not listed as bare attrs in the top-level shell (a plain `mkShell` cannot build them); instead the top-level flake references the component as a `path:./<dir>` input and composes its dev shell via `inputsFrom`, so the whole toolchain — and `just build` for that component — works from the project root. Plinth uses this to ship the recommended haskell.nix flake from `IntersectMBO/plinth-template`.

### 4.2 Render derivation (the `.jinja` rule)

A file is rendered through MiniJinja **if its `source` ends with `.jinja`**. The planner records this as `FileEntry.render = source.ends_with(".jinja")`. Authoring contract:

- Name a file `foo.ext.jinja` → it is rendered; set `dest = "foo.ext"` (drop `.jinja`).
- Name it `foo.ext` → copied verbatim (bytes), may be **binary**.
- Rendered templates **must be valid UTF-8** (enforced; non-UTF-8 `.jinja` is a bug). Binary assets must therefore not use the `.jinja` suffix.

### 4.3 Rendering contract

MiniJinja environment (`renderer.rs` config):
- **Undefined = strict**: referencing an undefined variable is a render error (caught at generation, not in the generated project). Authors guard optionals with `{% if has_* %}`.
- **Autoescape off**: output is code/config, not HTML, so no entity escaping.
- **Newlines normalized to `\n` (LF)**, UTF-8, for byte-identical cross-platform output (§11).

### 4.4 Path safety & destinations

- `dest` is resolved **relative to the role dir** (`on-chain/`, `off-chain/`, `test/`, `formal-methods/`); for infrastructure, relative to `infra/` (the aggregated component — no per-tool subdir, §6.1).
- `dest` MUST be relative and MUST NOT contain `..` or a leading `/` (no escaping the project root). Enforced + tested. (Manifests are first-party today, but the check is cheap insurance and required if templates ever become third-party.)
- Base/optional layer dests are fixed (§6).

### 4.5 Executable bit

The writer sets **no executable bits** (and `just` doesn't need them). Templates must invoke helper scripts through an interpreter (`sh scripts/x.sh`, `node …`, `just …`), never `./x.sh`. Rationale: portability (exec bits don't exist on Windows) + trivial writer. Documented as a template-authoring rule.

### 4.6 TemplateContext: the template-authoring API

The entire surface available to templates (`scaffold/context.rs`, `Serialize`):

```rust
struct TemplateContext {
    project_name: String,
    network: String,                 // "preview" | "preprod" | "mainnet"

    has_on_chain: bool, has_off_chain: bool, has_infra: bool,
    has_devnet: bool,  has_formal_methods: bool,
    has_fullstack: bool,             // one tool fills both on-chain+off-chain (§3.4)

    on_chain: Option<RoleContext>,
    off_chain: Option<RoleContext>,
    fullstack: Option<RoleContext>,  // the fused protocol/ component; dir = "protocol".
                                     // When Some, on_chain/off_chain are None (the two roles
                                     // are represented by this single component instead).
    infra_tools: Vec<InfraToolContext>,  // 0..n, canonical order (§11); aggregated infra component
    devnet: Option<RoleContext>,
    formal_methods: Option<RoleContext>,

    infra_context_name: String,      // cardano-up context the infra driver targets (= project_name)
    infra_env: Vec<EnvMapping>,      // resolved, key-unique .env emissions for infra (proposal §5.4)

    blueprint_path: String,          // "blueprint/plutus.json" (contract constant)
    env_vars: <ordered map>,         // see §6.3; iterated in sorted-key order

    nix: bool,
    nix_packages: Vec<String>,       // deduped union across selected tools, first-seen order; excludes nix_self_contained tools (composed via inputsFrom instead)
    nix_component_flakes: Vec<String>, // dirs of nix_self_contained components; the top-level flake references each as path:./<dir> and pulls its dev shell in via inputsFrom
}

struct RoleContext { tool_id, tool_name, language, dir }   // language = tool.languages[0]
struct InfraToolContext { tool_id, tool_name, cardano_up_package, env: Vec<EnvMapping> }
struct EnvMapping { from, to }   // cardano-up output var → contract .env key
```

This struct is the contract. Adding a field is additive; renaming/removing is a breaking template-API change.

---

## 5. Registry loading

`Registry::load()` iterates embedded `registry/tools/*.toml`, builds `Vec<ToolDef>` plus indexes `by_id: HashMap<String, usize>` and `by_role: HashMap<Role, Vec<usize>>`. 
Accessors: `get(id)`, `tools_for_role(role)`, `all_tools()`. Immutable after load.
Determinism note: any consumer that emits tools/roles must sort (§11), since `by_role` order follows asset-iteration order.

---

## 6. Scaffolding pipeline contracts

### 6.1 Plan order (canonical)

`planner::plan` emits `FileEntry`s in exactly this order:

1. **Base layer** (always): `Justfile`, `README.md`, `AGENTS.md` (rendered), `CLAUDE.md` (static), `.gitignore`, `.env`. `AGENTS.md` is the tailored agent brief (stack, interface contract, `just` workflow, per-tool doc links, and the relevant [cardano-dev-skills](https://github.com/cardano-foundation/cardano-dev-skills) for the selection); `CLAUDE.md` is a static `@AGENTS.md` import so Claude Code (which does not read `AGENTS.md` natively) picks it up.
2. **Blueprint dir**: `blueprint/.gitkeep`, **if  any non-infrastructure role is present** (§6.2). Source is `TemplateSource::Inline(empty)`.
3. **Role layers**: assignments processed in **`Role::ALL` order** (not flag order). For each, read the template manifest and append its files (rendered per §4.2). Two roles aggregate instead of emitting per-assignment:
   - **Fullstack collapses**: when the same tool fills on-chain + off-chain and declares a `[fullstack]` template (§3.4), the two assignments emit **one** `protocol/` component from the `[fullstack]` template, emitted **once** on the first of the pair (on-chain sorts first in `Role::ALL`), the off-chain assignment is skipped. `has_on_chain`/`has_off_chain` are false; `has_fullstack` is true. Because both assignments remain in the selection, the blueprint predicate (§6.2) is unchanged.
   - **Infrastructure aggregates**: all selected infra tools share one driver template (`_infra/cardano-up`), emitted **once** at `infra/` on the first infra assignment (the rest are contiguous after the canonical sort and skipped); they are still sorted by `tool_id` for the rendered `infra_tools`/`infra_env` order (§11). All infra tools must resolve to the same template path, else `ScaffoldError::InfraTemplateMismatch`.
4. **Optional layer**: if `nix`, `flake.nix` (rendered) + `.envrc` (rendered from `_nix/envrc.jinja`; `use flake`, plus — when the top-level flake composes a `nix_self_contained` component — a `NIX_CONFIG` pre-accept for its `nixConfig` and a source-build heads-up when the IOG cache isn't trusted).

`--dry-run` returns this `FilePlan` (no rendering, no I/O).

### 6.2 `blueprint/` predicate

```
blueprint_present  ⇔  assignments.iter().any(|a| a.role != Role::Infrastructure)
```

The **directory** (via `.gitkeep`) exists for every project except infrastructure-only; the **`plutus.json` file** is produced by on-chain `build` and may be absent, so consumers must tolerate a missing file (§7). A **fullstack** project keeps the directory: the collapse is derived and both on-chain/off-chain assignments stay in the selection, so the predicate holds and the `protocol/` component's `build` writes the blueprint like any on-chain producer.

### 6.3 `.env` seeding

`.env` is always written (base layer), seeded by `context.rs` with:
`CARDANO_NETWORK=<network>`, and empty `INDEXER_URL=`, `INDEXER_PORT=`, `NODE_SOCKET_PATH=`, `OGMIOS_URL=`, `TX_SUBMIT_URL=`, `DOLOS_GRPC_URL=`, `CARDANO_NODE_API_URL=`. Whichever component provisions a local endpoint fills the connection vars at runtime during its `dev` (§7).
Emitted in **sorted key order** for determinism.

### 6.4 Write semantics & target dir

- Write is the only phase with side effects: `create_dir_all(parent)` then write bytes. No chmod (§4.5).
- **Target directory policy:** generate into `./<project_name>/`. If it does not exist, create it. If it exists and is **empty**, proceed. If it exists and is **non-empty**, fail with `dir_exists` (exit 1). No `--force` in v1. Never overwrites user files.

---

## 7. Interface contract (concrete)

Constants (`contract.rs`): 
- `BLUEPRINT_PATH = "blueprint/plutus.json"`; 
- dirs `on-chain|off-chain|infra|devnet|formal-methods` (plus the derived `protocol` fullstack dir);
- env `INDEXER_URL`, `INDEXER_PORT`, `NODE_SOCKET_PATH`, `CARDANO_NETWORK`, and the provider endpoints `OGMIOS_URL`, `TX_SUBMIT_URL`, `DOLOS_GRPC_URL`, `CARDANO_NODE_API_URL`.

**Every component Justfile** exposes `build`, `test`, `clean` and works standalone (its `just build` succeeds with no other roles present). A target that is a no-op for a tool still exists (may print a message). **`dev` is optional**: a component provides it only when it has a genuine watch/daemon/devnet mode — there are no no-op `dev` targets (it is not aggregated at the top level, §7.2, so an absent `dev` costs nothing).

- **On-chain** `build` writes `../blueprint/plutus.json`.
- **Fullstack (`protocol/`)** `build` also writes `../blueprint/plutus.json` (it *is* the on-chain producer for its project) and reads/writes `../.env` like an off-chain consumer. Its internal on-chain↔off-chain link may bypass the file (shared in-process types), but the external seam is mandatory so devnet/formal/infra still compose.
- **Off-chain / devnet / formal-methods** read `../blueprint/plutus.json` and `../.env` if present; degrade gracefully if absent.
- **The component that provisions a local chain endpoint** writes the standard connection vars (`INDEXER_URL`, …) into `../.env` during its `dev`. This is **role-agnostic**: it is typically an *infrastructure* service, but a local devnet such as Yaci DevKit in the *devnet* role does it too. The seam is the `.env` keys, not the role — a tool's **role** is its *purpose*, while writing `.env` is the orthogonal *capability* of exposing a local endpoint. Consumers react only to the presence of `INDEXER_URL`, never to which tool/role set it (this is what keeps composition O(tools), ARCHITECTURE §1).

### 7.1 Top-level Justfile aggregation

The top level aggregates only the tasks that **terminate and compose**:

- `build`: each present component's `build`, on-chain first (so the blueprint exists for consumers), then off-chain/devnet/formal in `Role::ALL` order. A **fullstack `protocol/`** component takes the on-chain producer slot (built first).
- `test`: on-chain `build` first (produce the blueprint), then each present component's `test` in `Role::ALL` order — on-chain, off-chain, devnet, and formal-methods (`verify`). For fullstack, `protocol` builds then tests first.
- `clean`: each component's `clean`, then `rm -f blueprint/plutus.json`.

### 7.2 No top-level `dev`

There is **no top-level `dev` target**. Long-running / interactive tasks (watch modes, local devnets, REPLs) do not aggregate into one foreground command — that is exactly why a multi-service launcher is awkward — so they are **per-component**: the developer runs `just -f <role>/Justfile dev` (or `just -f infra/Justfile dev` for the aggregated infra stack) directly, documented in the README.

`dev` is **optional per component** (§7): a tool provides it only when it has a genuine watch/daemon/devnet mode. Because the top level never aggregates `dev`, a component without one costs nothing — and we don't ship no-op `dev` targets just to fill the slot.

A component whose `dev` provisions a local endpoint (e.g. Yaci DevKit's devnet) writes the standard connection vars into `../.env` as part of that per-component `dev`; off-chain/devnet consumers then pick them up automatically (§7). Bringing such a service up is therefore a deliberate, per-component developer action, not a top-level orchestration step.

---

## 8. `list` subcommand schema

`cardano-init list` (human default) / `cardano-init list --format json`:

```json
{ "schema_version": 1, "ok": true, "data": {
  "roles": [
    { "id": "on-chain",       "dir": "on-chain",       "display": "On-chain",       "multiple": false },
    { "id": "infrastructure", "dir": "infra",          "display": "Infrastructure", "multiple": true  }
    /* … all Role::ALL, in canonical order … */
  ],
  "tools": [
    { "id": "aiken", "name": "Aiken", "description": "…", "website": "https://…",
      "languages": ["aiken"], "roles": ["on-chain"], "fullstack": false, "experimental": false },
    { "id": "blaster", "name": "Blaster", "description": "…", "website": "https://…",
      "languages": ["blaster-spec"], "roles": ["formal-methods"], "fullstack": false, "experimental": true }
    /* … tools sorted by id; each tool's roles sorted … */
  ]
}}
```

`list` renders from a shared model (`registry::view`: `role_views()` / `tool_views()`). The human output has two forms: the default (a Roles table plus a per-tool block shared with `--help`), and a compact **`--table`** view — a full-grid matrix with one column per role (in `Role::ALL` order), each role's tools stacked and experimental ones tagged `🧪`. `--table` is a human-presentation flag only; it has no effect under `--format json` (the JSON already carries the same data). `roles[].multiple` is `true` only for infrastructure (`Role::multiple`). `tools[].fullstack` is `true` when the tool declares a `[fullstack]` template (i.e. `--fullstack <tool>` is valid); it is an additive field (no `schema_version` bump). `fullstack` is a capability, **not** a role — it never appears in `tools[].roles` or in the `roles` array. `tools[].experimental` is `true` for tools that are unstable and/or not yet build-green (§3.2.1); selecting one needs `--allow-experimental` — also additive.

---

## 9. Dependency doctor

Implemented for DX.02: the standalone `cardano-init doctor` command plus check-and-advise after generation. Both run the same pure resolver (§9.4) over the same catalog (§9.2).

**Scope — what the doctor *is*.** A **dependency checker and advisor**: it determines which required dependencies are present and, for missing ones, prints an OS-aware, ordered install plan (never just "go install it"). v1 prints the plan; v2 (DX.05) executes it with consent (same data, same resolver).

**Out of scope — what the doctor is *not*.**
- **A project validator.** The doctor does not verify that a component actually builds, type-checks, or is otherwise viable — that is the job of each component's `just build` / `just test` (the interface contract requires those to work standalone, §7). A directory that *looks* like a tool (matching signatures, §9.6) but isn't wired up correctly will still pass the doctor; it will fail `just test`. Keeping these separate avoids duplicating the build system's job in a fragile heuristic.
- **Alternative runtimes / package managers.** Each template fixes its toolchain (e.g. the MeshJS/Yaci components invoke `npm`/`node`/`npx` directly in their Justfiles), so `node` is the honest required dep. The doctor reflects what the template needs; it does not offer to satisfy that with `bun`/`deno`/etc. Making a component runtime-agnostic is a template decision, not a doctor feature (and cuts against the fixed-convention philosophy, ARCHITECTURE §3.1).
- **Version constraints.** Presence only in v1 (§9.3); minimum-version checks are a later item (ROADMAP Phase 3).

### 9.1 Dependency sets (required vs recommended)

Pure functions of the selection. Two tiers:

```
required_deps    = {"just"}                                  // universal task runner
                 ∪ (tool.system_deps for each selected tool) // unioned, deduped
recommended_deps = {}                                        // see note
```

- **Required** deps gate the build/test acceptance bar (SM-1); their absence is reported prominently. `just` is a base/derived required dep (every project needs the task runner).
- **Recommended** deps improve the experience but are **never required** (soft notes only). The two-tier mechanism remains for future use, but there is **currently no recommended dep**: the former `process-compose` case existed only to smooth a multi-service top-level `just dev`, and the top level no longer aggregates `dev` (§7.2), so that rationale is gone. Long-running services are now started per-component.

`just` is a **base/derived dep owned by no tool**; it has an entry in `registry/deps.toml` like any dep. (`cardano-up` is reached as an *installer* and is itself a dep entry, rather than added to either set directly.)

### 9.2 Catalog = installers (code) + recipes (data)

The catalog is a small **graph**. An *installer* is itself a kind of dependency, so the two node types are: code-defined installers, and data-defined dep recipes that reference them.

**Installers (code, `installers.rs`)**: a closed vocabulary. Per installer: the binaries that mean "available", a command template, and a `bootstrap` list of dep ids (**empty ⇒ terminal**, i.e. detect-only/never auto-installed; **non-empty ⇒ bootstrappable** by installing any one of those deps, tried in order):

```rust
enum Installer { Brew, Apt, Dnf, Pacman, Winget, Nix, Go, Cargo, Npm, Aikup, CardanoUp, Curl, PowerShell }

struct InstallerDef {
    detect:    &[&str],                 // ["npm"]: installer available if one is on PATH
    template:  fn(arg: &str) -> String, // Brew → "brew install {arg}"; Curl → "curl -sSfL {arg} | sh"
    bootstrap: &[&str],                 // dep ids that provide this installer; [] ⇒ terminal
}
```


| Installer | template (`{arg}`) | `bootstrap` |
|-----------|--------------------|-------------|
| `Brew` | `brew install {arg}` | `[]` (terminal) |
| `Apt` | `sudo apt install -y {arg}` | `[]` |
| `Dnf`/`Pacman`/`Winget` | native install of `{arg}` | `[]` |
| `Nix` | `nix profile install nixpkgs#{arg}` | `[]` |
| `Curl` | `curl -sSfL {arg} \| sh` | `[]` |
| `PowerShell` | `powershell -c "irm {arg} \| iex"` | `[]` |
| `Npm` | `npm install -g {arg}` | `["node"]` |
| `Cargo` | `cargo install {arg}` | `["rustup", "rust"]` |
| `Go` | `go install {arg}` | `["go"]` |
| `Aikup` | `aikup install {arg}` | `["aikup"]` |
| `CardanoUp` | `cardano-up install {arg}` | `["cardano-up"]` |
| `Tx3up` | `tx3up install {arg}` | `["tx3up"]` |


The `arg`'s meaning is the installer's: a package name for managers, an installer-script URL for `Curl`/`PowerShell`, a target for `Aikup`/`CardanoUp`. Adding an installer is a deliberate code change, only when a real recipe needs it (same discipline as roles).

**Recipes (data, `registry/deps.toml`)**: keyed by dep id; `install` is an ordered list of single-key `{ installer = arg }` methods (order = preference). Installer keys are validated against the `Installer` enum at load (unknown → load error):

```toml
[node]  
binaries=["node"]
docs="https://nodejs.org/en/download"
install=[ {brew="node"}, {apt="nodejs"}, {winget="OpenJS.NodeJS"}, {nix="nodejs"} ]

[aikup] 
binaries=["aikup"]
docs="https://aiken-lang.org/installation-instructions"
install=[ {npm="@aiken-lang/aikup"}, {curl="https://install.aiken-lang.org"}, {powershell="https://windows.aiken-lang.org"} ]

[aiken] 
binaries=["aiken"]
docs="https://aiken-lang.org/installation-instructions"
install=[ {aikup=""}, {nix="aiken"} ]

[just]
binaries=["just"] 
docs="https://just.systems"
install=[ {brew="just"}, {apt="just"}, {cargo="just"}, {nix="just"} ]

[process-compose]
binaries=["process-compose"]
docs="https://f1bonacc1.github.io/process-compose/"
install=[ {brew="process-compose"}, {go="github.com/f1bonacc1/process-compose@latest"}, {nix="process-compose"} ]
```

```rust
struct DepRecipe { binaries: Vec<String>, docs: String, install: Vec<(Installer, String)> }  // ordered
type DepCatalog = HashMap<String, DepRecipe>;   // dep id → recipe (loaded from registry/deps.toml)
```

Installers (logic, closed vocab) are code; recipes (which installer + arg per dep) are data, so a new tool whose deps install via existing installers is **pure data** (ARCHITECTURE §8.1). Shared deps (`node`, `jvm`) are defined once and referenced by many tools' `system_deps`.

### 9.3 Environment (impure probe)

```rust
struct Environment { os: Os, installers: HashSet<Installer> /* detected present */ }
enum Os { Linux, MacOs, Windows, Other }
```

`probe.rs` detects the OS and which installers are present (installer available if one of its `detect` binaries is on `PATH`). A **dep** is present if one of its `binaries` is on `PATH`. No execution, no version (v1).

### 9.4 Resolver (pure, recursive) & Report

```
resolve(dep_id, env, catalog, seen) -> Plan | Unresolved:
    if dep_id ∈ seen:                  return Unresolved          // cycle guard
    rec = catalog[dep_id]
    if any(rec.binaries on PATH):      return Plan([])            // already present

    // Pass 1 (preferred): the first method whose installer is usable right now.
    for (installer, arg) in rec.install:                          // ordered preference
        if installer ∈ env.installers:                            // usable right now
            return Plan([ {installer, installer.template(arg)} ])

    // Pass 2: no installer is directly available — bootstrap one, in order.
    for (installer, arg) in rec.install:
        for bdep in installer.bootstrap:                          // [] ⇒ skip (terminal)
            sub = resolve(bdep, env, catalog, seen ∪ {dep_id})
            if sub is Plan:            return Plan(sub.steps + [ {installer, installer.template(arg)} ])
    return Unresolved                                             // → docs fallback

all_required_present = every required dep resolves to Plan([])   // i.e. already present
```

The two passes are what make a directly-usable installer win over bootstrapping an earlier-listed one: this is exactly why the `nix` path for `aiken` needs no `aikup` when `nix` is present (Pass 1 picks it in one step). When neither `nix` nor `aikup` is present, no method's installer is directly available, so Pass 2 bootstraps the `aikup` installer (via `node`/`npm`, etc.), producing a multi-step plan. A single method is still chosen per dep. (A naive single-pass walk that tried bootstrapping each method before checking later methods' installers would wrongly bootstrap `aikup` even when `nix` is present.)

```json
{ "schema_version": 1, "ok": true, "data": {
  "all_required_present": false,
  "deps": [
    { "id": "node",  "required": true,  "present": true },
    { "id": "aiken", "required": true,  "present": false,
      "plan": [ { "installer": "npm",   "command": "npm install -g @aiken-lang/aikup" },
                { "installer": "aikup", "command": "aikup install" } ],
      "alternatives": [ { "installer": "nix", "command": "nix profile install nixpkgs#aiken", "available": false } ],
      "docs": "https://aiken-lang.org/installation-instructions" }
  ]
}}
```

(The `recommended`/soft-note tier carries no members today — see §9.1 — so the example lists only required deps. A recommended dep, if reintroduced, would appear with `"required": false` and a `reason`.)

- `plan` = the ordered, possibly multi-step install sequence the resolver produced **for this host** (empty when present; omitted/empty with only `docs` when unresolved).
- `alternatives` (additive) = the recipe's *other* install methods, so the user can pick a different installer. Each is `{ installer, command, available }` where `available` = that installer is present on this host now. Ordered available-first, then those needing their installer installed; the method already used by `plan` is excluded. Omitted when the dep is present or the recipe offers no other method. The presenter lists available ones as plain commands and tags the rest `requires <installer>`.
- `required` distinguishes tiers; `all_required_present` ignores recommended deps. The presenter shows missing required deps prominently and recommended ones as a soft note with `reason`. `docs` is always available so advice is never empty (FR-20).
- Doctor output is **host-dependent by design** (it reflects detected installers) and is **not** part of the byte-identical generation contract (§11). v1 prints the plan; v2 executes it (same data, same resolver).

### 9.5 Referential integrity (tests)

- Every `system_deps` id (plus the base dep `just`) has a `registry/deps.toml` entry.
- Every installer named in any recipe is an `Installer` enum variant (also enforced at load).
- Every dep id in any installer's `bootstrap` list has a recipe entry.
- The dep graph resolves without infinite recursion (the resolver's cycle guard is exercised by a test).

### 9.6 Project scan & tool detection (standalone `doctor`)

The standalone `cardano-init doctor` takes **no flags describing the project**: it derives the dependency set by scanning the current directory. There is no generated metadata file — the project's structure *is* the source of truth (`probe::scan_project`, impure):

1. For each role in `Role::ALL`, look for its contract directory (`contract::DIR_*`: `on-chain/`, `off-chain/`, `infra/`, `devnet/`, `formal-methods/`).
2. For a present directory, the candidate tools are exactly those that declare that role (so `on-chain/` is tested only against on-chain tools — this resolves the on-chain/off-chain ambiguity without per-pair logic).
3. A tool matches if **any** of its `detect` signatures matches. Exactly one match ⇒ the component is identified. On an ambiguous multiple, a **definitive** match wins: a bare-path (existence-only) signature is a tool-unique manifest (e.g. `trix.toml`), whereas a `contains` needle only proves a *shared* file mentions the tool (e.g. a Tx3 project's `package.json` pulls in `@meshsdk` as a library, tripping MeshJS's needle). If exactly one candidate matched via a bare-path signature, that tool is identified; otherwise (zero matches, or still-ambiguous after this tiebreak) the directory is reported as **unrecognized** (renamed, modified, or a foreign project). A renamed *directory* simply isn't found, so that role is absent.
4. The required set is `{just}` ∪ the `system_deps` of every identified tool (§9.1), fed to the resolver (§9.4).

**Infrastructure is the exception.** The aggregated `infra/` component has no per-tool subdirs (it's the single cardano-up driver), so it is *not* matched against per-tool `detect` signatures. Instead the scan recognizes it by a driver marker — `infra/Justfile` referencing `cardano-up` — and reports a synthetic `cardano-up` component (`doctor::INFRA_DRIVER_ID`). Its contribution to the required set is the **union of all registered infra tools' `system_deps`** (`{docker, cardano-up}`), data-driven from the registry. So infra tools carry `detect = []`.

**Fullstack `protocol/` is scanned like a normal component.** `protocol/` is not a `Role::ALL` directory, so it is handled by a dedicated branch: if `protocol/` exists, it is matched against the `detect` signatures of the tools that declare a `[fullstack]` template (the same per-tool signatures used for the role dirs — a fullstack tool's signatures must therefore be present in its fullstack template). Exactly one match ⇒ that component is identified; zero/ambiguous ⇒ `protocol/` is *unrecognized*. Unlike infra, the identified tool is a **real registry tool**, so its `system_deps` feed the required set via the normal `registry.get` path (no synthetic id).

**Detect signatures (`detect` in `registry/tools/<tool>.toml`).** A list; each entry is either:
- a **bare path** (relative to the role dir) — matches if the file exists; or
- a **table** `{ file = "<path>", contains = "<substring>" }` — matches if the file exists *and* its text contains the substring.

```toml
# Distinctive filenames need only existence:
detect = ["aiken.toml"]
# Generic filenames need content to avoid false positives:
detect = [{ file = "package.json", contains = "@meshsdk" }]
```

The `contains` form is what keeps detection **honest without overreaching** (per the scope note above): a from-scratch JS project (e.g. Next.js) has a `package.json`, but without `@meshsdk` it is *not* identified as MeshJS — it falls into the "unrecognized" bucket. This sharpens the label and the structure check; it does **not** attempt to prove the component is viable (still `just test`'s job). Signatures are tool-author data (no Rust), consistent with the registry's extensibility promise.

---

## 10. Version-update check (planned, not yet implemented)

Goal: surface "a newer `cardano-init` is available" **before generation**, so the user can update and regenerate with newer templates rather than discovering it post-write (and deleting/regenerating). Constraints: never block agents/CI, never alter generated output, bounded latency, offline-safe.

- **Gating.** Runs only when stdout is a **TTY and not `--format json`** (interactive, or human one-shot). For json/non-TTY (agents/CI) it is skipped entirely: no network, no spinner, no notice.
- **Cached once/day.** A small file under the OS cache dir (e.g. `~/.cache/cardano-init/update-check`) stores last-checked date + latest-seen version. Already checked today → cached result, **zero network, zero latency**.
- **Surfaced before the write phase; latency hidden where possible:**
  - **Interactive:** the check fires async at process start and completes during tool selection; the notice (if any) shows before generation with **no added latency**.
  - **Human one-shot:** no think-time to mask it, so the async check is joined with a **≤1s deadline** behind a `Checking for updates…` spinner before writing; on hit → notice then generate; on timeout/offline → proceed (worst case **+1s, once/day**).
- **Informational, not a gate.** The notice prints the newer version + suggested update command, then continues with the current version (the user may Ctrl-C to update first). It never blocks beyond the deadline and never alters generated output (determinism, A-3).
- **Fail-silent.** Best-effort GET of the latest release tag (GitHub releases API); offline/timeout/parse error → no-op. Requires a minimal HTTPS client (impl detail; off the generation path).
- `--dry-run` writes nothing, so the delete/regenerate concern doesn't apply; the notice may still show (same gating).

---

## 11. Determinism & reproducibility

Identical `(binary, Selection)` ⇒ byte-identical tree. Rules:

1. **Plan order** is fixed (§6.1): base → blueprint → roles in `Role::ALL` order → optional.
2. **Assignments are reordered into `Role::ALL` order** for emission (user/flag order does not affect output).
3. **Infrastructure tools sorted by `tool_id`**.
4. **Maps emitted in sorted-key order**: `env_vars` and any `HashMap` reaching output use a sorted/canonical view (spec: back `env_vars` with `BTreeMap` or sort at the boundary).
5. **`nix_packages`**: dedup preserving first-seen order across assignments (already so).
6. **Newlines LF, UTF-8, single trailing newline**; no timestamps, no absolute paths, no host-dependent content in generated files.
7. **Snapshot tests** over `--dry-run` and rendered output for a fixed set of selections guard all of the above.

> Implementation note: today `roles` is a `HashMap` and `assignments` keep flag order; realizing rules 2–4 (and `env_vars` ordering) is tracked work.

---

## 12. Edge-case matrix


| Situation | Behavior | Code / exit |
|-----------|----------|-------------|
| One-shot flags without `--name` | error | `name_required` / 2 |
| `--name` invalid (empty, `.`-lead, space, `/`) | error | `invalid_project_name` / 2 |
| Unknown tool id | error, list valid tools for role | `unknown_tool` / 2 |
| Tool doesn't fill the role | error, list tool's valid roles | `tool_role_mismatch` / 2 |
| No roles selected | error | `no_roles_selected` / 2 |
| `--infra X --infra X` | de-duplicated (keep first) | ok |
| `--fullstack X` (X has `[fullstack]`) | one `protocol/` component | ok |
| `--on-chain X --off-chain X` (X has `[fullstack]`) | collapses to one `protocol/` component | ok |
| `--on-chain X --off-chain X` (X has no `[fullstack]`) | two separate folders (fallback) | ok |
| `--fullstack X` (X has no `[fullstack]`) | error, list fullstack-capable tools | `fullstack_unsupported` / 2 |
| `--fullstack X --on-chain Y` (or `--off-chain Y`) | error | `fullstack_conflict` / 2 |
| Infra-only selection | no `blueprint/` dir | ok |
| Target dir absent | created | ok |
| Target dir empty | proceed | ok |
| Target dir non-empty | refuse | `dir_exists` / 1 |
| `--dry-run` | print plan, write nothing | ok / 0 |
| Interactive: user declines confirm | abort, no write | / 0 |
| Registry empty / dup id / unknown role (build-time data) | fail load | `registry_load` / 1 |
| Manifest missing/malformed, asset missing, render fails | fail | `scaffold_error` / 1 |
| `json` mode but interactive input needed | error, never prompt | usage / 2 |


---

## 13. Non-functional

- **Language/edition:** Rust 2024 edition (the code uses let-chains and `&[Role]` consts). MSRV pinned in `Cargo.toml`/CI to the stable that supports those (≥1.88).
- **Dependencies (current):** `clap`, `dialoguer`, `minijinja`, `serde`, `serde_json`, `toml`, `rust-embed`, `console`, `indicatif`, `comfy-table`, `miette`, `thiserror`; `libc` (Unix-only, SIGPIPE reset); `tempfile` (dev). **Planned additions:** a minimal HTTPS client for §10 (e.g. `ureq`), kept off the generation path. The generated *project* always depends on `just`, plus the `system_deps` of whichever tools were selected.
- **Distribution:** single statically-linked binary; generation works fully offline.
- **Platforms:** Linux, macOS, Windows. Exec-bit-free output (§4.5) and LF normalization (§11) keep behavior identical across them.

---

## 14. Open technical decisions

None currently open. (OD-1, the hosted-web strategy, is closed: the web
front-end has been dropped — the CLI is the only surface.)

---

## 15. In-place project updates (`add` / `remove`)

`cardano-init add`/`remove` edit an **already-generated** project's role/tool composition in the current directory: they add, remove, or replace whole component folders and re-wire the shared top-level files. This is deliberately **not** version management (PRD §5.2): it never pins, upgrades, or migrates the *tooling itself*, and it never rewrites the user's code inside a component it keeps. The change is expressed as a mutation of the project's `Selection`, then applied under a git safety net.

Modules (purity invariant intact, ARCHITECTURE §2): reconstruction is the impure edge in `doctor::probe::reconstruct` (reads the tree); the change-set is pure logic in `scaffold::update`; the disk side effect is `scaffold::writer::apply_update`; the CLI orchestration is `cli::update`. The validation gates are the same pure functions `init` uses (`registry::compat::check`, the experimental predicate), run on the *resulting* selection.

### 15.1 The model: components vs the shared layer

Every generated project is exactly two things, and the update engine treats them differently.

**Component slots** — one directory per contract role, plus the fused `protocol/` slot (`contract::DIR_*`):

| Slot | Dir | Multiplicity | On change |
|------|-----|--------------|-----------|
| on-chain | `on-chain/` | one tool | replace dir |
| off-chain | `off-chain/` | one tool | replace dir |
| infrastructure | `infra/` | **many tools, one aggregated dir** | re-render in place |
| devnet | `devnet/` | one tool | replace dir |
| formal-methods | `formal-methods/` | one tool | replace dir |
| protocol (fused) | `protocol/` | one fullstack tool | replace dir |

A component is **self-contained and standalone** (§7): its rendered content does not depend on which sibling roles are present. This is the load-bearing guarantee — **a slot whose tool is unchanged is never touched** (§15.4).

**Shared layer** — top-level files derived from the *whole* selection, re-rendered on any change: `Justfile`, `.env`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `.gitignore`, and (under `--nix`) `flake.nix` / `.envrc`, plus the `blueprint/.gitkeep` marker.

The update is: **reconstruct → confirm → mutate → validate → diff the slots → re-render the shared layer → write under a git safety net.**

### 15.2 Reconstructing the current `Selection` (detection, not a manifest)

An update needs the project's current `Selection` as its base state. Rather than persist a manifest at scaffold time, it **reconstructs by detection** — the same choice `doctor` makes (§9.6): the project's structure *is* the source of truth, so there is no second source that can silently drift from the tree. Every field of `Selection` is recoverable, and the one historically "lossy" field — the infra provider set — is present verbatim in `infra/Justfile`.

`reconstruct(root, registry)` extends `probe::scan_project` and yields a best-effort selection plus the items it could not identify:

```
reconstruct(root, registry) -> Reconstructed {
    selection: Selection,          // best-effort
    unrecognized: Vec<UnrecognizedDir>,
    low_confidence: Vec<Field>,    // fields we had to guess (e.g. network, infra)
    unknown_infra: Vec<String>,    // cardano-up packages not in the registry
}
```

- **Roles & tools** — directly from `scan_project`. Each detected component becomes a `RoleAssignment` (a detected `protocol/` becomes the two assignments `{on-chain→T, off-chain→T}` the planner re-collapses).
- **Infrastructure providers** — recovered by parsing `infra/Justfile` for `cardano-up install <package>` lines, mapping each `<package>` back to a tool via `ToolDef.infra.cardano_up_package`. Unknown packages are surfaced, not silently dropped.
- **network** — parsed from `CARDANO_NETWORK=` in `.env`. **nix** — `flake.nix`/`.envrc` present. **project_name** — the root directory name (only ever used to render text; a wrong guess is git-recoverable).

Any field not cleanly recoverable is marked `low_confidence`.

### 15.3 Confirm — the trust boundary

Reconstruction is **never trusted silently**; this is what neutralizes detection's one real risk (recovery logic coupled to generated template text). Before any mutation:

- **Interactive** — the reconstructed selection and any `unrecognized`/`low_confidence` items are shown, and the user confirms or corrects. On a **clean** git tree the applied change is fully reviewable/revertible via `git diff`, so it is written straight away (no confirm prompt — good agent DevX); the prompt appears only when `--force` is overriding a **dirty** tree, where the change cannot be cleanly separated from existing edits.
- **Non-interactive / `--format json`** — no prompts. The reconstruction must be fully recognized: **any `unrecognized` dir is a hard error** (`project_unrecognized`, exit 2). The tool never guesses in automation.

### 15.4 Validate the mutated selection

The mutation produces `S_new`, run through **exactly the same gates as `init`** — no new validation logic:

- **Role uniqueness** — one tool per non-infra role; infra repeatable and deduped keep-first (§3.4), so "add an infra provider already present" is an idempotent no-op.
- **At least one role** — removing the last role is refused (`no_roles_selected`); a project is never left empty.
- **Compatibility gate** — `registry::compat::check(S_new.assignments, registry)` (§3.2.2). The gate runs on the *result*, not the delta: adding Dolos to an Evolution project, or swapping MeshJS→Tx3 next to a Yaci devnet, must trip the same check a fresh scaffold would. Stops with `incompatible_tools` unless `--ignore-warning`.
- **Experimental gate** — if `S_new` newly includes an experimental tool, require `--allow-experimental` / interactive confirm (§3.2.1; `experimental_not_allowed`).

Because `Selection`-validity is by construction (ARCHITECTURE §3.3), a validated `S_new` is indistinguishable from one `init` would have built.

### 15.5 The change set

Pure logic over `S_old`, `S_new`, and the registry (`scaffold::update`, beside the planner). For each **slot**, compare the tool in `S_old` vs `S_new`:

| Transition | Action |
|-----------|--------|
| absent → present | **CREATE**: plan+render that component into its dir. Precondition: the dir must not already exist on disk; if it does (a foreign/unrecognized dir), abort (`slot_occupied`). |
| present → absent | **REMOVE**: `rm -rf <dir>` (removes user-added files in that dir too — intentional; git is the net). |
| present → present, tool changed | **REPLACE**: REMOVE then CREATE. |
| present → present, tool same (non-infra) | **KEEP** — never touched. |
| infra: provider set changed (dir stays) | **RE-RENDER IN PLACE**: overwrite `infra/`'s managed files (`Justfile`, `README.md`, `scripts/write-env.sh`) from the new provider set. |
| infra → empty | **REMOVE** `infra/`. |

**Fusion boundary** is just rows in this table — no special "migration":
- two dirs (`on-chain`+`off-chain`) → fullstack tool = REMOVE both + CREATE `protocol/` (a full replace; nothing is carried over — the code in the two dirs is deleted, loudly, git-recoverable).
- `protocol/` → separate tools = REMOVE `protocol/` + CREATE the new dir(s). "Drop the off-chain half of a fused `protocol/`" is expressed as *replace `protocol/` with an on-chain tool* — the user must name that tool; there is no in-place split of a fused codebase.

**Shared layer** is always recomputed from `S_new` and written **per-file with a content diff** — a file is only rewritten if its bytes change (so a slot swap that doesn't alter, say, `.gitignore` leaves it alone). `blueprint/.gitkeep` is added/removed to match the predicate `any(role != Infrastructure)` (§6.2); `flake.nix`/`.envrc` follow the nix flag.

**The "unchanged slot is safe" guarantee.** Removing off-chain from `{on-chain→aiken, off-chain→meshjs}`: on-chain is `KEEP` (same tool), so `on-chain/` is never in the write set; the standalone-component contract guarantees aiken's render doesn't depend on the removed sibling, so even the content diff shows no change. Only `off-chain/` is removed and the shared layer re-wired.

### 15.6 Safety, write ordering & dry-run

`init`'s writer assumes an empty dir (§6.4, "no `--force`, never overwrites"). Updating writes into a **populated, user-owned** tree, so the update path adds guards *around* the writer rather than changing `init`'s policy:

- **Git safety net (required).** The update refuses to run on a **dirty** working tree so every create/overwrite/delete is reviewable and revertible via `git diff` / `git restore` (`worktree_dirty`, exit 1). Overridable with `--force`. A **non-git** project is treated like a dirty tree: refuse unless `--force`. New projects are git-initialized with an initial commit at scaffold time so the net works immediately.
- **No merge engine.** Managed/shared files are overwritten outright; the user reconciles any hand-edits through git. There is no three-way merge and no `.new` shadow files.
- **Write ordering.** `apply_update` (1) `rm -rf`s the `Remove`/`Replace` dirs first — so a `Replace` clears the old tool's files before the new ones are written into the same path; then (2) writes the created/replaced/re-rendered component files; then (3) overwrites only the shared files whose bytes changed. There is nothing else to persist (no manifest). **Kept components are never in the plan**, so user work in an unchanged slot is untouched wherever a crash lands; a crash mid-rewrite of a *changed* slot is covered by the git safety net, and re-running is idempotent.
- **`--dry-run`.** Prints the change set (CREATE / REMOVE / REPLACE / RE-RENDER / shared-file overwrites) and writes nothing — the auditable plan for humans and agents. `--format json` emits the same as structured data. Each change row names the tool that moved (e.g. `replace Aiken → Scalus`, `add Kupo`, infra `+Dolos`/`-Kupo`).

### 15.7 CLI surface

```
cardano-init add    --off-chain tx3    # add/replace a slot (same flag vocabulary as init)
cardano-init add    --infra ogmios     # repeatable; dedup keep-first
cardano-init remove --off-chain        # drop a role (by role, not tool)
cardano-init remove --infra kupo       # drop one infra provider
```

- `add`/`remove` reuse `oneshot`'s per-role flag parsing and validation verbatim. `add` takes the same role flags as init (`--on-chain`, `--off-chain`, `--fullstack`, `--infra` (repeatable), `--devnet`, `--formal-methods`); `remove` takes bare role flags plus `--infra <id>`.
- Global flags honored: `--dry-run`, `--ignore-warning`, `--allow-experimental`, `--format`, plus `--force`.
- Deliberately **not** a `swap` verb: an `add --off-chain X` onto an occupied off-chain slot *is* the swap (REPLACE), reported as such in the diff so it is never silent.
- An interactive `edit` (re-open the selector seeded from the detected stack) was considered and **dropped** as low-value — `add`/`remove` (with `--dry-run`) already cover editing the stack.

### 15.8 Edge-case matrix (update path)

Error codes are defined in §2.5. This extends the init matrix (§12) for `add`/`remove`.

| # | Situation | Handling |
|---|-----------|----------|
| 1 | Add a role not present | CREATE new dir + re-wire shared layer. |
| 2 | Add a tool to an occupied non-infra slot | REPLACE (remove+create); shown as a swap in the diff; destructive → git-gated. |
| 3 | Add an infra provider already present | Dedup keep-first → `nothing_to_change` (idempotent). |
| 4 | Remove a role that isn't present | `nothing_to_change`. |
| 5 | Remove the **last** non-infra role | Allowed; `blueprint/.gitkeep` dropped (predicate flips). |
| 6 | Remove on-chain while consumers remain | Allowed; consumers already degrade gracefully per contract (§7) when `blueprint/plutus.json` is absent. |
| 7 | Remove the last remaining role | Refused — `no_roles_selected`. |
| 8 | Swap that breaks off-chain↔provider compat | `incompatible_tools` unless `--ignore-warning` (gate on `S_new`). |
| 9 | Add/swap in an experimental tool | `experimental_not_allowed` unless `--allow-experimental`. |
| 10 | Two dirs → fullstack tool (fuse) | REMOVE `on-chain/`+`off-chain/`, CREATE `protocol/`. Full replace, git-recoverable; not a merge. |
| 11 | `protocol/` → drop off-chain half | REPLACE `protocol/` with a user-named on-chain tool; no in-place split. |
| 12 | Same tool on both roles, no `[fullstack]` | Two separate dirs (not fused); each removable independently. |
| 13 | Infra provider set changes | RE-RENDER `infra/` in place from the new set; other slots untouched. |
| 14 | Unchanged slot (e.g. Aiken while off-chain changes) | KEEP — provably untouched (§15.5). |
| 15 | Unrecognized/renamed/foreign component dir | Interactive: surfaced, then a confirm to proceed with the detected stack (the odd dir is left in place, ignored). Non-interactive: `project_unrecognized` (fatal). |
| 16 | Ambiguous detection (2+ tools match one dir) | Resolved by definitive-match tiebreak (§9.6): a single bare-path/manifest match wins over shared-file `contains` matches. Only if that leaves 2+ still tied is the dir treated as unrecognized. |
| 17 | `infra/Justfile` hand-edited so providers unparseable | Recovered set shown in confirm; user corrects; non-interactive → treat as unrecognized. |
| 18 | Unknown `cardano-up` package in `infra/Justfile` | Surfaced, not dropped; user confirms/removes. |
| 19 | `.env` missing/edited `CARDANO_NETWORK` | Field marked low-confidence; asked/defaulted in confirm. |
| 20 | Dirty git tree / not a git repo | `worktree_dirty` unless `--force`. |
| 21 | Crash mid-write | Creates-before-deletes ordering → no kept component lost; re-run is idempotent. |
| 22 | `--dry-run` | Prints the change set; writes nothing. |
| 23 | Slot swap that leaves a shared file byte-identical | Content diff skips it — no spurious rewrite. |

### 15.9 Determinism

Determinism (§11) is preserved: reconstruction + canonical planning are deterministic, so `--dry-run` output and the applied change set are reproducible for a given `(binary, tree, mutation)`.

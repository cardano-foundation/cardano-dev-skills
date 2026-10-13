# Adding a Tool to cardano-init

This guide is for contributors who want to integrate their own tooling into `cardano-init`. If your tool fills one of the supported roles (**on-chain**, **off-chain**, **infrastructure**, **devnet**, or **formal-methods**) you can add it by providing two things:

1. A registry entry (`registry/tools/<your-tool>.toml`)
2. A template directory (`templates/<your-tool>/<role>/`)

No changes to Rust source code are required. Because all templates and registry files are embedded into the binary at compile time via `rust-embed`, you will need to recompile (`cargo build`) after adding your files.

---

## Step 1: Create the registry entry

Create `registry/tools/<your-tool>.toml`. Use the tool's id as the filename.

```toml
[tool]
id          = "mytool"                  # Unique identifier, used in CLI flags
name        = "MyTool"                  # Human-readable name shown in the UI
description = """\
One to three sentences. What does this tool do, and when should \
someone choose it over alternatives?"""
website     = "https://mytool.dev"
languages   = ["typescript"]           # Languages the generated project uses
system_deps = ["mytool-cli"]           # What the user needs installed (drives `doctor`; each id needs a registry/deps.toml entry)
nix_packages = ["mytool"]              # Nix package name(s), if available (omit if none)
# nix_self_contained = true            # optional; set if the template ships its own component flake (keeps nix_packages out of the top-level shell — see The manifest)
detect      = ["mytool.config.js"]     # How `doctor` recognizes this tool in a scanned project (see below)

[roles.off-chain]                      # The role this tool fills
template = "mytool/off-chain"          # Path under templates/ for this role
```

**`detect` signatures** tell `cardano-init doctor` how to recognize your tool inside a generated project's role directory (so it knows which `system_deps` to check). Each entry is either a **bare path** (matches if the file exists) or a table `{ file = "<path>", contains = "<substring>" }` (matches if the file exists *and* contains the substring). Use the `contains` form when the filename is generic — e.g. a `package.json` only means *your* tool if it references your package:

```toml
detect = ["mytool.config.js"]                              # distinctive filename → existence is enough
detect = [{ file = "package.json", contains = "mytool" }]  # generic filename → require content
```

Only tools that declare a role are tested against that role's directory, so signatures only need to disambiguate *within* a role. A directory that matches nothing is reported as "unrecognized" — `doctor` checks dependencies, it does not validate that the component builds (that's `just test`).

A tool can fill multiple roles. Add one `[roles.<role>]` section per role:

```toml
[roles.on-chain]
template = "mytool/on-chain"

[roles.off-chain]
template = "mytool/off-chain"
```

### Fullstack tools (one component for both on-chain and off-chain)

If your tool implements **both** on-chain and off-chain in one language and one build (e.g. Scalus), you can offer a **fullstack** experience: add a `[fullstack]` table with a third template. When a user assigns your tool to both roles (`--fullstack mytool`, or `--on-chain mytool --off-chain mytool`), the two collapse into a single unified **`protocol/`** component built from that template, instead of two folders that hand off through `blueprint/plutus.json`.

```toml
[roles.on-chain]
template = "mytool/on-chain"    # used when mytool fills on-chain only (e.g. with a different off-chain tool)

[roles.off-chain]
template = "mytool/off-chain"   # used when mytool fills off-chain only

[fullstack]
template = "mytool/fullstack"   # used when mytool fills BOTH → one protocol/ component
```

All three shapes are first-class, so you provide three templates. Rules:
- `[fullstack]` **requires both** `[roles.on-chain]` and `[roles.off-chain]` (validated at load).
- `protocol` is **not** a role — you never write `[roles.protocol]`. It is a fused component the CLI derives from the two role assignments.
- The `protocol/` component must still honor the interface contract (Step 3): its `build` **writes `../blueprint/plutus.json`** and it reads/writes `../.env`, so it composes with devnet/formal/infra like a normal on-chain producer. Internally it may share types between its on-chain and off-chain halves and skip the blueprint round-trip — that private short-cut is the whole point — but the external seam is mandatory.
- Your tool's `detect` signatures must be present in the fullstack template too, so `doctor` recognizes the tool inside a `protocol/` directory.
- Adding a fullstack tool is still **pure data** — no Rust changes.

### Valid role names

| Role key | Description |
|---|---|
| `on-chain` | Smart contract / validator logic |
| `off-chain` | Transaction building and submission |
| `infrastructure` | Indexers, chain followers, node providers |
| `devnet` | Local throwaway chain to develop and integration-test against |
| `formal-methods` | Specification and automated verification |

### Declaring provider compatibility (`[compat]`)

An off-chain tool reaches a local chain over one or more **seams** — the wire protocols it speaks — and its **providers** (the selected devnet and/or infra tools) each expose some set of seams. If none of the selected providers serve a seam the off-chain tool consumes, they can't talk and the generated project won't run. The optional `[compat]` table lets the CLI catch that **before** generation instead of handing the user a broken project. It's pure data, decided by `registry::compat` with no per-pair logic.

The seams today:

| Seam | Wire protocol | Served by | Consumed by |
|---|---|---|---|
| `blockfrost` | Blockfrost-compatible REST | Yaci, Dingo | Evolution, Mesh, Scalus |
| `u5c` | UTxORPC (gRPC) | Dolos | Mesh |
| `trp` | Tx3 Transaction Resolve Protocol | (self-hosted; Dolos/Demeter) | Tx3 |
| `ogmios` | Ogmios JSON-RPC | Ogmios | Evolution, Mesh |
| `kupo` | Kupo HTTP | Kupo | Evolution |

`ogmios` + `kupo` together form a **Kupmios** provider; an off-chain tool that uses Kupmios lists both, and a match on either counts as usable (so a partial selection is allowed, not force-completed).

A seam means "a **working** provider for the templates," not merely "an endpoint exists." Dolos, for instance, exposes a Blockfrost-compatible "minibf" API, but it omits tx evaluation (`/utils/txs/evaluate`), which off-chain Blockfrost providers need to budget script execution units — so Dolos declares `u5c` (its complete provider), not `blockfrost`. Declare a seam only when a tool can actually build the (script-based) reference example over it.

Declare what your tool consumes or serves:

```toml
# An off-chain tool: which seam(s) it can consume.
[compat]
consumes = ["blockfrost", "kupo", "ogmios"]   # e.g. Evolution (Blockfrost + Kupmios)

# A devnet or infra tool: which seam(s) it exposes to off-chain consumers.
[compat]
serves = ["blockfrost"]            # e.g. Yaci (devnet) or Dingo (infra); Dolos serves ["u5c"]

# A tool that bundles its OWN devnet and needs no devnet role at all.
[compat]
consumes = ["trp"]
self_contained_devnet = true       # e.g. Tx3 — a separately-chosen devnet is reported incompatible
```

How the gate behaves — it evaluates the off-chain tool against the **union of all selected providers (the devnet plus every infra tool)**:

- **Compatible** when at least one selected provider serves a seam the off-chain tool consumes. So `--off-chain meshjs --infra dolos` works (u5c), and `--off-chain evolution --devnet yaci --infra dolos` works too — Yaci covers Evolution's Blockfrost seam even though the extra Dolos doesn't.
- **Incompatible** when providers are selected but none serve a consumed seam → one-shot **stops generation** with `CliError::IncompatibleTools` (exit 2), listing the providers that would work for the off-chain tool and the off-chain tools that would work with the selected providers; `--ignore-warning` downgrades the stop to a warning. Interactive mode shows an incompatible **devnet** option as `✗ unavailable — <reason>` (infra is multi-select with union semantics, so individual infra picks aren't disabled — the run-level gate covers them).
- **Self-hosting** (`self_contained_devnet`) makes a separately-selected devnet redundant/incompatible regardless of seams.
- **`[compat]` is optional and permissive**: a tool with no `[compat]` table (or empty `consumes`/`serves`) imposes no constraint. Supplementary infra that isn't an off-chain endpoint (a bare node, a submit API) simply declares no `serves`, so it never triggers a conflict, and an off-chain tool with no selected provider falls back to a public provider per the interface contract. A mismatch only becomes a hard stop when both sides declare seams.

---

## Step 2: Create the template directory

Create a directory at the path you declared in the registry entry, e.g. `templates/mytool/off-chain/`. It must contain a `manifest.toml` plus all the files it declares.

### The manifest

`manifest.toml` lists every file your template emits.

```toml
[manifest]
summary = "MyTool off-chain project with a hello-world transaction"

[[files]]
source = "Justfile.jinja"      # Path relative to this template directory
dest   = "Justfile"            # Destination relative to the role directory

[[files]]
source = "src/index.ts"
dest   = "src/index.ts"

[[files]]
source = "package.json.jinja"
dest   = "package.json"

[[files]]
source = "flake.nix.jinja"     # optional: `when` gates emission on the selection
dest   = "flake.nix"           # `when = "nix"` ⇒ emit only under `--nix`
when   = "nix"
```

A file may carry an optional `when` guard. The only condition today is `when = "nix"`, which emits the file only when the project is generated with `--nix`. Use it to ship a component-local Nix flake — as the Plinth on-chain template does, bundling the recommended haskell.nix setup from `IntersectMBO/plinth-template`. A tool that does this should also set `nix_self_contained = true` in its registry entry. Its `nix_packages` are then not listed as bare attributes in the top-level dev shell (a plain nixpkgs `mkShell` cannot build a haskell.nix project); instead the top-level flake adds the component as a `path:./<dir>` input and composes its dev shell via `inputsFrom`, so the toolchain — and `just build` for that component — is available from the project root.

**Commit the `flake.lock`.** A component flake must also ship a pinned `flake.lock` (emit it with `when = "nix"`). Without it, inputs resolve at HEAD — for haskell.nix that is frequently broken (e.g. a missing bootstrap-GHC attribute) and never reproducible. Vendor a known-good lock (Plinth's is taken verbatim from upstream) and keep it consistent with `cabal.project`'s `index-state`.

Whether a file is rendered through MiniJinja is determined solely by its source filename: files ending in `.jinja` are rendered, all others are copied verbatim. Name a file `foo.jinja` when it contains template variables or conditional blocks; leave it without the extension when it should be copied byte-for-byte (source code, lock files, binary assets, or any file whose content contains `{{` or `{%` as literal syntax).

### Directory layout

```
templates/
└── mytool/
    └── off-chain/
        ├── manifest.toml
        ├── Justfile.jinja
        ├── package.json.jinja
        └── src/
            └── index.ts
```

---

## Step 3: Implement the interface contract

Every template, regardless of role, must conform to the interface contract defined in `src/contract.rs`. This is what allows any on-chain tool to compose with any off-chain tool without per-pair integration logic.

### Mandatory Justfile targets

Every template **must** include a `Justfile` that exposes these three targets:

| Target | Purpose |
|---|---|
| `build` | Compile / package the component |
| `test` | Run the component's tests |
| `clean` | Remove build artifacts |

The top-level project Justfile delegates to these by calling `just -f <role>/Justfile <target>`, so the names are non-negotiable. The top level aggregates only these three (the terminating, composable tasks).

### Optional: `dev`

| Target | Purpose |
|---|---|
| `dev` | Start development mode (watch, REPL, local daemon, local devnet) |

`dev` is **optional** — add it only when your tool has a genuine long-running or interactive mode (don't ship a no-op `dev` just to fill the slot). It is **never aggregated** at the top level; the developer runs it directly (`just -f <role>/Justfile dev`). A `dev` that provisions a local chain endpoint writes the standard connection vars to `../.env` (see below).

### The reference example: Gift Card

Every on-chain, off-chain, and fullstack template implements the **same** example — a **gift card** — so that any on-chain tool genuinely composes with any off-chain one (an Aiken contract driven by the Scalus off-chain, a Scalus contract driven by the MeshJS off-chain, and so on). Matching it is what makes a new tool interoperable, not just self-consistent.

The flow is two validators:

- **`gift_card` (minting policy)** — a one-shot policy that mints exactly one token, gated by a specific seed UTxO that must be spent (so the policy id is unique). Burning that one token is the redeem step.
- **`redeem` (spending validator)** — guards the gift locked at its script address; it only allows the UTxO to be spent when the gift-card token is burned in the same transaction.

To stay interchangeable, keep the **wire ABI** identical across tools:

| Aspect | Convention |
|---|---|
| Blueprint titles | `<module>.gift_card.mint` and `<module>.redeem.spend` — off-chain tools locate validators by the `<validator>.<purpose>` **suffix**, so the module prefix is free. |
| `gift_card` parameters | Two **separate** compile-time parameters, applied with `applyParamsToScript`: the token name (`ByteString`) then the seed `OutputReference`. |
| `redeem` parameters | Two separate parameters: the token name (`ByteString`) then the gift-card policy id (`ByteString`). |
| Seed `OutputReference` | The flat shape `Constr 0 [transaction_id, output_index]` — the transaction id is a **bare** byte string, not wrapped in a `TxId` constructor (this is Aiken's `OutputReference` / MeshJS's `outputReference`). |
| Mint redeemer | An `Action` enum: `Mint` = `Constr 0 []`, `Burn` = `Constr 1 []`. |
| Redeem redeemer / datum | Unused by the validator — burning the token is the authorization. |

An off-chain template consumes these by reading the compiled code straight from `../blueprint/plutus.json` and applying the parameters above (see **Off-chain tools** below), so it drives whatever on-chain tool produced the blueprint.

### Role-specific requirements

**On-chain tools** must produce the CIP-57 Plutus blueprint during `build`:

```justfile
build:
    mytool build
    cp -f output/plutus.json ../blueprint/plutus.json
```

The off-chain and devnet templates read from `../blueprint/plutus.json`. If your tool outputs to a different path, the `build` target must copy it to the canonical location. This is the primary integration seam between on-chain and off-chain.

**Off-chain tools** should build transactions against the validators **in the blueprint**, not a private recompiled copy — parameterize the `compiledCode` read from `../blueprint/plutus.json` (applying the gift-card parameters above). That is what makes the off-chain tool composable with *any* on-chain tool rather than only its own. They must also handle the case where no blueprint exists yet (a standalone off-chain project, before an on-chain component has built) — degrade gracefully, and gate any tests that need real scripts on the blueprint being present:

```justfile
build:
    @test -f ../blueprint/plutus.json || echo "Warning: no blueprint found, skipping type generation"
    npm run build
```

Off-chain tools may also read chain connection details from `../.env`, and should switch behavior on their presence — e.g. talk to a local devnet when `INDEXER_URL` is set, and fall back to a public provider otherwise:

```typescript
import * as dotenv from "dotenv";
dotenv.config({ path: "../.env" });

const indexerUrl = process.env.INDEXER_URL; // set → a local endpoint is up
```

If your off-chain tool talks a specific wire protocol (Blockfrost, TRP, UTxORPC), declare it with `consumes` in `[compat]` (see [Declaring provider compatibility](#declaring-provider-compatibility-compat)) so an incompatible provider pairing is caught before generation. A tool that bundles its own devnet (and reads no `.env` endpoint) instead sets `self_contained_devnet = true`.

**Fullstack tools** (a `[fullstack]` template, rendered into `protocol/`) must satisfy the on-chain contract from the fused component: `build` **writes `../blueprint/plutus.json`**, and the component reads/writes `../.env` like an off-chain consumer. Internally it may link its on-chain and off-chain halves directly (shared types, no blueprint round-trip); the blueprint file is written for the *other* roles (devnet/formal/infra), which still consume it. The three mandatory Justfile targets (`build`/`test`/`clean`) apply, and `dev` is optional as usual.

**Tools that provision a local chain endpoint** must write the connection details to `../.env` during `dev`. This applies to **infrastructure** services and, equally, to a **local devnet in the devnet role** (e.g. Yaci DevKit) — the seam is the `.env` keys, not the role. Use the standard variable names:

| Variable | Meaning |
|---|---|
| `INDEXER_URL` | Base URL of the chain indexer |
| `INDEXER_PORT` | Port of the indexer |
| `NODE_SOCKET_PATH` | Path to the local node socket |
| `CARDANO_NETWORK` | Target network (`preview`, `preprod`, or `mainnet`) |

```justfile
dev:
    mytool start &
    echo "INDEXER_URL=http://localhost" >> ../.env
    echo "INDEXER_PORT=1442" >> ../.env
```

Write the keys idempotently (replace in place rather than appending) so repeated `just dev` runs don't accumulate duplicate lines. Off-chain/devnet consumers read these and never need to know which tool wrote them.

**Infrastructure providers are added as data, not a new template.** The infra role is backed by a single shared `cardano-up` driver (`templates/_infra/cardano-up`), and all selected providers aggregate into one `infra/` component. To add a provider (e.g. `dolos`), you write only a `registry/tools/<provider>.toml` — no template:

```toml
[tool]
id = "dolos"
name = "Dolos"
description = "…"
website = "https://…"
languages = []                       # infra providers have no user-facing language
system_deps = ["docker", "cardano-up"]
detect = []                          # infra is scanned by a driver marker, not per-tool

[roles.infrastructure]
template = "_infra/cardano-up"       # always the shared driver

[infra]
cardano_up_package = "dolos"         # the `cardano-up install` package id
# Map cardano-up's `context env` outputs → contract .env keys. A mapping for an
# existing key (e.g. NODE_SOCKET_PATH) overrides the default at generation time.
env = [{ from = "DOLOS_SOCKET_PATH", to = "NODE_SOCKET_PATH" }]
```

If a mapping targets a contract `.env` key that isn't seeded yet (a brand-new
connection var), promote it: add a `contract::ENV_*` constant and a seeded
`KEY=` line in `templates/_base/env.jinja` so every project always carries it.
See TECH_SPEC §3.2 (infra config) and §9.6 (infra detection) for the full model.

**Devnet tools** provision a local throwaway chain. They should read both the blueprint and the `.env` if they are present, but must work if neither exists, and write the connection vars above during `dev` — that is how off-chain components reach the devnet, and it composes with any off-chain tool without per-pair code. Declare the seam(s) the devnet exposes with `serves` in `[compat]` (see [Declaring provider compatibility](#declaring-provider-compatibility-compat)) so the CLI can steer users away from an off-chain tool it can't serve.

**Formal-methods tools** have no extra contract beyond the four Justfile targets.

---

## Template variables

Any rendered file (one whose `source` ends in `.jinja`) can reference the following variables from the template context:

```jinja
{{ project_name }}          {# e.g. "my-protocol" #}
{{ network }}               {# "preview", "preprod", or "mainnet" #}
{{ blueprint_path }}        {# "blueprint/plutus.json" #}
{{ nix }}                   {# true or false #}

{# Flags for conditional sections #}
{{ has_on_chain }}
{{ has_off_chain }}
{{ has_fullstack }}         {# one tool fills both on-chain + off-chain → protocol/ #}
{{ has_infra }}
{{ has_devnet }}
{{ has_formal_methods }}

{# Per-role context (only safe to access when the corresponding has_* is true) #}
{{ on_chain.tool_id }}      {# e.g. "aiken" #}
{{ on_chain.tool_name }}    {# e.g. "Aiken" #}
{{ on_chain.language }}     {# first entry from the tool's languages list #}
{{ on_chain.dir }}          {# "on-chain" #}

{{ off_chain.tool_id }}
{{ off_chain.tool_name }}
{{ off_chain.language }}
{{ off_chain.dir }}         {# "off-chain" #}

{# Fullstack: set instead of on_chain/off_chain when one tool fills both.
   When has_fullstack is true, has_on_chain and has_off_chain are false. #}
{{ fullstack.tool_id }}
{{ fullstack.tool_name }}
{{ fullstack.language }}
{{ fullstack.dir }}         {# "protocol" #}

{{ devnet.tool_id }}
{{ devnet.dir }}            {# "devnet" #}

{{ formal_methods.tool_id }}
{{ formal_methods.dir }}    {# "formal-methods" #}

{# Infrastructure allows multiple tools simultaneously #}
{% for t in infra_tools %}
{{ t.tool_id }}
{{ t.dir }}                 {# "infra" #}
{% endfor %}

{# Nix packages from all selected tools, deduplicated #}
{% for pkg in nix_packages %}{{ pkg }}{% endfor %}
```

Your template files only need to reference the variables relevant to them. An off-chain template does not need to reference `on_chain.*` at all. The integration is handled by the base-level Justfile template, not by individual role templates.

---

## Worked example: a minimal off-chain tool

`registry/tools/mytool.toml`:

```toml
[tool]
id          = "mytool"
name        = "MyTool"
description = "A TypeScript SDK for building Cardano transactions."
website     = "https://mytool.dev"
languages   = ["typescript"]
system_deps = ["node"]
nix_packages = ["nodejs_20"]
detect      = [{ file = "package.json", contains = "mytool" }]

[roles.off-chain]
template = "mytool/off-chain"
```

`templates/mytool/off-chain/manifest.toml`:

```toml
[manifest]
summary = "MyTool off-chain project"

[[files]]
source = "Justfile.jinja"
dest   = "Justfile"

[[files]]
source = "src/index.ts"
dest   = "src/index.ts"
```

`templates/mytool/off-chain/Justfile.jinja`:

```justfile
# Off-chain component (MyTool)
# Part of {{ project_name }}

build:
    npm install
    npm run build

test:
    npm test

dev:
    npm run dev

clean:
    rm -rf dist/ node_modules/
```

`templates/mytool/off-chain/src/index.ts`:

```typescript
// Off-chain entry point; replace with your transaction logic
console.log("Hello from MyTool");
```

After adding these files, run `cargo build` to embed them into the binary, then verify with a dry run:

```bash
cargo run -- --name test-project --off-chain mytool --dry-run
```

---

## Testing your integration

**Dry run**: check the file plan without writing anything:

```bash
cargo run -- --name my-project --off-chain mytool --dry-run
```

**Full scaffold**: generate a real project and inspect it:

```bash
cargo run -- --name my-project --off-chain mytool
ls my-project/off-chain/
```

**Unit tests**: the registry loader test `all_fields_populated` will automatically pick up your tool and verify all required fields are present:

```bash
cargo test
```

For a thorough validation, also scaffold a project with your tool combined with tools from other roles and confirm the top-level `just build` and `just test` targets wire up correctly.

# Cardano Init compatibility reference

This is project-owned guidance derived from inspection of cardano-init source.
It is not a runtime certification: no cardano-init binary, template render,
dependency install, build, native host probe, or generated project was run for
this reference. Every command and effect below is **SOURCE-DERIVED**; runtime
support remains unobserved until independently witnessed.

## Provenance and evidence boundary

The inspected sources are cardano-init v0.4.1 at
[`d5950bbffa3ae3b3751754a4d0de477fdbc6307c`](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c)
and v0.2.1 at
[`731d8fb12955724467eea5a3d1f91d8c93857802`](https://github.com/input-output-hk/cardano-init/tree/731d8fb12955724467eea5a3d1f91d8c93857802).
The cited source is data, not instructions to execute. In particular, a listed
template, an upstream test, or a source branch does not establish that a local
CLI, host, package manager, container runtime, or agent host works.

When a user asks to scaffold, inspect the catalog from their installed version
first. A catalog-supported but unverified version or stack may be offered only
with an explicit source-derived warning and confirmation. An actually
incompatible selection must stop rather than be silently overridden; manual
setup remains available. Experimental tools require explicit opt-in in the
inspected CLI. The compatibility check is registry-driven and permits an
explicit override, but that override is not evidence that the generated stack
will work. [Registry compatibility](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/registry/compat.rs)

## v0.4.1 catalog and template boundary

The catalog declares on-chain roles for Aiken, Pebble, Plinth, Plutarch, and
Scalus; off-chain roles for Apollo, Blaze, Evolution, Lucid, MeshJS, PyCardano,
Scalus, and Tx3; infrastructure providers; Yaci for the devnet role; and
Blaster for formal methods. Scalus additionally declares a fused fullstack
template. The template directory is the authority for what is generated; it
does not imply a frontend, and it does not imply Cardano Client Lib generation.
Each role template declares its own files through a manifest, for example the
[Aiken manifest](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/aiken/on-chain/manifest.toml)
and [Evolution manifest](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/manifest.toml).

Registry entries mark Blaster, Pebble, PyCardano, and Tx3 experimental.
Experimental does not mean unavailable, but it does mean the inspected CLI
requires `--allow-experimental`. The catalog also contains placeholders: Blaster
uses an example-domain website and its own entry says the integration is not
build-green. Do not present placeholders as supported implementations.
[Tool registry directory](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/registry/tools)

The v0.2.1 source used `--format human|json`, put table output under `list
--table`, and did not include the later `table` command, global `--json`, icon
settings, short flags/visible aliases, or `--no-spec`. v0.4.1 has those flags
and a separate `table` command. Both sources use JSON schema version `1`; that
shared number does not mean flag sets or document layout are interchangeable.
[v0.2.1 CLI](https://github.com/input-output-hk/cardano-init/tree/731d8fb12955724467eea5a3d1f91d8c93857802/src/cli/mod.rs)
[v0.4.1 CLI](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/args.rs)

## Generated instructions and mutation model

Initial planning renders base files including `AGENTS.md`, a `CLAUDE.md` import,
the top-level Justfile, README, environment file, and selected component files.
The source tests identify the initial `CLAUDE.md` import as `@AGENTS.md`.
[Scaffold tests](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/scaffold/mod.rs)
That is generated project context, not plugin installation and not proof that
any particular agent host loads it.

SOURCE-DERIVED initial creation rejects a nonempty target, while `--dry-run`
plans without writing. A successful initial scaffold then makes a best-effort
Git repository and initial commit; missing Git, being inside another repository,
or a failed commit lead to recorded degraded outcomes rather than necessarily
failing scaffolding. [Git behavior](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/git.rs)

SOURCE-DERIVED `add` and `remove` first require a recognized project and, unless
`--force` is supplied, a clean Git tree. They preview with `--dry-run`; updates
create, remove, replace, or rerender component slots. Kept component directories
are left alone, but replacement/removal deletes the old directory before writes,
and shared files can be rewritten. An I/O failure can therefore leave partial
changes; source review is not an atomic-write guarantee.
[Update plan](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/scaffold/update.rs)
[Writer](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/scaffold/writer.rs)

For agent-driven work, treat canonical Cardano context setup as a requested
scaffolding follow-up: reuse or update an existing canonical context rather than
adding a duplicate import or block. Custom divergence, ambiguous ownership, or
newer content needs a user decision. Do not claim cardano-init itself preserves
additions, installs a plugin, or runs a standing detector.

## Representative Aiken + Evolution candidates

For the source-defined Aiken on-chain plus Evolution off-chain selection, these
are candidates, not verified commands:

| Goal | SOURCE-DERIVED candidate | Conditions and signal |
| --- | --- | --- |
| Compile Aiken and publish the blueprint | `just build-on-chain` | Runs `aiken build`, then copies `plutus.json` to the shared blueprint path. Requires the Aiken executable; the template pins compiler `v1.1.24` and declares a GitHub stdlib dependency. |
| Run Aiken checks | `just test-on-chain` | Runs `aiken check`; no claim is made here about test count or success. |
| Build Evolution bindings | `just build-off-chain` | Runs an install helper followed by `npm run --silent build`. The prebuild hook bundles a blueprint, using a null placeholder if the shared blueprint is absent. |
| Run non-E2E Evolution tests | `just test-off-chain` | Runs the same install helper then `npm run --silent test`, which maps to `vitest run --passWithNoTests`; zero tests may exit successfully. |
| Compose the normal build/test roles | `just build` / `just test` | The aggregate test builds on-chain before on-chain tests and off-chain tests, but also includes selected infrastructure, devnet, or formal-method targets. Do not use aggregate `test` as a non-E2E claim when such roles are selected. |

The Aiken and Evolution recipes establish these prerequisites and ordering:
[Aiken Justfile](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/aiken/on-chain/Justfile.jinja),
[Aiken configuration](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/aiken/on-chain/aiken.toml.jinja),
[Evolution Justfile](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/Justfile.jinja),
[Evolution package scripts](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/package.json.jinja),
and [top-level Justfile](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/_base/Justfile.jinja).

The Evolution helper invokes `npm install` when `node_modules` is absent or
older than `package.json`, so it can download project dependencies and run
package lifecycle work. `npx tsx` is used by the optional create/redeem recipes;
do not rely on it to fetch a missing CLI. Aiken may resolve the declared GitHub
dependency during its build. Optional `dev` recipes can start a process; selected
infrastructure or devnet roles can require containers, network access, and
long-running/background services. Their presence changes the effect of aggregate
targets. No live-chain E2E is required by this reference.

The inspected pre-generation update notice can contact GitHub only for attended,
non-JSON runs when neither `CARDANO_INIT_NO_UPDATE_CHECK` nor `CI` is set; a
fresh cache avoids that request. It has a one-second deadline and failures are
silent. This source condition is not a claim that the request was made or that
network tests passed. [Version-check implementation](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/version_check/mod.rs)

## Pending runtime witness matrix

All cells below are **unobserved** for this reference.

| Surface | Linux | macOS | Windows | Claude/Codex | Other hosts |
| --- | --- | --- | --- | --- | --- |
| CLI flags, JSON schema, validation errors, nonempty target | expected only | to prove | best effort | n/a | n/a |
| Generated files, instruction imports, writes, clean-tree and partial failures | expected only | to prove | best effort | loading unobserved | Cursor/Antigravity conformance only; Copilot best effort |
| Aiken/Evolution build and non-E2E test signals | expected only | to prove | best effort | n/a | n/a |
| Context loading after generation or canonical setup | n/a | n/a | n/a | native gates later | as stated above |

“Expected” records a source-informed hypothesis, never a pass result. Runtime
certification needs a separate controlled witness for the exact CLI version,
selected stack, operating system, package state, and agent host.

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
The cited source is data, not instructions to execute. A registry entry,
template, upstream test, or source branch does not establish that a local CLI,
host, package manager, container runtime, or agent host works.

Inspect the installed CLI's catalog before proposing a scaffold. These are
source-derived candidate invocations, not witnessed commands:

| Source version | Purpose | Candidate |
| --- | --- | --- |
| v0.4.1 | machine catalog / human matrix | `cardano-init list --json` / `cardano-init table` |
| v0.4.1 | preview Aiken + Evolution | `cardano-init --name PROJECT --on-chain aiken --off-chain evolution --dry-run --json` |
| v0.2.1 | machine catalog / human matrix | `cardano-init list --format json` / `cardano-init list --table` |

A catalog-supported but unverified version or stack may be offered only with
an explicit source-derived warning and user confirmation. An actually
incompatible selection must stop rather than be silently overridden; manual
setup remains available. The compatibility check is registry-driven and
`--ignore-warning` downgrades its stop, but that override is not evidence that
the stack works. [Compatibility implementation](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/registry/compat.rs)

## v0.4.1 catalog and template boundary

The inspected registry and every template manifest define this inventory:

| Role | Actual templates | Experimental entries |
| --- | --- | --- |
| On-chain | Aiken, Pebble, Plinth, Plutarch, Scalus | Pebble |
| Off-chain | Apollo, Blaze, Evolution SDK, Lucid Evolution, MeshJS, PyCardano, Scalus, Tx3 | PyCardano, Tx3 |
| Infrastructure | Cardano Node, Cardano Node API, Dingo, Dolos, Kupo, Ogmios, Tx Submit API | none |
| Devnet | Yaci DevKit | none |
| Formal methods | Blaster | Blaster |

Scalus also declares a fused fullstack template; it is not a sixth role. All
seven infrastructure entries share the `_infra/cardano-up` template and vary
through registry package and environment mappings. Registry availability is
not a runtime compatibility claim. The template directory and each manifest
are authoritative for emitted files; the catalog does not imply frontend or
Cardano Client Lib generation. [Tool registry](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/registry/tools),
[template manifests](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates),
[shared infrastructure manifest](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/_infra/cardano-up/manifest.toml)

Experimental behavior is mode-specific. One-shot init and `add`/`remove`
updates reject a resulting selection containing an experimental tool unless
`--allow-experimental` is supplied. The interactive wizard instead shows an
explicit confirmation that defaults to **No** and drops declined experimental
assignments. Blaster is also a placeholder: its registry uses an example-domain
website and says the integration is not build-green. Do not present a
placeholder as supported. [CLI dispatch](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/mod.rs),
[interactive gate](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/interactive.rs),
[Blaster registry entry](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/registry/tools/blaster.toml)

The v0.2.1 source used global `--format human|json`, placed the matrix at
`list --table`, and had neither the later standalone `table`, global `--json`,
icon setting, short/visible aliases, nor `--no-spec`. v0.4.1 has those newer
surfaces. Both JSON envelopes say schema version `1`; that number identifies
the envelope schema, not an identical flag set, payload, error set, or docs
layout. The old documentation was flat under `docs/` (`PRD.md`, `TECH_SPEC.md`,
`USER_DOCS.md`, and peers); the newer source uses `docs/design/`,
`docs/contributing/`, and `docs/user-guide/` plus book files.
[v0.2.1 CLI](https://github.com/input-output-hk/cardano-init/tree/731d8fb12955724467eea5a3d1f91d8c93857802/src/cli/mod.rs),
[v0.2.1 presenter](https://github.com/input-output-hk/cardano-init/tree/731d8fb12955724467eea5a3d1f91d8c93857802/src/cli/output.rs),
[v0.2.1 docs](https://github.com/input-output-hk/cardano-init/tree/731d8fb12955724467eea5a3d1f91d8c93857802/docs),
[v0.4.1 arguments](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/args.rs),
[v0.4.1 docs](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/docs)

## Generated instructions, ownership, and writes

Initial planning emits `Justfile`, `README.md`, `AGENTS.md`, `CLAUDE.md`,
`.gitignore`, and `.env`, then selected component files and optional layers.
The generated `CLAUDE.md` contains `@AGENTS.md`. This is project context, not
plugin installation and not proof that a host loads it.
[Planner](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/scaffold/planner.rs),
[initial Claude import](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/_base/CLAUDE.md)

Keep ownership explicit:

- cardano-init owns the generated stack facts and undelimited prose in its
  base `AGENTS.md`, plus the initial `CLAUDE.md` import. An `add` or `remove`
  re-renders shared top-level files; it does not promise to preserve additions
  to those files.
- The Cardano context setup owns only its marked directive block in
  `AGENTS.md` and marked import region in `CLAUDE.md`. For agent-driven
  operations, run that canonical setup automatically after requested initial
  scaffolding or an Init update: reuse/update existing canonical context and
  never add a duplicate block or import. Edited, malformed, ambiguous, or
  newer managed content still requires a user decision.
- Developer additions outside a marked region are developer-owned. Preview and
  review updates because cardano-init has no standing context detector and its
  shared-file rewrite can replace them. Kept component directories and the
  generated `spec/` layer are not re-rendered by role updates.

SOURCE-DERIVED initial creation refuses a nonempty target. `--dry-run` plans
without writing. Normal writes are sequential rather than transactional, so an
I/O error can leave a partial tree. A successful initial scaffold then tries
`git init`, `git add -A`, and an initial commit; missing Git, an enclosing Git
repository, or commit failure degrades the reported Git outcome rather than
necessarily failing scaffolding. [Init flow](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/mod.rs),
[writer](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/scaffold/writer.rs),
[Git behavior](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/git.rs)

`add` and `remove` reconstruct the current selection. Unrecognized components
are fatal in JSON mode; human mode shows them and requires a default-No
confirmation before ignoring them. Unless `--force` is used, applying a change
then requires a clean Git tree. `--dry-run` returns before that Git gate.
Replacement/removal deletes old component directories before new writes;
infrastructure and shared files can be re-rendered, so a failure can leave a
partial update.
[Update flow](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/update.rs),
[update plan](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/scaffold/update.rs)

The generated root `.env` is deliberately **tracked**: `.gitignore` ignores
`.env.local`, not `.env`, and the initial `git add -A` therefore stages the
shared `.env`. Treat `.env` as non-secret connection configuration; keep
secrets in the ignored local override or host environment. Runtime providers
may edit `.env`; an agent must not stage those later environment changes
without the user's request. Preserve these conventions rather than silently
changing which file is tracked. [Environment template](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/_base/env.jinja),
[ignore template](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/_base/gitignore)

## Representative Aiken + Evolution candidates

For the source-defined Aiken on-chain plus Evolution off-chain selection, these
are candidates, not verified commands:

| Goal | SOURCE-DERIVED candidate | Conditions and positive signal |
| --- | --- | --- |
| Compile Aiken and publish the blueprint | `just build-on-chain` | Runs `aiken build`, then copies `plutus.json` to `blueprint/plutus.json`. Requires Aiken v1.1.24-compatible behavior and the declared GitHub stdlib dependency. |
| Run Aiken unit checks | `just test-on-chain` | Runs `aiken check`; require its five declared GiftCard tests to run and pass, not merely exit zero. |
| Build Evolution bindings | `just build-off-chain` | Conditionally installs npm dependencies, bundles the blueprint (or a null placeholder), then runs TypeScript compilation. Require a real blueprint for ABI evidence. |
| Run Evolution local unit tests only | use the filtered sequence below | Require exactly `src/contract.test.ts` with both tests passing and none skipped. |

Use this explicit local-only test selection instead of the generated aggregate
test recipe:

```sh
just build-on-chain
if [ ! -d off-chain/node_modules ] || [ off-chain/package.json -nt off-chain/node_modules ]; then
  npm --prefix off-chain install --no-fund --no-audit --loglevel=error
fi
npm --prefix off-chain run --silent bundle-blueprint
(cd off-chain && ./node_modules/.bin/vitest run src/contract.test.ts)
```

This keeps dependency installation explicit, prepares the blueprint bundle,
uses the project-local Vitest binary, names only `contract.test.ts`, and omits
`--passWithNoTests`. Accept only two passed tests with no skip: without
`blueprint/plutus.json`, the bundler emits a null placeholder and both unit
tests are conditionally skipped. Malformed JSON fails bundling; missing
`gift_card.mint` or `redeem.spend` compiled-code entries, or incompatible
parameter application, fails the unit test. The required ABI is a Plutus V3
CIP-57 blueprint containing those two validator-purpose suffixes; the minting
policy parameters are token-name bytes plus an output reference, and the
spending validator parameters are token-name bytes plus policy-id bytes.
[Aiken recipe](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/aiken/on-chain/Justfile.jinja),
[Evolution recipe](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/Justfile.jinja),
[bundle script](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/scripts/bundle-blueprint.mjs),
[unit test](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/src/contract.test.ts),
[ABI consumer](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/src/contract.ts)

`just test-off-chain` is **not a safe non-E2E command**. It invokes the package
`test` script, which runs unfiltered `vitest run --passWithNoTests`; that
includes `contract.integration.test.ts`. When `INDEXER_URL` is nonempty and a
blueprint was bundled, the suite can contact the endpoint and execute a real
devnet mint, lock, and redeem round trip. It can also exit green with skipped
tests or no tests. [Package scripts](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/package.json.jinja),
[integration test](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/evolution/off-chain/src/contract.integration.test.ts)

`just test` is likewise not a non-E2E witness. It includes the unsafe
off-chain recipe and, when selected, infrastructure's intentional no-op test,
Yaci's process-spawning ephemeral integration workflow (which can gracefully
skip when unavailable), and formal-method verification. `just dev` recipes can
start persistent processes, containers, and background services. No live-chain
E2E is required here. [Top-level orchestration](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/_base/Justfile.jinja),
[Yaci recipe](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/yaci/devnet/Justfile.jinja),
[cardano-up recipe](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/templates/_infra/cardano-up/Justfile.jinja)

Command effects matter:

- Aiken may retrieve its GitHub stdlib dependency, then writes build output and
  the shared blueprint. Evolution's conditional `npm install` can contact the
  package registry and run package lifecycle work; build/test bundling writes
  `src/blueprint.generated.ts`, and build writes `dist/`.
- Optional Evolution `create`/`redeem` recipes use `npx tsx` and may contact a
  chain provider. They are not part of the candidates above; do not let `npx`
  fetch a missing CLI implicitly.
- Infrastructure and devnet recipes assume their tools were installed by the
  user. They can start Docker/native processes and access local or configured
  network endpoints. Normal project dependency installs are acceptable only
  under the host's permissions; CLI/tool acquisition remains user-run.
- Generation uses embedded templates, but an attended, non-JSON invocation can
  start a GitHub release check. It skips for JSON, unattended runs,
  `CARDANO_INIT_NO_UPDATE_CHECK` set to any value, or `CI` set to any value. A
  fresh successful-result cache avoids the request; a stale/missing/invalid
  cache can trigger it. The lookup has a one-second overall deadline, failures
  are silent, and a notice never authorizes an update command.
  [Version check](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/version_check/mod.rs),
  [cache](https://github.com/input-output-hk/cardano-init/tree/d5950bbffa3ae3b3751754a4d0de477fdbc6307c/src/cli/version_check/cache.rs)

## Pending runtime witness matrix

Every cell is **unobserved** for this reference.

| Surface | Linux | macOS | Windows | Agent hosts |
| --- | --- | --- | --- | --- |
| CLI flags, schema/payload, errors, experimental modes, nonempty target | expected only | to prove | best effort | n/a |
| Generated imports/files, tracked environment, clean-tree and partial-failure behavior | expected only | to prove | best effort | loading still unobserved |
| Aiken/Evolution build and filtered non-E2E positive signals | expected only | to prove | best effort | n/a |
| Canonical context setup and loading | n/a | n/a | n/a | Claude/Codex native gates later; Cursor/Antigravity conformance only; Copilot best effort |

“Expected” is a source-informed hypothesis, never a pass result. Runtime
certification needs a controlled witness for the exact CLI version, flags,
selected stack, operating system, dependency/package state, network boundary,
generated writes, and agent host.

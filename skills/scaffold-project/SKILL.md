---
name: scaffold-project
description: >-
  Scaffold a new Cardano project by driving cardano-init, the project
  scaffolder — "zero to a running Cardano protocol in one command".
  Picks a use case from the Cardano Foundation templates (or a custom one),
  maps it to cardano-init's roles (on-chain, off-chain, devnet, infrastructure,
  formal-methods), runs the CLI, verifies the build with `just test`, and grafts
  in the use-case starter validator + first transaction. Falls back to
  hand-authored templates for stacks cardano-init cannot generate yet (PyCardano,
  cardano-client-lib). Triggers: "scaffold project", "new Cardano project",
  "project structure", "init Cardano", "cardano-init", "starter template",
  "bootstrap dApp", "set up Cardano monorepo", "Cardano project skeleton",
  "scaffold dApp".
allowed-tools: Read Grep Glob Bash Edit Write
disallowed-tools: WebFetch WebSearch
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Scaffold a Cardano Project

Take a developer from "I want to build a Cardano dApp" to a working, tested project skeleton. **cardano-init — the project scaffolder — is the source of truth for creating new projects.** This skill's job is not to hand-write directory trees; it is to pick the right use case, stack, and network, drive `cardano-init` correctly, verify the result builds, and layer on what cardano-init does not provide: the use-case library, the security guardrails, and the starter validator + first transaction.

cardano-init and this skill set are designed as a pair: every project cardano-init generates ships an `AGENTS.md` (and a `CLAUDE.md` that imports it) that points back at cardano-dev-skills. cardano-init is the *scaffolding* layer; these skills are the *knowledge* layer.

## When to use

- Developer is starting a brand-new Cardano project from scratch
- Developer asks "how do I structure a Cardano monorepo?" or "bootstrap a dApp"
- Developer wants a starter with on-chain + off-chain + devnet wired together that builds out of the box
- Developer wants to learn by building one of the canonical use cases (vesting, escrow, HTLC, etc.)
- Developer wants the on-chain/off-chain bridge (CIP-57 `plutus.json`) wired up correctly

## When NOT to use

- Modifying an existing project's structure — this skill assumes a clean slate (use `cardano-init add` / `cardano-init remove` directly to swap a single tool)
- Adding a single new package to an existing repo — use the language's own tooling
- Frontend-only work (wallet connect UI, dApp pages) — hand off to `connect-wallet`
- Picking between many SDKs in depth — hand off to `suggest-tooling`
- Setting up Yaci DevKit details — hand off to `setup-devnet`
- Writing validator business logic — hand off to `write-validator`
- Writing transaction-building business logic — hand off to `build-transaction`

## Key principles

1. **cardano-init is the source of truth; discover it at runtime.** The tool registry moves fast (tools graduate from planned → experimental → available). Never assert what a role supports from memory. Run `cardano-init list --format json` and read the answer. Every command accepts `--format json` and returns a stable envelope — use it.
2. **Prefer zero-install, then offer to install.** `npx cardano-init …` and `nix run github:input-output-hk/cardano-init -- …` run without installing anything. Reach for those first. Only install the binary (via the official installer) when the developer wants it permanently — and always ask before installing.
3. **Never guess a toolchain is present.** Run `cardano-init doctor --format json` for the chosen stack. When something is missing, surface the exact installer cardano-init names (`aikup` for Aiken, `cardano-up` for infrastructure) — don't reinvent them, and don't silently install them.
4. **Use case first, stack second.** Pick what the contract does before picking what language writes it. cardano-init seeds every stack with the same gift-card example; the *use case* determines which starter validator + first transaction this skill grafts in afterward.
5. **Aiken is the default on-chain language.** cardano-init also offers Scalus and Plinth (and more as they land). Default to Aiken unless the team has a strong reason otherwise; see `references/stack-decision.md`.
6. **The interface contract is `blueprint/plutus.json` + `.env`.** cardano-init wires every component to these two seams, never to each other. On-chain `build` writes `blueprint/plutus.json`; off-chain/devnet/infra read it and the `.env` connection vars, degrading gracefully when absent. Off-chain code loads the blueprint and never re-derives script hashes by hand.
7. **Default to a testnet, always.** Devnet (Yaci DevKit) or a public testnet (preview, preprod) is the right starting point for every new project. Never deploy untested "hello world" validators to mainnet — bugs can lock funds permanently. See the mainnet guardrail in Step 3.
8. **Devnet from day one.** Select a `--devnet` (Yaci DevKit) so the local feedback loop exists from the first commit.
9. **Never commit secrets.** cardano-init generates a shared `.env`; confirm it is gitignored and that only an `.env.example`-style placeholder set is committed. Provider keys and dev keys live in env vars / gitignored dirs.
10. **A scaffold isn't done until `just test` passes.** cardano-init generates a project that builds and tests out of the box. After grafting in the use-case code, re-run `just build && just test`. If the developer says "just scaffold it," still run the verification and report the result — silent broken scaffolds waste hours downstream.
11. **Fall back to hand-authored templates only when cardano-init can't help.** If `list` shows the chosen off-chain stack is not yet available (today: PyCardano is planned, cardano-client-lib is not in the registry), or cardano-init is unavailable entirely (offline), use the `references/layout-*.md` templates. Otherwise, always prefer the generated project.

## Workflow

### Step 1: Make cardano-init available

Check whether cardano-init can run, preferring zero-install:

```bash
npx cardano-init --version   # or: nix run github:input-output-hk/cardano-init -- help
```

If neither works and the developer wants the binary on their PATH, **ask first**, then offer the official installer:

```bash
# macOS / Linux
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/input-output-hk/cardano-init/releases/latest/download/cardano-init-installer.sh | sh
# Windows (PowerShell)
irm https://github.com/input-output-hk/cardano-init/releases/latest/download/cardano-init-installer.ps1 | iex
```

Do not install without the developer's go-ahead. If they decline every install path, drop to the fallback templates (Key principle 11).

Throughout the rest of this workflow, invoke the CLI however it is available (`cardano-init …`, `npx cardano-init …`, or `nix run … --`). The examples below write `cardano-init` for brevity.

### Step 2: Discover the live tool matrix

Ask cardano-init what each role supports *right now* — do not rely on any hardcoded table:

```bash
cardano-init list --format json
```

The response is `{ "schema_version": 1, "ok": true, "data": { "roles": [...], "tools": [...] } }`. For each tool read `roles`, `experimental`, and `fullstack`. Notes that shape the flags in Step 4:

- **Roles:** `on-chain`, `off-chain`, `devnet`, `infrastructure`, `formal-methods`. Only `infrastructure` is multi-tool (`roles[].multiple == true`); the rest take one tool each.
- **Experimental** tools require `--allow-experimental` in one-shot/JSON mode.
- **Fullstack** tools (e.g. Scalus) implement on-chain *and* off-chain in one language; select with `--fullstack <tool>` and get a single `protocol/` component instead of separate `on-chain/` + `off-chain/`.

### Step 3: Pick a use case, then the stack and network

**Use case.** Drive the scaffold by what the contract does. Offer the Cardano Foundation reference use cases. The 5 curated ones have hand-reviewed implementations to graft in later:

- **simple-transfer** — spend validator that only releases funds to a designated recipient
- **vesting** — time-locked funds with owner clawback and beneficiary withdrawal past a deadline
- **escrow** — funds locked by a buyer, released by mutual agreement or arbitration
- **token-transfer** — native-token movement under a spend validator
- **htlc** — Hashed Time-Locked Contract; redeem-with-preimage or refund-after-deadline

The other 16 (bet, auction, crowdfund, vault, storage, simple-wallet, pricebet, payment-splitter, lottery, constant-product-amm, upgradable-proxy, factory, decentralized-identity, editable-nft, anonymous-data, atomic-transaction) have upstream Aiken coverage; off-chain is agent-generated in-session. See `references/use-cases.md`; for the flagship end-to-end walkthrough see `references/vesting-walkthrough.md`. A case that matches nothing is a custom case — model it on the closest upstream validator.

**Stack.** Map the team's primary language to cardano-init roles (confirm availability against Step 2):

| Team | On-chain | Off-chain | How |
|---|---|---|---|
| TypeScript, broad tutorials | Aiken | MeshJS | `--on-chain aiken --off-chain meshjs` |
| TypeScript, type-safe/composable | Aiken | Evolution SDK | `--on-chain aiken --off-chain evolution` |
| Scala / JVM, one language both sides | Scalus (fullstack) | Scalus | `--fullstack scalus` |
| Haskell on-chain | Plinth | (off-chain per team) | `--on-chain plinth --off-chain <tool>` |
| Python off-chain | Aiken | PyCardano | **fallback** — not in cardano-init yet (Step 6) |
| Java/Kotlin off-chain | Aiken | cardano-client-lib | **fallback** — not in the registry (Step 6) |

For a deeper tour hand off to `suggest-tooling`. Do not mix multiple off-chain tools in one project.

**Network.** Settle the target network before generating. It sets `--devnet` and the `.env` `CARDANO_NETWORK`.

| Network | Best for | Trade-off |
|---|---|---|
| **Yaci DevKit** (recommended default) | Learning, fast iteration, isolated testing | Instant finality; differs from mainnet around eras and slot timing |
| **Preview testnet** | Pre-mainnet integration testing | ~20s blocks; shared state |
| **Preprod testnet** | Pre-production rehearsal | Mirrors mainnet parameters most closely |
| **Mainnet** | Production only | Real funds — see guardrail |

**Mainnet guardrail.** If the developer asks to scaffold for mainnet, stop and warn: untested "hello world" validators must not touch mainnet — bugs can lock real funds permanently. Default to a testnet. Even after an explicit acknowledgement, keep the project's default `CARDANO_NETWORK` on a testnet so a misconfigured run never lands on mainnet by accident.

For Yaci DevKit launch details, hand off to `setup-devnet`. Faucets for preview/preprod: https://docs.cardano.org/cardano-testnets/tools/faucet.

### Step 4: Add infrastructure and formal methods (optional)

`infrastructure` is the one multi-tool role — pass `--infra` repeatedly. Each provider publishes connection vars into `.env` that the off-chain code reads automatically (provisioned via `cardano-up`, needs Docker):

- `--infra kupo` → `INDEXER_URL` · `--infra ogmios` → `OGMIOS_URL` · `--infra dolos` → `DOLOS_GRPC_URL`, `NODE_SOCKET_PATH`
- `--infra tx-submit-api` → `TX_SUBMIT_URL` · `--infra cardano-node` → `NODE_SOCKET_PATH` · `--infra dingo` → `INDEXER_URL`, `NODE_SOCKET_PATH`

One chain-index per project (`INDEXER_URL` has a single slot — Kupo and Dingo are alternatives, not additive). For formal methods, add `--formal-methods <tool>` (e.g. Blaster, experimental → needs `--allow-experimental`). Skip both roles for a plain learning project.

### Step 5: Frontend? (Recommended)

Default is yes; ask if the developer wants to opt out. cardano-init does not scaffold a frontend, so this stays a hand-off: a sibling Next.js App Router app using Mesh or Evolution for CIP-30 wallet integration and Blockfrost queries, consuming the same `blueprint/plutus.json`. Hand off to `connect-wallet` for the actual wallet integration content; do not duplicate it here.

### Step 6: Preview, then generate

Assemble the one-shot command and **preview first** — `--dry-run` prints the exact change set and writes nothing:

```bash
cardano-init --name <project> \
  --on-chain aiken --off-chain meshjs --devnet yaci \
  --dry-run --format json
```

Review the plan with the developer, then drop `--dry-run` to generate. Compatibility notes cardano-init enforces:

- It **stops before generating** an incompatible combination (e.g. an off-chain tool that can't reach a chain from the selected providers); the error's `context` lists providers that would work. Prefer fixing the selection; use `--ignore-warning` only deliberately.
- Experimental tools need `--allow-experimental`.
- To swap a tool in an already-generated project, use `cardano-init add --<role> <tool>` / `cardano-init remove --<role> <tool>` rather than regenerating.

**Fallback (no cardano-init support).** If Step 2 showed the chosen off-chain stack is unavailable (PyCardano, cardano-client-lib) or the developer declined every install path, generate from the hand-authored templates instead:

- Stack Aiken + Evolution SDK → `references/layout-aiken-evolution.md`
- Stack Aiken + Mesh SDK → `references/layout-aiken-mesh.md`
- Stack Aiken + PyCardano → `references/layout-aiken-pycardano.md`
- Stack Aiken + cardano-client-lib → `references/layout-aiken-cclib.md`
- Config files (`aiken.toml`, `package.json`, `pyproject.toml`, `pom.xml`, `.gitignore`, `.env.example`) → `references/config-templates.md`

In the fallback path, print the tree and file contents as guidance and follow the two-tier pinning policy: paste Aiken-side pins directly; for off-chain deps run `npm view <pkg> version` / `pip index versions <pkg>` / Maven Central at scaffold time and embed the exact returned version — never `^`, `~`, or `latest`.

### Step 7: Graft in the use-case code

cardano-init seeds the gift-card example. Replace it with the code for the use case picked in Step 3:

1. Read the generated `AGENTS.md` — it describes the layout, the interface-contract invariants, the exact `just` workflow, and the relevant cardano-dev-skills for this stack. Follow it.
2. **Starter validator.** For a curated use case, adapt the upstream Aiken validator from `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-use-case-templates/<name>/onchain/aiken/validators/` into the generated `on-chain/` component. For custom cases, model on the closest upstream validator. Then hand off to `write-validator` for real logic.
3. **First transaction.** A minimal off-chain script in the chosen SDK that loads `blueprint/plutus.json`, builds a transaction exercising the validator, signs with the dev key, submits, and prints the tx hash. Keep the interface contract intact — read the blueprint from the file, never hardcode a script hash. Then hand off to `build-transaction`.

### Step 8: Verify the scaffold builds

Do not call the scaffold done until it builds and tests pass. Every project is driven by `just`:

```bash
cd <project>
just build      # produces blueprint/plutus.json and compiles off-chain
just test       # runs the stack's tests end-to-end
```

If something fails:

1. **Missing toolchain:** run `cardano-init doctor --format json` and install what it names (`aikup`, `cardano-up`, …).
2. **On-chain build fails:** the grafted validator likely has unresolved imports — compare against the upstream use-case validator; a common miss is the `sidan-lab/vodka` dependency when copying a CF validator.
3. **Off-chain fails on the blueprint:** confirm the off-chain code reads `blueprint/plutus.json` from the contract path, not a stale copy.
4. **Anything else:** read the error, fix the affected file, re-run. Don't ship a scaffold that didn't build.

Report plainly: "Scaffold built and `just test` passes. See `setup-devnet` to bring the local chain up." Or, if something is still failing, explain what and why before handing off.

## On-chain / off-chain bridge

The bridge is cardano-init's interface contract — `blueprint/plutus.json` (CIP-57) plus the shared `.env`. On-chain `build` writes the blueprint; off-chain, devnet, formal-methods, and infra read it (and the `.env` connection vars) and degrade gracefully when it is absent. A fullstack `protocol/` component still writes the blueprint on its external seam so devnet and infra compose. Every off-chain SDK loads this file directly — the developer never copies a script hash by hand:

- Evolution SDK: `applyParamsToScript(blueprint.validators[0].compiledCode, [])` + `validatorToAddress`
- Mesh SDK: `applyParamsToScript` / `serializePlutusScript` consume the compiled CBOR
- PyCardano (fallback): reads `plutus.json`, constructs `PlutusV3Script` from the CBOR
- cardano-client-lib (fallback): `PlutusBlueprintLoader` + `PlutusBlueprintUtil`

## Security defaults baked into the scaffold

These are non-negotiable. Verify them after generating; don't let a developer talk you into removing them.

- `.env` is gitignored from the first commit; only placeholder values are committed
- Provider API keys read from env vars at runtime; never embedded in code
- A testnet (devnet, preview, or preprod) is the default network; mainnet requires an explicit env change and an acknowledged warning
- Dev keys are marked dev-only and live in a gitignored directory
- Lockfiles are committed so a fresh clone plus `just build` reproduces identical artifacts

## References

- `references/use-cases.md` — the reference use cases, curated vs agent-generated, with source-code pointers
- `references/vesting-walkthrough.md` — flagship end-to-end walkthrough across the off-chain stacks, plus the frontend story
- `references/stack-decision.md` — decision aid for picking on-chain + off-chain tools
- `references/config-templates.md` — annotated `aiken.toml`, `package.json`, `pyproject.toml`, `pom.xml`, `.gitignore`, `.env.example` (fallback path)
- `references/layout-aiken-evolution.md` / `layout-aiken-mesh.md` / `layout-aiken-pycardano.md` / `layout-aiken-cclib.md` — hand-authored directory trees + skeletons (fallback path)
- cardano-init docs: `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-init/` (README, `docs/USER_DOCS.md`, `docs/TECH_SPEC.md`, `registry/tools/*.toml`)
- Hand off to `setup-devnet` for Yaci DevKit launch and configuration
- Hand off to `suggest-tooling` for deeper SDK and language trade-off discussion
- Hand off to `write-validator` for real on-chain logic
- Hand off to `build-transaction` for real transaction-building logic
- Hand off to `connect-wallet` for a Next.js / React frontend with wallet integration

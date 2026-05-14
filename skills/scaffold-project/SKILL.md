---
name: scaffold-project
description: >-
  Scaffold a new Cardano project with on-chain + off-chain toolchain wired up.
  Helps pick a use case from the 21 Cardano Foundation templates (or a custom
  one), a stack (Aiken on-chain; Evolution SDK, Mesh SDK, PyCardano, or
  cardano-client-lib off-chain), a network (Yaci DevKit, preview, preprod), and
  optionally a Next.js frontend. Produces a canonical directory layout, config
  files, devnet wiring, and starter validator + transaction skeletons.
  Triggers: "scaffold project", "new Cardano project", "project structure",
  "init Cardano", "starter template", "project layout", "bootstrap dApp",
  "set up Cardano monorepo", "Cardano project skeleton", "scaffold dApp".
allowed-tools: Read Grep Glob
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Scaffold a Cardano Project

Take a developer from "I want to build a Cardano dApp" to a working project skeleton: a chosen use case, directory layout, config files, devnet wiring, a starter validator, and the first off-chain transaction. The skill is read-only — it prints the canonical structure and file contents as guidance for the developer (or the agent) to write into their own working directory.

## When to use

- Developer is starting a brand-new Cardano project from scratch
- Developer asks "how do I structure a Cardano monorepo?"
- Developer wants a starter template with on-chain + off-chain wired together
- Developer wants to learn by building one of the canonical use cases (vesting, escrow, HTLC, etc.)
- Developer needs an opinionated default layout for an Aiken + SDK stack
- Developer wants the on-chain/off-chain bridge (CIP-57 `plutus.json`) wired up correctly

## When NOT to use

- Modifying an existing project's structure — this skill assumes a clean slate
- Adding a single new package to an existing repo — use the language's own tooling
- Frontend-only work (wallet connect UI, dApp pages) — hand off to `connect-wallet`
- Picking between many SDKs in depth — hand off to `suggest-tooling`
- Setting up Yaci DevKit details — hand off to `setup-devnet`
- Writing validator business logic — hand off to `write-validator`
- Writing transaction-building business logic — hand off to `build-transaction`

## Key principles

1. **Read-only scaffolding.** Print the tree and file contents as guidance. Do not write files into the developer's working directory from inside the skill. The developer reviews each file before it lands on disk.
2. **Use case first, stack second.** Pick what the contract does before picking what language writes it. The use case sets the datum / redeemer / validator shape; the stack is only a language choice.
3. **One on-chain language for v1: Aiken.** Aiken has the strongest tooling, fastest compilation, and a native CIP-57 `plutus.json` blueprint emitter. Other on-chain languages exist; see `references/stack-decision.md` for why they are deferred.
4. **Four off-chain stacks for v1.** Evolution SDK, Mesh SDK, PyCardano, cardano-client-lib. Match the off-chain choice to the team's primary language. Do not mix multiple off-chain SDKs in one project.
5. **CIP-57 `plutus.json` is the contract between on-chain and off-chain.** Aiken emits this natively at build time. The off-chain code loads it and never re-derives script hashes manually.
6. **Default to a testnet, always.** Devnet (Yaci DevKit) or a public testnet (preview, preprod) is the right starting point for every new project. Scaffolded code is for learning and testing. Never deploy "hello world" validators to mainnet — bugs in untested validators can lock user funds permanently. Switch to mainnet only after thorough testing and, for anything non-trivial, an audit.
7. **Devnet from day one.** Wire Yaci DevKit into the scaffold from the start. Local feedback loops shorten iteration time and catch integration mistakes early.
8. **Pin versions; never commit secrets.** Every manifest pins exact toolchain versions. Every project has `.env.example` (committed) and `.env` (ignored). Provider API keys live in env vars.
9. **Reproducible builds.** A fresh clone plus the documented install command should produce identical artifacts. No global toolchain assumptions; document required versions explicitly.
10. **Default to monorepo for full-stack; single-repo for solo or library work.** The monorepo splits `onchain/` and `offchain/` (and optionally `frontend/`) into sibling directories with a shared `plutus.json` reference path.
11. **No hardcoded version numbers in this skill.** Versions move. Direct the developer to the source's GitHub releases or to the bundled docs at `${CLAUDE_SKILL_DIR}/../../docs/sources/<source>/` and have them pin the latest stable at scaffold time.

## Workflow

### Step 1: Pick a use case

Drive the scaffolding by what the contract does, not by the stack. Ask the developer to pick from one of the 21 reference use cases or describe their own.

The 5 curated use cases have hand-reviewed implementations across on-chain Aiken and all four off-chain stacks:

- **simple-transfer** — plain spend validator that only releases funds to a designated recipient
- **vesting** — time-locked funds with an owner clawback and a beneficiary withdrawal past the deadline
- **escrow** — funds locked by a buyer, released by mutual agreement or arbitration
- **token-transfer** — native-token movement under a spend validator (not bare ADA)
- **htlc** — Hashed Time-Locked Contract; redeem-with-preimage or refund-after-deadline

The other 16 use cases (bet, auction, crowdfund, vault, storage, simple-wallet, pricebet, payment-splitter, lottery, constant-product-amm, upgradable-proxy, factory, decentralized-identity, editable-nft, anonymous-data, atomic-transaction) have Aiken on-chain coverage upstream; off-chain code is agent-generated in-session.

For full descriptions and source-code paths see `references/use-cases.md`. For an end-to-end flagship walkthrough of vesting (the recommended first project) see `references/vesting-walkthrough.md`.

If the developer's case doesn't match any entry, treat it as a custom use case: read the closest upstream Aiken validator under `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-use-case-templates/<name>/onchain/aiken/` as a structural model and generalise from there.

### Step 2: Pick the stack

Map the team's primary language and constraints to one of four stacks. Use this short decision matrix; for more depth see `references/stack-decision.md` and hand off to `suggest-tooling` if the developer wants a broader tour.

| Stack | On-chain | Off-chain | Pick when |
|---|---|---|---|
| 1 | Aiken | Evolution SDK | TypeScript team, want a pure-JS toolchain with composable types |
| 2 | Aiken | Mesh SDK | TypeScript team, want the broadest tutorial coverage |
| 3 | Aiken | PyCardano | Python backend, data team, scripting-heavy |
| 4 | Aiken | cardano-client-lib | Java/Kotlin team, JVM ecosystem |

Search the bundled docs for SDK details:

- `${CLAUDE_SKILL_DIR}/../../docs/sources/aiken/` — Aiken language docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/aiken-stdlib/` — Aiken standard library
- `${CLAUDE_SKILL_DIR}/../../docs/sources/evolution-sdk/` — Evolution SDK docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/mesh-sdk/` — Mesh SDK docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/pycardano/` — PyCardano docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-client-lib/` — cardano-client-lib docs

### Step 3: Pick a network

Before scaffolding the layout, settle which network the project targets first. The choice changes `.env.example`, the off-chain provider initialisation, and the faucet URL.

| Network | Best for | Trade-off |
|---|---|---|
| **Yaci DevKit** (recommended default) | Learning, fast iteration, isolated testing | Instant finality; differs from mainnet behaviour around eras and slot timing |
| **Preview testnet** | Pre-mainnet integration testing | Slower than devnet (~20s blocks); shared state |
| **Preprod testnet** | Pre-production rehearsal | Mirrors mainnet parameters most closely |
| **Mainnet** | Production deployment only | Real funds — see guardrail below |

Mainnet guardrail. If the developer asks to scaffold with mainnet as the active network, stop and warn explicitly: scaffolded "hello world" validators must not be deployed to mainnet — bugs in untested code can lock real funds permanently. Default to a testnet. Only proceed with mainnet after the developer has explicitly acknowledged the warning, and even then, set the project's default `CARDANO_NETWORK` env to a testnet so a misconfigured run never accidentally lands on mainnet.

For Yaci DevKit launch details, hand off to `setup-devnet`. Faucets for preview and preprod live at https://docs.cardano.org/cardano-testnets/tools/faucet (the selector on the page picks preview vs preprod).

### Step 4: Include a frontend? (Recommended)

Default is yes. Ask the developer if they want to opt out.

When a frontend is included, scaffold a sibling Next.js App Router application that:

- Uses Mesh or Evolution for wallet integration (CIP-30) and chain queries via Blockfrost
- Talks directly to Blockfrost from the browser — independent of any Python or Java backend
- For TS stacks (1 and 2), lives in the same monorepo as the off-chain code and shares types
- For Python (stack 3) and Java (stack 4), is a separate Next.js app that uses the same on-chain blueprint (`plutus.json`) but does its own tx building client-side

When a frontend is excluded, the scaffold is backend-only (Aiken + the chosen off-chain SDK).

In all cases, hand off to `connect-wallet` for the actual CIP-30 wallet integration content. Do not duplicate it here.

### Step 5: Choose the layout shape

Two shapes are supported. Pick once; do not mix.

**Single-repo (flat).** Use when: solo developer, prototyping, a library, or contract-only project. Everything sits at the repo root: `aiken.toml`, `validators/`, and the off-chain code in a language-appropriate location.

**Monorepo (split).** Use when: full-stack product, more than one developer, on-chain and off-chain evolve at different speeds. Sibling top-level directories:

```
my-project/
├── onchain/        # Aiken project, emits plutus.json
├── offchain/       # SDK code, consumes plutus.json
└── frontend/       # Optional Next.js app; only if Step 4 = yes
```

If the developer says "I prefer single-repo," respect that override even when the project looks like it wants a monorepo. Document the trade-off briefly: single-repo is simpler now but harder to split later.

### Step 6: Print the canonical directory tree

Pick the matching reference file for the chosen stack and the chosen shape, and print the tree as a code block for the developer to materialize:

- Stack 1 (Aiken + Evolution SDK): `references/layout-aiken-evolution.md`
- Stack 2 (Aiken + Mesh SDK): `references/layout-aiken-mesh.md`
- Stack 3 (Aiken + PyCardano): `references/layout-aiken-pycardano.md`
- Stack 4 (Aiken + cardano-client-lib): `references/layout-aiken-cclib.md`

Each reference shows both single-repo and monorepo variants, plus the optional frontend layout. Use the variants matching Steps 4 and 5.

Frame the output as "Generate the following structure" followed by the tree and then individual file contents. Do not invoke a writing tool from inside this skill.

### Step 7: Print the canonical config files

Read `references/config-templates.md` and emit the templates relevant to the chosen stack and network:

- `aiken.toml` — on-chain manifest (all stacks)
- `.gitignore` — shared patterns plus stack-specific entries
- `.env.example` — network-specific placeholders, Blockfrost project ID, faucet pointer, devnet URL
- Stack 1, 2: `package.json` + `tsconfig.json`
- Stack 3: `pyproject.toml`
- Stack 4: `pom.xml`

Each emitted file preserves inline annotations (`#` or `//` comments) explaining each field. The annotations are part of the deliverable; they tell the developer what each line does so they can adapt it.

Versions: do not paste specific version numbers. In each manifest, leave a comment marker like `# PIN: latest stable Aiken release` and tell the developer to check the project's GitHub releases or the bundled docs at `${CLAUDE_SKILL_DIR}/../../docs/sources/aiken/` (or the equivalent source slug) before committing.

### Step 8: Wire up the local devnet

Yaci DevKit is the default local network. Do not duplicate setup details here; point the developer at the `setup-devnet` skill for installation, configuration, and pre-funded wallet handling.

What this skill provides in the scaffold:

- `.env.example` includes a `CARDANO_NETWORK` toggle (defaults to a testnet) and a `YACI_STORE_URL=http://localhost:10000` entry
- The off-chain SDK initialisation snippet reads these env vars and selects the provider accordingly
- A `scripts/dev-up.sh` (or equivalent) that launches Yaci DevKit; the script body is one line and points to the `setup-devnet` skill for the full command
- The off-chain code defaults to a testnet on startup; never to mainnet

Then hand off to `setup-devnet` for the actual launch.

### Step 9: Print starter validator + first-transaction skeletons, then hand off

End the scaffold with the starter on-chain and off-chain code for the use case picked in Step 1.

1. **Starter validator.** For a curated use case (simple-transfer, vesting, escrow, token-transfer, htlc), use the upstream Aiken validator from `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-use-case-templates/<name>/onchain/aiken/validators/` as the starting point. For an agent-generated use case, use the closest upstream validator as a model. For a fully custom case, fall back to the trivial "always succeeds when signed by the datum's owner" validator under each layout reference. After printing, hand off to `write-validator` for real business logic.

2. **First transaction.** A minimal off-chain script in the chosen SDK that: loads the `plutus.json` blueprint, builds a transaction that exercises the validator (lock for vesting/escrow/HTLC; transfer for simple-transfer; etc.), signs it with the dev key, submits it, and prints the resulting tx hash. The exact code lives in the stack's layout reference and (for vesting) in `references/vesting-walkthrough.md`. After printing, hand off to `build-transaction` for richer transaction logic.

If the developer enabled a frontend in Step 4, also note: "For the wallet-connect path see `connect-wallet`."

## On-chain / off-chain bridge

Aiken emits CIP-57 `plutus.json` as part of `aiken build`. This is the single source of truth that bridges on-chain and off-chain code. Every off-chain SDK in the v1 stack matrix can load this file directly:

- Evolution SDK: `applyParamsToScript(blueprint.validators[0].compiledCode, [])` plus `validatorToAddress`
- Mesh SDK: `applyParamsToScript` and `serializePlutusScript` consume the compiled CBOR
- PyCardano: reads `plutus.json` and constructs `PlutusV3Script` from the CBOR
- cardano-client-lib: parses `plutus.json` via `PlutusBlueprintLoader` + `PlutusBlueprintUtil`

In every stack layout reference, the off-chain starter snippet shows the exact load pattern. The pattern is the same shape across all four: open the file, pick the named validator, hand the CBOR to the SDK. The developer never copies a script hash by hand.

## Security defaults baked into the scaffold

These defaults are non-negotiable. The scaffold prints them; do not let a developer talk you into removing them.

- `.env` is in `.gitignore` from the first commit
- `.env.example` ships placeholder values only; no real keys
- Provider API keys read from env vars at runtime; never embedded in code
- A testnet (devnet, preview, or preprod) is the default network; mainnet requires an explicit env var change and an acknowledged warning
- Test keys generated by Yaci DevKit are clearly marked as dev-only and live in a `.keys/` directory that is also gitignored
- Lockfiles are committed: `package-lock.json` / `pnpm-lock.yaml`, `poetry.lock`, Maven dependency tree pinned via `<dependencyManagement>`

## References

- `references/use-cases.md` — the 21 reference use cases, curated vs agent-generated, with source-code pointers
- `references/vesting-walkthrough.md` — flagship end-to-end walkthrough across all four off-chain stacks, plus the frontend story; includes a full PyCardano implementation
- `references/stack-decision.md` — decision aid for picking one of the four stacks; brief notes on deferred stacks and why they are not v1 defaults
- `references/config-templates.md` — annotated `aiken.toml`, `package.json`, `pyproject.toml`, `pom.xml`, `.gitignore`, `.env.example` (with per-network Blockfrost / faucet guidance)
- `references/layout-aiken-evolution.md` — stack 1: Aiken + Evolution SDK directory tree, skeletons, optional Next.js frontend
- `references/layout-aiken-mesh.md` — stack 2: Aiken + Mesh SDK directory tree, skeletons, optional Next.js frontend
- `references/layout-aiken-pycardano.md` — stack 3: Aiken + PyCardano directory tree, skeletons, optional sibling Next.js frontend
- `references/layout-aiken-cclib.md` — stack 4: Aiken + cardano-client-lib directory tree, skeletons, optional sibling Next.js frontend
- Hand off to `setup-devnet` for Yaci DevKit launch and configuration
- Hand off to `suggest-tooling` for deeper SDK and language trade-off discussion
- Hand off to `write-validator` for real on-chain logic
- Hand off to `build-transaction` for real transaction-building logic
- Hand off to `connect-wallet` for a Next.js / React frontend with wallet integration

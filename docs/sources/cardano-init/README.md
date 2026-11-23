# cardano-init

**Go from zero to a running Cardano protocol in one command.**

Pick a tool for each role you need (on-chain, off-chain, devnet, infrastructure, formal-methods). `cardano-init` generates a monorepo where every component is **already connected** to the others. It also includes a worked end-to-end example that **builds and passes its tests** as soon as it is generated.

![cardano-init lists its tools by role, scaffolds an Aiken + MeshJS + Yaci DevKit stack in one command, then just test passes against a local devnet (test run sped up)](https://raw.githubusercontent.com/input-output-hk/cardano-init/main/assets/demo.gif)

```console
$ cardano-init --name my-protocol --on-chain aiken --off-chain meshjs --devnet yaci

my-protocol/
├── on-chain/     # Validators (smart contracts)
├── off-chain/    # Tx building (protocol transactions)
├── devnet/       # Local chain for integration testing
├── blueprint/    # shared CIP-57 contract interface
├── spec/         # Protocol specification (plain Markdown; --no-spec to skip)
├── .env          # shared between components
├── Justfile      # Commands to build, test, and clean
├── AGENTS.md     # Agent brief
└── README.md

$ cd my-protocol && just test
  ✓  All tests passed
```

## Why `cardano-init`?

- **One command to a working project.** The generated monorepo builds and passes its tests immediately.
- **Combine tools freely.** Components share a common *contract*, so a tool from one role works with any tool from another.
- **Built for coding agents.** Every command can print JSON, and every project includes an `AGENTS.md` that tells an agent what the project is and what to do next.
- **Help with setup.** The built-in `doctor` checks your toolchains and prints the install command for anything missing and the upgrade command for anything too old.
- **Change the stack later.** `add` and `remove` swap a tool or a role in an existing project, and every change is a reviewable `git diff`.
- **A real example.** Every stack ships the same gift-card scenario, and it runs end to end.

## Where to go next

- **New to Cardano:** the [Cardano Developer Portal](https://developers.cardano.org/) has a hands-on onboarding path, from wallets and transactions to writing and testing validators.
- **First project:** [Installation](user-guide/installation.md), then the [Quick start](user-guide/quick-start.md).
- **How the components connect:** [How it works](user-guide/how-it-works.md).
- **Which tools are available:** the [Tools catalog](user-guide/tools.md), or run `cardano-init table`.
- **All flags:** the [Command reference](user-guide/commands.md).
- **Using `cardano-init` from an LLM:** [For coding agents](user-guide/agents.md).
- **Adding your tool to the registry:** [Adding a tool](contributing/adding-a-tool.md).

`cardano-init` is open source (Apache-2.0) and developed on [GitHub](https://github.com/input-output-hk/cardano-init).

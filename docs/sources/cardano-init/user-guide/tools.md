# Tools catalog

The registry has 21 tools. Scalus fills two roles, so it appears in two columns.

| On-chain | Off-chain | Devnet | Infrastructure | Formal methods |
|----------|-----------|--------|----------------|----------------|
| ✅ Aiken | ✅ MeshJS | ✅ Yaci DevKit | 🔌 Kupo | 🚧 Blaster |
| ✅ Scalus | ✅ Scalus | | 🔌 Ogmios | |
| ✅ Plinth | ✅ Evolution SDK | | 🔌 Dolos | |
| ✅ Plutarch | 🧪 Tx3 | | 🔌 Tx Submit API | |
| 🧪 Pebble | ✅ Lucid Evolution | | 🔌 Cardano Node | |
| | ✅ Blaze | | 🔌 Cardano Node API | |
| | ✅ Apollo | | 🔌 Dingo | |
| | 🧪 PyCardano | | | |

What each status means:

- ✅ **Supported.** CI generates a project with the tool, builds it, and runs its tests every week and on every pull request that touches it.
- 🔌 **Supported, provisioned through [cardano-up](https://github.com/blinklabs-io/cardano-up).** Tests check the files `cardano-init` generates. CI does not start the service itself, because that needs Docker; the service is tested in its own repository.
- 🧪 **Experimental.** Generated and tested in CI like a supported tool, but the tool or its integration is still changing. You need `--allow-experimental` to select it in one-shot mode. See [Experimental tools](how-it-works.md#experimental-tools).
- 🚧 **Placeholder.** The tool is selectable as experimental, but its template is a stub and CI does not run it. Blaster has no released binary yet.

This table can be out of date. `list` shows the tools in the version you have installed:

```bash
cardano-init list           # every tool with its id, language, status, and links
cardano-init table         # the same matrix as above, with tool ids
```

Use the **tool id** shown by `list` or `table` (for example `aiken`, `meshjs`, `yaci`, `tx-submit-api`) as the value for role flags.

## Tested combinations

Each tool is tested on its own and in at least one combination. The table lists every combination CI builds and tests. It runs weekly and on pull requests that touch one of the tools.


| Combination | Builds and passes its tests | Runs end to end on Yaci DevKit |
|-------------|:---------------------------:|:------------------------------:|
| Aiken (on-chain only) | ✅ |  |
| Apollo (off-chain only) | ✅ |  |
| Blaze (off-chain only) | ✅ |  |
| Evolution SDK (off-chain only) | ✅ |  |
| Lucid Evolution (off-chain only) | ✅ |  |
| MeshJS (off-chain only) | ✅ |  |
| Pebble (on-chain only) | ✅ |  |
| Plinth (on-chain only), with `--nix` | ✅ |  |
| Plutarch (on-chain only), with `--nix` | ✅ |  |
| PyCardano (off-chain only) | ✅ |  |
| Scalus (off-chain only) | ✅ |  |
| Scalus (on-chain only) | ✅ |  |
| Aiken + Apollo | ✅ | ✅ |
| Aiken + Blaze | ✅ | ✅ |
| Aiken + Evolution SDK | ✅ | ✅ |
| Aiken + Lucid Evolution | ✅ | ✅ |
| Aiken + MeshJS | ✅ | ✅ |
| Aiken + PyCardano | ✅ | ✅ |
| Aiken + Scalus | ✅ | ✅ |
| Aiken + Tx3 | ✅ |  |
| Pebble + MeshJS | ✅ | ✅ |
| Plinth + MeshJS, with `--nix` | ✅ | ✅ |
| Plinth + PyCardano, with `--nix` | ✅ |  |
| Plutarch + MeshJS, with `--nix` | ✅ | ✅ |
| Plutarch + PyCardano, with `--nix` | ✅ |  |
| Scalus + MeshJS | ✅ | ✅ |
| Scalus + PyCardano | ✅ |  |
| Scalus (fullstack) | ✅ | ✅ |


The other on-chain and off-chain pairs are covered by testing against two reference tools, Aiken and MeshJS, instead of testing every pair:

- Every off-chain tool is built and tested with Aiken.
- MeshJS is tested on Yaci DevKit with every on-chain tool, so each tool's validators are checked on a live chain.
- Every on-chain tool's `blueprint/plutus.json` must read the same way as Aiken's: the same validators, parameters, redeemer encoding, Plutus version, and script encoding, and no builtins newer than protocol 10 (Plomin), which some off-chain libraries can't read. Only the compiled scripts and their hashes may differ. CI fails if they don't match.

So any off-chain tool that works with Aiken's blueprint reads the other on-chain tools' blueprints the same way. This relies on the [interface contract](how-it-works.md#the-interface-contract), which also covers providers: every devnet or infrastructure provider writes its connection details to `.env`. `cardano-init` [refuses to generate](how-it-works.md#compatibility-checks) a combination it knows can't work, such as an off-chain tool paired with a provider that doesn't speak its protocol.

No CI check starts an infrastructure provider, so combinations with `--infra` are tested only for the files they generate.

## Notes

- **Scalus** fills both on-chain and off-chain and supports `--fullstack`, which generates a single `protocol/` component. See [Fullstack tools](how-it-works.md#fullstack-tools).
- **Plinth** and **Plutarch** are both Haskell. Plinth targets GHC 9.6; Plutarch targets GHC 9.8. With `--nix`, each component ships a Nix flake that provides the right GHC.
- **PyCardano** generates a Python project managed by [uv](https://docs.astral.sh/uv/), which installs the Python version and packages the project needs. It connects through a Blockfrost-compatible API, such as Yaci DevKit or Blockfrost itself.
- **Pebble** scripts use protocol version 11 features, so they run on mainnet, preview, preprod, and Yaci DevKit 0.12 or later, but not on older devnets.
- **Experimental** (🧪) and **placeholder** (🚧) tools require `--allow-experimental` in one-shot mode. See [Experimental tools](how-it-works.md#experimental-tools).
- **Infrastructure** is the only role that accepts several tools. See [Infrastructure providers](infrastructure.md).
- To add a tool to the registry, see [Adding a tool](../contributing/adding-a-tool.md).

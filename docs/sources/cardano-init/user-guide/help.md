# Supporting tools and getting help

## Learn Cardano

The [Cardano Developer Portal](https://developers.cardano.org/) has a hands-on onboarding path for new developers. Its lectures start with wallets, keys, and transactions, and continue to writing, testing, and using validators. Its *Get started* page creates a project with `cardano-init`, and a tutorial builds a complete atomic swap dApp: validator, off-chain code, and frontend.

## Supporting tools

Each language has supporting tools: editor extensions (VS Code, Neovim, Zed, Emacs, JetBrains), language servers, and online playgrounds.

- `cardano-init doctor --links` lists the ones that match the stack in your project, under *Supporting tools* (`deps[].support` in `doctor --json`).
- `cardano-init list` shows them for every tool, on a *Tooling* line (`tools[].support` in JSON).

The links are stored in the `support` field of [`registry/deps.toml`](https://github.com/input-output-hk/cardano-init/blob/main/registry/deps.toml), and come from each tool's own documentation.

Some tools are useful with any stack:

- CBOR and transaction inspectors, to decode datums, redeemers, and raw transactions;
- block explorers for mainnet, preprod, and preview;
- the testnet faucet, for free test ADA.

The [Builder Tools](https://developers.cardano.org/tools/) page on the Developer Portal lists them.

## Getting help

Every tool in the registry records its official community channels, usually a Discord server, sometimes GitHub Discussions or a forum. They are the channels that each project links from its own website or repository.

- `cardano-init doctor --links` shows them for the components in your project, under *Get help*.
- `cardano-init list` shows them for every tool, on a *Community* line (`tools[].community` in JSON).

For questions about Cardano in general, the [Cardano Developer Portal](https://developers.cardano.org/) links to the developer Discord, the Cardano Forum, and Cardano Stack Exchange.

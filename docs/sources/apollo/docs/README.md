# Apollo Documentation

Apollo is a pure Go library for building Cardano transactions. Ledger types,
CBOR, scripts, addresses, and transaction bodies come from
[gouroboros](https://github.com/blinklabs-io/gouroboros). HD wallets come from
[bursa](https://github.com/blinklabs-io/bursa). Plutus data encoding can use
[plutigo](https://github.com/blinklabs-io/plutigo) directly or Apollo's
[struct-tag encoder](plutusencoder/README.md).

The module path is `github.com/Salvionied/apollo/v2`. Apollo v2 requires Go
1.25.13 or newer — the `go` directive in `go.mod` is a hard floor.

## Start here

- **[Install and first transaction](getting_started/README.md)** — `go get`, a
  Blockfrost payment, and the `Complete` → `Sign` → `Submit` loop.
- **[Fluent builder and errors](getting_started/fluent_api.md)** — chaining
  methods that cannot fail, and why `Complete()` is where stored errors surface.
- **[Chain backends](backends/README.md)** — Blockfrost, Ogmios/Kupo,
  UTxO RPC, the in-memory `fixed` backend, and the cache wrapper.

## Build transactions

- **[Builder overview](transaction_building/README.md)**
- **[Wallets and signing](wallets/README.md)**
- **[Coin selection (MACS)](coin_selection/README.md)**
- **[Fees and collateral](fees_and_collateral/README.md)**
- **[Plutus encoder](plutusencoder/README.md)**
- **[Validation and pitfalls](validation/README.md)** — behaviors the compiler
  will not catch when upgrading from v1.

## Domain guides

These pages include method signatures, examples, and cardano-cli comparisons
written against **cardano-cli 10.14.0.0**. The latest upstream CLI release at
the time of the v2 review was 11.0.0.0; treat parity statements as historical
until that review is complete.

- **[Plutus V3 Support](plutus_v3_support/README.md)**
- **[Data Attachment](data_attachment/README.md)**
- **[Staking Functionalities](staking_functionalities/README.md)**
- **[Conway Governance](conway_governance/README.md)**

## Migration

- **[v1 to v2](v2_migration/MIGRATION.md)**

## Other references

- [GitHub README](https://github.com/Salvionied/apollo/blob/master/README.md) —
  short landing page and install snippet.
- [Changelog](https://github.com/Salvionied/apollo/blob/master/CHANGELOG.md)
- [pkg.go.dev](https://pkg.go.dev/github.com/Salvionied/apollo/v2)
- [Apollo Discord](https://discord.gg/MH4CmJcg49)

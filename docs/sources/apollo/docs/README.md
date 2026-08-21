# Apollo Documentation

Documentation for the Apollo transaction building library for Cardano.

## Sections

- **[Plutus V3 Support](plutus_v3_support/README.md)** — Plutus V3 scripts, reference inputs, cost models, and data structures.
- **[Data Attachment](data_attachment/README.md)** — Attaching Plutus datums (hash and inline) and reference scripts to transaction outputs; CLI parity for datum and reference script flags.
- **[Staking Functionalities](staking_functionalities/README.md)** — Stake key registration and deregistration, pool and vote (DRep) delegation, combined certificates, and reward withdrawals; CLI parity for stake-address and withdrawal flags.
- **[Conway Governance](conway_governance/README.md)** — DRep registration/retirement/update, constitutional committee key authorization and resignation, casting votes, submitting governance action proposals, and treasury donations; CLI parity for `conway governance` commands and CIP-1694.
- **[v1 to v2 migration](v2_migration/MIGRATION.md)** — Import, type, and builder API changes for users upgrading from Apollo v1.
- **[SundaeSwap fork migration](sundaeswap-fork-migration.md)** — A focused checklist for applications moving from the SundaeSwap fork.

The command comparisons were written against **cardano-cli 10.14.0.0**. During
the Apollo v2 release review, the latest
[upstream release](https://github.com/IntersectMBO/cardano-cli/releases) was
11.0.0.0. The examples have not yet been fully revalidated against that
release, so treat parity statements as historical until that review is
complete. API details and examples are based on the Apollo codebase (see
[AGENTS.md](../AGENTS.md) for build and test commands).

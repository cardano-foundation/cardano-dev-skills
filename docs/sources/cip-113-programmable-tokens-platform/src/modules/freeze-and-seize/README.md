# Freeze-and-Seize Module

A CIP-113 module for regulated stablecoins: denylist-aware transfer logic, seizure/freeze operations, and on-chain denylist management.

This module demonstrates how regulatory controls can be implemented on top of the CIP-113 core framework while preserving Cardano's native-token semantics.

## What it provides

- **Denylist** — On-chain sorted linked list of denied credentials (`blacklist_mint`, `blacklist_spend`)
- **Transfer validation** — Every transfer checks that sender and recipient are not denylisted (`example_transfer_logic`)
- **Constant-time checks** — O(1) verification via covering-node proofs against the sorted list
- **Issuer controls** — Authorised parties can freeze and seize tokens held by denylisted credentials

## Prerequisites

- [Aiken](https://aiken-lang.org/installation-instructions) v1.1.21 (pinned in `aiken.toml`)

## Build and test

```bash
aiken fmt --check
aiken check -D
aiken build
```

## Structure

```
freeze-and-seize/
├── aiken.toml
├── plutus.json                                 # Build output
├── lib/
│   ├── linked_list.ak                          # Sorted linked list ops (denylist storage)
│   ├── types.ak                                # Data types
│   ├── utils.ak                                # Utilities
│   └── *_test.ak                               # Unit tests
└── validators/
    ├── blacklist_mint.ak                       # Denylist minting policy (add/remove entries)
    ├── blacklist_spend.ak                      # Denylist node UTxO guard
    └── example_transfer_logic.ak               # Transfer validator consulting the denylist
```

## How it fits CIP-113

This module is a **stake validator** invoked via a 0-ADA withdrawal, registered in the CIP-113 registry alongside the token's issuance policy. When a transfer occurs, the core `programmable_logic_global` validator looks the token up in the registry and requires this module's withdrawal to succeed — which is where denylist checks happen.

For the full on-chain coordination model, see the [core framework's architecture doc](https://github.com/cardano-foundation/cip113-programmable-tokens/blob/main/documentation/02-ARCHITECTURE.md).

## Related

- Platform overview: [root README](../../../README.md)
- Core framework: [cardano-foundation/cip113-programmable-tokens](https://github.com/cardano-foundation/cip113-programmable-tokens)
- Contract provenance: [docs/CONTRACTS.md](../../../docs/CONTRACTS.md)

## License

Apache License 2.0 — see the [LICENSE](../../../LICENSE) file for details.

# Dummy Module

A minimal CIP-113 module used for integration testing and as a template for building new modules.

The `transfer` validator accepts a transfer only when the redeemer is exactly `200`; the `issue` validator accepts issuance only when the redeemer is exactly `100`. There is no real-world authorisation logic — the point is to exercise the CIP-113 registry, withdrawal flow, and off-chain integration without any domain-specific rules getting in the way.

Use this as:

- A smoke test for the core CIP-113 framework end-to-end
- A starting point when implementing your own module (copy, rename, add real logic)

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
dummy/
├── aiken.toml
├── plutus.json          # Build output
└── validators/
    └── transfer.ak      # issue + transfer withdraw validators
```

## Related

- Platform overview: [root README](../../../README.md)
- Core framework: [cardano-foundation/cip113-programmable-tokens](https://github.com/cardano-foundation/cip113-programmable-tokens)
- Contract provenance: [docs/CONTRACTS.md](../../../docs/CONTRACTS.md)

## License

Apache License 2.0 — see the [LICENSE](../../../LICENSE) file for details.

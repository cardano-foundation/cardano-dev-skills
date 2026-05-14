# CIP-113 Programmable Tokens — Aiken Implementation

![Aiken](https://img.shields.io/badge/Aiken-v1.1.21-blue)
![CIP-113](https://img.shields.io/badge/CIP--113-Adapted-green)
![Status](https://img.shields.io/badge/Status-R&D-yellow)

**Smart contracts for CIP-113 programmable tokens on Cardano, written in Aiken.**

This repository contains the **on-chain** implementation. The off-chain platform (reference frontend, Java backend, and substandard implementations used for experimentation on testnets) lives in a companion repository:

👉 **[cardano-foundation/cip113-programmable-tokens-platform](https://github.com/cardano-foundation/cip113-programmable-tokens-platform)**

---

## Important Disclaimers

### Origins and Attribution

This implementation builds on the foundational **CIP-143 reference implementation** originally developed by Phil DiSarro and the IOG team. The Aiken validators in this repository are migrated from their Plutarch implementation.

**Original work:**
- Repository: [input-output-hk/wsc-poc](https://github.com/input-output-hk/wsc-poc)
- Specification: [CIP-143: Interoperable Programmable Tokens](https://cips.cardano.org/cip/CIP-0143)
- Authors: Phil DiSarro, IOG Team

We are deeply grateful for the significant effort and expertise invested in the original design and implementation. Their work has provided an invaluable foundation for advancing programmable token standards on Cardano.

### CIP-113 Adaptation

This codebase has been adapted to align with the requirements of **CIP-113**, which supersedes CIP-143 as a more comprehensive standard for programmable tokens on Cardano.

**Note:** CIP-113 is currently under active development ([PR #444](https://github.com/cardano-foundation/CIPs/pull/444)) and has not been finalized. The specification may change as the standard evolves. This implementation reflects our current understanding and may require updates as CIP-113 matures.

---

## Overview

CIP-113 defines the core framework for programmable tokens on Cardano: the shared custody model, on-chain registry, and validation coordination. The actual rules that specific programmable tokens must obey (e.g. denylist checks, freeze-and-seize) are defined in **substandards** — pluggable rule sets that operate within the CIP-113 framework. This repository contains the core standard implementation; example substandards live in the [platform repository](https://github.com/cardano-foundation/cip113-programmable-tokens-platform/tree/main/src/substandards).

## What Are Programmable Tokens?

Programmable tokens are **native Cardano assets** with an additional layer of validation logic that executes on every transfer, mint, or burn operation. They leverage Cardano's existing native token infrastructure and require no hard fork or ledger changes — all programmable logic is implemented using features already supported at the L1 level. However, because all programmable tokens are held at a shared script address (with ownership determined by stake credentials), existing wallets, explorers, and DEXes would require integration work to fully support them — for example, wallets need to resolve stake-credential-based ownership to display balances, and DEX contracts would need to account for the programmable logic validators.

**Key principle:** All programmable tokens are locked in a shared smart contract address. Ownership is determined by stake credentials, allowing standard wallets to manage them while enabling unified validation across the entire token ecosystem.

## Key Features

- 🔐 **Permissioned Transfers** — Enforce custom validation rules on every token transfer
- 📋 **On-Chain Registry** — Decentralized directory of registered programmable tokens
- 🎯 **Composable Logic** — Plug-and-play transfer and minting validation scripts
- 🚫 **Freeze & Seize** — Optional issuer controls for regulatory compliance
- ⚡ **Constant-Time Lookups** — Sorted linked list registry enables O(1) token verification
- 🔗 **Native Asset Based** — Built on Cardano's native token infrastructure with no hard fork required
- 🛡️ **Multi-Layer Security** — NFT authenticity, ownership proofs, and authorization checks
- 🧩 **Extensible** — Support for denylists, allowlists, time-locks, and custom policies

## Use Cases

- **Stablecoins** — Fiat-backed tokens with sanctions screening and freeze capabilities
- **Tokenized Securities** — Compliance with securities regulations and transfer restrictions
- **Regulated Assets** — Any token requiring KYC/AML compliance or jurisdictional controls
- **Tokenized Real-World Assets (RWAs)** — Asset-backed tokens with programmable restrictions
- **Custom Policies** — Extensible framework for any programmable token logic

## Quick Start

### Prerequisites

- [Aiken](https://aiken-lang.org/installation-instructions) v1.1.21 (pinned in `aiken.toml`)
- [Cardano CLI](https://github.com/IntersectMBO/cardano-cli) (optional, for deployment)

### Build

```bash
aiken build
```

### Test

```bash
aiken check
```

All tests should pass (202 checks at the time of writing).

## Project Structure

```
.
├── validators/                             # Smart contract validators
│   ├── programmable_logic_global.ak        # Core transfer validation coordinator
│   ├── programmable_logic_base.ak          # Token custody (delegates to global)
│   ├── programmable_logic/                 # Supporting modules for the global validator
│   ├── registry_mint.ak                    # Registry sorted linked list management
│   ├── registry_spend.ak                   # Registry node UTxO guard
│   ├── issuance_mint.ak                    # Token minting/burning policy
│   ├── issuance_cbor_hex_mint.ak           # Issuance script template reference NFT
│   └── protocol_params_mint.ak             # Protocol parameters NFT (one-shot)
├── lib/                                    # Shared library modules
│   ├── types.ak                            # Core data types
│   ├── utils.ak                            # Utility functions
│   ├── linked_list.ak                      # Sorted linked list operations
│   └── ...
├── env/                                    # Aiken environments
├── documentation/                          # Architecture + integration guides
├── aiken.toml                              # Aiken project manifest
└── build.sh                                # Build helper
```

## Documentation

📚 **Documentation is available in the [`documentation/`](./documentation/) directory:**

- **[Introduction](./documentation/01-INTRODUCTION.md)** — Problem statement, concepts, and benefits
- **[Architecture](./documentation/02-ARCHITECTURE.md)** — System design, validator coordination, on-chain data structures, and validation flows
- **[Developing Substandards](./documentation/09-DEVELOPING-SUBSTANDARDS.md)** — Guide for implementing new substandards (issuance, transfer, and third-party logic)
- **[Integration Guides](./documentation/08-INTEGRATION-GUIDES.md)** — For wallet developers, indexers, and dApp developers

## Core Components

The system is split into two layers: the **core standard** (CIP-113 framework, this repository) and **substandards** (pluggable token-specific rules, [platform repository](https://github.com/cardano-foundation/cip113-programmable-tokens-platform/tree/main/src/substandards)).

### Core Standard (CIP-113 Framework)

These components form the shared infrastructure that all programmable tokens use:

#### 1. Token Registry (On-Chain Directory)

A sorted linked list of registered programmable tokens, implemented as on-chain UTxOs with NFT markers. Each registry entry contains the token policy ID, transfer validation script reference, issuer control script reference, and optional global state reference. The sorted structure enables O(1) membership and non-membership proofs via covering nodes.

#### 2. Programmable Logic Base + Global Validator

A shared spending validator (`programmable_logic_base`) holds all programmable tokens. It delegates all validation to the `programmable_logic_global` stake validator via the withdraw-zero pattern — the base runs per-input but the global runs once per-transaction, keeping costs constant regardless of input count.

#### 3. Minting Policies

- **Issuance Policy** (`issuance_mint`) — Parameterized per token type, handles minting/burning
- **Registry Policy** (`registry_mint`) — Manages the sorted linked list of registered tokens
- **Protocol Params Policy** (`protocol_params_mint`) — One-shot mint for global protocol parameters

### Substandards (Pluggable Token Rules)

Substandards define the actual rules that specific programmable tokens must obey. They are stake validators invoked via 0-ADA withdrawals, registered in the on-chain registry, and executed by the core framework on every transfer. Different tokens can use different substandards depending on their compliance requirements.

Substandard implementations live in the platform repository:

- **[Dummy](https://github.com/cardano-foundation/cip113-programmable-tokens-platform/tree/main/src/substandards/dummy)** — Simple permissioned transfer requiring a specific credential
- **[Freeze and Seize](https://github.com/cardano-foundation/cip113-programmable-tokens-platform/tree/main/src/substandards/freeze-and-seize)** — Denylist-aware transfer logic, seizure/freeze operations, and on-chain denylist management for regulated stablecoins

### Validator Reference

**Core Standard (CIP-113 Framework)**

| Validator | Type | Purpose |
|-----------|------|---------|
| `programmable_logic_base` | Spend | Custody of all programmable token UTxOs; delegates to global validator |
| `programmable_logic_global` | Stake (withdraw) | Core coordinator: registry lookups, transfer logic invocation, value preservation |
| `protocol_params_mint` | Mint | One-shot mint of protocol parameters NFT |
| `registry_mint` | Mint | Sorted linked list management for registered token policies |
| `registry_spend` | Spend | Guards registry node UTxOs |
| `issuance_mint` | Mint | Mints/burns programmable tokens (parameterized per token type) |
| `issuance_cbor_hex_mint` | Mint | One-shot mint of issuance script template reference NFT |

See the [Architecture doc](./documentation/02-ARCHITECTURE.md) for detailed validator interactions and validation flows. For substandard validators, see the [platform repository](https://github.com/cardano-foundation/cip113-programmable-tokens-platform/tree/main/src/substandards).

## Transaction Lifecycle

```mermaid
graph LR
    A[Deploy Protocol] --> B[Register Token]
    B --> C[Issue Tokens]
    C --> D[Transfer]
    D --> D
    C --> E[Burn]

    style A fill:#e1f5ff
    style B fill:#fff4e1
    style C fill:#e8f5e9
    style D fill:#f3e5f5
    style E fill:#ffebee
```

1. **Deployment** — One-time setup of registry and protocol parameters
2. **Registration** — Register transfer logic and mint policy in registry
3. **Issuance** — Mint tokens with registered validation rules
4. **Transfer** — Transfer tokens with automatic validation
5. **Burn** — Burn tokens (requires issuer authorization)

## How It Works

```mermaid
graph TB
    A[User Initiates Transfer] --> B{Lookup Token in Registry}
    B -->|Found| C[Invoke Transfer Logic Script]
    B -->|Not Found| D[Treat as Regular Native Token]
    C --> E{Validation Passes?}
    E -->|Yes| F[Complete Transfer]
    E -->|No| G[Reject Transaction]
    D --> F

    style A fill:#e3f2fd
    style B fill:#fff9c4
    style C fill:#f3e5f5
    style E fill:#ffe0b2
    style F fill:#c8e6c9
    style G fill:#ffcdd2
```

All programmable tokens are locked at a shared smart contract address. When a transfer occurs:

1. Transaction spends token UTxO from programmable logic address
2. Global validator looks up token in on-chain registry
3. If registered, corresponding transfer logic script executes
4. Transfer succeeds only if all validation passes
5. Tokens return to programmable logic address with new stake credential

## Example: Freeze & Seize Stablecoin

The [platform repository](https://github.com/cardano-foundation/cip113-programmable-tokens-platform/tree/main/src/substandards/freeze-and-seize) includes a complete example of a regulated stablecoin with freeze and seize capabilities:

- **On-chain Denylist** — Sorted linked list of sanctioned addresses
- **Transfer Validation** — Every transfer checks sender/recipient not denylisted
- **Constant-Time Checks** — O(1) verification using covering node proofs
- **Issuer Controls** — Authorized parties can freeze/seize tokens

## Standards

This implementation is based on the foundational [CIP-143 (Interoperable Programmable Tokens)](https://cips.cardano.org/cip/CIP-0143) architecture and has been adapted for [CIP-113](https://github.com/cardano-foundation/CIPs/pull/444), which supersedes CIP-143 as a more comprehensive standard for programmable tokens on Cardano.

## Development Status

**Current Status:** Research & Development

This is high-quality research and development code with the following characteristics:

- ✅ All core validators implemented with strong code quality
- ✅ Registry (directory) operations complete
- ✅ Token issuance and transfer flows working
- ✅ Freeze & seize functionality complete (in the [platform repo](https://github.com/cardano-foundation/cip113-programmable-tokens-platform))
- ✅ Denylist system operational
- ✅ Good test coverage (202 checks passing)
- ✅ Tested on Preview testnet (limited scope)
- ⏳ Comprehensive testing required
- ⏳ Professional security audit pending

**Security features implemented:**
- ✅ NFT-based registry authenticity
- ✅ Ownership verification via stake credentials
- ✅ Multi-layer authorization checks
- ✅ One-shot minting policies for protocol components
- ✅ Immutable validation rules post-registration
- ✅ DDOS prevention mechanisms

## Security Considerations

⚠️ **Important:** This code has **not been professionally audited** and has only been briefly tested on Preview testnet. While code quality is high, it is **not production-ready**. Do not use with real assets or in production environments without:

- Comprehensive security audit by qualified professionals
- Extensive testing across multiple scenarios
- Thorough review by domain experts

## Related Components

- **Off-chain platform:** [cardano-foundation/cip113-programmable-tokens-platform](https://github.com/cardano-foundation/cip113-programmable-tokens-platform) — Reference Next.js frontend, Java backend, and substandard implementations.

## Contributing

Contributions welcome! Please:

1. Read the [documentation](./documentation/) to understand the architecture
2. Ensure all tests pass (`aiken check`)
3. Add tests for new functionality
4. Follow existing code style and patterns
5. Open an issue to discuss major changes

See [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

## Testing

Run the complete test suite:

```bash
# Run all tests
aiken check

# Run specific test file
aiken check -m validators/programmable_logic_global

# Watch mode for development
aiken check --watch
```

## Resources

- 📖 [Aiken Language Documentation](https://aiken-lang.org/)
- 🎓 [CIP-143 Specification](https://cips.cardano.org/cip/CIP-0143) — Original standard
- 🔄 [CIP-113 Pull Request](https://github.com/cardano-foundation/CIPs/pull/444) — Current standard development
- 🔗 [Cardano Developer Portal](https://developers.cardano.org/)
- 💬 [Aiken Discord](https://discord.gg/Vc3x8N9nz2)

## License

This project is licensed under the Apache License 2.0 — see the [LICENSE](./LICENSE) file for details.

Copyright 2024 Cardano Foundation

## Acknowledgments

This implementation is migrated from the original Plutarch implementation developed by **Phil DiSarro** and the **IOG Team** (see [wsc-poc](https://github.com/input-output-hk/wsc-poc)). We are grateful for their foundational work on CIP-143.

Special thanks to:
- **Phil DiSarro** and the **IOG Team** for the original Plutarch design and implementation
- The **Aiken team** for the excellent smart contract language and tooling
- The **CIP-143/CIP-113 authors and contributors** for standard development
- The **Cardano developer community** for continued support and collaboration

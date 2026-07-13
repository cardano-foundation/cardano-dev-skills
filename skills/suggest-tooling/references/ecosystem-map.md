# Cardano Developer Ecosystem Map

Comprehensive map of tools, SDKs, and infrastructure in the Cardano developer ecosystem.

## Smart Contract Languages

| Name | Base Language | Status | Adoption | Best For |
|---|---|---|---|---|
| **Aiken** | Own (Rust-like) | Production | High | Most new smart contract projects. Fast compilation, great DX. |
| **Plinth (formerly Plutus Tx)** | Haskell | Production | High | Haskell teams, complex on-chain logic, academic rigor. |
| **OpShin** | Python | Production | Medium | Python developers wanting to write validators in Python. |
| **Pebble** | TypeScript | Production | Medium | TypeScript devs wanting on-chain + off-chain in one language (`@harmoniclabs/pebble`, successor of Plu-ts). |
| **Scalus** | Scala | Production | Low | JVM/Scala teams. |
| **Helios** | Own (JS-like) | Production | Medium | Quick prototyping, simple validators. |
| **Plutarch** | Haskell (eDSL) | Production | Medium | Performance-optimized Plutus, Haskell experts. |

## Off-Chain SDKs

### TypeScript / JavaScript

| Name | Status | Adoption | Best For |
|---|---|---|---|
| **Mesh SDK** | Production | High | Full-stack dApp dev, beginners, React integration, comprehensive API. |
| **Evolution SDK** | Production | High | IntersectMBO's canonical Lucid-lineage successor. Type-safe, Effect-based composable tx building. Staged-builder API (`Client.make(...).withBlockfrost(...).newTx().payToAddress(...).build()`). Modern DX. |
| **Blaze** | Production | Medium | Modular, lightweight alternative. Multiple provider backends. |
| **cardano-js-sdk** | Production | Medium | Lace wallet ecosystem, full node interaction, enterprise use. |
| **Cardano Multiplatform Lib** | Production | Medium | Low-level serialization, cross-platform WASM. |

### Python

| Name | Status | Adoption | Best For |
|---|---|---|---|
| **PyCardano** | Production | High | Python backends, scripting, data science, prototyping. |

### Rust

| Name | Status | Adoption | Best For |
|---|---|---|---|
| **whisky** | Production | Low | dApp transaction building (Mesh-like API; SIDAN Lab, young project). |
| **Pallas** | Production | High | Low-level building blocks: network protocols, ledger primitives, indexers. Foundation of Dolos/Oura/Amaru; not an app-dev tx builder. |
| **Cardano Serialization Lib** | Production | Medium | Serialization/deserialization, WASM targets. |

### Java / Kotlin

| Name | Status | Adoption | Best For |
|---|---|---|---|
| **Cardano Java Client Lib** | Production | Medium | JVM backends, Android, enterprise Java. |
| **Yaci** | Production | Medium | Java mini-protocols, low-level node interaction. |

### Go

| Name | Status | Adoption | Best For |
|---|---|---|---|
| **gouroboros** | Production | Low | Go backends, node communication. |
| **apollo (Go)** | Production | Low | Go tx building. |

### C# / .NET

| Name | Status | Adoption | Best For |
|---|---|---|---|
| **CardanoSharp** | Production | Low | .NET backends, Unity game development. |
| **Chrysalis** | Experimental | Low | .NET Cardano integration. |

## Infrastructure - Data Providers

| Name | Type | Protocol | Status | Adoption | Best For |
|---|---|---|---|---|---|
| **Blockfrost** | Hosted | REST | Production | High | Quick start, frontend dApps, no infra management. |
| **Koios** | Hosted (community) | REST | Production | High | Free tier, open source, community-maintained. |
| **Ogmios** | Self-hosted | WebSocket | Production | High | Low-latency, tx submission, paired with Kupo. |
| **Kupo** | Self-hosted | REST | Production | High | UTxO indexing by pattern, datum resolution. |
| **DB-Sync** | Self-hosted | SQL | Production | High | Full chain in PostgreSQL, analytics, reporting. |
| **Oura** | Self-hosted | Pipeline | Production | Medium | Event streaming, Kafka/Elastic/webhooks. |
| **Cardano GraphQL** | Self-hosted | GraphQL | Production | Medium | Complex queries, relationship traversal. |
| **Scrolls** | Self-hosted | Various | Production | Low | Lightweight chain indexer, key-value projections. |
| **Carp** | Self-hosted | REST | Production | Low | Lightweight indexer, specific query patterns. |

## Infrastructure - Node & Network

| Name | Status | Best For |
|---|---|---|
| **cardano-node** | Production | Running a full Cardano node. Required for SPOs and self-hosted infra. |
| **Dolos** | Experimental | Lightweight data-only node (no block production). Faster sync. |
| **Amaru** | Experimental | Alternative node implementation in Rust. |
| **Mithril** | Production | Fast bootstrapping via snapshot certificates. Sync in minutes, not days. |

## Testing

| Name | Type | Status | Best For |
|---|---|---|---|
| **Aiken built-in** | Unit + property tests | Production | Validator logic testing with `test` and `fuzz`. |
| **Yaci DevKit** | Local devnet | Production | Integration testing, full tx lifecycle. |
| **Preview testnet** | Public testnet | Production | Shared-state testing, new features. |
| **Preprod testnet** | Public testnet | Production | Pre-production, mainnet-mirroring params. |
| **SanchoNet** | Governance testnet | Production | Governance-specific testing. |
| **tx-village** | Tx testing framework | Experimental | Transaction-level testing. |
| **Plutip** | Local cluster | Production | Haskell-based local cluster testing. |

## Governance Tools

| Name | Status | Best For |
|---|---|---|
| **GovTool** | Production | Web UI for DRep registration, voting, delegation. |
| **cardano-cli (Conway)** | Production | CLI governance operations. |
| **SanchoNet** | Production | Governance testnet for practice. |
| **Intersect tools** | Production | Constitutional Committee and governance coordination. |

## Scaling Solutions

| Name | Type | Status | Best For |
|---|---|---|---|
| **Hydra** | State channels (L2) | Production | High-frequency, low-latency off-chain transactions. |
| **Mithril** | Snapshot certificates | Production | Fast chain sync, lightweight clients. |
| **Partner Chains** | Sidechains | Experimental | Custom chains anchored to Cardano. |
| **Input Endorsers** | L1 scaling | Research | Future L1 throughput improvements. |

## Wallet Connectors

| Name | Type | Status | Best For |
|---|---|---|---|
| **CIP-30** | Browser standard | Production | Connecting browser extension wallets to dApps. |
| **CIP-95** | Governance extension | Production | Governance actions in wallets (extends CIP-30). |
| **Mesh SDK wallet hooks** | React library | Production | React-based dApp wallet integration. |
| **WalletConnect** | Mobile bridge | Production | Mobile wallet connection. |
| **CIP-45** | Peer-to-peer DApp connector | Production | Decentralized wallet-dApp connection. |

## Popular Wallets (for developer testing)

| Name | Type | CIP-30 | CIP-95 |
|---|---|---|---|
| **Eternl** | Browser extension | Yes | Yes |
| **Lace** | Browser extension | Yes | Yes |
| **Nami** | Browser extension | Yes | Partial |
| **Flint** | Browser extension | Yes | Yes |
| **Vespr** | Mobile + extension | Yes | Yes |
| **Typhon** | Browser extension | Yes | Yes |
| **GeroWallet** | Browser extension | Yes | Partial |

## Metadata & Standards

| CIP | Name | Purpose |
|---|---|---|
| CIP-25 | NFT Metadata | Standard for NFT metadata on Cardano |
| CIP-30 | Wallet Bridge | dApp-wallet web bridge standard |
| CIP-57 | Blueprints | Plutus contract blueprint specification |
| CIP-68 | Rich Tokens | Datum-based token metadata (FTs, NFTs, RFTs) |
| CIP-95 | Governance Wallet | Governance extensions for CIP-30 |
| CIP-1694 | Governance | On-chain governance mechanism |
| CIP-1854 | Multi-sig | Multi-signature wallet standard |

## Developer Resources

| Resource | URL | Description |
|---|---|---|
| Cardano Developer Portal | developers.cardano.org | Official developer docs and guides |
| Aiken documentation | aiken-lang.org | Smart contract language docs |
| Cardano Docs | docs.cardano.org | Core Cardano documentation |
| CIPs repository | github.com/cardano-foundation/CIPs | All Cardano Improvement Proposals |
| Cardano Forum | forum.cardano.org | Community discussion |
| Cardano Stack Exchange | cardano.stackexchange.com | Q&A for developers |

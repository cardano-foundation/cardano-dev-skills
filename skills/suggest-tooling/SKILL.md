---
name: suggest-tooling
description: >-
  Recommends Cardano developer tools and SDKs for a specific project. Triggers: "which SDK", "recommend tools", "best library for", "Cardano SDK", "Mesh vs Evolution SDK", "Aiken vs Plutus", "what tools should I use", "Cardano ecosystem", "oracle", "price feed", "price oracle", "external data on-chain", "real-world data on-chain".
allowed-tools: Read Grep Glob
disallowed-tools: Bash Edit Write WebFetch WebSearch
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Suggest Cardano Tooling

Help the developer choose the right tools, SDKs, and libraries for their Cardano project based on their requirements and preferred programming language.

## When to use

- Developer is starting a new Cardano project and needs tool recommendations
- Comparing SDKs (Mesh vs Evolution SDK vs PyCardano vs others)
- Choosing a smart contract language (Aiken vs Plutus vs others)
- Selecting infrastructure components (indexers, APIs, testing tools)
- Choosing how to get external data on-chain (oracles, price feeds)
- Evaluating wallet integration options
- Understanding which CIPs are relevant to their project

## When NOT to use

- Already chosen tools and needs help using them (use specific tool skills)
- Setting up a devnet (use `setup-devnet` skill)
- Querying chain data with a specific provider (use `query-chain` skill)
- Detailed wallet integration steps (use `connect-wallet` skill)

## Key principles

1. **Start from the project requirements, not the tools.** Understand what they are building before recommending.
2. **Language preference matters.** A Python developer should know about PyCardano; a TypeScript developer about Mesh and Evolution SDK.
3. **Recommend production-ready tools first.** Flag experimental tools clearly.
4. **Fewer tools is better.** Do not recommend 10 options when 2 will do.
5. **Consider the full stack.** Smart contracts, off-chain code, infrastructure, testing, and deployment are all part of the picture.

## Workflow

### Step 1: Understand the project

Ask the developer (if not already clear):

- **What are you building?** (dApp, DeFi protocol, NFT platform, governance tool, data analytics, wallet, library)
- **What programming language(s) do you prefer?**
- **Do you need smart contracts?** If yes, how complex?
- **What is your deployment target?** (mainnet, testnet, local devnet)
- **What is your experience level with Cardano?** (new, intermediate, advanced)
- **Any existing infrastructure?** (running a node, using hosted APIs)

### Step 2: Search Bundled Documentation

Search the bundled documentation for relevant content:
- `${CLAUDE_SKILL_DIR}/../../docs/sources/mesh-sdk/` - Mesh SDK docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/evolution-sdk/` - Evolution SDK docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/aiken/` - Aiken language docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/ogmios/` - Ogmios WebSocket bridge docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/blockfrost-openapi/` - Blockfrost API docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/developer-portal/developers/curriculum/dapps/oracles/` - oracle concepts, integration, randomness
- `${CLAUDE_SKILL_DIR}/../../docs/sources/pyth-lazer-cardano/` - Pyth oracle design doc, Aiken contracts, consumer guide
- `${CLAUDE_SKILL_DIR}/../../docs/sources/charli3-pull-oracle-contracts/` - Charli3 oracle architecture and validators

### Step 3: Search the ecosystem map

Reference the ecosystem map for the full landscape:

```
File: skills/suggest-tooling/references/ecosystem-map.md
```

### Step 4: Recommend by category

#### Smart Contract Languages

| Language | Best for | Language base | Status |
|---|---|---|---|
| **Aiken** | Most new projects, performance-critical validators | Own syntax (Rust-like) | Production |
| **Plinth (formerly Plutus Tx)** | Haskell teams, complex on-chain logic | Haskell | Production |
| **OpShin** | Python developers writing validators | Python | Production |
| **Pebble** | TypeScript developers wanting on-chain code in TS (`@harmoniclabs/pebble`, successor of Plu-ts) | TypeScript | Production |
| **Scalus** | Scala/JVM teams | Scala | Production |
| **Helios** | Simple validators, quick prototyping | Own syntax (JS-like) | Production |

**Default recommendation**: Aiken. Best tooling, fastest compilation, growing community, excellent documentation. Unless the team has a strong reason to use another language.

#### Off-Chain SDKs

| SDK | Language | Best for | Status |
|---|---|---|---|
| **Mesh SDK** | TypeScript/JS | Full-stack dApp development, beginners | Production |
| **Evolution SDK** | TypeScript/JS | IntersectMBO's canonical Lucid-lineage successor. Type-safe, Effect-based composable tx building (`Client.make(...).withBlockfrost(...).newTx().payToAddress(...).build()`) | Production |
| **PyCardano** | Python | Python backends, scripting, data science | Production |
| **Cardano CLI** | Shell | DevOps, scripting, node operators | Production |
| **cardano-js-sdk** | TypeScript | Lace wallet ecosystem, full node interaction | Production |
| **Blaze** | TypeScript | Lightweight, modular tx building | Production |
| **Cardano Java Client Lib** | Java/Kotlin | JVM backends, Android | Production |
| **whisky** | Rust | Transaction building for dApps (Mesh-like API; young project by SIDAN Lab) | Production |
| **Pallas** | Rust | Low-level building blocks: network protocols, ledger primitives, indexers (foundation of Dolos, Oura, Amaru) | Production |

**Default recommendation by language**:
- TypeScript/JavaScript: **Mesh SDK** (comprehensive, well-documented, great for beginners) or **Evolution SDK** (type-safe, Effect-based composable builder)
- Python: **PyCardano**
- Rust: **Pallas**
- Java/Kotlin: **Cardano Java Client Lib**

#### Infrastructure

| Tool | Purpose | Type |
|---|---|---|
| **Blockfrost** | Chain data API | Hosted |
| **Koios** | Chain data API | Hosted (community) |
| **Ogmios** | Node WebSocket bridge | Self-hosted |
| **Kupo** | UTxO indexer | Self-hosted |
| **DB-Sync** | Full chain PostgreSQL | Self-hosted |
| **Oura** | Event pipeline | Self-hosted |
| **Yaci DevKit** | Local devnet | Self-hosted |

**Default recommendation**: Blockfrost for getting started (easy, hosted). Ogmios + Kupo for production self-hosted.

#### Oracles / Data Feeds

First check the data is actually off-chain — UTxOs, balances, tx history, and protocol
parameters are on-chain reads (use the `query-chain` skill), not an oracle problem.
Then route by the pair you need, not by vendor list:

**Cross-chain pair (ADA/USD, BTC/USD, ...):**

| Option | Model | Notes |
|---|---|---|
| **Pyth Pro (Lazer)** | Pull: signed update carried in your own tx, verified via zero-withdrawal script | Access-gated commercial product — "request access" is part of the integration cost. Bundled docs: `docs/sources/pyth-lazer-cardano/` + dev-portal guide |

**Cardano-native token pair (MIN/ADA, SNEK/USD, ...):** no general-purpose third-party
feed covers these. The patterns production protocols actually use:

1. **Authenticated AMM pool read** — derive price from a DEX pool's reserves via
   reference input. Manipulable by design; the security pattern is in the
   `review-contract` skill's vulnerability checklist.
2. **Aggregate existing feeds** — other protocols publish oracle state for their own
   use; aggregate several plus DEX pools with median/deviation logic. Each source has
   no SLA to you, can change datum shape or stop at its publisher's discretion; know
   each feed's provenance (some in-house feeds are themselves backed by a third-party
   oracle); authenticate every source by NFT/policy, never by address.
3. **Butane's oracle network** — MIT open-source node stack whose feed is a signed
   HTTP payload verified in your validator with one Ed25519 check. Consumer
   integration surface is thin; see the ecosystem map for the architecture and links.
4. **Run your own publisher** — two documented open-source starting points with
   different architectures: Charli3's stack (pull-based multisig + IQR outlier
   consensus; Aiken + Python, bundled) and Butane's stack (Raft leader election +
   FROST threshold signing; Rust).

**Selection criteria**: publication model fit (push vs pull), who signs and how you
verify it on-chain, feed coverage, update cadence vs your freshness window, cost, and
operational liveness. Before building against any feed, verify it is currently
publishing — check for recent on-chain updates of the feed UTxO, not directory
listings or marketing pages. Current provider landscape with dated facts and primary
sources: `references/ecosystem-map.md` (Oracles & Data Feeds). Read pattern and
concepts: the dev-portal oracles curriculum (bundled). The dev-portal curriculum
recommends Pyth for most applications — treat that as the portal's editorial position;
the capability facts above are what should drive the choice.

#### Testing

| Tool | Purpose |
|---|---|
| **Aiken built-in tests** | Unit and property tests for Aiken validators |
| **Yaci DevKit** | Local devnet for integration tests |
| **Preview testnet** | Public testnet with frequent hard forks |
| **Preprod testnet** | Public testnet mirroring mainnet |
| **tx-village** | Transaction-level testing framework |

#### Wallet Integration

| Tool | Purpose |
|---|---|
| **Mesh SDK** | React hooks and components for wallet connection |
| **CIP-30 direct** | Vanilla JS wallet connection |
| **CIP-95** | Governance extensions for wallets |
| **WalletConnect** | Mobile wallet connection |

### Step 5: Recommend a stack

Based on the project requirements, recommend a concrete stack. Example stacks:

#### Beginner dApp (TypeScript)
- Smart contracts: **Aiken**
- Off-chain: **Mesh SDK**
- Infrastructure: **Blockfrost**
- Testing: Aiken tests + Yaci DevKit
- Wallet: Mesh wallet hooks

#### DeFi Protocol (TypeScript, advanced)
- Smart contracts: **Aiken**
- Off-chain: **Evolution SDK** or **Blaze**
- Infrastructure: **Ogmios + Kupo** (self-hosted)
- Data feeds: see **Oracles / Data Feeds** above — the answer differs for cross-chain vs Cardano-native pairs
- Testing: Aiken property tests + Preview testnet
- Wallet: CIP-30 direct integration

#### Python Backend
- Smart contracts: **Aiken** (or OpShin if team prefers Python on-chain too)
- Off-chain: **PyCardano**
- Infrastructure: **Blockfrost** or **Koios**
- Testing: Aiken tests + pytest with PyCardano

#### Data Analytics Platform
- Infrastructure: **DB-Sync** (SQL) + **Oura** (streaming)
- Language: Python or SQL
- No smart contracts needed

#### Governance Tool
- Off-chain: **Mesh SDK** (CIP-95 support)
- Infrastructure: **Blockfrost** or **Koios** (governance endpoints)
- Wallet: CIP-30 + CIP-95
- Reference: CIP-1694 for governance actions

### Step 6: Mention relevant CIPs

Based on the project type, flag relevant CIPs:

| Project type | Relevant CIPs |
|---|---|
| Any dApp | CIP-30 (wallet bridge), CIP-57 (blueprints) |
| Token/NFT | CIP-25 (NFT metadata), CIP-68 (rich FTs/NFTs) |
| Governance | CIP-1694 (governance), CIP-95 (wallet governance) |
| Multi-sig | CIP-1854 (multi-sig wallets) |
| Metadata | CIP-20 (tx metadata), CIP-25 (NFT metadata) |
| DEX | CIP-35 (on-chain message signing) |

### Step 7: Flag trade-offs

For each recommendation, briefly note:

- **Maturity**: How battle-tested is this tool?
- **Community**: Size and responsiveness of the community
- **Documentation**: Quality and completeness
- **Maintenance**: Is it actively maintained? Who maintains it?
- **Lock-in**: How easy is it to switch later?

## References

- `skills/suggest-tooling/references/ecosystem-map.md` -- Full ecosystem map with all tools
- Cardano developer portal: https://developers.cardano.org
- Aiken: https://aiken-lang.org
- Mesh SDK: https://meshjs.dev
- Evolution SDK: https://github.com/IntersectMBO/evolution-sdk (docs: https://evolution-sdk.dev)
- PyCardano: https://pycardano.readthedocs.io
- Blockfrost: https://blockfrost.io

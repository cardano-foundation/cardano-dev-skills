# NFT Ownership Demo — Private Token-Gated Access on Cardano

Prove you own an NFT **without revealing your wallet address**. This demo uses zero-knowledge proofs (Groth16 on BLS12-381) to enable anonymous, one-time access — with nullifiers stored on-chain in a sorted linked list on Cardano.

Built with [ZeroJ](https://github.com/bloxbean/zeroj) — a pure Java ZK toolkit for Cardano.

## What This Demo Does

1. **Mint NFTs** on a local Cardano devnet (Yaci DevKit)
2. **Build an ownership snapshot** — a Merkle tree of all NFT holders
3. **Generate a ZK proof** — proves you own an NFT without revealing which wallet holds it
4. **Verify and access** — proof is verified on-chain via Plutus V3, nullifier prevents reuse

The proof reveals **nothing** about your wallet address, which specific NFT you hold, or any other token in your wallet. The verifier only learns: "someone owns an NFT from this collection."

## Prerequisites

| Requirement | Version | How to install |
|-------------|---------|----------------|
| Java (GraalVM) | 25 | `sdk install java 25.0.2-graal` |
| Yaci DevKit | Latest | [yaci-devkit](https://github.com/bloxbean/yaci-devkit) |
| Node.js | 18+ | Only needed if rebuilding the frontend |

### Start Yaci DevKit

```bash
yaci-cli devkit start
```

This starts a local Cardano devnet on `localhost:8080` with admin API on `localhost:10000`.

### Set Java 25

```bash
sdk use java 25.0.2-graal
```

## Quick Start

### 1. Build

```bash
cd nft-ownership
./gradlew clean bootJar
```

To also rebuild the Svelte frontend:
```bash
./gradlew clean bootJar -PwithFrontend
```

### 2. Run

```bash
java --enable-native-access=ALL-UNNAMED \
  -Dzeroj.allowInsecureTrustedSetup=true \
  -jar build/libs/nft-ownership-*.jar
```

Startup takes ~50 seconds:
- Compiles the ZK circuit (10,847 constraints)
- Runs trusted setup (dev-only, single-party)
- Compiles on-chain Plutus validators
- Deploys root sentinel to the linked list on Yaci

Wait for: `Started NftOwnershipApplication in XX seconds`

### 3. Top up the admin wallet

```bash
curl -X POST http://localhost:10000/local-cluster/api/addresses/topup \
  -H "Content-Type: application/json" \
  -d '{"address":"addr_test1qryvgass5dsrf2kxl3vgfz76uhp83kv5lagzcp29tcana68ca5aqa6swlq6llfamln09tal7n5kvt4275ckwedpt4v7q48uhex","adaAmount":10000}'
```

### 4. Open the UI

**http://localhost:8085**

## Demo Flow (Step by Step)

### Step 1: Mint NFTs

```bash
curl -X POST http://localhost:8085/api/mint \
  -H "Content-Type: application/json" \
  -d '{"collectionName":"ZeroJTicket","count":3}'
```

This mints 3 NFTs (ZeroJTicket_1, ZeroJTicket_2, ZeroJTicket_3) on the local devnet.

### Step 2: Register holders and build snapshot

```bash
# Register a holder (secretKey identifies the wallet, tokenName identifies which NFT)
curl -X POST http://localhost:8085/api/snapshot/register \
  -H "Content-Type: application/json" \
  -d '{"secretKey":"12345","tokenName":"101"}'

# Build Merkle tree
curl -X POST http://localhost:8085/api/snapshot/build
```

### Step 3: Generate ZK proof

```bash
curl -X POST http://localhost:8085/api/prove \
  -H "Content-Type: application/json" \
  -d '{"secretKey":"12345","tokenName":"101"}'
```

This generates a Groth16 proof (~7-30 seconds, pure Java). The response includes the proof points and a `nullifier`.

### Step 4: Access (on-chain nullifier insertion)

```bash
curl -X POST http://localhost:8085/api/access \
  -H "Content-Type: application/json" \
  -d '{"nullifier":"<nullifier from step 3>"}'
```

This submits a Cardano transaction that:
- Verifies the Groth16 proof **on-chain** via BLS12-381 pairing check (Plutus V3)
- Inserts the nullifier into a **sorted linked list** on-chain
- Returns the transaction hash

### Step 5: Try again (double-access rejected)

```bash
curl -X POST http://localhost:8085/api/access \
  -H "Content-Type: application/json" \
  -d '{"nullifier":"<same nullifier>"}'
```

Returns `403`: "Already accessed (nullifier exists on-chain)"

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/mint` | Mint NFTs (`collectionName`, `count`) |
| GET | `/api/mint/status` | Minting status (policyId, tokens, admin address) |
| POST | `/api/snapshot/register` | Register holder (`secretKey`, `tokenName`) |
| POST | `/api/snapshot/build` | Build Merkle tree from registered holders |
| GET | `/api/snapshot/status` | Snapshot info (root, epoch, holder count) |
| POST | `/api/prove` | Generate ZK proof (`secretKey`, `tokenName`) |
| POST | `/api/verify` | Verify proof structure (`nullifier`, `snapshotRoot`) |
| POST | `/api/access` | Submit proof for gated access (`nullifier`) |
| GET | `/api/status` | System status (circuit, snapshot, nullifiers) |

## Configuration

Edit `src/main/resources/application.yml`:

```yaml
# Switch between on-chain and in-memory nullifier tracking
nullifier:
  mode: on-chain    # "on-chain" — nullifiers stored in Cardano sorted linked list
                    # "in-memory" — nullifiers stored in RAM (resets on restart)

zk:
  tree-depth: 10    # Merkle tree depth (10 = 1024 holders, 20 = 1M)
  pot-power: 13     # Powers of Tau (must be >= log2(constraints))
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | Spring Boot 3.5.0-M3 |
| Java | GraalVM 25 |
| ZK Proofs | ZeroJ (Groth16, BLS12-381, pure Java) |
| On-chain scripts | Julc (Java to Plutus V3) |
| Cardano client | cardano-client-lib 0.8.0 |
| Frontend | Svelte 5 + Vite |
| Local devnet | Yaci DevKit |

## Project Structure

```
nft-ownership/
├── build.gradle
├── src/main/java/.../nft/
│   ├── NftOwnershipApplication.java      # Spring Boot entry point
│   ├── circuit/
│   │   └── NFTOwnershipProof.java        # Symbolic annotation ZK circuit
│   ├── config/
│   │   └── CardanoConfig.java            # Network config (Yaci/Preprod)
│   ├── controller/
│   │   ├── ProofController.java          # Snapshot, prove, verify, access APIs
│   │   └── MintController.java           # NFT minting API
│   ├── service/
│   │   ├── ProverService.java            # Circuit compile + prove + verify
│   │   ├── SnapshotService.java          # Merkle tree builder
│   │   ├── MintService.java              # NFT minting on-chain
│   │   ├── NullifierTracker.java         # Interface for nullifier tracking
│   │   ├── NullifierService.java         # In-memory nullifier tracking
│   │   ├── OnChainNullifierService.java  # On-chain sorted linked list
│   │   └── ProofCompressor.java          # BLS point compression
│   └── onchain/
│       ├── ZkProofMintingPolicy.java     # Groth16 verifier (Plutus V3)
│       ├── NullifierListValidator.java   # Sorted linked list (Plutus V3)
│       └── NullifierListLib.java         # List validation logic
├── src/main/resources/
│   ├── application.yml
│   └── static/                           # Built frontend
└── frontend/                             # Svelte 5 + Vite source
```

## Important Notes

- The trusted setup is **dev-only** (single-party). Production use requires an MPC ceremony.
- The admin mnemonic in `application.yml` is for testing only.
- Proof generation is CPU-intensive (~7-30s). The pure Java prover runs on any JVM without native dependencies.
- Each on-chain nullifier node locks ~2 ADA (reclaimable if nullifiers are ever cleaned up).

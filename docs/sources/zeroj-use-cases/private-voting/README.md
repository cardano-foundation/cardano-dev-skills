# Private Voting Demo — Anonymous DAO Governance on Cardano

Cast votes in a DAO election **without revealing your identity or vote choice**. Uses zero-knowledge proofs (Groth16 on BLS12-381) with on-chain verification and a sorted linked list for nullifier-based double-vote prevention.

Built with [ZeroJ](https://github.com/bloxbean/zeroj) — a pure Java ZK toolkit for Cardano.

## What This Demo Does

1. **Creates an election** with 5 test voter accounts (auto-funded on Yaci DevKit)
2. **Builds a voter eligibility Merkle tree** — root published as public input
3. **Voters cast votes (YES/NO)** — ZK proof proves eligibility without revealing identity
4. **On-chain verification** — Groth16 proof verified via Plutus V3 BLS12-381 builtins
5. **Nullifier prevents double-voting** — sorted linked list on-chain
6. **Tally** — commitments on-chain are decoded to count YES/NO votes

The proof reveals **nothing** about which voter cast the vote or how they voted. The verifier only learns: "an eligible voter cast a valid vote."

## Prerequisites

| Requirement | Version | How to install |
|-------------|---------|----------------|
| Java (GraalVM) | 25 | `sdk install java 25.0.2-graal` |
| Yaci DevKit | Latest | [yaci-devkit](https://github.com/bloxbean/yaci-devkit) |

## Quick Start

```bash
# 1. Start Yaci DevKit
yaci-cli devkit start

# 2. Set Java 25
sdk use java 25.0.2-graal

# 3. Build
cd private-voting
./gradlew clean bootJar

# 4. Top up admin wallet
curl -X POST http://localhost:10000/local-cluster/api/addresses/topup \
  -H "Content-Type: application/json" \
  -d '{"address":"addr_test1qryvgass5dsrf2kxl3vgfz76uhp83kv5lagzcp29tcana68ca5aqa6swlq6llfamln09tal7n5kvt4275ckwedpt4v7q48uhex","adaAmount":10000}'

# 5. Run
java --enable-native-access=ALL-UNNAMED \
  -Dzeroj.allowInsecureTrustedSetup=true \
  -jar build/libs/private-voting-*.jar
```

Startup takes ~55 seconds (circuit compilation + trusted setup + voter account creation).

### 6. Open UI: **http://localhost:8086**

## Demo Flow via curl

```bash
# Election is auto-created with 5 voters at startup
# Check election status
curl http://localhost:8086/api/election/status | python3 -m json.tool

# voter1 votes YES
curl -X POST http://localhost:8086/api/vote \
  -H "Content-Type: application/json" \
  -d '{"voterLabel":"voter1","vote":1}'

# voter2 votes NO
curl -X POST http://localhost:8086/api/vote \
  -H "Content-Type: application/json" \
  -d '{"voterLabel":"voter2","vote":0}'

# voter3 votes YES
curl -X POST http://localhost:8086/api/vote \
  -H "Content-Type: application/json" \
  -d '{"voterLabel":"voter3","vote":1}'

# Double vote — rejected!
curl -X POST http://localhost:8086/api/vote \
  -H "Content-Type: application/json" \
  -d '{"voterLabel":"voter1","vote":0}'

# Tally
curl http://localhost:8086/api/results | python3 -m json.tool
# → {yes: 2, no: 1, total: 3}
```

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/election/status` | Election info (voters, root, finalized) |
| POST | `/api/election/create` | Create new election (`name`) |
| POST | `/api/election/register` | Register voter (`label`, `secretKey`) |
| POST | `/api/election/finalize` | Build voter Merkle tree |
| POST | `/api/vote` | Cast vote (`voterLabel`, `vote`: 0=NO, 1=YES) |
| GET | `/api/results` | Tally (yes, no, total, individual votes) |
| GET | `/api/status` | System status (circuit, election, votes) |

## How It Works

Each vote submission:
1. Generates a ZK proof (~13-27s, pure Java BLS12-381 Groth16)
2. Submits a Cardano transaction with two minting policies:
   - **VoteZkMintingPolicy** — verifies the Groth16 proof on-chain
   - **VoteListValidator** — inserts nullifier into sorted linked list
3. The nullifier is deterministic: `Poseidon(secretKey, electionId)` — same voter + same election = same nullifier
4. The commitment `Poseidon(vote, nullifier)` is stored on-chain for tallying

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | Spring Boot 3.5.0-M3 |
| Java | GraalVM 25 |
| ZK Proofs | ZeroJ (Groth16, BLS12-381, pure Java) |
| On-chain | Julc (Java to Plutus V3) |
| Cardano client | cardano-client-lib 0.8.0 |
| Frontend | Svelte 5 + Vite |
| Local devnet | Yaci DevKit |

## Project Structure

```
private-voting/
├── build.gradle
├── src/main/java/.../voting/
│   ├── PrivateVotingApplication.java
│   ├── circuit/PrivateVoteProof.java        # Symbolic annotation ZK circuit
│   ├── config/CardanoConfig.java            # Network config
│   ├── controller/
│   │   ├── ElectionController.java          # Election management API
│   │   └── VoteController.java              # Voting + results API
│   ├── service/
│   │   ├── VoteCircuitService.java          # Circuit compile + prove
│   │   ├── ElectionService.java             # Voter registration + Merkle tree
│   │   ├── AccountSetupService.java         # Test account creation
│   │   ├── OnChainVoteService.java          # On-chain tx building
│   │   ├── TallyService.java               # Vote counting
│   │   └── ProofCompressor.java            # BLS point compression
│   └── onchain/
│       ├── VoteZkMintingPolicy.java         # Groth16 verifier (Plutus V3)
│       ├── VoteListValidator.java           # Sorted linked list (Plutus V3)
│       └── VoteListLib.java                 # List validation logic
├── src/main/resources/
│   ├── application.yml
│   └── static/                              # Built frontend
└── frontend/                                # Svelte 5 + Vite source
```

## Important Notes

- Trusted setup is **dev-only** (single-party). Production requires MPC ceremony.
- Vote privacy: votes are private during voting but can be decoded during tally (commitment = Poseidon(vote, nullifier) with vote in {0,1}). For full tally privacy, a homomorphic scheme is needed.
- Each on-chain nullifier node locks ~2 ADA (reclaimable after election).
- 5 test voters are auto-created at startup with deterministic secret keys.

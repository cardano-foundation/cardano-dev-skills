# Proof of Reserves Demo — ZK Solvency on Cardano

Prove an exchange/custodian holds enough reserves to cover all customer deposits **without revealing individual account balances**. Uses a Merkle Sum Tree + Groth16 ZK proof with on-chain verification.

Built with [ZeroJ](https://github.com/bloxbean/zeroj) — a pure Java ZK toolkit for Cardano.

## What This Demo Does

1. **Register accounts** with balances (simulating customer deposits)
2. **Build Merkle Sum Tree** — each leaf = `Poseidon(accountId, balance)`, root carries total sum
3. **Prove solvency** — ZK proves: reserves >= total liabilities + all balances >= 0
4. **On-chain verification** — Groth16 proof verified via Plutus V3 on Cardano
5. **User inclusion** — individual users verify their balance is in the tree

## Quick Start

```bash
yaci-cli devkit start
sdk use java 25.0.2-graal
cd proof-of-reserves

curl -X POST http://localhost:10000/local-cluster/api/addresses/topup \
  -H "Content-Type: application/json" \
  -d '{"address":"addr_test1qryvgass5dsrf2kxl3vgfz76uhp83kv5lagzcp29tcana68ca5aqa6swlq6llfamln09tal7n5kvt4275ckwedpt4v7q48uhex","adaAmount":10000}'

./gradlew clean bootJar
java --enable-native-access=ALL-UNNAMED \
  -Dzeroj.allowInsecureTrustedSetup=true \
  -jar build/libs/proof-of-reserves-*.jar
```

Open **http://localhost:8089**

The first run creates a local development Groth16 setup cache in `./data/`.
This can take a few minutes for the default depth-4 Merkle circuit. Later runs
reuse the circuit-specific setup cache after checking it matches the current
wire/public-input shape.

To run the gated Yaci DevKit E2E test:

```bash
ZEROJ_YACI_E2E=true ./gradlew test --tests '*ProofOfReservesYaciE2ETest'
```

## Test Scenarios

| Scenario | Reserves | Liabilities | Result |
|----------|----------|------------|--------|
| Solvent | 10,000 ADA | 8,500 ADA | ✅ SOLVENT (on-chain verified) |
| Insolvent | 5,000 ADA | 8,500 ADA | ❌ INSOLVENT (on-chain rejected) |
| User verify | — | — | ✅ Alice's 500 ADA included in tree |

## API

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/reserves/status` | Account count, total liabilities, tree status |
| GET | `/api/reserves/accounts?page=0&size=20` | Paginated account list |
| POST | `/api/reserves/accounts/add` | Add random accounts (`count`) |
| POST | `/api/reserves/build-tree` | Build Merkle Sum Tree |
| POST | `/api/reserves/prove` | Prove solvency (`reservesAda`, `forceOnChain`) |
| GET | `/api/reserves/verify/{accountId}` | Verify individual inclusion |

## How It Works

### Merkle Sum Tree
```
Leaf:   hash = Poseidon(accountId, balance)
Node:   hash = Poseidon(left_hash, right_hash), sum = left_sum + right_sum
Root:   hash = rootHash, sum = total_liabilities
```

### ZK Circuit (SolvencyProof)
Proves in zero knowledge:
1. All account balances are non-negative (64-bit range check)
2. Their Poseidon Merkle tree root matches the published root
3. Their sum equals the published total liabilities
4. Declared reserves >= total liabilities

### On-Chain Verification
- Attestation UTXO with datum: `[totalReserves, liabilitiesRoot, totalLiabilities, isSolvent]`
- Spending validator verifies Groth16 BLS12-381 pairing check
- isSolvent must be 1 (prevents insolvent attestations)

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | Spring Boot 3.5.0-M3, H2 (persistent accounts) |
| ZK Proofs | ZeroJ (Groth16, BLS12-381, pure Java, Groth16SetupCache) |
| On-chain | Julc → Plutus V3 spending validator |
| Frontend | Svelte 5 + Vite |
| Devnet | Yaci DevKit |

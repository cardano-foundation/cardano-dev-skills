# Digital Product Passport Demo — EU DPP with ZK Proofs on Cardano

Prove product compliance with EU ESPR regulations (carbon footprint, recycled content, manufacturing origin, quality inspections) **without revealing commercially sensitive supply chain data**.

Built with [ZeroJ](https://github.com/bloxbean/zeroj) + Cardano's Merkle Patricia Forestry (MPF) with Poseidon hash for ZK-compatible persistent product storage.

## What This Demo Does

1. **Product registry** — products and batches stored in a Poseidon MPF trie (RocksDB, survives restarts, scales to millions)
2. **ZK compliance proofs** — prove "carbon < 50kg", "recycled >= 30%", "made in EU", "3/3 inspections passed" without revealing actual values
3. **Two scenarios**: EV Battery (per-product NFT, high-value) and Textile (per-batch NFT, cost-effective for high volume)
4. **On-chain verification** — Groth16 proof verified via Plutus V3 BLS12-381 on Cardano
5. **Negative cases** — high-carbon battery and non-EU textile show "NOT COMPLIANT"

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Java (GraalVM) | 25 (`sdk install java 25.0.2-graal`) |
| Yaci DevKit | Latest |

## Quick Start

```bash
yaci-cli devkit start
sdk use java 25.0.2-graal
cd digital-product-passport

# Top up admin
curl -X POST http://localhost:10000/local-cluster/api/addresses/topup \
  -H "Content-Type: application/json" \
  -d '{"address":"addr_test1qryvgass5dsrf2kxl3vgfz76uhp83kv5lagzcp29tcana68ca5aqa6swlq6llfamln09tal7n5kvt4275ckwedpt4v7q48uhex","adaAmount":10000}'

./gradlew clean bootJar
java --enable-native-access=ALL-UNNAMED \
  -Dzeroj.allowInsecureTrustedSetup=true \
  -jar build/libs/digital-product-passport-*.jar
```

Open **http://localhost:8088**

## Demo Products

### EV Battery (Per-Product)
| Serial | Carbon (kg) | Recycled (%) | Country | Inspections | Expected |
|--------|------------|-------------|---------|-------------|----------|
| BAT-SN001 | 7 | 45 | DEU (276) | 3/3 | ALL COMPLIANT |
| BAT-SN002 | 12 | 38 | DEU (276) | 3/3 | ALL COMPLIANT |
| BAT-SN003 | 65 | 20 | DEU (276) | 3/3 | carbon FAIL, recycled FAIL |

### Textile Batch (Per-Batch, shared proofs)
| Batch | Units | Carbon/unit | Recycled (%) | Country | Expected |
|-------|-------|------------|-------------|---------|----------|
| TEX-B2024-001 | 100 | 3 | 42 | FRA (250) | ALL COMPLIANT |
| TEX-B2024-002 | 200 | 8 | 65 | FRA (250) | ALL COMPLIANT |
| TEX-B2024-003 | 500 | 15 | 5 | CHN (156) | carbon+recycled+country FAIL |

## API

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dpp/status` | Products, batches, MPF root, thresholds |
| POST | `/api/dpp/verify` | Generate ZK proofs (`id`, `type`: product/batch) |
| POST | `/api/dpp/lock` | Lock ADA at compliance-gated script |
| POST | `/api/dpp/unlock` | Unlock with ZK proof |

## Key Innovation: Poseidon MPF

This demo uses CCL's Merkle Patricia Forestry (`0.8.0-pre5-dev1`) with a **custom PoseidonCommitmentScheme** — replacing Blake2b-256 with Poseidon hash. This makes the MPF root ZK-circuit-verifiable while maintaining all MPF benefits: persistent RocksDB storage, add/remove products, scales to millions.

See [`docs/mpf-architecture.md`](docs/mpf-architecture.md) for the full technical design.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Product storage | MPF + Poseidon + RocksDB (persistent, ZK-compatible) |
| ZK proofs | ZeroJ (Groth16, BLS12-381, pure Java) |
| On-chain | Julc → Plutus V3 spending validator |
| Backend | Spring Boot 3.5.0-M3 |
| Frontend | Svelte 5 + Vite |
| Cardano client | cardano-client-lib 0.8.0-pre5-dev1 |

## ZK Circuits

| Circuit | Claims | Constraints |
|---------|--------|-------------|
| ComplianceThreshold (GTE) | recycled >= 30% | ~1,300 |
| ComplianceThreshold (LTE) | carbon <= 50kg | ~1,300 |
| InspectionChain | 3 inspections in order | ~3,000 |
| CountryMembership | made in EU | ~1,000 |

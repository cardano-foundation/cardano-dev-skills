# Identity KYC Demo — Privacy-Preserving Credential Verification on Cardano

Prove you meet KYC requirements (age, country) **without revealing your personal data**. Uses zero-knowledge proofs (Groth16 on BLS12-381), issuer-signed EdDSA-Jubjub credentials, and on-chain verification via Plutus V3.

Built with [ZeroJ](https://github.com/bloxbean/zeroj) — a pure Java ZK toolkit for Cardano.

## What This Demo Does

1. **Issues KYC credentials** — the KYC provider signs a Poseidon claim digest with EdDSA-Jubjub
2. **Verifies eligibility** — user generates ZK proof: "I have a valid credential AND age >= 18 AND country is approved"
3. **On-chain gated access** — ADA locked at a Plutus V3 script, unlockable only with valid credential proof
4. **5 test users** with different ages/countries (some eligible, some not)

The proof reveals **only** "eligible: YES" or "eligible: NO". Age, country, and identity are never exposed.

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Java (GraalVM) | 25 (`sdk install java 25.0.2-graal`) |
| Yaci DevKit | Latest ([yaci-devkit](https://github.com/bloxbean/yaci-devkit)) |

## Quick Start

```bash
# 1. Start Yaci DevKit
yaci-cli devkit start

# 2. Set Java 25
sdk use java 25.0.2-graal

# 3. Top up admin wallet
curl -X POST http://localhost:10000/local-cluster/api/addresses/topup \
  -H "Content-Type: application/json" \
  -d '{"address":"addr_test1qryvgass5dsrf2kxl3vgfz76uhp83kv5lagzcp29tcana68ca5aqa6swlq6llfamln09tal7n5kvt4275ckwedpt4v7q48uhex","adaAmount":10000}'

# 4. Build
cd identity-kyc
./gradlew clean bootJar

# 5. Run
java --enable-native-access=ALL-UNNAMED \
  -Dzeroj.allowInsecureTrustedSetup=true \
  -jar build/libs/identity-kyc-*.jar
```

Startup time is machine-dependent. The demo compiles an 11,258-constraint circuit and performs a fresh, development-only trusted setup on every start.

### Open UI: **http://localhost:8087**

## Test Users

| Name | Age | Country | minAge=18, approved=[USA,GBR,DEU,FRA,JPN] | Expected |
|------|-----|---------|---------------------------------------------|----------|
| Alice | 25 | USA (840) | age OK, country OK | **ELIGIBLE** |
| Bob | 30 | GBR (826) | age OK, country OK | **ELIGIBLE** |
| Charlie | 16 | USA (840) | age too low | **NOT ELIGIBLE** |
| Diana | 22 | BRA (76) | country not approved | **NOT ELIGIBLE** |
| Eve | 45 | JPN (392) | age OK, country OK | **ELIGIBLE** |

## Demo Flow via curl

```bash
# Check users and credentials
curl http://localhost:8087/api/credential/status | python3 -m json.tool

# Verify Alice (eligible) — generates ZK proof
curl -X POST http://localhost:8087/api/credential/verify \
  -H "Content-Type: application/json" -d '{"name":"Alice"}'

# Verify Charlie (underage — not eligible)
curl -X POST http://localhost:8087/api/credential/verify \
  -H "Content-Type: application/json" -d '{"name":"Charlie"}'

# Lock 5 ADA at credential-gated script
curl -X POST http://localhost:8087/api/credential/lock \
  -H "Content-Type: application/json" -d '{"adaAmount":5}'

# Verify Alice first, then unlock
curl -X POST http://localhost:8087/api/credential/verify \
  -H "Content-Type: application/json" -d '{"name":"Alice"}'
curl -X POST http://localhost:8087/api/credential/unlock \
  -H "Content-Type: application/json" -d '{"name":"Alice"}'
```

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/credential/status` | List users, credentials, locked UTXOs |
| POST | `/api/credential/verify` | Generate ZK proof for a user (`name`) |
| POST | `/api/credential/lock` | Lock ADA at gated script (`adaAmount`) |
| POST | `/api/credential/unlock` | Unlock with ZK proof (`name`) |

## How It Works

**Credential issuance** (demo/offline compatibility signer):
```
field     = Poseidon(age, country)
message   = JubjubMessage.fromCanonicalFieldBytes(BE32(field))
signature = EdDSAJubjub.signCompatibilityOffline(issuerKeypair, message)
```
The issuer keeps the secret key. The holder receives `age`, `country`, and
the signature; no issuer secret is shared with the holder.

**ZK proof generation** (11,258 constraints):
1. Verify the EdDSA-Jubjub signature over `Poseidon(age, country)`
2. Age check: `age >= minAge` (8-bit comparison)
3. Country check: Merkle proof that `country` is in the approved list
4. Output: `eligible = 1` if all checks pass

**On-chain verification**:
- ADA locked at `CredentialGatedValidator` script address
- Redeemer contains compressed Groth16 proof + public inputs
- Validator does the BLS12-381 pairing check, requires `eligible == 1`,
  and pins the issuer public key, minimum age, and approved-country root
  to script parameters
- If valid, funds are released

## Key Difference from NFT/Voting Demos

This demo is **stateless** — no nullifiers, no linked list. The proof can be reused for ongoing DeFi access. This is appropriate for KYC where you want to prove eligibility repeatedly, not one-time access.

| Pattern | NFT Ownership | Private Voting | Identity KYC |
|---------|--------------|----------------|--------------|
| On-chain | Sorted linked list | Sorted linked list | Spending validator |
| Nullifiers | Yes (one-time use) | Yes (one vote) | No (reusable) |
| Proof reuse | No | No | **Yes** |
| Complexity | High | High | **Simple** |

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | Spring Boot 3.5.0-M3 |
| Java | GraalVM 25 |
| ZK Proofs | ZeroJ (Groth16, BLS12-381, pure Java) |
| On-chain | Julc (Java to Plutus V3) |
| Credential signing | EdDSA-Jubjub over a Poseidon claim digest |
| Frontend | Svelte 5 + Vite |
| Local devnet | Yaci DevKit |

## Project Structure

```
identity-kyc/
├── src/main/java/.../identity/
│   ├── IdentityKycApplication.java
│   ├── circuit/CredentialProof.java           # Symbolic annotation ZK circuit
│   ├── config/CardanoConfig.java
│   ├── controller/CredentialController.java   # REST API
│   ├── service/
│   │   ├── CredentialService.java             # Circuit + prover
│   │   ├── IssuerService.java                 # Credential issuance
│   │   ├── OnChainCredentialService.java      # Lock/unlock on-chain
│   │   └── ProofCompressor.java
│   └── onchain/
│       └── CredentialGatedValidator.java      # Spending validator
├── frontend/                                   # Svelte 5 + Vite
└── README.md
```

## Notes

- The seeded credentials use ZeroJ's explicit compatibility/offline signer.
  Do not expose this demo issuance method as a network-reachable signing API.
- Trusted setup is single-party and development-only. Production requires
  reviewed ceremony material and an external cryptographic review.
- The on-chain validator is registered-key mode: the script parameters bind
  both issuer coordinates and the policy values. Changing the issuer, minimum
  age, or country root creates a different script.

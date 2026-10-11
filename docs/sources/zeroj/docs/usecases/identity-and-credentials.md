# ZK Identity & Credentials on Cardano — Detailed Design

Prove who you are (or what you're authorized to do) without revealing your identity.

## Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [Use Cases Beyond KYC](#use-cases-beyond-kyc)
- [How ZK Credentials Work](#how-zk-credentials-work)
- [Credential Lifecycle](#credential-lifecycle)
- [Three Credential Approaches](#three-credential-approaches)
  - [Approach 1: Custom ZK Credential (Poseidon-Signed)](#approach-1-custom-zk-credential-poseidon-signed)
  - [Approach 2: EdDSA-Signed Credential (W3C VC Compatible)](#approach-2-eddsa-signed-credential-w3c-vc-compatible)
  - [Approach 3: BBS+ Selective Disclosure (Advanced)](#approach-3-bbs-selective-disclosure-advanced)
- [Credential Revocation on Cardano](#credential-revocation-on-cardano)
  - [Option A: Expiry Timestamp](#option-a-expiry-timestamp)
  - [Option B: Revocation Merkle Tree](#option-b-revocation-merkle-tree)
  - [Option C: Validity Credential (Recommended)](#option-c-validity-credential-recommended)
- [On-Chain Design: Cardano UTXO Patterns](#on-chain-design-cardano-utxo-patterns)
  - [Issuer Registry](#issuer-registry)
  - [Credential-Gated Access](#credential-gated-access)
  - [One-Time vs Reusable Proofs](#one-time-vs-reusable-proofs)
- [Smart Contract Code (Julc)](#smart-contract-code-julc)
- [Full Transaction Flow](#full-transaction-flow)
- [W3C Verifiable Credentials Compatibility](#w3c-verifiable-credentials-compatibility)
- [Atala PRISM Integration](#atala-prism-integration)
- [Approach Comparison](#approach-comparison)
- [Security Considerations](#security-considerations)
- [CircuitSpec Implementation](#circuitspec-implementation)
- [Architecture Recommendation](#architecture-recommendation)

---

## Overview

A DeFi protocol needs to verify that a user meets certain requirements (age, residency, accreditation, membership) before allowing them to interact with a smart contract. Today, this means sharing sensitive personal data with every protocol. With ZK credentials, the user proves they meet the requirements **without revealing any personal data**.

This design applies to any scenario where someone needs to prove authorization:

```
Traditional:   "Here's my passport, credit score, and bank statements"
               → Protocol sees everything, stores it, can leak it

With ZK:       "Here's a 192-byte proof that I'm eligible"
               → Protocol sees only: eligible = YES
               → No personal data on-chain, no data to leak
```

## The Problem

### For KYC/Compliance

Regulated DeFi protocols need to verify users meet requirements. Current approaches:

| Approach | Privacy | Centralization | Cost |
|----------|---------|---------------|------|
| Upload documents to protocol | None — full data exposure | Protocol holds your data | Free but risky |
| Third-party KYC (Fractal, Synaps) | Partial — KYC provider sees data | KYC provider is single point of failure | $1-5 per verification |
| On-chain identity (soul-bound NFT) | None — publicly linked | Issuer controls | Variable |
| **ZK credential proof** | **Full — only eligibility revealed** | **Issuer signs, user proves, nobody stores** | **~0.5 ADA tx fee** |

### For General Authorization

The same problem extends beyond KYC:

- **DAO membership**: Prove you're a member without revealing which member
- **Age-gated content**: Prove you're over 18 without revealing your birthday
- **Accredited investor**: Prove qualification without revealing net worth
- **Employee access**: Prove you work at Company X without revealing your role
- **Jurisdiction check**: Prove you're in an allowed country without revealing which one
- **Credit eligibility**: Prove your score is above a threshold without revealing the exact score

## Use Cases Beyond KYC

| Use Case | Issuer | What's Proven | What's Hidden |
|----------|--------|--------------|---------------|
| **KYC/AML** | KYC provider | "Eligible for DeFi" | Name, age, address, documents |
| **Age verification** | Government | "Age >= 18" | Exact age, birthday, name |
| **Accredited investor** | Financial institution | "Net worth >= $1M" | Exact net worth, assets |
| **DAO membership** | DAO contract | "I'm a member" | Which member (anonymous voting) |
| **Employee access** | Company HR | "I work at Acme Corp" | Name, role, salary |
| **License/certification** | Certification body | "I hold credential X" | Name, issue date, details |
| **Jurisdiction** | Government / geo-IP | "I'm in EU" | Exact country |
| **Credit score** | Credit bureau | "Score >= 700" | Exact score, history |
| **Sanctions check** | Compliance provider | "I'm NOT sanctioned" | Identity |

**Key insight**: All of these share the same ZK pattern:
1. A **trusted issuer** signs a credential with specific claims
2. The **holder** generates a ZK proof about specific claims
3. The **verifier** (on-chain smart contract) checks the proof — sees only the public outputs

## How ZK Credentials Work

### The Data Flow

```
┌──────────────┐         ┌──────────────┐         ┌──────────────────┐
│   ISSUER      │         │   HOLDER      │         │   VERIFIER        │
│ (KYC provider,│         │ (user)        │         │ (smart contract,  │
│  government,  │         │               │         │  DeFi protocol)   │
│  enterprise)  │         │               │         │                   │
│               │         │               │         │                   │
│ 1. Verify     │         │               │         │                   │
│    identity   │         │               │         │                   │
│    off-chain  │         │               │         │                   │
│               │         │               │         │                   │
│ 2. Sign       │  cred   │               │         │                   │
│    credential ├────────▶│ 3. Store      │         │                   │
│    (EdDSA/    │         │    credential │         │                   │
│     Poseidon) │         │    locally    │         │                   │
│               │         │               │         │                   │
│               │         │ 4. Generate   │  proof   │                   │
│               │         │    ZK proof   ├────────▶│ 5. Verify proof   │
│               │         │    (selective │         │    on-chain       │
│               │         │     disclosure)│        │    (pairing check)│
│               │         │               │         │                   │
│               │         │               │         │ 6. Grant access   │
│               │         │               │         │    or reject      │
└──────────────┘         └──────────────┘         └──────────────────┘

What's on-chain: proof (192 bytes) + public outputs (eligible: YES/NO)
What's NOT on-chain: name, age, address, documents, credential details
```

### What Each Party Knows

| Data | Issuer | Holder | Verifier | Public |
|------|--------|--------|----------|--------|
| Full identity (name, DOB, etc.) | Yes | Yes | **No** | **No** |
| Credential claims (age=25, country=DE) | Yes | Yes | **No** | **No** |
| Issuer's signature | Yes | Yes | **No** | **No** |
| Issuer's public key | Yes | Yes | Yes | Yes |
| "Is eligible" (boolean) | N/A | Yes | Yes | Yes |
| ZK proof (192 bytes) | N/A | Yes | Yes | Yes |

## Credential Lifecycle

```
┌────────────────────────────────────────────────────────────────────┐
│ 1. ISSUANCE (off-chain, one-time per credential)                  │
│                                                                    │
│    Issuer verifies identity (KYC check, document review, etc.)    │
│    Issuer creates credential:                                      │
│      claims = { age: 25, country: "DE", tier: "accredited" }      │
│      signature = sign(issuerSecretKey, hash(claims))               │
│    Issuer sends credential to holder (encrypted, off-chain)       │
│                                                                    │
│    Issuer publishes: public key (on-chain or well-known)          │
│    Issuer does NOT publish: credential or holder identity          │
│                                                                    │
└────────────────────────────┬───────────────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│ 2. STORAGE (holder's device)                                       │
│                                                                    │
│    Holder stores credential in wallet / secure storage             │
│    Credential contains: claims + issuer signature                  │
│    Holder can generate unlimited proofs from this credential       │
│                                                                    │
└────────────────────────────┬───────────────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│ 3. PROOF GENERATION (holder's device, per interaction)             │
│                                                                    │
│    For each DeFi interaction:                                      │
│      1. Protocol specifies requirements (e.g., "age >= 18")       │
│      2. Holder selects which claims to prove (selective disclosure)│
│      3. Holder generates ZK proof on their device                 │
│      4. Proof reveals only: issuer pubkey + "eligible: YES"        │
│                                                                    │
│    Different protocols can have different requirements —            │
│    holder uses SAME credential with DIFFERENT proofs               │
│                                                                    │
└────────────────────────────┬───────────────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│ 4. VERIFICATION (on-chain, per transaction)                        │
│                                                                    │
│    Smart contract checks:                                          │
│      ✓ ZK proof is valid (BLS12-381 pairing check)                │
│      ✓ Issuer public key is in the trusted issuer registry        │
│      ✓ Credential is not revoked (revocation check)               │
│      ✓ Requirements are met (public outputs)                      │
│    → Transaction proceeds or is rejected                           │
│                                                                    │
└────────────────────────────┬───────────────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│ 5. REVOCATION (issuer-initiated, when needed)                      │
│                                                                    │
│    If a credential is compromised, expired, or holder is banned:  │
│      Issuer adds credential nullifier to revocation registry       │
│      Future proofs against revoked credentials fail                │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Three Credential Approaches

### Approach 1: Custom ZK Credential (Poseidon-Signed)

The simplest approach — credential claims are field elements, "signed" via Poseidon hash with a shared secret.

**How it works**: The issuer and holder share a secret. The credential is a Poseidon hash of (secret + claims). To prove a claim, the holder proves they know the secret that produces the credential hash.

```
Credential = Poseidon(issuerSecret, Poseidon(age, country, tier))
```

**Circuit**:

```java
public class PoseidonCredentialCircuit implements CircuitSpec {
    private final int approvedCountriesDepth;

    public PoseidonCredentialCircuit(int depth) { this.approvedCountriesDepth = depth; }

    @Override
    public void define(SignalBuilder c) {
        // Secret inputs
        Signal credentialSecret = c.privateInput("credentialSecret");
        Signal age              = c.privateInput("age");
        Signal country          = c.privateInput("country");

        // Public inputs
        Signal credentialHash   = c.publicInput("credentialHash");
        Signal minAge           = c.publicInput("minAge");
        Signal countryRoot      = c.publicInput("countryRoot");

        // Public output
        Signal eligible         = c.publicOutput("eligible");

        // Merkle proof for country (secret)
        Signal[] siblings = new Signal[approvedCountriesDepth];
        Signal[] pathBits = new Signal[approvedCountriesDepth];
        for (int i = 0; i < approvedCountriesDepth; i++) {
            siblings[i] = c.privateInput("countrySibling_" + i);
            pathBits[i] = c.privateInput("countryPath_" + i);
        }

        // 1. Verify credential: hash(secret, hash(age, country)) == credentialHash
        Signal claimsHash = SignalPoseidon.hash(c, age, country);
        c.assertEqual(SignalPoseidon.hash(c, credentialSecret, claimsHash), c.signal("credentialHash"));

        // 2. Age check: age >= minAge
        Signal ageOk = SignalComparators.greaterOrEqual(c, age, c.signal("minAge"), 64);

        // 3. Country check: country is in approved set
        SignalMerkle.verifyProof(c, country, c.signal("countryRoot"),
                siblings, pathBits, SignalPoseidon::hash);

        // 4. All checks passed
        c.assertEqual(eligible, ageOk);
    }
}
```

| Pros | Cons |
|------|------|
| **~1,000 constraints** (very efficient) | Shared secret — issuer can impersonate holder |
| No EdDSA needed (works with current ZeroJ stdlib) | No standard compatibility (not W3C VC) |
| Simple to implement and audit | Issuer must be online for issuance |
| ZK-native (Poseidon is optimal in circuits) | Can't prove "signed by issuer X" to third party |

**Best for**: Closed systems where the issuer and verifier are the same entity (e.g., a single DeFi protocol that runs its own KYC).

**Constraints**: ~1,000 (Poseidon hashes + range check + Merkle proof)

### Approach 2: EdDSA-Signed Credential (W3C VC Compatible)

The issuer signs the credential with EdDSA on BabyJubJub. The holder proves they have a valid signature without revealing the credential.

**How it works**: Standard public-key cryptography. The issuer's public key is published. The holder proves they possess a credential signed by that key.

```
Credential:
  claims = { age: 25, country: "DE" }
  message = Poseidon(age, country, nonce)
  signature = EdDSA.sign(issuerPrivateKey, message)

Proof: "I know (claims, signature) such that
        EdDSA.verify(issuerPubKey, signature, message) = true
        AND age >= 18
        AND country ∈ approvedCountries"
```

**Circuit**:

```java
public class EdDSACredentialCircuit implements CircuitSpec {
    private final int countryTreeDepth;

    public EdDSACredentialCircuit(int depth) { this.countryTreeDepth = depth; }

    @Override
    public void define(SignalBuilder c) {
        // Public inputs
        Signal issuerPubKeyX = c.publicInput("issuerPubKeyX");
        Signal issuerPubKeyY = c.publicInput("issuerPubKeyY");
        Signal minAge        = c.publicInput("minAge");
        Signal countryRoot   = c.publicInput("countryRoot");

        // Public output
        Signal eligible      = c.publicOutput("eligible");

        // Secret inputs (credential)
        Signal age           = c.privateInput("age");
        Signal country       = c.privateInput("country");
        Signal nonce         = c.privateInput("nonce");

        // Secret inputs (EdDSA signature)
        Signal sigRx         = c.privateInput("sigRx");
        Signal sigRy         = c.privateInput("sigRy");
        Signal sigS          = c.privateInput("sigS");

        // Secret inputs (Merkle proof for country)
        Signal[] siblings = new Signal[countryTreeDepth];
        Signal[] pathBits = new Signal[countryTreeDepth];
        for (int i = 0; i < countryTreeDepth; i++) {
            siblings[i] = c.privateInput("countrySibling_" + i);
            pathBits[i] = c.privateInput("countryPath_" + i);
        }

        // 1. Compute message hash from claims
        Signal claimsHash = PoseidonN.hash(c, age, country, nonce);

        // 2. Verify EdDSA signature (BabyJubJub)
        //    EdDSA.verify(pubKey, signature, message)
        //    ~3000 constraints (two scalar multiplications + hash + point addition)
        // (Requires BabyJubJub stdlib — currently removed, to be re-added with hardening)

        // 3. Age check
        Signal ageOk = SignalComparators.greaterOrEqual(c, age, c.signal("minAge"), 64);

        // 4. Country check (Merkle membership)
        SignalMerkle.verifyProof(c, country, c.signal("countryRoot"),
                siblings, pathBits, SignalPoseidon::hash);

        // 5. Output
        c.assertEqual(eligible, ageOk);
    }
}
```

| Pros | Cons |
|------|------|
| **Proper digital signature** — issuer can't impersonate holder | ~4,000 constraints (heavier) |
| **W3C VC compatible** (EdDSA is a standard proof type) | Requires BabyJubJub + EdDSA in stdlib (not yet production-ready) |
| Issuer's public key is verifiable by anyone | EdDSA circuit needs security hardening (subgroup checks) |
| Standard pattern (used by Semaphore, WorldID) | More complex issuance flow |

**Best for**: Multi-issuer ecosystems where credentials from different issuers need to be verified by different protocols.

**Constraints**: ~4,000 (EdDSA verify + Poseidon hashes + range check + Merkle proof)

### Approach 3: BBS+ Selective Disclosure (Advanced)

BBS+ signatures allow the holder to selectively disclose individual claims from a multi-claim credential without revealing the others — built into the signature scheme itself.

```
Issuer signs: BBS+.sign(issuerKey, [age, country, name, address, tier])

Holder proves: "I have a valid BBS+ signature on 5 claims,
               and claim[0] (age) >= 18,
               without revealing claims 2, 3, 4 (name, address, tier)"

Selective: The holder chooses WHICH claims to reveal per proof.
           Same credential, different proofs for different verifiers.
```

| Pros | Cons |
|------|------|
| **Native selective disclosure** — no extra circuit logic | ~1,200 constraints for signature, but complex pairing math |
| **W3C standard** (`bbs-2023` cryptosuite) | BBS+ circuit requires in-circuit pairing operations |
| Multiple claims in one credential | Not yet implemented in any ZK circuit library |
| Most privacy-preserving | Most complex to implement and audit |

**Best for**: Future — when BBS+ circuit implementations mature. Currently the most privacy-preserving but also the most complex.

**Constraints**: ~1,200 for signature verification + claim-specific constraints

## Credential Revocation on Cardano

When a credential is compromised, expired, or the holder's status changes, the issuer needs to revoke it. On Cardano's UTXO model, revocation has unique challenges.

### Option A: Expiry Timestamp

The simplest approach — credential includes an expiry time, checked in the circuit.

```
Credential: { age: 25, country: "DE", expiresAt: 1735689600 }  // 2025-01-01

Circuit proves: currentSlot < expiresAt
```

```java
// In the circuit:
Signal expiresAt = c.privateInput("expiresAt");
Signal currentSlot = c.publicInput("currentSlot");

// Credential hasn't expired
Signal notExpired = SignalComparators.greaterThan(c, expiresAt, currentSlot, 64);
c.assertEqual(notExpired, c.constant(1));
```

| Pros | Cons |
|------|------|
| Zero on-chain revocation infrastructure | Can't revoke before expiry |
| Simple circuit (1 comparison) | Must reissue frequently for short validity |
| No UTXO contention | Compromised credential valid until expiry |

**Best for**: Low-risk credentials with short validity (e.g., 24-hour session tokens).

### Option B: Revocation Merkle Tree

The issuer maintains a Merkle tree of revoked credential IDs. The circuit proves the credential is NOT in the revocation tree.

```
Revocation tree: Merkle tree of revoked credential hashes
  Root published on-chain (periodically updated by issuer)

Circuit proves: "My credential hash is NOT in the revocation tree"
  → Non-membership proof via sorted Merkle tree
```

**On Cardano**: The revocation root is stored in a single UTXO updated by the issuer:

```
Revocation UTXO:
  Address: revocationValidator
  Datum: { issuer: "did:prism:xyz", revocationRoot: 0x5678..., epoch: 42 }
```

The proof circuit references this root as a public input. The smart contract verifies the root matches the latest on-chain revocation UTXO.

| Pros | Cons |
|------|------|
| Instant revocation (issuer updates root) | Issuer must update root on-chain (single UTXO) |
| Non-membership proof is efficient (~7K constraints) | Off-chain revocation tree service needed |
| Proven pattern (used by iden3, Polygon ID) | Revocation tx has contention if many issuers |

**Best for**: Medium-risk credentials where timely revocation matters (e.g., accredited investor status).

### Option C: Validity Credential (Recommended)

Instead of revoking the credential itself, the issuer periodically issues a **validity attestation** — a short-lived token that says "this credential is still valid as of epoch X."

```
Original credential: { age: 25, country: "DE" }  (long-lived, signed once)
Validity attestation: { credentialHash: 0xABC, validUntilEpoch: 50 }  (short-lived, refreshed)

Circuit proves:
  1. I have a valid credential (signature check)
  2. I have a validity attestation for this credential
  3. The attestation hasn't expired (validUntilEpoch >= currentEpoch)
```

**On Cardano**: The validity attestation root is a Merkle tree of all currently-valid credential hashes:

```
Validity UTXO:
  Address: validityValidator
  Datum: { issuer: "did:prism:xyz", validRoot: 0x9ABC..., epoch: 42 }

Issuer updates this every epoch (every 5 days on Cardano).
Only valid credentials are in the tree.
Revoked credentials are simply removed from the tree in the next update.
```

| Pros | Cons |
|------|------|
| **Simple revocation** — just stop including in validity tree | Holder must refresh attestation periodically |
| **Positive attestation** — proves validity, not non-revocation | Issuer must maintain and publish tree |
| No non-membership proofs (simpler circuit) | Slight delay between revocation and effect |
| Natural expiry (attestation expires if not refreshed) | Requires off-chain validity tree service |

**Best for**: Production systems where revocation timeliness of ~1 epoch (5 days) is acceptable.

## On-Chain Design: Cardano UTXO Patterns

### Issuer Registry

A registry of trusted issuers — which public keys are trusted for credential issuance.

```
Issuer Registry UTXO:
  Address: issuerRegistryValidator
  Datum: {
    issuers: [
      { name: "FractalKYC", pubKey: 0x1234..., credType: "kyc" },
      { name: "GovID",      pubKey: 0x5678..., credType: "age" },
      { name: "AccredCorp", pubKey: 0x9ABC..., credType: "investor" }
    ]
  }
```

**Governance**: Who can add/remove issuers? Options:
- **Multi-sig** — N-of-M trusted parties
- **DAO vote** — token holders decide
- **Protocol admin** — single admin key (centralized but simple)

### Credential-Gated Access

A DeFi protocol gates access via ZK credential proof:

```
Protocol UTXO:
  Address: protocolValidator
  Datum: {
    requiredCredType: "kyc",
    trustedIssuers: [0x1234..., 0x5678...],
    minAge: 18,
    approvedCountriesRoot: 0xDEAD...
  }

User transaction:
  Redeemer: ZK proof (192 bytes) + public inputs
  → Validator checks proof, grants access
```

### One-Time vs Reusable Proofs

**One-time proof** (with nullifier):
```
Each proof generates a unique nullifier.
The protocol records it — prevents using the same proof twice.
Use case: one-time airdrop claim, one-vote-per-person.
```

**Reusable proof** (no nullifier):
```
The same proof can be submitted multiple times.
No nullifier tracking needed.
Use case: ongoing DeFi access, repeated interactions.
Note: the verifier knows it's the same proof (same bytes), but
      can't link it to an identity.
```

**Session-based proof** (nullifier per epoch):
```
Nullifier includes epoch: nullifier = Poseidon(secret, epoch)
Each epoch generates a new nullifier.
Use case: daily attestation, subscription-based access.
```

## Smart Contract Code (Julc)

### Credential-Gated DeFi Access

```java
@SpendingValidator
public class CredentialGatedProtocol {

    // Groth16 VK for credential proof verification
    @Param static byte[] vkAlpha;
    @Param static byte[] vkBeta;
    @Param static byte[] vkGamma;
    @Param static byte[] vkDelta;
    @Param static PlutusData vkIc;

    // Trusted issuer public key (baked at deploy)
    @Param static byte[] trustedIssuerPubKey;

    record CredentialProof(
        byte[] piA, byte[] piB, byte[] piC,
        BigInteger eligible         // public output from ZK circuit
    ) {}

    @Entrypoint
    static boolean validate(PlutusData datum, CredentialProof proof, PlutusData ctx) {
        // 1. Verify Groth16 ZK proof (BLS12-381 pairing check)
        //    Public inputs: issuerPubKey, minAge, countryRoot, eligible
        boolean proofValid = verifyGroth16(
            proof.piA(), proof.piB(), proof.piC(),
            trustedIssuerPubKey,
            proof.eligible());

        // 2. Check that the proof says "eligible = 1"
        boolean isEligible = proof.eligible().equals(BigInteger.ONE);

        // 3. (Optional) Check reference input for revocation registry
        //    The circuit already checks non-revocation, but we can
        //    additionally verify the revocation root matches on-chain state

        return proofValid && isEligible;
    }
}
```

## Full Transaction Flow

### Setup (Protocol Deployer)

```
1. Choose credential type and requirements:
   - credType: "kyc"
   - minAge: 18
   - approvedCountries: [US, EU, UK, ...]

2. Build approved countries Merkle tree → countryRoot

3. Compile credential circuit:
   var circuit = PoseidonCredentialCircuit.build(20);
   var r1cs = circuit.compileR1CS(CurveId.BLS12_381);

4. Trusted setup (MPC ceremony for production)

5. Deploy CredentialGatedProtocol with VK baked in

6. Deploy issuer registry (or use existing one)
```

### Credential Issuance (Off-Chain)

```
1. User completes KYC with issuer (off-chain)
2. Issuer verifies: age=25, country=DE, tier=accredited
3. Issuer creates credential:
   secret = randomFieldElement()
   credentialHash = Poseidon(secret, Poseidon(25, countryCode_DE))
4. Issuer sends to user: { secret, age: 25, country: DE, credentialHash }
5. User stores credential in wallet

   Nothing on-chain yet. Issuer doesn't need a transaction.
```

### User Accesses DeFi Protocol (On-Chain)

```
1. User reads protocol requirements: minAge=18, countryRoot=0xDEAD...
2. User generates Merkle proof for their country (from public country tree)
3. User generates ZK proof on their device (pure Java, ~2 seconds)
4. User submits transaction:

   Transaction:
     Input:  User's wallet UTXO
     Input:  Protocol UTXO (to interact with)
     Redeemer: { piA, piB, piC, eligible: 1 }
     Output: Protocol interaction result

   On-chain:
     ✓ ZK proof valid (BLS12-381 pairing check)
     ✓ eligible == 1
     → Transaction succeeds. User accesses protocol.

   The protocol NEVER sees: user's age, country, name, or credential details.
```

## W3C Verifiable Credentials Compatibility

The ZK credential approach is compatible with W3C VC standards:

### W3C VC Data Model

```json
{
  "@context": ["https://www.w3.org/ns/credentials/v2"],
  "type": ["VerifiableCredential", "KYCCredential"],
  "issuer": "did:prism:issuer123",
  "credentialSubject": {
    "age": 25,
    "country": "DE",
    "tier": "accredited"
  },
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "eddsa-jcs-2022",
    "verificationMethod": "did:prism:issuer123#key-1",
    "proofValue": "z3FcC..."
  }
}
```

### Mapping to ZK Circuit

| W3C VC Field | ZK Circuit Role |
|-------------|----------------|
| `issuer` | Public input: issuerPubKey |
| `credentialSubject.age` | Private input: age |
| `credentialSubject.country` | Private input: country |
| `proof.proofValue` | Private input: issuerSignature |
| *Protocol requirement* | Public input: minAge, countryRoot |
| *Proof output* | Public output: eligible (YES/NO) |

The W3C VC is the **off-chain credential format**. The ZK circuit is the **on-chain verification mechanism**. They complement each other — W3C VC for interoperability, ZK for privacy.

## Atala PRISM Integration

Atala PRISM is Cardano's native identity platform. ZK credentials can integrate with PRISM:

```
PRISM DID → credential issuance (off-chain)
PRISM credential → ZK proof generation (on device)
ZK proof → on-chain verification (Plutus V3)
```

**How**: PRISM issues credentials using standard EdDSA signatures. The ZK circuit verifies the PRISM issuer's signature and proves claims without revealing the credential.

**Integration point**: PRISM's DID resolution provides the issuer's public key. The ZK circuit uses this public key as a public input.

## Approach Comparison

| | Poseidon-Signed | EdDSA-Signed | BBS+ |
|---|---|---|---|
| **Constraints** | **~1,000** | ~4,000 | ~1,200 |
| **Issuer trust** | Shared secret (can impersonate) | **Public key (standard)** | **Public key (standard)** |
| **Selective disclosure** | Per-circuit (choose which claims to prove) | Per-circuit | **Native** (built into signature) |
| **W3C VC compatible** | No | **Yes** | **Yes** |
| **Revocation** | Any method | Any method | Accumulator-friendly |
| **Implementation complexity** | **Low** | Medium (needs BabyJubJub) | High (needs pairing in circuit) |
| **ZeroJ readiness** | **Ready today** | Needs EdDSA stdlib | Future |
| **Best for** | Single-issuer systems | **Multi-issuer ecosystems** | Maximum privacy |

## Security Considerations

### Credential Replay

Without a nullifier, the same proof can be replayed. Solutions:
- Include a **nonce** (transaction hash) in the public inputs
- Use **session-based nullifiers** (nullifier = Poseidon(secret, epoch))
- Use **one-time nullifiers** for sensitive operations

### Issuer Compromise

If the issuer's private key is compromised:
- All credentials signed by that key are potentially forged
- **Mitigation**: Key rotation — issuer registry allows updating the public key
- **Mitigation**: Short-lived validity attestations (credential expires even if key is stolen)

### Credential Sharing

A holder can share their credential secret with someone else, who can then generate proofs. This is inherent to ZK credentials — the "proof of knowledge" proves knowledge, not identity.

**Mitigation**: Bind the credential to a biometric or hardware key (not implementable in ZK alone, requires trusted hardware).

### Timing Correlation

If a user generates a credential proof and submits a DeFi transaction in the same block, an observer might correlate them. **Mitigation**: Use a relayer (same pattern as private token transfer).

## CircuitSpec Implementation

The Poseidon-signed approach works with ZeroJ today:

```java
// Build the circuit
var circuit = PoseidonCredentialCircuit.build(10);  // depth 10 = 1024 countries

// Compile for BLS12-381
var r1cs = circuit.compileR1CS(CurveId.BLS12_381);
// ~1,000 constraints

// Setup (local dev requires -Dzeroj.allowInsecureTrustedSetup=true;
// production: MPC ceremony)
var srs = PowersOfTauBLS381.generate(10);
var setup = Groth16SetupBLS381.setup(constraints, numWires, numPublic, srs.tauScalar());

// Prove (on user's device, pure Java)
var witness = circuit.calculateWitness(Map.of(
    "credentialSecret", List.of(mySecret),
    "age", List.of(BigInteger.valueOf(25)),
    "country", List.of(countryFieldElement),
    "credentialHash", List.of(myCredentialHash),
    "minAge", List.of(BigInteger.valueOf(18)),
    "countryRoot", List.of(approvedCountriesRoot),
    "eligible", List.of(BigInteger.ONE),
    // ... Merkle siblings and path bits
), CurveId.BLS12_381);

var proof = Groth16ProverBLS381.prove(setup.provingKey(), witness, constraints, numWires);

// Submit to Cardano (192 bytes proof)
var compressed = ProverToCardano.compressProof(proof);
```

## Architecture Recommendation

### For Today (Poseidon-Signed — works now)

Use the Poseidon-signed approach for single-issuer systems:
- DeFi protocol runs its own KYC
- Issues Poseidon-signed credentials to verified users
- Users prove eligibility on-chain with ~1,000-constraint circuit
- **Ready to build today** with existing ZeroJ stdlib

### For Multi-Issuer (EdDSA — needs BabyJubJub hardening)

When BabyJubJub + EdDSA are re-added with subgroup checks:
- Multiple KYC providers issue EdDSA-signed credentials
- Users prove eligibility from any trusted issuer
- Standard W3C VC compatible
- ~4,000-constraint circuit

### For Maximum Privacy (BBS+ — future)

When BBS+ circuits are available:
- Native selective disclosure (choose which claims per proof)
- One credential serves multiple verifiers with different requirements
- W3C `bbs-2023` standard
- ~1,200-constraint signature + claim constraints

### Upgrade Path

All three approaches use the same on-chain verifier (`Groth16BLS12381Verifier`). The circuit changes, but the Plutus V3 script shape is identical. You can upgrade from Poseidon-signed to EdDSA to BBS+ without writing a custom on-chain verifier; redeployment is only needed when the verification key changes.

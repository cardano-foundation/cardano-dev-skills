# Identity KYC with EdDSA-Jubjub — Tutorial

This demo shows how to build a **privacy-preserving KYC credential system**
on Cardano using ZK-SNARKs, with asymmetric EdDSA-Jubjub signatures. A
holder proves they hold an issuer-signed credential that
satisfies policy rules (age ≥ minAge, country ∈ approved set) — without
revealing age, country, or the signature itself.

## 1. What changed vs. the Poseidon-MAC version?

Previously the credential was `Poseidon(issuerSecret, Poseidon(age, country))`
— a shared-secret MAC. Issuer and holder both knew `issuerSecret`. Anyone
with the secret could forge credentials, and there was no way to interop
with W3C VC / DID / Atala PRISM.

Now the credential is a genuine digital signature: the issuer holds a
**Jubjub private key `sk`**, publishes `pk = [sk]·G`, and signs each
credential with EdDSA:

```
message   = JubjubMessage.fromCanonicalFieldBytes(BE32(Poseidon(age, country)))
signature = EdDSAJubjub.signCompatibilityOffline(keypair, message)
```

The holder gets `(age, country, signature)`. The secret `sk` never leaves
the issuer. The signature is what the ZK proof will verify inside the
circuit.

## 2. Components at a glance

```
 ┌────────────┐           ┌────────────┐           ┌────────────────┐
 │  Issuer    │  issues   │  Holder    │  proves   │ Cardano Plutus │
 │  (Alice…)  │──────────▶│  (client)  │──────────▶│   validator    │
 │            │  (age,    │            │  Groth16  │                │
 │  sk, pk    │   country,│  age, cty, │  BLS12-   │  verify proof  │
 │  (Jubjub)  │   sig)    │  sig       │  381 proof│  w/ pk public  │
 └────────────┘           └────────────┘           └────────────────┘
```

- **IssuerService** (this app): holds `sk`, issues signed credentials, runs
  the approved-countries Merkle tree.
- **CredentialService** (this app): compiles the circuit, runs trusted
  setup, generates per-holder Groth16 proofs.
- **CredentialProof** (`zeroj-usecases/identity-kyc/.../circuit/`):
  in-circuit checks — EdDSA-Jubjub verify, age range, country Merkle-
  membership.
- **CredentialGatedValidator** (Plutus V3, compiled from Julc): on-chain
  Groth16 verifier that unlocks funds when the proof + `eligible=1`.

## 3. End-to-end flow

### 3.1 Issuance (one-time, by the issuer)

```
// Issuer
sk    = secureRandom() ∈ [1, l)   // Jubjub scalar field order
pk    = [sk] · G                   // Jubjub subgroup generator

for each (name, age, country):
    msg = Poseidon(age, country)    // BLS12-381 scalar field element
    typedMsg = JubjubMessage.fromCanonicalFieldBytes(BE32(msg))
    sig = EdDSAJubjub.signCompatibilityOffline(keypair, typedMsg) // (R, S)
    persist { name: (age, country, sig) }
```

Published: `pk` (two 32-byte field elements).  
Kept secret: `sk`.

`signCompatibilityOffline` is deliberate: this application issues fixed
demo fixtures during startup. It is not approval for a network-reachable
Java signing endpoint.

### 3.2 Proof generation (by the holder)

```
input  (public):  pk.u, pk.v, minAge, countryRoot, eligible
input  (secret):  age, country, sig.R.u, sig.R.v, sig.S,
                  kModL, kQuotient,  (Merkle siblings + path bits)

circuit:
    claimsMsg = Poseidon(age, country)
    ZkEdDSAJubjub.verifyWithRegisteredKey(
        pkU, pkV, claimsMsg, sigRU, sigRV, sigS, kModL, kQuotient)
    ageOk     = (age >= minAge)            // 8-bit unsigned compare
    assertMerkleInclusion(country, countryRoot)  // Poseidon tree
    assert eligible == ageOk
```

The circuit outputs a Groth16 BLS12-381 proof (~200-byte on the wire after
`ProofCompressor`). The whole witness is secret except the five declared
public inputs.

### 3.3 On-chain verification

The Plutus V3 validator (`CredentialGatedValidator`) is parameterized with
the Groth16 verifying key, the registered issuer's two Jubjub coordinates,
the minimum age, and the approved-country root. At unlock time it accepts
the proof + public inputs as a redeemer and runs the pairing check. It
releases funds only if the proof is valid, `eligible == 1`, and all four
registered policy values match.

## 4. API endpoints

Base URL (default): `http://localhost:8087`

### GET `/api/credential/status`
Returns issuer public-key fingerprint, policy parameters, and a list of
test users pre-issued at startup:

```json
{
  "users": [
    { "name": "Alice", "age": 25, "countryCode": 840,
      "sigR": "37f9abc1...", "expectedEligible": true }, ...
  ],
  "minAge": 18,
  "issuerPkU": "ab12cd34...",
  "issuerPkV": "56ef78a1...",
  "countryRoot": "9a8b7c6d...",
  "lockedUtxos": 0,
  "countryTreeDepth": 4
}
```

### POST `/api/credential/verify`
Generates a ZK proof that the named user holds a valid credential meeting
the policy.

```
POST /api/credential/verify
{ "name": "Alice" }
```

Response:
```json
{
  "name": "Alice",
  "eligible": true,
  "provingTimeMs": 18432,
  "age": 25,
  "countryCode": 840
}
```

### POST `/api/credential/lock`
Locks ADA at the credential-gated script address:
```
POST /api/credential/lock
{ "adaAmount": 5 }
```

### POST `/api/credential/unlock`
Submits the last-generated proof to the chain. If eligible, the Plutus
validator accepts the proof + public inputs and releases the funds:
```
POST /api/credential/unlock
{ "name": "Alice" }
```

Passing `{"forceOnChain": true}` bypasses the off-chain eligibility check
and sends the proof to the validator even when the holder is ineligible —
useful for demonstrating that the Plutus validator independently rejects
such proofs.

## 5. Running the demo

Prereqs:
- Java 25 (`sdk use java 25.0.2-graal`)
- yaci-devkit up on localhost (yaci-store on :8080, cardano-node on :31000)

```
cd zeroj-usecases/identity-kyc
./gradlew bootRun
```

Startup time is machine-dependent. The application compiles the
11,258-constraint circuit and performs a fresh development-only Powers of
Tau and Groth16 Phase-2 setup on every start.

### Quick demo
```
# 1. Lock some ADA behind the credential gate
curl -X POST http://localhost:8087/api/credential/lock \
  -H 'Content-Type: application/json' -d '{"adaAmount": 5}'

# 2. Alice proves she's eligible
curl -X POST http://localhost:8087/api/credential/verify \
  -H 'Content-Type: application/json' -d '{"name": "Alice"}'

# 3. Alice unlocks
curl -X POST http://localhost:8087/api/credential/unlock \
  -H 'Content-Type: application/json' -d '{"name": "Alice"}'
```

Try it with Charlie (underage) — `/verify` returns `eligible=false`,
`/unlock` refuses. Send `forceOnChain=true` to see the Plutus validator
reject an ineligible proof.

## 6. What's secret / what's public

Public (visible on-chain in the redeemer):

- `pkU, pkV` — issuer identity (not the holder's identity).
- `minAge, countryRoot` — policy parameters.
- `eligible` — the claim the holder is making ("yes I qualify").
- The Groth16 proof itself (~200 bytes compressed).

Secret (witness-only, never leaves the prover):

- `age, country`.
- The issuer's signature `(R, S)`.
- The country Merkle proof path.

A successful verification reveals only that <i>some</i> credential signed
by the issuer exists that satisfies the policy — not which one, or what
the values are.

## 7. Next steps

- **Revocation**: add a per-credential nullifier derived from the signature,
  published on-chain when revoked; the circuit asserts the credential's
  nullifier is not in the revocation set.
- **Multiple issuers**: extend the circuit to accept any of N trusted
  `pk`s (or a Merkle membership proof against an issuer whitelist).
- **W3C VC envelope**: wrap the sig + claims in a CIP-30 / DID-friendly
  envelope so wallets can present credentials.
- **Bridge to Atala PRISM DID**: issuers publish pk via DID documents; the
  circuit becomes interoperable with the broader Cardano identity stack.

## 8. Security and deployment scope

- The circuit uses `verifyWithRegisteredKey`; the Plutus script supplies
  the required protocol-level key registry by pinning both issuer
  coordinates as parameters.
- The script also pins `minAge` and `countryRoot`. Treating them only as
  public proof inputs would let a caller choose a weaker policy.
- The seeded issuer key and single-party trusted setup are demo material.
  Production requires protected key provisioning, reviewed ceremony
  material, and external review of the complete protocol.
- The compatibility signer is suitable for isolated/demo issuance, not a
  network timing oracle.

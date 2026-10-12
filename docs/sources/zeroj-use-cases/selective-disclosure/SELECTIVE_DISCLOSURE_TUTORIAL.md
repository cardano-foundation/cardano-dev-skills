# Selective Disclosure of Multi-Field VC — Tutorial

Shows how **one** issuer-signed credential can prove **many** distinct
predicates to **many** different Cardano DApps, without revealing the
underlying fields. This is the ZK building block behind W3C Verifiable
Credentials used selectively: one issuance, reusable across verifiers.

## 1. Why this is different from single-predicate KYC

ADR-0016's `identity-kyc` demo proves *one* predicate (age ≥ X AND
country ∈ Y) from a minimal credential. Here we go further:

- The credential is **richer**: `(dobYear, country, roleId,
  salaryBracket, nameHash)` — five fields, signed once.
- The approved-country set is a **Merkle tree** — the issuer publishes
  a root, the circuit checks membership. The demo seeds it with
  `{USA, GBR, DEU, FRA, JPN}` (labelled "approved" rather than EU;
  substitute any country codes you like).
- **Multiple predicates** share the same signature. The holder can
  prove *"adult resident"* to the Library DApp and *"senior doctor"* to
  the Healthcare Portal, both from the same credential bundle.
- **No linkability** between DApp interactions: the proofs are
  independent Groth16 artefacts over different circuits; nothing in
  them leaks which credential they came from.

That's the core shape of **W3C VC selective disclosure**: one signed
document, many predicate proofs.

## 2. Architecture

```
 ┌────────────────┐            ┌────────────────────┐
 │ Credential     │   sig      │  Holder (UI)       │
 │ Issuer         │───────────▶│  full credential   │
 │ Jubjub sk, pk  │            │  + sig stored      │
 └────────────────┘            └─────────┬──────────┘
                                         │
                        ┌────────────────┴────────────────┐
                        ▼                                 ▼
            ┌───────────────────────┐         ┌───────────────────────┐
            │ AdultResidentProof    │         │ SeniorDoctorProof     │
            │ age ≥ 21 + EU Merkle  │         │ role == Doctor        │
            │                       │         │ + age ≥ 30            │
            └───────────┬───────────┘         └───────────┬───────────┘
                        ▼                                 ▼
            ┌───────────────────────┐         ┌───────────────────────┐
            │ AdultResidentValidator│         │ SeniorDoctorValidator │
            │ Plutus V3 spending    │         │ Plutus V3 spending    │
            │ Groth16 BLS12-381     │         │ Groth16 BLS12-381     │
            └───────────────────────┘         └───────────────────────┘
```

### Components

| Piece | Role |
|---|---|
| `RichCredentialIssuerService` | Jubjub keypair; signs `(dobYear, country, roleId, salaryBracket, nameHash)` once per user |
| `AdultResidentProof` | EdDSA verify + `dobYear ≤ currentYear-21` + country Merkle membership (depth 4) |
| `SeniorDoctorProof`  | EdDSA verify + `roleId == DOCTOR` + `dobYear ≤ currentYear-30` |
| `PredicateProofService`| Compiles both circuits, shares PoT SRS, runs per-circuit Phase-2 setup |
| `AdultResidentValidator` | Plutus V3 spending validator parameterized by the adult-resident vk; 5 public inputs |
| `SeniorDoctorValidator`  | Plutus V3 spending validator parameterized by the senior-doctor vk; 4 public inputs |
| `OnChainGateService` | Compiles both scripts; lock ADA at either gate, unlock requires matching predicate proof |

## 3. End-to-end flow

### 3.1 Issuer setup (once)

```java
BigInteger sk = secureRandomScalar();
JubjubPoint pk = JubjubPoint.SUBGROUP_GENERATOR.scalarMul(sk);
```

### 3.2 Credential issuance (per person)

```java
BigInteger msg = Poseidon(dobYear, country, roleId, salaryBracket, nameHash);
JubjubMessage typed = JubjubMessage.fromCanonicalFieldBytes(BE32(msg));
EdDSAJubjub.Signature sig =
        EdDSAJubjub.signCompatibilityOffline(keypair, typed);
// Deliver (full credential, sig) privately to the holder
```

### 3.3 Prove predicate #1 — Adult Resident

```
public:  pkU, pkV, currentYear, countryRoot, eligible
secret:  (full credential), sigRU, sigRV, sigS, kModL, kQuotient,
         sibling_0..3, pathBit_0..3

circuit:
    claimsMsg = Poseidon(dobYear, country, roleId, salaryBracket, nameHash)
    ZkEdDSAJubjub.verifyWithRegisteredKey(
        pkU, pkV, claimsMsg, sigRU, sigRV, sigS, kModL, kQuotient)
    assert dobYear <= currentYear - 21
    merkleProof(country, countryRoot, siblings, pathBits)
    eligible = 1
```

### 3.4 Prove predicate #2 — Senior Doctor

```
public:  pkU, pkV, currentYear, eligible
secret:  (full credential), sigRU, sigRV, sigS, kModL, kQuotient

circuit:
    claimsMsg = Poseidon(dobYear, country, roleId, salaryBracket, nameHash)
    ZkEdDSAJubjub.verifyWithRegisteredKey(
        pkU, pkV, claimsMsg, sigRU, sigRV, sigS, kModL, kQuotient)
    assert roleId == 1001            // Doctor role ID
    assert dobYear <= currentYear - 30
    eligible = 1
```

Each predicate produces an **independent** proof against its own vk; no
proof re-uses data from another. Bob (1990, DEU, Doctor, salary 4) can
produce both. Alice (1995, USA, Engineer, 5) can produce only the adult
resident proof. Charlie (2010, GBR, Student) can produce neither.

## 4. API

Base URL: `http://localhost:8085`

### GET `/api/predicate/status`

```json
{
  "issuerPkU": "0x…",
  "currentYear": 2026,
  "adultGateAddr": "addr_test1…",
  "doctorGateAddr": "addr_test1…",
  "adultGateUtxos": 1,
  "doctorGateUtxos": 1,
  "users": [
    { "name": "Alice", "dobYear": 1995, "country": 840, "role": "Engineer",
      "salaryBracket": 5 },
    …
  ]
}
```

### POST `/api/predicate/lock`

```
{ "gate": "adult" | "doctor", "adaAmount": 5 }
```

Locks `adaAmount` ADA at the gate's script address. The datum is a
unit constructor (no fields); the proof and its public inputs travel
in the **redeemer** at unlock time.

### POST `/api/predicate/prove-adult`, `/api/predicate/prove-doctor`

```
{ "name": "Bob" }
```

Generates the predicate proof and returns `{eligible, provingTimeMs}`.
Returns `eligible: false` if the user's credential fails the predicate
— the proof is still produced (no short-circuit), so the validator
would still reject; the flag is for UI convenience.

### POST `/api/predicate/unlock-adult`, `/api/predicate/unlock-doctor`

```
{ "name": "Bob" }
```

Submits an unlock tx against the gate's script address using the
proof previously generated by `/prove-adult` or `/prove-doctor` (the
controller caches the last proof per (predicate, name) pair — you
must call `prove-*` first, or the endpoint returns HTTP 400 with
"No proof generated"). HTTP 200 → proof satisfied + UTxO sent to
admin wallet. HTTP 403 with `onChainRejection: true` → Plutus
rejected the proof.

## 5. Running

```
# Prereqs: Java 25, yaci-devkit on localhost:8080
cd zeroj-usecases/selective-disclosure
./gradlew bootRun
```

First boot runs a development-only Powers of Tau once, followed by one
Phase-2 setup per circuit. Timings are machine-dependent. Subsequent
boots load setups whose filenames are keyed by SHA-256 of each complete
serialized R1CS; a changed relation cannot accidentally reuse a cached
setup merely because its dimensions stayed the same. The current circuits
have 12,109 constraints (Adult Resident) and 11,137 constraints (Senior
Doctor), so the development configuration uses a power-14 SRS; a capacity
regression test prevents either circuit from silently outgrowing it.

### Minimal demo script

```bash
# 1. Lock 5 ADA at each gate
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/lock -d '{"gate":"adult","adaAmount":5}'
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/lock -d '{"gate":"doctor","adaAmount":5}'

# 2. Bob unlocks the Library (age 36 ≥ 21 + DEU ∈ approved set ✓).
#    Must prove first (UI does this for you), then unlock uses the
#    cached proof.
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/prove-adult  -d '{"name":"Bob"}'
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/unlock-adult -d '{"name":"Bob"}'

# 3. Bob unlocks the Healthcare Portal (Doctor ✓ + age 36 ≥ 30 ✓)
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/prove-doctor  -d '{"name":"Bob"}'
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/unlock-doctor -d '{"name":"Bob"}'

# 4. Charlie (age 16) fails adult — /prove-adult returns eligible=false
#    because Charlie's country isn't in the approved set; /unlock-adult
#    would be rejected on-chain.
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/prove-adult -d '{"name":"Charlie"}'

# 5. Frank (Doctor but Brazilian) succeeds Healthcare, fails Library
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/prove-doctor  -d '{"name":"Frank"}'  # ✓
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8085/api/predicate/prove-adult   -d '{"name":"Frank"}'  # ✗
```

Or open <http://localhost:8085> for the UI.

## 6. Selective-disclosure properties

| Property | How it's achieved |
|---|---|
| Holder reveals *only* the predicate's truth value | All credential fields are `privateInput`; only `eligible` is public |
| Same credential → many predicates | `claimsMessage = Poseidon(dobYear, country, roleId, salaryBracket, nameHash)` is common; only the constraint shape differs |
| No linkability across DApps | Two unrelated Groth16 proofs, distinct vks — no shared nonce or tag |
| Approved-country policy is explicit | Merkle tree of approved country codes; the validator pins the accepted root as a script parameter |
| On-chain verification is cheap | Groth16: 3 pairings, independent of circuit size |

## 7. What this does NOT yet defend against

- **Credential theft**: if the full `(credential, sig)` bundle leaks,
  the attacker can also prove any predicate the victim could. Standard
  VC risk; mitigate with holder-binding (tie credential to holder's
  wallet key — omitted from this demo for simplicity).
- **Predicate-reuse replay across sessions**: the current proof has no
  nonce / session binding. A passive observer who captures an unlock
  tx could attempt to replay the proof — the on-chain UTxO consumption
  prevents double-spend of the *locked funds*, but the proof itself
  would still verify. For session-bound uses (e.g., proving to a
  web-service without spending a UTxO), add a nonce or epoch input.
- **Inter-predicate linkability via public inputs**: the circuits
  share `currentYear`; if a verifier collects unlocks from both the
  Library and the Healthcare Portal within the same year they cannot
  link the two without additional metadata, but anything that *does*
  correlate (e.g. same recipient address paying fees) would leak.
  Production would use fresh per-tx recipient addresses.
- **Issuer signing scope**: the seeded credentials use
  `signCompatibilityOffline` during application startup. This is an
  isolated/demo issuance path, not a network-reachable signing service.
- **Policy upgrades redeploy scripts**: issuer key, `currentYear`, and
  (for Adult Resident) `countryRoot` are validator parameters. Updating
  any of them changes the script address; this is intentional so a caller
  cannot select weaker public inputs.

## 8. Where to go next

- Add more predicate circuits over the same credential: *"salary
  bracket ≥ 5 AND age ≤ 40"*, *"role ∈ {Engineer, Teacher}"*.
- Wire real W3C VC issuance (JSON-LD credentialSubject) via
  `did:key` + Jubjub EdDSA; demonstrate selective presentation to a
  non-Cardano verifier (e.g., a web portal).
- Holder-binding: include the holder's Cardano payment credential as a
  bound field in the claims message; the proof then ties to a specific
  wallet.
- Revocation: add a Merkle root of revoked credential IDs and require
  the proof to include a non-membership witness.

# Sybil-Resistant Airdrop — Tutorial

Shows how to build a **one-per-human faucet** on Cardano using ZK proofs:
each personhood credential can claim ADA once per epoch. The ZK circuit
proves "I hold an issuer-signed personhood credential" + publishes a
deterministic nullifier; the policy/name asset identity creates a claim
receipt. The demo service rejects a repeated
nullifier; a production protocol still needs stateful on-chain uniqueness
enforcement.

## 1. Why this is different from an "age/country KYC" gate

ADR-0016's `identity-kyc` demo proves eligibility (age ≥ X, country ∈ Y).
Proofs there can be reused indefinitely — one credential always verifies.

This demo adds a **rate limit per credential**: the holder proves
possession *and* binds the proof to (credential × epoch) via a
deterministic nullifier. Attempting to claim twice with the same
credential in the same epoch produces the same nullifier → the mint
would use the same NFT name, which the service recognizes as already
claimed. Cardano itself does not globally forbid minting more units under
the same policy/name, so the service check is not a production
double-claim guarantee.

This is the ZK building block underneath: Semaphore signals, Tornado
Cash withdrawals, Worldcoin claim tokens, every airdrop that wants
sybil resistance.

## 2. Architecture

```
 ┌────────────────┐       ┌────────────────┐       ┌──────────────────┐
 │ Personhood     │       │  Holder        │       │  Cardano         │
 │ Issuer         │─────▶ │  (UI)          │─────▶ │  Faucet minting  │
 │ (e.g. BrightID)│  sig  │  proof + mint  │       │  policy (Plutus) │
 │ sk, pk         │       │                │       │                  │
 └────────────────┘       └────────────────┘       └──────────────────┘
                                 │                          │
                                 ├─ (personhoodId)        ─ Groth16 BLS12-381
                                 │  EdDSA(sk, Poseidon     verification
                                 │  (personhoodId, 0))      +
                                 │                          NFT name = nullifier
                                 ▼                          + mint qty == 1
                          nullifier = Poseidon(
                              personhoodId, epoch)
```

### Components

| Piece | Role |
|---|---|
| `PersonhoodIssuerService` | Holds the issuer's Jubjub keypair; signs one credential per enrolled person |
| `PersonhoodAirdropProof` | In-SNARK: EdDSA verify + `nullifier == Poseidon(personhoodId, epoch)` + binds recipient |
| `AirdropProofService` | Compiles circuit, runs Powers-of-Tau + Phase-2 setup, generates claim proofs |
| `FaucetMintingPolicy` (Plutus V3) | Parameterized by Groth16 vk, registered issuer key, and epoch; gates 1 NFT mint per transaction, asset name = nullifier |
| `OnChainAirdropService` | Submits the proof as a `mintAsset` tx; maintains off-chain used-nullifier cache |

## 3. End-to-end flow

### 3.1 Issuer setup (once)

```java
BigInteger sk = secureRandomScalar();
JubjubPoint pk = JubjubPoint.SUBGROUP_GENERATOR.scalarMul(sk);
// Publish pk.u, pk.v
```

### 3.2 Credential issuance (per person)

```java
BigInteger personhoodId = newUniqueFieldElement(); // issuer tracks real-human uniqueness
BigInteger msg = Poseidon(personhoodId, 0);    // BLS12-381 scalar
JubjubMessage typed = JubjubMessage.fromCanonicalFieldBytes(BE32(msg));
EdDSAJubjub.Signature sig =
        EdDSAJubjub.signCompatibilityOffline(keypair, typed);
// Deliver (personhoodId, sig) privately to the person
```

### 3.3 Claim (per epoch, per person)

```
input  (public):  pkU, pkV, epoch, nullifier, recipient, eligible
input  (secret):  personhoodId, sigRU, sigRV, sigS, kModL, kQuotient

circuit:
    claimsMsg = Poseidon(personhoodId, 0)
    ZkEdDSAJubjub.verifyWithRegisteredKey(
        pkU, pkV, claimsMsg, sigRU, sigRV, sigS, kModL, kQuotient)
    assert nullifier == Poseidon(personhoodId, epoch)       // sybil binding
    recipient bound as public input (tx-shape commitment)
    eligible = 1
```

Plutus V3 minting policy verifies the Groth16 proof over BLS12-381 with 6
public inputs and mints 1 NFT whose asset name = nullifier bytes. A second
claim with the same personhoodId in the same epoch produces the same
nullifier. The demo service rejects that duplicate before building the
transaction.

## 4. API

Base URL (default): `http://localhost:8086`

### GET `/api/airdrop/status`

```json
{
  "issuerPkU": "0x…",
  "issuerPkV": "0x…",
  "currentEpoch": 1,
  "adaPerClaim": 2,
  "policyId": "c6c019a9…",
  "totalClaims": 2,
  "users": [
    { "name": "Alice", "personhoodId": "0x…", "alreadyClaimedThisEpoch": true },
    …
  ]
}
```

### POST `/api/airdrop/claim`

```
{ "name": "Alice", "recipient": "addr_test1…" (optional) }
```

Generates ZK proof + submits `mintAsset` tx. Returns tx hash, nullifier,
proving time. Rejects with HTTP 409 if the nullifier was already claimed.

### GET `/api/airdrop/history`

Session-local claim history (list of `(name, nullifier, txHash, provingMs)`).

## 5. Running

```
# Prereqs: Java 25, yaci-devkit on localhost
cd zeroj-usecases/personhood-airdrop
./gradlew bootRun
```

The circuit currently has 10,467 constraints and uses a power-14
development SRS. First-boot setup time is machine-dependent. Subsequent
boots load a setup whose filename is keyed by SHA-256 of the complete
serialized R1CS, so a changed circuit relation cannot reuse a
same-shaped setup accidentally.

### Minimal demo script

```bash
# 1. Alice claims 2 ADA
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8086/api/airdrop/claim \
  -d '{"name": "Alice"}'

# 2. Alice attempts double-claim (fails with 409 — same nullifier)
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8086/api/airdrop/claim \
  -d '{"name": "Alice"}'

# 3. Bob claims (different nullifier — succeeds)
curl -X POST -H 'Content-Type: application/json' \
  http://localhost:8086/api/airdrop/claim \
  -d '{"name": "Bob"}'
```

Or open <http://localhost:8086> for the UI and click through.

## 6. Nullifier anatomy

`nullifier = Poseidon(personhoodId, epoch)` — 32 bytes. Deterministic in
both inputs, secret in personhoodId, public in epoch. The nullifier
reveals *nothing* about personhoodId (Poseidon is one-way). All that
leaks publicly is "this nullifier has been used" — i.e., "someone holding
some credential has claimed in this epoch".

Each epoch reset produces a fresh nullifier space; the same credential
can claim again next epoch with a completely different nullifier. No
linkability across epochs.

## 7. What this does NOT yet defend against

- **Stolen credentials**: if `personhoodId` leaks (compromised issuer,
  user shares credential bundle), attacker can claim once per epoch.
  Standard credential-system risk; mitigate via revocation lists (not
  demonstrated here).
- **Double-claim enforcement is off-chain in this demo.** The faucet
  minting policy verifies the Groth16 proof, pins the issuer and epoch,
  requires `eligible == 1`, and requires the minted asset name to equal
  the nullifier bytes. It does not maintain on-chain state proving that
  this nullifier has never been minted before. The real duplicate gate is
  the service's in-memory `claimedNullifiersHex` set. Consequences:
  - If the service restarts, the in-memory set is lost. The ledger's
    UTxO set still contains the receipt NFT, but Cardano permits a minting
    policy to mint another unit with the same asset name. A restart can
    therefore reopen a claim unless the service reconstructs its set.
  - Concurrent claim requests for the same credential may race past
    the in-memory check; resolution depends on mempool ordering.
  - A production deployment should tighten the minting policy to
    assert `assetName(mintedToken) == nullifierBytes` and add a
    state-thread token (DST) carrying a Merkle set of used nullifiers
    for adversarial-signer defense.
- **Sybil at the issuer layer**: the demo simulates issuer uniqueness
  via an in-memory map. Real BrightID / Worldcoin / proof-of-personhood
  systems do biometric / social-graph checks; that's orthogonal to
  what's verified on Cardano.
- **Static epoch**: `currentEpoch` is read from `application.yml`, not
  from the chain. It is pinned into the policy ID, so changing it deploys
  a new policy. Wire it to the live Cardano epoch before a long-running
  deployment.
- **Issuer signing scope**: startup fixtures use
  `signCompatibilityOffline`. Do not expose that demo signer as a
  network-reachable issuance endpoint.

## 8. Where to go next

- Add a state-thread token to the minting policy for adversarial-signer
  defense.
- Rate-limit per epoch × recipient (currently one-per-credential, not
  one-per-wallet).
- Wire W3C VC issuance so the credential can be presented to non-Cardano
  services as well.
- Wallet integration via CIP-30: holder signs the claim tx locally
  rather than the service wallet-as-faucet.

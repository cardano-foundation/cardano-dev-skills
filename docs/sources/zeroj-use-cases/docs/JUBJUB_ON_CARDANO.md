# Jubjub + BLS12-381 Poseidon on Cardano — What Becomes Possible

> Status: Historical design note, refreshed 2026-07-28. Jubjub arithmetic,
> Pedersen commitments, and EdDSA-Jubjub verification are now implemented
> in ZeroJ. The usecases in this repository exercise registered-key
> verification. This is not a production-readiness approval: the complete
> protocol and the dedicated-host signing profile still require their
> documented external/platform review gates.

## 1. Why this matters for Cardano

Cardano onchain supports exactly one ZK-friendly pairing-friendly curve
natively: **BLS12-381**. Any circuit whose Groth16 / PlonK proof is verified
by a Plutus V3 script must be built over BLS12-381. That constrains every
other cryptographic primitive used inside the circuit — field arithmetic,
hash functions, signatures, commitments — to be **defined over the
BLS12-381 scalar field** (or derivatively composable with it).

Before ADR-0015 (shipped), zeroj circuits used `Poseidon` built from BN254
circomlib constants operating over the BLS12-381 scalar prime — a
non-standard hybrid that worked internally but was incompatible with every
published reference implementation. Third parties could not reproduce a
hash, verify a commitment, or re-derive a nullifier from chain data.

After ADR-0015 and the subsequent Jubjub hardening work:

- **Poseidon over BLS12-381 scalar field**, paper-canonical (✅ shipped;
  paper-spec Sage cross-checked; byte-reproducible from chain data by any
  conforming implementation).
- **Jubjub** — a twisted-Edwards elliptic curve whose base field *is* the
  BLS12-381 scalar field, with off-circuit arithmetic and hardened
  in-circuit gadgets now available.

Together these two primitives complete the minimum cryptographic alphabet
for privacy-preserving applications on Cardano.

## 2. Terminology: Jubjub vs BabyJubJub

| Name | Host curve (scalar field) | Use |
|---|---|---|
| **BabyJubJub** | BN254 (alt_bn128) | Ethereum, circom ecosystem |
| **Jubjub** | BLS12-381 | Zcash, Filecoin, Cardano ZK |

Both are twisted Edwards curves with identical structural design, different
parameters. **Cardano wants Jubjub, not BabyJubJub.** The onchain validator
can only verify Groth16 proofs over BLS12-381, so all in-circuit
elliptic-curve operations must be native to that scalar field.

The zeroj codebase (and ADR-0015) uses "Jubjub" to mean the Zcash/zkcrypto
variant pinned at those curve parameters.

## 3. Primitives the stack enables

### Shipped in ADR-0015

| Primitive | Building block | Evidence |
|---|---|---|
| Poseidon hash (2-to-1, N-to-1) | `PoseidonHash`, `Poseidon` gadget | Circomlibjs BN254 match + Sage paper-spec match |
| Poseidon Merkle trees | `SignalMerkle` + `SignalPoseidon` | End-to-end DPP on yaci-devkit (tx `80c28182…`) |
| MPF (Merkle Patricia Forest) with Poseidon leaves | DPP `PoseidonHashFunction` → CCL | DPP demo persistence |
| Nullifier derivation | Poseidon(secret, context) | private-voting, nft-ownership |
| Commitment schemes | Poseidon(secret, value) | identity-kyc credential hash |

### Jubjub building blocks and design opportunities

| Primitive | Status | Why it matters on Cardano |
|---|---|---|
| **Jubjub point arithmetic in-circuit** | Implemented | Foundation for Jubjub-backed circuit protocols |
| **Pedersen commitment** | Implemented | Hiding, binding, and homomorphic commitments |
| **EdDSA-Jubjub verification in-circuit** | Implemented | An issuer signs while a holder proves possession and predicates privately |
| **Schnorr signatures in-circuit** | Design opportunity | Anonymous or threshold authorization protocols |
| **Jubjub/Poseidon Merkle constructions** | Poseidon trees implemented; Jubjub-specific construction is protocol-dependent | Membership and revocation registries |
| **Anonymous credentials / encryption** | Design opportunity requiring its own specification and review | Richer privacy protocols |

All of these produce a Groth16 / PlonK proof that ZeroJ's existing Plutus V3
verifier (`zeroj-onchain-julc/Groth16BLS12381Verifier`) accepts on-chain.
**No new Plutus builtins or onchain changes needed** — the full complexity
is internalized in the SNARK.

## 4. Impact on each existing zeroj usecase

### 4.1 identity-kyc — **highest-impact target** for Jubjub

**Current implementation:**
- Issuer signs the canonical field element
  `Poseidon(age, country)` with EdDSA-Jubjub — asymmetric.
- Holder proves in ZK: "I know a credential + signature verifying under
  the registered issuer's public key, such that age ≥ 18 and country is
  in the configured set", without
  revealing claim values or the signature.
- The Plutus script pins the issuer key and policy values rather than
  trusting caller-selected public inputs.
- Jubjub EdDSA is a suite-specific in-SNARK signature, not RFC 8032
  Ed25519. A W3C VC integration needs an explicit envelope/profile rather
  than an interoperability claim based only on the word “EdDSA.”
- Issuer rotation, revocation, multi-issuer all become tractable.
- Direct path to Atala PRISM / CIP-30 credential presentation.

**ADR-0014 explicitly flagged this as the motivation for re-adding EC
operations to circuit-lib.** ADR-0016 is its Cardano-native realization.

### 4.2 private-voting

**Today:**
- Eligible voter set = Poseidon Merkle tree of public keys (where each
  key = `Poseidon(secret, 0)`).
- Nullifier = `Poseidon(secret, electionId)`.
- Commitment = `Poseidon(vote, nullifier)`.

**With Jubjub:**
- **Voter keys become Jubjub keypairs.** Voter public key = `[sk]·G` where
  G is the Jubjub generator — a standard EdDSA public key. Voters can
  derive and prove membership using the same key they'd use for wallet
  signing.
- **Vote commitment via Pedersen** = `[vote]·G + [r]·H` — homomorphic.
  Allows **additive tallying** (sum the on-chain commitments → encrypted
  total → threshold-decrypt off-chain by vote authority). No need for
  the tallier to see individual votes.
- **Sybil-resistant registration**: voter proves ownership of a Cardano
  wallet via Jubjub-Schnorr tied to an on-chain stake key commitment.
- **Weighted voting by stake**: same proof, but the tally weights each
  vote by a stake amount committed via Pedersen.

Cardano onchain: the minting policy already exists; only the witness-set
contents change.

### 4.3 proof-of-reserves

**Today:**
- Merkle Sum Tree of `Poseidon(accountId, balance)` leaves.
- Proves sum of all balances ≤ declared reserves.

**With Jubjub:**
- **Pedersen-committed balances** (hiding + binding). The Merkle Sum Tree
  holds Pedersen commitments instead of cleartext `(accountId, balance)`
  hashes. The exchange doesn't reveal even the hash of the pair — only
  a commitment. Aggregate sum is a **homomorphic** sum of Pedersen
  commitments (opened to reveal only the total, not individuals).
- Users can prove inclusion of their own balance (by opening one leaf's
  Pedersen commitment to themselves) without the exchange revealing it
  to anyone else.
- **Optional: EdDSA-signed balance attestations** from the exchange —
  each leaf's Pedersen commitment is signed by the exchange, binding
  them to not re-issue it under a different account.

Result: significantly stronger confidentiality than the current scheme
(which hashes `(id, balance)` but still leaks balance to anyone who can
enumerate ID space).

### 4.4 nft-ownership

**Today:**
- `ownerHash = Poseidon(secretKey, 0)`; leaf = `Poseidon(ownerHash, tokenName)`.
- Proves membership in a Merkle snapshot of holders.
- Nullifier = `Poseidon(tokenName, contextId)`.

**With Jubjub:**
- **Proper wallet-derived ownership**: replace `secretKey` with a Jubjub
  (or Cardano stake-key-derived) signature over `(tokenName, contextId)`.
  Owner proves "I hold the Cardano key that last received this NFT" —
  stronger binding than `Poseidon(secret, 0)`.
- **Pedersen-hidden token names**: snapshots commit to Pedersen
  commitments of token IDs, not cleartext hashes. Prevents a third
  party from enumerating "which NFTs exist" from the snapshot.
- **Batched airdrop claims** with one proof covering multiple holdings
  (Pedersen commitment sum = total).

### 4.5 digital-product-passport (DPP)

**Today:**
- Three ZK circuits (carbon threshold, recycled threshold, country
  membership) under Poseidon.
- On-chain Plutus policy mints an NFT if proof valid.

**With Jubjub:**
- **Inspector signatures** (currently a Poseidon key in the circuit)
  become Jubjub EdDSA. Inspectors hold standard Ed25519-equivalent keys
  that they can also use off-chain for other purposes.
- **Supply-chain chain-of-custody** — each leg of the supply chain signs
  a Pedersen-committed product state. The DPP minting circuit proves
  "an unbroken chain of valid signatures from raw-material supplier to
  retailer exists", without revealing intermediate parties or timestamps.
- **Confidential batch sizes**: manufacturers commit to batch sizes via
  Pedersen; downstream proofs reason about bounds without revealing exact
  production volume.

### 4.6 Not-yet-existing usecases the stack unlocks

- **Private Cardano-native payment proofs** — prove "I sent ≥ X ADA in
  the last epoch" via Pedersen-committed transfer amounts, without
  revealing exact amounts or counterparties.
- **Anonymous governance voting** on CIP-1694 governance actions — eligible
  stake-weighted voting where individual ADA-holder votes are Pedersen-
  committed and homomorphically summed.
- **Reusable identity attestations for dApps** — DID holder proves
  "my identity credential from issuer X includes country Y" directly
  to any dApp, via a single proof reusing a signed credential. Revoke
  revocation list via Merkle membership on Jubjub.
- **Privacy-preserving loyalty programs** — users prove "I bought ≥ N
  products from retailer X in the last year" without retailer seeing
  purchase history.
- **Confidential sealed-bid auctions** — Pedersen-committed bids, proved
  valid and in range via Jubjub-backed range proofs, revealed only on
  auction close.
- **KYC-gated DeFi** — DeFi protocol requires ZK proof "I hold an
  issuer-signed KYC credential" before allowing withdrawal; issuer
  signatures are Jubjub EdDSA.

## 5. Why these primitives specifically (and not BLS12-381 group ops)

BLS12-381 itself has G1 + G2 + pairings natively. So why add a second curve
(Jubjub) inside the SNARK?

Because **BLS12-381 scalar multiplication inside a BLS12-381 SNARK is
prohibitively expensive**. Each EC op on the host curve requires emulating
base-field arithmetic inside scalar-field arithmetic — tens of thousands
of constraints per scalar-mul.

Jubjub operates natively in the scalar field of BLS12-381, so a Jubjub
scalar-mul is a few hundred constraints — cheap enough for real-time ZK
proofs. That's the entire point of having an "embedded" curve: the curve
arithmetic and the SNARK arithmetic share the same field.

The trade-off: Jubjub operations stay *inside* the proof. You cannot use a
Jubjub public key as a Cardano wallet signing key — those are Ed25519, a
different curve. But the two can be linked via a one-time derivation
commitment proved in-circuit.

## 6. Security note on BabyJubJub vs Jubjub

The hardened design uses cofactorless EdDSA verification and canonical
`S < l` handling. Affine prover inputs are constructed through
curve-checking gadgets. Two verifier entry points make the key-trust model
explicit:

- `verifyStrict` proves subgroup membership in-circuit for a
  prover-supplied key.
- `verifyWithRegisteredKey` is cheaper, but only sound as an authorization
  protocol when the public key is bound by a registry or script
  parameter. The affected usecases pin both coordinates on-chain.

The demos issue startup fixtures through
`signCompatibilityOffline`. Do not turn that path into a
network-reachable signing service. The fixed-limb dedicated-host signer
remains unavailable through its validated factory until its external and
platform-specific release gates are satisfied.

## 7. Implementation summary

| Area | Deliverable | Status |
|---|---|---|
| Arithmetic | Off-circuit and in-circuit Jubjub operations | Implemented; external review gate remains |
| Commitments | Jubjub Pedersen commitment | Implemented; deployment restrictions apply to secret generation |
| Signatures | Cofactorless EdDSA-Jubjub verification | Implemented; external review gate remains |
| Signing | Fixed-limb dedicated-host candidate | Implemented internally; validated factory remains fail-closed pending platform gates |
| Usecases | Identity KYC, personhood airdrop, selective disclosure | Migrated to registered-key verification and explicit offline fixture signing |
| Integration | Yaci DevKit transactions | Revalidated as part of the migration; see each usecase tutorial |

---
name: explain-zk
description: >-
  Zero-knowledge and the BLS12-381 primitive family on Cardano: verify SNARK
  proofs on-chain, aggregate BLS signatures, run VRFs, derive keys, and check
  BBS+ credentials in Aiken. Triggers: "explain zero-knowledge", "ZK on Cardano",
  "verify a SNARK on-chain", "Groth16 in Aiken", "zk-SNARK verifier", "BLS
  signatures in Aiken", "aggregate signatures", "VRF on Cardano", "verifiable
  randomness", "BBS+ / selective disclosure", "anonymous credentials",
  "prove knowledge without revealing it".
allowed-tools: Read Grep Glob
disallowed-tools: Bash Edit Write WebFetch WebSearch
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Explain ZK — zero-knowledge and BLS12-381 on Cardano

Help a developer understand and build with Cardano's on-chain cryptography: verifying
zero-knowledge proofs, and the wider family of protocols the same curve unlocks —
aggregated signatures, verifiable randomness, on-chain key derivation, and anonymous
credentials. Teach the model, then hand them a minimal working verifier they can adapt.

"Zero-knowledge" is the umbrella most people search under, but the engine underneath is
the **BLS12-381** elliptic curve, and proof verification is only one of the things it does.

## When to use

- A developer asks how zero-knowledge proofs work on Cardano, or how to verify a SNARK on-chain
- Someone wants to add a Groth16 / PLONK / Halo2 verifier to a validator
- Questions about BLS signature aggregation, multisig at scale, or committee/consensus signatures
- Building with verifiable randomness (VRF), on-chain key derivation (KDF), or BBS+ credentials
- "Prove I know X without revealing X", private voting, proof of reserves, selective disclosure
- Choosing a proof system, or understanding what a proof actually guarantees

## When NOT to use

- Writing a general (non-ZK) validator or minting policy — use `write-validator`
- Auditing a contract for vulnerabilities — use `review-contract`
- Walking through the text of a specific CIP — use `explain-cip` (CIP-0381 / 0133 / 0109)
- Choosing an SDK or the broader toolchain — use `suggest-tooling`
- Lowering script CPU / memory / size — use `optimize-validator`
- The goal only needs revealing a secret on spend — an HTLC, atomic swap, or hash-lock where the
  reveal is the point. A plain preimage check (`sha2_256(preimage) == commitment`) is simpler than a
  ZK proof and needs no circuit or trusted setup; use `write-validator`. Reach for a proof only when
  the secret must *stay* secret after it is used.

## Key principles

1. **One curve, many protocols.** BLS12-381 is *pairing-friendly*. That single property is
   what lets a validator aggregate thousands of signatures, verify a SNARK, produce verifiable
   randomness, or check an anonymous credential — all from the same handful of builtins. Treat
   the primitives as a construction kit, not a single feature.
2. **Prove off-chain, verify on-chain.** Generating a proof is heavy (seconds to minutes) and
   happens off-chain; verifying is cheap and deterministic and happens inside one validator.
   That asymmetry is exactly what makes the eUTxO model a good fit.
3. **A proof only proves what the circuit constrains.** Read the circuit, not the pitch. Every
   property an application claims must appear as a constraint, or the proof does not guarantee it.
4. **Bind every proof to its context.** A proof or signature sitting in a redeemer is public and
   replayable. Commit a nonce, the spent `OutputReference`, or a session key into the public
   inputs so a copied proof is useless anywhere else.
5. **Everything on-chain is public forever.** Datums and redeemers are permanent and world-readable.
   Whatever secrecy a scheme gives you comes from what you *never publish* (the witness, the
   password, the hidden attributes), not from the ledger.
6. **The builtins are audited; the libraries on top are not.** The BLS12-381 builtins sit on the
   audited `blst` library. The developer portal notes that the higher-level Aiken libraries built on
   them are unaudited and their APIs still change. Prototype on testnets, read the code you depend on,
   and treat published costs as measured snapshots.

## The BLS12-381 primitive family

Each row is a specialization of the same on-chain shape (below).

| Primitive | What it does | Reach for it when |
|---|---|---|
| **ZK-SNARK proof** | Prove knowledge of a witness, or that a computation ran correctly, revealing nothing else | Private eligibility, proof of reserves, "I solved it" bounties, rollup-style succinctness |
| **BLS signatures + aggregation** | Collapse many signatures or public keys into one small value, one pairing to verify | Large multisig, committees, consensus, vote tallies |
| **VRF** | Deterministic, unpredictable, publicly verifiable randomness from a key | Lotteries, leader selection, unlinkable record addresses |
| **KDF** | Turn seeds or shared secrets into valid curve keys, on-chain | Deriving session / child keys from already-public or committed material |
| **BBS+ credentials** | Prove a subset of signed attributes while hiding the rest | Selective disclosure, KYC, membership, compliance |

See `references/proof-systems.md` for the SNARK half and `references/bls-primitives.md` for the
signature / VRF / KDF / credential half.

## The one on-chain shape

Almost every verifier is the same pattern:

- The **trust anchor** — a verification key, an issuer key, or a commitment — lives in the **datum**
  (or a reference input, or is compiled into the validator).
- The **proof or signature** travels in the **redeemer**.
- The **public inputs** come from the datum, the redeemer, or the transaction context.
- The validator **decompresses** the points, runs the protocol's **pairing equation** via the
  BLS12-381 builtins, and returns a `Bool`.

Points cross the datum/redeemer boundary **compressed** (G1 is 48 bytes, G2 is 96 bytes). By
convention keys live in G1 (long-lived, small) and signatures in G2 (transient, larger).

## Workflow

### Step 1: Identify the primitive from the goal

Map what the developer wants to the family table. "Prove you know a password" or "private
eligibility" is a **SNARK**; "one signature for a hundred signers" is **aggregation**; "a fair
random winner anyone can check" is a **VRF**; "show you are over 18 without your birthdate" is
**BBS+**. Many goals only need a **sigma protocol** (a discrete-log proof, no circuit) — the
lightest tool; see `references/proof-systems.md`.

### Step 2: Search the bundled documentation

- `${CLAUDE_SKILL_DIR}/../../docs/sources/developer-portal/developers/curriculum/smart-contracts/advanced/zero-knowledge.md`
  — the landscape, what shipped when, and the catalog of real verifiers and apps
- `${CLAUDE_SKILL_DIR}/../../docs/sources/aiken-stdlib/aiken/crypto/bls12_381/`
  — the actual `g1`, `g2`, and `scalar` module APIs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/cips/CIP-0381/`, `CIP-0133/`, `CIP-0109/`
  — the builtins these all rest on

### Step 3: Build the on-chain verifier

Show the minimal working shape, then adapt it. The example below is a password lock: funds unlock
only for someone who can prove they know a secret whose Poseidon hash matches an on-chain
commitment — the "hello world" of ZK, and a faithful copy of a compiled, test-passing validator.

```aiken
use aiken/crypto/bls12_381/scalar
use cardano/transaction.{OutputReference, Transaction}
use zk_password/groth16.{Proof, VerificationKey, groth16_verify}

// Locked on-chain when the UTxO is created.
pub type Datum {
  credential_hash: Int,   // Poseidon(password) as a field element
  vk: VerificationKey,    // the compressed Groth16 verification key for the circuit
}

// Supplied by whoever tries to unlock.
pub type Redeemer {
  proof: Proof,           // a Groth16 proof that you know the pre-image
}

validator password_lock {
  spend(datum: Option<Datum>, redeemer: Redeemer, _self: OutputReference, _tx: Transaction) {
    expect Some(d) = datum
    // Convert the stored integer back to a field scalar; this rejects an
    // out-of-range value, so a malformed datum can never slip through.
    expect Some(hash) = scalar.new(d.credential_hash)
    groth16_verify(d.vk, redeemer.proof, [hash])
  }

  else(_) {
    False
  }
}
```

`groth16_verify` / `Proof` / `VerificationKey` come from a **standard Groth16 verifier**: plain Aiken
code that runs the pairing equation on the BLS builtins. It is the same for every circuit (around a
hundred lines, so you add it as a project dependency rather than inline it — see the ZK/BLS ecosystem
map via `suggest-tooling` for implementations). It checks `e(A, B) == e(alpha, beta) · e(vk_x, gamma) ·
e(C, delta)`; circuit size does not change its cost (measured around a fifth of a script's CPU budget,
~2.1 billion units in one run). Deriving a public key is even simpler — one scalar multiplication of
the generator:

```aiken
use aiken/builtin
use aiken/crypto/bls12_381/g1

fn sk_to_pk(sk: ByteArray) -> ByteArray {
  let s = builtin.bytearray_to_integer(True, sk)
  expect s != 0
  builtin.bls12_381_g1_compress(builtin.bls12_381_g1_scalar_mul(s, g1.generator))
}
```

For aggregation, VRF, KDF, and BBS+ shapes, route to `references/bls-primitives.md`.

### Step 4: Outline the off-chain pipeline

The validator is only the last step. For a SNARK the full path runs off-chain first: write the
circuit (Circom or gnark, targeting BLS12-381), run a trusted setup, generate the proof (in the
browser or on a backend), then compress the verification key and proof to Cardano's format. Only
then does the Aiken validator verify it as the spending condition. `references/proof-systems.md`
covers this pipeline and points to a complete written walkthrough.

### Step 5: Flag the sharp edges

Before they ship, walk the relevant items from the list below.

## Sharp edges

- **The circuit is the spec.** A property that is not constrained is not proven.
- **Trusted setup is a real ceremony.** Groth16 and PLONK setups produce toxic waste; whoever holds
  the setup randomness can forge proofs. A single-party setup is fine for a demo and unsafe for a
  real deployment — use a multi-party ceremony (secure if any one participant was honest).
- **Replay.** Bind every proof to its context (nonce / `OutputReference` / session key), or a proof
  read out of one transaction can be reused in another.
- **Public inputs cost.** Each public input adds real verification cost; keep them few and commit
  bulky data with a single hash instead.
- **Circuit-friendly hashes, on the right curve.** SHA-256 inside a circuit is enormous; use Poseidon
  or MiMC, and generate parameters for BLS12-381 or the in-circuit hash will not match your off-chain one.
- **Whoever runs the prover sees the witness.** Browser proving keeps the secret on the user's device;
  a proving server is a trust assumption — name it if you make it.
- **On-chain KDFs are not password hashing.** A password in a redeemer is public forever. See the KDF
  section for the narrow, legitimate uses.
- **Aggregation has a rogue-key trap.** Pick the BLS signing mode (basic / augmented / proof-of-possession)
  by your key-trust model — see `references/bls-primitives.md`.

## Confidence and iteration

The BLS12-381 builtins are stable and audited; the higher-level libraries and toolchains on top of
them are unaudited and still moving. Two practical notes:

- **The BLS stdlib API is still changing.** Some examples use `scalar.new(x) -> Option<Scalar>`
  (Aiken stdlib v2.1.0); newer stdlib replaces it with `scalar.from_int(x)`. Match the API to your
  pinned `aiken/stdlib` version.
- **BBS+ has the fewest Aiken implementations of the family.** Treat it as the least settled of these
  primitives, and check the current landscape in the ZK/BLS ecosystem map before depending on it.

Where a proof system, library, or cost figure is newer or less settled, say so rather than presenting
it as fixed.

## References

- `references/proof-systems.md` — SNARK verification: proof systems, the Groth16 shape, the pipeline, costs
- `references/bls-primitives.md` — signatures + aggregation, VRF, KDF, and BBS+ credentials
- Bundled: `docs/sources/developer-portal/.../smart-contracts/advanced/zero-knowledge.md` (landscape + app catalog),
  `docs/sources/aiken-stdlib/aiken/crypto/bls12_381/` (the API), `docs/sources/cips/` (CIP-0381 / 0133 / 0109)
- Named verifier and BLS libraries: the ZK/BLS section of `suggest-tooling` (ecosystem map)
- Shared principles: `../shared/PRINCIPLES.md`

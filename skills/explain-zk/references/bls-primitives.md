# BLS12-381 primitives: signatures, VRFs, KDFs, and credentials

The signature / VRF / KDF / credential half of `explain-zk`. Proof verification lives in
`proof-systems.md`. Everything here composes from the same operations — scalar multiplication, point
addition, hash-to-curve, and the pairing check — exposed through `aiken/crypto/bls12_381/g1` and
`/g2`, with the raw builtins under `aiken/builtin`. Named library implementations live in the ZK/BLS
ecosystem map (via `suggest-tooling`).

## The shared primitives

Keys and signatures are curve points. Deriving a public key is one scalar multiplication; signing is
a hash-to-curve followed by another:

```aiken
use aiken/builtin

fn hash_and_sign(sk: ByteArray, message: ByteArray, dst: ByteArray) -> ByteArray {
  let s = builtin.bytearray_to_integer(True, sk)
  expect s != 0
  let h = builtin.bls12_381_g2_hash_to_group(message, dst)
  builtin.bls12_381_g2_compress(builtin.bls12_381_g2_scalar_mul(s, h))
}
```

`dst` is a **domain separation tag**: a public string baked into the hash so a hash computed for a
signature can never collide with one computed for a VRF or any other protocol, even on identical
input. Keep public keys in G1 (48 bytes, long-lived, stored in datums) and signatures in G2 (96
bytes, transient) — the minimal-public-key-size convention.

Verifying a signature is the **pairing check** — the operation the whole curve exists for. It is a
Miller loop per point-pair, then one `final_verify`:

```aiken
use aiken/builtin.{
  bls12_381_final_verify, bls12_381_g2_hash_to_group, bls12_381_miller_loop,
}
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2

// e(pk, H(m)) == e(G1 generator, sig).
fn verify(pk: ByteArray, message: ByteArray, dst: ByteArray, sig: ByteArray) -> Bool {
  let hm = bls12_381_g2_hash_to_group(message, dst)
  bls12_381_final_verify(
    bls12_381_miller_loop(g1.decompress(pk), hm),
    bls12_381_miller_loop(g1.generator, g2.decompress(sig)),
  )
}
```

That is stdlib only — no external library. Everything below is an ergonomic wrapper over exactly this
pairing check.

## BLS signatures and aggregation

Because signatures are points, they **add together**. A hundred signatures aggregate into one 96-byte
value, and verification stays cheap. This is what makes large committees, vote tallies, and k-of-n
schemes with big n practical in one script budget. (For a small fixed signer set, native-script
multisig is simpler and needs no Plutus.)

A BLS signature library (`ilap/bls`) implements the IETF signature draft on top of the builtins, with a
small API: `sk_to_pk`, `sign`, `verify`, `aggregate`, `aggregate_verify`.

**Two aggregation patterns:**

- **Signature aggregation, distinct messages.** Each party signs its own message; the signatures sum
  into one. The verifier runs one pairing per `(public key, message)` pair. The witness is one
  signature instead of n.

  ```aiken
  use bls/g1/basic as basic_bls

  // Off-chain: anyone can aggregate the collected signatures.
  let sig_aggr = basic_bls.aggregate([sig1, sig2, sig3])
  // On-chain: one call covers all three signers.
  basic_bls.aggregate_verify([pk1, pk2, pk3], [msg1, msg2, msg3], sig_aggr)
  ```

  *Source: `ilap/bls` (Aiken dependency) — see the ecosystem map.*

- **Public-key aggregation, same message.** When everyone signs the *same* message, the public keys
  aggregate too (point addition in G1, 48 bytes total). Verification is then **two pairings, no matter
  how many signers** — the committee case. Aggregate the keys and the signatures, then verify:

  ```aiken
  use bls/api
  use bls/g1/basic as basic_bls
  use bls_extra/core as bls_extra_core

  // Off-chain: sum the public keys (one 48-byte value) and the signatures (one 96-byte value).
  let pk_aggr = bls_extra_core.aggregate_publickeys([pk1, pk2, pk3])
  let sig_aggr = basic_bls.aggregate([sig1, sig2, sig3])
  // On-chain: two pairings, constant cost no matter how many signers.
  bls_extra_core.aggregate_publickey_verify(pk_aggr, [message], sig_aggr, api.Basic)
  ```

  *Source: `bls_extra/core` from `cardano-foundation/bls`, with `ilap/bls` for signing — see the ecosystem map.*

  This holds **only in Basic mode with an identical message** (see the modes below).

### The rogue-key attack, and the three modes

Aggregation adds an attack plain signatures do not have. Seeing honest keys `pk_1` and `pk_2`, an
attacker can claim `pk_rogue = pk_att - (pk_1 + pk_2)`. They never knew the honest secrets, but the
aggregate `pk_1 + pk_2 + pk_rogue` collapses to `pk_att`, so a signature they produce alone verifies
as if all three signed. The IETF draft defines three modes; the difference is exactly how each kills
this attack.

| Mode | How it signs | Defense | Use when |
|---|---|---|---|
| **Basic** (`bls/g1/basic`) | The raw message | `aggregate_verify` rejects duplicate messages, so cancellation cannot pay off | Trusted or pre-validated keys, messages known distinct |
| **Augmented** (`bls/g1/aug`) | `pk ‖ message` | Each hash input is unique per signer, so a forged aggregate never matches | Untrusted keys that change often, duplicate messages allowed |
| **Proof-of-possession** (`bls/g1/pop`) | Registers each key once with a signature over itself | Registration proves the owner holds the secret; rogue keys cannot register | Fixed committees or pools that register once, sign many times |

One rule to respect: **public-key aggregation only works in Basic mode with an identical message.**
Augmented and PoP bind each signature to the individual key, so the pairing over an aggregated key no
longer balances; the Aug and Pop variants fail with more than one signer.

## Verifiable random functions

A VRF is a keyed hash with a public verification story: only the secret-key holder can compute the
output for an input, the output is deterministic and looks random to everyone else, and it comes with
a proof anyone can check. Three properties do the work: **verifiability**, **uniqueness** (exactly one
valid output per key and input — nothing to grind), and **non-interactivity**.

An ECVRF over BLS12-381 G2 runs in pure Aiken, with a four-function API and a 144-byte proof:

```aiken
use vrf/core as vrf

let (sk, pk) = vrf.keys_from_secret(operator_secret)
// Operator, per round: the input is public (a block hash, a round number).
let pi = vrf.prove(sk, round_input, "ECVRF_")
let Some(beta) = vrf.proof_to_hash(pi)
// Anyone, including a validator: recompute and confirm the same beta.
vrf.verify(pk, round_input, pi, "ECVRF_", False) == Some(beta)
```

*Source: the `vrf` example in `cardano-foundation/bls` — see the ecosystem map.*

What it buys you on-chain:

- **A randomness beacon a validator can enforce.** The input is public and fixed, so the operator gets
  exactly one possible output per round — no grinding. Verification is curve arithmetic on the same
  builtins, so the validator itself can check the proof rather than trusting an oracle's signature.
- **Enumeration-resistant data structures.** Key a public tree by the owner's VRF output instead of
  `hash(record_name)`, and outsiders see only unlinkable pseudorandom addresses while the owner can
  still prove membership later.
- **Leader selection and proofs of prior knowledge** — the same tool Ouroboros uses, in application space.

## Key derivation functions

Real inputs are messier than a curve-ready 32-byte secret. A KDF turns a seed, a shared secret, or a
password into a valid private key, reducing modulo the field order. Two, both implementable purely
from builtins:

- **HKDF** for high-entropy input — cheap (a 32-byte derivation measured around 15M CPU units). An
  `info` string gives domain separation, so one master secret yields many unlinkable keys.
- **PBKDF2** for low-entropy input — deliberately slow through iteration. On-chain the count must stay
  modest: ~10 iterations measured around 160M CPU units, while the classic off-chain 4096 iterations
  runs to billions, more than half a transaction budget.

```aiken
use kdf/keys
let (sk, pk) = keys.gen_keys_hkdf(salt: "my_salt", ikm: "high_entropy_secret")
```

*Source: the `kdf` example in `cardano-foundation/bls` — see the ecosystem map.*

**Critical caveat.** A password or salt passed through a datum or redeemer is published on-chain
permanently; anyone can extract it and rerun the KDF off-chain. On-chain KDFs are therefore **not** a
password-hashing mechanism. Their legitimate inputs are already-public or already-committed values
(a Diffie-Hellman shared secret), and their legitimate uses are narrow: deriving session or child keys
from strong secrets, and testing. Hash human passwords off-chain and put only the resulting key or hash
on-chain. **Memory-hard KDFs (Argon2, Balloon) are fundamentally incompatible with on-chain execution**
— their memory needs are orders of magnitude over the per-transaction budget.

## BBS+ anonymous credentials

BBS+ has the fewest Aiken implementations of the family — treat it as the least settled of these
primitives, and confirm the current landscape in the ZK/BLS ecosystem map before depending on it.

BBS+ turns a signed list of attributes into a privacy-preserving credential. An issuer signs n
attributes into one constant-size signature. Later the holder proves they hold a valid signature over
all n attributes **while revealing only a chosen subset** — "over 18 and an EU citizen", without the
birthdate, the name, or a trackable identifier. Each showing randomises the signature and wraps it in
a zero-knowledge proof, so showings cannot be linked to each other or to issuance.

On-chain it is the familiar shape: the issuer's key and the attribute schema sit in the datum, the
proof travels in the redeemer, and the challenge nonce is derived from the spent `OutputReference` so
a proof lifted from one transaction is useless in another.

```aiken
use bbs/types.{BBSProof, RegulatorRegistry}
use bbs/verify

validator bbs_credential {
  spend(datum: Option<RegulatorRegistry>, redeemer: BBSProof, own_ref, _self) {
    when datum is {
      Some(registry) ->
        verify.verify(registry, redeemer, nonce_from_output_reference(own_ref))
      None -> False
    }
  }
}
```

*Source: `lambdasistemi/cardano-bbs` — see the ecosystem map.*

Proof size is constant regardless of how many attributes the credential carries, and the dominant cost
is a few pairings — which is what makes membership, compliance, and identity checks with selective
disclosure practical in a Plutus budget.

## Where to go deeper

- Named verifier and BLS libraries: the ZK/BLS section of `suggest-tooling/references/ecosystem-map.md`.
- Bundled: `docs/sources/aiken-stdlib/aiken/crypto/bls12_381/` for the exact `g1` / `g2` / `scalar` APIs.

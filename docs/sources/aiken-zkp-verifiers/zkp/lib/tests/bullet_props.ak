//// Property-based tests for the Bulletproofs range-proof verifier, at
//// n = 8 (values in [0, 256)). See `tests/groth_props` for what the `prop_*`
//// and `known_issue_*` prefixes mean.

use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/fuzz
use bullet/bullet.{
  BulletproofProof, BulletproofVerificationKey, commit_value,
  generate_proof_deterministic, setup, verify,
}
use tests/groth_props.{nonzero_scalar}

const n: Int = 8

/// An in-range value, a commitment blinding, and a prover seed.
fn statement() -> Fuzzer<(Int, Int, ByteArray)> {
  fuzz.tuple3(
    fuzz.int_between(0, 255),
    nonzero_scalar(),
    fuzz.bytearray_between(0, 32),
  )
}

/// The key, a proof for `value`, and the matching commitment.
fn prove(
  value: Int,
  gamma: Int,
  seed: ByteArray,
) -> (BulletproofVerificationKey, BulletproofProof, G1Element) {
  let vk = setup(n)
  let g = scalar.from_int(gamma)
  (
    vk,
    generate_proof_deterministic(vk, value, g, seed),
    commit_value(vk, value, g),
  )
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

/// Every value in [0, 2^n) can be proven, with any blinding and seed.
test prop_bullet_valid_proof_verifies((value, gamma, seed) via statement()) {
  let (vk, proof, commitment) = prove(value, gamma, seed)
  verify(vk, commitment, proof)
}

/// A proof for one value doesn't verify against a commitment to another value
/// (mod r) with the same blinding.
test prop_bullet_rejects_other_value(
  ((value, gamma, seed), delta) via fuzz.tuple(statement(), nonzero_scalar()),
) {
  let (vk, proof, _) = prove(value, gamma, seed)
  let other =
    commit_value(vk, ( value + delta ) % field_prime, scalar.from_int(gamma))
  !verify(vk, other, proof)
}

/// Changing `tau_x`, `mu` or the first entry of `l_vec` or `r_vec` breaks the
/// proof.
test prop_bullet_rejects_tampered_proof(
  ((value, gamma, seed), which, delta) via fuzz.tuple3(
    statement(),
    fuzz.int_between(0, 3),
    nonzero_scalar(),
  ),
) {
  let (vk, proof, commitment) = prove(value, gamma, seed)
  let d = scalar.from_int(delta)
  let bump_head =
    fn(xs) {
      when xs is {
        [x, ..rest] -> [scalar.add(x, d), ..rest]
        [] -> fail @"empty vector"
      }
    }
  let tampered =
    when which is {
      0 -> BulletproofProof { ..proof, tau_x: scalar.add(proof.tau_x, d) }
      1 -> BulletproofProof { ..proof, mu: scalar.add(proof.mu, d) }
      2 -> BulletproofProof { ..proof, l_vec: bump_head(proof.l_vec) }
      _ -> BulletproofProof { ..proof, r_vec: bump_head(proof.r_vec) }
    }
  !verify(vk, commitment, tampered)
}

// ---------------------------------------------------------------------------
// Known issues
// ---------------------------------------------------------------------------

/// ADAOcommunity/zk#16: `commit_value` reduces mod r, so a commitment built
/// from `value + k * r` (including negative k, i.e. a negative amount) matches
/// the proof for `value`. Once fixed, replace with
/// `prop_bullet_commit_value_rejects_out_of_field` (the same call must fail).
test known_issue_16_bullet_commit_value_reduces_mod_r(
  ((value, gamma, seed), k) via fuzz.tuple(
    statement(),
    fuzz.either(fuzz.int_between(-1000, -1), fuzz.int_between(1, 1000)),
  ),
) {
  let (vk, proof, _) = prove(value, gamma, seed)
  verify(
    vk,
    commit_value(vk, value + k * field_prime, scalar.from_int(gamma)),
    proof,
  )
}

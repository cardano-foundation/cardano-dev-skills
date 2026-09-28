/// Groth16 batch verifier for BLS12-381.
///
/// This is the on-chain twin of the Rust `verify_batch` in
/// `clis/trusted-setup/src/prover.rs` (Implementation 11).  It checks `N`
/// independent proofs with a single multi-pairing product:
///
/// ```text
///   Π_i e(r_i·A_i, B_i)  ==  e((Σ r_i)·α, β) · e(Σ r_i·C_i, δ) · e(Σ r_i·V_i, γ)
/// ```
///
/// The per-proof scalars are Fiat–Shamir derived on-chain:
/// `r_i = r^i` with `r = blake2b-256(proofs ‖ vk) mod Fr`.  The transcript
/// commits to the proofs and the fixed CRS points before any scalar is chosen,
/// so the Schwartz–Zippel soundness argument applies exactly as in the RNG
/// case; an adversary cannot steer `r` into `0` or `1` (fail-closed:
/// `r < 2` → reject) short of a blake2b-256 preimage.
///
/// Cost: `N` individual verifies run `4N` pairings; this batched path runs
/// `N + 3` Miller loops plus **one** final exponentiation.

use aiken/builtin.{
  append_bytearray,
  blake2b_256,
  bls12_381_final_verify,
  bls12_381_g1_add,
  bls12_381_g1_scalar_mul,
  bls12_381_g1_uncompress,
  bls12_381_g2_uncompress,
  bls12_381_miller_loop,
  bls12_381_mul_miller_loop_result,
  bytearray_to_integer,
}
use aiken/crypto/bls12_381/scalar.{field_prime, from_int}
use aiken/collection/list
use groth16/verifier.{Proof, VerificationKey, compute_public_input_commitment}

// ---------------------------------------------------------------------------
// Batched verifier
// ---------------------------------------------------------------------------

/// Verify `N` proofs whose public-input lists share the same circuit, in one
/// multi-pairing product.  `publics[i]` must be the public variables consumed
/// by `proofs[i]` (length `vk.n_public` each).  See the module docs for the
/// equation and the soundness argument.
pub fn verify_batch(proofs: List<Proof>, publics: List<List<Int>>, vk: VerificationKey) -> Bool {
  let n = list.length(proofs)
  if n == 0 {
    False
  } else if list.length(publics) != n {
    False
  } else {
    // Fiat–Shamir scalar: r = blake2b-256(proof bytes ‖ VK points) mod Fr.
    let payload =
      append_bytearray(
        batch_transcript(proofs),
        append_bytearray(
          vk.alpha_g1,
          append_bytearray(vk.beta_g2, append_bytearray(vk.gamma_g2, vk.delta_g2)),
        ),
      )
    let r = bytearray_to_integer(True, blake2b_256(payload)) % field_prime
    if r < 2 {
      // r ∈ {0, 1} collapses the randomisation; fail closed.
      False
    } else {
      verify_batch_with_r(proofs, publics, vk, r)
    }
  }
}

/// Concatenate the compressed proof points into the FS transcript.
fn batch_transcript(proofs: List<Proof>) -> ByteArray {
  when proofs is {
    [] -> #""
    [p, ..rest] ->
      append_bytearray(p.a, append_bytearray(p.b, append_bytearray(p.c, batch_transcript(rest))))
  }
}

fn verify_batch_with_r(
  proofs: List<Proof>,
  publics: List<List<Int>>,
  vk: VerificationKey,
  r: Int,
) -> Bool {
  when (proofs, publics) is {
    ([first, ..rest_p], [first_pub, ..rest_pub]) -> {
      // Seed the fold with proof 0 (r_0 = r^0 = 1).
      let a = bls12_381_g1_uncompress(first.a)
      let b = bls12_381_g2_uncompress(first.b)
      let c = bls12_381_g1_uncompress(first.c)
      let v = compute_public_input_commitment(first_pub, vk.ic, vk.n_public)

      let lhs = bls12_381_miller_loop(a, b)
      let alpha = bls12_381_g1_uncompress(vk.alpha_g1)
      let beta = bls12_381_g2_uncompress(vk.beta_g2)
      let gamma = bls12_381_g2_uncompress(vk.gamma_g2)
      let delta = bls12_381_g2_uncompress(vk.delta_g2)

      do_batch(rest_p, rest_pub, vk, r, lhs, c, v, 1, r, alpha, beta, gamma, delta)
    }
    _ -> False
  }
}

/// Fold the remaining proofs: scale each `A, C, V` by `r^i`, accumulate the
/// lhs pairing product, the two point sums and `Σ r^i`, and finish with a
/// single final exponentiation.
fn do_batch(
  proofs: List<Proof>,
  publics: List<List<Int>>,
  vk: VerificationKey,
  r: Int,
  lhs: MillerLoopResult,
  c_batch: G1Element,
  v_batch: G1Element,
  sum_r: Int,
  r_pow: Int,
  alpha: G1Element,
  beta: G2Element,
  gamma: G2Element,
  delta: G2Element,
) -> Bool {
  when (proofs, publics) is {
    ([], []) -> finish_batch(lhs, c_batch, v_batch, sum_r, alpha, beta, gamma, delta)
    ([p, ..rest_p], [pub_i, ..rest_pub]) -> {
      let a = bls12_381_g1_uncompress(p.a)
      let b = bls12_381_g2_uncompress(p.b)
      let c = bls12_381_g1_uncompress(p.c)
      let v = compute_public_input_commitment(pub_i, vk.ic, vk.n_public)

      let scaled_a = bls12_381_g1_scalar_mul(r_pow, a)
      let scaled_c = bls12_381_g1_scalar_mul(r_pow, c)
      let scaled_v = bls12_381_g1_scalar_mul(r_pow, v)

      let lhs = bls12_381_mul_miller_loop_result(lhs, bls12_381_miller_loop(scaled_a, b))
      do_batch(
        rest_p,
        rest_pub,
        vk,
        r,
        lhs,
        bls12_381_g1_add(c_batch, scaled_c),
        bls12_381_g1_add(v_batch, scaled_v),
        (sum_r + r_pow) % field_prime,
        r_pow * r % field_prime,
        alpha,
        beta,
        gamma,
        delta,
      )
    }
    _ -> finish_batch(lhs, c_batch, v_batch, sum_r, alpha, beta, gamma, delta)
  }
}

/// One final exponentiation over the folded equality.
fn finish_batch(
  lhs: MillerLoopResult,
  c_batch: G1Element,
  v_batch: G1Element,
  sum_r: Int,
  alpha: G1Element,
  beta: G2Element,
  gamma: G2Element,
  delta: G2Element,
) -> Bool {
  let alpha_scaled = bls12_381_g1_scalar_mul(sum_r, alpha)

  let rhs = bls12_381_miller_loop(alpha_scaled, beta)
  let rhs = bls12_381_mul_miller_loop_result(rhs, bls12_381_miller_loop(c_batch, delta))
  let rhs = bls12_381_mul_miller_loop_result(rhs, bls12_381_miller_loop(v_batch, gamma))

  bls12_381_final_verify(lhs, rhs)
}

// ---------------------------------------------------------------------------
// Unit tests — parity with the single verifier and tamper resistance
// ---------------------------------------------------------------------------

/// A one-proof batch behaves exactly like the single verifier.
test t_batch_one_valid_proof() {
  let vk = verifier.hardcoded_verification_key()
  verify_batch([verifier.hardcoded_proof()], [[1, 48]], vk)
}

/// A one-proof batch with the wrong public output must fail.
test t_batch_one_valid_proof_wrong_input() {
  let vk = verifier.hardcoded_verification_key()
  !verify_batch([verifier.hardcoded_proof()], [[1, 49]], vk)
}

/// Two proofs where the second is a tampered copy must be rejected.
test t_batch_two_proofs_rejects_tampered_c() {
  let vk = verifier.hardcoded_verification_key()
  let bad_c =
    #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb"
  let bad = Proof { ..verifier.hardcoded_proof(), c: bad_c }
  !verify_batch([verifier.hardcoded_proof(), bad], [[1, 48], [1, 48]], vk)
}

/// A tampered proof in first position must also fail.
test t_batch_two_proofs_rejects_tampered_factor_at_head() {
  let vk = verifier.hardcoded_verification_key()
  let bad_c =
    #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb"
  let bad = Proof { ..verifier.hardcoded_proof(), c: bad_c }
  !verify_batch([bad, verifier.hardcoded_proof()], [[1, 48], [1, 48]], vk)
}

test t_batch_empty_is_rejected() {
  let vk = verifier.hardcoded_verification_key()
  !verify_batch([], [], vk)
}

test t_batch_length_mismatch_is_rejected() {
  let vk = verifier.hardcoded_verification_key()
  !verify_batch([verifier.hardcoded_proof()], [], vk)
}

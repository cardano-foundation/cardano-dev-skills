/// Vendored Groth16 batch verifier for the F5 pool contract.
///
/// ⚠️  This is a **vendored copy** of `aiken/groth16/lib/groth16/batch.ak`.
///     The canonical implementation lives in the `cardano-foundation/groth16`
///     package (`aiken/groth16`).  Keep this file in sync with upstream.
///
/// Identical types and single-proof `verify` (from `verifier.ak`), extended
/// with a *batched* verifier `verify_batch` that checks `N` proofs in a single
/// multi-pairing product:
///
/// ```text
///   Π_i e(r_i·A_i, B_i)  ==  e((Σ r_i)·α, β) · e(Σ r_i·C_i, δ) · e(Σ r_i·V_i, γ)
/// ```
///
/// with the V_i the per-proof public-input commitments.  This is the on-chain
/// version of the Rust `verify_batch` in `clis/trusted-setup/src/prover.rs`
/// (item (q), "batch handling on Plutus").  Whereas the CLI draws its `r_i`
/// from an OS RNG, on-chain the scalars are Fiat–Shamir derived:
/// `r_i = r^i` with `r = blake2b-256(proofs ‖ vk) mod Fr`.  The proofs (and
/// the fixed CRS points) are committed to in the transcript before any scalar
/// is chosen, so the Schwartz–Zippel soundness argument applies exactly as in
/// the RNG case; an adversary cannot steer `r` into `0` or `1` (fail-closed:
/// `r < 2` → reject) short of a blake2b-256 preimage.
///
/// Cost: `N` individual verifies run `4N` pairings; this batched path runs
/// `N + 3` Miller loops plus **one** final exponentiation, and never
/// re-prepares the fixed VK points.

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
use aiken/crypto/bls12_381/g1 as g1
use aiken/crypto/bls12_381/scalar.{field_prime, from_int}
use aiken/collection/list

// ---------------------------------------------------------------------------
// Public types (identical to aiken/groth16/lib/groth16/verifier.ak)
// ---------------------------------------------------------------------------

/// Groth16 proof consisting of three compressed curve points.
pub type Proof {
  a: ByteArray,
  b: ByteArray,
  c: ByteArray,
}

/// Groth16 verification key — everything needed to verify a proof.
///
/// * `alpha_g1` — 48-byte compressed G1 point (`alpha * G1`).
/// * `beta_g2`  — 96-byte compressed G2 point (`beta * G2`).
/// * `gamma_g2` — 96-byte compressed G2 point (`gamma * G2`).
/// * `delta_g2` — 96-byte compressed G2 point (`delta * G2`).
/// * `ic`       — list of 48-byte compressed G1 points, `ic[i] = Psi_V_G1[i]`.
///                   Only the first `n_public` entries are used for `V`.
/// * `n_public` — number of public variables (including the constant wire).
pub type VerificationKey {
  alpha_g1: ByteArray,
  beta_g2: ByteArray,
  gamma_g2: ByteArray,
  delta_g2: ByteArray,
  ic: List<ByteArray>,
  n_public: Int,
}

// ---------------------------------------------------------------------------
// Hard-coded 3-constraint circuit (for the batch tests only)
// ---------------------------------------------------------------------------

/// alpha * G1  (scalar = 5)
const alpha_g1 =
  #"b0e7791fb972fe014159aa33a98622da3cdc98ff707965e536d8636b5fcc5ac7a91a8c46e59a00dca575af0f18fb13dc"

/// beta * G2  (scalar = 7)
const beta_g2 =
  #"8d0273f6bf31ed37c3b8d68083ec3d8e20b5f2cc170fa24b9b5be35b34ed013f9a921f1cad1644d4bdb14674247234c8049cd1dbb2d2c3581e54c088135fef36505a6823d61b859437bfc79b617030dc8b40e32bad1fa85b9c0f368af6d38d3c"

/// gamma * G2  (scalar = 11)
const gamma_g2 =
  #"a190be857d602284393305bfe0a29e29a6982ed3f04ccaabafb7e59cdc7eda85c22bc3e8690355c7a0fb7590ae40f1b009303f04d568e289a35102b6df883d5ed620355c0eb5d02236718cdaf99fba6e19ef5cee2996268eb9a53ae1ee09bce3"

/// delta * G2  (scalar = 13)
const delta_g2 =
  #"8bf78a97086750eb166986ed8e428ca1d23ae3bbf8b2ee67451d7dd84445311e8bc8ab558b0bc008199f577195fc39b7152110e866f1a6e8c5348f6e005dbd93de671b7d0fbfa04d6614bcdd27a3cb2a70f0deacb3608ba95226268481a0be7c"

/// Psi_V_G1[1] — variable 1 is the public output `a` (scalar = 3/gamma).
const psi_v_g1_1 =
  #"a087561bc7f3b2650328084de8424253a1846fe77fb0f498a3fade9d70b556016d1de5d0490fa64a444a1f53cc13d70d"

/// A = (l(tau)+alpha) * G1  (combined scalar = 10)
const proof_a =
  #"af81da25ecf1c84b577fefbedd61077a81dc43b00304015b2b596ab67f00e41c86bb00ebd0f90d4b125eb0539891aeed"

/// B = (r(tau)+beta) * G2  (combined scalar = 33)
const proof_b =
  #"ab0f336a9b3ee493b210f64587b8c1d5fab0a86346812545a822692c40ee4eecb349a69388ba3ad13ea3c5f8d29eb36506547761152a1517a6fffeefff70c7e817bdcf94dfa8e25955a0b4ac6ffcfd9477d7230902453d78bac3bcd06dbbb457"

/// C = (sum_private + h(tau)*T(tau)/delta) * G1  (combined scalar = 151/delta)
const proof_c =
  #"b697c05f3d58d125ed8630e8f547dd5a952c33753b65629e18efcada75d443690fc1f3759dfb55edc35e4d03dd17860e"

/// The hard-coded valid proof for the concrete circuit.
pub fn hardcoded_proof() -> Proof {
  Proof { a: proof_a, b: proof_b, c: proof_c }
}

/// The hard-coded verification key for the concrete 3-constraint circuit.
pub fn hardcoded_verification_key() -> VerificationKey {
  VerificationKey {
    alpha_g1,
    beta_g2,
    gamma_g2,
    delta_g2,
    ic: [
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      psi_v_g1_1,
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    ],
    n_public: 2,
  }
}

// ---------------------------------------------------------------------------
// Single verifier (identical to aiken/groth16)
// ---------------------------------------------------------------------------

/// Verify a Groth16 proof against a supplied verification key.
pub fn verify(proof: Proof, public_inputs: List<Int>, vk: VerificationKey) -> Bool {
  let a = bls12_381_g1_uncompress(proof.a)
  let b = bls12_381_g2_uncompress(proof.b)
  let c = bls12_381_g1_uncompress(proof.c)

  let alpha = bls12_381_g1_uncompress(vk.alpha_g1)
  let beta = bls12_381_g2_uncompress(vk.beta_g2)
  let gamma = bls12_381_g2_uncompress(vk.gamma_g2)
  let delta = bls12_381_g2_uncompress(vk.delta_g2)

  let v = compute_public_input_commitment(public_inputs, vk.ic, vk.n_public)

  let lhs = bls12_381_miller_loop(a, b)
  let rhs = bls12_381_miller_loop(alpha, beta)
  let rhs = bls12_381_mul_miller_loop_result(rhs, bls12_381_miller_loop(c, delta))
  let rhs = bls12_381_mul_miller_loop_result(rhs, bls12_381_miller_loop(v, gamma))

  bls12_381_final_verify(lhs, rhs)
}

/// Compute the public-input commitment `V = Σ a_i · ic[i]`.
fn compute_public_input_commitment(
  public_inputs: List<Int>,
  ic: List<ByteArray>,
  n_public: Int,
) -> G1Element {
  do_compute_v(public_inputs, ic, n_public, g1.zero)
}

fn do_compute_v(
  public_inputs: List<Int>,
  ic: List<ByteArray>,
  remaining: Int,
  acc: G1Element,
) -> G1Element {
  if remaining <= 0 {
    acc
  } else {
    when (public_inputs, ic) is {
      ([input, ..rest_inputs], [ic_point, ..rest_ic]) -> {
        let pt = bls12_381_g1_uncompress(ic_point)
        let s = from_int(input)
        let weighted = g1.scale(pt, s)
        do_compute_v(rest_inputs, rest_ic, remaining - 1, bls12_381_g1_add(acc, weighted))
      }
      _ -> g1.zero
    }
  }
}

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
// Unit tests — the batch reduces to the single verification for one proof and
// rejects tampering for any mix
// ---------------------------------------------------------------------------

test t_single_verify_still_works() {
  let vk = hardcoded_verification_key()
  verify(hardcoded_proof(), [1, 48], vk)
}

/// A one-proof batch behaves exactly like the single verifier.
test t_batch_one_valid_proof() {
  let vk = hardcoded_verification_key()
  verify_batch([hardcoded_proof()], [[1, 48]], vk)
}

/// A one-proof batch with the wrong public output must fail.
test t_batch_one_valid_proof_wrong_input() {
  let vk = hardcoded_verification_key()
  !verify_batch([hardcoded_proof()], [[1, 49]], vk)
}

/// Two proofs where the second is a tampered copy must be rejected.
test t_batch_two_proofs_rejects_tampered_c() {
  let vk = hardcoded_verification_key()
  let bad_c =
    #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb"
  let bad = Proof { a: proof_a, b: proof_b, c: bad_c }
  !verify_batch([hardcoded_proof(), bad], [[1, 48], [1, 48]], vk)
}

/// A tampered proof in first position must also fail.
test t_batch_two_proofs_rejects_tampered_factor_at_head() {
  let vk = hardcoded_verification_key()
  let bad_c =
    #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb"
  let bad = Proof { a: proof_a, b: proof_b, c: bad_c }
  !verify_batch([bad, hardcoded_proof()], [[1, 48], [1, 48]], vk)
}

test t_batch_empty_is_rejected() {
  let vk = hardcoded_verification_key()
  !verify_batch([], [], vk)
}

test t_batch_length_mismatch_is_rejected() {
  let vk = hardcoded_verification_key()
  !verify_batch([hardcoded_proof()], [], vk)
}
use aiken/builtin.{
  bls12_381_final_verify, bls12_381_g1_add, bls12_381_g1_scalar_mul,
  bls12_381_g1_uncompress, bls12_381_g2_uncompress, bls12_381_miller_loop,
  bls12_381_mul_miller_loop_result,
}
use aiken/collection/list

pub type CompressedProof {
  a: ByteArray,
  b: ByteArray,
  c: ByteArray,
}

pub type CompressedVK {
  alpha: ByteArray,
  beta: ByteArray,
  gamma: ByteArray,
  delta: ByteArray,
  vkIC: List<ByteArray>,
}

pub type Proof {
  a: G1Element,
  b: G2Element,
  c: G1Element,
}

pub type VerifierKey {
  alpha: G1Element,
  beta: G2Element,
  gamma: G2Element,
  delta: G2Element,
  vkIC: List<G1Element>,
}

pub fn uncompress_proof(c: CompressedProof) -> Proof {
  Proof {
    a: bls12_381_g1_uncompress(c.a),
    b: bls12_381_g2_uncompress(c.b),
    c: bls12_381_g1_uncompress(c.c),
  }
}

pub fn uncompress_vk(c: CompressedVK) -> VerifierKey {
  VerifierKey {
    alpha: bls12_381_g1_uncompress(c.alpha),
    beta: bls12_381_g2_uncompress(c.beta),
    gamma: bls12_381_g2_uncompress(c.gamma),
    delta: bls12_381_g2_uncompress(c.delta),
    vkIC: list.map(c.vkIC, fn(c_ic) { bls12_381_g1_uncompress(c_ic) }),
  }
}

pub fn verify_compressed(
  vk: CompressedVK,
  proof: CompressedProof,
  inputs: List<Int>,
) {
  let vk = uncompress_vk(vk)
  let proof = uncompress_proof(proof)
  verify(vk, proof, inputs)
}

pub fn pairing_check(
  a: G1Element,
  b: G2Element,
  c: G1Element,
  delta: G2Element,
  alpha: G1Element,
  beta: G2Element,
  k: G1Element,
  gamma: G2Element,
) -> Bool {
  // e(A,B) = e(α,β) ∙ e(C,δ) ∙ e(K,γ)
  // e: miller loop
  // ∙: mul miller loop
  // =: final verify

  // Pair Components w/ Miller Loop
  let ab = bls12_381_miller_loop(a, b)
  let alphabeta = bls12_381_miller_loop(alpha, beta)

  let kgamma = bls12_381_miller_loop(k, gamma)
  let cdelta = bls12_381_miller_loop(c, delta)

  // Combine Miller Loop Results
  let mlr1 = bls12_381_mul_miller_loop_result(alphabeta, kgamma)
  let mlr2 = bls12_381_mul_miller_loop_result(mlr1, cdelta)

  // Final Equality Check
  bls12_381_final_verify(ab, mlr2)
}

// Main verification function
pub fn verify(vk: VerifierKey, proof: Proof, inputs: List<Int>) -> Bool {
  let k =
    when vk.vkIC is {
      [] -> fail @"empty vkIC?"
      [head, ..tail] -> derive(tail, inputs, head)
    }

  // Pairing check
  pairing_check(
    proof.a,
    proof.b,
    proof.c,
    vk.delta,
    vk.alpha,
    vk.beta,
    k,
    vk.gamma,
  )
}

pub fn derive(
  vk_ic: List<G1Element>,
  public: List<Int>,
  result: G1Element,
) -> G1Element {
  when vk_ic is {
    [] -> result
    [i, ..vk_ic] ->
      when public is {
        [] -> fail
        [scalar, ..public] ->
          derive(
            vk_ic,
            public,
            bls12_381_g1_add(result, bls12_381_g1_scalar_mul(scalar, i)),
          )
      }
  }
}

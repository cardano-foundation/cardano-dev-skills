use aiken/crypto/bls12_381/scalar
use common/blst_affine.{
  G1Affine, G2Affine, g1_affine_compress, g2_affine_compress,
}
use plonk/preinputs.{
  PlonkPreInputs, PreparedPlonkPreInputs, plonk_prepare_preinputs,
}
use plonk/proofs.{PlonkProof}

pub type AffineVerificationKey {
  n_public: Int,
  power: Int,
  k1: Int,
  k2: Int,
  q_m: G1Affine,
  q_l: G1Affine,
  q_r: G1Affine,
  q_o: G1Affine,
  q_c: G1Affine,
  s_sig1: G1Affine,
  s_sig2: G1Affine,
  s_sig3: G1Affine,
  x2: G2Affine,
  w: Int,
}

pub type AffineProof {
  commitment_a: G1Affine,
  commitment_b: G1Affine,
  commitment_c: G1Affine,
  commitment_z: G1Affine,
  t_low: G1Affine,
  t_mid: G1Affine,
  t_high: G1Affine,
  w_omega: G1Affine,
  w_omega_zeta: G1Affine,
  a_eval: Int,
  b_eval: Int,
  c_eval: Int,
  s_sig1_p: Int,
  s_sig2_p: Int,
  z_omega: Int,
}

pub fn prepare_affine_vkey(
  vkey: AffineVerificationKey,
) -> PreparedPlonkPreInputs {
  let preinputs =
    PlonkPreInputs {
      power: vkey.power,
      k1: scalar.from_int(vkey.k1),
      k2: scalar.from_int(vkey.k2),
      q_m: g1_affine_compress(vkey.q_m),
      q_l: g1_affine_compress(vkey.q_l),
      q_r: g1_affine_compress(vkey.q_r),
      q_o: g1_affine_compress(vkey.q_o),
      q_c: g1_affine_compress(vkey.q_c),
      s_sig1: g1_affine_compress(vkey.s_sig1),
      s_sig2: g1_affine_compress(vkey.s_sig2),
      s_sig3: g1_affine_compress(vkey.s_sig3),
      x2: g2_affine_compress(vkey.x2),
    }
  plonk_prepare_preinputs(
    inputs: preinputs,
    generator: scalar.from_int(vkey.w),
    n_public: vkey.n_public,
  )
}

pub fn prepare_affine_proof(proof: AffineProof) -> PlonkProof {
  PlonkProof {
    commitment_a: g1_affine_compress(proof.commitment_a),
    commitment_b: g1_affine_compress(proof.commitment_b),
    commitment_c: g1_affine_compress(proof.commitment_c),
    commitment_z: g1_affine_compress(proof.commitment_z),
    t_low: g1_affine_compress(proof.t_low),
    t_mid: g1_affine_compress(proof.t_mid),
    t_high: g1_affine_compress(proof.t_high),
    w_omega: g1_affine_compress(proof.w_omega),
    w_omega_zeta: g1_affine_compress(proof.w_omega_zeta),
    a_eval: proof.a_eval,
    b_eval: proof.b_eval,
    c_eval: proof.c_eval,
    s_sig1_p: proof.s_sig1_p,
    s_sig2_p: proof.s_sig2_p,
    z_omega: proof.z_omega,
  }
}

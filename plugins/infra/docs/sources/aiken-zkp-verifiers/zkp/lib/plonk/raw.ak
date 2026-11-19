use aiken/crypto/bls12_381/scalar
use common/common.{G1Point, G2Point, g1_compress, g2_compress}
use plonk/preinputs.{
  PlonkPreInputs, PreparedPlonkPreInputs, plonk_prepare_preinputs,
}
use plonk/proofs.{PlonkProof}

pub type PlonkVerificationKey {
  n_public: Int,
  power: Int,
  k1: Int,
  k2: Int,
  q_m: G1Point,
  q_l: G1Point,
  q_r: G1Point,
  q_o: G1Point,
  q_c: G1Point,
  s_sig1: G1Point,
  s_sig2: G1Point,
  s_sig3: G1Point,
  x2: G2Point,
  w: Int,
}

pub type RawPlonkProof {
  commitment_a: G1Point,
  commitment_b: G1Point,
  commitment_c: G1Point,
  commitment_z: G1Point,
  t_low: G1Point,
  t_mid: G1Point,
  t_high: G1Point,
  w_omega: G1Point,
  w_omega_zeta: G1Point,
  a_eval: Int,
  b_eval: Int,
  c_eval: Int,
  s_sig1_p: Int,
  s_sig2_p: Int,
  z_omega: Int,
}

pub fn vkey_to_prepared_preinputs(
  vkey: PlonkVerificationKey,
) -> PreparedPlonkPreInputs {
  let preinputs =
    PlonkPreInputs {
      power: vkey.power,
      k1: scalar.from_int(vkey.k1),
      k2: scalar.from_int(vkey.k2),
      q_m: g1_compress(vkey.q_m),
      q_l: g1_compress(vkey.q_l),
      q_r: g1_compress(vkey.q_r),
      q_o: g1_compress(vkey.q_o),
      q_c: g1_compress(vkey.q_c),
      s_sig1: g1_compress(vkey.s_sig1),
      s_sig2: g1_compress(vkey.s_sig2),
      s_sig3: g1_compress(vkey.s_sig3),
      x2: g2_compress(vkey.x2),
    }

  plonk_prepare_preinputs(
    inputs: preinputs,
    generator: scalar.from_int(vkey.w),
    n_public: vkey.n_public,
  )
}

pub fn prepare_raw_proof(proof: RawPlonkProof) -> PlonkProof {
  PlonkProof {
    commitment_a: g1_compress(proof.commitment_a),
    commitment_b: g1_compress(proof.commitment_b),
    commitment_c: g1_compress(proof.commitment_c),
    commitment_z: g1_compress(proof.commitment_z),
    t_low: g1_compress(proof.t_low),
    t_mid: g1_compress(proof.t_mid),
    t_high: g1_compress(proof.t_high),
    w_omega: g1_compress(proof.w_omega),
    w_omega_zeta: g1_compress(proof.w_omega_zeta),
    a_eval: proof.a_eval,
    b_eval: proof.b_eval,
    c_eval: proof.c_eval,
    s_sig1_p: proof.s_sig1_p,
    s_sig2_p: proof.s_sig2_p,
    z_omega: proof.z_omega,
  }
}

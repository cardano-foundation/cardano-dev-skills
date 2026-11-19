use aiken/builtin.{keccak_256}
use aiken/collection/list
use aiken/crypto/bitwise.{State}
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2
use aiken/crypto/bls12_381/pairing.{final_exponentiation, miller_loop}
use aiken/crypto/bls12_381/scalar.{Scalar, scale2}
use common/common.{concat_and_keccak_256, g1_sum, scalar_sum}
use plonk/preinputs.{PreparedPlonkPreInputs}
use plonk/proofs.{PreparedPlonkProof}

pub fn verify_plonk(
  preinputs: PreparedPlonkPreInputs,
  pub_inputs: List<Int>,
  proof: PreparedPlonkProof,
) -> Bool {
  // compress the inputs
  let q_m = g1.compress(preinputs.q_m)
  let q_l = g1.compress(preinputs.q_l)
  let q_r = g1.compress(preinputs.q_r)
  let q_o = g1.compress(preinputs.q_o)
  let q_c = g1.compress(preinputs.q_c)
  let s_sig1 = g1.compress(preinputs.s_sig1)
  let s_sig2 = g1.compress(preinputs.s_sig2)
  let s_sig3 = g1.compress(preinputs.s_sig3)

  // compress the proof commitments
  let bs_commitment_a = g1.compress(proof.commitment_a)
  let bs_commitment_b = g1.compress(proof.commitment_b)
  let bs_commitment_c = g1.compress(proof.commitment_c)
  let bs_commitment_z = g1.compress(proof.commitment_z)
  let bs_t_low = g1.compress(proof.t_low)
  let bs_t_mid = g1.compress(proof.t_mid)
  let bs_t_high = g1.compress(proof.t_high)
  let bs_w_omega = g1.compress(proof.w_omega)
  let bs_w_omega_zeta = g1.compress(proof.w_omega_zeta)

  // prepare negated public inputs for polynomial evaluation
  let w_all: List<State<Scalar>> =
    list.map(pub_inputs, fn(x) { scalar.neg(scalar.from_int(x)) })

  // w (root of unity), used directly in the pairing check
  let gen_w = preinputs.generator

  // define scalar constants
  let scalar1: State<Scalar> = scalar.from_int(1)

  // compute Fiat-Shamir challenges (BE encoding, keccak-256, all pub inputs)
  // matching snarkjs's keccak256-compressed transcript variant
  let pub_input_bytes =
    list.map(pub_inputs, fn(x) { scalar.to_bytes(scalar.from_int(x)) })
  let beta: State<Scalar> =
    scalar.from_bytes(
      concat_and_keccak_256(
        list.concat(
          [q_m, q_l, q_r, q_o, q_c, s_sig1, s_sig2, s_sig3],
          list.concat(
            pub_input_bytes,
            [bs_commitment_a, bs_commitment_b, bs_commitment_c],
          ),
        ),
      ),
    )
  let gamma: State<Scalar> =
    scalar.from_bytes(keccak_256(scalar.to_bytes(beta)))
  let alpha: State<Scalar> =
    scalar.from_bytes(
      concat_and_keccak_256(
        [scalar.to_bytes(beta), scalar.to_bytes(gamma), bs_commitment_z],
      ),
    )
  let zeta: State<Scalar> =
    scalar.from_bytes(
      concat_and_keccak_256(
        [scalar.to_bytes(alpha), bs_t_low, bs_t_mid, bs_t_high],
      ),
    )
  let v: State<Scalar> =
    scalar.from_bytes(
      concat_and_keccak_256(
        [
          scalar.to_bytes(zeta),
          scalar.to_bytes(proof.a_eval),
          scalar.to_bytes(proof.b_eval),
          scalar.to_bytes(proof.c_eval),
          scalar.to_bytes(proof.s_sig1_p),
          scalar.to_bytes(proof.s_sig2_p),
          scalar.to_bytes(proof.z_omega),
        ],
      ),
    )
  let u: State<Scalar> =
    scalar.from_bytes(concat_and_keccak_256([bs_w_omega, bs_w_omega_zeta]))

  // compute powers of zeta for polynomial evaluation
  let pow2_zeta_p: State<Scalar> = scale2(zeta, preinputs.power)
  let pow2_zeta_p_minus_1: State<Scalar> = scalar.sub(pow2_zeta_p, scalar1)

  // calculate lagrange polynomials
  let lagrange_polys: List<State<Scalar>> =
    list.map2(
      preinputs.generators,
      proof.lagrange_inverses,
      fn(x, y) { scalar.mul(scalar.mul(x, pow2_zeta_p_minus_1), y) },
    )
  expect Some(lagrange_poly_head) = list.head(lagrange_polys)

  // compute public input polynomial evaluation at zeta
  let pi_zeta: State<Scalar> =
    scalar_sum(
      list.map2(w_all, lagrange_polys, fn(w, lag) { scalar.mul(w, lag) }),
    )

  // compute derived scalars for verification equations
  let alpha_sq = scalar.mul(alpha, alpha)
  let alpha_z_omega = scalar.mul(alpha, proof.z_omega)
  let beta_zeta = scalar.mul(beta, zeta)
  // compute shifted witness polynomials
  let a_gamma = scalar.add(proof.a_eval, gamma)
  let b_gamma = scalar.add(proof.b_eval, gamma)
  let c_gamma = scalar.add(proof.c_eval, gamma)
  let beta_s1 = scalar.mul(beta, proof.s_sig1_p)
  let beta_s2 = scalar.mul(beta, proof.s_sig2_p)

  // compute linearization polynomial r(zeta)
  let r0 =
    scalar.sub(
      scalar.sub(pi_zeta, scalar.mul(lagrange_poly_head, alpha_sq)),
      scalar.mul(
        alpha_z_omega,
        scalar.mul(
          scalar.add(a_gamma, beta_s1),
          scalar.mul(scalar.add(b_gamma, beta_s2), c_gamma),
        ),
      ),
    )

  // batch constraint polynomial commitments
  let constraint_commitments =
    g1_sum(
      [
        g1.scale(preinputs.q_m, scalar.mul(proof.a_eval, proof.b_eval)),
        g1.scale(preinputs.q_l, proof.a_eval),
        g1.scale(preinputs.q_r, proof.b_eval),
        g1.scale(preinputs.q_o, proof.c_eval),
        preinputs.q_c,
        g1.scale(
          proof.commitment_z,
          {
            let product =
              scalar.add(a_gamma, beta_zeta)
                |> scalar.mul(
                    scalar.add(b_gamma, scalar.mul(beta_zeta, preinputs.k1)),
                  )
                |> scalar.mul(
                    scalar.add(c_gamma, scalar.mul(beta_zeta, preinputs.k2)),
                  )
                |> scalar.mul(alpha)
            scalar.add(
              scalar.add(product, scalar.mul(lagrange_poly_head, alpha_sq)),
              u,
            )
          },
        ),
        g1.scale(
          preinputs.s_sig3,
          scalar.neg(
            scalar.mul(
              scalar.mul(
                scalar.add(a_gamma, beta_s1),
                scalar.add(b_gamma, beta_s2),
              ),
              scalar.mul(alpha_z_omega, beta),
            ),
          ),
        ),
        g1.scale(
          g1.add(
            proof.t_low,
            g1.add(
              g1.scale(proof.t_mid, pow2_zeta_p),
              g1.scale(proof.t_high, scale2(pow2_zeta_p, 1)),
            ),
          ),
          scalar.neg(pow2_zeta_p_minus_1),
        ),
      ],
    )

  // combine batched polynomial commitments
  let batched_polynomial_commitments =
    g1.add(
      constraint_commitments,
      {
        let sigma_witness_commits =
          g1.add(preinputs.s_sig1, g1.scale(preinputs.s_sig2, v))
            |> g1.scale(v)
            |> g1.add(proof.commitment_c, _)
            |> g1.scale(v)
            |> g1.add(proof.commitment_b, _)
            |> g1.scale(v)
            |> g1.add(proof.commitment_a, _)
        g1.scale(sigma_witness_commits, v)
      },
    )

  // batch evaluations
  let group_encoded_batch_eval =
    g1.scale(
      g1.generator,
      {
        let sigma_witness_evals =
          scalar.add(proof.s_sig1_p, scalar.mul(v, proof.s_sig2_p))
            |> scalar.mul(v, _)
            |> scalar.add(proof.c_eval, _)
            |> scalar.mul(v, _)
            |> scalar.add(proof.b_eval, _)
            |> scalar.mul(v, _)
            |> scalar.add(proof.a_eval, _)
        scalar.add(
          scalar.add(scalar.neg(r0), scalar.mul(v, sigma_witness_evals)),
          scalar.mul(u, proof.z_omega),
        )
      },
    )

  // verify polynomial evaluations
  let miller_loop_1 =
    miller_loop(
      g1.add(proof.w_omega, g1.scale(proof.w_omega_zeta, u)),
      preinputs.x2,
    )

  // verify constraint satisfaction
  let miller_loop_2 =
    miller_loop(
      g1.add(
        g1.add(
          g1.scale(proof.w_omega, zeta),
          g1.scale(proof.w_omega_zeta, scalar.mul(u, scalar.mul(zeta, gen_w))),
        ),
        g1.sub(batched_polynomial_commitments, group_encoded_batch_eval),
      ),
      g2.generator,
    )

  let final_verification = final_exponentiation(miller_loop_1, miller_loop_2)

  // verify lagrange polynomial inverses
  let lagrange_check =
    list.all(
      list.map2(
        proof.lagrange_inverses,
        preinputs.generators,
        fn(inv, gen) {
          scalar.mul(
            inv,
            scalar.mul(scalar.from_int(preinputs.n), scalar.sub(zeta, gen)),
          ) == scalar.from_int(1)
        },
      ),
      fn(b) { b },
    )
  final_verification && lagrange_check
}

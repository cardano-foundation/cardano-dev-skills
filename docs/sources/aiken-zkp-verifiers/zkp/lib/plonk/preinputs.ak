use aiken/collection/list
use aiken/crypto/bitwise.{State}
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2
use aiken/crypto/bls12_381/scalar.{Scalar, scale}

pub type PlonkPreInputs {
  power: Int,
  k1: State<Scalar>,
  k2: State<Scalar>,
  q_m: ByteArray,
  q_l: ByteArray,
  q_r: ByteArray,
  q_o: ByteArray,
  q_c: ByteArray,
  s_sig1: ByteArray,
  s_sig2: ByteArray,
  s_sig3: ByteArray,
  x2: ByteArray,
}

pub type PreparedPlonkPreInputs {
  n: Int,
  generator: State<Scalar>,
  generators: List<State<Scalar>>,
  power: Int,
  k1: State<Scalar>,
  k2: State<Scalar>,
  q_m: G1Element,
  q_l: G1Element,
  q_r: G1Element,
  q_o: G1Element,
  q_c: G1Element,
  s_sig1: G1Element,
  s_sig2: G1Element,
  s_sig3: G1Element,
  x2: G2Element,
}

pub fn plonk_prepare_preinputs(
  inputs: PlonkPreInputs,
  generator: State<Scalar>,
  n_public: Int,
) -> PreparedPlonkPreInputs {
  let q_m = g1.decompress(inputs.q_m)
  let q_l = g1.decompress(inputs.q_l)
  let q_r = g1.decompress(inputs.q_r)
  let q_o = g1.decompress(inputs.q_o)
  let q_c = g1.decompress(inputs.q_c)
  let s_sig1 = g1.decompress(inputs.s_sig1)
  let s_sig2 = g1.decompress(inputs.s_sig2)
  let s_sig3 = g1.decompress(inputs.s_sig3)
  let x2 = g2.decompress(inputs.x2)

  PreparedPlonkPreInputs {
    n: scalar.to_int(scale(scalar.from_int(2), inputs.power)),
    generator,
    generators: list.map(list.range(0, n_public), fn(n) { scale(generator, n) }),
    power: inputs.power,
    k1: inputs.k1,
    k2: inputs.k2,
    q_m,
    q_l,
    q_r,
    q_o,
    q_c,
    s_sig1,
    s_sig2,
    s_sig3,
    x2,
  }
}

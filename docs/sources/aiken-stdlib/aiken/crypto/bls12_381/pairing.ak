use aiken/builtin.{bls12_381_final_verify, bls12_381_miller_loop}

/// Computes a MillerLoop over the elements `q` and `p`
pub fn miller_loop(q: G1Element, p: G2Element) -> MillerLoopResult {
  bls12_381_miller_loop(q, p)
}

/// Final exponentiation against two `MillerLoopResult`.
///
/// ```aiken
/// prove: e(q^x, p^m) == e(q, p^m*x)
/// let secret: State<Scalar> = scalar.from_int(44203)
///
/// let public_value: G1Element = g1.generator |> g1.scale(secret)
///
/// let message: ByteArray = #"acab"
///
/// let challenge: G2Element =
///   message |> g2.hash_to_group(domain_separation_tag_nul)
///
/// let witness: G2Element =
///   message
///     |> g2.hash_to_group(domain_separation_tag_nul)
///     |> g2.scale(secret)
///
/// final_exponentiation(
///   miller_loop(public_value, challenge),
///   miller_loop(g1.generator, witness),
/// )
/// ```
pub fn final_exponentiation(
  left: MillerLoopResult,
  right: MillerLoopResult,
) -> Bool {
  bls12_381_final_verify(left, right)
}

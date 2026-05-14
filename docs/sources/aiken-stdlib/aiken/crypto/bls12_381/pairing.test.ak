use aiken/crypto/bitwise.{State}
use aiken/crypto/bls12_381.{domain_separation_tag_nul}
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2
use aiken/crypto/bls12_381/pairing.{final_exponentiation, miller_loop}
use aiken/crypto/bls12_381/scalar.{Scalar}

// -------------------------------- simple_miller_loop_with_final_exponentiation

// prove: e(q^x, p^m) == e(q, p^m*x)
test simple_miller_loop_with_final_exponentiation() {
  let secret: State<Scalar> = scalar.from_int(44203)

  let public_value: G1Element = g1.generator |> g1.scale(secret)

  let message: ByteArray = #"acab"

  let challenge: G2Element = message
    |> g2.hash_to_group(domain_separation_tag_nul)

  let witness: G2Element = message
    |> g2.hash_to_group(domain_separation_tag_nul)
    |> g2.scale(secret)

  final_exponentiation(
    miller_loop(public_value, challenge),
    miller_loop(g1.generator, witness),
  )
}

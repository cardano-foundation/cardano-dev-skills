use aiken/builtin.{
  bls12_381_g1_add, bls12_381_g1_compress, bls12_381_g1_neg,
  bls12_381_g1_uncompress,
}
use bls/homomorphic_hash.{homomorphic_hash}

/// Test
const my_dst: ByteArray = "my_custom_dst"

test hash_homomorphic_basic_success() {
  let h1 = homomorphic_hash("message1", my_dst)
  let h2 = homomorphic_hash("message2", my_dst)

  let hashes = [h1, h2]

  let aggregated_hash = homomorphic_hash.aggregate_hashes(hashes)

  // Decompress the hashes to get the group elements
  let g1_h1 = bls12_381_g1_uncompress(h1)
  let g1_h2 = bls12_381_g1_uncompress(h2)

  // Sum the group elements directly
  let expected_sum = bls12_381_g1_add(g1_h1, g1_h2)

  // Compress the expected sum for comparison
  let expected_aggregated_hash = bls12_381_g1_compress(expected_sum)

  // Assert that the computed aggregated hash matches the expected aggregated hash
  aggregated_hash == expected_aggregated_hash
}

test hash_homomorphic_subtract_success() {
  let h1 = homomorphic_hash("message1", my_dst)
  let h2 = homomorphic_hash("message2", my_dst)
  let h3 = homomorphic_hash("message3", my_dst)

  let h12 = [h1, h2]

  let ah12 = homomorphic_hash.aggregate_hashes(h12)
  let ah123 = homomorphic_hash.aggregate_hashes([ah12, h3])

  let epxected_orig =
    bls12_381_g1_add(
      bls12_381_g1_uncompress(ah123),
      bls12_381_g1_neg(bls12_381_g1_uncompress(h3)),
    )

  ah12 == bls12_381_g1_compress(epxected_orig)
}

test hash_homomorphic_shuffle_success() {
  let h1 = homomorphic_hash("message1", my_dst)
  let h2 = homomorphic_hash("message2", my_dst)
  let h3 = homomorphic_hash("message3", my_dst)

  let ah12 = homomorphic_hash.aggregate_hashes([h1, h2])
  let ah123 = homomorphic_hash.aggregate_hashes([h1, h2, h3])
  let ah3_12 = homomorphic_hash.aggregate_hashes([h3, ah12])
  ah123 == ah3_12
}

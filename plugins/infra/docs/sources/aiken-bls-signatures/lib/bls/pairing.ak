use aiken/builtin.{
  bls12_381_g1_add, bls12_381_g1_compress, bls12_381_g1_uncompress,
  bls12_381_g2_add, bls12_381_g2_compress, bls12_381_g2_uncompress,
  bls12_381_miller_loop,
}
use aiken/collection/list.{foldl, length}
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2

/// This function performs a pairing operation on elements represented by two byte arrays.
/// It uncompresses the byte arrays to their respective elements and then calls the group_pairing function.
pub fn pairing(g1: ByteArray, g2: ByteArray) {
  let g1_element = bls12_381_g1_uncompress(g1)
  let g2_element = bls12_381_g2_uncompress(g2)

  group_pairing(g1_element, g2_element)
}

// This function performs the pairing operation using the Miller loop algorithm on two elements,
// one from G1 and one from G2.
pub fn group_pairing(g1: G1Element, g2: G2Element) {
  expect g1 != g1.zero
  expect g2 != g2.zero

  bls12_381_miller_loop(g1, g2)
}

pub fn aggregate_g1(elems: List<ByteArray>) -> ByteArray {
  if length(elems) <= 0 {
    fail @"G1: Cannot aggregate an empty list."
  } else {
    foldl(
      elems,
      g1.zero,
      fn(elem, sum) {
        let p = bls12_381_g1_uncompress(elem)
        expect p != g1.zero
        bls12_381_g1_add(p, sum)
      },
    )
      |> bls12_381_g1_compress
  }
}

pub fn aggregate_g2(elems: List<ByteArray>) -> ByteArray {
  if length(elems) <= 0 {
    fail @"G2: Cannot aggregate an empty list."
  } else {
    foldl(
      elems,
      g2.zero,
      fn(elem, sum) {
        let s = bls12_381_g2_uncompress(elem)
        expect s != g2.zero
        bls12_381_g2_add(s, sum)
      },
    )
      |> bls12_381_g2_compress
  }
}

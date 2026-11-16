//// Property-based tests for the affine point compression in
//// `common/blst_affine`, checked against the BLS builtins. See
//// `tests/groth_props` for what the `prop_*` and `known_issue_*` prefixes mean.

use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/scalar
use aiken/fuzz
use aiken/primitive/bytearray
use common/blst_affine.{G1Affine, G1Point, g1_affine_compress, g1_on_curve}
use common/common.{bls12_381_base_prime, bls12_381_half_prime}
use tests/groth_props.{nonzero_scalar}

/// `b^e mod m` by square-and-multiply.
fn mod_pow(b: Int, e: Int, m: Int) -> Int {
  if e == 0 {
    1
  } else {
    let half = mod_pow(b, e / 2, m)
    let sq = half * half % m
    if e % 2 == 1 {
      sq * b % m
    } else {
      sq
    }
  }
}

/// The affine coordinates of `k * G`, recovered from blst's compressed bytes:
/// clear the three flag bits to get x, then solve y^2 = x^3 + 4 (p = 3 mod 4,
/// so a square root is a power of (p + 1) / 4) and pick the root the sort bit
/// names. Returns the point, the other root's point, and blst's bytes.
fn affine_of(k: Int) -> (G1Affine, G1Affine, ByteArray) {
  let p = bls12_381_base_prime
  let compressed = g1.compress(g1.scale(g1.generator, scalar.from_int(k)))
  let first = bytearray.at(compressed, 0)
  let x_bytes = bytearray.push(bytearray.drop(compressed, 1), first % 32)
  let x = bytearray.to_int_big_endian(x_bytes)
  let root = mod_pow(( x * x * x + 4 ) % p, ( p + 1 ) / 4, p)
  let sort_bit_set = first / 32 % 2 == 1
  let (y, other) =
    if root > bls12_381_half_prime == sort_bit_set {
      (root, p - root)
    } else {
      (p - root, root)
    }
  let to48 =
    fn(n) { bytearray.from_int_big_endian(n, 48) }
  (
    G1Point { x: x_bytes, y: to48(y) },
    G1Point { x: x_bytes, y: to48(other) },
    compressed,
  )
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

/// For any point, `g1_affine_compress` gives exactly blst's encoding, the
/// recovered point is on the curve, and the other square root encodes
/// differently.
test prop_g1_affine_compress_matches_blst(k via nonzero_scalar()) {
  let (point, other, compressed) = affine_of(k)
  and {
    g1_on_curve(point),
    g1_affine_compress(point) == compressed,
    g1_affine_compress(other) != compressed,
    g1.decompress(g1_affine_compress(point)) == g1.scale(
      g1.generator,
      scalar.from_int(k),
    ),
  }
}

// ---------------------------------------------------------------------------
// Known issues
// ---------------------------------------------------------------------------

/// ADAOcommunity/zk#15: `y` only contributes its sign, so any `y` on the same
/// side of (p - 1) / 2 compresses to the same bytes, even one that isn't on the
/// curve. Once fixed, replace with `prop_g1_affine_compress_rejects_wrong_y`
/// (the same call must fail).
test known_issue_15_g1_affine_compress_ignores_y(
  (k, r) via fuzz.tuple(
    nonzero_scalar(),
    fuzz.int_between(1, bls12_381_half_prime),
  ),
) {
  expect (G1Point { x, y }, _, compressed) = affine_of(k)
  let y_int = bytearray.to_int_big_endian(y)
  // A different y on the same side of the half-way point.
  let fake =
    if y_int > bls12_381_half_prime {
      bls12_381_half_prime + r
    } else {
      r - 1
    }
  fake == y_int || g1_affine_compress(
    G1Point { x, y: bytearray.from_int_big_endian(fake, 48) },
  ) == compressed
}

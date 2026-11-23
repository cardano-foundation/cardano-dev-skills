//// Property-based tests for the affine point compression in
//// `common/blst_affine`, checked against the BLS builtins. See
//// `tests/groth_props` for what the `prop_*` and `known_issue_*` prefixes mean.

use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/scalar
use aiken/fuzz
use aiken/primitive/bytearray
use common/blst_affine.{
  G1Affine, G1Point, g1_affine_compress, g1_affine_valid, g1_on_curve,
}
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
/// recovered point and its negation are valid, and the other square root
/// encodes differently.
test prop_g1_affine_compress_matches_blst(k via nonzero_scalar()) {
  let (point, other, compressed) = affine_of(k)
  and {
    g1_on_curve(point),
    g1_affine_valid(point),
    g1_affine_valid(other),
    g1_affine_compress(point) == compressed,
    g1_affine_compress(other) != compressed,
    g1.decompress(g1_affine_compress(point)) == g1.scale(
      g1.generator,
      scalar.from_int(k),
    ),
  }
}

/// ADAOcommunity/zk#15: `y` only contributes its sign to the compressed
/// bytes, so any other `y` on the same side of (p - 1) / 2 must be rejected.
/// It used to compress to the same bytes as the real point.
test prop_g1_affine_rejects_wrong_y(
  (k, r) via fuzz.tuple(
    nonzero_scalar(),
    fuzz.int_between(1, bls12_381_half_prime),
  ),
) {
  expect (G1Point { x, y }, _, _) = affine_of(k)
  let y_int = bytearray.to_int_big_endian(y)
  // A different y on the same side of the half-way point.
  let fake =
    if y_int > bls12_381_half_prime {
      bls12_381_half_prime + r
    } else {
      r - 1
    }
  fake == y_int || !g1_affine_valid(
    G1Point { x, y: bytearray.from_int_big_endian(fake, 48) },
  )
}

/// ADAOcommunity/zk#15: each point has one encoding. A coordinate at or above
/// p (including one with a flag bit already set), or with an extra leading
/// zero byte, is rejected although it names the same field element or sets a
/// flag the compressor would also set.
test prop_g1_affine_rejects_noncanonical_coordinates(k via nonzero_scalar()) {
  expect (G1Point { x, y }, _, _) = affine_of(k)
  let p = bls12_381_base_prime
  let x_int = bytearray.to_int_big_endian(x)
  let y_int = bytearray.to_int_big_endian(y)
  let to48 =
    fn(n) { bytearray.from_int_big_endian(n, 48) }
  and {
    !g1_affine_valid(G1Point { x: to48(x_int + p), y }),
    !g1_affine_valid(G1Point { x, y: to48(y_int + p) }),
    // x with the sort bit (0x20) already set in its top byte.
    !g1_affine_valid(
      G1Point {
        x: bytearray.push(bytearray.drop(x, 1), bytearray.at(x, 0) + 32),
        y,
      },
    ),
    !g1_affine_valid(G1Point { x: bytearray.push(x, 0), y }),
    !g1_affine_valid(G1Point { x, y: bytearray.push(y, 0) }),
  }
}

/// ADAOcommunity/zk#15: compressing a point with the wrong `y` fails rather
/// than returning the real point's bytes.
test g1_affine_compress_fails_on_wrong_y() fail {
  expect (G1Point { x, y }, _, _) = affine_of(42)
  let y_int = bytearray.to_int_big_endian(y)
  let fake =
    if y_int > bls12_381_half_prime {
      y_int - 1
    } else {
      y_int + 1
    }
  bytearray.length(
    g1_affine_compress(
      G1Point { x, y: bytearray.from_int_big_endian(fake, 48) },
    ),
  ) == 48
}

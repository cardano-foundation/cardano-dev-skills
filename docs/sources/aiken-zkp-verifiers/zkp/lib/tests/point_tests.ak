use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2
use aiken/primitive/bytearray
use common/blst_affine.{
  G1Affine, G1Infinity, G1Point, G2Affine, G2Infinity, G2Point,
  g1_affine_compress, g1_on_curve, g2_affine_compress, g2_affine_valid,
}
use common/common.{bls12_381_base_prime}
use tests/plonk_tests.{test_plonk_proof_affine, test_plonk_vkey_affine}
use tests/test_utils.{int_to_field_bytes}

// ---------------------------------------------------------------------------
// Test point constants
// ---------------------------------------------------------------------------

const g1_a =
  G1Point {
    x: int_to_field_bytes(
      1449497163185511255960735085284916465289671960584516882188976107972557459282929317206787632956592412629479052789269,
    ),
    y: int_to_field_bytes(
      3989435130608907884226398003251903810202294754002824591270717519803551766794598638405495657602973072105705998377235,
    ),
  }

const g1_b =
  G1Point {
    x: int_to_field_bytes(
      1736517976604336165319190912612272873938577839112916200234711436320455450585513057542289433496238251851408450867401,
    ),
    y: int_to_field_bytes(
      3933887163973139524131102938351008807575633708420235139733365238460765495095075881949112452329274308243204895789594,
    ),
  }

pub const simple_g1_point: G1Affine =
  G1Point {
    x: int_to_field_bytes(
      3685416753713387016781088315183077757961620795782546409894578378688607592378376318836054947676345821548104185464507,
    ),
    y: int_to_field_bytes(
      1339506544944476473020471379941921221584933875938349620426543736416511423956333506472724655353366534992391756441569,
    ),
  }

// ---------------------------------------------------------------------------
// G1 compression tests
// ---------------------------------------------------------------------------

test test_g1_compression_format() {
  let compressed = g1_affine_compress(g1_a)
  let compressed_length = bytearray.length(compressed)
  let first_byte = bytearray.to_int_big_endian(bytearray.take(compressed, 1))
  let has_compression_bit = first_byte >= 128
  compressed_length == 48 && has_compression_bit
}

test test_g1_infinity_compression() {
  let compressed = g1_affine_compress(G1Infinity)
  let first_byte = bytearray.to_int_big_endian(bytearray.take(compressed, 1))
  let length = bytearray.length(compressed)
  let is_infinity_encoding = first_byte == 192
  let correct_length = length == 48
  is_infinity_encoding && correct_length
}

test test_g1_different_points_different_compression() {
  let compressed1 = g1_affine_compress(g1_a)
  let compressed2 = g1_affine_compress(g1_b)
  compressed1 != compressed2
}

test test_y_ordering_bit() {
  expect G1Point { y, .. } = g1_a
  let compressed = g1_affine_compress(g1_a)
  let first_byte = bytearray.to_int_big_endian(bytearray.take(compressed, 1))
  let y_bit_set = first_byte % 64 >= 32
  let y_int = bytearray.to_int_big_endian(y)
  let expected_y_larger =
    y_int > 2001204777610833696708894912867952078278441409969503942666029068062015825245418932221343814564507832018947136279893
  y_bit_set == expected_y_larger
}

// ---------------------------------------------------------------------------
// G2 compression tests
// ---------------------------------------------------------------------------

/// The point used to be made-up coordinates, which compression now rejects
/// (ADAOcommunity/zk#15); the generator is a real point.
test test_g2_compression_format() {
  let point = g2_generator_affine
  let compressed = g2_affine_compress(point)
  let compressed_length = bytearray.length(compressed)
  let first_byte = bytearray.to_int_big_endian(bytearray.take(compressed, 1))
  let has_compression_bit = first_byte >= 128
  compressed_length == 96 && has_compression_bit
}

/// The standard BLS12-381 G2 generator in affine form, `x0`/`y0` real parts.
const g2_generator_affine: G2Affine =
  G2Point {
    x: (
      #"024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8",
      #"13e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e",
    ),
    y: (
      #"0ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801",
      #"0606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79be",
    ),
  }

/// `(p - n) mod p` as 48 bytes: the coordinate of the negated point.
fn negate_component(bytes: ByteArray) -> ByteArray {
  let n = bytearray.to_int_big_endian(bytes)
  int_to_field_bytes(( bls12_381_base_prime - n ) % bls12_381_base_prime)
}

/// Add `delta` to one component's integer value, keeping 48 bytes.
fn bump(bytes: ByteArray, delta: Int) -> ByteArray {
  int_to_field_bytes(bytearray.to_int_big_endian(bytes) + delta)
}

/// ADAOcommunity/zk#15, G2: the generator, its negation and the fixture's
/// `x2` are valid, and the first two compress to exactly blst's bytes.
test test_g2_affine_valid_points_match_blst() {
  expect G2Point { x, y: (y0, y1) } = g2_generator_affine
  let negated = G2Point { x, y: (negate_component(y0), negate_component(y1)) }
  and {
    g2_affine_valid(g2_generator_affine),
    g2_affine_valid(negated),
    g2_affine_valid(test_plonk_vkey_affine.x2),
    g2_affine_compress(g2_generator_affine) == g2.compress(g2.generator),
    g2_affine_compress(negated) == g2.compress(g2.sub(g2.zero, g2.generator)),
  }
}

/// ADAOcommunity/zk#15, G2: a changed `y` component, a component at or above
/// p, an `x1` with the sort bit already set, and an extra leading zero byte
/// are each rejected.
test test_g2_affine_rejects_bad_coordinates() {
  expect G2Point { x: (x0, x1), y: (y0, y1) } = g2_generator_affine
  let p = bls12_381_base_prime
  and {
    !g2_affine_valid(G2Point { x: (x0, x1), y: (bump(y0, 1), y1) }),
    !g2_affine_valid(G2Point { x: (x0, x1), y: (y0, bump(y1, 1)) }),
    !g2_affine_valid(G2Point { x: (x0, x1), y: (bump(y0, p), y1) }),
    !g2_affine_valid(G2Point { x: (bump(x0, p), x1), y: (y0, y1) }),
    !g2_affine_valid(
      G2Point {
        x: (x0, bytearray.push(bytearray.drop(x1, 1), bytearray.at(x1, 0) + 32)),
        y: (y0, y1),
      },
    ),
    !g2_affine_valid(G2Point { x: (bytearray.push(x0, 0), x1), y: (y0, y1) }),
  }
}

/// ADAOcommunity/zk#15, G2: compressing a point with a wrong `y` fails.
test test_g2_affine_compress_fails_on_wrong_y() fail {
  expect G2Point { x, y: (y0, y1) } = g2_generator_affine
  bytearray.length(g2_affine_compress(G2Point { x, y: (bump(y0, 1), y1) })) == 96
}

test test_g2_infinity_compression() {
  let compressed = g2_affine_compress(G2Infinity)
  let first_byte = bytearray.to_int_big_endian(bytearray.take(compressed, 1))
  let length = bytearray.length(compressed)
  let is_infinity_encoding = first_byte == 192
  let correct_length = length == 96
  is_infinity_encoding && correct_length
}

// ---------------------------------------------------------------------------
// Infinity decompression tests
// ---------------------------------------------------------------------------

test test_known_infinity_format() {
  // Standard BLS12-381 infinity: 0xc0 followed by 47 zero bytes (48 bytes total = 96 hex chars)
  let known_infinity =
    #"c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
  expect _decompressed = g1.decompress(known_infinity)
  let our_infinity = g1_affine_compress(test_plonk_vkey_affine.q_c)
  known_infinity == our_infinity
}

test test_infinity_roundtrip() {
  let compressed_infinity = g1_affine_compress(test_plonk_vkey_affine.q_c)
  expect _decompressed = g1.decompress(compressed_infinity)
  True
}

// ---------------------------------------------------------------------------
// Individual point decompression (vkey points)
// ---------------------------------------------------------------------------

test test_vkey_point_decompressions() {
  let compressed_q_m = g1_affine_compress(test_plonk_vkey_affine.q_m)
  expect _d1 = g1.decompress(compressed_q_m)

  let compressed_q_l = g1_affine_compress(test_plonk_vkey_affine.q_l)
  expect _d2 = g1.decompress(compressed_q_l)

  let compressed_q_r = g1_affine_compress(test_plonk_vkey_affine.q_r)
  expect _d3 = g1.decompress(compressed_q_r)

  let compressed_q_o = g1_affine_compress(test_plonk_vkey_affine.q_o)
  expect _d4 = g1.decompress(compressed_q_o)

  let compressed_q_c = g1_affine_compress(test_plonk_vkey_affine.q_c)
  expect _d5 = g1.decompress(compressed_q_c)

  True
}

// ---------------------------------------------------------------------------
// Point structure validation (proof points)
// ---------------------------------------------------------------------------

test test_proof_point_structures() {
  and {
    g1_on_curve(test_plonk_proof_affine.commitment_a),
    g1_on_curve(test_plonk_proof_affine.commitment_b),
    g1_on_curve(test_plonk_proof_affine.commitment_c),
    g1_on_curve(test_plonk_proof_affine.commitment_z),
    g1_on_curve(test_plonk_proof_affine.t_low),
    g1_on_curve(test_plonk_proof_affine.t_mid),
    g1_on_curve(test_plonk_proof_affine.t_high),
    g1_on_curve(test_plonk_proof_affine.w_omega),
    g1_on_curve(test_plonk_proof_affine.w_omega_zeta),
  }
}

// ---------------------------------------------------------------------------
// Point structure validation (vkey points)
// ---------------------------------------------------------------------------

test test_vkey_point_structures() {
  and {
    g1_on_curve(test_plonk_vkey_affine.q_m),
    g1_on_curve(test_plonk_vkey_affine.q_l),
    g1_on_curve(test_plonk_vkey_affine.q_r),
    g1_on_curve(test_plonk_vkey_affine.q_o),
    g1_on_curve(test_plonk_vkey_affine.s_sig1),
    g1_on_curve(test_plonk_vkey_affine.s_sig2),
    g1_on_curve(test_plonk_vkey_affine.s_sig3),
    when test_plonk_vkey_affine.x2 is {
      G2Point { x: _, y: _ } -> True
      _ -> False
    },
  }
}

test test_simple_point_validation() {
  when simple_g1_point is {
    G1Point { .. } -> g1_on_curve(simple_g1_point)
    _ -> False
  }
}

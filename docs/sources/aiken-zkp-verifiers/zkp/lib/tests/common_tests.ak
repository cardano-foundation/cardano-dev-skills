//// Unit and property tests for the parts of `common/common` that the
//// verifiers depend on: the two BLS12-381 constants (used by `blst_affine`),
//// `concat_and_keccak_256` (the PLONK transcript), and `scalar_sum` and
//// `g1_sum` (the PLONK verifier's sums). The rest of `common/common` is legacy
//// code that no verifier calls; see the implementation reports.

use aiken/collection/list
use aiken/crypto
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/fuzz
use aiken/primitive/bytearray
use common/common.{
  bls12_381_base_prime, bls12_381_half_prime, concat_and_keccak_256, g1_sum,
  scalar_sum,
}
use tests/groth_props.{nonzero_scalar}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// p as published in the BLS12-381 specification.
test common_base_prime_matches_spec() {
  bls12_381_base_prime == bytearray.to_int_big_endian(
    #"1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab",
  )
}

test common_half_prime_is_half() {
  bls12_381_half_prime == ( bls12_381_base_prime - 1 ) / 2
}

/// The square root in `tests/point_props` relies on p = 3 mod 4.
test common_base_prime_is_3_mod_4() {
  bls12_381_base_prime % 4 == 3
}

/// The standard G1 generator satisfies y^2 = x^3 + 4 mod p, and its x matches
/// the builtin generator's compressed bytes.
test common_base_prime_fits_g1_generator() {
  let p = bls12_381_base_prime
  let x =
    bytearray.to_int_big_endian(
      #"17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb",
    )
  let y =
    bytearray.to_int_big_endian(
      #"08b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1",
    )
  let compressed = g1.compress(g1.generator)
  let first = bytearray.at(compressed, 0)
  and {
    y * y % p == ( x * x * x + 4 ) % p,
    bytearray.to_int_big_endian(
      bytearray.push(bytearray.drop(compressed, 1), first % 32),
    ) == x,
  }
}

// ---------------------------------------------------------------------------
// concat_and_keccak_256
// ---------------------------------------------------------------------------

/// Keccak-256, not SHA3-256, of the empty string.
test common_keccak_empty_list() {
  concat_and_keccak_256([]) == #"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
}

/// Pieces are joined in order.
test common_keccak_joins_in_order() {
  and {
    concat_and_keccak_256([#"01", #"0203"]) == crypto.keccak_256(#"010203"),
    concat_and_keccak_256([#"0203", #"01"]) == crypto.keccak_256(#"020301"),
  }
}

/// Where the input is split doesn't change the hash.
test prop_common_keccak_ignores_split(
  (bytes, cut) via fuzz.tuple(
    fuzz.bytearray_between(0, 64),
    fuzz.int_between(0, 64),
  ),
) {
  concat_and_keccak_256(
    [bytearray.take(bytes, cut), #"", bytearray.drop(bytes, cut)],
  ) == crypto.keccak_256(bytes)
}

// ---------------------------------------------------------------------------
// scalar_sum and g1_sum
// ---------------------------------------------------------------------------

test common_scalar_sum_empty_is_zero() {
  scalar_sum([]) == scalar.from_int(0)
}

/// Summing scalars matches summing the integers mod r.
test prop_common_scalar_sum_matches_int_sum(
  xs via fuzz.list_between(nonzero_scalar(), 0, 8),
) {
  scalar_sum(list.map(xs, scalar.from_int)) == scalar.from_int(
    list.foldl(xs, 0, fn(x, acc) { acc + x }) % field_prime,
  )
}

test common_g1_sum_empty_is_zero() {
  g1_sum([]) == g1.zero
}

fn times_g(k: Int) -> G1Element {
  g1.scale(g1.generator, scalar.from_int(k))
}

/// The sum of k_i * G is (sum of k_i) * G.
test prop_common_g1_sum_matches_scalar_sum(
  ks via fuzz.list_between(nonzero_scalar(), 1, 4),
) {
  g1_sum(list.map(ks, times_g)) == times_g(
    list.foldl(ks, 0, fn(k, acc) { acc + k }) % field_prime,
  )
}

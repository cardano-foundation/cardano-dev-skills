use aiken/crypto
use aiken/primitive/bytearray

/// BLS12-381 scalar field prime.
fn q() -> Int {
  52435875175126190479447740508185965837690552500527637822603658699938581184513
}

/// Correct BLAKE2b-256 of "hello"
test blake2b_correct() {
  crypto.blake2b_256(#"68656c6c6f")
    == #"324dcf027dd4a30a932c441f365a25e86b173defa4b8e58948253471b81b72cf"
}

/// LE serialization round-trip
test le_round_trip() {
  bytearray.to_int_little_endian(
    bytearray.from_int_little_endian(42, 32),
  ) == 42
}

/// Modular reduction: raw hash int % q must match Rust's Fr::from_le_bytes_mod_order
test modular_reduction_small() {
  let raw = 21328464620381525131075982840458371645799272542070335445245641326034385905465
  // raw < q, so mod q = raw
  raw % q() == raw
}

test modular_reduction_large() {
  let raw = 87734536033648665463951268419596319249651621536220309251560243029008662170935
  let reduced = raw % q()
  // Rust: 35298660858522474984503527911410353411961069035692671428956584329070080986422
  reduced == 35298660858522474984503527911410353411961069035692671428956584329070080986422
}

/// CKO round 0: hash([0, 0, 0]) → mod q
test fs_cko_round_0() {
  let e = bytearray.from_int_little_endian(0, 32)
  let input = bytearray.concat(bytearray.concat(e, e), e)
  let raw = bytearray.to_int_little_endian(crypto.blake2b_256(input))
  let challenge = raw % q()
  challenge == 21328464620381525131075982840458371645799272542070335445245641326034385905465
}

/// CKO round 1: hash([0, 0, 0, 0]) → mod q
test fs_cko_round_1() {
  let e = bytearray.from_int_little_endian(0, 32)
  let input = bytearray.concat(
    bytearray.concat(bytearray.concat(e, e), e),
    e,
  )
  let raw = bytearray.to_int_little_endian(crypto.blake2b_256(input))
  let challenge = raw % q()
  challenge == 35298660858522474984503527911410353411961069035692671428956584329070080986422
}

/// Simple round 0: hash([42, 10, 20]) → mod q
test fs_simple_round_0() {
  let e1 = bytearray.from_int_little_endian(42, 32)
  let e2 = bytearray.from_int_little_endian(10, 32)
  let e3 = bytearray.from_int_little_endian(20, 32)
  let input = bytearray.concat(bytearray.concat(e1, e2), e3)
  let raw = bytearray.to_int_little_endian(crypto.blake2b_256(input))
  let challenge = raw % q()
  // raw = 12733011041497404045585672835906705871033664918944065493410980735042167106341
  // raw < q, so challenge = raw
  challenge == 12733011041497404045585672835906705871033664918944065493410980735042167106341
}

/// Simple round 1: hash([42, 100, 200, 30, 40]) → mod q
test fs_simple_round_1() {
  let e1 = bytearray.from_int_little_endian(42, 32)
  let e2 = bytearray.from_int_little_endian(100, 32)
  let e3 = bytearray.from_int_little_endian(200, 32)
  let e4 = bytearray.from_int_little_endian(30, 32)
  let e5 = bytearray.from_int_little_endian(40, 32)
  let input = bytearray.concat(
    bytearray.concat(bytearray.concat(bytearray.concat(e1, e2), e3), e4),
    e5,
  )
  let raw = bytearray.to_int_little_endian(crypto.blake2b_256(input))
  let challenge = raw % q()
  challenge == 34615077230899160322180096103917711459030716309906699828373418088195755802985
}

/// Changing one element changes the challenge
test fs_challenge_depends_on_input() {
  let input1 = bytearray.concat(
    bytearray.from_int_little_endian(42, 32),
    bytearray.from_int_little_endian(10, 32),
  )
  let input2 = bytearray.concat(
    bytearray.from_int_little_endian(42, 32),
    bytearray.from_int_little_endian(11, 32),
  )
  let ch1 = bytearray.to_int_little_endian(crypto.blake2b_256(input1)) % q()
  let ch2 = bytearray.to_int_little_endian(crypto.blake2b_256(input2)) % q()
  ch1 != ch2
}

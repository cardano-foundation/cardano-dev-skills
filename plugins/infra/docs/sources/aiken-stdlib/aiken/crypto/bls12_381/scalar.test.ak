use aiken/builtin
use aiken/crypto/bitwise.{one, zero}
use aiken/crypto/bls12_381/scalar.{
  add, div, field_prime, from_bytes, from_bytes_little_endian, from_int, mul,
  neg, recip, scale, scale2, sub, to_bytes, to_int,
}

// ----------------------------------------------------------------------- scale

test scale_1() {
  let x = from_int(834884848)

  and {
    ( x |> scale(-1) ) == zero,
    ( x |> scale(0) ) == one,
    ( x |> scale(1) ) == x,
    ( x |> scale(2) |> to_int ) == 697032709419983104,
    ( x |> scale(3) |> to_int ) == 581942047655130761945608192,
    (
      from_int(field_prime - 4)
        |> scale(200)
        |> to_int
    ) == 12843927705572658539565969578937286576443167978938369866871449552629978143484,
  }
}

// ---------------------------------------------------------------------- scale2

test scale2_1() {
  let x = from_int(834884848)

  and {
    scale2(x, -1) == zero,
    scale2(x, 0) == scale(x, 1),
    scale2(x, 1) == scale(x, 2),
    scale2(x, 2) == scale(x, 4),
    scale2(x, 3) == scale(x, 8),
    scale2(x, 4) == scale(x, 16),
  }
}

// ------------------------------------------------------------------------- add

test add_1() {
  let x = from_int(834884848)
  let y = from_int(field_prime - 1)
  let z = from_int(3)

  and {
    (( add(x, x) |> to_int ) == 1669769696)?,
    (add(y, one) == zero)?,
    (add(z, add(y, one)) == z)?,
  }
}

// ------------------------------------------------------------------------- div

test div_1() {
  let x = from_int(834884848)

  and {
    div(x, x) == Some(one),
    div(x, zero) == None,
    div(from_int(field_prime - 1), from_int(2)) == Some(
      from_int(
        26217937587563095239723870254092982918845276250263818911301829349969290592256,
      ),
    ),
  }
}

// ------------------------------------------------------------------------- mul

test mul_1() {
  let x = from_int(834884848)
  and {
    mul(x, x) == from_int(697032709419983104),
    mul(zero, x) == zero,
    mul(from_int(field_prime - 1), from_int(2)) == from_int(
      52435875175126190479447740508185965837690552500527637822603658699938581184511,
    ),
  }
}

// ------------------------------------------------------------------------- neg

test neg_1() {
  trace neg(zero)

  and {
    neg(from_int(834884848)) == from_int(
      52435875175126190479447740508185965837690552500527637822603658699937746299665,
    ),
    neg(zero) == zero,
    neg(one) == from_int(field_prime - 1),
  }
}

// ----------------------------------------------------------------------- recip

test recip_1() {
  and {
    recip(from_int(834884848)) == Some(
      from_int(
        35891248691642227249400403463796410930702563777316955162085759263735363466421,
      ),
    ),
    recip(zero) == None,
  }
}

// ------------------------------------------------------------------------- sub

test sub_1() {
  let x = from_int(834884848)

  and {
    (sub(x, x) == zero)?,
    (sub(zero, from_int(5)) == from_int(field_prime - 5))?,
  }
}

// ---------------------------------------------------------------------- to_int

test to_int_1() {
  to_int(from_int(834884848)) == 834884848
}

// ----------------------------------------------------------------- field_prime

test field_prime_1() {
  builtin.integer_to_bytearray(True, 32, field_prime) == #"73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001"
}

// --------------------------------------------------- from_bytearray_big_endian

test from_bytearray_big_endian_1() {
  ( from_bytes(#"ffff00") |> to_int ) == 16776960
}

// ------------------------------------------------ from_bytearray_little_endian

test from_bytearray_little_endian_1() {
  ( from_bytes_little_endian(#"ffff00") |> to_int ) == 65535
}

// ------------------------------------------------------------------------- new

test new_1() {
  trace from_int(-1)
  and {
    ( from_int(-1) |> to_int ) == field_prime - 1,
    ( from_int(field_prime) |> to_int ) == 0,
    ( from_int(834884848) |> to_int ) == 834884848,
  }
}

// ---------------------------------------------------------------- to_bytearray

test to_bytearray_1() {
  ( to_bytes(from_int(16777215)) |> builtin.slice_bytearray(29, 32, _) ) == #"ffffff"
}

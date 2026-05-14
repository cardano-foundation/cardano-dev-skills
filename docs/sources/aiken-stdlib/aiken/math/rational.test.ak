use aiken/fuzz.{both, either, map}
use aiken/math/rational.{
  Rational, abs, add, arithmetic_mean, ceil, compare, compare_with, denominator,
  div, floor, from_int, geometric_mean, mul, negate, new, numerator, pow,
  proper_fraction, reciprocal, reduce, round, round_even, sub, truncate, zero,
}

// ---------------------------------------------------------- fixtures & fuzzers

const any_positive_rational: Fuzzer<Rational> =
  either(
    map(
      both(fuzz.int_at_least(1), fuzz.int_at_least(1)),
      fn((num, den)) {
        expect Some(new_fraction) = new(num, den)
        new_fraction
      },
    ),
    map(
      both(fuzz.int_at_most(-1), fuzz.int_at_most(-1)),
      fn((num, den)) {
        expect Some(new_fraction) = new(num, den)
        new_fraction
      },
    ),
  )

const any_negative_rational: Fuzzer<Rational> =
  either(
    map(
      both(fuzz.int_at_most(-1), fuzz.int_at_least(1)),
      fn((num, den)) {
        expect Some(new_fraction) = new(num, den)
        new_fraction
      },
    ),
    map(
      both(fuzz.int_at_least(1), fuzz.int_at_most(-1)),
      fn((num, den)) {
        expect Some(new_fraction) = new(num, den)
        new_fraction
      },
    ),
  )

const any_non_zero_rational: Fuzzer<Rational> =
  either(any_negative_rational, any_positive_rational)

// --------------------------------------------------------------------- helpers

/// An unsafe constructor for `Rational` values. Assumes that the following invariants are
/// enforced:
///
/// - the denominator is positive (the sign is managed in the numerator);
/// - the denominator is not null.
///
/// This function is mainly used as a quick way to construct rationals from literal values.
fn ratio(numerator: Int, denominator: Int) -> Rational {
  expect Some(ratio) = new(numerator, denominator)
  ratio
}

// -------------------------------------------------------------------- from_int

test from_int_1() {
  and {
    (from_int(14) == ratio(14, 1))?,
    (from_int(-5) == ratio(-5, 1))?,
    (from_int(0) == ratio(0, 1))?,
  }
}

// ------------------------------------------------------------------------- new

test new_1() {
  and {
    (new(2, 0) == None)?,
    (new(2, 3) == Some(ratio(2, 3)))?,
    (new(-2, 3) == Some(ratio(-2, 3)))?,
    (new(2, -3) == Some(ratio(-2, 3)))?,
    (new(2, 4) == Some(ratio(2, 4)))?,
    (new(-2, -3) == Some(ratio(2, 3)))?,
    (new(-2, -4) == Some(ratio(2, 4)))?,
  }
}

// ----------------------------------------------------------------- denominator

test denominator_1() {
  expect Some(x) = new(2, 3)
  expect Some(y) = new(-2, 3)
  expect Some(z) = new(2, -3)
  expect Some(w) = new(-2, -3)
  and {
    (denominator(x) == 3)?,
    (denominator(y) == 3)?,
    (denominator(z) == 3)?,
    (denominator(w) == 3)?,
  }
}

// ------------------------------------------------------------------- numerator

test numerator_1() {
  expect Some(x) = new(2, 3)
  expect Some(y) = new(-2, 3)
  expect Some(z) = new(2, -3)
  expect Some(w) = new(-2, -3)

  and {
    (numerator(x) == 2)?,
    (numerator(y) == -2)?,
    (numerator(z) == -2)?,
    (numerator(w) == 2)?,
  }
}

// ------------------------------------------------------------------------- abs

test abs_examples() {
  and {
    (abs(ratio(5, 2)) == ratio(5, 2))?,
    (abs(ratio(-5, 2)) == ratio(5, 2))?,
    (abs(ratio(5, 2)) == abs(ratio(-5, 2)))?,
  }
}

// ---------------------------------------------------------------------- negate

test negate_1() {
  and {
    (negate(ratio(5, 2)) == ratio(-5, 2))?,
    (negate(ratio(-5, 2)) == ratio(5, 2))?,
    (negate(negate(ratio(5, 2))) == ratio(5, 2))?,
  }
}

// ------------------------------------------------------------------ reciprocal

test reciprocal_1() {
  and {
    (reciprocal(ratio(5, 2)) == new(2, 5))?,
    (reciprocal(ratio(-5, 2)) == new(-2, 5))?,
    (reciprocal(ratio(0, 2)) == None)?,
    (reciprocal(ratio(2, 3)) == new(3, 2))?,
    (reciprocal(ratio(-2, 3)) == new(-3, 2))?,
  }
}

// ---------------------------------------------------------------------- reduce

test reduce_1() {
  and {
    (reduce(ratio(80, 200)) == ratio(2, 5))?,
    (reduce(ratio(-5, 1)) == ratio(-5, 1))?,
    (reduce(ratio(0, 3)) == ratio(0, 1))?,
  }
}

// ------------------------------------------------------------------------- add

test add_1() {
  add(ratio(2, 3), ratio(3, 4)) == ratio(17, 12)
}

test add_2() {
  add(ratio(-2, 3), ratio(3, 4)) == ratio(1, 12)
}

// ------------------------------------------------------------------------- div

test div_1() {
  div(ratio(2, 3), ratio(3, 4)) == new(8, 9)
}

test div_2() {
  div(ratio(2, 3), ratio(-3, 4)) == new(-8, 9)
}

// ------------------------------------------------------------------------- mul

test mul_1() {
  mul(ratio(2, 3), ratio(3, 4)) == ratio(6, 12)
}

test mul_2() {
  mul(ratio(-2, 3), ratio(-3, 4)) == ratio(6, 12)
}

test mul_3() {
  let result = ratio(2, 5)
    |> mul(ratio(1, 8))
    |> mul(ratio(3, 10))
    |> mul(ratio(21, 100))
    |> mul(ratio(3, 5))
    |> mul(ratio(2, 8))
    |> mul(ratio(4, 10))
    |> mul(ratio(22, 100))
    |> reduce

  result == ratio(2079, 50000000)
}

// ------------------------------------------------------------------------- sub

test sub_1() {
  sub(ratio(2, 3), ratio(3, 4)) == ratio(-1, 12)
}

test sub_2() {
  sub(ratio(2, 3), ratio(-3, 4)) == ratio(17, 12)
}

test sub_3() {
  sub(ratio(-2, 3), ratio(3, 4)) == ratio(-17, 12)
}

// --------------------------------------------------------------------- compare

test compare_1() {
  expect Some(x) = new(2, 3)
  expect Some(y) = new(3, 4)
  expect Some(z) = new(4, 6)
  and {
    compare(x, y) == Less,
    compare(y, x) == Greater,
    compare(x, x) == Equal,
    compare(x, z) == Equal,
  }
}

// ---------------------------------------------------------------- compare_with

// TODO: Rewrite tests using binary-operator as first-class functions once aiken-lang/aiken#619 is merged.

test compare_with_eq() {
  let eq = compare_with(_, fn(l, r) { l == r }, _)

  expect Some(x) = new(2, 3)
  expect Some(y) = new(3, 4)

  !eq(x, y)? && !eq(y, x)? && eq(x, x)?
}

test compare_with_gt() {
  let gt = compare_with(_, fn(l, r) { l > r }, _)

  expect Some(x) = new(2, 3)
  expect Some(y) = new(3, 4)

  !gt(x, y)? && gt(y, x)? && !gt(x, x)?
}

test compare_with_gte() {
  let gte = compare_with(_, fn(l, r) { l >= r }, _)

  expect Some(x) = new(2, 3)
  expect Some(y) = new(3, 4)

  !gte(x, y)? && gte(y, x)? && gte(x, x)?
}

test compare_with_lt() {
  let lt = compare_with(_, fn(l, r) { l < r }, _)

  expect Some(x) = new(2, 3)
  expect Some(y) = new(3, 4)

  lt(x, y)? && !lt(y, x)? && !lt(x, x)?
}

test compare_with_lte() {
  let lte = compare_with(_, fn(l, r) { l <= r }, _)

  expect Some(x) = new(2, 3)
  expect Some(y) = new(3, 4)

  lte(x, y)? && !lte(y, x)? && lte(x, x)?
}

test compare_with_neq() {
  let neq = compare_with(_, fn(l, r) { l != r }, _)

  expect Some(x) = new(2, 3)
  expect Some(y) = new(3, 4)

  neq(x, y)? && neq(y, x)? && !neq(x, x)?
}

// ------------------------------------------------------------- arithmetic_mean

test arithmetic_mean_1() {
  let x = ratio(1, 2)
  let y = ratio(1, 2)
  expect Some(z) = arithmetic_mean([x, y])
  reduce(z) == ratio(1, 2)
}

test arithmetic_mean_2() {
  let x = ratio(1, 1)
  let y = ratio(2, 1)
  expect Some(z) = arithmetic_mean([x, y])
  reduce(z) == ratio(3, 2)
}

test arithmetic_mean_3() {
  let xs = [
    ratio(1, 1),
    ratio(2, 1),
    ratio(3, 1),
    ratio(4, 1),
    ratio(5, 1),
    ratio(6, 1),
  ]
  expect Some(z) = arithmetic_mean(xs)
  reduce(z) == ratio(7, 2)
}

// -------------------------------------------------------------- geometric_mean

test geometric_mean1() {
  expect Some(x) = new(1, 2)
  expect Some(y) = new(1, 2)
  geometric_mean(x, y) == new(1, 2)
}

test geometric_mean2() {
  expect Some(x) = new(-1, 2)
  expect Some(y) = new(1, 2)
  geometric_mean(x, y) == None
}

test geometric_mean3() {
  expect Some(x) = new(1, 2)
  expect Some(y) = new(-1, 2)
  geometric_mean(x, y) == None
}

test geometric_mean4() {
  expect Some(x) = new(1, 3)
  expect Some(y) = new(1, 6)
  geometric_mean(x, y) == new(1, 4)
}

test geometric_mean5() {
  expect Some(x) = new(67, 2500)
  expect Some(y) = new(35331, 1000)
  expect Some(yi) = reciprocal(y)
  geometric_mean(x, yi) == new(258, 9398)
}

// ------------------------------------------------------------------------ ceil

test ceil_1() {
  and {
    (ceil(ratio(13, 5)) == 3)?,
    (ceil(ratio(15, 5)) == 3)?,
    (ceil(ratio(16, 5)) == 4)?,
    (ceil(ratio(-3, 5)) == 0)?,
    (ceil(ratio(-5, 5)) == -1)?,
    (ceil(ratio(-14, 3)) == -4)?,
    (ceil(ratio(-14, 6)) == -2)?,
    (ceil(ratio(44, 14)) == 4)?,
  }
}

// ----------------------------------------------------------------------- floor

test floor_1() {
  and {
    (floor(ratio(5, 2)) == 2)?,
    (floor(ratio(5, 3)) == 1)?,
    (floor(ratio(5, 4)) == 1)?,
    (floor(ratio(5, 5)) == 1)?,
    (floor(ratio(5, 6)) == 0)?,
    (floor(ratio(8, 3)) == 2)?,
    (floor(ratio(-14, 3)) == -5)?,
  }
}

// ------------------------------------------------------------------------- pow

test pow_exponent_zero() {
  expect Some(base) = new(50, 2500)
  pow(base, 0) == new(1, 1)
}

test pow_negative_exponent_non_zero_fraction() {
  expect Some(base) = new(50, 2500)
  expect Some(calculated_result) = pow(base, -3)
  expect Some(expected_result) = new(125000, 1)
  reduce(calculated_result) == expected_result
}

test pow_positive_exponent() {
  expect Some(base) = new(50, 2500)
  expect Some(calculated_result) = pow(base, 3)
  expect Some(expected_result) = new(1, 125000)
  reduce(calculated_result) == expected_result
}

test pow_rational_zero_exponent_zero() {
  expect Some(base) = new(0, 1)
  pow(base, 0) == None
}

test prop_power_numerator_zero_exponent_negative_returns_none(
  (denominator, exponent) via both(fuzz.int_at_least(1), fuzz.int_at_most(-1)),
) {
  expect Some(fraction) = new(0, denominator)
  expect None = pow(fraction, exponent)
}

test prop_power_of_one_returns_same_fraction(rational via any_non_zero_rational) {
  expect Some(calculated_result) = pow(rational, 1)
  calculated_result == rational
}

test prop_power_of_zero_returns_one(rational via any_non_zero_rational) {
  expect Some(calculated_result) = pow(rational, 0)
  expect Some(expected_result) = new(1, 1)
  calculated_result == expected_result
}

test prop_power_unit_fraction_is_immutable(exponent via fuzz.int()) {
  expect Some(unit) = new(1, 1)
  expect Some(calculated_result) = pow(unit, exponent)
  calculated_result == unit
}

// ------------------------------------------------------------- proper_fraction

test proper_fraction_1() {
  let r = ratio(10, 7)
  let (n, f) = proper_fraction(r)
  and {
    (n == 1)?,
    (f == ratio(3, 7))?,
    (r == add(from_int(n), f))?,
  }
}

test proper_fraction_2() {
  let r = ratio(-10, 7)
  let (n, f) = proper_fraction(r)
  and {
    (n == -1)?,
    (f == ratio(-3, 7))?,
    (r == add(from_int(n), f))?,
  }
}

test proper_fraction_3() {
  let r = ratio(4, 2)
  let (n, f) = proper_fraction(r)
  and {
    (n == 2)?,
    (f == ratio(0, 2))?,
    (r == add(from_int(n), f))?,
  }
}

// ----------------------------------------------------------------------- round

test round_1() {
  and {
    (round(ratio(10, 7)) == 1)?,
    (round(ratio(11, 7)) == 2)?,
    (round(ratio(3, 2)) == 2)?,
    (round(ratio(5, 2)) == 3)?,
    (round(ratio(-3, 2)) == -1)?,
    (round(ratio(-2, 3)) == -1)?,
    (round(ratio(-10, 7)) == -1)?,
    (round(ratio(4, 2)) == 2)?,
  }
}

// ------------------------------------------------------------------ round_even

test round_even_1() {
  and {
    (round_even(ratio(10, 7)) == 1)?,
    (round_even(ratio(11, 7)) == 2)?,
    (round_even(ratio(3, 2)) == 2)?,
    (round_even(ratio(5, 2)) == 2)?,
    (round_even(ratio(-3, 2)) == -2)?,
    (round_even(ratio(-2, 3)) == -1)?,
    (round_even(ratio(-10, 7)) == -1)?,
    (round_even(ratio(4, 2)) == 2)?,
  }
}

// -------------------------------------------------------------------- truncate

test truncate_1() {
  and {
    (truncate(ratio(5, 2)) == 2)?,
    (truncate(ratio(5, 3)) == 1)?,
    (truncate(ratio(5, 4)) == 1)?,
    (truncate(ratio(5, 5)) == 1)?,
    (truncate(ratio(5, 6)) == 0)?,
    (truncate(ratio(8, 3)) == 2)?,
    (truncate(ratio(-14, 3)) == -4)?,
  }
}

// ------------------------------------------------------------------------ zero

test zero_1() {
  zero == ratio(0, 1)
}

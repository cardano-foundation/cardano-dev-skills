//// This module implements operations between rational numbers.
////
//// > [!CAUTION]
//// > Internally, rational aren't automatically reduced as this is **only done on-demand**.
//// >
//// > Thus, for example:
//// >
//// > ```aiken
//// > rational.new(2, 3) != rational.new(4, 6)
//// > ```
//// >
//// > Comparing rational values should, therefore, only happen after reduction (see [reduce](#reduce)) or via the [compare](#compare) method.

use aiken/builtin
use aiken/collection/list
use aiken/math
use aiken/option

/// Opaque type used to ensure the sign of the Rational is managed strictly in the numerator.
pub opaque type Rational {
  numerator: Int,
  denominator: Int,
}

// ## Constructing

/// Create a new `Rational` from an `Int`.
///
/// ```aiken
/// Some(rational.from_int(14)) == rational.new(14, 1)
/// Some(rational.from_int(-5)) == rational.new(-5, 1)
/// Some(rational.from_int(0)) == rational.new(0, 1)
/// ```
pub fn from_int(numerator: Int) -> Rational {
  Rational { numerator, denominator: 1 }
}

/// An unsafe constructor for `Rational` values. Assumes that the following invariants are
/// enforced:
///
/// - the denominator is positive (the sign is managed in the numerator);
/// - the denominator is not null.
///
/// This function is mainly used as a quick way to construct rationals from literal values.
fn ratio(numerator: Int, denominator: Int) -> Rational {
  Rational { numerator, denominator }
}

/// Make a `Rational` number from the ratio of two integers.
///
/// Returns `None` when the denominator is null.
///
/// ```aiken
/// rational.new(14, 42) == Some(r)
/// rational.new(14, 0) == None
/// ```
pub fn new(numerator: Int, denominator: Int) -> Option<Rational> {
  if denominator == 0 {
    None
  } else if denominator < 0 {
    Some(Rational { numerator: -numerator, denominator: -denominator })
  } else {
    Some(Rational { numerator, denominator })
  }
}

/// A null `Rational`.
pub const zero: Rational = Rational { numerator: 0, denominator: 1 }

// ## Inspecting

/// Get the denominator of a rational value.
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// rational.denominator(x) == 3
/// ```
pub fn denominator(self: Rational) -> Int {
  self.denominator
}

/// Get the numerator of a rational value.
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// rational.numerator(x) == 2
/// ```
pub fn numerator(self: Rational) -> Int {
  self.numerator
}

// ## Modifying

/// Absolute value of a `Rational`.
///
/// ```aiken
/// expect Some(x) = rational.new(3, 2)
/// expect Some(y) = rational.new(-3, 2)
///
/// rational.abs(x) == x
/// rational.abs(y) == x
/// ```
pub fn abs(self: Rational) -> Rational {
  let Rational { numerator: a_n, denominator: a_d } = self
  Rational { numerator: math.abs(a_n), denominator: a_d }
}

/// Change the sign of a `Rational`.
///
/// ```aiken
/// expect Some(x) = rational.new(3, 2)
/// expect Some(y) = rational.new(-3, 2)
///
/// rational.negate(x) == y
/// rational.negate(y) == x
/// ```
pub fn negate(a: Rational) -> Rational {
  let Rational { numerator: a_n, denominator: a_d } = a
  Rational { numerator: -a_n, denominator: a_d }
}

/// Reciprocal of a `Rational` number. That is, a new `Rational` where the
/// numerator and denominator have been swapped.
///
/// ```aiken
/// expect Some(x) = rational.new(2, 5)
/// rational.reciprocal(x) == rational.new(5, 2)
///
/// let y = rational.zero
/// rational.reciprocal(y) == None
/// ```
pub fn reciprocal(self: Rational) -> Option<Rational> {
  let Rational { numerator: a_n, denominator: a_d } = self
  if a_n < 0 {
    Some(Rational { numerator: -a_d, denominator: -a_n })
  } else if a_n > 0 {
    Some(Rational { numerator: a_d, denominator: a_n })
  } else {
    None
  }
}

/// Reduce a rational to its irreducible form. This operation makes the
/// numerator and denominator coprime.
///
/// ```aiken
/// expect Some(x) = rational.new(80, 200)
/// Some(rational.reduce(x)) == rational.new(2, 5)
/// ```
pub fn reduce(self: Rational) -> Rational {
  let Rational { numerator: a_n, denominator: a_d } = self
  let d = math.gcd(a_n, a_d)
  Rational { numerator: a_n / d, denominator: a_d / d }
}

// ## Combining

// ### Arithmetic operations

/// Addition: sum of two rational values
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// expect Some(y) = rational.new(3, 4)
///
/// Some(rational.add(x, y)) == rational.new(17, 12)
/// ```
pub fn add(left: Rational, right: Rational) -> Rational {
  let Rational { numerator: a_n, denominator: a_d } = left
  let Rational { numerator: b_n, denominator: b_d } = right
  Rational { numerator: a_n * b_d + b_n * a_d, denominator: a_d * b_d }
}

/// Division: quotient of two rational values. Returns `None` when the second
/// value is null.
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// expect Some(y) = rational.new(3, 4)
///
/// rational.div(x, y) == rational.new(8, 9)
/// ```
pub fn div(left: Rational, right: Rational) -> Option<Rational> {
  reciprocal(right) |> option.map(mul(left, _))
}

/// Multiplication: the product of two rational values.
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// expect Some(y) = rational.new(3, 4)
///
/// Some(rational.mul(x, y)) == rational.new(6, 12)
/// ```
pub fn mul(left: Rational, right: Rational) -> Rational {
  let Rational { numerator: a_n, denominator: a_d } = left
  let Rational { numerator: b_n, denominator: b_d } = right
  Rational { numerator: a_n * b_n, denominator: a_d * b_d }
}

/// Subtraction: difference of two rational values
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// expect Some(y) = rational.new(3, 4)
///
/// Some(rational.sub(x, y)) == rational.new(-1, 12)
/// ```
pub fn sub(left: Rational, right: Rational) -> Rational {
  let Rational { numerator: a_n, denominator: a_d } = left
  let Rational { numerator: b_n, denominator: b_d } = right
  Rational { numerator: a_n * b_d - b_n * a_d, denominator: a_d * b_d }
}

// ### Ordering

/// Compare two rationals for an ordering. This is safe to use even for
/// non-reduced rationals.
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// expect Some(y) = rational.new(3, 4)
/// expect Some(z) = rational.new(4, 6)
///
/// compare(x, y) == Less
/// compare(y, x) == Greater
/// compare(x, x) == Equal
/// compare(x, z) == Equal
/// ```
pub fn compare(left: Rational, right: Rational) -> Ordering {
  let Rational { numerator: a_n, denominator: a_d } = left
  let Rational { numerator: b_n, denominator: b_d } = right

  let l = a_n * b_d
  let r = b_n * a_d

  if l < r {
    Less
  } else if l > r {
    Greater
  } else {
    Equal
  }
}

/// Comparison of two rational values using a chosen heuristic. For example:
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// expect Some(y) = rational.new(3, 4)
///
/// rational.compare_with(x, >, y) == False
/// rational.compare_with(y, >, x) == True
/// rational.compare_with(x, >, x) == False
/// rational.compare_with(x, >=, x) == True
/// rational.compare_with(x, ==, x) == True
/// rational.compare_with(x, ==, y) == False
/// ```
pub fn compare_with(
  left: Rational,
  with: fn(Int, Int) -> Bool,
  right: Rational,
) -> Bool {
  let Rational { numerator: a_n, denominator: a_d } = left
  let Rational { numerator: b_n, denominator: b_d } = right
  with(a_n * b_d, b_n * a_d)
}

// ### Means

/// Calculate the arithmetic mean between two `Rational` values.
///
/// ```aiken
/// let x = rational.from_int(0)
/// let y = rational.from_int(1)
/// let z = rational.from_int(2)
///
/// expect Some(result) = rational.arithmetic_mean([x, y, z])
///
/// rational.compare(result, y) == Equal
/// ```
pub fn arithmetic_mean(self: List<Rational>) -> Option<Rational> {
  div(list.foldr(self, zero, add), from_int(list.length(self)))
}

/// Calculate the geometric mean between two `Rational` values. This returns
/// either the exact result or the smallest integer nearest to the square root
/// for the numerator and denominator.
///
/// ```aiken
/// expect Some(x) = rational.new(1, 3)
/// expect Some(y) = rational.new(1, 6)
///
/// rational.geometric_mean(x, y) == rational.new(1, 4)
/// ```
pub fn geometric_mean(left: Rational, right: Rational) -> Option<Rational> {
  let Rational { numerator: a_n, denominator: a_d } = left
  let Rational { numerator: b_n, denominator: b_d } = right
  when math.sqrt(a_n * b_n) is {
    Some(numerator) ->
      when math.sqrt(a_d * b_d) is {
        Some(denominator) -> Some(Rational { numerator, denominator })
        None -> None
      }
    None -> None
  }
}

// ## Transforming

/// Returns the smallest `Int` not less than a given `Rational`
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// rational.ceil(x) == 1
///
/// expect Some(y) = rational.new(44, 14)
/// rational.ceil(y) == 4
///
/// expect Some(z) = rational.new(-14, 3)
/// rational.ceil(z) == -4
/// ```
pub fn ceil(self: Rational) -> Int {
  let Rational { numerator, denominator } = self
  if builtin.remainder_integer(numerator, denominator) > 0 {
    builtin.quotient_integer(numerator, denominator) + 1
  } else {
    builtin.quotient_integer(numerator, denominator)
  }
}

/// Returns the greatest `Int` no greater than a given `Rational`
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// rational.floor(x) == 0
///
/// expect Some(y) = rational.new(44, 14)
/// rational.floor(y) == 3
///
/// expect Some(z) = rational.new(-14, 3)
/// rational.floor(z) == -5
/// ```
pub fn floor(self: Rational) -> Int {
  let Rational { numerator: a_n, denominator: a_d } = self
  a_n / a_d
}

/// Computes the rational number x raised to the power y. Returns `None` for
/// invalid exponentiation.
///
/// ```aiken
/// expect Some(x) = rational.new(50, 2500)
/// rational.reduce(rational.pow(x, 3)) == rational.new(1, 125000)
///
/// expect Some(x) = rational.new(50, 2500)
/// rational.reduce(rational.pow(x, -3)) == rational.new(125000, 1)
/// ```
pub fn pow(x: Rational, y: Int) -> Option<Rational> {
  let Rational { numerator: a, denominator: b } = x

  if a == 0 && y <= 0 {
    None
  } else if y > 0 {
    Some(Rational { numerator: math.pow(a, y), denominator: math.pow(b, y) })
  } else if y < 0 {
    Some(Rational { numerator: math.pow(b, -y), denominator: math.pow(a, -y) })
  } else {
    Some(Rational { numerator: 1, denominator: 1 })
  }
}

/// Returns the proper fraction of a given `Rational` `r`. That is, a 2-tuple of
/// an `Int` and `Rational` (n, f) such that:
///
/// - `r = n + f`;
/// - `n` and `f` have the same sign as `r`;
/// - `f` has an absolute value less than 1.
pub fn proper_fraction(self: Rational) -> (Int, Rational) {
  let Rational { numerator, denominator } = self
  (
    builtin.quotient_integer(numerator, denominator),
    Rational {
      numerator: builtin.remainder_integer(numerator, denominator),
      denominator,
    },
  )
}

/// Round the argument to the nearest whole number. If the argument is
/// equidistant between two values, the greater value is returned (it
/// rounds half towards positive infinity).
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// rational.round(x) == 1
///
/// expect Some(y) = rational.new(3, 2)
/// rational.round(y) == 2
///
/// expect Some(z) = rational.new(-3, 2)
/// rational.round(z) == -1
/// ```
///
/// > [!CAUTION]
/// > This behaves differently than _Haskell_. If you're coming from `PlutusTx`, beware that in Haskell, rounding on equidistant values depends on the whole number being odd or even.
/// > If you need this behaviour, use [`round_even`](#round_even).
pub fn round(self: Rational) -> Int {
  let (n, f) = proper_fraction(self)

  let is_negative = f.numerator < 0

  when compare(abs(f), ratio(1, 2)) is {
    Less -> n
    Equal ->
      if is_negative {
        n
      } else {
        n + 1
      }
    Greater ->
      if is_negative {
        n - 1
      } else {
        n + 1
      }
  }
}

/// Round the argument to the nearest whole number. If the argument is
/// equidistant between two values, it returns the value that is even (it
/// rounds half to even, also known as 'banker's rounding').
///
/// ```aiken
/// expect Some(w) = rational.new(2, 3)
/// rational.round_even(w) == 1
///
/// expect Some(x) = rational.new(3, 2)
/// rational.round_even(x) == 2
///
/// expect Some(y) = rational.new(5, 2)
/// rational.round_even(y) == 2
///
/// expect Some(y) = rational.new(-3, 2)
/// rational.round_even(y) == -2
/// ```
pub fn round_even(self: Rational) -> Int {
  let (n, f) = proper_fraction(self)

  let m = when compare(f, ratio(0, 1)) is {
    Less -> -1
    _ -> 1
  }

  let is_even = n % 2 == 0

  when compare(abs(f), ratio(1, 2)) is {
    Less -> n
    Equal ->
      if is_even {
        n
      } else {
        n + m
      }
    Greater -> n + m
  }
}

/// Returns the nearest `Int` between zero and a given `Rational`.
///
/// ```aiken
/// expect Some(x) = rational.new(2, 3)
/// rational.truncate(x) == 0
///
/// expect Some(y) = rational.new(44, 14)
/// rational.truncate(y) == 3
///
/// expect Some(z) = rational.new(-14, 3)
/// rational.truncate(z) == -4
/// ```
pub fn truncate(self: Rational) -> Int {
  let Rational { numerator: a_n, denominator: a_d } = self
  builtin.quotient_integer(a_n, a_d)
}

//// This module implements arithmetic operations in the scalar field associated with the BLS12-381 elliptic curve.
//// The scalar field, defined over a prime number `q`, is derived from the order of the subgroup G1.
////
//// More explicitly, we have the identity:
////
//// ```aiken
//// builtin.bls12_381_g1_scalar_mul(q, bls12_381_g1_generator) == 1
//// ```
////
//// where,
////
//// ```aiken
//// q = 52435875175126190479447740508185965837690552500527637822603658699938581184513
//// ```
////
//// This module provides functionality for basic arithmetic operations (addition, subtraction, multiplication, division) within this scalar field.
//// Additionally, it includes advanced operations such as exponentiation and calculation of multiplicative inverses, tailored for cryptographic applications.

use aiken/builtin
use aiken/crypto/bitwise.{State, one, zero}

/// The prime number defining the scalar field of the BLS12-381 curve.
pub const field_prime =
  52435875175126190479447740508185965837690552500527637822603658699938581184513

pub const field_size = 32

pub type Scalar =
  ByteArray

// ## Constructing
/// Constructs a new `Scalar` element from a Big-Endian (most-significant bits first) `ByteArray`.
pub fn from_bytes(b: ByteArray) -> State<Scalar> {
  b
    |> builtin.bytearray_to_integer(True, _)
    |> bitwise.from_int(field_prime)
}

/// Constructs a new `Scalar` element from a Little-Endian (least-significant bits first) `ByteArray`.
pub fn from_bytes_little_endian(bytes: ByteArray) -> State<Scalar> {
  bytes
    |> builtin.bytearray_to_integer(False, _)
    |> bitwise.from_int(field_prime)
}

/// Constructs a new `Scalar` element from an integer, ensuring it's within the valid range of the field.
pub fn from_int(n: Int) -> State<Scalar> {
  bitwise.from_int(n, field_prime)
}

type BitwiseScalarBytes =
  fn(State<Scalar>, ByteArray) -> State<Scalar>

type BitwiseScalarInt =
  fn(State<Scalar>, Int) -> State<Scalar>

type BitwiseScalarState =
  fn(State<Scalar>, State<Scalar>) -> State<Scalar>

// ## Modifying

/// Exponentiates an `Scalar` element by a non-negative integer exponent, using repeated squaring.
/// Note that this function returns `scalar.zero` for negative exponents.
/// A dedicated builtin function for this is in the making, see CIP 109.
pub fn scale(self: State<Scalar>, e: Int) -> State<Scalar> {
  bitwise.scale(self, e, mul)
}

/// A faster version of `scale` for the case where the exponent is a power of two.
/// That is, the exponent `e = 2^k` for some non-negative integer `k`. Which is used alot in zk-SNARKs.
pub fn scale2(self: State<Scalar>, k: Int) -> State<Scalar> {
  bitwise.scale2(self, k, mul)
}

// ## Combining

const add_s_scalar: BitwiseScalarState = bitwise.add_state(field_prime)

/// Adds two `Scalar` elements, ensuring the result stays within the finite field range.
pub fn add(left: State<Scalar>, right: State<Scalar>) -> State<Scalar> {
  add_s_scalar(left, right)
}

const add_bit_scalar: BitwiseScalarBytes = bitwise.add_bits(field_prime, True)

pub fn add_bytes(intermediate: State<Scalar>, bytes: ByteArray) -> State<Scalar> {
  add_bit_scalar(intermediate, bytes)
}

const add_i_scalar: BitwiseScalarInt = bitwise.add_int(field_prime)

pub fn add_int(intermediate: State<Scalar>, int: Int) -> State<Scalar> {
  add_i_scalar(intermediate, int)
}

/// Divides one `Scalar` element by another, returning `None` if the divisor is zero.
pub fn div(left: State<Scalar>, right: State<Scalar>) -> Option<State<Scalar>> {
  if right == zero {
    None
  } else {
    Some(mul(left, scale(right, field_prime - 2)))
  }
}

pub fn div_int(left: State<Scalar>, right: Int) -> Option<State<Scalar>> {
  let right = from_int(right)
  if right == zero {
    None
  } else {
    Some(mul(left, scale(right, field_prime - 2)))
  }
}

pub fn div_bytes(left: State<Scalar>, right: ByteArray) -> Option<State<Scalar>> {
  let right = from_bytes(right)

  if right == zero {
    None
  } else {
    Some(mul(left, scale(right, field_prime - 2)))
  }
}

const mul_s_scalar: BitwiseScalarState = bitwise.mul_state(field_prime)

/// Multiplies two `Scalar` elements, with the result constrained within the finite field.
pub fn mul(left: State<Scalar>, right: State<Scalar>) -> State<Scalar> {
  mul_s_scalar(left, right)
}

const mul_bit_scalar: BitwiseScalarBytes = bitwise.mul_bits(field_prime, True)

pub fn mul_bytes(intermediate: State<Scalar>, bytes: ByteArray) -> State<Scalar> {
  mul_bit_scalar(intermediate, bytes)
}

const mul_i_scalar: BitwiseScalarInt = bitwise.mul_int(field_prime)

pub fn mul_int(intermediate: State<Scalar>, int: Int) -> State<Scalar> {
  mul_i_scalar(intermediate, int)
}

const neg_scalar: fn(State<Scalar>) -> State<Scalar> = bitwise.neg(field_prime)

/// Calculates the additive inverse of a `Scalar` element.
pub fn neg(intermediate: State<Scalar>) -> State<Scalar> {
  neg_scalar(intermediate)
}

/// Calculates the multiplicative inverse of an `Scalar` element, returning `None` if the element is zero.
pub fn recip(self: State<Scalar>) -> Option<State<Scalar>> {
  div(one, self)
}

const sub_s_scalar: BitwiseScalarState = bitwise.sub_state(field_prime)

/// Subtracts one `Scalar` element from another, with the result wrapped within the finite field range.
pub fn sub(left: State<Scalar>, right: State<Scalar>) -> State<Scalar> {
  sub_s_scalar(left, right)
}

const sub_bit_scalar: BitwiseScalarBytes = bitwise.sub_bits(field_prime, True)

pub fn sub_bytes(intermediate: State<Scalar>, bytes: ByteArray) -> State<Scalar> {
  sub_bit_scalar(intermediate, bytes)
}

const sub_i_scalar: BitwiseScalarInt = bitwise.sub_int(field_prime)

pub fn sub_int(intermediate: State<Scalar>, int: Int) -> State<Scalar> {
  sub_i_scalar(intermediate, int)
}

// ## Transforming

/// Converts a `Scalar` element back to its integer representation.
pub fn to_int(s: State<Scalar>) -> Int {
  bitwise.to_int(s)
}

/// Converts a `Scalar` element to a Big-Endian (most-significant bits first) `ByteArray`.
pub fn to_bytes(s: State<Scalar>) -> ByteArray {
  s |> bitwise.to_int |> builtin.integer_to_bytearray(True, field_size, _)
}

/// Converts a `Scalar` element to a Little-Endian (least-significant bits first) `ByteArray`.
pub fn to_bytes_little_endian(s: State<Scalar>) -> ByteArray {
  s |> bitwise.to_int |> builtin.integer_to_bytearray(False, field_size, _)
}

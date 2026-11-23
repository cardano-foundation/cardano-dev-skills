//// Tests for `common/inputs`, the public-input check both verifiers share.

use aiken/collection/list
use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/fuzz
use common/inputs.{check_public_inputs}

/// A uniformly random value in `[0, r)`.
fn in_field() -> Fuzzer<Int> {
  fuzz.int_between(0, field_prime - 1)
}

/// A value outside `[0, r)`, on either side.
fn out_of_field() -> Fuzzer<Int> {
  fuzz.either(fuzz.int_at_least(field_prime), fuzz.int_at_most(-1))
}

/// A list length to compare against, including one below zero.
fn some_count() -> Fuzzer<Int> {
  fuzz.int_between(-1, 9)
}

/// Any list of in-range values passes for its own length, and fails for every
/// other length.
test prop_check_public_inputs_count(
  (xs, other) via fuzz.tuple(fuzz.list_between(in_field(), 0, 8), some_count()),
) {
  let n = list.length(xs)
  and {
    check_public_inputs(xs, n),
    check_public_inputs(xs, other) == ( other == n ),
  }
}

/// One out-of-range value anywhere in the list makes it fail.
test prop_check_public_inputs_range(
  (xs, index, bad) via fuzz.tuple3(
    fuzz.list_between(in_field(), 1, 8),
    fuzz.int_between(0, 7),
    out_of_field(),
  ),
) {
  let i = index % list.length(xs)
  let ys =
    list.indexed_map(
      xs,
      fn(j, x) {
        if j == i {
          bad
        } else {
          x
        }
      },
    )
  !check_public_inputs(ys, list.length(ys))
}

test check_public_inputs_empty() {
  and {
    check_public_inputs([], 0),
    !check_public_inputs([], 1),
    !check_public_inputs([0], 0),
  }
}

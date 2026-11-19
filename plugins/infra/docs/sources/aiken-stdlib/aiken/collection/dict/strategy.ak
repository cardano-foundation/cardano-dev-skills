//// This module contains strategies used to transform [`Dict`](../dict.html#Dict). You can safely ignore this module if you aren't using [`union_with`](../dict.html#union_with) nor [`insert_with`](../dict.html#insert_with).

/// A strategy for combining two values in a dictionary that belong to the same key.
pub type UnionStrategy<key, value> =
  fn(key, value, value, KeepValue<key, value>, DiscardValue<key, value>) ->
    Pairs<key, value>

/// A strategy for inserting a value from a dictionary into another.
pub type InsertStrategy<key, value> =
  fn(key, value, KeepValue<key, value>, DiscardValue<key, value>) ->
    Pairs<key, value>

/// A callback to keep a combined value at a given key
pub type KeepValue<key, value> =
  fn(value) -> Pairs<key, value>

/// A callback to discard a value at a given key
pub type DiscardValue<key, value> =
  fn() -> Pairs<key, value>

// ### Insert Strategies

/// Discard the value
///
/// ```aiken
/// fn(_key, _right, _keep, discard) { discard() }
/// ```
pub fn discard() -> InsertStrategy<key, value> {
  fn(_key, _right, _keep, discard) { discard() }
}

/// Keep and insert the value.
///
/// ```aiken
/// fn(_key, right, keep, _discard) { keep(right) }
/// ```
pub fn keep() -> InsertStrategy<key, value> {
  fn(_key, right, keep, _discard) { keep(right) }
}

/// Keep the value and negate it, effectively treating the left-side as `0`.
///
/// ```aiken
/// fn(_key, right, keep, _discard) { keep(-right) }
/// ```
pub fn negate() -> InsertStrategy<key, Int> {
  fn(_key, right, keep, _discard) { keep(-right) }
}

/// A strategy which always fail, indicating that values should always be present
/// on the left dictionary.
///
/// ```aiken
/// fn(_key, _right, _keep, _discard) { fail }
/// ```
pub fn never() -> InsertStrategy<ByteArray, value> {
  fn(key: ByteArray, _right, _keep, _discard) {
    trace @"InsertStrategy.never": key
    fail
  }
}

// ### Union Strategies

/// Combine values by taking their difference.
///
/// ```aiken
/// fn(_key, left, right, keep, _discard) { keep(left - right) }
/// ```
pub fn difference() -> UnionStrategy<key, Int> {
  fn(_key, left, right, keep, _discard) { keep(left - right) }
}

/// Keep the resulting difference only if it's non zero; otherwise discard the key entirely.
///
/// ```aiken
/// fn(_key, left, right, keep, discard) {
///   let value = left - right
///   if value != 0 {
///     keep(value)
///   } else {
///     discard()
///   }
/// }
/// ```
pub fn difference_if_non_zero() -> UnionStrategy<key, Int> {
  fn(_key, left, right, keep, discard) {
    if left == right {
      discard()
    } else {
      keep(left - right)
    }
  }
}

/// A strategy which always fail, enforcing the dict contains no duplicate.
///
/// ```aiken
/// fn(_, _, _, _, _) {
///   fail @"unexpected duplicate key found in dict."
/// }
/// ```
pub fn expect_no_duplicate() -> UnionStrategy<ByteArray, value> {
  fn(key: ByteArray, _, _, _, _) {
    trace @"UnionStrategy.expect_no_duplicate": key
    fail
  }
}

/// Combine values by keeping the values present in the left-most dict.
///
/// ```aiken
/// fn(_key, left, _right, keep, _discard) { keep(left) }
/// ```
pub fn keep_left() -> UnionStrategy<key, value> {
  fn(_key, left, _right, keep, _discard) { keep(left) }
}

/// Combine values by keeping the values present in the right-most dict.
///
/// ```aiken
/// fn(_key, _left, right, keep, _discard) { keep(right) }
/// ```
pub fn keep_right() -> UnionStrategy<key, value> {
  fn(_key, _left, right, keep, _discard) { keep(right) }
}

/// Combine values by taking their sum.
///
/// ```aiken
/// fn(_key, left, right, keep, _discard) { keep(left + right) }
/// ```
pub fn sum() -> UnionStrategy<key, Int> {
  fn(_key, left, right, keep, _discard) { keep(left + right) }
}

/// Combine values by taking their sum, only if it is non-null. If the
/// resulting sum is 0, discard the key/value entirely.
///
/// ```aiken
/// fn(_key, left, right, keep, discard) {
///   let value = left + right
///   if value == 0 {
///     discard()
///   } else {
///     keep(value)
///   }
/// }
/// ```
pub fn sum_if_non_zero() -> UnionStrategy<key, Int> {
  fn(_key, left, right, keep, discard) {
    if left == -right {
      discard()
    } else {
      keep(left + right)
    }
  }
}

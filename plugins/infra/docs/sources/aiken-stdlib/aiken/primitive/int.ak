use aiken/builtin.{bytearray_to_integer, decode_utf8}
use aiken/math
use aiken/option
use aiken/primitive/bytearray

// ## Combining

/// Compare two integers.
///
/// ```aiken
/// int.compare(14, 42) == Less
/// int.compare(14, 14) == Equal
/// int.compare(42, 14) == Greater
/// ```
pub fn compare(left: Int, right: Int) -> Ordering {
  if left < right {
    Less
  } else if left > right {
    Greater
  } else {
    Equal
  }
}

// ## Transforming

/// Interpret a Big-Endian (most-significant bytes first) `ByteArray` as an `Int`.
///
/// ```aiken
/// int.from_bytearray_big_endian(#"0f4240") == 1_000_000
/// int.from_bytearray_big_endian(#"00000f4240") == 1_000_000
/// int.from_bytearray_big_endian(#"0000000000000000") == 0
/// ```
pub fn from_bytearray_big_endian(self: ByteArray) -> Int {
  bytearray_to_integer(True, self)
}

/// Interpret a Little-Endian (least-significant bytes first) `ByteArray` as an `Int`.
///
/// ```aiken
/// int.from_bytearray_little_endian(#"40420f") == 1_000_000
/// int.from_bytearray_little_endian(#"40420f0000") == 1_000_000
/// int.from_bytearray_little_endian(#"0000000000000000") == 0
/// ```
pub fn from_bytearray_little_endian(self: ByteArray) -> Int {
  bytearray_to_integer(False, self)
}

/// Parse an integer from a utf-8 encoded `ByteArray`, when possible.
///
/// ```aiken
/// int.from_utf8("14") == Some(14)
/// int.from_utf8("-42") == Some(-42)
/// int.from_utf8("007") == Some(7)
/// int.from_utf8("foo") == None
/// int.from_utf8("1.0") == None
/// int.from_utf8("1-2") == None
/// ```
pub fn from_utf8(bytes: ByteArray) -> Option<Int> {
  bytes
    |> bytearray.foldr(
        Some((0, 0)),
        fn(byte, st) {
          when st is {
            None -> None
            Some((n, e)) ->
              if byte < 48 || byte > 57 {
                if byte == 45 {
                  Some((-n, 0))
                } else {
                  None
                }
              } else if n < 0 {
                None
              } else {
                let digit = byte - 48
                Some((n + digit * math.pow(10, e), e + 1))
              }
          }
        },
      )
    |> option.map(fn(tuple) { tuple.1st })
}

/// Convert an `Int` to its `String` representation.
///
/// ```aiken
/// int.to_string(42) == @"42"
/// ```
pub fn to_string(n: Int) -> String {
  diagnostic(n, "") |> decode_utf8
}

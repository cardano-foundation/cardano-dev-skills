use aiken/builtin.{
  append_bytearray, append_string, decode_utf8, encode_utf8, length_of_bytearray,
}

// ## Constructing

/// Convert a `ByteArray` into a `String`
///
/// > [!WARNING]
/// > This function fails if the underlying `ByteArray` isn't UTF-8-encoded. In particular, you cannot convert arbitrary hash digests using this function.
/// >
/// > For converting arbitrary `ByteArray`s, use [bytearray.to_hex](./bytearray.html#to_hex).
///
/// ```aiken
/// string.from_bytearray("foo") == @"foo"
/// string.from_bytearray(#"666f6f") == @"foo"
/// string.from_bytearray(some_hash) -> 💥
/// ```
pub fn from_bytearray(bytes: ByteArray) -> String {
  decode_utf8(bytes)
}

/// Convert an `Int` to its `String` representation.
///
/// ```aiken
/// string.from_int(42) == @"42"
/// ```
pub fn from_int(n: Int) -> String {
  diagnostic(n, "") |> decode_utf8
}

// ## Combining

/// Combine two `String` together.
///
/// ```aiken
/// string.concat(left: @"Hello", right: @", World!") == @"Hello, World!"
/// ```
pub fn concat(left: String, right: String) -> String {
  append_string(left, right)
}

/// Join a list of strings, separated by a given _delimiter_.
///
/// ```aiken
/// string.join([], @"+") == @""
/// string.join([@"a", @"b", @"c"], @",") == @"a,b,c"
/// ```
pub fn join(list: List<String>, delimiter: String) -> String {
  do_join(list, encode_utf8(delimiter), #"")
    |> decode_utf8
}

fn do_join(xs, delimiter, bytes) {
  when xs is {
    [] -> bytes
    [x, ..rest] ->
      do_join(
        rest,
        delimiter,
        if length_of_bytearray(bytes) == 0 {
          encode_utf8(x)
        } else {
          append_bytearray(bytes, append_bytearray(delimiter, encode_utf8(x)))
        },
      )
  }
}

// ## Transforming

/// Convert a `String` into a `ByteArray`
///
/// ```aiken
/// string.to_bytearray(@"foo") == "foo"
/// ```
pub fn to_bytearray(self: String) -> ByteArray {
  encode_utf8(self)
}

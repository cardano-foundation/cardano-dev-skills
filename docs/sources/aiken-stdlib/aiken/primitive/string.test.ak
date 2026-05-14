use aiken/primitive/string.{
  concat, from_bytearray, from_int, join, to_bytearray,
}

// -------------------------------------------------------------- from_bytearray

test from_bytearray_1() {
  from_bytearray(#[]) == @""
}

test from_bytearray_2() {
  from_bytearray(#[65, 66, 67]) == @"ABC"
}

test from_bytearray_3() {
  from_bytearray("ABC") == @"ABC"
}

// -------------------------------------------------------------------- from_int

test from_int_1() {
  from_int(0) == @"0"
}

test from_int_2() {
  from_int(5) == @"5"
}

test from_int_3() {
  from_int(42) == @"42"
}

test from_int_4() {
  from_int(200) == @"200"
}

// ---------------------------------------------------------------------- concat

test concat_1() {
  concat(@"", @"") == @""
}

test concat_2() {
  concat(@"", @"foo") == concat(@"foo", @"")
}

test concat_3() {
  concat(left: @"Hello", right: @", World!") == @"Hello, World!"
}

// ------------------------------------------------------------------------ join

test join_1() {
  join([], @",") == @""
}

test join_2() {
  join([@"a", @"b", @"c"], @",") == @"a,b,c"
}

// ---------------------------------------------------------------- to_bytearray

test to_bytearray_1() {
  to_bytearray(@"") == ""
}

test to_bytearray_2() {
  to_bytearray(@"ABC") == #[65, 66, 67]
}

test to_bytearray_3() {
  to_bytearray(@"ABC") == "ABC"
}

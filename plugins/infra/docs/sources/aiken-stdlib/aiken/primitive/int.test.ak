use aiken/primitive/int.{
  from_bytearray_big_endian, from_bytearray_little_endian, from_utf8, to_string,
}

// --------------------------------------------------- from_bytearray_big_endian

test from_bytearray_big_endian_1() {
  from_bytearray_big_endian(#"0f4240") == 1_000_000
}

test from_bytearray_big_endian_2() {
  from_bytearray_big_endian(#"00000f4240") == 1_000_000
}

test from_bytearray_big_endian_3() {
  from_bytearray_big_endian(#"0000000000000000") == 0
}

// ------------------------------------------------ from_bytearray_little_endian

test from_bytearray_little_endian_1() {
  from_bytearray_little_endian(#"40420f") == 1_000_000
}

test from_bytearray_little_endian_2() {
  from_bytearray_little_endian(#"40420f0000") == 1_000_000
}

test from_bytearray_little_endian_3() {
  from_bytearray_little_endian(#"0000000000000000") == 0
}

// ------------------------------------------------------------------- from_utf8

test from_utf8_1() {
  from_utf8("0017") == Some(17)
}

test from_utf8_2() {
  from_utf8("42") == Some(42)
}

test from_utf8_3() {
  from_utf8("1337") == Some(1337)
}

test from_utf8_4() {
  from_utf8("-14") == Some(-14)
}

test from_utf8_5() {
  from_utf8("foo") == None
}

test from_utf8_6() {
  from_utf8("1-2") == None
}

// ------------------------------------------------------------------- to_string

test to_string_1() {
  to_string(0) == @"0"
}

test to_string_2() {
  to_string(5) == @"5"
}

test to_string_3() {
  to_string(42) == @"42"
}

test to_string_4() {
  to_string(200) == @"200"
}

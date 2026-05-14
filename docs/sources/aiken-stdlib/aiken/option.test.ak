use aiken/option.{
  and_then, choice, flatten, is_none, is_some, map, map2, map3, or_else, or_try,
}

// --------------------------------------------------------------------- helpers

fn try_decrement(n: Int) -> Option<Int> {
  if n > 0 {
    Some(n - 1)
  } else {
    None
  }
}

// --------------------------------------------------------------------- is_none

test is_none_1() {
  is_none(Some(0)) == False
}

test is_none_2() {
  is_none(None) == True
}

// --------------------------------------------------------------------- is_some

test is_some_1() {
  is_some(Some(0)) == True
}

test is_some_2() {
  is_some(None) == False
}

// -------------------------------------------------------------------- and_then

test and_then_1() {
  let result = None
    |> and_then(try_decrement)
  result == None
}

test and_then_2() {
  let result = Some(14)
    |> and_then(try_decrement)
  result == Some(13)
}

test and_then_3() {
  let result = Some(0)
    |> and_then(try_decrement)
  result == None
}

// ---------------------------------------------------------------------- choice

test choice_1() {
  Some(1) == choice([Some(1), Some(2)])
}

test choice_2() {
  None == choice([])
}

test choice_3() {
  Some(1) == choice([None, Some(1)])
}

// --------------------------------------------------------------------- flatten

test flatten_1() {
  let x: Option<Option<Int>> = Some(Some(6))
  Some(6) == flatten(x)
}

test flatten_2() {
  let x: Option<Option<Int>> = Some(None)
  None == flatten(x)
}

test flatten_3() {
  let x: Option<Option<Int>> = None
  None == flatten(x)
}

test flatten_4() {
  let x: Option<Option<Option<Int>>> = Some(Some(Some(6)))

  let result = x
    |> flatten
    |> flatten

  Some(6) == result
}

// ------------------------------------------------------------------------- map

test map_1() {
  map(None, fn(_) { Void }) == None
}

test map_2() {
  map(Some(14), fn(n) { n + 1 }) == Some(15)
}

// ------------------------------------------------------------------------ map2

test map2_1() {
  map2(None, Some(42), fn(_, _) { 14 }) == None
}

test map2_2() {
  map2(Some(42), None, fn(_, _) { 14 }) == None
}

test map2_3() {
  map2(Some(14), Some(42), fn(a, b) { (a, b) }) == Some((14, 42))
}

// ------------------------------------------------------------------------ map3

test map3_1() {
  map3(None, Some(42), None, fn(_, _, _) { 14 }) == None
}

test map3_2() {
  map3(Some(42), None, None, fn(_, _, _) { 14 }) == None
}

test map3_3() {
  map3(Some(14), Some(42), Some(1337), fn(a, b, c) { c - a + b }) == Some(1365)
}

// ---------------------------------------------------------------------- or_try

test or_try_1() {
  or_try(None, fn() { Some("aiken") }) == Some("aiken")
}

test or_try_2() {
  or_try(Some(42), fn() { fail }) == Some(42)
}

// --------------------------------------------------------------------- or_else

test or_else_1() {
  or_else(None, "aiken") == "aiken"
}

test or_else_2() {
  or_else(Some(42), 14) == 42
}

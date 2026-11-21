use aiken/builtin
use aiken/collection/pairs.{
  delete_all, delete_first, delete_last, expect_delete_first, expect_find_first,
  expect_find_last, expect_get_first, expect_get_last, expect_has_key,
  expect_pop_until, expect_pop_until_and_then, expect_pop_until_key,
  expect_pop_until_key_and_then, find_all, find_first, find_last, foldl, foldr,
  get_all, get_first, get_last, has_key, insert_by_ascending_key,
  insert_with_by_ascending_key, keys, map, pop_until, pop_until_and_then,
  pop_until_key, pop_until_key_and_then, repsert_by_ascending_key, values,
}
use aiken/primitive/bytearray

// ---------------------------------------------------------- fixtures & fuzzers

const fixture_bench =
  [
    Pair("a", 1), Pair("b", 2), Pair("c", 3), Pair("d", 4), Pair("e", 5),
    Pair("f", 6), Pair("g", 7), Pair("h", 8), Pair("i", 9), Pair("j", 10),
    Pair("k", 11),
  ]

// --------------------------------------------------------------------- helpers

fn tautology(a: a) -> Bool {
  a == a
}

// --------------------------------------------------------------------- get_all

test get_all_1() {
  get_all([], "a") == []
}

test get_all_2() {
  get_all([Pair("a", 1)], "a") == [1]
}

test get_all_3() {
  get_all([Pair("a", 1), Pair("b", 2)], "a") == [1]
}

test get_all_4() {
  get_all([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [1, 3]
}

test get_all_5() {
  get_all([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") == []
}

// ------------------------------------------------------------------- get_first

test get_first_1() {
  get_first([], "a") == None
}

test get_first_2() {
  get_first([Pair("a", 1)], "a") == Some(1)
}

test get_first_3() {
  get_first([Pair("a", 1), Pair("b", 2)], "a") == Some(1)
}

test get_first_4() {
  get_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == Some(1)
}

test get_first_5() {
  get_first([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") == None
}

test get_first_bench() {
  and {
    get_first(fixture_bench, "a") == Some(1),
    get_first(fixture_bench, "f") == Some(6),
    get_first(fixture_bench, "k") == Some(11),
  }
}

// -------------------------------------------------------------------- get_last

test get_last_1() {
  get_last([], "a") == None
}

test get_last_2() {
  get_last([Pair("a", 1)], "a") == Some(1)
}

test get_last_3() {
  get_last([Pair("a", 1), Pair("b", 2)], "a") == Some(1)
}

test get_last_4() {
  get_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == Some(3)
}

test get_last_5() {
  get_last([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") == None
}

test get_last_bench() {
  and {
    get_last(fixture_bench, "a") == Some(1),
    get_last(fixture_bench, "f") == Some(6),
    get_last(fixture_bench, "k") == Some(11),
  }
}

// -------------------------------------------------------------------- find_all

test find_all_1() {
  find_all([], "a") == []
}

test find_all_2() {
  find_all([Pair("a", 14)], 14) == ["a"]
}

test find_all_3() {
  find_all([Pair("a", 14)], 42) == []
}

test find_all_4() {
  find_all([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == ["a", "c"]
}

// ------------------------------------------------------------------ find_first

test find_first_1() {
  find_first([], "a") == None
}

test find_first_2() {
  find_first([Pair("a", 14)], 14) == Some("a")
}

test find_first_3() {
  find_first([Pair("a", 14)], 42) == None
}

test find_first_4() {
  find_first([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == Some("a")
}

test find_first_bench() {
  and {
    find_first(fixture_bench, 1) == Some("a"),
    find_first(fixture_bench, 6) == Some("f"),
    find_first(fixture_bench, 11) == Some("k"),
  }
}

// ------------------------------------------------------------------- find_last

test find_last_1() {
  find_last([], "a") == None
}

test find_last_2() {
  find_last([Pair("a", 14)], 14) == Some("a")
}

test find_last_3() {
  find_last([Pair("a", 14)], 42) == None
}

test find_last_4() {
  find_last([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == Some("c")
}

test find_last_bench() {
  and {
    find_last(fixture_bench, 1) == Some("a"),
    find_last(fixture_bench, 6) == Some("f"),
    find_last(fixture_bench, 11) == Some("k"),
  }
}

// --------------------------------------------------------------------- has_key

test has_key_1() {
  !has_key([], "a")
}

test has_key_2() {
  has_key([Pair("a", 14)], "a")
}

test has_key_3() {
  !has_key([Pair("a", 14)], "b")
}

test has_key_4() {
  has_key([Pair("a", 14), Pair("b", 42)], "b")
}

test has_key_5() {
  has_key([Pair("a", 14), Pair("b", 42), Pair("a", 42)], "a")
}

test has_key_bench() {
  and {
    has_key(fixture_bench, "a"),
    has_key(fixture_bench, "f"),
    has_key(fixture_bench, "k"),
  }
}

// ------------------------------------------------------------------------ keys

test keys_1() {
  keys([]) == []
}

test keys_2() {
  keys([Pair("a", 0)]) == ["a"]
}

test keys_3() {
  keys([Pair("a", 0), Pair("b", 0)]) == ["a", "b"]
}

// ---------------------------------------------------------------------- values

test values_1() {
  values([]) == []
}

test values_2() {
  values([Pair("a", 1)]) == [1]
}

test values_3() {
  values([Pair("a", 1), Pair("b", 2)]) == [1, 2]
}

test values_4() {
  values([Pair("a", 1), Pair("b", 2), Pair("a", 3)]) == [1, 2, 3]
}

// ------------------------------------------------------------ expect_get_first

test expect_get_first_1() fail {
  expect_get_first([], "a") |> tautology
}

test expect_get_first_2() {
  expect_get_first([Pair("a", 1)], "a") == 1
}

test expect_get_first_3() {
  expect_get_first([Pair("a", 1), Pair("b", 2)], "a") == 1
}

test expect_get_first_4() {
  expect_get_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == 1
}

test expect_get_first_5() fail {
  expect_get_first([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") |> tautology
}

test expect_get_first_bench() {
  and {
    expect_get_first(fixture_bench, "a") == 1,
    expect_get_first(fixture_bench, "f") == 6,
    expect_get_first(fixture_bench, "k") == 11,
  }
}

// ------------------------------------------------------------- expect_get_last

test expect_get_last_1() fail {
  expect_get_last([], "a") |> tautology
}

test expect_get_last_2() {
  expect_get_last([Pair("a", 1)], "a") == 1
}

test expect_get_last_3() {
  expect_get_last([Pair("a", 1), Pair("b", 2)], "a") == 1
}

test expect_get_last_4() {
  expect_get_last([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == 3
}

test expect_get_last_5() fail {
  expect_get_last([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "d") |> tautology
}

test expect_get_last_bench() {
  and {
    expect_get_last(fixture_bench, "a") == 1,
    expect_get_last(fixture_bench, "f") == 6,
    expect_get_last(fixture_bench, "k") == 11,
  }
}

// ----------------------------------------------------------- expect_find_first

test expect_find_first_1() fail {
  expect_find_first([], "a") |> tautology
}

test expect_find_first_2() {
  expect_find_first([Pair("a", 14)], 14) == "a"
}

test expect_find_first_3() fail {
  expect_find_first([Pair("a", 14)], 42) |> tautology
}

test expect_find_first_4() {
  expect_find_first([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == "a"
}

test expect_find_first_bench() {
  and {
    expect_find_first(fixture_bench, 1) == "a",
    expect_find_first(fixture_bench, 6) == "f",
    expect_find_first(fixture_bench, 11) == "k",
  }
}

// ------------------------------------------------------------ expect_find_last

test expect_find_last_1() fail {
  expect_find_last([], "a") |> tautology
}

test expect_find_last_2() {
  expect_find_last([Pair("a", 14)], 14) == "a"
}

test expect_find_last_3() fail {
  expect_find_last([Pair("a", 14)], 42) |> tautology
}

test expect_find_last_4() {
  expect_find_last([Pair("a", 14), Pair("b", 42), Pair("c", 14)], 14) == "c"
}

test expect_find_last_bench() {
  and {
    expect_find_last(fixture_bench, 1) == "a",
    expect_find_last(fixture_bench, 6) == "f",
    expect_find_last(fixture_bench, 11) == "k",
  }
}

// -------------------------------------------------------------- expect_has_key

test expect_has_key_1() fail {
  expect_has_key([], "a")
}

test expect_has_key_2() {
  expect_has_key([Pair("a", 14)], "a")
}

test expect_has_key_3() fail {
  expect_has_key([Pair("a", 14)], "b")
}

test expect_has_key_4() {
  expect_has_key([Pair("a", 14), Pair("b", 42)], "b")
}

test expect_has_key_5() {
  expect_has_key([Pair("a", 14), Pair("b", 42), Pair("a", 42)], "a")
}

test expect_has_key_bench() {
  expect_has_key(fixture_bench, "a")
  expect_has_key(fixture_bench, "f")
  expect_has_key(fixture_bench, "k")
}

// ------------------------------------------------------------------ delete_all

test delete_all_1() {
  delete_all([], "a") == []
}

test delete_all_2() {
  delete_all([Pair("a", 14)], "a") == []
}

test delete_all_3() {
  let fixture = [Pair("a", 14)]
  delete_all(fixture, "b") == fixture
}

test delete_all_4() {
  let fixture = [Pair("a", 1), Pair("b", 2), Pair("a", 3)]
  delete_all(fixture, "a") == [Pair("b", 2)]
}

// ---------------------------------------------------------------- delete_first

test delete_first_1() {
  delete_first([], "a") == []
}

test delete_first_2() {
  delete_first([Pair("a", 14)], "a") == []
}

test delete_first_3() {
  let fixture = [Pair("a", 14)]
  delete_first(fixture, "b") == fixture
}

test delete_first_4() {
  let fixture = [Pair("a", 1), Pair("b", 2), Pair("a", 3)]
  delete_first(fixture, "a") == [Pair("b", 2), Pair("a", 3)]
}

// ----------------------------------------------------------------- delete_last

test delete_last_1() {
  delete_last([], "a") == []
}

test delete_last_2() {
  delete_last([Pair("a", 14)], "a") == []
}

test delete_last_3() {
  let fixture = [Pair("a", 14)]
  delete_last(fixture, "b") == fixture
}

test delete_last_4() {
  let fixture = [Pair("a", 1), Pair("b", 2), Pair("a", 3)]
  delete_last(fixture, "a") == [Pair("a", 1), Pair("b", 2)]
}

// ----------------------------------------------------- insert_by_ascending_key

test insert_by_ascending_key_1() {
  let m = []
    |> insert_by_ascending_key("foo", 42, bytearray.compare)
    |> insert_by_ascending_key("foo", 14, bytearray.compare)

  m == [Pair("foo", 14), Pair("foo", 42)]
}

test insert_by_ascending_key_2() {
  let m = []
    |> insert_by_ascending_key("foo", 42, bytearray.compare)
    |> insert_by_ascending_key("bar", 14, bytearray.compare)
    |> insert_by_ascending_key("baz", 1337, bytearray.compare)

  m == [Pair("bar", 14), Pair("baz", 1337), Pair("foo", 42)]
}

// ------------------------------------------------ insert_with_by_ascending_key

test insert_with_by_ascending_key_1() {
  let compare_un_b_data = fn(l, r) {
    bytearray.compare(l |> builtin.un_b_data, r |> builtin.un_b_data)
  }

  let m = []
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        42,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        14,
        compare_un_b_data,
        builtin.add_integer,
      )

  m == [Pair("foo" |> builtin.b_data, 56)]
}

test insert_with_by_ascending_key_2() {
  let compare_un_b_data = fn(l, r) {
    bytearray.compare(l |> builtin.un_b_data, r |> builtin.un_b_data)
  }

  let m = []
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        42,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "bar" |> builtin.b_data,
        14,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "baz" |> builtin.b_data,
        1337,
        compare_un_b_data,
        builtin.add_integer,
      )

  m == [
    Pair("bar" |> builtin.b_data, 14),
    Pair("baz" |> builtin.b_data, 1337),
    Pair("foo" |> builtin.b_data, 42),
  ]
}

test insert_with_by_ascending_key_3() {
  let compare_un_b_data = fn(l, r) {
    bytearray.compare(l |> builtin.un_b_data, r |> builtin.un_b_data)
  }

  let result = []
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        1,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "bar" |> builtin.b_data,
        2,
        compare_un_b_data,
        builtin.add_integer,
      )
    |> insert_with_by_ascending_key(
        "foo" |> builtin.b_data,
        3,
        compare_un_b_data,
        builtin.add_integer,
      )

  result == [Pair("bar" |> builtin.b_data, 2), Pair("foo" |> builtin.b_data, 4)]
}

// ------------------------------------------------------------------------- map

test map_1() {
  let fixture = [Pair("a", 1), Pair("b", 2)]

  map(fixture, with: fn(k, _) { k }) == [Pair("a", "a"), Pair("b", "b")]
}

test map_2() {
  let fixture = [Pair("a", 1), Pair("b", 2)]

  map(fixture, with: fn(_, v) { v + 1 }) == [Pair("a", 2), Pair("b", 3)]
}

// ------------------------------------------------------------------- pop_until

test pop_until_1() {
  pop_until([], fn(k, _) { k == "a" }) == (None, [])
}

test pop_until_2() {
  pop_until([Pair("a", 1), Pair("b", 2)], fn(k, _) { k == "a" }) == (
    Some(Pair("a", 1)),
    [Pair("b", 2)],
  )
}

test pop_until_3() {
  pop_until([Pair("a", 1), Pair("b", 2), Pair("c", 3)], fn(k, _) { k == "c" }) == (
    Some(Pair("c", 3)),
    [],
  )
}

test pop_until_4() {
  pop_until([Pair("a", 1), Pair("b", 2), Pair("c", 3)], fn(_, _) { False }) == (
    None,
    [],
  )
}

test pop_until_bench() {
  and {
    pop_until(fixture_bench, fn(k, _) { k == "a" }).1st == Some(Pair("a", 1)),
    pop_until(fixture_bench, fn(k, _) { k == "f" }).1st == Some(Pair("f", 6)),
    pop_until(fixture_bench, fn(k, _) { k == "k" }).1st == Some(Pair("k", 11)),
  }
}

// ---------------------------------------------------------- pop_until_and_then

test pop_until_and_then_bench() {
  and {
    pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "a" },
      fn(kv, _) { kv == Some(Pair("a", 1)) },
    ),
    pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "f" },
      fn(kv, _) { kv == Some(Pair("f", 6)) },
    ),
    pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "k" },
      fn(kv, _) { kv == Some(Pair("k", 11)) },
    ),
  }
}

// --------------------------------------------------------------- pop_until_key

test pop_until_key_1() {
  pop_until_key([], "a") == (None, [])
}

test pop_until_key_2() {
  pop_until_key([Pair("a", 1), Pair("b", 2)], "a") == (Some(1), [Pair("b", 2)])
}

test pop_until_key_3() {
  pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c") == (
    Some(3),
    [],
  )
}

test pop_until_key_4() {
  pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "") == (None, [])
}

test pop_until_key_bench() {
  and {
    pop_until_key(fixture_bench, "a").1st == Some(1),
    pop_until_key(fixture_bench, "f").1st == Some(6),
    pop_until_key(fixture_bench, "k").1st == Some(11),
  }
}

// ------------------------------------------------------ pop_until_key_and_then

test pop_until_key_and_then_bench() {
  and {
    pop_until_key_and_then(fixture_bench, "a", fn(k, _) { k == Some(1) }),
    pop_until_key_and_then(fixture_bench, "f", fn(k, _) { k == Some(6) }),
    pop_until_key_and_then(fixture_bench, "k", fn(k, _) { k == Some(11) }),
  }
}

// ---------------------------------------------------- repsert_by_ascending_key

test repsert_by_ascending_key_1() {
  let m = []
    |> repsert_by_ascending_key("foo", 42, bytearray.compare)
    |> repsert_by_ascending_key("foo", 14, bytearray.compare)

  m == [Pair("foo", 14)]
}

test repsert_by_ascending_key_2() {
  let m = []
    |> repsert_by_ascending_key("foo", 42, bytearray.compare)
    |> repsert_by_ascending_key("bar", 14, bytearray.compare)
    |> repsert_by_ascending_key("baz", 1337, bytearray.compare)

  m == [Pair("bar", 14), Pair("baz", 1337), Pair("foo", 42)]
}

// --------------------------------------------------------- expect_delete_first

test expect_delete_first_1() fail {
  expect_delete_first([], "a") |> tautology
}

test expect_delete_first_2() {
  expect_delete_first([Pair("a", 1), Pair("b", 2), Pair("a", 3)], "a") == [
    Pair("b", 2), Pair("a", 3),
  ]
}

test expect_delete_first_3() fail {
  expect_delete_first([Pair("a", 14)], "b") |> tautology
}

// ------------------------------------------------------------ expect_pop_until

test expect_pop_until_1() fail {
  expect_pop_until([], fn(k, _) { k == "a" }) |> tautology
}

test expect_pop_until_2() {
  expect_pop_until([Pair("a", 1), Pair("b", 2)], fn(k, _) { k == "a" }) == (
    Pair("a", 1),
    [Pair("b", 2)],
  )
}

test expect_pop_until_3() {
  expect_pop_until(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(k, _) { k == "c" },
  ) == (Pair("c", 3), [])
}

test expect_pop_until_4() fail {
  expect_pop_until(
    [Pair("a", 1), Pair("b", 2), Pair("c", 3)],
    fn(_, _) { False },
  )
    |> tautology
}

test expect_pop_until_bench() {
  and {
    expect_pop_until(fixture_bench, fn(k, _) { k == "a" }).1st == Pair("a", 1),
    expect_pop_until(fixture_bench, fn(k, _) { k == "f" }).1st == Pair("f", 6),
    expect_pop_until(fixture_bench, fn(k, _) { k == "k" }).1st == Pair("k", 11),
  }
}

// --------------------------------------------------- expect_pop_until_and_then

test expect_pop_until_and_then_bench() {
  and {
    expect_pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "a" },
      fn(kv, _) { kv == Pair("a", 1) },
    ),
    expect_pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "f" },
      fn(kv, _) { kv == Pair("f", 6) },
    ),
    expect_pop_until_and_then(
      fixture_bench,
      fn(k, _) { k == "k" },
      fn(kv, _) { kv == Pair("k", 11) },
    ),
  }
}

// -------------------------------------------------------- expect_pop_until_key

test expect_pop_until_key_1() fail {
  expect_pop_until_key([], "a") |> tautology
}

test expect_pop_until_key_2() {
  expect_pop_until_key([Pair("a", 1), Pair("b", 2)], "a") == (1, [Pair("b", 2)])
}

test expect_pop_until_key_3() {
  expect_pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "c") == (
    3,
    [],
  )
}

test expect_pop_until_key_4() fail {
  expect_pop_until_key([Pair("a", 1), Pair("b", 2), Pair("c", 3)], "")
    |> tautology
}

test expect_pop_until_key_bench() {
  and {
    expect_pop_until_key(fixture_bench, "a").1st == 1,
    expect_pop_until_key(fixture_bench, "f").1st == 6,
    expect_pop_until_key(fixture_bench, "k").1st == 11,
  }
}

// ----------------------------------------------- expect_pop_until_key_and_then

test expect_pop_until_key_and_then_bench() {
  and {
    expect_pop_until_key_and_then(fixture_bench, "a", fn(k, _) { k == 1 }),
    expect_pop_until_key_and_then(fixture_bench, "f", fn(k, _) { k == 6 }),
    expect_pop_until_key_and_then(fixture_bench, "k", fn(k, _) { k == 11 }),
  }
}

// ----------------------------------------------------------------------- foldl

test foldl_1() {
  foldl([], 14, fn(_, _, _) { 42 }) == 14
}

test foldl_2() {
  foldl(
    [Pair("a", 42), Pair("b", 14)],
    zero: 0,
    with: fn(_, v, total) { v + total },
  ) == 56
}

test foldl_3() {
  "a1b2c3" == (
    [Pair("a", "1"), Pair("b", "2"), Pair("c", "3")]
      |> foldl(
          "",
          fn(k, v, str) { bytearray.concat(str, bytearray.concat(k, v)) },
        )
  )
}

// ----------------------------------------------------------------------- foldr

test foldr_1() {
  foldr([], 14, fn(_, _, _) { 42 }) == 14
}

test foldr_2() {
  foldr(
    [Pair("a", 42), Pair("b", 14)],
    zero: 0,
    with: fn(_, v, total) { v + total },
  ) == 56
}

test foldr_3() {
  let fixture = [Pair(1, 100), Pair(2, 200), Pair(3, 300)]

  foldr(fixture, 0, fn(k, v, result) { k * v + result }) == 1400
}

test foldr_4() {
  "c3b2a1" == (
    [Pair("a", "1"), Pair("b", "2"), Pair("c", "3")]
      |> foldr(
          "",
          fn(k, v, str) { bytearray.concat(str, bytearray.concat(k, v)) },
        )
  )
}

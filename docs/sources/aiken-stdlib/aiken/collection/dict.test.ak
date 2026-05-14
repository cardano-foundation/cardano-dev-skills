use aiken/builtin
use aiken/collection/dict.{
  contains, delete, difference_with, empty, expect_contains, expect_delete,
  expect_find, expect_get, expect_has_key, expect_pop, expect_tail, filter, find,
  foldl, foldl2, foldr, foldr2, from_ascending_pairs, from_pairs, get,
  get_or_else, has_key, insert, insert_with, is_empty, keys, map, pop, singleton,
  size, to_pairs, union, union_with, values,
}
use aiken/collection/dict/strategy
use aiken/primitive/int

// ---------------------------------------------------------- fixtures & fuzzers

const foo = #"666f6f"

const bar = #"626172"

const baz = #"62617a"

const fixture_bench =
  empty
    |> insert("aaa", "1")
    |> insert("bbb", "2")
    |> insert("ccc", "3")
    |> insert("ddd", "4")
    |> insert("eee", "5")
    |> insert("fff", "6")
    |> insert("ggg", "7")
    |> insert("hhh", "8")
    |> insert("iii", "9")
    |> insert("jjj", "10")
    |> insert("kkk", "11")

const fixture_delete_aaa =
  empty
    |> insert("bbb", "2")
    |> insert("ccc", "3")
    |> insert("ddd", "4")
    |> insert("eee", "5")
    |> insert("fff", "6")
    |> insert("ggg", "7")
    |> insert("hhh", "8")
    |> insert("iii", "9")
    |> insert("jjj", "10")
    |> insert("kkk", "11")

const fixture_delete_fff =
  empty
    |> insert("aaa", "1")
    |> insert("bbb", "2")
    |> insert("ccc", "3")
    |> insert("ddd", "4")
    |> insert("eee", "5")
    |> insert("ggg", "7")
    |> insert("hhh", "8")
    |> insert("iii", "9")
    |> insert("jjj", "10")
    |> insert("kkk", "11")

const fixture_delete_kkk =
  empty
    |> insert("aaa", "1")
    |> insert("bbb", "2")
    |> insert("ccc", "3")
    |> insert("ddd", "4")
    |> insert("eee", "5")
    |> insert("fff", "6")
    |> insert("ggg", "7")
    |> insert("hhh", "8")
    |> insert("iii", "9")
    |> insert("jjj", "10")

const fixture_1 =
  empty
    |> insert(foo, 42)
    |> insert(bar, 14)

const fixture_superset =
  empty
    |> insert("a", 10)
    |> insert("b", 42)

const fixture_contains_superset =
  empty
    |> insert("a", 1)
    |> insert("b", 2)
    |> insert("c", 3)
    |> insert("d", 4)
    |> insert("e", 5)
    |> insert("f", 6)
    |> insert("g", 7)
    |> insert("h", 8)
    |> insert("i", 9)
    |> insert("j", 10)

const fixture_contains_subset =
  empty
    |> insert("a", 1)

// --------------------------------------------------------------------- helpers

fn tautology(a: a) -> Bool {
  a == a
}

// -------------------------------------------------------- from_ascending_pairs

test from_ascending_pairs_bench() {
  let dict = from_ascending_pairs(
    [
      Pair("aaaa", 1), Pair("aaab", 9), Pair("aaba", 5), Pair("aabb", 13),
      Pair("abaa", 2), Pair("abab", 10), Pair("abba", 6), Pair("abbb", 14),
      Pair("baaa", 3), Pair("baab", 11), Pair("baba", 7), Pair("babb", 15),
      Pair("bbaa", 4), Pair("bbab", 12), Pair("bbba", 8), Pair("bbbb", 16),
    ],
  )

  size(dict) == 16
}

// ------------------------------------------------------------------ from_pairs

test from_pairs_1() {
  from_pairs([]) == empty
}

test from_pairs_2() {
  from_pairs([Pair(foo, 42), Pair(bar, 14)]) == from_pairs(
    [Pair(bar, 14), Pair(foo, 42)],
  )
}

test from_pairs_3() {
  from_pairs([Pair(foo, 42), Pair(bar, 14)]) == fixture_1
}

test from_pairs_4() {
  from_pairs([Pair(foo, 42), Pair(bar, 14), Pair(foo, 1337)]) == fixture_1
}

test from_pairs_bench() {
  let dict = from_pairs(
    [
      Pair("bbba", 8), Pair("bbab", 12), Pair("aabb", 13), Pair("aaab", 9),
      Pair("bbbb", 16), Pair("aaaa", 1), Pair("aaba", 5), Pair("abab", 10),
      Pair("baba", 7), Pair("baab", 11), Pair("abaa", 2), Pair("baaa", 3),
      Pair("bbaa", 4), Pair("babb", 15), Pair("abbb", 14), Pair("abba", 6),
    ],
  )

  size(dict) == 16
}

// ------------------------------------------------------------- expect_contains

test expect_contains_1() {
  expect_contains(fixture_superset, empty, int.compare)
}

test expect_contains_2() {
  expect_contains(fixture_superset, from_pairs([Pair("a", 1)]), int.compare)
}

test expect_contains_3() {
  expect_contains(
    fixture_superset,
    from_pairs([Pair("a", 1), Pair("b", 42)]),
    int.compare,
  )
}

test expect_contains_4() fail {
  expect_contains(fixture_superset, from_pairs([Pair("a", 14)]), int.compare)
}

test expect_contains_5() fail {
  expect_contains(
    fixture_superset,
    from_pairs([Pair("a", 1), Pair("c", 1)]),
    int.compare,
  )
}

test expect_contains_bench() {
  expect_contains(
    fixture_contains_superset,
    fixture_contains_subset,
    int.compare,
  )
  expect_contains(
    fixture_contains_superset,
    fixture_contains_superset,
    int.compare,
  )
}

// ----------------------------------------------------------------- expect_find

test expect_find_1() fail {
  expect_find(empty, foo) |> tautology
}

test expect_find_2() {
  expect_find(
    empty
      |> insert(foo, 14),
    14,
  ) == foo
}

test expect_find_3() fail {
  expect_find(
    empty
      |> insert(foo, 14),
    42,
  )
    |> tautology
}

test expect_find_4() {
  expect_find(
    empty
      |> insert(foo, 14)
      |> insert(bar, 42)
      |> insert(baz, 14),
    14,
  ) == baz
}

// ------------------------------------------------------------------ expect_get

test expect_get_1() fail {
  expect_get(empty, foo) |> tautology
}

test expect_get_2() {
  let m = empty
    |> insert(foo, "Aiken")
    |> insert(bar, "awesome")
  expect_get(m, key: foo) == "Aiken"
}

test expect_get_3() fail {
  let m = empty
    |> insert(foo, "Aiken")
    |> insert(bar, "awesome")
  expect_get(m, key: baz) |> tautology
}

test expect_get_4() fail {
  expect_get(fixture_bench, "bcd") |> tautology
}

test expect_get_5() fail {
  expect_get(fixture_bench, "lll") |> tautology
}

test expect_get_bench() {
  and {
    expect_get(fixture_bench, "aaa") == "1",
    expect_get(fixture_bench, "fff") == "6",
    expect_get(fixture_bench, "kkk") == "11",
  }
}

// -------------------------------------------------------------- expect_has_key

test expect_has_key_1() fail {
  expect_has_key(empty, foo)
}

test expect_has_key_2() {
  expect_has_key(
    empty
      |> insert(foo, 14),
    foo,
  )
}

test expect_has_key_3() fail {
  expect_has_key(
    empty
      |> insert(foo, 14),
    bar,
  )
}

test expect_has_key_4() {
  expect_has_key(
    empty
      |> insert(foo, 14)
      |> insert(bar, 42),
    bar,
  )
}

test expect_has_key_bench() {
  expect_has_key(fixture_bench, "aaa")
  expect_has_key(fixture_bench, "fff")
  expect_has_key(fixture_bench, "kkk")
}

// -------------------------------------------------------------------- contains

test contains_1() {
  contains(fixture_superset, empty, int.compare)
}

test contains_2() {
  contains(fixture_superset, from_pairs([Pair("a", 1)]), int.compare)
}

test contains_3() {
  contains(
    fixture_superset,
    from_pairs([Pair("a", 1), Pair("b", 42)]),
    int.compare,
  )
}

test contains_4() {
  !contains(fixture_superset, from_pairs([Pair("a", 14)]), int.compare)
}

test contains_5() {
  !contains(
    fixture_superset,
    from_pairs([Pair("a", 1), Pair("c", 1)]),
    int.compare,
  )
}

test contains_bench() {
  and {
    contains(fixture_contains_superset, fixture_contains_subset, int.compare),
    contains(fixture_contains_superset, fixture_contains_superset, int.compare),
  }
}

// ------------------------------------------------------------------------ find

test find_1() {
  find(empty, foo) == None
}

test find_2() {
  find(
    empty
      |> insert(foo, 14),
    14,
  ) == Some(foo)
}

test find_3() {
  find(
    empty
      |> insert(foo, 14),
    42,
  ) == None
}

test find_4() {
  find(
    empty
      |> insert(foo, 14)
      |> insert(bar, 42)
      |> insert(baz, 14),
    14,
  ) == Some(baz)
}

// ------------------------------------------------------------------------- get

test get_1() {
  get(empty, foo) == None
}

test get_2() {
  let m = empty
    |> insert(foo, "Aiken")
    |> insert(bar, "awesome")
  get(m, key: foo) == Some("Aiken")
}

test get_3() {
  let m = empty
    |> insert(foo, "Aiken")
    |> insert(bar, "awesome")
  get(m, key: baz) == None
}

test get_4() {
  get(fixture_bench, "bcd") == None
}

test get_5() {
  get(fixture_bench, "lll") == None
}

test get_bench() {
  and {
    get(fixture_bench, "aaa") == Some("1"),
    get(fixture_bench, "fff") == Some("6"),
    get(fixture_bench, "kkk") == Some("11"),
  }
}

// ----------------------------------------------------------------- get_or_else

test get_or_else_1() {
  get_or_else(empty, foo, fn() { 0 }) == 0
}

test get_or_else_2() {
  let m = empty
    |> insert(foo, "Aiken")
    |> insert(bar, "awesome")
  get_or_else(m, key: foo, or_else: fn() { "" }) == "Aiken"
}

test get_or_else_3() {
  let m = empty
    |> insert(foo, "Aiken")
    |> insert(bar, "awesome")
  get_or_else(m, key: baz, or_else: fn() { "missing?" }) == "missing?"
}

test get_or_else_4() {
  get_or_else(fixture_bench, "bcd", fn() { "0" }) == "0"
}

test get_or_else_5() {
  get_or_else(fixture_bench, "lll", fn() { "" }) == ""
}

test get_or_else_bench() {
  and {
    get_or_else(fixture_bench, "aaa", fn() { "" }) == "1",
    get_or_else(fixture_bench, "fff", fn() { "" }) == "6",
    get_or_else(fixture_bench, "kkk", fn() { "" }) == "11",
  }
}

// --------------------------------------------------------------------- has_key

test has_key_1() {
  !has_key(empty, foo)
}

test has_key_2() {
  has_key(
    empty
      |> insert(foo, 14),
    foo,
  )
}

test has_key_3() {
  !has_key(
    empty
      |> insert(foo, 14),
    bar,
  )
}

test has_key_4() {
  has_key(
    empty
      |> insert(foo, 14)
      |> insert(bar, 42),
    bar,
  )
}

test has_key_bench() {
  and {
    has_key(fixture_bench, "aaa"),
    has_key(fixture_bench, "fff"),
    has_key(fixture_bench, "kkk"),
  }
}

// -------------------------------------------------------------------- is_empty

test is_empty_1() {
  is_empty(empty)
}

// ------------------------------------------------------------------------ keys

test keys_1() {
  keys(empty) == []
}

test keys_2() {
  keys(
    empty
      |> insert(foo, 0)
      |> insert(bar, 0),
  ) == [bar, foo]
}

// ------------------------------------------------------------------------ size

test size_1() {
  size(empty) == 0
}

test size_2() {
  size(
    empty
      |> insert(foo, 14),
  ) == 1
}

test size_3() {
  size(
    empty
      |> insert(foo, 14)
      |> insert(bar, 42),
  ) == 2
}

// ---------------------------------------------------------------------- values

test values_1() {
  values(empty) == []
}

test values_2() {
  values(
    empty
      |> insert(foo, 3)
      |> insert(bar, 4),
  ) == [4, 3]
}

// ---------------------------------------------------------------------- delete

test delete_1() {
  delete(empty, foo) == empty
}

test delete_2() {
  let m = empty
    |> insert(foo, 14)
  delete(m, foo) == empty
}

test delete_3() {
  let m = empty
    |> insert(foo, 14)
  delete(m, bar) == m
}

test delete_4() {
  let m = empty
    |> insert(foo, 14)
    |> insert(bar, 14)
  !has_key(delete(m, foo), foo)
}

test delete_5() {
  let m = empty
    |> insert(foo, 14)
    |> insert(bar, 14)
  has_key(delete(m, bar), foo)
}

test delete_6() {
  delete(fixture_bench, "bcd") == fixture_bench
}

test delete_bench() {
  and {
    delete(fixture_bench, "aaa") == fixture_delete_aaa,
    delete(fixture_bench, "fff") == fixture_delete_fff,
    delete(fixture_bench, "kkk") == fixture_delete_kkk,
  }
}

// ------------------------------------------------------------- difference_with

test difference_with_1() {
  difference_with(empty, empty, strategy.sum(), strategy.keep()) == empty
}

test difference_with_2() {
  let left = empty
    |> insert(foo, 14)
    |> insert(bar, 42)

  difference_with(left, empty, strategy.sum(), strategy.keep()) == left
}

test difference_with_3() {
  let right = empty
    |> insert(foo, 14)
    |> insert(bar, 42)

  difference_with(empty, right, strategy.sum(), strategy.keep()) == right
}

test difference_with_4() {
  let left = empty
    |> insert("a", 100)
    |> insert("b", 200)

  let right = empty
    |> insert("a", 150)
    |> insert("c", 300)

  let result = difference_with(left, right, strategy.sum(), strategy.keep())

  result == from_pairs([Pair("a", 250), Pair("b", 200), Pair("c", 300)])
}

test difference_with_5() {
  let left = empty
    |> insert("a", 100)
    |> insert("b", 200)
    |> insert("c", 300)

  let right = empty
    |> insert("a", 100)
    |> insert("c", 300)

  let result = difference_with(
    left,
    right,
    strategy.difference_if_non_zero(),
    strategy.discard(),
  )

  result == from_pairs([Pair("b", 200)])
}

test difference_with_6() {
  let left = empty
    |> insert("a", 100)
    |> insert("b", 200)

  let right = empty
    |> insert("a", 150)
    |> insert("c", 300)

  let result = difference_with(
    left,
    right,
    strategy.difference(),
    strategy.negate(),
  )

  result == from_pairs([Pair("a", -50), Pair("b", 200), Pair("c", -300)])
}

// ---------------------------------------------------------------------- filter

test filter_1() {
  filter(empty, fn(_, _) { True }) == empty
}

test filter_2() {
  let expected = empty
    |> insert(foo, 42)
  filter(fixture_1, fn(_, v) { v > 14 }) == expected
}

test filter_3() {
  let expected = empty
    |> insert(bar, 14)
  filter(fixture_1, fn(k, _) { k == bar }) == expected
}

// ---------------------------------------------------------------------- insert

test insert_1() {
  let m1 = empty
    |> insert(foo, 42)
  let m2 = empty
    |> insert(foo, 14)
  insert(m1, foo, 14) == m2
}

test insert_2() {
  let m1 = empty
    |> insert(foo, 42)
  let m2 = empty
    |> insert(bar, 14)
  insert(m1, bar, 14) == insert(m2, foo, 42)
}

// ----------------------------------------------------------------- insert_with

test insert_with_1() {
  let result = empty
    |> insert_with(key: "foo", value: 1, with: strategy.sum())
    |> insert_with(key: "bar", value: 2, with: strategy.sum())
    |> to_pairs()

  result == [Pair("bar", 2), Pair("foo", 1)]
}

test insert_with_2() {
  let result = empty
    |> insert_with(key: "foo", value: 1, with: strategy.sum())
    |> insert_with(key: "bar", value: 2, with: strategy.sum())
    |> insert_with(key: "foo", value: 3, with: strategy.sum())
    |> to_pairs()

  result == [Pair("bar", 2), Pair("foo", 4)]
}

test insert_with_3() {
  let with = fn(k, a, _b, keep, discard) {
    if k == "foo" {
      keep(a)
    } else {
      discard()
    }
  }

  let result = empty
    |> insert_with(key: "foo", value: 1, with: with)
    |> insert_with(key: "bar", value: 2, with: with)
    |> insert_with(key: "foo", value: 3, with: with)
    |> insert_with(key: "bar", value: 4, with: with)
    |> to_pairs()

  result == [Pair("foo", 1)]
}

// ------------------------------------------------------------------------- map

test map_1() {
  let result = fixture_1
    |> map(with: fn(k, _) { k })
  get(result, foo) == Some(foo)
}

test map_2() {
  let result = fixture_1
    |> map(with: fn(_, v) { v + 1 })
  get(result, foo) == Some(43) && size(result) == size(fixture_1)
}

// ------------------------------------------------------------------------- pop

test pop_1() {
  pop(empty, foo) == (None, empty)
}

test pop_2() {
  let m = empty
    |> insert(foo, 14)
  pop(m, foo) == (Some(14), empty)
}

test pop_3() {
  let m = empty
    |> insert(foo, 14)
  pop(m, bar) == (None, m)
}

test pop_4() {
  let m = empty
    |> insert(foo, 14)
    |> insert(bar, 14)
  pop(m, foo) == (Some(14), empty |> insert(bar, 14))
}

test pop_5() {
  let m = empty
    |> insert("a", 1)
    |> insert("b", 2)
    |> insert("c", 3)
  pop(m, "a") == (Some(1), empty |> insert("b", 2) |> insert("c", 3))
}

test pop_6() {
  pop(fixture_bench, "bcd") == (None, fixture_bench)
}

test pop_bench() {
  and {
    pop(fixture_bench, "aaa") == (Some("1"), fixture_delete_aaa),
    pop(fixture_bench, "fff") == (Some("6"), fixture_delete_fff),
    pop(fixture_bench, "kkk") == (Some("11"), fixture_delete_kkk),
  }
}

// --------------------------------------------------------------- expect_delete

test expect_delete_1() fail {
  expect_delete(empty, foo) |> tautology
}

test expect_delete_2() {
  let m = empty |> insert(foo, 14)
  expect_delete(m, foo) == empty
}

test expect_delete_3() fail {
  let m = empty |> insert(foo, 14)
  expect_delete(m, bar) |> tautology
}

test expect_delete_4() {
  let m = empty
    |> insert(foo, 14)
    |> insert(bar, 14)
  !has_key(expect_delete(m, foo), foo)
}

test expect_delete_5() {
  let m = empty
    |> insert(foo, 14)
    |> insert(bar, 14)
  has_key(expect_delete(m, bar), foo)
}

test expect_delete_6() fail {
  expect_delete(fixture_bench, "bcd") |> tautology
}

test expect_delete_bench() {
  and {
    expect_delete(fixture_bench, "aaa") == fixture_delete_aaa,
    expect_delete(fixture_bench, "fff") == fixture_delete_fff,
    expect_delete(fixture_bench, "kkk") == fixture_delete_kkk,
  }
}

// ------------------------------------------------------------------ expect_pop

test expect_pop_1() fail {
  expect_pop(empty, foo) |> tautology
}

test expect_pop_2() {
  let m = empty
    |> insert(foo, 14)
  expect_pop(m, foo) == (14, empty)
}

test expect_pop_3() fail {
  let m = empty
    |> insert(foo, 14)
  expect_pop(m, bar) |> tautology
}

test expect_pop_4() {
  let m = empty
    |> insert(foo, 14)
    |> insert(bar, 14)
  expect_pop(m, foo) == (14, empty |> insert(bar, 14))
}

test expect_pop_5() {
  let m = empty
    |> insert("a", 1)
    |> insert("b", 2)
    |> insert("c", 3)
  expect_pop(m, "a") == (1, empty |> insert("b", 2) |> insert("c", 3))
}

test expect_pop_6() fail {
  expect_pop(fixture_bench, "bcd") |> tautology
}

test expect_pop_bench() {
  and {
    expect_pop(fixture_bench, "aaa") == ("1", fixture_delete_aaa),
    expect_pop(fixture_bench, "fff") == ("6", fixture_delete_fff),
    expect_pop(fixture_bench, "kkk") == ("11", fixture_delete_kkk),
  }
}

// ----------------------------------------------------------------- expect_tail

test expect_tail_1() fail {
  expect_tail(empty) |> tautology
}

test expect_tail_2() {
  expect_tail(singleton("a", 1)) == empty
}

test expect_tail_3() {
  expect_tail(from_pairs([Pair("a", 1), Pair("b", 2)])) == singleton("b", 2)
}

// ----------------------------------------------------------------------- union

test union_1() {
  union(fixture_1, empty) == fixture_1
}

test union_2() {
  union(empty, fixture_1) == fixture_1
}

test union_3() {
  let left = empty
    |> insert(foo, 14)
  let right = empty
    |> insert(bar, 42)
    |> insert(baz, 1337)
  union(left, right) == from_pairs(
    [Pair(foo, 14), Pair(baz, 1337), Pair(bar, 42)],
  )
}

test union_4() {
  let left = empty
    |> insert(foo, 14)
  let right = empty
    |> insert(bar, 42)
    |> insert(foo, 1337)
  union(left, right) == from_pairs([Pair(foo, 14), Pair(bar, 42)])
}

// ------------------------------------------------------------------ union_with

test union_with_1() {
  let left = empty
    |> insert(foo, 14)

  let right = empty
    |> insert(bar, 42)
    |> insert(foo, 1337)

  let result = union_with(left, right, with: strategy.sum())

  result == from_pairs([Pair(foo, 1351), Pair(bar, 42)])
}

// ---------------------------------------------------------------------- foldl2

test foldl2_size_and_merge() {
  let size, merge <- foldl2(
    fixture_bench,
    0,
    "",
    fn(k, v, size, merge, return) {
      return(
        size + 1,
        builtin.append_bytearray(merge, builtin.append_bytearray(k, v)),
      )
    },
  )

  and {
    size == 11,
    merge == "aaa1bbb2ccc3ddd4eee5fff6ggg7hhh8iii9jjj10kkk11",
  }
}

// ----------------------------------------------------------------------- foldr

test foldr_1() {
  foldr(empty, 14, fn(_, _, _) { 42 }) == 14
}

test foldr_2() {
  foldr(fixture_1, zero: 0, with: fn(_, v, total) { v + total }) == 56
}

// ---------------------------------------------------------------------- foldr2

test foldr2_size_and_merge() {
  let size, merge <- foldr2(
    fixture_bench,
    0,
    "",
    fn(k, v, size, merge, return) {
      return(
        size + 1,
        builtin.append_bytearray(merge, builtin.append_bytearray(k, v)),
      )
    },
  )

  and {
    size == 11,
    merge == "kkk11jjj10iii9hhh8ggg7fff6eee5ddd4ccc3bbb2aaa1",
  }
}

// ------------------------------------------------------------------------ fold

test fold_1() {
  foldl(empty, 14, fn(_, _, _) { 42 }) == 14
}

test fold_2() {
  foldl(fixture_1, zero: 0, with: fn(_, v, total) { v + total }) == 56
}

// --------------------------------------------------------------------- to_list

test to_list_1() {
  to_pairs(empty) == []
}

test to_list_2() {
  to_pairs(fixture_1) == [Pair(bar, 14), Pair(foo, 42)]
}

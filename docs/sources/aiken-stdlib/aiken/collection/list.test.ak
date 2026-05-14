use aiken/builtin
use aiken/collection/list.{
  all, any, at, concat, count, delete, difference, drop, drop_while, expect_any,
  expect_at, expect_delete, expect_drop, expect_find, expect_find_map,
  expect_has, expect_head, expect_index_of, expect_init, expect_last,
  expect_tail, expect_take, filter, filter_map, find, find_map, flat_map, foldl,
  foldl2, foldr, foldr2, for_each, has, head, index_of, indexed_foldr,
  indexed_map, init, is_empty, last, length, map, map2, map3, partition, push,
  range, reduce, repeat, reverse, slice, sort, span, tail, take, take_while,
  unique, unzip, zip,
}
use aiken/primitive/bytearray
use aiken/primitive/int

// ---------------------------------------------------------- fixtures & fuzzers

const fixture_bench = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

type Foo {
  Foo(Int, Int)
}

// --------------------------------------------------------------------- helpers

fn tautology(a: a) -> Bool {
  a == a
}

// ------------------------------------------------------------------------ push

test push_1() {
  push([], 0) == [0]
}

test push_2() {
  push([2, 3], 1) == [1, 2, 3]
}

// ----------------------------------------------------------------------- range

test range_1() {
  range(0, 3) == [0, 1, 2, 3]
}

test range_2() {
  range(-1, 1) == [-1, 0, 1]
}

// ---------------------------------------------------------------------- repeat

test repeat_1() {
  repeat(42, 0) == []
}

test repeat_2() {
  repeat(14, 3) == [14, 14, 14]
}

// ------------------------------------------------------------------------- all

test all_1() {
  all([1, 2, 3], fn(n) { n > 0 }) == True
}

test all_2() {
  all([1, 2, 3], fn(n) { n > 42 }) == False
}

test all_3() {
  all([], fn(n) { n == 42 }) == True
}

// ------------------------------------------------------------------------- any

test any_1() {
  any([1, 2, 3], fn(n) { n > 0 }) == True
}

test any_2() {
  any([1, 2, 3], fn(n) { n > 42 }) == False
}

test any_3() {
  any([], fn(n) { n == 42 }) == False
}

test any_bench() {
  and {
    any(fixture_bench, fn(n) { n == 0 }),
    any(fixture_bench, fn(n) { n == 5 }),
    any(fixture_bench, fn(n) { n == 10 }),
  }
}

// -------------------------------------------------------------------------- at

test at_1() {
  at([1, 2, 3], -1) == None
}

test at_2() {
  at([], 0) == None
}

test at_3() {
  at([1, 2, 3], 3) == None
}

test at_4() {
  at([1], 0) == Some(1)
}

test at_bench() {
  and {
    at(fixture_bench, 0) == Some(0),
    at(fixture_bench, 6) == Some(6),
    at(fixture_bench, 10) == Some(10),
  }
}

// ----------------------------------------------------------------------- count

test count_all() {
  count([1, 2, 3], fn(a) { a > 0 }) == 3
}

test count_empty() {
  count([], fn(a) { a > 2 }) == 0
}

test count_none() {
  count([1, 2, 3], fn(a) { a > 5 }) == 0
}

test count_some() {
  count([1, 2, 3], fn(a) { a >= 2 }) == 2
}

// ------------------------------------------------------------------------ find

test find_1() {
  find([1, 2, 3], fn(x) { x == 1 }) == Some(1)
}

test find_2() {
  find([1, 2, 3], fn(x) { x > 42 }) == None
}

test find_3() {
  find([], fn(_) { True }) == None
}

test find_4() {
  find([1, 2, 3], fn(x) { x >= 3 }) == Some(3)
}

test find_bench() {
  and {
    find(fixture_bench, fn(x) { x == 0 }) == Some(0),
    find(fixture_bench, fn(x) { x == 6 }) == Some(6),
    find(fixture_bench, fn(x) { x == 10 }) == Some(10),
  }
}

// -------------------------------------------------------------------- find_map

test find_map_1() {
  find_map(
    ["a", "bb", "ccc"],
    fn(x) {
      let len = bytearray.length(x)
      if len > 1 {
        Some(len)
      } else {
        None
      }
    },
  ) == Some(2)
}

test find_map_2() {
  find_map(
    [1, 2, 3],
    fn(x) {
      if x == 1 {
        Some(x - 1)
      } else {
        None
      }
    },
  ) == Some(0)
}

test find_map_3() {
  find_map(
    [1, 2, 3],
    fn(x) {
      if x > 42 {
        Some(x)
      } else {
        None
      }
    },
  ) == None
}

test find_map_4() {
  find_map([], fn(_) { Some(True) }) == None
}

// ------------------------------------------------------------------------- has

test has_1() {
  has([1, 2, 3], 1) == True
}

test has_2() {
  has([1, 2, 3], 14) == False
}

test has_3() {
  has([], 14) == False
}

test has_bench() {
  and {
    has(fixture_bench, 0),
    has(fixture_bench, 6),
    has(fixture_bench, 10),
  }
}

// ------------------------------------------------------------------------ head

test head_1() {
  head([1, 2, 3]) == Some(1)
}

test head_2() {
  head([]) == None
}

test head_bench() {
  head(fixture_bench) == Some(0)
}

// -------------------------------------------------------------------- is_empty

test is_empty_1() {
  is_empty([]) == True
}

test is_empty_2() {
  is_empty([1, 2, 3]) == False
}

// -------------------------------------------------------------------- index_of

test index_of_1() {
  index_of([1, 5, 2], 2) == Some(2)
}

test index_of_2() {
  index_of([1, 7, 3], 4) == None
}

test index_of_3() {
  index_of([1, 0, 9, 6], 6) == Some(3)
}

test index_of_4() {
  index_of([], 6) == None
}

test index_of_bench() {
  and {
    index_of(fixture_bench, 0) == Some(0),
    index_of(fixture_bench, 6) == Some(6),
    index_of(fixture_bench, 10) == Some(10),
  }
}

// ------------------------------------------------------------------------ last

test last_1() {
  last([]) == None
}

test last_2() {
  last([1]) == Some(1)
}

test last_bench() {
  last(fixture_bench) == Some(10)
}

// ---------------------------------------------------------------------- length

test length_1() {
  length([]) == 0
}

test length_2() {
  length([1, 2, 3]) == 3
}

// ------------------------------------------------------------------ expect_any

test expect_any_1() {
  expect_any([1, 2, 3], fn(n) { n > 0 })
}

test expect_any_2() fail {
  expect_any([1, 2, 3], fn(n) { n > 42 })
}

test expect_any_3() fail {
  expect_any([], fn(n) { n == 42 })
}

test expect_any_bench() {
  expect_any(fixture_bench, fn(n) { n == 0 })
  expect_any(fixture_bench, fn(n) { n == 5 })
  expect_any(fixture_bench, fn(n) { n == 10 })
}

// ------------------------------------------------------------------- expect_at

test expect_at_1() fail {
  let n = expect_at([1, 2, 3], -1)
  n == n
}

test expect_at_2() fail {
  let n = expect_at([], 0)
  n == n
}

test expect_at_3() fail {
  let n = expect_at([1, 2, 3], 3)
  n == n
}

test expect_at_4() {
  expect_at([1], 0) == 1
}

test expect_at_bench() {
  and {
    expect_at(fixture_bench, 0) == 0,
    expect_at(fixture_bench, 6) == 6,
    expect_at(fixture_bench, 10) == 10,
  }
}

// ----------------------------------------------------------------- expect_find

test expect_find_1() {
  expect_find([1, 2, 3], fn(x) { x == 1 }) == 1
}

test expect_find_2() fail {
  let n = expect_find([1, 2, 3], fn(x) { x > 42 })
  n == n
}

test expect_find_3() fail {
  let n = expect_find([], fn(_) { True })
  n == n
}

test expect_find_4() {
  expect_find([1, 2, 3], fn(x) { x >= 3 }) == 3
}

test expect_find_bench() {
  and {
    expect_find(fixture_bench, fn(x) { x == 0 }) == 0,
    expect_find(fixture_bench, fn(x) { x == 6 }) == 6,
    expect_find(fixture_bench, fn(x) { x == 10 }) == 10,
  }
}

// ------------------------------------------------------------- expect_find_map

test expect_find_map_1() {
  expect_find_map(
    ["a", "bb", "ccc"],
    fn(x, keep, discard) {
      let len = bytearray.length(x)
      if len > 1 {
        keep(len)
      } else {
        discard()
      }
    },
  ) == 2
}

test expect_find_map_2() {
  expect_find_map(
    [1, 2, 3],
    fn(x, keep, discard) {
      if x == 1 {
        keep(x - 1)
      } else {
        discard()
      }
    },
  ) == 0
}

test expect_find_map_3() fail {
  expect_find_map(
    [1, 2, 3],
    fn(x, keep, discard) {
      if x > 42 {
        keep(x)
      } else {
        discard()
      }
    },
  )
    |> tautology
}

test expect_find_map_4() fail {
  expect_find_map([], fn(_, keep, _) { keep(14) }) |> tautology
}

// ------------------------------------------------------------------ expect_has

test expect_has_1() {
  expect_has([1, 2, 3], 1)
}

test expect_has_2() fail {
  expect_has([1, 2, 3], 14)
}

test expect_has_3() fail {
  expect_has([], 14)
}

test expect_has_bench() {
  expect_has(fixture_bench, 0)
  expect_has(fixture_bench, 6)
  expect_has(fixture_bench, 10)
}

// ----------------------------------------------------------------- expect_head

test expect_head_bench() {
  expect_head(fixture_bench) == 0
}

// ------------------------------------------------------------- expect_index_of

test expect_index_of_1() {
  expect_index_of([1, 5, 2], 2) == 2
}

test expect_index_of_2() fail {
  let i = expect_index_of([1, 7, 3], 4)
  i == i
}

test expect_index_of_3() {
  expect_index_of([1, 0, 9, 6], 6) == 3
}

test expect_index_of_4() fail {
  let i = expect_index_of([], 6)
  i == i
}

test expect_index_of_bench() {
  and {
    expect_index_of(fixture_bench, 0) == 0,
    expect_index_of(fixture_bench, 6) == 6,
    expect_index_of(fixture_bench, 10) == 10,
  }
}

// ----------------------------------------------------------------- expect_last

test expect_last_1() fail {
  expect_last([]) |> tautology
}

test expect_last_2() {
  expect_last([1]) == 1
}

test expect_last_bench() {
  expect_last(fixture_bench) == 10
}

// ---------------------------------------------------------------------- delete

test delete_1() {
  delete([], 42) == []
}

test delete_2() {
  delete([1, 2, 3, 1], 1) == [2, 3, 1]
}

test delete_3() {
  delete([1, 2, 3], 14) == [1, 2, 3]
}

test delete_4() {
  delete([2], 2) == []
}

test delete_bench() {
  and {
    delete(fixture_bench, 0) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    delete(fixture_bench, 6) == [0, 1, 2, 3, 4, 5, 7, 8, 9, 10],
    delete(fixture_bench, 10) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  }
}

// ------------------------------------------------------------------------ drop

test drop_0() {
  drop([], 0) == []
}

test drop_1() {
  drop([], 42) == []
}

test drop_2() {
  drop([1, 2, 3], 2) == [3]
}

test drop_3() {
  drop([1, 2, 3, 4, 5], 3) == [4, 5]
}

test drop_4() {
  drop([1, 2, 3], -1) == [1, 2, 3]
}

test drop_bench() {
  and {
    drop(fixture_bench, 0) == fixture_bench,
    drop(fixture_bench, 6) == [6, 7, 8, 9, 10],
    drop(fixture_bench, 11) == [],
  }
}

// ------------------------------------------------------------------ drop_while

test drop_while_1() {
  drop_while([], fn(x) { x > 2 }) == []
}

test drop_while_2() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  drop_while(xs, fn(x) { x > 5 }) == [5, 4, 3, 2, 1]
}

test drop_while_3() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  drop_while(xs, fn(x) { x == 42 }) == xs
}

test drop_while_4() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  drop_while(xs, fn(x) { x < 42 }) == []
}

// ---------------------------------------------------------------------- filter

test filter_1() {
  filter([], fn(x) { x > 0 }) == []
}

test filter_2() {
  let xs = [1, 2, 3, 4, 5, 6]
  filter(xs, fn(x) { builtin.mod_integer(x, 2) == 0 }) == [2, 4, 6]
}

test filter_3() {
  let filter_foldr = fn(xs, f) {
    foldr(
      xs,
      [],
      fn(x, ys) {
        if f(x) {
          [x, ..ys]
        } else {
          ys
        }
      },
    )
  }

  let is_odd = fn(n) { builtin.mod_integer(n, 2) != 0 }

  filter_foldr([1, 2, 3], is_odd) == filter([1, 2, 3], is_odd)
}

// ------------------------------------------------------------------ filter_map

test filter_map_1() {
  filter_map([], fn(_) { Some(42) }) == []
}

test filter_map_2() {
  filter_map(
    [1, 2, 3, 4, 5, 6],
    fn(x) {
      if builtin.mod_integer(x, 2) != 0 {
        Some(3 * x)
      } else {
        None
      }
    },
  ) == [3, 9, 15]
}

// ------------------------------------------------------------------------ init

test init_1() {
  init([]) == None
}

test init_2() {
  init([1]) == Some([])
}

test init_3() {
  init([1, 2, 3, 4]) == Some([1, 2, 3])
}

// ------------------------------------------------------------------- partition

test partition_1() {
  partition([], fn(x) { x > 2 }) == ([], [])
}

test partition_2() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  partition(xs, fn(x) { x > 5 }) == ([10, 9, 8, 7, 6], [5, 4, 3, 2, 1])
}

test partition_3() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  partition(xs, fn(x) { x == 42 }) == ([], xs)
}

test partition_4() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  partition(xs, fn(x) { x < 42 }) == (xs, [])
}

test partition_5() {
  partition([1, 2, 3, 4], fn(x) { x % 2 == 0 }) == ([2, 4], [1, 3])
}

// ----------------------------------------------------------------------- slice

test slice_1() {
  slice([1, 2, 3], 0, 2) == [1, 2, 3]
}

test slice_2() {
  slice([1, 2, 3, 4, 5, 6], from: 2, to: 4) == [3, 4, 5]
}

test slice_3() {
  slice([1, 2, 3, 4, 5, 6], from: -2, to: -1) == [5, 6]
}

test slice_4() {
  slice([1, 2, 3, 4, 5, 6], from: 1, to: -1) == [2, 3, 4, 5, 6]
}

test slice_5() {
  slice([1, 2, 3, 4, 5, 6], from: -4, to: -3) == [3, 4]
}

test slice_6() {
  slice([1, 2, 3, 4, 5, 6], from: -2, to: 1) == []
}

// ------------------------------------------------------------------------ span

test span_1() {
  span([], 2) == ([], [])
}

test span_2() {
  span([1, 2, 3], 2) == ([1, 2], [3])
}

test span_3() {
  span([1, 2, 3], -1) == ([], [1, 2, 3])
}

test span_4() {
  span([1, 2, 3], 42) == ([1, 2, 3], [])
}

test span_5() {
  span([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 10) == (
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  )
}

// ------------------------------------------------------------------------ tail

test tail_1() {
  tail([1, 2, 3]) == Some([2, 3])
}

test tail_2() {
  tail([]) == None
}

// ------------------------------------------------------------------------ take

test take_1() {
  take([], 42) == []
}

test take_2() {
  take([1, 2, 3], 2) == [1, 2]
}

test take_3() {
  take([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 10) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
}

test take_4() {
  take([1, 2, 3, 4], 3) == [1, 2, 3]
}

test take_5() {
  take([1, 2, 3, 4], -2) == []
}

test take_bench() {
  and {
    take(fixture_bench, 0) == [],
    take(fixture_bench, 5) == [0, 1, 2, 3, 4],
    take(fixture_bench, 11) == fixture_bench,
  }
}

// ------------------------------------------------------------------ take_while

test take_while_1() {
  take_while([], fn(x) { x > 2 }) == []
}

test take_while_2() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  take_while(xs, fn(x) { x > 5 }) == [10, 9, 8, 7, 6]
}

test take_while_3() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  take_while(xs, fn(x) { x == 42 }) == []
}

test take_while_4() {
  let xs = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  take_while(xs, fn(x) { x < 42 }) == xs
}

// ---------------------------------------------------------------------- unique

test unique_1() {
  unique([]) == []
}

test unique_2() {
  let xs = [1, 2, 3, 1, 1, 3, 4, 1, 2, 3, 2, 4, 5, 6, 7, 8, 9, 10, 9]
  unique(xs) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
}

// --------------------------------------------------------------- expect_delete

test expect_delete_1() fail {
  expect_delete([], 42) |> tautology
}

test expect_delete_2() {
  expect_delete([1, 2, 3, 1], 1) == [2, 3, 1]
}

test expect_delete_3() fail {
  expect_delete([1, 2, 3], 14) |> tautology
}

test expect_delete_4() {
  expect_delete([2], 2) == []
}

test expect_delete_bench() {
  and {
    expect_delete(fixture_bench, 0) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    expect_delete(fixture_bench, 6) == [0, 1, 2, 3, 4, 5, 7, 8, 9, 10],
    expect_delete(fixture_bench, 10) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  }
}

// ----------------------------------------------------------------- expect_drop

test expect_drop_0() {
  expect_drop([], 0) == []
}

test expect_drop_1() fail {
  expect_drop([], 42) |> tautology
}

test expect_drop_2() {
  expect_drop([1, 2, 3], 2) == [3]
}

test expect_drop_3() {
  expect_drop([1, 2, 3, 4, 5], 3) == [4, 5]
}

test expect_drop_4() {
  expect_drop([1, 2, 3], -1) == [1, 2, 3]
}

test expect_drop_bench() {
  and {
    expect_drop(fixture_bench, 0) == fixture_bench,
    expect_drop(fixture_bench, 6) == [6, 7, 8, 9, 10],
    expect_drop(fixture_bench, 11) == [],
  }
}

// ----------------------------------------------------------------- expect_init

test expect_init_1() fail {
  expect_init([]) |> tautology
}

test expect_init_2() {
  expect_init([1]) == []
}

test expect_init_3() {
  expect_init([1, 2, 3, 4]) == [1, 2, 3]
}

// ----------------------------------------------------------------- expect_tail

test expect_tail_1() {
  expect_tail([1, 2, 3]) == [2, 3]
}

test expect_tail_2() fail {
  expect_tail([]) |> tautology
}

// ----------------------------------------------------------------- expect_take

test expect_take_1() fail {
  expect_take([], 42) |> tautology
}

test expect_take_2() {
  expect_take([1, 2, 3], 2) == [1, 2]
}

test expect_take_3() {
  expect_take([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 10) == [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
  ]
}

test expect_take_4() {
  expect_take([1, 2, 3, 4], 3) == [1, 2, 3]
}

test expect_take_5() {
  expect_take([1, 2, 3, 4], -2) == []
}

test expect_take_bench() {
  and {
    expect_take(fixture_bench, 0) == [],
    expect_take(fixture_bench, 5) == [0, 1, 2, 3, 4],
    expect_take(fixture_bench, 11) == fixture_bench,
  }
}

// -------------------------------------------------------------------- flat_map

test flat_map_1() {
  flat_map([], fn(a) { [a] }) == []
}

test flat_map_2() {
  flat_map([1, 2, 3], fn(a) { [a, a] }) == [1, 1, 2, 2, 3, 3]
}

// -------------------------------------------------------------------- for_each

test for_each_1() {
  for_each(
    [@"hello", @"world"],
    do: fn(lbl) {
      trace lbl
      Void
    },
  )
}

// ----------------------------------------------------------------- indexed_map

test indexed_map_1() {
  indexed_map([], fn(i, _n) { i }) == []
}

test indexed_map_2() {
  indexed_map(
    [4, 8, 13, 2],
    fn(i, n) {
      if n == 8 {
        n
      } else {
        i
      }
    },
  ) == [0, 8, 2, 3]
}

// ------------------------------------------------------------------------- map

test map_1() {
  map([], fn(n) { n + 1 }) == []
}

test map_2() {
  map([1, 2, 3, 4], fn(n) { n + 1 }) == [2, 3, 4, 5]
}

// ------------------------------------------------------------------------ map2

test map2_1() {
  map2([], [1, 2, 3], fn(a, b) { a + b }) == []
}

test map2_2() {
  map2([1, 2, 3], [1, 2], fn(a, b) { a + b }) == [2, 4]
}

test map2_3() {
  map2([42], [1, 2, 3], fn(_a, b) { Some(b) }) == [Some(1)]
}

// ------------------------------------------------------------------------ map3

test map3_1() {
  map3([], [], [1, 2, 3], fn(a, b, c) { a + b + c }) == []
}

test map3_2() {
  map3([1, 2, 3], [1, 2], [1, 2, 3], fn(a, b, c) { a + b + c }) == [3, 6]
}

// --------------------------------------------------------------------- reverse

test reverse_1() {
  reverse([]) == []
}

test reverse_2() {
  reverse([1, 2, 3]) == [3, 2, 1]
}

// ------------------------------------------------------------------------ sort

test sort_1() {
  let xs = [6, 7, 5, 4, 1, 3, 9, 8, 0, 2]
  sort(xs, int.compare) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
}

test sort_2() {
  let xs = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  sort(xs, int.compare) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
}

test sort_3() {
  let xs = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  sort(xs, int.compare) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
}

test sort_4() {
  sort([], int.compare) == []
}

// ----------------------------------------------------------------------- unzip

test unzip_1() {
  unzip([]) == ([], [])
}

test unzip_2() {
  unzip([(1, "a"), (2, "b")]) == ([1, 2], ["a", "b"])
}

// ---------------------------------------------------------------------- concat

test concat_1() {
  concat([1, 2, 3], [4, 5, 6]) == [1, 2, 3, 4, 5, 6]
}

test concat_2() {
  concat([1, 2, 3], []) == [1, 2, 3]
}

test concat_3() {
  concat([], [1, 2, 3]) == [1, 2, 3]
}

// ------------------------------------------------------------------ difference

test difference_1() {
  difference(["h", "e", "l", "l", "o"], ["l", "e", "l"]) == ["h", "o"]
}

test difference_2() {
  difference([1, 2, 3, 4, 5], [1, 1, 2]) == [3, 4, 5]
}

test difference_3() {
  difference([1, 2, 3], []) == [1, 2, 3]
}

test difference_4() {
  difference([], [1, 2, 3]) == []
}

// ------------------------------------------------------------------------- zip

test zip_1() {
  zip([], [1, 2, 3]) == []
}

test zip_2() {
  zip([1, 2, 3], []) == []
}

test zip_3() {
  zip([1, 2], ["a", "b", "c"]) == [(1, "a"), (2, "b")]
}

// ----------------------------------------------------------------------- foldl

test foldl_1() {
  foldl([], 0, fn(_, _) { 1 }) == 0
}

test foldl_2() {
  foldl([1, 2, 3, 4, 5], 0, fn(n, total) { n + total }) == 15
}

test foldl_3() {
  foldl([1, 2, 3, 4], [], fn(x, xs) { [x, ..xs] }) == [4, 3, 2, 1]
}

// ---------------------------------------------------------------------- foldl2

test foldl2_classic() {
  let (len, sum) = foldl(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    (0, 0),
    fn(n, (len, sum)) { (len + 1, sum + n) },
  )

  and {
    len == 10,
    sum == 55,
  }
}

test foldl2_foo() {
  let Foo(len, sum) = foldl(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    Foo(0, 0),
    fn(n, Foo(len, sum)) { Foo(len + 1, sum + n) },
  )

  and {
    len == 10,
    sum == 55,
  }
}

test foldl2_optimized() {
  let len, sum <- foldl2(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    0,
    0,
    fn(n, len, sum, return) { return(len + 1, sum + n) },
  )

  and {
    len == 10,
    sum == 55,
  }
}

test foldl2_pair() {
  let Pair(len, sum) = foldl(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    Pair(0, 0),
    fn(n, Pair(len, sum)) { Pair(len + 1, sum + n) },
  )

  and {
    len == 10,
    sum == 55,
  }
}

// ----------------------------------------------------------------------- foldr

test foldr_1() {
  foldr([1, 2, 3, 4, 5], 0, fn(n, total) { n + total }) == 15
}

test foldr_2() {
  foldr(
    [1, 2, 3],
    "",
    fn(n, _str) {
      if builtin.mod_integer(n, 2) == 0 {
        "foo"
      } else {
        "bar"
      }
    },
  ) == "bar"
}

test foldr_3() {
  foldr([1, 2, 3, 4], [], fn(x, xs) { [x, ..xs] }) == [1, 2, 3, 4]
}

// ---------------------------------------------------------------------- foldr2

test foldr2_optimized() {
  let len, sum <- foldr2(
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    0,
    0,
    fn(n, len, sum, return) { return(len + 1, sum + n) },
  )

  and {
    len == 10,
    sum == 55,
  }
}

// --------------------------------------------------------------- indexed_foldr

test indexed_foldr_1() {
  indexed_foldr([], 0, fn(i, x, xs) { i + x + xs }) == 0
}

test indexed_foldr_2() {
  let letters = ["a", "b", "c"]
  indexed_foldr(letters, [], fn(i, x, xs) { [(i, x), ..xs] }) == [
    (0, "a"), (1, "b"), (2, "c"),
  ]
}

// ---------------------------------------------------------------------- reduce

test reduce_1() {
  reduce([], 0, fn(n, total) { n + total }) == 0
}

test reduce_2() {
  reduce([1, 2, 3], 0, fn(n, total) { n + total }) == 6
}

test reduce_3() {
  reduce([True, False, True], False, fn(left, right) { left || right }) == True
}

test reduce_4() {
  reduce(
    [#[1], #[2], #[3]],
    #[9],
    fn(left, right) { bytearray.concat(left, right) },
  ) == #[9, 1, 2, 3]
}

use aiken/fuzz.{and_then, both, constant, either}
use aiken/interval.{
  Finite, Interval, IntervalBound, IntervalBoundType, NegativeInfinity,
  PositiveInfinity, after, before, between, contains, empty, entirely_after,
  entirely_before, entirely_between, everything, hull, includes, intersection,
  is_empty, is_entirely_after, is_entirely_before,
}

// ---------------------------------------------------------- fixtures & fuzzers

const bound_type: Fuzzer<IntervalBoundType> =
  fuzz.either(
    fuzz.map(fuzz.int(), IntervalBoundType.Finite),
    either(
      constant(IntervalBoundType.NegativeInfinity),
      constant(IntervalBoundType.PositiveInfinity),
    ),
  )

const bound: Fuzzer<IntervalBound> =
  fuzz.map2(bound_type, fuzz.bool(), IntervalBound)

const interval: Fuzzer<Interval> = {
    let roll <- and_then(fuzz.byte())
    if roll < 220 {
      fuzz.map2(bound, bound, Interval)
        |> fuzz.such_that(fn(itv) { !interval.is_empty(itv) })
    } else {
      fuzz.map2(bound, bound, Interval)
    }
  }

const fixture_intersection_contains: Fuzzer<(Interval, Interval, Int)> = {
    let a <- and_then(interval)
    let b <- and_then(interval)
    let pt <- fuzz.map(fuzz.int())
    (a, b, pt)
  }

// --------------------------------------------------------------------- helpers

fn inclusive_lower_bound(
  IntervalBound { bound_type, is_inclusive }: IntervalBound,
) -> IntervalBoundType {
  if is_inclusive {
    bound_type
  } else {
    when bound_type is {
      Finite(x) -> Finite(x + 1)
      NegativeInfinity | PositiveInfinity -> bound_type
    }
  }
}

fn inclusive_upper_bound(
  IntervalBound { bound_type, is_inclusive }: IntervalBound,
) -> IntervalBoundType {
  if is_inclusive {
    bound_type
  } else {
    when bound_type is {
      Finite(x) -> Finite(x - 1)
      NegativeInfinity | PositiveInfinity -> bound_type
    }
  }
}

// -------------------------------------------------------------------- contains

test contains_1() {
  let iv = everything
  contains(iv, 14)
}

test contains_10() {
  let iv = between(0, 42)
  contains(iv, 42)
}

test contains_11() {
  let iv = entirely_between(0, 42)
  !contains(iv, 0)
}

test contains_12() {
  let iv = empty
  !contains(iv, 14)
}

test contains_2() {
  let iv = entirely_before(15)
  contains(iv, 14)
}

test contains_3() {
  let iv = before(14)
  contains(iv, 14)
}

test contains_4() {
  let iv = entirely_before(14)
  !contains(iv, 14)
}

test contains_5() {
  let iv = entirely_after(13)
  contains(iv, 14)
}

test contains_6() {
  let iv = after(14)
  contains(iv, 14)
}

test contains_7() {
  let iv = entirely_after(14)
  !contains(iv, 14)
}

test contains_8() {
  let iv = between(42, 1337)
  !contains(iv, 14)
}

test contains_9() {
  let iv = between(0, 42)
  contains(iv, 14)
}

// ----------------------------------------------------------- is_entirely_after

test is_entirely_after_1() {
  is_entirely_after(after(10), 5)
}

test is_entirely_after_10() {
  is_entirely_after(
    Interval {
      lower_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: False,
      },
    },
    1,
  )
}

test is_entirely_after_2() {
  !is_entirely_after(after(10), 10)
}

test is_entirely_after_3() {
  !is_entirely_after(after(10), 15)
}

test is_entirely_after_4() {
  !is_entirely_after(between(10, 20), 30)
}

test is_entirely_after_5() {
  is_entirely_after(between(10, 20), 5)
}

test is_entirely_after_6() {
  is_entirely_after(entirely_after(10), 10)
}

test is_entirely_after_7() {
  !is_entirely_after(before(10), 5)
}

test is_entirely_after_8() {
  !is_entirely_after(before(10), 15)
}

test is_entirely_after_9() {
  !is_entirely_after(entirely_before(10), 5)
}

// ---------------------------------------------------------- is_entirely_before

test is_entirely_before_1() {
  is_entirely_before(before(10), 15)
}

test is_entirely_before_10() {
  is_entirely_before(
    Interval {
      lower_bound: IntervalBound {
        bound_type: NegativeInfinity,
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: NegativeInfinity,
        is_inclusive: False,
      },
    },
    1,
  )
}

test is_entirely_before_2() {
  !is_entirely_before(before(10), 10)
}

test is_entirely_before_3() {
  !is_entirely_before(before(10), 5)
}

test is_entirely_before_4() {
  is_entirely_before(between(10, 20), 30)
}

test is_entirely_before_5() {
  !is_entirely_before(between(10, 20), 5)
}

test is_entirely_before_6() {
  is_entirely_before(entirely_before(10), 10)
}

test is_entirely_before_7() {
  !is_entirely_before(after(10), 15)
}

test is_entirely_before_8() {
  !is_entirely_before(after(10), 5)
}

test is_entirely_before_9() {
  !is_entirely_before(entirely_after(10), 5)
}

// ------------------------------------------------------------------------ hull

test hull_1() {
  let iv1 = between(0, 10)
  let iv2 = between(2, 14)
  hull(iv1, iv2) == between(0, 14)
}

test hull_2() {
  let iv1 = between(5, 10)
  let iv2 = before(0)
  hull(iv1, iv2) == before(10)
}

test hull_3() {
  let iv1 = entirely_after(0)
  let iv2 = between(10, 42)
  hull(iv1, iv2) == entirely_after(0)
}

// -------------------------------------------------------------------- includes

test includes_1() {
  between(-5, 5) |> includes(between(-5, 5))
}

test includes_2() {
  between(-5, 5) |> includes(between(0, 2))
}

test includes_3() {
  between(-5, 5) |> includes(entirely_between(-5, 5))
}

test includes_4() {
  !(entirely_between(-5, 5) |> includes(between(-5, 5)))
}

test includes_5() {
  and {
    after(0) |> includes(after(1)),
    entirely_after(0) |> includes(entirely_after(1)),
  }
}

test includes_6() {
  and {
    after(0) |> includes(after(1)),
    entirely_after(0) |> includes(after(1)),
  }
}

test includes_7() {
  and {
    before(0) |> includes(before(-1)),
    entirely_before(0) |> includes(before(-1)),
  }
}

test includes_8() {
  and {
    !(before(-1) |> includes(before(0))),
    !(entirely_before(-1) |> includes(before(0))),
  }
}

test prop_includes_empty(itv via interval) {
  let is_empty = interval.is_empty(itv)
  fuzz.label_when(is_empty, @"empty", @"non-empty")
  is_empty || interval.includes(itv, interval.empty)
}

test prop_includes_intersection((a, b) via both(interval, interval)) {
  let intersection = interval.intersection(a, b)
  and {
    interval.includes(a, intersection),
    interval.includes(b, intersection),
  }
}

test prop_includes_intersection_reg() {
  let a = Interval {
    lower_bound: IntervalBound {
      bound_type: interval.Finite(41),
      is_inclusive: True,
    },
    upper_bound: IntervalBound {
      bound_type: interval.PositiveInfinity,
      is_inclusive: True,
    },
  }
  let b = Interval {
    lower_bound: IntervalBound {
      bound_type: interval.Finite(41),
      is_inclusive: False,
    },
    upper_bound: IntervalBound {
      bound_type: interval.Finite(42),
      is_inclusive: True,
    },
  }

  let intersection = interval.intersection(a, b)

  (intersection == b)? || interval.is_empty(intersection)?
}

test prop_includes_itself(itv via interval) {
  interval.is_empty(itv) || interval.includes(itv, itv)
}

// ---------------------------------------------------------------- intersection

test intersection_1() {
  let iv1 = between(0, 10)
  let iv2 = between(2, 14)
  intersection(iv1, iv2) == between(2, 10)
}

test intersection_2() {
  let iv1 = between(0, 1)
  let iv2 = between(1, 2)
  intersection(iv1, iv2) == between(1, 1)
}

test intersection_3() {
  let iv1 = between(0, 1)
  let iv2 = entirely_between(1, 2)
  intersection(iv1, iv2)
    |> is_empty
}

test intersection_4() {
  let iv1 = entirely_between(0, 1)
  let iv2 = entirely_between(1, 2)
  intersection(iv1, iv2)
    |> is_empty
}

test intersection_5() {
  let iv1 = between(0, 10)
  let iv2 = before(4)
  intersection(iv1, iv2) == between(0, 4)
}

test intersection_6() {
  let iv1 = entirely_before(10)
  let iv2 = entirely_after(0)
  intersection(iv1, iv2) == entirely_between(0, 10)
}

test prop_intersection_contains((a, b, pt) via fixture_intersection_contains) {
  let intersection = interval.intersection(a, b)
  if interval.contains(intersection, pt) {
    fuzz.label(@"contains")
    and {
      interval.contains(a, pt),
      interval.contains(b, pt),
    }
  } else {
    fuzz.label(@"not contains")
    True
  }
}

test prop_intersection_empty_is_empty(itv via interval) {
  interval.intersection(itv, interval.empty) |> interval.is_empty
}

test prop_intersection_everything_is_identity(itv via interval) {
  interval.intersection(itv, interval.everything) == itv
}

test prop_intersection_idempotent((a, b) via both(interval, interval)) {
  let intersection = interval.intersection(a, b)
  interval.intersection(intersection, b) == intersection
}

test prop_intersection_symmetric((a, b) via both(interval, interval)) {
  let it1 = interval.intersection(a, b)
  let it2 = interval.intersection(b, a)
  and {
    inclusive_lower_bound(it1.lower_bound) == inclusive_lower_bound(
      it2.lower_bound,
    ),
    inclusive_upper_bound(it1.upper_bound) == inclusive_upper_bound(
      it2.upper_bound,
    ),
  }
}

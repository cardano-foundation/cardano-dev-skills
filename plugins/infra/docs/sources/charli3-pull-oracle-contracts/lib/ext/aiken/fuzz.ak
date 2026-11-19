use aiken/builtin
use aiken/collection/list
use aiken/fuzz

// TODO Use in tests
pub fn list_normal(
  median: Int,
  variance: Int,
  sample_size: Int,
) -> Fuzzer<List<Int>> {
  let accuracy = 12

  fuzz.list_between(
    int_normal(median, variance, accuracy),
    sample_size,
    sample_size,
  )
}

/// This function converts uniform integer distribution to normal
pub fn int_normal(median: Int, variance: Int, accuracy: Int) -> Fuzzer<Int> {
  fuzz.list_between(
    fuzz.int_between(median - variance, median + variance),
    accuracy,
    accuracy,
  )
    |> fuzz.map(
        fn(uniform) { list.reduce(uniform, 0, builtin.add_integer) / accuracy },
      )
}

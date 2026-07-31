use aiken/builtin
use bls/utils

test utils_foldl2_sum_success() {
  let result =
    utils.foldl2([1, 2, 3], [4, 5, 6], 0, fn(a, b, acc) { acc + a + b })
  result == 21
}

test utils_foldl2_concat_strings_success() {
  let result =
    utils.foldl2(
      [@"a", @"b"],
      [@"x", @"y"],
      @"",
      fn(a, b, acc) { builtin.append_string(acc, builtin.append_string(a, b)) },
    )
  result == @"axby"
}

test utils_foldl2_empty_lists_success() {
  let result = utils.foldl2([], [], 100, fn(_a, _b, acc) { acc + 1 })
  result == 100
}

/// ------------------------
/// Tests for trace_message
/// ------------------------
test utils_trace_message_basic_success() {
  let result = utils.trace_message(@"Value", 42)
  result == @"Value: 42"
}

test utils_trace_message_empty_string_success() {
  let result = utils.trace_message(@"", "")
  result == @": h''"
}

test utils_trace_message_boolean_success() {
  let true = utils.trace_message(@"", True)
  let false = utils.trace_message(@"", False)
  and {
    true == @": 122([])",
    false == @": 121([])",
  }
}

/// ------------------------
/// Tests for all_unique
/// ------------------------
test utils_all_unique_false_fails() {
  let xs = [#"01", #"02", #"03", #"01", #"04"]
  !utils.all_unique(xs)
}

test utils_all_unique_true_success() {
  let xs = [#"04", #"02", #"03", #"01"]
  utils.all_unique(xs)
}

test utils_all_unique_empty_success() {
  let xs: List<ByteArray> = []
  utils.all_unique(xs)
}

test utils_all_unique_single_success() {
  let xs = [#"ff"]
  utils.all_unique(xs)
}

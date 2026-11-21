/// A combination of `zip` and `indexed_map`
/// https://github.com/aiken-lang/stdlib/blob/0f88f8ffce60b91ae3e4b3a3f40bab153e494760/lib/aiken/collection/list.ak#L1168
/// https://github.com/aiken-lang/stdlib/blob/0f88f8ffce60b91ae3e4b3a3f40bab153e494760/lib/aiken/collection/list.ak#L896
pub fn indexed_zip_with(
  self: List<a>,
  bs: List<b>,
  with: fn(Int, a, b) -> result,
) -> List<result> {
  do_indexed_zip_with(0, self, bs, with)
}

fn do_indexed_zip_with(
  n: Int,
  self: List<a>,
  bs: List<b>,
  with: fn(Int, a, b) -> result,
) -> List<result> {
  when self is {
    [] -> []
    [x, ..xs] ->
      when bs is {
        [] -> []
        [y, ..ys] -> [with(n, x, y), ..do_indexed_zip_with(n + 1, xs, ys, with)]
      }
  }
}

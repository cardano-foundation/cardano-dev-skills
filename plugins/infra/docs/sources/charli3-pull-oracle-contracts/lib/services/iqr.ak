//// To ensure a more reliable outlier detection using IQR, it's advisable to have a sample size of at least 20-30 data points,
//// i.e. five points per quartile.
//// Naturally, minimum number of points is four, to have at least one element in each quartile,
//// but beware that IQR could become useless for sample sizes of 4-10.

use aiken/collection/list
use aiken/math/rational.{Rational}
use ext/aiken/math/rational.{Percent, per_cent} as ext

/// See interquartile range (IQR) and Tukey fences methods for outlier detection.
/// Explanation for cases when it can return None:
/// The IQR method is built on the assumption that there is a meaningful spread between
/// the 25th and 75th percentiles. When you find that the 0.25‐quantile equals the 0.75‐quantile
/// it indicates that a large number of your data points are concentrated at the center.
/// This situation leads to zero interquartile range, and the thresholds for detecting outliers collapse,
/// meaning even minor deviations from the center would be flagged as outliers.
pub fn iqr_fence(
  sorted_input: List<Int>,
  input_length: Int,
  iqr_fence_multiplier: Percent,
) -> Option<(Int, Int)> {
  expect Some(multiplier) = rational.new(iqr_fence_multiplier, per_cent)
  expect Some(point_25) = rational.new(25, per_cent)
  expect Some(point_75) = rational.new(75, per_cent)
  let q25 = quantile(sorted_input, input_length, point_25)
  let q75 = quantile(sorted_input, input_length, point_75)
  let iqr = rational.sub(q75, q25)

  if rational.round_even(iqr) == 0 {
    trace @"T34"
    None
  } else {
    let fence = rational.mul(multiplier, iqr)
    let fence_lower = rational.sub(q25, fence)
    let fence_upper = rational.add(q75, fence)

    Some((rational.round_even(fence_lower), rational.round_even(fence_upper)))
  }
}

/// Returns weighted (by proximity) average of the two elements closest to the quantile index q * (n - 1)
pub fn quantile(
  // The input list sorted
  xs: List<Int>,
  // Length of the list
  n: Int,
  // Desired quantile (between 0 and 100%)
  q: Rational,
) -> Rational {
  let n_sub_one = rational.from_int(n - 1)
  let quantile_index = rational.mul(q, n_sub_one)

  // Integral part of q * (n - 1)
  let j = rational.floor(quantile_index)
  // Fractional part of q * (n - 1)
  let g = rational.sub(quantile_index, rational.from_int(j))

  // Get the j-th element of xs (0-indexed)
  expect [x_j, ..ys] = list.drop(xs, j)
  // Get the (j+1)-th element of xs
  expect [x_j_1, ..] = ys

  // Linearly interpolate between x_j
  // and x_j_1, using g as the mixing factor.
  let fst =
    rational.sub(rational.from_int(1), g)
      |> rational.mul(rational.from_int(x_j))
  let snd = rational.mul(g, rational.from_int(x_j_1))
  rational.add(fst, snd)
}

use aiken/builtin
use aiken/collection/list
use aiken/collection/pairs
use aiken/math/rational
use config
use core/datum.{FeedVkh, NodeFeed, OracleFeed}
use ext/aiken/math/rational.{Percent, Permille, per_mille} as ext
use services/iqr.{iqr_fence, quantile}

pub fn median(
  node_feeds_sorted: List<NodeFeed>,
  node_feeds_count: Int,
) -> OracleFeed {
  when node_feeds_sorted is {
    [] -> fail @"E4"
    [x] -> x
    xs -> {
      expect Some(midpoint) = rational.new(1, 2)
      quantile(xs, node_feeds_count, midpoint) |> rational.round_even
    }
  }
}

/// Returns list of nodes which are not outliers using interquartile range algorithm (IQR).
/// Uses divergency from the middle point (median) if IQR is not applicable:
/// 1. Judging by the nodes feeds count:
///   * required minimum for IQR at least not to throw error is one point per quartile, i.e. 4 points;
///   * a reasonable minimum of IQR applicability is 3 points per quartile, i.e. 12 points;
///   * a threshold from which IQR starts to work really good is 5 points per quartile, i.e. 20 points.
/// 2. In case iqr equals zero we cannot use it, see the docstring for iqr_fence function.
pub fn consensus_by_iqr_and_divergency(
  middle_point: NodeFeed,
  node_feeds: Pairs<FeedVkh, NodeFeed>,
  node_feeds_count: Int,
  iqr_fence_multiplier: Percent,
  median_divergency_factor: Permille,
) -> List<FeedVkh> {
  if node_feeds_count == 1 {
    pairs.keys(node_feeds)
  } else if node_feeds_count < config.iqr_applicability_threshold {
    filter_with_divergency_fence(
      middle_point,
      node_feeds,
      median_divergency_factor,
    )
  } else {
    let iqr =
      pairs.values(node_feeds)
        |> iqr_fence(node_feeds_count, iqr_fence_multiplier)
    when iqr is {
      None ->
        filter_with_divergency_fence(
          middle_point,
          node_feeds,
          median_divergency_factor,
        )
      Some((fence_lower, fence_upper)) ->
        filter_outliers(node_feeds, fence_lower, fence_upper)
    }
  }
}

pub fn filter_with_divergency_fence(
  middle_point: NodeFeed,
  node_feeds: Pairs<FeedVkh, NodeFeed>,
  median_divergency_factor: Permille,
) -> List<FeedVkh> {
  expect Some(factor) = rational.new(median_divergency_factor, per_mille)
  let midpoint = rational.from_int(middle_point)

  let fence = rational.mul(factor, midpoint)
  let fence_lower = rational.sub(midpoint, fence) |> rational.round_even
  let fence_upper = rational.add(midpoint, fence) |> rational.round_even

  filter_outliers(node_feeds, fence_lower, fence_upper)
}

pub fn filter_outliers(
  node_feeds: Pairs<FeedVkh, NodeFeed>,
  lower_limit: Int,
  upper_limit: Int,
) {
  list.filter_map(
    node_feeds,
    fn(p) {
      let id = builtin.fst_pair(p)
      let feed = builtin.snd_pair(p)

      if feed < lower_limit || feed > upper_limit {
        None
      } else {
        Some(id)
      }
    },
  )
}

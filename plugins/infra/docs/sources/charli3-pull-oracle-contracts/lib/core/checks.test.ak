use aiken/crypto.{ScriptHash}
use cardano/address
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction as tx
use core/checks.{
  check_node_received_reward, check_nodes_update, check_reward_distribution,
  get_length_and_check_strict_order,
}
use core/datum.{
  AggregateMessage, FeeConfig, FeedVkh, Nodes, OracleSettingsDatum,
  RewardAccount, RewardAccountDatum, RewardPrices,
}
use core/multisig.{check_nodes_multisig}
use core/redeemer.{AddNodes, DelNodes}
use ext/cardano/value.{Asset}

fn mk_settings(nodes: Nodes, sigs: Int) -> OracleSettingsDatum {
  OracleSettingsDatum {
    nodes,
    required_node_signatures_count: sigs,
    fee_info: FeeConfig {
      rate_nft: None,
      reward_prices: RewardPrices { node_fee: 0, platform_fee: 0 },
    },
    aggregation_liveness_period: 0,
    time_uncertainty_aggregation: 0,
    time_uncertainty_platform: 1,
    iqr_fence_multiplier: 150,
    median_divergency_factor: 10,
    utxo_size_safety_buffer: 2,
    pause_period_started_at: None,
  }
}

const node_a: FeedVkh = #"01"

const node_b: FeedVkh = #"02"

const node_c: FeedVkh = #"03"

const node_d: FeedVkh = #"04"

const reward_account_script: ScriptHash = #"ff"

const reward_account_address = address.from_script(reward_account_script)

const fee_policy_id: PolicyId = #"feed"

const fee_asset_name: AssetName = #"c3"

const fee_token_asset = Asset { policy_id: fee_policy_id, name: fee_asset_name }

// ManageSettings :: AddNodes
test add_nodes_succeeds() {
  let before = mk_settings([node_a, node_b], 1)
  let after = mk_settings([node_a, node_b, node_c], 1)

  check_nodes_update(before, after, AddNodes)
}

test add_nodes_fails_when_unsorted() fail {
  let before = mk_settings([node_a, node_c], 1)
  let after = mk_settings([node_c, node_a], 1)

  check_nodes_update(before, after, AddNodes)
}

test add_nodes_fails_when_zero_signatories() fail {
  let before = mk_settings([node_a, node_b], 1)
  let after = mk_settings([node_a, node_b, node_c], 0)

  check_nodes_update(before, after, AddNodes)
}

// ManageSettings :: DelNodes
test del_nodes_succeeds() {
  let before = mk_settings([node_a, node_b], 1)
  let after = mk_settings([node_a], 1)

  check_nodes_update(before, after, DelNodes)
}

test del_nodes_requires_removal() fail {
  let before = mk_settings([node_a, node_b], 1)
  let after = mk_settings([node_a, node_b], 1)

  check_nodes_update(before, after, DelNodes)
}

// RewardRedeemer :: NodeCollect
test node_collect_succeeds_with_fee_token() {
  let utxo_size_safety_buffer = 5_000_000
  let in_distribution =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_a, 5), Pair(node_b, 3)],
      last_update_time: 42,
    }
  let in_value =
    assets.merge(
      assets.from_lovelace(utxo_size_safety_buffer),
      assets.from_asset(fee_policy_id, fee_asset_name, 8),
    )
  let out_distribution =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_b, 3)],
      last_update_time: 42,
    }
  let out_value =
    assets.merge(
      assets.from_lovelace(utxo_size_safety_buffer),
      assets.from_asset(fee_policy_id, fee_asset_name, 3),
    )
  let reward_account_output =
    tx.Output {
      address: reward_account_address,
      value: out_value,
      datum: tx.InlineDatum(RewardAccount(out_distribution)),
      reference_script: None,
    }

  check_node_received_reward(
    Some(fee_token_asset),
    node_a,
    in_distribution,
    in_value,
    reward_account_output,
    utxo_size_safety_buffer,
  )
}

test node_collect_fails_when_lovelace_decreases() fail {
  let utxo_size_safety_buffer = 5_000_000
  let in_distribution =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_a, 5), Pair(node_b, 3)],
      last_update_time: 73,
    }
  let in_value =
    assets.merge(
      assets.from_lovelace(utxo_size_safety_buffer),
      assets.from_asset(fee_policy_id, fee_asset_name, 8),
    )
  let out_distribution =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_b, 3)],
      last_update_time: 73,
    }
  let out_value =
    assets.merge(
      assets.from_lovelace(utxo_size_safety_buffer - 1),
      assets.from_asset(fee_policy_id, fee_asset_name, 3),
    )
  let reward_account_output =
    tx.Output {
      address: reward_account_address,
      value: out_value,
      datum: tx.InlineDatum(RewardAccount(out_distribution)),
      reference_script: None,
    }

  check_node_received_reward(
    Some(fee_token_asset),
    node_a,
    in_distribution,
    in_value,
    reward_account_output,
    utxo_size_safety_buffer,
  )
}

test node_collect_succeeds_with_ada_rewards() {
  let utxo_size_safety_buffer = 5_000_000
  let in_distribution =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_a, 2_000_000), Pair(node_b, 500_000)],
      last_update_time: 99,
    }
  let in_value = assets.from_lovelace(7_500_000)
  let out_distribution =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_b, 500_000)],
      last_update_time: 99,
    }
  let out_value = assets.from_lovelace(5_500_000)
  let reward_account_output =
    tx.Output {
      address: reward_account_address,
      value: out_value,
      datum: tx.InlineDatum(RewardAccount(out_distribution)),
      reference_script: None,
    }

  check_node_received_reward(
    None,
    node_a,
    in_distribution,
    in_value,
    reward_account_output,
    utxo_size_safety_buffer,
  )
}

// Aggregate
test reward_distribution_accepts_sorted_output() {
  let node_reward_price = 5
  let node_feeds_sorted_by_feed: AggregateMessage =
    [Pair(node_a, 100), Pair(node_b, 100)]
  let in_distribution = [Pair(node_a, 10), Pair(node_b, 10)]
  let out_distribution = [Pair(node_a, 15), Pair(node_b, 15)]
  let nodes = [node_a, node_b]

  check_reward_distribution(
    node_feeds_sorted_by_feed,
    2,
    100,
    node_reward_price,
    in_distribution,
    out_distribution,
    nodes,
    150,
    300,
  )
}

// check_reward_distribution rejects unsorted out_distributions.
// During the fold, consume_allowed_feed expects to find each out_distribution VKH
// in the remaining allowed_nodes list (which is sorted by VKH in ascending order).
// If out_distribution is not sorted by VKH, consume_allowed_feed will fail because
// it cannot find a VKH that comes before an already-consumed smaller VKH.
// This ensures out_distribution must be sorted by VKH in ascending order.

test reward_distribution_rejects_unsorted_output() fail {
  let node_reward_price = 5
  let node_feeds_sorted_by_feed: AggregateMessage =
    [Pair(node_a, 100), Pair(node_b, 100), Pair(node_c, 100)]
  let in_distribution = [Pair(node_a, 10), Pair(node_b, 10), Pair(node_c, 10)]
  let out_distribution = [Pair(node_b, 15), Pair(node_a, 15), Pair(node_c, 15)]
  let nodes = [node_a, node_b, node_c]

  check_reward_distribution(
    node_feeds_sorted_by_feed,
    2,
    100,
    node_reward_price,
    in_distribution,
    out_distribution,
    nodes,
    150,
    300,
  )
}

test check_nodes_multisig_accepts_required_signers() {
  let message: AggregateMessage = [Pair(node_a, 100), Pair(node_b, 105)]
  let signers = [node_a, node_b]
  let allowed_nodes = [node_a, node_b, node_c]

  check_nodes_multisig(message, 2, signers, allowed_nodes, 2)
}

test check_nodes_multisig_rejects_unknown_node() fail {
  let message: AggregateMessage = [Pair(node_a, 100), Pair(node_c, 105)]
  let signers = [node_a, node_c]
  let allowed_nodes = [node_a, node_b]

  check_nodes_multisig(message, 2, signers, allowed_nodes, 2)
}

test reward_distribution_filters_outliers_with_iqr() {
  let node_reward_price = 5
  let node_feeds_sorted_by_feed: AggregateMessage =
    [
      Pair(node_a, 100), Pair(node_b, 101), Pair(node_c, 102),
      Pair(node_d, 1000),
    ]
  let in_distribution =
    [Pair(node_a, 10), Pair(node_b, 10), Pair(node_c, 10), Pair(node_d, 10)]
  let out_distribution =
    [Pair(node_a, 15), Pair(node_b, 15), Pair(node_c, 15), Pair(node_d, 10)]
  let nodes = [node_a, node_b, node_c, node_d]

  check_reward_distribution(
    node_feeds_sorted_by_feed,
    4,
    101,
    node_reward_price,
    in_distribution,
    out_distribution,
    nodes,
    150,
    300,
  )
}

test get_length_and_check_strict_order_succeds() {
  let inst_sorted = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
  expect 12 == get_length_and_check_strict_order(inst_sorted)
}

test get_length_and_check_strict_order_fails() fail {
  let inst_sorted = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 11]
  expect 12 == get_length_and_check_strict_order(inst_sorted)
}

// Test with 30 nodes - comprehensive reward distribution test
test reward_distribution_with_30_nodes() fail {
  // Define all 30 node VKHs
  let node_0: FeedVkh =
    #"5848520dfa6b26145066e09643f874596234f4cb618d2a2018758625"
  let node_1: FeedVkh =
    #"c197b921e0c8758e1ba13a3f5ce58bbef5f861de0ca6a9caaf31cd2c"
  let node_2: FeedVkh =
    #"f4e957d6f07d49c6d10e697c11c9d0440a0b765d5d01ab81846e66c7"
  let node_3: FeedVkh =
    #"71769484c979288cad81c7d9ac1a1913a8d412b7c09d4dd31859009e"
  let node_4: FeedVkh =
    #"bc579fd1e2311a0074d5b5f818ca5af64d96c1c314d4ae70f6730ce8"
  let node_5: FeedVkh =
    #"a4b1879a8e38140fb8963b5105ba1c35ec50701fcae9b0733debe9f9"
  let node_6: FeedVkh =
    #"c694c8402c8dfbf4b5649889ae37321007574f80cf46d6a05945cfd2"
  let node_7: FeedVkh =
    #"44fdab95b86f3af8d9b3596fac1eb1f276937224b8680c3050f53477"
  let node_8: FeedVkh =
    #"8dc1c0c011294d9eb3e55e1cf1695bad55e5ce91864879ddc464afd3"
  let node_9: FeedVkh =
    #"07d177613d046b235a74e5190aaa607f305a631d4de7bd5388340607"
  let node_10: FeedVkh =
    #"def21973cda45428dea421d1fb645e60447975b27d6dd70461701b2e"
  let node_11: FeedVkh =
    #"c88cffa0544c1c43424e3cf5fdc49b81d80a4732ad50b9c73b3ed1fe"
  let node_12: FeedVkh =
    #"4b4f4146e22a8b29eca600ed69acfe7797002cb9622af2ef9646cbec"
  let node_13: FeedVkh =
    #"39ddac71d0da8225c46f8c374d3b5edcd340220b84a0ad85bbeab67c"
  let node_14: FeedVkh =
    #"d0a6843b61d05acc3f41e6d25824729f049858afa56cfdb57d2accd1"
  let node_15: FeedVkh =
    #"5b76918be7c3b1b523dfb588b614fd2a38dd3554f85975c75eff2492"
  let node_16: FeedVkh =
    #"783cb9d7188732edf33df3903730b39bd67c8cc7aac47930829448cd"
  let node_17: FeedVkh =
    #"4af356c34add3eabadae93c68ecc6c8e27bfa118e67627faa002ef9b"
  let node_18: FeedVkh =
    #"f843f119468eba5832b853f0d79733c8f38a72e4f82de2f3e6403e8f"
  let node_19: FeedVkh =
    #"d1b550f53e32bbe67062ea3fbffbdd6e94ddd7ec408b9d71e3c870c4"
  let node_20: FeedVkh =
    #"03535de740ed5f678c33256432c872f53c468e84813f5eb204c19f60"
  let node_21: FeedVkh =
    #"ee5da5f21b3713023e7cc0fc31c4ccc6d308514b12e6bb554191225f"
  let node_22: FeedVkh =
    #"fd85c01cac08f860697ef228e5b5e5ac2720f675b59adbc2a3ea8948"
  let node_23: FeedVkh =
    #"7c72c2bc5c613d7957c2c0c2edf305a5ddd2ef4aac2591cd6d538d8b"
  let node_24: FeedVkh =
    #"5acd32fa4d3f6b7052a44757c7c088c85254e899e2e35848f604e2dc"
  let node_25: FeedVkh =
    #"7cb6baef7f9afc198c2660a112aef1b7738ce6608ca8404d7b1ae1ad"
  let node_26: FeedVkh =
    #"71120bfab9c4462954daf5c8155b02fb335e318dc4dcb8bfd0470b00"
  let node_27: FeedVkh =
    #"e2a69d10fd0b7f01ee0381a652a58096bb437d9180e2033ea8fa2eb1"
  let node_28: FeedVkh =
    #"cae4335791bd4520b63d423557a9134fbd39492095ff456fb0990a5f"
  let node_29: FeedVkh =
    #"70955e68b2f733dffff93376b4ea768766fb86b374fad56fc362a076"

  // Node feeds sorted by feed value (sorted by NodeFeed for AggregateMessage)
  // Feeds: 100, 100, 102, 105, 106, 106, 107, 107, 107, 109, 110, 111, 111,
  //        112, 112, 112, 112, 112, 113, 113, 114, 115, 115, 116, 117, 117, 117, 118, 119, 119
  let node_feeds_sorted_by_feed: AggregateMessage =
    [
      Pair(node_8, 100), Pair(node_12, 100), Pair(node_1, 102),
      Pair(node_19, 105), Pair(node_16, 106), Pair(node_22, 106),
      Pair(node_14, 107), Pair(node_21, 107), Pair(node_26, 107),
      Pair(node_4, 109), Pair(node_9, 110), Pair(node_15, 111),
      Pair(node_29, 111), Pair(node_5, 112), Pair(node_7, 112),
      Pair(node_11, 112), Pair(node_13, 112), Pair(node_17, 112),
      Pair(node_0, 113), Pair(node_25, 113), Pair(node_27, 114),
      Pair(node_10, 115), Pair(node_20, 115), Pair(node_23, 116),
      Pair(node_3, 117), Pair(node_24, 117), Pair(node_28, 117),
      Pair(node_2, 118), Pair(node_6, 119), Pair(node_18, 119),
    ]

  // Nodes list (sorted by VKH in ascending order)
  let nodes =
    [
      node_20, node_9, node_13, node_7, node_17, node_12, node_0, node_24,
      node_15, node_26, node_3, node_29, node_23, node_25, node_16, node_6,
      node_8, node_5, node_4, node_11, node_28, node_1, node_14, node_19,
      node_10, node_27, node_21, node_18, node_2, node_22,
    ]

  // Create in_distribution with base rewards for all nodes
  let in_distribution =
    [
      Pair(node_20, 10), Pair(node_9, 10), Pair(node_13, 10), Pair(node_7, 10),
      Pair(node_17, 10), Pair(node_12, 10), Pair(node_0, 10), Pair(node_24, 10),
      Pair(node_15, 10), Pair(node_26, 10), Pair(node_3, 10), Pair(node_29, 10),
      Pair(node_23, 10), Pair(node_25, 10), Pair(node_16, 10), Pair(node_6, 10),
      Pair(node_8, 10), Pair(node_5, 10), Pair(node_4, 10), Pair(node_11, 10),
      Pair(node_28, 10), Pair(node_1, 10), Pair(node_14, 10), Pair(node_19, 10),
      Pair(node_10, 10), Pair(node_27, 10), Pair(node_21, 10), Pair(node_18, 10),
      Pair(node_2, 10), Pair(node_22, 10),
    ]

  // Create out_distribution with rewards (5 added) for nodes within consensus
  // Using median=112, with IQR fence multiplier 150%, most nodes should be rewarded
  let node_reward_price = 5
  let out_distribution =
    [
      Pair(node_20, 15), Pair(node_9, 15), Pair(node_13, 15), Pair(node_7, 15),
      Pair(node_17, 15), Pair(node_12, 15), Pair(node_0, 15), Pair(node_24, 15),
      Pair(node_15, 15), Pair(node_26, 15), Pair(node_3, 15), Pair(node_29, 15),
      Pair(node_23, 15), Pair(node_25, 15), Pair(node_16, 15), Pair(node_6, 15),
      Pair(node_8, 15), Pair(node_5, 15), Pair(node_4, 15), Pair(node_11, 15),
      Pair(node_28, 15), Pair(node_1, 15), Pair(node_14, 15), Pair(node_19, 15),
      Pair(node_10, 15), Pair(node_27, 15), Pair(node_21, 15), Pair(node_18, 15),
      Pair(node_2, 15), Pair(node_22, 15),
    ]

  let median = 112
  let iqr_fence_multiplier = 150
  let median_divergency_factor = 200

  check_reward_distribution(
    node_feeds_sorted_by_feed,
    30,
    median,
    node_reward_price,
    in_distribution,
    out_distribution,
    nodes,
    iqr_fence_multiplier,
    median_divergency_factor,
  )
}

// Test with 30 nodes - CORRECTLY ORDERED VERSION
// This test demonstrates the proper ordering requirements:
//
// ORDERING REQUIREMENTS:
// 1. node_feeds_sorted_by_feed (oracle message / AggregateMessage):
//    - MUST be sorted by NodeFeed (feed value) in ascending order
//    - VKH order within same feed value does NOT matter (check_nodes_multisig handles unsorted VKHs)
//    - This ordering is validated by validate_message_and_count_nodes
//
// 2. allowed_nodes:
//    - MUST be sorted by VKH (FeedVkh) in ascending order
//    - This is enforced by check_nodes_update when adding/deleting nodes
//    - check_nodes_multisig uses consume_allowed which searches the entire list (VKH order independent)
//
// 3. in_distribution:
//    - MUST be sorted by VKH (FeedVkh) in ascending order
//    - Used by check_reward_distribution with consume_allowed_feed
//
// 4. out_distribution:
//    - MUST be sorted by VKH (FeedVkh) in ascending order
//    - check_reward_distribution enforces this via consume_allowed_feed
//    - If unsorted, consume_allowed_feed will fail (see reward_distribution_rejects_unsorted_output test)
//
// NOTE: In this test, VKHs are also sorted within each feed group for clarity,
// but this is NOT required for check_nodes_multisig to work correctly.
test reward_distribution_with_30_nodes_properly_sorted() {
  // Define all 30 node VKHs (same as before)
  let node_0: FeedVkh =
    #"5848520dfa6b26145066e09643f874596234f4cb618d2a2018758625"
  let node_1: FeedVkh =
    #"c197b921e0c8758e1ba13a3f5ce58bbef5f861de0ca6a9caaf31cd2c"
  let node_2: FeedVkh =
    #"f4e957d6f07d49c6d10e697c11c9d0440a0b765d5d01ab81846e66c7"
  let node_3: FeedVkh =
    #"71769484c979288cad81c7d9ac1a1913a8d412b7c09d4dd31859009e"
  let node_4: FeedVkh =
    #"bc579fd1e2311a0074d5b5f818ca5af64d96c1c314d4ae70f6730ce8"
  let node_5: FeedVkh =
    #"a4b1879a8e38140fb8963b5105ba1c35ec50701fcae9b0733debe9f9"
  let node_6: FeedVkh =
    #"c694c8402c8dfbf4b5649889ae37321007574f80cf46d6a05945cfd2"
  let node_7: FeedVkh =
    #"44fdab95b86f3af8d9b3596fac1eb1f276937224b8680c3050f53477"
  let node_8: FeedVkh =
    #"8dc1c0c011294d9eb3e55e1cf1695bad55e5ce91864879ddc464afd3"
  let node_9: FeedVkh =
    #"07d177613d046b235a74e5190aaa607f305a631d4de7bd5388340607"
  let node_10: FeedVkh =
    #"def21973cda45428dea421d1fb645e60447975b27d6dd70461701b2e"
  let node_11: FeedVkh =
    #"c88cffa0544c1c43424e3cf5fdc49b81d80a4732ad50b9c73b3ed1fe"
  let node_12: FeedVkh =
    #"4b4f4146e22a8b29eca600ed69acfe7797002cb9622af2ef9646cbec"
  let node_13: FeedVkh =
    #"39ddac71d0da8225c46f8c374d3b5edcd340220b84a0ad85bbeab67c"
  let node_14: FeedVkh =
    #"d0a6843b61d05acc3f41e6d25824729f049858afa56cfdb57d2accd1"
  let node_15: FeedVkh =
    #"5b76918be7c3b1b523dfb588b614fd2a38dd3554f85975c75eff2492"
  let node_16: FeedVkh =
    #"783cb9d7188732edf33df3903730b39bd67c8cc7aac47930829448cd"
  let node_17: FeedVkh =
    #"4af356c34add3eabadae93c68ecc6c8e27bfa118e67627faa002ef9b"
  let node_18: FeedVkh =
    #"f843f119468eba5832b853f0d79733c8f38a72e4f82de2f3e6403e8f"
  let node_19: FeedVkh =
    #"d1b550f53e32bbe67062ea3fbffbdd6e94ddd7ec408b9d71e3c870c4"
  let node_20: FeedVkh =
    #"03535de740ed5f678c33256432c872f53c468e84813f5eb204c19f60"
  let node_21: FeedVkh =
    #"ee5da5f21b3713023e7cc0fc31c4ccc6d308514b12e6bb554191225f"
  let node_22: FeedVkh =
    #"fd85c01cac08f860697ef228e5b5e5ac2720f675b59adbc2a3ea8948"
  let node_23: FeedVkh =
    #"7c72c2bc5c613d7957c2c0c2edf305a5ddd2ef4aac2591cd6d538d8b"
  let node_24: FeedVkh =
    #"5acd32fa4d3f6b7052a44757c7c088c85254e899e2e35848f604e2dc"
  let node_25: FeedVkh =
    #"7cb6baef7f9afc198c2660a112aef1b7738ce6608ca8404d7b1ae1ad"
  let node_26: FeedVkh =
    #"71120bfab9c4462954daf5c8155b02fb335e318dc4dcb8bfd0470b00"
  let node_27: FeedVkh =
    #"e2a69d10fd0b7f01ee0381a652a58096bb437d9180e2033ea8fa2eb1"
  let node_28: FeedVkh =
    #"cae4335791bd4520b63d423557a9134fbd39492095ff456fb0990a5f"
  let node_29: FeedVkh =
    #"70955e68b2f733dffff93376b4ea768766fb86b374fad56fc362a076"

  // Node feeds sorted ONLY by FEED VALUE (ascending order)
  // VKHs are also sorted within each feed group in this example for clarity,
  // but check_nodes_multisig does NOT require VKHs to be sorted within feed groups.
  // Feeds: 100, 100, 102, 105, 106, 106, 107, 107, 107, 109, 110, 111, 111,
  //        112, 112, 112, 112, 112, 113, 113, 114, 115, 115, 116, 117, 117, 117, 118, 119, 119
  let node_feeds_sorted_by_feed: AggregateMessage =
    [
      Pair(node_12, 100), Pair(node_8, 100), Pair(node_1, 102),
      Pair(node_19, 105), Pair(node_16, 106), Pair(node_22, 106),
      Pair(node_26, 107), Pair(node_14, 107), Pair(node_21, 107),
      Pair(node_4, 109), Pair(node_9, 110), Pair(node_15, 111),
      Pair(node_29, 111), Pair(node_13, 112), Pair(node_7, 112),
      Pair(node_17, 112), Pair(node_5, 112), Pair(node_11, 112),
      Pair(node_0, 113), Pair(node_25, 113), Pair(node_27, 114),
      Pair(node_20, 115), Pair(node_10, 115), Pair(node_23, 116),
      Pair(node_24, 117), Pair(node_3, 117), Pair(node_28, 117),
      Pair(node_2, 118), Pair(node_6, 119), Pair(node_18, 119),
    ]

  // allowed_nodes: MUST be sorted by VKH in ascending order
  // This is enforced by check_nodes_update via get_length_and_check_feed_vkh_order
  let nodes =
    [
      node_20, node_9, node_13, node_7, node_17, node_12, node_0, node_24,
      node_15, node_29, node_26, node_3, node_16, node_23, node_25, node_8,
      node_5, node_4, node_1, node_6, node_11, node_28, node_14, node_19,
      node_10, node_27, node_21, node_2, node_18, node_22,
    ]

  // in_distribution: MUST be sorted by VKH in ascending order
  // Used by check_reward_distribution
  let in_distribution =
    [
      Pair(node_20, 10), Pair(node_9, 10), Pair(node_13, 10), Pair(node_7, 10),
      Pair(node_17, 10), Pair(node_12, 10), Pair(node_0, 10), Pair(node_24, 10),
      Pair(node_15, 10), Pair(node_29, 10), Pair(node_26, 10), Pair(node_3, 10),
      Pair(node_16, 10), Pair(node_23, 10), Pair(node_25, 10), Pair(node_8, 10),
      Pair(node_5, 10), Pair(node_4, 10), Pair(node_1, 10), Pair(node_6, 10),
      Pair(node_11, 10), Pair(node_28, 10), Pair(node_14, 10), Pair(node_19, 10),
      Pair(node_10, 10), Pair(node_27, 10), Pair(node_21, 10), Pair(node_2, 10),
      Pair(node_18, 10), Pair(node_22, 10),
    ]

  // out_distribution: MUST be sorted by VKH in ascending order
  // check_reward_distribution enforces this via consume_allowed_feed
  // With median_divergency_factor=200 (20%), median=112:
  // Lower fence: 112 * (1 - 0.20) = 89.6 -> 90
  // Upper fence: 112 * (1 + 0.20) = 134.4 -> 134
  // All nodes (100-119) are within range, so all get rewarded
  let node_reward_price = 5
  let out_distribution =
    [
      Pair(node_20, 15), Pair(node_9, 15), Pair(node_13, 15), Pair(node_7, 15),
      Pair(node_17, 15), Pair(node_12, 15), Pair(node_0, 15), Pair(node_24, 15),
      Pair(node_15, 15), Pair(node_29, 15), Pair(node_26, 15), Pair(node_3, 15),
      Pair(node_16, 15), Pair(node_23, 15), Pair(node_25, 15), Pair(node_8, 15),
      Pair(node_5, 15), Pair(node_4, 15), Pair(node_1, 15), Pair(node_6, 15),
      Pair(node_11, 15), Pair(node_28, 15), Pair(node_14, 15), Pair(node_19, 15),
      Pair(node_10, 15), Pair(node_27, 15), Pair(node_21, 15), Pair(node_2, 15),
      Pair(node_18, 15), Pair(node_22, 15),
    ]

  let median = 112
  let iqr_fence_multiplier = 150
  let median_divergency_factor = 200

  check_reward_distribution(
    node_feeds_sorted_by_feed,
    30,
    median,
    node_reward_price,
    in_distribution,
    out_distribution,
    nodes,
    iqr_fence_multiplier,
    median_divergency_factor,
  )
}

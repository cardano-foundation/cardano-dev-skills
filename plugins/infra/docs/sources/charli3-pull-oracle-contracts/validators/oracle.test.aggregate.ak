use aiken/builtin
use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{ScriptHash}
use aiken/interval
use aiken/primitive/bytearray
use cardano/address
use cardano/assets.{AssetName, PolicyId} as assets
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use cardano/transaction as tx
use config
use core/datum.{
  AggState, FeeConfig, GenericData, OracleConfiguration, OracleSettings,
  OracleSettingsDatum, RewardAccount, RewardAccountDatum, RewardPrices,
  create_price_data,
}
use core/redeemer.{OdvAggregate, OdvAggregateMsg}
use ext/aiken/math/rational.{coin_precision}
use ext/cardano/value.{Asset}
use oracle

const platform_policy_id: assets.PolicyId =
  #"000102030405060708090a0b0c0d0e0f101112131415161718191a1b"

const oracle_policy_id: assets.PolicyId =
  #"1c1d1e1f202122232425262728292a2b2c2d2e2f30313233343536373839"

const oracle_script_hash: ScriptHash =
  #"5d5e5f606162636465666768696a6b6c6d6e6f70717273747576777879"

const agg_liveness: Int = 3_600_000

const platform_uncertainty: Int = 600_000

const aggregation_uncertainty: Int = 120_000

const pause_period: Int = 86_400_000

const utxo_buffer: Int = 5_000_000

const node_fee: Int = 1_000_000

const platform_fee: Int = 500_000

const mock_conf =
  OracleConfiguration {
    platform_auth_nft: platform_policy_id,
    pause_period_length: pause_period,
    reward_dismissing_period_length: pause_period,
    fee_token: None,
  }

const mock_fee_token_policy_id: PolicyId = "C3 policy id"

const mock_fee_token_name: AssetName = "C3"

const mock_conf_with_token =
  OracleConfiguration {
    platform_auth_nft: platform_policy_id,
    pause_period_length: pause_period,
    reward_dismissing_period_length: pause_period,
    fee_token: Some(
      Asset { policy_id: mock_fee_token_policy_id, name: mock_fee_token_name },
    ),
  }

const mock_rate_nft =
  Asset { policy_id: "C3/USD policy id", name: config.aggstate_token_name }

const mock_nodes =
  [
    "node01               FeedVkh", "node02               FeedVkh",
    "node03               FeedVkh", "node04               FeedVkh",
    "node05               FeedVkh", "node06               FeedVkh",
    "node07               FeedVkh", "node08               FeedVkh",
    "node09               FeedVkh", "node10               FeedVkh",
    "node11               FeedVkh", "node12               FeedVkh",
    "node13               FeedVkh", "node14               FeedVkh",
    "node15               FeedVkh", "node16               FeedVkh",
    "node17               FeedVkh", "node18               FeedVkh",
    "node19               FeedVkh", "node20               FeedVkh",
    "node21               FeedVkh",
  ]

const mock_settings =
  OracleSettingsDatum {
    nodes: mock_nodes,
    required_node_signatures_count: 16,
    fee_info: FeeConfig {
      rate_nft: None,
      reward_prices: RewardPrices { node_fee, platform_fee },
    },
    aggregation_liveness_period: agg_liveness,
    time_uncertainty_aggregation: aggregation_uncertainty,
    time_uncertainty_platform: platform_uncertainty,
    iqr_fence_multiplier: 150,
    median_divergency_factor: 10,
    utxo_size_safety_buffer: utxo_buffer,
    pause_period_started_at: None,
  }

const mock_core_settings_token_value =
  assets.from_asset(oracle_policy_id, config.core_settings_token_name, 1)

const mock_median: Int = 449999

const mock_node_feeds_count: Int = 21

const mock_node_fee: Int = 10_000_000

const mock_platform_fee: Int = 2_000_000

const mock_minimum_fee_amount: Int =
  mock_node_feeds_count * mock_node_fee + mock_platform_fee

const empty_oracle_feed = AggState(GenericData { price_map: [] })

const mock_aggstate_token_value =
  assets.from_asset(oracle_policy_id, config.aggstate_token_name, 1)

const mock_empty_aggstate_output =
  Output {
    address: address.from_script(oracle_script_hash),
    value: mock_aggstate_token_value,
    datum: tx.InlineDatum(empty_oracle_feed),
    reference_script: None,
  }

const mock_empty_reward_account_datum =
  RewardAccountDatum {
    nodes_to_rewards: list.map(mock_nodes, fn(node) { Pair(node, 0) }),
    last_update_time: 0,
  }

const mock_reward_account_token_value =
  assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1)

const mock_empty_reward_account_output =
  Output {
    address: address.from_script(oracle_script_hash),
    value: mock_reward_account_token_value,
    datum: tx.InlineDatum(RewardAccount(mock_empty_reward_account_datum)),
    reference_script: None,
  }

const mock_precise_tx_validity_interval =
  interval.between(1732195907000, 1732195907000 + aggregation_uncertainty)

const mock_current_time =
  ( 1732195907000 + 1732195907000 + aggregation_uncertainty ) / 2

const mock_core_settings_input =
  tx.Input {
    output_reference: OutputReference {
      transaction_id: "core settings before odv aggregation tx",
      output_index: 0,
    },
    output: tx.Output {
      address: address.from_script(oracle_script_hash),
      value: mock_core_settings_token_value,
      datum: tx.InlineDatum(
        OracleSettings(
          OracleSettingsDatum {
            ..mock_settings,
            fee_info: FeeConfig {
              rate_nft: None,
              reward_prices: RewardPrices {
                node_fee: mock_node_fee,
                platform_fee: mock_platform_fee,
              },
            },
          },
        ),
      ),
      reference_script: None,
    },
  }

const mock_core_settings_input_using_ada_fee =
  tx.Input {
    output_reference: OutputReference {
      transaction_id: "some tx",
      output_index: 11,
    },
    output: tx.Output {
      address: address.from_script(oracle_script_hash),
      value: mock_core_settings_token_value,
      datum: tx.InlineDatum(OracleSettings(mock_settings)),
      reference_script: None,
    },
  }

const thirty_minutes: Int = 1_800_000

test successful_odv_aggregation() {
  let aggstate_ref =
    OutputReference {
      transaction_id: #"61676773746174655f746f6b656e",
      output_index: 0,
    }
  let aggstate_before = empty_oracle_feed
  let aggstate_after =
    AggState(
      create_price_data(
        mock_median,
        mock_current_time,
        mock_current_time + agg_liveness,
      ),
    )
  let aggstate_input =
    Input { output_reference: aggstate_ref, output: mock_empty_aggstate_output }
  let aggstate_output =
    Output {
      address: address.from_script(oracle_script_hash),
      value: mock_aggstate_token_value,
      datum: tx.InlineDatum(aggstate_after),
      reference_script: None,
    }

  let reward_account_ref =
    OutputReference {
      transaction_id: #"7265776172645f746f6b656e",
      output_index: 0,
    }

  let mock_node_feeds_sorted =
    list.map(mock_nodes, fn(node) { Pair(node, mock_median) })

  let expected_nodes_to_rewards =
    list.map(mock_nodes, fn(node) { Pair(node, mock_node_fee) })

  let sorted_expected_nodes_to_rewards =
    expected_nodes_to_rewards
      |> list.sort(
          fn(p1: Pair<ByteArray, Int>, p2: Pair<ByteArray, Int>) -> Ordering {
            bytearray.compare(builtin.fst_pair(p1), builtin.fst_pair(p2))
          },
        )
  let reward_account_after =
    RewardAccount(
      RewardAccountDatum {
        nodes_to_rewards: sorted_expected_nodes_to_rewards,
        last_update_time: mock_current_time,
      },
    )

  let reward_account_before = RewardAccount(mock_empty_reward_account_datum)

  let reward_account_input =
    Input {
      output_reference: reward_account_ref,
      output: mock_empty_reward_account_output,
    }
  let reward_account_output =
    Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        mock_reward_account_token_value,
        assets.merge(
          assets.from_lovelace(utxo_buffer),
          assets.from_asset(
            mock_fee_token_policy_id,
            mock_fee_token_name,
            mock_minimum_fee_amount,
          ),
        ),
      ),
      datum: tx.InlineDatum(reward_account_after),
      reference_script: None,
    }

  let odv_aggregate_redeemer: Data = OdvAggregate(mock_node_feeds_sorted)
  let odv_aggregate_msg_redeemer: Data = OdvAggregateMsg
  let signatories_from_feeds =
    mock_node_feeds_sorted
      |> pairs.keys
      |> list.sort(
          fn(a: ByteArray, b: ByteArray) -> Ordering { bytearray.compare(a, b) },
        )

  let aggregation_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [mock_core_settings_input],
      inputs: [reward_account_input, aggstate_input],
      redeemers: [
        Pair(tx.Spend(reward_account_ref), odv_aggregate_redeemer),
        Pair(tx.Spend(aggstate_ref), odv_aggregate_msg_redeemer),
      ],
      outputs: [reward_account_output, aggstate_output],
      validity_range: mock_precise_tx_validity_interval,
      extra_signatories: signatories_from_feeds,
    }

  expect
    oracle.oracle_manager.spend(
      mock_conf_with_token,
      Some(reward_account_before),
      OdvAggregate(mock_node_feeds_sorted),
      reward_account_ref,
      aggregation_tx,
    ) && oracle.oracle_manager.spend(
      mock_conf_with_token,
      Some(aggstate_before),
      OdvAggregateMsg,
      aggstate_ref,
      aggregation_tx,
    )
}

test successful_odv_aggregation_with_ada_fees() {
  let aggstate_ref =
    OutputReference {
      transaction_id: #"61676773746174655f746f6b656e",
      output_index: 0,
    }
  let aggstate_before = empty_oracle_feed
  let aggstate_after =
    AggState(
      create_price_data(
        mock_median,
        mock_current_time,
        mock_current_time + agg_liveness,
      ),
    )
  let aggstate_input =
    Input { output_reference: aggstate_ref, output: mock_empty_aggstate_output }
  let aggstate_output =
    Output {
      address: address.from_script(oracle_script_hash),
      value: mock_aggstate_token_value,
      datum: tx.InlineDatum(aggstate_after),
      reference_script: None,
    }

  let reward_account_ref =
    OutputReference {
      transaction_id: #"7265776172645f746f6b656e",
      output_index: 0,
    }

  let mock_node_feeds_sorted =
    list.map(mock_nodes, fn(node) { Pair(node, mock_median) })

  let expected_nodes_to_rewards =
    list.map(mock_nodes, fn(node) { Pair(node, node_fee) })

  let sorted_expected_nodes_to_rewards =
    expected_nodes_to_rewards
      |> list.sort(
          fn(p1: Pair<ByteArray, Int>, p2: Pair<ByteArray, Int>) -> Ordering {
            bytearray.compare(builtin.fst_pair(p1), builtin.fst_pair(p2))
          },
        )

  let reward_account_after =
    RewardAccount(
      RewardAccountDatum {
        nodes_to_rewards: sorted_expected_nodes_to_rewards,
        last_update_time: mock_current_time,
      },
    )

  let reward_account_before = RewardAccount(mock_empty_reward_account_datum)

  let reward_account_input =
    Input {
      output_reference: reward_account_ref,
      output: mock_empty_reward_account_output,
    }

  let minimum_fee_amount_for_ada =
    mock_node_feeds_count * node_fee + platform_fee

  let reward_account_output =
    Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        mock_reward_account_token_value,
        assets.merge(
          assets.from_lovelace(utxo_buffer),
          assets.from_lovelace(minimum_fee_amount_for_ada),
        ),
      ),
      datum: tx.InlineDatum(reward_account_after),
      reference_script: None,
    }

  let odv_aggregate_redeemer: Data = OdvAggregate(mock_node_feeds_sorted)
  let odv_aggregate_msg_redeemer: Data = OdvAggregateMsg
  let signatories_from_feeds =
    mock_node_feeds_sorted
      |> pairs.keys
      |> list.sort(
          fn(a: ByteArray, b: ByteArray) -> Ordering { bytearray.compare(a, b) },
        )

  let aggregation_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [mock_core_settings_input_using_ada_fee],
      inputs: [reward_account_input, aggstate_input],
      redeemers: [
        Pair(tx.Spend(reward_account_ref), odv_aggregate_redeemer),
        Pair(tx.Spend(aggstate_ref), odv_aggregate_msg_redeemer),
      ],
      outputs: [reward_account_output, aggstate_output],
      validity_range: mock_precise_tx_validity_interval,
      extra_signatories: signatories_from_feeds,
    }

  expect
    oracle.oracle_manager.spend(
      mock_conf,
      Some(reward_account_before),
      OdvAggregate(mock_node_feeds_sorted),
      reward_account_ref,
      aggregation_tx,
    ) && oracle.oracle_manager.spend(
      mock_conf,
      Some(aggstate_before),
      OdvAggregateMsg,
      aggstate_ref,
      aggregation_tx,
    )
}

test successful_odv_aggregation_with_dynamic_oracle_fees_calculation() {
  let core_settings_input =
    tx.Input {
      output_reference: OutputReference {
        transaction_id: "some tx",
        output_index: 1,
      },
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value: mock_core_settings_token_value,
        datum: tx.InlineDatum(
          OracleSettings(
            OracleSettingsDatum {
              ..mock_settings,
              fee_info: FeeConfig {
                rate_nft: Some(mock_rate_nft),
                reward_prices: RewardPrices { node_fee, platform_fee },
              },
            },
          ),
        ),
        reference_script: None,
      },
    }

  let c3_rate: Int = 130_000

  let convert_to_rate =
    fn(amount: Int) -> Int {
      ( amount * c3_rate + coin_precision - 1 ) / coin_precision
    }

  let c3_rate_input =
    tx.Input {
      output_reference: OutputReference {
        transaction_id: "some tx",
        output_index: 2,
      },
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value: assets.from_asset(
          mock_rate_nft.policy_id,
          config.aggstate_token_name,
          1,
        ),
        datum: tx.InlineDatum(
          AggState(
            create_price_data(
              c3_rate,
              mock_current_time - thirty_minutes / 2,
              mock_current_time - thirty_minutes / 2 + agg_liveness,
            ),
          ),
        ),
        reference_script: None,
      },
    }

  let aggstate_ref =
    OutputReference {
      transaction_id: #"61676773746174655f746f6b656e",
      output_index: 0,
    }
  let aggstate_before = empty_oracle_feed
  let aggstate_after =
    AggState(
      create_price_data(
        mock_median,
        mock_current_time,
        mock_current_time + agg_liveness,
      ),
    )
  let aggstate_input =
    Input { output_reference: aggstate_ref, output: mock_empty_aggstate_output }
  let aggstate_output =
    Output {
      address: address.from_script(oracle_script_hash),
      value: mock_aggstate_token_value,
      datum: tx.InlineDatum(aggstate_after),
      reference_script: None,
    }

  let reward_account_ref =
    OutputReference {
      transaction_id: #"7265776172645f746f6b656e",
      output_index: 0,
    }
  let reward_account_before = RewardAccount(mock_empty_reward_account_datum)

  let mock_node_feeds_sorted =
    list.map(mock_nodes, fn(node) { Pair(node, mock_median) })

  let expected_nodes_to_rewards =
    list.map(mock_nodes, fn(node) { Pair(node, convert_to_rate(node_fee)) })
  let sorted_expected_nodes_to_rewards =
    expected_nodes_to_rewards
      |> list.sort(
          fn(p1: Pair<ByteArray, Int>, p2: Pair<ByteArray, Int>) -> Ordering {
            bytearray.compare(builtin.fst_pair(p1), builtin.fst_pair(p2))
          },
        )

  let reward_account_after =
    RewardAccount(
      RewardAccountDatum {
        nodes_to_rewards: sorted_expected_nodes_to_rewards,
        last_update_time: mock_current_time,
      },
    )

  let reward_account_input =
    Input {
      output_reference: reward_account_ref,
      output: mock_empty_reward_account_output,
    }

  let minimum_fee_amount_for_dynamic =
    convert_to_rate(mock_node_feeds_count * node_fee + platform_fee)

  let reward_account_output =
    Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        mock_reward_account_token_value,
        assets.merge(
          assets.from_lovelace(utxo_buffer),
          assets.from_asset(
            mock_fee_token_policy_id,
            mock_fee_token_name,
            minimum_fee_amount_for_dynamic,
          ),
        ),
      ),
      datum: tx.InlineDatum(reward_account_after),
      reference_script: None,
    }

  let odv_aggregate_redeemer: Data = OdvAggregate(mock_node_feeds_sorted)
  let odv_aggregate_msg_redeemer: Data = OdvAggregateMsg
  let signatories_from_feeds =
    mock_node_feeds_sorted
      |> pairs.keys
      |> list.sort(
          fn(a: ByteArray, b: ByteArray) -> Ordering { bytearray.compare(a, b) },
        )
  let aggregation_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input, c3_rate_input],
      inputs: [reward_account_input, aggstate_input],
      redeemers: [
        Pair(tx.Spend(reward_account_ref), odv_aggregate_redeemer),
        Pair(tx.Spend(aggstate_ref), odv_aggregate_msg_redeemer),
      ],
      outputs: [reward_account_output, aggstate_output],
      validity_range: mock_precise_tx_validity_interval,
      extra_signatories: signatories_from_feeds,
    }

  expect
    oracle.oracle_manager.spend(
      mock_conf_with_token,
      Some(aggstate_before),
      OdvAggregateMsg,
      aggstate_ref,
      aggregation_tx,
    ) && oracle.oracle_manager.spend(
      mock_conf_with_token,
      Some(reward_account_before),
      OdvAggregate(mock_node_feeds_sorted),
      reward_account_ref,
      aggregation_tx,
    )
}

use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{ScriptHash}
use aiken/interval
use aiken/math/rational
use aiken/option.{is_some}
use cardano/assets.{PolicyId, Value}
use cardano/transaction.{Input,
  Output, Redeemer, ScriptPurpose, ValidityRange} as tx
use core/consensus.{consensus_by_iqr_and_divergency}
use core/datum.{
  AggState, AggregateMessage, FeedVkh, GenericData, NodeFeed, Nodes,
  OracleConfiguration, OracleDatum, OracleFeed, OracleSettingsDatum, PriceData,
  RewardAccount, RewardAccountDatum, RewardPrices, get_price_data,
}
use core/redeemer.{
  AddNodes, DelNodes, DismissRewards, OdvAggregate, OracleRedeemer,
  RedeemRewards, RewardRedeemer, SettingsRedeemer,
}
use ext/aiken/math/rational.{Percent, Permille, coin_precision} as ext
use ext/aiken/time.{PosixTime, PosixTimeDiff}
use ext/cardano/value.{Asset}
use services/protocol_token.{
  find_script_inputs_by_token, find_script_outputs_by_token,
  find_script_outputs_by_token_allowing_asset,
}

/// A convenience function that calls find_script_inputs_by_token
/// and also checks number of spent inputs
pub fn spends_protocol_nft_inputs(
  script_hash: ScriptHash,
  redeemer: OracleRedeemer,
  protocol_nft: Asset,
  utxo_count: Int,
  tx_inputs: List<Input>,
  tx_redeemers: Pairs<ScriptPurpose, Redeemer>,
) -> Bool {
  trace @"T7"

  let as_data: Data = redeemer
  let refs =
    find_script_inputs_by_token(tx_inputs, script_hash, protocol_nft)
      |> list.map(fn(i) { i.output_reference })

  let refs_that_have_correct_redeemers =
    list.filter(
      refs,
      fn(ref) {
        expect Some(r) = pairs.get_first(tx_redeemers, tx.Spend(ref))

        r == as_data
      },
    )

  list.length(refs_that_have_correct_redeemers) == utxo_count
}

/// Find one protocol NFT inside transaction inputs.
/// Same as spends_protocol_nft_inputs, but more optimized.
pub fn spends_one_script_utxo_with_nft(
  script_hash: ScriptHash,
  redeemer: OracleRedeemer,
  nft: Asset,
  tx_inputs: List<Input>,
  tx_redeemers: Pairs<ScriptPurpose, Redeemer>,
) -> Bool {
  trace @"T8"

  let as_data: Data = redeemer
  expect [input] = find_script_inputs_by_token(tx_inputs, script_hash, nft)
  expect Some(r) =
    pairs.get_first(tx_redeemers, tx.Spend(input.output_reference))

  r == as_data
}

pub fn spends_one_account_utxo_for_aggregation(
  script_hash: ScriptHash,
  acc_nft: Asset,
  tx_inputs: List<Input>,
  tx_redeemers: Pairs<ScriptPurpose, Redeemer>,
) -> Bool {
  trace @"T9"

  expect [input] = find_script_inputs_by_token(tx_inputs, script_hash, acc_nft)
  expect Some(redeemer) =
    pairs.get_first(tx_redeemers, tx.Spend(input.output_reference))
  expect r: OracleRedeemer = redeemer
  expect OdvAggregate(_) = r

  True
}

pub fn returns_empty_account_outputs(
  script_hash: ScriptHash,
  reward_account_nft: Asset,
  total_input_accounts: Int,
  tx_outputs: List<Output>,
  utxo_size_safety_buffer: Int,
) -> Bool {
  trace @"T10"

  let outputs =
    find_script_outputs_by_token(tx_outputs, script_hash, reward_account_nft)
  let extractor =
    fn(output: Output) -> Value {
      expect tx.InlineDatum(datum) = output.datum
      expect oracle_datum: OracleDatum = datum
      expect RewardAccount(RewardAccountDatum { nodes_to_rewards: [], .. }) =
        oracle_datum

      output.value
    }
  let empty_outputs_value = list.map(outputs, extractor)

  list.length(empty_outputs_value) == total_input_accounts && list.all(
    empty_outputs_value,
    check_utxo_size_safety_buffer(utxo_size_safety_buffer, _),
  )
}

pub fn returns_empty_aggstate_outputs(
  script_hash: ScriptHash,
  aggstate_nft: Asset,
  utxo_count: Int,
  tx_outputs: List<Output>,
) -> Bool {
  trace @"T11"
  let outputs =
    find_script_outputs_by_token(tx_outputs, script_hash, aggstate_nft)
  let extractor =
    fn(output: Output) -> Bool {
      expect tx.InlineDatum(datum) = output.datum
      expect oracle_datum: OracleDatum = datum
      expect AggState(GenericData { price_map }) = oracle_datum
      list.is_empty(price_map)
    }

  list.length(outputs) == utxo_count && list.all(outputs, extractor)
}

pub fn find_out_datum_and_value(
  tx_outputs: List<Output>,
  script_hash: ScriptHash,
  protocol_token: Asset,
) -> List<(OracleDatum, Value)> {
  trace @"T12"

  let script_outputs =
    find_script_outputs_by_token(tx_outputs, script_hash, protocol_token)
  list.map(
    script_outputs,
    fn(script_output) {
      expect tx.InlineDatum(datum) = script_output.datum
      expect oracle_datum: OracleDatum = datum
      (oracle_datum, script_output.value)
    },
  )
}

pub fn find_out_datum_and_value_with_allowing_asset(
  tx_outputs: List<Output>,
  script_hash: ScriptHash,
  protocol_token: Asset,
  allowed_asset: Option<Asset>,
) -> List<(OracleDatum, Value)> {
  trace @"T13"

  when allowed_asset is {
    None -> find_out_datum_and_value(tx_outputs, script_hash, protocol_token)
    Some(asset) -> {
      let script_outputs =
        find_script_outputs_by_token_allowing_asset(
          tx_outputs,
          script_hash,
          asset.policy_id,
          protocol_token,
        )
      list.map(
        script_outputs,
        fn(script_output) {
          expect tx.InlineDatum(datum) = script_output.datum
          expect oracle_datum: OracleDatum = datum
          (oracle_datum, script_output.value)
        },
      )
    }
  }
}

pub fn find_referenced_datum(
  tx_reference_inputs: List<Input>,
  script_hash: ScriptHash,
  protocol_token: Asset,
) -> OracleDatum {
  trace @"T14"

  expect [script_in] =
    find_script_inputs_by_token(
      tx_reference_inputs,
      script_hash,
      protocol_token,
    )
  expect tx.InlineDatum(datum) = script_in.output.datum
  expect oracle_datum: OracleDatum = datum

  oracle_datum
}

pub fn find_in_datum(
  tx_inputs: List<Input>,
  tx_redeemers: Pairs<ScriptPurpose, Redeemer>,
  script_hash: ScriptHash,
  redeemer: OracleRedeemer,
  protocol_token: Asset,
) -> OracleDatum {
  trace @"T15"

  expect [script_in] =
    find_script_inputs_by_token(tx_inputs, script_hash, protocol_token)

  let as_data: Data = redeemer
  expect Some(r) =
    pairs.get_first(tx_redeemers, tx.Spend(script_in.output_reference))
  expect r == as_data

  expect tx.InlineDatum(datum) = script_in.output.datum
  expect oracle_datum: OracleDatum = datum

  oracle_datum
}

pub fn count_dismissed_reward_accounts(
  tx_inputs: List<Input>,
  tx_redeemers: Pairs<ScriptPurpose, Redeemer>,
  script_hash: ScriptHash,
  protocol_token: Asset,
) -> Int {
  trace @"T16"

  let acc_inputs =
    find_script_inputs_by_token(tx_inputs, script_hash, protocol_token)

  let as_data: Data = DismissRewards
  let refs = list.map(acc_inputs, fn(i) { i.output_reference })
  let must_have_correct_redeemers =
    list.all(
      refs,
      fn(ref) {
        expect Some(r) = pairs.get_first(tx_redeemers, tx.Spend(ref))
        r == as_data
      },
    )
  expect must_have_correct_redeemers

  list.length(acc_inputs)
}

pub fn check_reward_accounts_in_to_out_mapping(
  tx_inputs: List<Input>,
  tx_outputs: List<Output>,
  tx_redeemers: Pairs<ScriptPurpose, Redeemer>,
  script_hash: ScriptHash,
  protocol_token: Asset,
  reward_redeemer: RewardRedeemer,
  allowed_asset: Option<Asset>,
) -> Bool {
  trace @"T17"

  let acc_inputs =
    find_script_inputs_by_token(tx_inputs, script_hash, protocol_token)
  let out_refs =
    list.map(
      acc_inputs,
      fn(i) {
        let ref = i.output_reference
        expect Some(r) = pairs.get_first(tx_redeemers, tx.Spend(ref))
        expect redeemer: OracleRedeemer = r
        expect RedeemRewards { collector, corresponding_out_ix } = redeemer
        expect collector == reward_redeemer
        corresponding_out_ix
      },
    )
  let acc_inputs_count = get_length_and_check_strict_order(out_refs)

  when allowed_asset is {
    None ->
      acc_inputs_count == list.length(
        find_script_outputs_by_token(tx_outputs, script_hash, protocol_token),
      )

    Some(asset) ->
      acc_inputs_count == list.length(
        find_script_outputs_by_token_allowing_asset(
          tx_outputs,
          script_hash,
          asset.policy_id,
          protocol_token,
        ),
      )
  }
}

pub fn get_length_and_check_strict_order(ints_sorted: List<Int>) -> Int {
  trace @"T18"

  go_get_length_and_check_strict_order(ints_sorted, 0, None)
}

fn go_get_length_and_check_strict_order(
  ints_sorted: List<Int>,
  count: Int,
  prev_opt: Option<Int>,
) -> Int {
  when ints_sorted is {
    [] -> count
    [curr, ..rest] ->
      // Check ordering only if we have a previous value
      when prev_opt is {
        Some(prev) ->
          if prev < curr {
            go_get_length_and_check_strict_order(rest, count + 1, Some(curr))
          } else {
            fail @"E5"
          }
        None ->
          go_get_length_and_check_strict_order(rest, count + 1, Some(curr))
      }
  }
}

pub fn does_not_produce_own_nft_outputs(
  tx_outputs: List<Output>,
  own_nft_policy_id: PolicyId,
) -> Bool {
  trace @"T19"

  tx_outputs
    |> list.filter(
        fn(o) {
          o.value |> assets.to_dict |> dict.get(own_nft_policy_id) |> is_some
        },
      )
    |> list.is_empty
}

pub fn is_aggstate_expired(
  price_data: PriceData,
  tx_validity_range: ValidityRange,
) -> Bool {
  trace @"T20"
  get_price_data(price_data, 2)
    |> option.map(
        fn(time_expiration) {
          interval.is_entirely_after(tx_validity_range, time_expiration)
        },
      )
    |> option.or_else(True)
}

pub fn convert_reward_prices(
  tx_reference_inputs: List<Input>,
  tx_validity_range: ValidityRange,
  rate_nft: Option<Asset>,
  reward_prices: RewardPrices,
) -> RewardPrices {
  trace @"T21"

  when rate_nft is {
    None -> reward_prices
    Some(nft) -> {
      expect Some(rate_input) =
        tx_reference_inputs
          |> list.find(
              fn(input) {
                input.output.value
                  |> assets.flatten
                  |> list.has((nft.policy_id, nft.name, 1))
              },
            )
      expect tx.InlineDatum(datum) = rate_input.output.datum
      expect oracle_datum: OracleDatum = datum
      expect AggState(generic_data) = oracle_datum
      expect Some(price) = get_price_data(generic_data, 0)
      expect Some(rate) = rational.new(price, coin_precision)

      expect Some(time_expiration) = get_price_data(generic_data, 2)
      expect interval.is_entirely_before(tx_validity_range, time_expiration)

      let convert_reward =
        fn(reward: Int) -> Int {
          rational.from_int(reward) |> rational.mul(rate) |> rational.ceil
        }

      RewardPrices {
        node_fee: convert_reward(reward_prices.node_fee),
        platform_fee: convert_reward(reward_prices.platform_fee),
      }
    }
  }
}

pub fn calculate_minimum_fee_amount(
  reward_prices: RewardPrices,
  nodes_count: Int,
) -> Int {
  reward_prices.node_fee * nodes_count + reward_prices.platform_fee
}

pub fn calculate_asset_net_change(
  asset: Asset,
  in_value: Value,
  out_value: Value,
) -> Int {
  assets.quantity_of(out_value, asset.policy_id, asset.name) - assets.quantity_of(
    in_value,
    asset.policy_id,
    asset.name,
  )
}

pub fn calculate_asset_net_change_with_default(
  asset: Option<Asset>,
  in_value: Value,
  out_value: Value,
) -> Int {
  option.or_else(
    asset,
    Asset { policy_id: assets.ada_policy_id, name: assets.ada_asset_name },
  )
    |> calculate_asset_net_change(in_value, out_value)
}

pub fn calculate_asset_quantity_with_default(
  value: Value,
  optional_asset: Option<Asset>,
) -> Int {
  when optional_asset is {
    None ->
      assets.quantity_of(value, assets.ada_policy_id, assets.ada_asset_name)
    Some(asset) -> assets.quantity_of(value, asset.policy_id, asset.name)
  }
}

pub fn conserves_utxo_value_strict(in_value: Value, out_value: Value) -> Bool {
  trace @"T22"
  in_value == out_value
}

pub fn conserves_utxo_value(in_value: Value, out_value: Value) -> Bool {
  let in_tokens = assets.without_lovelace(in_value)
  let out_tokens = assets.without_lovelace(out_value)
  let must_conserve_token_value = in_tokens == out_tokens

  let in_lovelace = assets.lovelace_of(in_value)
  let out_lovelace = assets.lovelace_of(out_value)
  let must_conserve_ada_value = in_lovelace <= out_lovelace

  must_conserve_token_value && must_conserve_ada_value
}

pub fn check_utxo_size_safety_buffer(
  utxo_size_safety_buffer: Int,
  out_value: Value,
) -> Bool {
  trace @"T23"

  let out_lovelace = assets.lovelace_of(out_value)

  out_lovelace >= utxo_size_safety_buffer
}

pub fn check_reward_distribution(
  node_feeds_sorted_by_feed: AggregateMessage,
  node_feeds_count: Int,
  median: OracleFeed,
  node_reward_price: Int,
  in_distribution: Pairs<FeedVkh, Int>,
  out_distribution: Pairs<FeedVkh, Int>,
  nodes: Nodes,
  iqr_fence_multiplier: Percent,
  median_divergency_factor: Permille,
) -> Bool {
  trace @"T24"
  let rewarded_feed_nodes =
    consensus_by_iqr_and_divergency(
      median,
      node_feeds_sorted_by_feed,
      node_feeds_count,
      iqr_fence_multiplier,
      median_divergency_factor,
    )
  let rewarded_feed_dict =
    list.foldr(
      rewarded_feed_nodes,
      dict.empty,
      fn(feed_vkh, acc) { dict.insert(acc, feed_vkh, True) },
    )
  let in_distribution_dict = dict.from_ascending_pairs(in_distribution)

  let (is_valid, remaining_rewarded, remaining_inputs, _) =
    list.foldl(
      out_distribution,
      (True, rewarded_feed_dict, in_distribution_dict, nodes),
      fn(Pair(out_feed_vkh, out_amount), state) {
        let (ok, acc_rewarded, acc_inputs, remaining_allowed) = state
        if !ok {
          state
        } else {
          when consume_allowed_feed(remaining_allowed, out_feed_vkh) is {
            None -> (False, acc_rewarded, acc_inputs, remaining_allowed)
            Some(next_allowed) -> {
              let (base_amount, next_inputs) =
                when dict.get(acc_inputs, out_feed_vkh) is {
                  None -> (0, acc_inputs)
                  Some(amount) ->
                    (amount, dict.delete(acc_inputs, out_feed_vkh))
                }
              let (expected_reward, next_rewarded) =
                if dict.has_key(acc_rewarded, out_feed_vkh) {
                  (node_reward_price, dict.delete(acc_rewarded, out_feed_vkh))
                } else {
                  (0, acc_rewarded)
                }
              let expected_amount = base_amount + expected_reward

              if expected_amount == out_amount && out_amount > 0 {
                (True, next_rewarded, next_inputs, next_allowed)
              } else {
                (False, acc_rewarded, acc_inputs, remaining_allowed)
              }
            }
          }
        }
      },
    )

  is_valid && dict.size(remaining_rewarded) == 0 && dict.size(remaining_inputs) == 0
}

fn consume_allowed_feed(nodes: Nodes, feed: FeedVkh) -> Option<Nodes> {
  when nodes is {
    [] -> None
    [candidate, ..rest] ->
      if builtin.less_than_bytearray(candidate, feed) {
        consume_allowed_feed(rest, feed)
      } else if candidate == feed {
        Some(rest)
      } else {
        None
      }
  }
}

pub fn validate_message_and_count_nodes(
  node_feeds_sorted_by_feed: AggregateMessage,
) -> Int {
  trace @"T25"
  go_check_order_and_count(pairs.values(node_feeds_sorted_by_feed), 0, None)
}

fn go_check_order_and_count(
  node_feeds: List<NodeFeed>,
  count: Int,
  prev_opt: Option<NodeFeed>,
) -> Int {
  when node_feeds is {
    [] -> count
    [curr, ..rest] ->
      // Check ordering only if we have a previous value
      when prev_opt is {
        Some(prev) ->
          if prev <= curr {
            go_check_order_and_count(rest, count + 1, Some(curr))
          } else {
            fail @"E5"
          }
        None -> go_check_order_and_count(rest, count + 1, Some(curr))
      }
  }
}

pub fn check_settings_sanity(
  oracle_conf: OracleConfiguration,
  in_settings: OracleSettingsDatum,
  out_settings: OracleSettingsDatum,
) -> Bool {
  trace @"T26"

  in_settings.nodes == out_settings.nodes && in_settings.pause_period_started_at == out_settings.pause_period_started_at && validate_settings_form(
    oracle_conf,
    out_settings,
  )
}

pub fn validate_settings_form(
  oracle_conf: OracleConfiguration,
  oracle_settings: OracleSettingsDatum,
) -> Bool {
  trace @"T27"

  let must_not_break_multisig =
    oracle_settings.required_node_signatures_count > 0 && oracle_settings.required_node_signatures_count <= list.length(
      oracle_settings.nodes,
    )

  let must_measure_time_precisely =
    oracle_settings.aggregation_liveness_period > oracle_settings.time_uncertainty_platform && oracle_conf.pause_period_length > oracle_settings.time_uncertainty_platform && oracle_conf.reward_dismissing_period_length > oracle_settings.time_uncertainty_platform
  let must_have_fair_validity_intervals =
    oracle_settings.time_uncertainty_platform > oracle_settings.time_uncertainty_aggregation && oracle_settings.time_uncertainty_aggregation > 0

  let must_be_fair_about_outliers =
    oracle_settings.iqr_fence_multiplier > 100 && oracle_settings.median_divergency_factor >= 1
  let must_not_have_negative_utxo_buffer =
    oracle_settings.utxo_size_safety_buffer > 0

  let must_not_have_negative_prices =
    oracle_settings.fee_info.reward_prices.node_fee >= 0 && oracle_settings.fee_info.reward_prices.platform_fee >= 0

  must_not_break_multisig && must_measure_time_precisely && must_have_fair_validity_intervals && must_be_fair_about_outliers && must_not_have_negative_utxo_buffer && must_not_have_negative_prices
}

pub fn check_pause_does_not_change_settings(
  in_core_datum: OracleSettingsDatum,
  out_core_datum: OracleSettingsDatum,
) -> Bool {
  trace @"T28"

  in_core_datum.nodes == out_core_datum.nodes && in_core_datum.utxo_size_safety_buffer == out_core_datum.utxo_size_safety_buffer && in_core_datum.iqr_fence_multiplier == out_core_datum.iqr_fence_multiplier && in_core_datum.median_divergency_factor == out_core_datum.median_divergency_factor && in_core_datum.fee_info == out_core_datum.fee_info && in_core_datum.aggregation_liveness_period == out_core_datum.aggregation_liveness_period && in_core_datum.time_uncertainty_platform == out_core_datum.time_uncertainty_platform && in_core_datum.time_uncertainty_aggregation == out_core_datum.time_uncertainty_aggregation
}

pub fn find_node_by_signature(
  tx_signatories: List<a>,
  nodes_to_rewards: List<Pair<a, b>>,
) -> a {
  trace @"T29"
  expect [first, ..] = tx_signatories
  expect Some(_) = list.find(nodes_to_rewards, fn(pair) { pair.1st == first })
  first
}

fn remove_reward_entry(
  entries: Pairs<FeedVkh, Int>,
  target: FeedVkh,
) -> Option<Pair<Int, Pairs<FeedVkh, Int>>> {
  when entries is {
    [] -> None
    [Pair(node, amount), ..rest] ->
      if node == target {
        Some(Pair(amount, rest))
      } else {
        when remove_reward_entry(rest, target) is {
          Some(Pair(found, remaining)) ->
            Some(Pair(found, [Pair(node, amount), ..remaining]))
          None -> None
        }
      }
  }
}

pub fn check_node_received_reward(
  fee_token: Option<Asset>,
  node_id: FeedVkh,
  in_distribution: RewardAccountDatum,
  in_value: Value,
  reward_account_output: Output,
  utxo_size_safety_buffer: Int,
) -> Bool {
  trace @"T30"

  // Check if the feed VKH exists and capture the remaining distribution
  expect Some(Pair(required_reward, expected_out_nodes)) =
    remove_reward_entry(in_distribution.nodes_to_rewards, node_id)
  expect required_reward > 0

  // Read and validate reward account output
  expect tx.InlineDatum(datum) = reward_account_output.datum
  expect oracle_datum: OracleDatum = datum
  expect RewardAccount(RewardAccountDatum { nodes_to_rewards, last_update_time }) =
    oracle_datum
  let out_value = reward_account_output.value

  // Calculate actual reward received
  let actual_reward =
    calculate_asset_net_change_with_default(fee_token, out_value, in_value)
  let in_lovelace = assets.lovelace_of(in_value)
  let out_lovelace = assets.lovelace_of(out_value)
  let must_preserve_ada_buffer =
    when fee_token is {
      None -> out_lovelace >= utxo_size_safety_buffer
      Some(_) ->
        out_lovelace == in_lovelace && out_lovelace >= utxo_size_safety_buffer
    }
  // Ensure the required reward matches the actual reward, the node is removed,
  // and the last update timestamp is preserved.
  and {
    must_preserve_ada_buffer,
    nodes_to_rewards == expected_out_nodes,
    required_reward == actual_reward,
    last_update_time == in_distribution.last_update_time,
  }
}

pub fn check_platform_received_reward(
  fee_token: Option<Asset>,
  utxo_size_safety_buffer: Int,
  in_account_datum: RewardAccountDatum,
  in_value: Value,
  reward_account_output: Output,
) -> Bool {
  trace @"T31"

  // Calculate total rewards to be distributed to nodes
  let nodes_rewards =
    list.foldl(
      in_account_datum.nodes_to_rewards,
      0,
      fn(Pair(_, reward), total) { reward + total },
    )

  // Read and validate reward account output
  expect tx.InlineDatum(datum) = reward_account_output.datum
  expect oracle_datum: OracleDatum = datum
  expect RewardAccount(RewardAccountDatum { nodes_to_rewards, last_update_time }) =
    oracle_datum
  expect
    nodes_to_rewards == in_account_datum.nodes_to_rewards && last_update_time == in_account_datum.last_update_time
  let out_value = reward_account_output.value

  let out_total_rewards =
    calculate_asset_quantity_with_default(out_value, fee_token)

  let actual_reward =
    calculate_asset_net_change_with_default(fee_token, out_value, in_value)

  // Check safety buffer requirements
  let must_save_nodes_rewards =
    when fee_token is {
      Some(_) ->
        out_total_rewards >= nodes_rewards && check_utxo_size_safety_buffer(
          utxo_size_safety_buffer,
          out_value,
        )
      None -> out_total_rewards >= nodes_rewards + utxo_size_safety_buffer
    }

  must_save_nodes_rewards && actual_reward > 0
}

pub fn check_nodes_update(
  in_settings: OracleSettingsDatum,
  out_settings: OracleSettingsDatum,
  redeemer: SettingsRedeemer,
) -> Bool {
  trace @"T32"
  let must_perform_redeemer_action = {
    let deleted_nodes = difference_sorted(in_settings.nodes, out_settings.nodes)
    let added_nodes = difference_sorted(out_settings.nodes, in_settings.nodes)
    when redeemer is {
      AddNodes -> deleted_nodes == [] && added_nodes != []
      DelNodes -> deleted_nodes != [] && added_nodes == []
      _ -> False
    }
  }

  must_perform_redeemer_action && {
    let must_not_break_multisig =
      out_settings.required_node_signatures_count <= get_length_and_check_feed_vkh_order(
        out_settings.nodes,
      ) && out_settings.required_node_signatures_count > 0

    must_not_break_multisig && and {
      //  must_keep_other_settings_unchanged
      in_settings.fee_info == out_settings.fee_info,
      in_settings.aggregation_liveness_period == out_settings.aggregation_liveness_period,
      in_settings.time_uncertainty_platform == out_settings.time_uncertainty_platform,
      in_settings.time_uncertainty_aggregation == out_settings.time_uncertainty_aggregation,
      in_settings.iqr_fence_multiplier == out_settings.iqr_fence_multiplier,
      in_settings.median_divergency_factor == out_settings.median_divergency_factor,
      in_settings.utxo_size_safety_buffer == out_settings.utxo_size_safety_buffer,
      in_settings.pause_period_started_at == out_settings.pause_period_started_at,
    }
  }
}

fn difference_sorted(left: Nodes, right: Nodes) -> Nodes {
  when (left, right) is {
    ([], _) -> []
    ([x, ..xs], []) -> [x, ..difference_sorted(xs, [])]
    ([x, ..xs], [y, ..ys]) ->
      if builtin.less_than_bytearray(x, y) {
        [x, ..difference_sorted(xs, [y, ..ys])]
      } else if x == y {
        difference_sorted(xs, ys)
      } else {
        difference_sorted([x, ..xs], ys)
      }
  }
}

fn get_length_and_check_feed_vkh_order(node_ids_sorted: List<FeedVkh>) -> Int {
  when node_ids_sorted is {
    [] -> fail @"E7"
    [x, ..xs] -> do_get_length_and_check_feed_vkh_order(xs, 1, x)
  }
}

fn do_get_length_and_check_feed_vkh_order(
  node_ids_sorted: List<FeedVkh>,
  n: Int,
  prev: FeedVkh,
) -> Int {
  when node_ids_sorted is {
    [] -> n
    [x, ..xs] ->
      if builtin.less_than_bytearray(prev, x) {
        do_get_length_and_check_feed_vkh_order(xs, n + 1, x)
      } else {
        fail @"E6"
      }
  }
}

pub fn validate_dismissing_period(
  last_update_time: PosixTime,
  tx_validity_range: ValidityRange,
  reward_dismissing_period_length: PosixTimeDiff,
) -> Bool {
  trace @"T33"

  interval.is_entirely_after(
    tx_validity_range,
    last_update_time + reward_dismissing_period_length,
  )
}

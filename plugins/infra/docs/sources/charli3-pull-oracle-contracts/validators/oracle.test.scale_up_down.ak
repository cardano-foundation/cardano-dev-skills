use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address
use cardano/assets
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use cardano/transaction as tx
use config
use core/datum.{
  AggState, FeeConfig, GenericData, NftsConfiguration, OracleConfiguration,
  OracleDatum, OracleSettings, OracleSettingsDatum, RewardAccount,
  RewardAccountDatum, RewardPrices,
}
use core/redeemer.{ScaleDown, ScaleToken}
use oracle

const platform_policy_id: assets.PolicyId =
  #"000102030405060708090a0b0c0d0e0f101112131415161718191a1b"

const oracle_policy_id: assets.PolicyId =
  #"1c1d1e1f202122232425262728292a2b2c2d2e2f30313233343536373839"

const platform_script_hash: ScriptHash =
  #"404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c"

const oracle_script_hash: ScriptHash =
  #"5d5e5f606162636465666768696a6b6c6d6e6f70717273747576777879"

const platform_nft_name = #"504c4154464f524d"

const agg_liveness: Int = 3_600_000

const platform_uncertainty: Int = 600_000

const aggregation_uncertainty: Int = 120_000

const pause_period: Int = 86_400_000

const utxo_buffer: Int = 5_000_000

const mock_nodes =
  [
    "node01               FeedVkh", "node02               FeedVkh",
    "node03               FeedVkh",
  ]

const mock_conf =
  OracleConfiguration {
    platform_auth_nft: platform_policy_id,
    pause_period_length: pause_period,
    reward_dismissing_period_length: pause_period,
    fee_token: None,
  }

const mock_settings =
  OracleSettingsDatum {
    nodes: mock_nodes,
    required_node_signatures_count: 2,
    fee_info: FeeConfig {
      rate_nft: None,
      reward_prices: RewardPrices { node_fee: 1_000_000, platform_fee: 500_000 },
    },
    aggregation_liveness_period: agg_liveness,
    time_uncertainty_aggregation: aggregation_uncertainty,
    time_uncertainty_platform: platform_uncertainty,
    iqr_fence_multiplier: 150,
    median_divergency_factor: 10,
    utxo_size_safety_buffer: utxo_buffer,
    pause_period_started_at: None,
  }

const mock_nfts =
  NftsConfiguration {
    utxo_ref: OutputReference {
      transaction_id: #"f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00112233445566778899aabbccddeeff",
      output_index: 0,
    },
    oracle_conf: mock_conf,
    oracle_script_hash,
  }

const platform_nft_output =
  Output {
    address: address.from_script(platform_script_hash),
    value: assets.from_asset(platform_policy_id, platform_nft_name, 1),
    datum: tx.NoDatum,
    reference_script: None,
  }

const platform_nft_input =
  tx.Input {
    output_reference: OutputReference {
      transaction_id: "platform nft",
      output_index: 0,
    },
    output: platform_nft_output,
  }

const core_settings_input =
  tx.Input {
    output_reference: OutputReference {
      transaction_id: "core settings",
      output_index: 0,
    },
    output: tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.from_asset(
        oracle_policy_id,
        config.core_settings_token_name,
        1,
      ),
      datum: tx.InlineDatum(OracleSettings(mock_settings)),
      reference_script: None,
    },
  }

fn mk_reward_output(lovelace: Int) -> Output {
  tx.Output {
    address: address.from_script(oracle_script_hash),
    value: assets.merge(
      assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
      assets.from_lovelace(lovelace),
    ),
    datum: tx.InlineDatum(
      RewardAccount(
        RewardAccountDatum { nodes_to_rewards: [], last_update_time: 0 },
      ),
    ),
    reference_script: None,
  }
}

fn mk_aggstate_output(price_map: List<Pair<Int, Int>>) -> Output {
  tx.Output {
    address: address.from_script(oracle_script_hash),
    value: assets.from_asset(oracle_policy_id, config.aggstate_token_name, 1),
    datum: tx.InlineDatum(AggState(GenericData { price_map })),
    reference_script: None,
  }
}

fn add_token(value, count: Int, name: assets.AssetName) {
  when count is {
    0 -> value
    _ -> assets.add(value, oracle_policy_id, name, count)
  }
}

fn build_mint_value(reward_count: Int, agg_count: Int) {
  let with_rewards =
    add_token(assets.zero, reward_count, config.reward_account_token_name)
  add_token(with_rewards, agg_count, config.aggstate_token_name)
}

fn build_reward_outputs(count: Int) -> List<Output> {
  when count is {
    0 -> []
    _ -> [mk_reward_output(utxo_buffer), ..build_reward_outputs(count - 1)]
  }
}

fn build_agg_outputs(count: Int) -> List<Output> {
  when count is {
    0 -> []
    _ -> [mk_aggstate_output([]), ..build_agg_outputs(count - 1)]
  }
}

fn concat_lists(lhs: List<a>, rhs: List<a>) -> List<a> {
  when lhs is {
    [] -> rhs
    [head, ..tail] -> [head, ..concat_lists(tail, rhs)]
  }
}

fn build_outputs(reward_count: Int, agg_count: Int) -> List<Output> {
  let reward_outputs = build_reward_outputs(reward_count)
  let agg_outputs = build_agg_outputs(agg_count)
  concat_lists([platform_nft_output], concat_lists(reward_outputs, agg_outputs))
}

fn build_scale_token_tx(reward_count: Int, agg_count: Int) -> Transaction {
  let minted_value = build_mint_value(reward_count, agg_count)
  let outputs = build_outputs(reward_count, agg_count)

  Transaction {
    ..tx.placeholder,
    inputs: [platform_nft_input],
    reference_inputs: [core_settings_input],
    outputs,
    mint: minted_value,
  }
}

fn assert_scale_token(reward_count: Int, agg_count: Int) -> Bool {
  let tx = build_scale_token_tx(reward_count, agg_count)
  oracle.oracle_nfts.mint(mock_nfts, ScaleToken, oracle_policy_id, tx)
}

test scale_token_mint_one_reward_one_aggstate_succeeds() {
  assert_scale_token(1, 1)
}

test scale_token_mint_one_reward_succeeds() {
  assert_scale_token(1, 0)
}

test scale_token_mint_one_aggstate_succeeds() {
  assert_scale_token(0, 1)
}

test scale_token_one_reward_three_aggstate_succeeds() {
  assert_scale_token(1, 3)
}

test scale_token_three_reward_one_aggstate_succeeds() {
  assert_scale_token(3, 1)
}

test scale_token_mint_three_aggstate_succeeds() {
  assert_scale_token(0, 3)
}

test scale_token_mint_three_reward_succeeds() {
  assert_scale_token(3, 0)
}

fn burn_inputs(
  count: Int,
  name: assets.AssetName,
  index_offset: Int,
) -> List<(OutputReference, Input)> {
  when count is {
    0 -> []
    _ -> {
      let next_index = index_offset + count
      let ref =
        OutputReference {
          transaction_id: #"f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00112233445566778899aabbccddeeff",
          output_index: next_index,
        }
      let output =
        if name == config.reward_account_token_name {
          mk_reward_output(utxo_buffer)
        } else {
          mk_aggstate_output([])
        }
      let input = tx.Input { output_reference: ref, output }

      [(ref, input), ..burn_inputs(count - 1, name, index_offset)]
    }
  }
}

fn build_burn_value(reward_count: Int, agg_count: Int) {
  let with_rewards =
    add_token(assets.zero, -reward_count, config.reward_account_token_name)
  add_token(with_rewards, -agg_count, config.aggstate_token_name)
}

fn validate_burn_inputs(
  inputs: List<(OutputReference, Input)>,
  datum_value: OracleDatum,
  tx: Transaction,
) -> Bool {
  list.foldl(
    inputs,
    True,
    fn(tuple, acc) {
      let (ref, _input) = tuple
      acc && oracle.oracle_manager.spend(
        mock_conf,
        Some(datum_value),
        ScaleDown,
        ref,
        tx,
      )
    },
  )
}

fn assert_scale_down(reward_count: Int, agg_count: Int) -> Bool {
  let reward_inputs =
    burn_inputs(reward_count, config.reward_account_token_name, 0)
  let agg_inputs =
    burn_inputs(agg_count, config.aggstate_token_name, reward_count)
  let all_inputs = concat_lists(reward_inputs, agg_inputs)

  let references =
    list.map(
      all_inputs,
      fn(tuple) {
        let (ref, _) = tuple
        ref
      },
    )
  let inputs =
    list.map(
      all_inputs,
      fn(tuple) {
        let (_, input) = tuple
        input
      },
    )

  let redeemers =
    list.map(
      references,
      fn(ref) {
        let redeemer_data: Data = ScaleDown
        Pair(tx.Spend(ref), redeemer_data)
      },
    )

  let tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: concat_lists(inputs, [platform_nft_input]),
      outputs: [platform_nft_output],
      redeemers,
      mint: build_burn_value(reward_count, agg_count),
    }

  let reward_datum =
    RewardAccount(
      RewardAccountDatum { nodes_to_rewards: [], last_update_time: 0 },
    )
  let aggstate_datum = AggState(GenericData { price_map: [] })

  let rewards_ok = validate_burn_inputs(reward_inputs, reward_datum, tx)
  let aggstates_ok = validate_burn_inputs(agg_inputs, aggstate_datum, tx)

  let manager_ok = rewards_ok && aggstates_ok

  manager_ok && oracle.oracle_nfts.mint(
    mock_nfts,
    ScaleToken,
    oracle_policy_id,
    tx,
  )
}

test scale_down_burn_one_reward_succeeds() {
  assert_scale_down(1, 0)
}

test scale_down_burn_one_aggstate_succeeds() {
  assert_scale_down(0, 1)
}

test scale_down_burn_one_reward_one_aggstate_succeeds() {
  assert_scale_down(1, 1)
}

test scale_down_burn_three_rewards_succeeds() {
  assert_scale_down(3, 0)
}

test scale_down_burn_three_aggstates_succeeds() {
  assert_scale_down(0, 3)
}

test scale_down_burn_three_rewards_one_aggstate_succeeds() {
  assert_scale_down(3, 1)
}

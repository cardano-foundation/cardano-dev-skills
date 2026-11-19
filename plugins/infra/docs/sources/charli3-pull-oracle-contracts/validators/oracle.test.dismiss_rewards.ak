use aiken/collection/list
use aiken/crypto.{ScriptHash}
use aiken/interval
use cardano/address
use cardano/assets
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use cardano/transaction as tx
use config
use core/datum.{
  FeeConfig, OracleConfiguration, OracleSettings, OracleSettingsDatum,
  RewardAccount, RewardAccountDatum, RewardPrices,
}
use core/redeemer.{DismissRewards}
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

const mock_core_settings_token_value =
  assets.from_asset(oracle_policy_id, config.core_settings_token_name, 1)

const reward_account_token_value =
  assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1)

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
      transaction_id: "platform nft input",
      output_index: 0,
    },
    output: platform_nft_output,
  }

const mock_current_time =
  ( 1732195907000 + 1732195907000 + aggregation_uncertainty ) / 2

fn mk_core_settings_input(tag: ByteArray) -> (OutputReference, Input) {
  let ref = OutputReference { transaction_id: tag, output_index: 0 }
  (
    ref,
    tx.Input {
      output_reference: ref,
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value: mock_core_settings_token_value,
        datum: tx.InlineDatum(OracleSettings(mock_settings)),
        reference_script: None,
      },
    },
  )
}

fn mk_reward_account_input(
  tag: ByteArray,
  rewards: List<Pair<ByteArray, Int>>,
  last_update: Int,
  extra_lovelace: Int,
) -> (OutputReference, RewardAccountDatum, Input) {
  let datum =
    RewardAccountDatum {
      nodes_to_rewards: rewards,
      last_update_time: last_update,
    }
  let value =
    assets.merge(
      reward_account_token_value,
      assets.from_lovelace(
        utxo_buffer + list.foldl(
          rewards,
          0,
          fn(Pair(_, reward), acc) { reward + acc },
        ) + extra_lovelace,
      ),
    )
  let ref = OutputReference { transaction_id: tag, output_index: 0 }
  let input =
    tx.Input {
      output_reference: ref,
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value,
        datum: tx.InlineDatum(RewardAccount(datum)),
        reference_script: None,
      },
    }
  (ref, datum, input)
}

fn mk_empty_reward_output(last_update: Int) -> Output {
  tx.Output {
    address: address.from_script(oracle_script_hash),
    value: assets.merge(
      reward_account_token_value,
      assets.from_lovelace(utxo_buffer),
    ),
    datum: tx.InlineDatum(
      RewardAccount(
        RewardAccountDatum {
          nodes_to_rewards: [],
          last_update_time: last_update,
        },
      ),
    ),
    reference_script: None,
  }
}

fn mk_validity_range(start: Int) -> tx.ValidityRange {
  interval.between(start, start + aggregation_uncertainty)
}

fn dismiss_tx(
  core_input: Input,
  reward_inputs: List<Input>,
  reward_refs: List<OutputReference>,
  reward_outputs: List<Output>,
  validity_start: Int,
) -> Transaction {
  let redeemers =
    list.map(
      reward_refs,
      fn(ref) {
        let dismiss_redeemer: Data = DismissRewards
        Pair(tx.Spend(ref), dismiss_redeemer)
      },
    )
  Transaction {
    ..tx.placeholder,
    reference_inputs: [core_input],
    inputs: list.concat(reward_inputs, [platform_nft_input]),
    outputs: list.concat(reward_outputs, [platform_nft_output]),
    redeemers,
    validity_range: mk_validity_range(validity_start),
  }
}

test dismiss_rewards_single_succeeds() {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))

  let (_, core_input) = mk_core_settings_input("core settings dismiss single")
  let last_update =
    mock_current_time - mock_conf.reward_dismissing_period_length - 1

  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "reward dismiss single",
      [Pair(node_1, 2_000_000), Pair(node_2, 1_000_000)],
      last_update,
      0,
    )
  let reward_output = mk_empty_reward_output(last_update)

  let tx =
    dismiss_tx(
      core_input,
      [reward_input],
      [reward_ref],
      [reward_output],
      last_update + mock_conf.reward_dismissing_period_length + 1,
    )

  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    DismissRewards,
    reward_ref,
    tx,
  )
}

test dismiss_rewards_fails_when_period_not_reached() fail {
  expect Some(node_1) = list.head(mock_nodes)

  let (_, core_input) = mk_core_settings_input("core settings dismiss early")
  let last_update = mock_current_time

  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "reward dismiss early",
      [Pair(node_1, 500_000)],
      last_update,
      0,
    )
  let reward_output = mk_empty_reward_output(last_update)

  let tx =
    dismiss_tx(
      core_input,
      [reward_input],
      [reward_ref],
      [reward_output],
      last_update + mock_conf.reward_dismissing_period_length - 1,
    )

  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    DismissRewards,
    reward_ref,
    tx,
  )
}

test dismiss_rewards_fails_when_output_not_empty() fail {
  expect Some(node_1) = list.head(mock_nodes)

  let (_, core_input) =
    mk_core_settings_input("core settings dismiss non empty")
  let last_update =
    mock_current_time - mock_conf.reward_dismissing_period_length - 10

  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "reward dismiss non empty",
      [Pair(node_1, 700_000)],
      last_update,
      0,
    )
  let non_empty_output =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        reward_account_token_value,
        assets.from_lovelace(utxo_buffer),
      ),
      datum: tx.InlineDatum(
        RewardAccount(
          RewardAccountDatum {
            nodes_to_rewards: [Pair(node_1, 0)],
            last_update_time: last_update,
          },
        ),
      ),
      reference_script: None,
    }

  let tx =
    dismiss_tx(
      core_input,
      [reward_input],
      [reward_ref],
      [non_empty_output],
      last_update + mock_conf.reward_dismissing_period_length + 1,
    )

  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    DismissRewards,
    reward_ref,
    tx,
  )
}

test dismiss_rewards_multiple_accounts_succeeds() {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))
  expect Some(node_3) = list.head(list.drop(mock_nodes, 2))

  let (_, core_input) = mk_core_settings_input("core settings dismiss multi")
  let base_update =
    mock_current_time - mock_conf.reward_dismissing_period_length - 5

  let accounts =
    [
      mk_reward_account_input(
        "reward dismiss multi 1",
        [Pair(node_1, 400_000)],
        base_update,
        0,
      ),
      mk_reward_account_input(
        "reward dismiss multi 2",
        [Pair(node_2, 600_000)],
        base_update - 100,
        0,
      ),
      mk_reward_account_input(
        "reward dismiss multi 3",
        [Pair(node_3, 800_000)],
        base_update - 200,
        0,
      ),
    ]

  let reward_refs =
    list.map(
      accounts,
      fn(tuple) {
        let (ref, _, _) = tuple
        ref
      },
    )
  let reward_inputs =
    list.map(
      accounts,
      fn(tuple) {
        let (_, _, input) = tuple
        input
      },
    )
  let reward_datums =
    list.map(
      accounts,
      fn(tuple) {
        let (_, datum, _) = tuple
        datum
      },
    )
  let reward_outputs =
    list.map(
      reward_datums,
      fn(datum) { mk_empty_reward_output(datum.last_update_time) },
    )

  let tx =
    dismiss_tx(
      core_input,
      reward_inputs,
      reward_refs,
      reward_outputs,
      base_update + mock_conf.reward_dismissing_period_length + 1,
    )

  expect
    list.foldl(
      list.zip(reward_refs, reward_datums),
      True,
      fn(pair, acc) {
        let (ref, datum) = pair
        acc && oracle.oracle_manager.spend(
          mock_conf,
          Some(RewardAccount(datum)),
          DismissRewards,
          ref,
          tx,
        )
      },
    )
}

test dismiss_rewards_multiple_accounts_fail_when_one_invalid() fail {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))
  expect Some(node_3) = list.head(list.drop(mock_nodes, 2))

  let (_, core_input) =
    mk_core_settings_input("core settings dismiss multi fail")
  let mature_update =
    mock_current_time - mock_conf.reward_dismissing_period_length - 5

  let (ref1, datum1, input1) =
    mk_reward_account_input(
      "reward dismiss multi fail 1",
      [Pair(node_1, 400_000)],
      mature_update,
      0,
    )
  let (ref2, datum2, input2) =
    mk_reward_account_input(
      "reward dismiss multi fail 2",
      [Pair(node_2, 600_000)],
      mature_update,
      0,
    )
  let (ref3, datum3, input3) =
    mk_reward_account_input(
      "reward dismiss multi fail 3",
      [Pair(node_3, 800_000)],
      mock_current_time,
      0,
    )

  let outputs =
    [
      mk_empty_reward_output(datum1.last_update_time),
      mk_empty_reward_output(datum2.last_update_time),
      mk_empty_reward_output(datum3.last_update_time),
    ]

  let tx =
    dismiss_tx(
      core_input,
      [input1, input2, input3],
      [ref1, ref2, ref3],
      outputs,
      mock_current_time + 1,
    )

  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(datum3)),
    DismissRewards,
    ref3,
    tx,
  )
}

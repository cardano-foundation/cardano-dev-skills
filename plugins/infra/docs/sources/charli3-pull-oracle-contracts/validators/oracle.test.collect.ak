use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address
use cardano/assets as assets
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use cardano/transaction as tx
use config
use core/datum.{
  FeeConfig, OracleConfiguration, OracleSettings, OracleSettingsDatum,
  RewardAccount, RewardAccountDatum, RewardPrices,
}
use core/redeemer.{NodeCollect, PlatformCollect, RedeemRewards}
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

const pause_period: Int = 86_400_000

const agg_liveness: Int = 3_600_000

const platform_uncertainty: Int = 600_000

const aggregation_uncertainty: Int = 120_000

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

const other_signer = "additional signer     FeedVkh"

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

const mock_core_settings_token_value =
  assets.from_asset(oracle_policy_id, config.core_settings_token_name, 1)

const core_settings_output =
  Output {
    address: address.from_script(oracle_script_hash),
    value: mock_core_settings_token_value,
    datum: tx.InlineDatum(OracleSettings(mock_settings)),
    reference_script: None,
  }

fn mk_core_settings_input(tag: ByteArray) -> (OutputReference, Input) {
  let ref = OutputReference { transaction_id: tag, output_index: 0 }

  (ref, tx.Input { output_reference: ref, output: core_settings_output })
}

fn mk_reward_account_input(
  tx_id: ByteArray,
  rewards: List<Pair<ByteArray, Int>>,
  last_update: Int,
  extra_ada: Int,
) -> (OutputReference, RewardAccountDatum, tx.Input) {
  let datum =
    RewardAccountDatum {
      nodes_to_rewards: rewards,
      last_update_time: last_update,
    }
  let value =
    assets.merge(
      assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
      assets.from_lovelace(
        utxo_buffer + list.foldl(rewards, 0, fn(Pair(_, r), acc) { r + acc }) + extra_ada,
      ),
    )
  let ref = OutputReference { transaction_id: tx_id, output_index: 0 }
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

// Node collector spends the reward account,
// keeps it at output index 0, and pays itself at index 1.
// We supply two signatories so find_node_by_signature recognises the first node.
test redeem_rewards_node_single_utxo_succeeds() {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))

  let (_, core_settings_input) =
    mk_core_settings_input("core settings for single collect")

  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "node single collect",
      [Pair(node_1, 2_000_000), Pair(node_2, 1_500_000)],
      123,
      platform_fee,
    )
  let reward_after =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_2, 1_500_000)],
      last_update_time: reward_before.last_update_time,
    }
  let reward_output_after =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 1_500_000 + platform_fee),
      ),
      datum: tx.InlineDatum(RewardAccount(reward_after)),
      reference_script: None,
    }
  let node_payout_output =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(2_000_000),
      datum: tx.NoDatum,
      reference_script: None,
    }

  let redeemer =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 0 }
  let redeemer_data: Data = redeemer
  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input],
      outputs: [reward_output_after, node_payout_output],
      redeemers: [Pair(tx.Spend(reward_ref), redeemer_data)],
      extra_signatories: [node_1, other_signer],
    }

  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    redeemer,
    reward_ref,
    spend_tx,
  )
}

// Platform collect returns the NFT to the platform output
// and takes its fee from the reward account.
test redeem_rewards_platform_collect_succeeds() {
  expect Some(node_1) = list.head(mock_nodes)
  let (_, core_settings_input) =
    mk_core_settings_input("core settings for platform collect")

  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "platform collect",
      [Pair(node_1, 3_500_000)],
      321,
      platform_fee,
    )
  let reward_output_after =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 3_500_000),
      ),
      // Node operators rewards are constant
      datum: tx.InlineDatum(RewardAccount(reward_before)),
      reference_script: None,
    }
  let platform_payout_output =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(platform_fee),
      datum: tx.NoDatum,
      reference_script: None,
    }

  let redeemer =
    RedeemRewards { collector: PlatformCollect, corresponding_out_ix: 0 }
  let redeemer_data: Data = redeemer
  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input, platform_nft_input],
      outputs: [
        reward_output_after, platform_nft_output, platform_payout_output,
      ],
      redeemers: [Pair(tx.Spend(reward_ref), redeemer_data)],
      extra_signatories: [],
    }

  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    redeemer,
    reward_ref,
    spend_tx,
  )
}

test redeem_rewards_platform_collect_fails() fail {
  expect Some(node_1) = list.head(mock_nodes)
  let (_, core_settings_input) =
    mk_core_settings_input("core settings for platform collect")

  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "platform collect",
      [Pair(node_1, 3_500_000)],
      321,
      platform_fee,
    )
  let reward_output_after =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 2_500_000),
      ),
      // Incorrect node rewards a amount 
      datum: tx.InlineDatum(RewardAccount(reward_before)),
      reference_script: None,
    }
  let platform_payout_output =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(platform_fee),
      datum: tx.NoDatum,
      reference_script: None,
    }

  let redeemer =
    RedeemRewards { collector: PlatformCollect, corresponding_out_ix: 0 }
  let redeemer_data: Data = redeemer
  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input, platform_nft_input],
      outputs: [
        reward_output_after, platform_nft_output, platform_payout_output,
      ],
      redeemers: [Pair(tx.Spend(reward_ref), redeemer_data)],
      extra_signatories: [],
    }

  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    redeemer,
    reward_ref,
    spend_tx,
  )
}

test redeem_rewards_node_multiple_utxos_succeeds() {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))

  let (_, core_settings_input) =
    mk_core_settings_input("core settings for multi collect")

  let (reward_ref1, reward_before1, reward_input1) =
    mk_reward_account_input(
      "node collect 1",
      [Pair(node_1, 1_200_000), Pair(node_2, 850_000)],
      123,
      0,
    )
  let reward_after1 =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_2, 850_000)],
      last_update_time: reward_before1.last_update_time,
    }
  let reward_output_after1 =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 850_000),
      ),
      datum: tx.InlineDatum(RewardAccount(reward_after1)),
      reference_script: None,
    }

  let (reward_ref2, reward_before2, reward_input2) =
    mk_reward_account_input(
      "node collect 2",
      [Pair(node_1, 1_500_000), Pair(node_2, 750_000)],
      124,
      0,
    )
  let reward_after2 =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_2, 750_000)],
      last_update_time: reward_before2.last_update_time,
    }
  let reward_output_after2 =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 750_000),
      ),
      datum: tx.InlineDatum(RewardAccount(reward_after2)),
      reference_script: None,
    }

  let (reward_ref3, reward_before3, reward_input3) =
    mk_reward_account_input(
      "node collect 3",
      [Pair(node_1, 3_000_000), Pair(node_2, 1_500_000)],
      125,
      0,
    )
  let reward_after3 =
    RewardAccountDatum {
      nodes_to_rewards: [Pair(node_2, 1_500_000)],
      last_update_time: reward_before3.last_update_time,
    }
  let reward_output_after3 =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 1_500_000),
      ),
      datum: tx.InlineDatum(RewardAccount(reward_after3)),
      reference_script: None,
    }

  let node_total_payout =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(1_200_000 + 1_500_000 + 3_000_000),
      datum: tx.NoDatum,
      reference_script: None,
    }

  let redeemer1 =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 0 }
  let redeemer2 =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 1 }
  let redeemer3 =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 2 }
  let redeemer_data1: Data = redeemer1
  let redeemer_data2: Data = redeemer2
  let redeemer_data3: Data = redeemer3

  // Reward-account outputs occupy indices 0-2; the node payout lives at index 3.
  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input1, reward_input2, reward_input3],
      outputs: [
        reward_output_after1, reward_output_after2, reward_output_after3,
        node_total_payout,
      ],
      redeemers: [
        Pair(tx.Spend(reward_ref1), redeemer_data1),
        Pair(tx.Spend(reward_ref2), redeemer_data2),
        Pair(tx.Spend(reward_ref3), redeemer_data3),
      ],
      extra_signatories: [node_1, other_signer],
    }

  let first_utxo =
    oracle.oracle_manager.spend(
      mock_conf,
      Some(RewardAccount(reward_before1)),
      redeemer1,
      reward_ref1,
      spend_tx,
    )
  let second_utxo =
    oracle.oracle_manager.spend(
      mock_conf,
      Some(RewardAccount(reward_before2)),
      redeemer2,
      reward_ref2,
      spend_tx,
    )
  let third_utxo =
    oracle.oracle_manager.spend(
      mock_conf,
      Some(RewardAccount(reward_before3)),
      redeemer3,
      reward_ref3,
      spend_tx,
    )
  first_utxo && second_utxo && third_utxo
}

test redeem_rewards_node_incorrect_index_fails() fail {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))

  let (_, core_settings_input) =
    mk_core_settings_input("core settings for failing collect")
  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "node collect wrong index",
      [Pair(node_1, 2_000_000), Pair(node_2, 1_500_000)],
      200,
      0,
    )
  let reward_output_after =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 1_500_000),
      ),
      datum: tx.InlineDatum(
        RewardAccount(
          RewardAccountDatum {
            nodes_to_rewards: [Pair(node_2, 1_500_000)],
            last_update_time: reward_before.last_update_time,
          },
        ),
      ),
      reference_script: None,
    }
  let node_payout_output =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(2_000_000),
      datum: tx.NoDatum,
      reference_script: None,
    }
  let redeemer =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 1 }
  let redeemer_data: Data = redeemer

  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input],
      outputs: [reward_output_after, node_payout_output],
      redeemers: [Pair(tx.Spend(reward_ref), redeemer_data)],
      extra_signatories: [node_1, other_signer],
    }

  // Fails because index 1 points at the payout output;
  // check_node_received_reward expects a reward account datum there.
  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    redeemer,
    reward_ref,
    spend_tx,
  )
}

test redeem_rewards_node_retains_entry_fails() fail {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))

  let (_, core_settings_input) =
    mk_core_settings_input("core settings for retained entry")
  let (reward_ref, reward_before, reward_input) =
    mk_reward_account_input(
      "node retain entry",
      [Pair(node_1, 1_000_000), Pair(node_2, 750_000)],
      500,
      0,
    )
  let reward_output_after =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer),
      ),
      datum: tx.InlineDatum(
        RewardAccount(
          RewardAccountDatum {
            nodes_to_rewards: [Pair(node_1, 1_000_000), Pair(node_2, 750_000)],
            last_update_time: reward_before.last_update_time,
          },
        ),
      ),
      reference_script: None,
    }
  let node_payout_output =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(1_000_000),
      datum: tx.NoDatum,
      reference_script: None,
    }
  let redeemer =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 0 }
  let redeemer_data: Data = redeemer
  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input],
      outputs: [reward_output_after, node_payout_output],
      redeemers: [Pair(tx.Spend(reward_ref), redeemer_data)],
      extra_signatories: [node_1, other_signer],
    }

  // Fails because the node remains in the reward account output,
  // so check_node_received_reward detects unchanged distribution.
  oracle.oracle_manager.spend(
    mock_conf,
    Some(RewardAccount(reward_before)),
    redeemer,
    reward_ref,
    spend_tx,
  )
}

test redeem_rewards_node_missing_entry_second_utxo_fails() fail {
  expect Some(node_1) = list.head(mock_nodes)
  expect Some(node_2) = list.head(list.drop(mock_nodes, 1))

  let (_, core_settings_input) =
    mk_core_settings_input("core settings for missing entry")

  let (reward_ref1, reward_before1, reward_input1) =
    mk_reward_account_input(
      "node collect present",
      [Pair(node_1, 800_000), Pair(node_2, 600_000)],
      600,
      0,
    )
  let reward_output_after1 =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 600_000),
      ),
      datum: tx.InlineDatum(
        RewardAccount(
          RewardAccountDatum {
            nodes_to_rewards: [Pair(node_2, 600_000)],
            last_update_time: reward_before1.last_update_time,
          },
        ),
      ),
      reference_script: None,
    }

  let (reward_ref2, reward_before2, reward_input2) =
    mk_reward_account_input(
      "node collect absent",
      [Pair(node_2, 400_000)],
      601,
      0,
    )
  let reward_output_after2 =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 400_000),
      ),
      datum: tx.InlineDatum(RewardAccount(reward_before2)),
      reference_script: None,
    }

  let node_total_payout =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(800_000),
      datum: tx.NoDatum,
      reference_script: None,
    }

  let redeemer1 =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 0 }
  let redeemer2 =
    RedeemRewards { collector: NodeCollect, corresponding_out_ix: 1 }
  let redeemer_data1: Data = redeemer1
  let redeemer_data2: Data = redeemer2

  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input1, reward_input2],
      outputs: [reward_output_after1, reward_output_after2, node_total_payout],
      redeemers: [
        Pair(tx.Spend(reward_ref1), redeemer_data1),
        Pair(tx.Spend(reward_ref2), redeemer_data2),
      ],
      extra_signatories: [node_1, other_signer],
    }

  // Fails because the second reward account never contained the node's key,
  // so find_node_by_signature/check_node_received_reward aborts.
  let first_utxo =
    oracle.oracle_manager.spend(
      mock_conf,
      Some(RewardAccount(reward_before1)),
      redeemer1,
      reward_ref1,
      spend_tx,
    )
  let second_utxo =
    oracle.oracle_manager.spend(
      mock_conf,
      Some(RewardAccount(reward_before2)),
      redeemer2,
      reward_ref2,
      spend_tx,
    )
  first_utxo && second_utxo
}

test redeem_rewards_platform_multiple_utxos_succeeds() {
  let (_, core_settings_input) =
    mk_core_settings_input("core settings for platform multi")

  let (reward_ref1, reward_before1, reward_input1) =
    mk_reward_account_input(
      "platform collect one",
      [Pair("Platform Operator", 1_000_000)],
      400,
      300_000,
    )
  let reward_output_after1 =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 1_000_000),
      ),
      datum: tx.InlineDatum(RewardAccount(reward_before1)),
      reference_script: None,
    }

  let (reward_ref2, reward_before2, reward_input2) =
    mk_reward_account_input(
      "platform collect two",
      [Pair("Platform Operator", 2_000_000)],
      401,
      350_000,
    )
  let reward_output_after2 =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: assets.merge(
        assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
        assets.from_lovelace(utxo_buffer + 2_000_000),
      ),
      datum: tx.InlineDatum(RewardAccount(reward_before2)),
      reference_script: None,
    }

  let combined_platform_fee =
    tx.Output {
      address: address.from_script(platform_script_hash),
      value: assets.from_lovelace(300_000 + 350_000),
      datum: tx.NoDatum,
      reference_script: None,
    }

  let redeemer1 =
    RedeemRewards { collector: PlatformCollect, corresponding_out_ix: 0 }
  let redeemer2 =
    RedeemRewards { collector: PlatformCollect, corresponding_out_ix: 1 }
  let redeemer_data1: Data = redeemer1
  let redeemer_data2: Data = redeemer2

  // Both redeemers point to their reward-account outputs (indices 0 and 1)
  // while the combined fee lands at index 3.
  let spend_tx =
    Transaction {
      ..tx.placeholder,
      reference_inputs: [core_settings_input],
      inputs: [reward_input1, reward_input2, platform_nft_input],
      outputs: [
        reward_output_after1, reward_output_after2, platform_nft_output,
        combined_platform_fee,
      ],
      redeemers: [
        Pair(tx.Spend(reward_ref1), redeemer_data1),
        Pair(tx.Spend(reward_ref2), redeemer_data2),
      ],
      extra_signatories: [],
    }

  let first_utxo =
    oracle.oracle_manager.spend(
      mock_conf,
      Some(RewardAccount(reward_before1)),
      redeemer1,
      reward_ref1,
      spend_tx,
    )
  let second_utxo =
    oracle.oracle_manager.spend(
      mock_conf,
      Some(RewardAccount(reward_before2)),
      redeemer2,
      reward_ref2,
      spend_tx,
    )
  first_utxo && second_utxo
}

use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash}
use aiken/interval
use cardano/address
use cardano/assets.{AssetName, PolicyId} as assets
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use cardano/transaction as tx
use config
use core/checks.{
  find_out_datum_and_value, returns_empty_account_outputs,
  returns_empty_aggstate_outputs, validate_settings_form,
}
use core/datum.{
  AggState, FeeConfig, GenericData, NftsConfiguration, OracleConfiguration,
  OracleSettings, OracleSettingsDatum, RewardAccount, RewardAccountDatum,
  RewardPrices,
}
use core/redeemer.{
  AddNodes, BurnToken, DelNodes, ManageSettings, MintToken, PauseOracle,
  RemoveOracle, ResumeOracle, UpdateSettings,
}
use ext/cardano/value.{Asset}
use oracle
use services/nft_based_auth.{auth_by_nft}

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

// node VerificationKeyHash = Hash<Blake2b_224, VerificationKey>
// blake2b-224 hash digest is 28 bytes long
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

const mock_nfts =
  NftsConfiguration {
    utxo_ref: OutputReference {
      transaction_id: #"f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00112233445566778899aabbccddeeff",
      output_index: 0,
    },
    oracle_conf: mock_conf_with_token,
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
      transaction_id: "some platform tx",
      output_index: 0,
    },
    output: platform_nft_output,
  }

const reward_account_output =
  Output {
    address: address.from_script(oracle_script_hash),
    value: assets.merge(
      assets.from_asset(oracle_policy_id, config.reward_account_token_name, 1),
      assets.from_lovelace(utxo_buffer),
    ),
    datum: tx.InlineDatum(
      RewardAccount(
        RewardAccountDatum { nodes_to_rewards: [], last_update_time: 0 },
      ),
    ),
    reference_script: None,
  }

const aggstate_output =
  Output {
    address: address.from_script(oracle_script_hash),
    value: assets.from_asset(oracle_policy_id, config.aggstate_token_name, 1),
    datum: tx.InlineDatum(AggState(GenericData { price_map: [] })),
    reference_script: None,
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

const minted_value =
  assets.zero
    |> assets.add(oracle_policy_id, config.core_settings_token_name, 1)
    |> assets.add(oracle_policy_id, config.reward_account_token_name, 1)
    |> assets.add(oracle_policy_id, config.aggstate_token_name, 1)

const mock_precise_tx_validity_interval =
  interval.between(1732195907000, 1732195907000 + aggregation_uncertainty)

const mock_current_time =
  ( 1732195907000 + 1732195907000 + aggregation_uncertainty ) / 2

test successful_oracle_start() {
  let minted_assets = minted_value |> assets.tokens(oracle_policy_id)

  expect Some(1) = dict.get(minted_assets, config.core_settings_token_name)
  expect Some(1) = dict.get(minted_assets, config.reward_account_token_name)
  expect Some(1) = dict.get(minted_assets, config.aggstate_token_name)

  expect validate_settings_form(mock_conf, mock_settings)

  let reward_account_nft =
    Asset {
      policy_id: oracle_policy_id,
      name: config.reward_account_token_name,
    }
  let aggstate_nft =
    Asset { policy_id: oracle_policy_id, name: config.aggstate_token_name }
  let core_nft =
    Asset { policy_id: oracle_policy_id, name: config.core_settings_token_name }

  let oracle_outputs =
    [
      platform_nft_output, core_settings_output, reward_account_output,
      aggstate_output,
    ]

  expect
    returns_empty_account_outputs(
      oracle_script_hash,
      reward_account_nft,
      1,
      oracle_outputs,
      utxo_buffer,
    )

  expect
    returns_empty_aggstate_outputs(
      oracle_script_hash,
      aggstate_nft,
      1,
      oracle_outputs,
    )

  expect [(OracleSettings(_), _)] =
    find_out_datum_and_value(oracle_outputs, oracle_script_hash, core_nft)

  let platform_input =
    Input { output_reference: mock_nfts.utxo_ref, output: platform_nft_output }

  expect
    auth_by_nft(mock_conf.platform_auth_nft, [platform_input], oracle_outputs)

  let start_tx =
    Transaction {
      ..tx.placeholder,
      inputs: [platform_input],
      outputs: oracle_outputs,
      mint: minted_value,
    }

  expect
    oracle.oracle_nfts.mint(mock_nfts, MintToken, oracle_policy_id, start_tx)
}

test successful_update_settings() {
  let core_settings_ref =
    OutputReference {
      transaction_id: "core settings before update settings tx",
      output_index: 0,
    }
  let core_settings_input =
    tx.Input {
      output_reference: core_settings_ref,
      output: core_settings_output,
    }
  let core_settings_after =
    OracleSettingsDatum {
      ..mock_settings,
      required_node_signatures_count: 17,
      aggregation_liveness_period: 3_000_000,
      iqr_fence_multiplier: 170,
      fee_info: FeeConfig {
        rate_nft: Some(mock_rate_nft),
        reward_prices: RewardPrices {
          node_fee: node_fee / 10,
          platform_fee: platform_fee / 10,
        },
      },
    }
  let core_settings_output =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: mock_core_settings_token_value,
      datum: tx.InlineDatum(OracleSettings(core_settings_after)),
      reference_script: None,
    }

  let update_settings_redeemer: Data = ManageSettings(UpdateSettings)
  let update_settings_tx =
    Transaction {
      ..tx.placeholder,
      inputs: [core_settings_input, platform_nft_input],
      redeemers: [Pair(tx.Spend(core_settings_ref), update_settings_redeemer)],
      outputs: [core_settings_output, platform_nft_output],
    }
  oracle.oracle_manager.spend(
    mock_conf_with_token,
    Some(OracleSettings(mock_settings)),
    ManageSettings(UpdateSettings),
    core_settings_ref,
    update_settings_tx,
  )
}

test successful_add_nodes() {
  let core_settings_ref =
    OutputReference {
      transaction_id: "core settings before add nodes tx",
      output_index: 0,
    }
  let core_settings_input =
    tx.Input {
      output_reference: core_settings_ref,
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value: mock_core_settings_token_value,
        datum: tx.InlineDatum(OracleSettings(mock_settings)),
        reference_script: None,
      },
    }
  let core_settings_after =
    OracleSettingsDatum {
      ..mock_settings,
      nodes: [
        "node00               FeedVkh",
        ..list.concat(
          mock_nodes,
          ["node22               FeedVkh", "node23               FeedVkh"],
        )
      ],
      required_node_signatures_count: 19,
    }
  let core_settings_output =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: mock_core_settings_token_value,
      datum: tx.InlineDatum(OracleSettings(core_settings_after)),
      reference_script: None,
    }

  let add_nodes_redeemer: Data = ManageSettings(AddNodes)
  let add_nodes_tx =
    Transaction {
      ..tx.placeholder,
      inputs: [core_settings_input, platform_nft_input],
      redeemers: [Pair(tx.Spend(core_settings_ref), add_nodes_redeemer)],
      outputs: [core_settings_output, platform_nft_output],
    }

  oracle.oracle_manager.spend(
    mock_conf_with_token,
    Some(OracleSettings(mock_settings)),
    ManageSettings(AddNodes),
    core_settings_ref,
    add_nodes_tx,
  )
}

test successful_del_nodes() {
  let core_settings_ref =
    OutputReference {
      transaction_id: "core settings before del nodes tx",
      output_index: 0,
    }
  let core_settings_input =
    tx.Input {
      output_reference: core_settings_ref,
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value: mock_core_settings_token_value,
        datum: tx.InlineDatum(OracleSettings(mock_settings)),
        reference_script: None,
      },
    }
  let core_settings_after =
    OracleSettingsDatum {
      ..mock_settings,
      nodes: list.delete(mock_nodes, "node16               FeedVkh"),
      required_node_signatures_count: 15,
    }
  let core_settings_output =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: mock_core_settings_token_value,
      datum: tx.InlineDatum(OracleSettings(core_settings_after)),
      reference_script: None,
    }

  let del_nodes_redeemer: Data = ManageSettings(DelNodes)
  let del_nodes_tx =
    Transaction {
      ..tx.placeholder,
      inputs: [core_settings_input, platform_nft_input],
      redeemers: [Pair(tx.Spend(core_settings_ref), del_nodes_redeemer)],
      outputs: [core_settings_output, platform_nft_output],
    }

  oracle.oracle_manager.spend(
    mock_conf_with_token,
    Some(OracleSettings(mock_settings)),
    ManageSettings(DelNodes),
    core_settings_ref,
    del_nodes_tx,
  )
}

test successful_oracle_pause() {
  let core_settings_ref =
    OutputReference {
      transaction_id: "core settings before oracle pause tx",
      output_index: 0,
    }
  let core_settings_input =
    tx.Input {
      output_reference: core_settings_ref,
      output: core_settings_output,
    }
  let core_settings_after =
    OracleSettingsDatum {
      ..mock_settings,
      pause_period_started_at: Some(mock_current_time),
    }
  let produced_core_settings_output =
    tx.Output {
      address: address.from_script(oracle_script_hash),
      value: mock_core_settings_token_value,
      datum: tx.InlineDatum(OracleSettings(core_settings_after)),
      reference_script: None,
    }

  let oracle_pause_redeemer: Data = ManageSettings(PauseOracle)
  let oracle_pause_tx =
    Transaction {
      ..tx.placeholder,
      inputs: [core_settings_input, platform_nft_input],
      redeemers: [Pair(tx.Spend(core_settings_ref), oracle_pause_redeemer)],
      outputs: [produced_core_settings_output, platform_nft_output],
      validity_range: mock_precise_tx_validity_interval,
    }
  oracle.oracle_manager.spend(
    mock_conf_with_token,
    Some(OracleSettings(mock_settings)),
    ManageSettings(PauseOracle),
    core_settings_ref,
    oracle_pause_tx,
  )
}

test successful_resume_oracle() {
  let core_settings_ref =
    OutputReference {
      transaction_id: "core settings before resume oracle tx",
      output_index: 0,
    }
  let core_settings_before =
    OracleSettingsDatum {
      ..mock_settings,
      pause_period_started_at: Some(mock_current_time),
    }
  let core_settings_input =
    tx.Input {
      output_reference: core_settings_ref,
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value: mock_core_settings_token_value,
        datum: tx.InlineDatum(OracleSettings(core_settings_before)),
        reference_script: None,
      },
    }

  let resume_oracle_redeemer: Data = ManageSettings(ResumeOracle)
  let resume_oracle_tx =
    Transaction {
      ..tx.placeholder,
      inputs: [core_settings_input, platform_nft_input],
      redeemers: [Pair(tx.Spend(core_settings_ref), resume_oracle_redeemer)],
      outputs: [core_settings_output, platform_nft_output],
    }
  oracle.oracle_manager.spend(
    mock_conf_with_token,
    Some(OracleSettings(core_settings_before)),
    ManageSettings(ResumeOracle),
    core_settings_ref,
    resume_oracle_tx,
  )
}

test successful_remove_oracle() {
  let remove_oracle_redeemer: Data = ManageSettings(RemoveOracle)
  let burned_tokens_value =
    assets.from_asset_list(
      [Pair(oracle_policy_id, [Pair(config.core_settings_token_name, -1)])],
    )

  let core_settings_ref =
    OutputReference {
      transaction_id: "core settings before remove oracle tx",
      output_index: 0,
    }
  let core_settings =
    OracleSettingsDatum {
      ..mock_settings,
      pause_period_started_at: Some(mock_current_time),
    }
  let core_settings_input =
    tx.Input {
      output_reference: core_settings_ref,
      output: tx.Output {
        address: address.from_script(oracle_script_hash),
        value: mock_core_settings_token_value,
        datum: tx.InlineDatum(OracleSettings(core_settings)),
        reference_script: None,
      },
    }

  let remove_oracle_tx =
    Transaction {
      ..tx.placeholder,
      inputs: [core_settings_input, platform_nft_input],
      redeemers: [Pair(tx.Spend(core_settings_ref), remove_oracle_redeemer)],
      outputs: [platform_nft_output],
      mint: burned_tokens_value,
      validity_range: interval.after(mock_current_time + 2 * pause_period),
    }
  oracle.oracle_nfts.mint(
    mock_nfts,
    BurnToken,
    oracle_policy_id,
    remove_oracle_tx,
  ) && oracle.oracle_manager.spend(
    mock_conf_with_token,
    Some(OracleSettings(core_settings)),
    ManageSettings(RemoveOracle),
    core_settings_ref,
    remove_oracle_tx,
  )
}

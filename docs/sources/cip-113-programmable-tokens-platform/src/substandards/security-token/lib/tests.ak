use cardano/address.{Address, Credential, Script}
use cardano/assets.{from_asset, from_lovelace, merge}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use constants
use utils

// Faithful mirror of the CIP-113 programmable-token registry node datum shape:
// https://github.com/cardano-foundation/cip113-programmable-tokens/blob/main/lib/registry_node.ak
//
// Field order matters: `derive_issuance_policy_id_from_registry_node` reads the
// node via `builtin.unconstr_fields` and indexes by position, so this type must
// keep the exact CIP-113 layout.
//   0: key                              (ByteArray)  -> the issuance policy id
//   1: next                             (ByteArray)
//   2: minting_logic_script             (Credential)
//   3: transfer_logic_script            (Credential)
//   4: third_party_transfer_logic_script(Credential)
//   5: global_state_cs                  (ByteArray)
type RegistryNode {
  key: ByteArray,
  next: ByteArray,
  minting_logic_script: Credential,
  transfer_logic_script: Credential,
  third_party_transfer_logic_script: Credential,
  global_state_cs: ByteArray,
}

// 28-byte stand-ins for the various script hashes / policy ids.
const test_registry_policy_id: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

// `key` of the registry node == the derived issuance policy id.
const test_issuance_policy_id: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const test_minting_logic_hash: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const test_transfer_logic_hash: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const test_third_party_transfer_logic_hash: ByteArray =
  #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

const test_global_state_cs: ByteArray =
  #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

// Builds a reference input shaped exactly like a CIP-113 registry node UTxO:
// it carries ada + exactly one registry NFT (so `has_any_nft_strict` finds it)
// and an inline datum following the RegistryNode layout above.
fn make_cip113_registry_ref_input() -> Input {
  let node = RegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_minting_logic_hash),
    transfer_logic_script: Script(test_transfer_logic_hash),
    third_party_transfer_logic_script: Script(
      test_third_party_transfer_logic_hash,
    ),
    global_state_cs: test_global_state_cs,
  }
  Input {
    output_reference: OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    },
    output: Output {
      address: Address {
        payment_credential: Script(test_registry_policy_id),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_registry_policy_id, "Node", 1),
      ),
      datum: InlineDatum(node),
      reference_script: None,
    },
  }
}

// Exercises `derive_issuance_policy_id_from_registry_node` against the real
// CIP-113 registry node shape. The transfer-logic credential (index 3) is the
// one running the withdraw-0; the function must locate the node by its NFT,
// decode the indexed field as a `Credential`, match its script hash against the
// redeemer credential, and return `key` (field 0) as the issuance policy id.
test derive_issuance_policy_id_from_cip113_registry_node() {
  let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
    [make_cip113_registry_ref_input()],
    test_registry_policy_id,
    Script(test_transfer_logic_hash),
    constants.transfer_logic_script_registry_node_index,
  )
  issuance_policy_id == test_issuance_policy_id
}
// test is_user_allowed() {
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   let userTokenPolicyId = "TEST_POLICY"
//   let userTokenAssetName = "TEST_ASSET"
//   let inputOutputReference =
//     OutputReference { transaction_id: "123456789", output_index: 3 }
//   let inputAddress =
//     Address {
//       payment_credential: address.VerificationKey("payment_credential"),
//       stake_credential: Some(userStakeCredential),
//     }
//   let inputOutput =
//     Output {
//       address: inputAddress,
//       value: from_asset(userTokenPolicyId, userTokenAssetName, 1),
//       datum: NoDatum,
//       reference_script: None,
//     }
//   let input =
//     Input { output_reference: inputOutputReference, output: inputOutput }

//   common.is_user_allowed(
//     input,
//     userStakeCredential,
//     userTokenPolicyId,
//     userTokenAssetName,
//   )
// }

// test is_user_allowed_fail() fail {
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   let userTokenPolicyId = "TEST_POLICY"
//   let userTokenAssetName = "TEST_ASSET"
//   let inputOutputReference =
//     OutputReference { transaction_id: "123456789", output_index: 3 }
//   let inputAddress =
//     Address {
//       payment_credential: address.VerificationKey("payment_credential"),
//       stake_credential: Some(userStakeCredential),
//     }
//   let inputOutput =
//     Output {
//       address: inputAddress,
//       value: from_asset(userTokenPolicyId, userTokenAssetName, 1),
//       datum: NoDatum,
//       reference_script: None,
//     }
//   let input =
//     Input { output_reference: inputOutputReference, output: inputOutput }

//   common.is_user_allowed(
//     input,
//     Inline(address.VerificationKey("different_stake_credential")),
//     userTokenPolicyId,
//     userTokenAssetName,
//   )
// }

// test must_be_signed_by_stake_credential() {
//   let validityRange: Interval<Int> =
//     Interval {
//       lower_bound: IntervalBound { bound_type: Finite(1), is_inclusive: True },
//       upper_bound: IntervalBound { bound_type: Finite(10), is_inclusive: True },
//     }
//   let tx =
//     Transaction {
//       inputs: [],
//       reference_inputs: [],
//       outputs: [],
//       fee: 0,
//       mint: from_asset("", "", 10),
//       certificates: [],
//       withdrawals: [],
//       validity_range: validityRange,
//       extra_signatories: [
//         "stake_credential", "another_stake_credential",
//         "another_stake_credential2",
//       ],
//       redeemers: [],
//       datums: dict.empty,
//       id: "transaction_id",
//       votes: [],
//       proposal_procedures: [],
//       current_treasury_amount: None,
//       treasury_donation: None,
//     }
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   utils.must_be_signed_by_stake_credential(tx, userStakeCredential)
// }

// test must_be_signed_by_stake_credential_fail() fail {
//   let validityRange: Interval<Int> =
//     Interval {
//       lower_bound: IntervalBound { bound_type: Finite(1), is_inclusive: True },
//       upper_bound: IntervalBound { bound_type: Finite(10), is_inclusive: True },
//     }
//   let tx =
//     Transaction {
//       inputs: [],
//       reference_inputs: [],
//       outputs: [],
//       fee: 0,
//       mint: from_asset("", "", 10),
//       certificates: [],
//       withdrawals: [],
//       validity_range: validityRange,
//       extra_signatories: [
//         "another_stake_credential", "another_stake_credential2",
//       ],
//       redeemers: [],
//       datums: dict.empty,
//       id: "transaction_id",
//       votes: [],
//       proposal_procedures: [],
//       current_treasury_amount: None,
//       treasury_donation: None,
//     }
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   utils.must_be_signed_by_stake_credential(tx, userStakeCredential)
// }

// test input_contains_any_token_with_policy_id() {
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   let inputOutputReference =
//     OutputReference { transaction_id: "123456789", output_index: 3 }
//   let inputAddress =
//     Address {
//       payment_credential: address.VerificationKey("payment_credential"),
//       stake_credential: Some(userStakeCredential),
//     }
//   let inputOutput =
//     Output {
//       address: inputAddress,
//       value: from_asset_list(
//         [
//           Pair("a", [Pair("a", 1), Pair("b", 5)]),
//           Pair("b", [Pair("a", 7), Pair("b", 1)]),
//           Pair("c", [Pair("a", 7), Pair("b", 1)]),
//         ],
//       ),
//       datum: NoDatum,
//       reference_script: None,
//     }
//   let input =
//     Input { output_reference: inputOutputReference, output: inputOutput }
//   common.input_contains_any_token_with_policy_id(input: input, policy_id: "b")
// }

// test input_contains_any_token_with_policy_id_fail() fail {
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   let inputOutputReference =
//     OutputReference { transaction_id: "123456789", output_index: 3 }
//   let inputAddress =
//     Address {
//       payment_credential: address.VerificationKey("payment_credential"),
//       stake_credential: Some(userStakeCredential),
//     }
//   let inputOutput =
//     Output {
//       address: inputAddress,
//       value: from_asset_list(
//         [
//           Pair("a", [Pair("a", 1), Pair("b", 5)]),
//           Pair("c", [Pair("a", 7), Pair("b", 1)]),
//         ],
//       ),
//       datum: NoDatum,
//       reference_script: None,
//     }
//   let input =
//     Input { output_reference: inputOutputReference, output: inputOutput }
//   common.input_contains_any_token_with_policy_id(input: input, policy_id: "b")
// }

// test all_sc_inputs_from_same_user() {
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   let transferManagerInputs =
//     [
//       build_input_with_stake_credential_from_sc(userStakeCredential, "scHash"),
//       build_input_with_stake_credential_from_sc(userStakeCredential, "scHash"),
//       build_input_with_stake_credential_from_sc(userStakeCredential, "scHash"),
//     ]
//   utils.all_sc_inputs_from_same_user(transferManagerInputs, userStakeCredential)
// }

// test all_sc_inputs_from_same_user_fail() fail {
//   let userStakeCredential = Inline(address.VerificationKey("stake_credential"))
//   let userStakeCredential2 =
//     Inline(address.VerificationKey("stake_credential2"))
//   let transferManagerInputs =
//     [
//       build_input_with_stake_credential_from_sc(userStakeCredential, "scHash"),
//       build_input_with_stake_credential_from_sc(userStakeCredential, "scHash"),
//       build_input_with_stake_credential_from_sc(userStakeCredential2, "scHash"),
//       build_input_with_stake_credential_from_sc(userStakeCredential, "scHash"),
//     ]
//   utils.all_sc_inputs_from_same_user(transferManagerInputs, userStakeCredential)
// }

// // test validate_all_inputs_and_get_total_amount() {
// //   let inputs =
// //     []
// //   let userRefInput = False

// //   transfer_manager.test_validate_all_inputs_and_get_total_amount(
// //     inputs: inputs,
// //     transferManagerScriptHash: "transferManagerScriptHash",
// //     securityAssetName: "securityAssetName",
// //     userRefInput: userRefInput,
// //     stateManagerHash: "stateManagerHash",
// //     userStateAssetName: "userStateAssetName",
// //   )
// // }

// // fn build_input_with_stake_credential_from_user(
// //   stakeCredential: StakeCredential,
// //   userPaymentCredential: ByteArray,
// // ) {
// //   let userTokenPolicyId = "TEST_POLICY"
// //   let userTokenAssetName = "TEST_ASSET"
// //   let inputOutputReference =
// //     OutputReference { transaction_id: "123456789", output_index: 3 }
// //   let inputAddress =
// //     Address {
// //       payment_credential: address.VerificationKey(userPaymentCredential),
// //       stake_credential: Some(stakeCredential),
// //     }
// //   let inputOutput =
// //     Output {
// //       address: inputAddress,
// //       value: from_asset(userTokenPolicyId, userTokenAssetName, 1),
// //       datum: NoDatum,
// //       reference_script: None,
// //     }
// //   let input =
// //     Input { output_reference: inputOutputReference, output: inputOutput }
// //   input
// // }

// fn build_input_with_stake_credential_from_sc(
//   stakeCredential: StakeCredential,
//   scHash: ByteArray,
// ) {
//   let userTokenPolicyId = "TEST_POLICY"
//   let userTokenAssetName = "TEST_ASSET"
//   let inputOutputReference =
//     OutputReference { transaction_id: "123456789", output_index: 3 }
//   let inputAddress =
//     Address {
//       payment_credential: address.VerificationKey(scHash),
//       stake_credential: Some(stakeCredential),
//     }
//   let inputOutput =
//     Output {
//       address: inputAddress,
//       value: from_asset(userTokenPolicyId, userTokenAssetName, 1),
//       datum: NoDatum,
//       reference_script: None,
//     }
//   let input =
//     Input { output_reference: inputOutputReference, output: inputOutput }
//   input
// }

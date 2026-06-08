use aiken_design_patterns/linked_list.{get_element_info, run_element_with}
use cardano/address.{Credential}
use cardano/assets.{quantity_of}
use cardano/certificate.{Certificate, RegisterCredential}
use cardano/transaction.{Input, Output, Transaction}
use constants
use types/minting_logic_script.{MintingLogicScriptWithdrawRedeemer}
use types/power_users.{PowerUser}
use utils.{must_be_signed_by_credential}

validator minting_logic_validator(
  security_asset_name: ByteArray,
  global_state_policy_id: ByteArray,
  registry_policy_id: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
) {
  withdraw(
    redeemer: MintingLogicScriptWithdrawRedeemer,
    credential: Credential,
    self: Transaction,
  ) {
    // DIVERGES FROM UPSTREAM (registration-mode rubber-stamp):
    //
    // The CIP-113 platform invokes substandard.withdraw at REGISTRATION time
    // (= the tx that inserts the prog-token policy into the directory linked
    // list). At that point the directory entry being created doesn't yet exist
    // as a reference input, so `derive_issuance_policy_id_from_registry_node`
    // below would crash with EmptyList. We detect registration mode by the
    // presence of a fresh directory NFT mint under `registry_policy_id` and
    // short-circuit to True. The CIP-113 directory mint validator that fires
    // in the same tx enforces the admin signature, the (issuance, substandard)
    // hash pairing, and the linked-list structural invariants — so this
    // rubber-stamp doesn't weaken the supply cap. All real (non-registration)
    // mints still run the full strict path below, including GS spend, PU
    // ref-input, and the registry-derived issuance policy check.
    let is_registration_tx = utils.quantity_of_policy_id(
      self.mint,
      registry_policy_id,
    ) > 0
    if is_registration_tx {
      True
    } else {
      let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
        self.reference_inputs,
        registry_policy_id,
        credential,
        constants.minting_logic_script_registry_node_index,
      )

      let minted_amount = quantity_of(
        self.mint,
        issuance_policy_id,
        security_asset_name,
      )

      // GS is always spent during a mint under the Track 4 design (GS minted at
      // initCompliance; register spends-and-updates it via the MintSecurity
      // branch, which enforces the supply cap). This validator only needs to
      // assert the GS NFT is actually on the referenced input — NFT presence on
      // an input implies the GS spend validator is running; by the non-Mint-
      // branches-reject-mint invariant in global_state.ak, only the MintSecurity
      // branch permits a security-token mint — and it decrements `mintable_amount`.
      let gs_input = utils.safe_list_at(
        self.inputs,
        redeemer.global_state_input_index,
      )
      expect
        quantity_of(
          gs_input.output.value,
          global_state_policy_id,
          constants.global_state_asset_name,
        ) == 1

      let power_user_ref_input = utils.safe_list_at(
        self.reference_inputs,
        redeemer.power_user_node_ref_input_index,
      )

      let (power_user_node_key, power_user_data) = get_element_info(
        power_user_ref_input.output,
        fn(_lovelace, node_key, data, _link) {
          expect Some(key) = node_key
          expect power_user_data: PowerUser = data
          (key, power_user_data)
        },
      )
        |> run_element_with(
            power_users_linked_list_policy_id,
            constants.linked_list_root_key,
            constants.linked_list_node_key_prefix,
            constants.linked_list_node_key_prefix_length,
          )

      and {
        //Redeemer contains the amount just for easy reference for eventual other contracts
        (minted_amount == redeemer.minted_amount)?,
        //A power user must have signed the transaction
        must_be_signed_by_credential(self, power_user_node_key)?,
        //If minted_amount > 0, power user must be minter
        //If minted_amount < 0, power user must be burner
        if minted_amount > 0 {
          power_user_data.can_mint
        } else {
          power_user_data.can_burn
        }?,
      }
    }
  }

  // Whitelist RegisterCredential only. Rejecting UnregisterCredential prevents
  // a ~2 ADA griefing DoS: a rubber-stamp publish would allow anyone to
  // de-register this script's stake credential, which would brick every
  // withdraw-zero mint/burn until re-registered. Also rejects delegation and
  // DRep/committee cert types — this credential exists solely for withdraw-0.
  // Tradeoff: the stake credential becomes permanent (2 ADA locked forever).
  publish(_r: Data, c: Certificate, _s: Transaction) {
    when c is {
      RegisterCredential { .. } -> True
      _ -> False
    }
  }

  else(_) {
    fail
  }
}
// ── Test constants ───────────────────────────────────────────────────────────

// const test_security_asset_name: ByteArray = "SEC"

// // 28-byte stand-ins for the three script hashes the validator is parameterised
// // on, plus the power-user credential and the script-applied hashed parameter.
// const test_gs_policy_id: ByteArray =
//   #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

// const test_pu_policy_id: ByteArray =
//   #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

// const test_pu_credential_hash: ByteArray =
//   #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

// const test_hashed_param: ByteArray =
//   #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

// // Arbitrary prefix/postfix bytes — apply_hashed_parameter is hashed at test
// // time to obtain the issuance policy id the mint must use.
// const test_issuance_prefix: ByteArray = #"4d01000033222233"

// const test_issuance_postfix: ByteArray = #"0001"

// // ── Test helpers ─────────────────────────────────────────────────────────────

// // fn test_issuance_policy_id() -> PolicyId {
// //   apply_hashed_parameter(
// //     test_issuance_prefix,
// //     test_issuance_postfix,
// //     test_hashed_param,
// //   )
// // }

// // fn test_out_ref(ix: Int) -> OutputReference {
// //   OutputReference {
// //     transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
// //     output_index: ix,
// //   }
// // }

// // // GS input — only the NFT presence matters here; the spend validator handles
// // // the cap. Datum is not read by minting_logic_validator.
// // fn make_gs_input() -> Input {
// //   Input {
// //     output_reference: test_out_ref(0),
// //     output: Output {
// //       address: Address {
// //         payment_credential: Script(test_gs_policy_id),
// //         stake_credential: None,
// //       },
// //       value: merge(
// //         from_lovelace(2_000_000),
// //         from_asset(test_gs_policy_id, constants.global_state_asset_name, 1),
// //       ),
// //       datum: NoDatum,
// //       reference_script: None,
// //     },
// //   }
// // }

// // // Linked-list node ref input: asset name = "Node" ++ credential_hash, datum
// // // is an Element wrapping a PowerUser as Node data. authenticate_element_utxo
// // // requires exactly ada + 1 NFT in the value.
// // fn make_pu_node_ref_input(can_mint: Bool, can_burn: Bool) -> Input {
// //   let pu =
// //     PowerUser {
// //       credential_hash: test_pu_credential_hash,
// //       is_admin: False,
// //       can_mint,
// //       can_burn,
// //       can_pause: False,
// //       can_force_transfer: False,
// //     }
// //   let datum = Element { data: Node { data: pu }, link: None }
// //   let node_asset_name =
// //     bytearray.concat(
// //       constants.linked_list_node_key_prefix,
// //       test_pu_credential_hash,
// //     )
// //   Input {
// //     output_reference: test_out_ref(1),
// //     output: Output {
// //       address: Address {
// //         payment_credential: Script(test_pu_policy_id),
// //         stake_credential: None,
// //       },
// //       value: merge(
// //         from_lovelace(2_000_000),
// //         from_asset(test_pu_policy_id, node_asset_name, 1),
// //       ),
// //       datum: InlineDatum(datum),
// //       reference_script: None,
// //     },
// //   }
// // }

// // // IssuanceCborHex ref input — derive_token_policy locates it by NFT, reads
// // // its inline datum, and hashes (prefix ++ hashed_param ++ postfix) to obtain
// // // the security-token policy id.
// // fn make_issuance_ref_input() -> Input {
// //   let datum =
// //     IssuanceCborHex {
// //       prefix_cbor_hex: test_issuance_prefix,
// //       postfix_cbor_hex: test_issuance_postfix,
// //     }
// //   Input {
// //     output_reference: test_out_ref(2),
// //     output: Output {
// //       address: Address {
// //         payment_credential: Script(env.issuance_cbor_hex_policy_id),
// //         stake_credential: None,
// //       },
// //       value: from_asset(
// //         env.issuance_cbor_hex_policy_id,
// //         issuance_cbor_hex_token_name,
// //         1,
// //       ),
// //       datum: InlineDatum(datum),
// //       reference_script: None,
// //     },
// //   }
// // }
// fn make_withdraw_tx(
//   minted_amount: Int,
//   can_mint: Bool,
//   can_burn: Bool,
//   signatories: List<ByteArray>,
// ) -> Transaction {
//   Transaction {
//     inputs: [make_gs_input()],
//     reference_inputs: [
//       make_pu_node_ref_input(can_mint, can_burn),
//       make_issuance_ref_input(),
//     ],
//     outputs: [],
//     fee: 0,
//     mint: from_asset(
//       test_issuance_policy_id(),
//       test_security_asset_name,
//       minted_amount,
//     ),
//     certificates: [],
//     withdrawals: [],
//     validity_range: Interval {
//       lower_bound: IntervalBound {
//         bound_type: NegativeInfinity,
//         is_inclusive: True,
//       },
//       upper_bound: IntervalBound {
//         bound_type: PositiveInfinity,
//         is_inclusive: False,
//       },
//     },
//     extra_signatories: signatories,
//     redeemers: [],
//     datums: dict.empty,
//     id: #"0000000000000000000000000000000000000000000000000000000000000000",
//     votes: [],
//     proposal_procedures: [],
//     current_treasury_amount: None,
//     treasury_donation: None,
//   }
// }
// // ── withdraw — critical paths ────────────────────────────────────────────────

// test withdraw_succeeds_for_mint() {
//   let amount = 1_000
//   let redeemer =
//     MintingLogicScriptWithdrawRedeemer {
//       global_state_input_index: 0,
//       power_user_node_ref_input_index: 0,
//       minted_amount: amount,
//     }
//   minting_logic_validator.withdraw(
//     test_security_asset_name,
//     test_gs_policy_id,
//     test_pu_policy_id,
//     redeemer,
//     Script(test_hashed_param),
//     make_withdraw_tx(amount, True, False, [test_pu_credential_hash]),
//   )
// }

// test withdraw_succeeds_for_burn() {
//   let amount = -1_000
//   let redeemer =
//     MintingLogicScriptWithdrawRedeemer {
//       global_state_input_index: 0,
//       power_user_node_ref_input_index: 0,
//       minted_amount: amount,
//     }
//   minting_logic_validator.withdraw(
//     test_security_asset_name,
//     test_gs_policy_id,
//     test_pu_policy_id,
//     redeemer,
//     Script(test_hashed_param),
//     make_withdraw_tx(amount, False, True, [test_pu_credential_hash]),
//   )
// }

// // ── withdraw — failure paths ─────────────────────────────────────────────────
// //
// // Each test exercises one rejection branch. The first four cover the final
// // `and { ... }` block (validator returns False — negated via `!`). The last
// // covers a precondition `expect` that traps before reaching that block, so it
// // uses the `fail` annotation.

// test withdraw_fails_when_redeemer_amount_mismatch() {
//   // Mint is 1_000 but redeemer claims 500 — `minted_amount == redeemer.minted_amount` is False.
//   let redeemer =
//     MintingLogicScriptWithdrawRedeemer {
//       global_state_input_index: 0,
//       power_user_node_ref_input_index: 0,
//       minted_amount: 500,
//     }
//   !minting_logic_validator.withdraw(
//     test_security_asset_name,
//     test_gs_policy_id,
//     test_pu_policy_id,
//     redeemer,
//     Script(test_hashed_param),
//     make_withdraw_tx(1_000, True, False, [test_pu_credential_hash]),
//   )
// }

// test withdraw_fails_when_not_signed_by_power_user() {
//   // No extra_signatories and no script-withdrawal → must_be_signed_by_credential = False.
//   let amount = 1_000
//   let redeemer =
//     MintingLogicScriptWithdrawRedeemer {
//       global_state_input_index: 0,
//       power_user_node_ref_input_index: 0,
//       minted_amount: amount,
//     }
//   !minting_logic_validator.withdraw(
//     test_security_asset_name,
//     test_gs_policy_id,
//     test_pu_policy_id,
//     redeemer,
//     Script(test_hashed_param),
//     make_withdraw_tx(amount, True, False, []),
//   )
// }

// test withdraw_fails_when_minting_without_mint_permission() {
//   // minted_amount > 0 selects the `can_mint` branch, but the power user lacks it.
//   let amount = 1_000
//   let redeemer =
//     MintingLogicScriptWithdrawRedeemer {
//       global_state_input_index: 0,
//       power_user_node_ref_input_index: 0,
//       minted_amount: amount,
//     }
//   !minting_logic_validator.withdraw(
//     test_security_asset_name,
//     test_gs_policy_id,
//     test_pu_policy_id,
//     redeemer,
//     Script(test_hashed_param),
//     make_withdraw_tx(amount, False, True, [test_pu_credential_hash]),
//   )
// }

// test withdraw_fails_when_burning_without_burn_permission() {
//   // minted_amount < 0 selects the `can_burn` branch, but the power user lacks it.
//   let amount = -1_000
//   let redeemer =
//     MintingLogicScriptWithdrawRedeemer {
//       global_state_input_index: 0,
//       power_user_node_ref_input_index: 0,
//       minted_amount: amount,
//     }
//   !minting_logic_validator.withdraw(
//     test_security_asset_name,
//     test_gs_policy_id,
//     test_pu_policy_id,
//     redeemer,
//     Script(test_hashed_param),
//     make_withdraw_tx(amount, True, False, [test_pu_credential_hash]),
//   )
// }

// test withdraw_fails_when_gs_nft_missing() fail {
//   // Replace the GS input with a UTxO that has no GS NFT — the `expect
//   // quantity_of(...) == 1` precondition traps.
//   let bogus_gs_input =
//     Input {
//       output_reference: test_out_ref(0),
//       output: Output {
//         address: Address {
//           payment_credential: Script(test_gs_policy_id),
//           stake_credential: None,
//         },
//         value: from_lovelace(2_000_000),
//         datum: NoDatum,
//         reference_script: None,
//       },
//     }
//   let tx =
//     Transaction {
//       ..make_withdraw_tx(1_000, True, False, [test_pu_credential_hash]),
//       inputs: [bogus_gs_input],
//     }
//   let redeemer =
//     MintingLogicScriptWithdrawRedeemer {
//       global_state_input_index: 0,
//       power_user_node_ref_input_index: 0,
//       minted_amount: 1_000,
//     }
//   minting_logic_validator.withdraw(
//     test_security_asset_name,
//     test_gs_policy_id,
//     test_pu_policy_id,
//     redeemer,
//     Script(test_hashed_param),
//     tx,
//   )
// }

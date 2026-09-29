use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{PolicyId, quantity_of, without_lovelace}
use cardano/transaction.{InlineDatum, OutputReference, Transaction, find_input}
use constants
use types/global_state.{
  GlobalStateDatum, GlobalStateSpendRedeemer, ModifySecurityInfo,
  ModifyTrustedEntities, PauseTransfers, UpdateMemberRootHash, UpdateMintableAmount,
} as gs_types
use utils.{must_be_signed_by_credential, quantity_of_policy_id, safe_list_at}

/// Combined global state validator (mint + spend in one script).
///
/// Having both handlers in a single validator ensures the minting policy ID
/// equals the spending script hash, so the NFT can be sent to the validator's
/// own address and later spent/updated.
///
/// Parameters:
///   - tx0: Bootstrap UTxO transaction hash (one-shot uniqueness)
///   - index0: Bootstrap UTxO output index
///   - owner_credential_hash: Admin public key hash who can update state
validator global_state(
  tx0: ByteArray,
  index0: Int,
  owner_credential_hash: ByteArray,
) {
  // ─── Mint Handler ─────────────────────────────────────────────────────
  // One-shot minting policy: mints exactly 1 "GlobalState" NFT to own address.
  mint(_redeemer: Data, policy_id: PolicyId, self: Transaction) {
    let contract_credential = Script(policy_id)

    let one_time_utxo = OutputReference(tx0, index0)
    expect Some(_input_present) = find_input(self.inputs, one_time_utxo)
    let first_output = safe_list_at(self.outputs, 0)

    and {
      // First output goes to this validator's own address
      first_output.address.payment_credential == contract_credential,
      // Only 1 token of this policy minted in total
      quantity_of_policy_id(self.mint, policy_id) == 1,
      // Exactly 1 NFT with the "GlobalState" asset name
      quantity_of(self.mint, policy_id, constants.global_state_asset_name) == 1,
      // NFT is in the first output
      quantity_of(
        first_output.value,
        policy_id,
        constants.global_state_asset_name,
      ) == 1,
    }
  }

  // ─── Spend Handler ────────────────────────────────────────────────────
  // Admin-guarded spending: validates typed redeemer actions, each updating
  // exactly one datum field while preserving the NFT at the same address.
  spend(
    datum_opt: Option<GlobalStateDatum>,
    redeemer: GlobalStateSpendRedeemer,
    input_out_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(input_datum) = datum_opt
    expect Some(own_input) =
      list.find(
        self.inputs,
        fn(input) { input.output_reference == input_out_ref },
      )

    // Extract own script hash (= policy ID) from our address
    expect Script(own_hash) = own_input.output.address.payment_credential

    let global_state_output =
      safe_list_at(self.outputs, redeemer.global_state_output_index)
    expect InlineDatum(global_state_output_datum) = global_state_output.datum
    expect parsed_output_datum: GlobalStateDatum = global_state_output_datum

    when redeemer.action is {
      UpdateMintableAmount { new_mintable_amount } -> {
        let expected_datum =
          GlobalStateDatum {
            ..input_datum,
            mintable_amount: new_mintable_amount,
          }
        and {
          must_be_signed_by_credential(self, owner_credential_hash),
          new_mintable_amount >= 0,
          global_state_output.address.payment_credential == own_input.output.address.payment_credential,
          parsed_output_datum == expected_datum,
          quantity_of(
            global_state_output.value,
            own_hash,
            constants.global_state_asset_name,
          ) == 1,
          own_input.output.value == global_state_output.value,
        }
      }
      PauseTransfers { transfers_paused } -> {
        let expected_datum =
          GlobalStateDatum { ..input_datum, transfers_paused: transfers_paused }
        and {
          must_be_signed_by_credential(self, owner_credential_hash),
          global_state_output.address.payment_credential == own_input.output.address.payment_credential,
          parsed_output_datum == expected_datum,
          quantity_of(
            global_state_output.value,
            own_hash,
            constants.global_state_asset_name,
          ) == 1,
          own_input.output.value == global_state_output.value,
        }
      }
      ModifySecurityInfo { new_security_info } -> {
        let expected_datum =
          GlobalStateDatum { ..input_datum, security_info: new_security_info }
        and {
          must_be_signed_by_credential(self, owner_credential_hash),
          global_state_output.address.payment_credential == own_input.output.address.payment_credential,
          parsed_output_datum == expected_datum,
          without_lovelace(own_input.output.value) == without_lovelace(
            global_state_output.value,
          ),
        }
      }
      ModifyTrustedEntities { new_trusted_entities } -> {
        let expected_datum =
          GlobalStateDatum {
            ..input_datum,
            trusted_entities: new_trusted_entities,
          }
        and {
          must_be_signed_by_credential(self, owner_credential_hash),
          global_state_output.address.payment_credential == own_input.output.address.payment_credential,
          parsed_output_datum == expected_datum,
          quantity_of(
            global_state_output.value,
            own_hash,
            constants.global_state_asset_name,
          ) == 1,
          own_input.output.value == global_state_output.value,
        }
      }
      UpdateMemberRootHash { new_member_root_hash } -> {
        let expected_datum =
          GlobalStateDatum {
            ..input_datum,
            member_root_hash: new_member_root_hash,
          }
        and {
          must_be_signed_by_credential(self, owner_credential_hash),
          global_state_output.address.payment_credential == own_input.output.address.payment_credential,
          parsed_output_datum == expected_datum,
          quantity_of(
            global_state_output.value,
            own_hash,
            constants.global_state_asset_name,
          ) == 1,
          own_input.output.value == global_state_output.value,
        }
      }
    }
  }

  else(_) {
    fail
  }
}

use aiken/collection/list
use aiken_design_patterns/linked_list.{get_element_info, run_element_with}
use cardano/address.{Credential, Inline, Script, VerificationKey}
use cardano/assets.{quantity_of}
use cardano/certificate.{Certificate, RegisterCredential}
use cardano/transaction.{InlineDatum, Transaction}
use constants
use denylist/absence.{verify_denylist_absence}
use env
use kyc/verify.{verify_kyc_proof}
use types/global_state.{GlobalStateDatum}
use types/power_users.{PowerUser}
use types/third_party_transfer_logic_script.{
  ThirdPartyTransferLogicScriptWithdrawRedeemer,
}
use utils.{must_be_signed_by_credential}

/// Third-party (force) transfer logic for emergency regulatory flows.
///
/// Per-destination check (for each unique destination stake credential):
///   1. A valid KYC proof for the destination (attested by a TEL entity).
///   2. The destination is NOT in the denylist.
///
/// NO source checks — force transfer is an admin override: the source may be
/// denylisted or have expired KYC. That is the point.
///
/// Plus:
///   - Transfers-paused gate (same as regular transfers — H-3 fix).
///   - `can_force_transfer` power user signs.
validator third_party_transfer_logic_validator(
  security_asset_name: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
  global_state_policy_id: ByteArray,
  registry_policy_id: ByteArray,
) {
  withdraw(
    redeemer: ThirdPartyTransferLogicScriptWithdrawRedeemer,
    credential: Credential,
    self: Transaction,
  ) {
    let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
      self.reference_inputs,
      registry_policy_id,
      credential,
      constants.transfer_logic_script_registry_node_index,
    )

    // Pause + GS-datum decode.
    let gs_input = utils.safe_list_at(
      self.reference_inputs,
      redeemer.global_state_ref_input_index,
    )
    let transfers_paused = global_state.is_paused(
      gs_input,
      global_state_policy_id,
    )
    expect InlineDatum(gs_datum_raw) = gs_input.output.datum
    expect gs_datum: GlobalStateDatum = gs_datum_raw

    // Unique destination stake-cred hashes from outputs carrying the token.
    let outputs_user_stake_cred_hash = list.unique(
      list.foldr(
        self.outputs,
        [],
        fn(output, result) {
          if quantity_of(output.value, issuance_policy_id, security_asset_name) > 0 {
            expect Some(Inline(stake_cred)) = output.address.stake_credential
            let credential_hash = when stake_cred is {
              VerificationKey(hash) -> hash
              Script(hash) -> hash
            }
            list.push(result, credential_hash)
          } else {
            result
          }
        },
      ),
    )

    // Per-destination: KYC proof + denylist absence.
    let all_destinations_ok = list.indexed_foldr(
      outputs_user_stake_cred_hash,
      True,
      fn(index, dest_pkh, acc) {
        expect acc
        let action = utils.safe_list_at(redeemer.destination_actions, index)
        let kyc_ok = verify_kyc_proof(
          action.destination_proof,
          dest_pkh,
          gs_datum,
          issuance_policy_id,
          env.network_id,
          self,
        )
        let denylist_ok = verify_denylist_absence(
          dest_pkh,
          action.destination_denylist_covering_ref_input_index,
          self.reference_inputs,
          gs_datum.denylist_linked_list_policy_id,
        )
        and {
          kyc_ok,
          denylist_ok,
        }
      },
    )

    // Admin-authorised power user with can_force_transfer.
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
      transfers_paused == False,
      all_destinations_ok,
      power_user_data.can_force_transfer,
      must_be_signed_by_credential(self, power_user_node_key),
    }
  }

  // Whitelist RegisterCredential only — see minting_logic_script for rationale.
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

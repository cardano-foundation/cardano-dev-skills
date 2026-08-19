use aiken/collection/dict
use aiken/collection/list
use aiken_design_patterns/linked_list.{
  deinit, get_element_info, init, insert_ascending, remove, run_element_with,
  run_eval_with, run_root_with, spend_for_adding_or_removing_an_element,
}
use cardano/assets.{PolicyId, tokens}
use cardano/transaction.{OutputReference, Transaction}
use constants
use types/denylist.{
  AddToDenylist, Deinit, Denylist, Init, MintRedeemer, RemoveFromDenylist,
  SpendRedeemer, StateTransition,
}
use types/global_state.{active_admin_from_ref_input, gs_datum_from_ref_input}
use types/power_users.{PowerUser}
use utils.{must_be_signed_by_credential}

/// Resolves the GS reference input (for the power-user linked-list policy id)
/// and the power-user node reference input at `power_user_node_ref_input_index`,
/// authenticating the node against that list. Returns the node's credential hash
/// and parsed `PowerUser` data. Callers gate sanctions on `is_admin` + the
/// returned credential's signature.
fn power_user_from_refs(
  self: Transaction,
  global_state_ref_input_index: Int,
  global_state_policy_id: ByteArray,
  power_user_node_ref_input_index: Int,
) -> (ByteArray, PowerUser) {
  let gs = gs_datum_from_ref_input(
    self.reference_inputs,
    global_state_ref_input_index,
    global_state_policy_id,
  )
  // No sanctions administration on a decommissioned protocol.
  expect !gs.deactivated
  let power_user_node_ref_input = utils.safe_list_at(
    self.reference_inputs,
    power_user_node_ref_input_index,
  )
  get_element_info(
    power_user_node_ref_input.output,
    fn(_lovelace, node_key, data, _link) {
      expect Some(key) = node_key
      expect power_user_data: PowerUser = data
      (key, power_user_data)
    },
  )
    |> run_element_with(
        gs.power_user_linked_list_policy_id,
        constants.linked_list_root_key,
        constants.linked_list_node_key_prefix,
        constants.linked_list_node_key_prefix_length,
      )
}

validator denylist_validator(denylist_linked_list_policy_id: ByteArray) {
  spend(
    _datum_opt: Option<Data>,
    redeemer: SpendRedeemer,
    _input_out_ref: OutputReference,
    self: Transaction,
  ) {
    let StateTransition = redeemer
    // Delegate to mint validator. No ModifyUser action — presence IS the
    // state, there's nothing to toggle.
    spend_for_adding_or_removing_an_element(
      denylist_linked_list_policy_id,
      self.mint,
    )
  }

  else(_) {
    fail
  }
}

validator mint(
  global_state_policy_id: ByteArray,
  init_input_out_ref: OutputReference,
) {
  mint(redeemer: MintRedeemer, policy_id: PolicyId, self: Transaction) {
    when redeemer is {
      Init { root_output_index } -> {
        // Nonce-gated. GS doesn't exist yet at bootstrap — the operator-held
        // one-shot UTxO is the implicit gate, same pattern as power_users.
        let nonce_validated = list.any(
          self.inputs,
          fn(input) { input.output_reference == init_input_out_ref },
        )
        let root_output = utils.safe_list_at(self.outputs, root_output_index)
        and {
          dict.size(tokens(self.mint, policy_id)) == 1,
          init(nonce_validated, root_output, self.mint, fn(_, _) { True })
            |> run_root_with(policy_id, constants.linked_list_root_key),
        }
      }
      Deinit { root_input_index, global_state_ref_input_index } -> {
        let admin = active_admin_from_ref_input(
          self.reference_inputs,
          global_state_ref_input_index,
          global_state_policy_id,
        )
        let root_input = utils.safe_list_at(self.inputs, root_input_index)
        and {
          must_be_signed_by_credential(self, admin),
          dict.size(tokens(self.mint, policy_id)) == 1,
          deinit(root_input, self.mint, fn(_, _) { True })
            |> run_root_with(policy_id, constants.linked_list_root_key),
        }
      }
      AddToDenylist {
        user_pkh,
        anchor_node_input_index,
        anchor_node_output_index,
        appended_node_output_index,
        global_state_ref_input_index,
        power_user_node_ref_input_index,
      } -> {
        // Sanctioning is delegated: any power user holding `is_admin` can add a
        // denylist entry (signed by that user). The GS admin grants the flag.
        let (power_user_credential_hash, power_user_data) = power_user_from_refs(
          self,
          global_state_ref_input_index,
          global_state_policy_id,
          power_user_node_ref_input_index,
        )
        let anchor_input = utils.safe_list_at(
          self.inputs,
          anchor_node_input_index,
        )
        let anchor_output = utils.safe_list_at(
          self.outputs,
          anchor_node_output_index,
        )
        let new_node_output = utils.safe_list_at(
          self.outputs,
          appended_node_output_index,
        )
        and {
          power_user_data.is_admin,
          must_be_signed_by_credential(self, power_user_credential_hash),
          dict.size(tokens(self.mint, policy_id)) == 1,
          insert_ascending(
            anchor_input,
            anchor_output,
            new_node_output,
            self.mint,
            fn(
              _lovelace_change,
              _anchor_key,
              _anchor_data,
              _new_lovelace,
              node_key,
              node_data,
              _link,
            ) {
              // Datum type must be correct (metadata is free-form Data).
              expect _parsed: Denylist = node_data
              node_key == user_pkh
            },
          )
            |> run_eval_with(
                policy_id,
                constants.linked_list_root_key,
                constants.linked_list_node_key_prefix,
                constants.linked_list_node_key_prefix_length,
              ),
        }
      }
      RemoveFromDenylist {
        user_pkh,
        anchor_node_input_index,
        removed_node_input_index,
        anchor_node_output_index,
        global_state_ref_input_index,
        power_user_node_ref_input_index,
      } -> {
        // Un-sanctioning is gated the same as adding: a power user holding
        // `is_admin`, signed by that user.
        let (power_user_credential_hash, power_user_data) = power_user_from_refs(
          self,
          global_state_ref_input_index,
          global_state_policy_id,
          power_user_node_ref_input_index,
        )
        let anchor_input = utils.safe_list_at(
          self.inputs,
          anchor_node_input_index,
        )
        let removing_input = utils.safe_list_at(
          self.inputs,
          removed_node_input_index,
        )
        let anchor_output = utils.safe_list_at(
          self.outputs,
          anchor_node_output_index,
        )
        and {
          power_user_data.is_admin,
          must_be_signed_by_credential(self, power_user_credential_hash),
          dict.size(tokens(self.mint, policy_id)) == 1,
          remove(
            anchor_input,
            removing_input,
            anchor_output,
            self.mint,
            fn(
              _lovelace_change,
              _anchor_key,
              _anchor_data,
              _rem_lovelace,
              rem_key,
              rem_data,
              _link,
            ) {
              expect _parsed: Denylist = rem_data
              rem_key == user_pkh
            },
          )
            |> run_eval_with(
                policy_id,
                constants.linked_list_root_key,
                constants.linked_list_node_key_prefix,
                constants.linked_list_node_key_prefix_length,
              ),
        }
      }
    }
  }

  else(_) {
    fail
  }
}

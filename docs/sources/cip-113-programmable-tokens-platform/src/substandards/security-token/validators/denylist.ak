use aiken/collection/dict
use aiken/collection/list
use aiken_design_patterns/linked_list.{
  deinit, init, insert_ascending, remove, run_eval_with, run_root_with,
  spend_for_adding_or_removing_an_element,
}
use cardano/assets.{PolicyId, tokens}
use cardano/transaction.{OutputReference, Transaction}
use constants
use types/denylist.{
  AddToDenylist, Deinit, Denylist, Init, MintRedeemer, RemoveFromDenylist,
  SpendRedeemer, StateTransition,
}
use types/global_state.{admin_from_ref_input}
use utils.{must_be_signed_by_credential}

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
        let admin = admin_from_ref_input(
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
      } -> {
        let admin = admin_from_ref_input(
          self.reference_inputs,
          global_state_ref_input_index,
          global_state_policy_id,
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
          must_be_signed_by_credential(self, admin),
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
      } -> {
        let admin = admin_from_ref_input(
          self.reference_inputs,
          global_state_ref_input_index,
          global_state_policy_id,
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
          must_be_signed_by_credential(self, admin),
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

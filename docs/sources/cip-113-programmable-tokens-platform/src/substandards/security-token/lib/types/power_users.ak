/// Power users are the BAFIN protocol's operators. Each flag is independent —
/// a power user holds exactly the set of permissions granted to them.
///
/// KYC verification is no longer a power-user concern — it's delegated to
/// trusted-entity-issued signed proofs (see `lib/types/kyc_proof.ak`).
/// Sanctions (denylist) mutations are gated directly by the admin credential
/// stored in `GlobalStateDatum`, not a PowerUser flag.
pub type PowerUser {
  credential_hash: ByteArray,
  //Admins can add/remove entries from the users/denylist linked list lifecycle
  is_admin: Bool,
  //Minters can mint new tokens
  can_mint: Bool,
  //Burners can burn tokens
  can_burn: Bool,
  //Pausers can pause/unpause all the transfers
  can_pause: Bool,
  //Force-transferers can move tokens between KYC'd non-denylisted addresses
  can_force_transfer: Bool,
}

pub type SpendRedeemer {
  StateTransition
  ModifyPowerUser {
    own_input_index: Int,
    own_output_index: Int,
    wanted_user_state: PowerUser,
    global_state_ref_input_index: Int,
  }
}

pub type MintRedeemer {
  Init { root_output_index: Int }
  Deinit { root_input_index: Int, global_state_ref_input_index: Int }
  AddPowerUser {
    new_power_user_key: ByteArray,
    anchor_node_input_index: Int,
    anchor_node_output_index: Int,
    appended_node_output_index: Int,
    global_state_ref_input_index: Int,
  }
  RemovePowerUser {
    power_user_key_to_remove: ByteArray,
    anchor_node_input_index: Int,
    removed_node_input_index: Int,
    anchor_node_output_index: Int,
    global_state_ref_input_index: Int,
  }
}

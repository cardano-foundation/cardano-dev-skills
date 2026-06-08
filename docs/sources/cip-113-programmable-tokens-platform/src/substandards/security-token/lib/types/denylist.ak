/// A node in the denylist linked list. Presence of a node keyed by a user's
/// PKH means that user is sanctioned — they cannot send OR receive security
/// tokens (enforced by transfer_logic and third_party_transfer_logic).
///
/// The node datum carries optional metadata (reason_hash, added_at, jurisdiction,
/// etc.). On-chain validators do NOT inspect this field — it exists only for
/// off-chain indexing and auditability.
pub type Denylist {
  metadata: Data,
}

/// Spend redeemer. Only `StateTransition` — all mutation logic delegates to
/// the mint validator. No `ModifyUser` analogue: presence IS the state, there
/// is nothing to toggle within a node.
pub type SpendRedeemer {
  StateTransition
}

/// Mint redeemer. Admin-gated Add/Remove/Deinit; Init is nonce-gated.
/// Every admin-gated action carries a reference-input index to the GS UTxO
/// so the validator can read the current `admin_credential_hash` from GS datum.
pub type MintRedeemer {
  Init { root_output_index: Int }
  Deinit { root_input_index: Int, global_state_ref_input_index: Int }
  AddToDenylist {
    user_pkh: ByteArray,
    anchor_node_input_index: Int,
    anchor_node_output_index: Int,
    appended_node_output_index: Int,
    global_state_ref_input_index: Int,
  }
  RemoveFromDenylist {
    user_pkh: ByteArray,
    anchor_node_input_index: Int,
    removed_node_input_index: Int,
    anchor_node_output_index: Int,
    global_state_ref_input_index: Int,
  }
}

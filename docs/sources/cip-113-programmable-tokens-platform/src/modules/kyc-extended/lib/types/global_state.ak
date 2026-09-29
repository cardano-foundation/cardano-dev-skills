/// Types for the KYC global state UTxO.
///
/// The global state UTxO holds mutable per-token state including the Trusted
/// Entity List (TEL), transfer pause flag, mintable amount cap, and arbitrary
/// security/compliance metadata.

/// Datum stored in the global state UTxO.
pub type GlobalStateDatum {
  /// If true, no transfer can be executed
  transfers_paused: Bool,
  /// Goes to zero when new tokens are minted, increases when tokens are burnt
  mintable_amount: Int,
  /// Ed25519 verification keys (32 bytes each) of entities authorized to sign
  /// KYC attestations for this token
  trusted_entities: List<ByteArray>,
  /// Regulation compliancy info, not directly used in the contracts
  security_info: Data,
  /// Root hash of the MPF membership tree (32 bytes); empty = no members yet
  member_root_hash: ByteArray,
}

/// Actions that can be performed on the global state UTxO.
pub type GlobalStateSpendAction {
  UpdateMintableAmount { new_mintable_amount: Int }
  PauseTransfers { transfers_paused: Bool }
  ModifySecurityInfo { new_security_info: Data }
  ModifyTrustedEntities { new_trusted_entities: List<ByteArray> }
  UpdateMemberRootHash { new_member_root_hash: ByteArray }
}

/// Redeemer for spending the global state UTxO.
pub type GlobalStateSpendRedeemer {
  global_state_output_index: Int,
  action: GlobalStateSpendAction,
}

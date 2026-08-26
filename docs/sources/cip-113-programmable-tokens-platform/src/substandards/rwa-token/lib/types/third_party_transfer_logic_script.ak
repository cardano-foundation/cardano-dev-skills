use types/global_state.{GlobalStateLocation}
use types/kyc_proof.{KycProof}

/// One entry per unique destination (unique stake-credential among outputs
/// carrying the security token). Admin provides a KYC proof for each
/// destination + a denylist-absence covering-node reference index.
///
/// Source is NOT checked — force transfer is an admin override: the source
/// may be denylisted or its KYC may have expired. That's the point.
pub type ThirdPartyDestinationAction {
  destination_proof: KycProof,
  destination_denylist_covering_ref_input_index: Int,
}

pub type ThirdPartyTransferLogicScriptWithdrawRedeemer {
  /// WHERE GlobalState is, not just which reference input it is.
  ///
  /// This validator only READS the datum (`requires_receiver_kyc` to decide
  /// whether destinations need a proof, `deactivated` to refuse once the
  /// protocol is decommissioned) — it makes no claim that depends on the GS
  /// spend validator having run, so it accepts either form. Demanding a
  /// reference input, as this field did when it was a bare
  /// `global_state_ref_input_index`, made the BURN unbuildable: a burn must
  /// SPEND GlobalState so `MintSecurity` credits the supply back, this
  /// withdrawal is not droppable from a burn (CIP-113's `ThirdPartyAct` is the
  /// only programmable-logic-global branch a burn can take), and Conway
  /// rejects a transaction that both spends and references one UTxO.
  global_state_location: GlobalStateLocation,
  power_user_node_ref_input_index: Int,
  destination_actions: List<ThirdPartyDestinationAction>,
}

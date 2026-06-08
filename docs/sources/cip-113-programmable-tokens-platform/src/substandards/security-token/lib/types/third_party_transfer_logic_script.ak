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
  global_state_ref_input_index: Int,
  power_user_node_ref_input_index: Int,
  destination_actions: List<ThirdPartyDestinationAction>,
}

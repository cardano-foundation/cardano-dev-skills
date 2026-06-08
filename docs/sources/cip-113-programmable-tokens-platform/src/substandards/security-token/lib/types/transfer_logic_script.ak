use types/kyc_proof.{KycProof}

/// One action per unique sender (unique stake-credential among inputs carrying
/// the security token). Binds a KYC proof to that sender and a covering-node
/// reference-input index proving the sender's pkh is absent from the denylist.
pub type TransferLogicScriptAction {
  source_proof: KycProof,
  source_denylist_covering_ref_input_index: Int,
}

/// One action per unique destination. Both a fresh KYC proof bound to the
/// destination and a denylist-absence proof are required.
///
/// Rationale: Swiss CO Art. 973e (DLT Act) requires the issuer to perform
/// obligations only to a named creditor in the ledger; eWpG §14 requires the
/// issuer to maintain a register of identified holders; and industry-standard
/// regulated-securities designs (ERC-3643; CMTAT with RuleWhitelist) gate
/// both sender and recipient. Requiring a destination proof on regular
/// transfers matches all three.
pub type TransferLogicScriptDestinationAction {
  destination_proof: KycProof,
  destination_denylist_covering_ref_input_index: Int,
}

/// Transfer-logic withdraw redeemer.
///
/// - `global_state_ref_input_index` — GS UTxO as ref input; provides pause
///   flag, TEL, denylist policy id.
/// - `actions_for_each_input` — one KYC proof + denylist-absence covering-node
///   index per unique sender, ordered to match the aggregated-senders order.
/// - `destination_actions` — one KYC proof + denylist-absence covering-node
///   index per unique destination, ordered to match the aggregated-destinations
///   order. Both positive (KYC) and negative (denylist absence) attestations
///   required on receive.
pub type TransferLogicScriptWithdrawRedeemer {
  global_state_ref_input_index: Int,
  actions_for_each_input: List<TransferLogicScriptAction>,
  destination_actions: List<TransferLogicScriptDestinationAction>,
}

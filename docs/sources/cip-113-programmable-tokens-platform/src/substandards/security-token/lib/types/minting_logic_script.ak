/// Withdraw redeemer for the minting_logic_script.
///
/// Under the Track 4 refactor, GS is minted at `initCompliance` (not at
/// register), so GS always exists by the time any security-token mint
/// runs. The earlier `GlobalStateRef` sum type (`GlobalStateInput` for
/// steady-state vs `GlobalStateOutputIndex` for genesis) is gone — every
/// mint now spends the GS UTxO via its input.
pub type MintingLogicScriptWithdrawRedeemer {
  /// Index into `self.inputs` — the GS UTxO being spent in this tx. Its
  /// spend validator runs under `MintSecurity`, which enforces the cap.
  global_state_input_index: Int,
  power_user_node_ref_input_index: Int,
  /// Amount minted (signed: positive for mint, negative for burn).
  minted_amount: Int,
}

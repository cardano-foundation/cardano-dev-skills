use types/kyc_proof.{KycProof}

/// One entry per unique destination (unique stake-credential among outputs
/// carrying the security token) when minting. Mirrors the transfer-logic
/// destination action: a KYC proof (checked only when
/// `GlobalStateDatum.requires_receiver_kyc`) and a denylist-absence
/// covering-node reference-input index (always checked). CMTAT v3.2.0
/// refuses to mint to a frozen address (core) or to a non-allowlisted one
/// (Allowlist variant); this is the eUTxO equivalent.
pub type MintingLogicDestinationAction {
  destination_proof: KycProof,
  destination_denylist_covering_ref_input_index: Int,
}

/// Withdraw redeemer for the minting_logic_script.
///
/// Under the Track 4 refactor, GS is minted at `initCompliance` (not at
/// register), so GS always exists by the time any security-token mint
/// runs. The earlier `GlobalStateRef` sum type (`GlobalStateInput` for
/// steady-state vs `GlobalStateOutputIndex` for genesis) is gone — every
/// mint now spends the GS UTxO via its input.
pub type MintingLogicScriptWithdrawRedeemer {
  /// Steady state: mint or burn the security token. This token's registry
  /// node already exists and is supplied as a reference input.
  MintBurn {
    /// Index into `self.reference_inputs` — the CIP-113 registry node for
    /// THIS token. Named explicitly because every programmable token's node
    /// shares the registry policy, so a search would resolve the wrong one in
    /// any transaction touching a second programmable token.
    registry_node_ref_input_index: Int,
    /// Index into `self.inputs` — the GS UTxO being spent in this tx. Its
    /// spend validator runs under `MintSecurity`, which enforces the cap.
    global_state_input_index: Int,
    power_user_node_ref_input_index: Int,
    /// Amount minted (signed: positive for mint, negative for burn).
    minted_amount: Int,
    /// One action per unique destination stake credential among outputs
    /// carrying the security token. Only consulted when `minted_amount > 0`
    /// (burns have no destinations); ordered to match the aggregated
    /// unique-destinations order.
    destination_actions: List<MintingLogicDestinationAction>,
  }
  /// CIP-113 registry insertion for this token.
  ///
  /// `registry_mint`'s `RegistryInsert` branch requires this validator's
  /// withdraw-0 to be present as the substandard's "proof of instance" — it
  /// is what stops anyone registering a policy that names a substandard which
  /// never consented. At that moment this token's registry node exists only
  /// as an OUTPUT (the covering node it splits is an input), so the
  /// steady-state reference-input lookup cannot resolve it and every
  /// registration would otherwise trap. This variant is that path.
  /// A registration MAY carry the first mint (CIP-113 supports it: the
  /// `OutputIndex` proof in `issuance_mint` explicitly covers "a genuine first
  /// mint"). When it does, every check the `MintBurn` path applies also
  /// applies here — `issuance_mint` verifies only that the node is genuine and
  /// that no token escapes the programmable-logic-base, so this validator is
  /// the sole authority on whether the mint itself is allowed.
  RegisterToken {
    /// Index into `self.outputs` — the registry node being created. An insert
    /// emits TWO registry-node outputs (the new node and the re-emitted
    /// covering node), so the index alone does not identify ours; the
    /// validator additionally matches on the node's `minting_logic_script`.
    registry_node_output_index: Int,
    /// Index into `self.reference_inputs` — GlobalState, read for the admin
    /// credential. Used when `minted_amount == 0`, where GS is only
    /// referenced. Ignored when `minted_amount > 0`.
    global_state_ref_input_index: Int,
    /// Index into `self.inputs` — GlobalState SPENT under `MintSecurity`, so
    /// its spend validator decrements and enforces `mintable_amount`. Used
    /// when `minted_amount > 0`; a UTxO cannot be both spent and referenced,
    /// which is why this is a separate field. Ignored when `minted_amount`
    /// is 0 (no GS spend action permits a no-op re-emit).
    global_state_input_index: Int,
    /// Index into `self.reference_inputs` — the `can_mint` power user
    /// authorising the first mint. Ignored when `minted_amount == 0`.
    power_user_node_ref_input_index: Int,
    /// Quantity of the security asset minted by this registration. Zero for a
    /// structural registration. Never negative — nothing exists to burn yet.
    minted_amount: Int,
    /// One action per unique destination, exactly as in `MintBurn`. Ignored
    /// when `minted_amount == 0`.
    destination_actions: List<MintingLogicDestinationAction>,
  }
}

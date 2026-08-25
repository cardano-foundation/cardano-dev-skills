use types/global_state.{GlobalStateLocation}
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

/// Withdraw redeemer for validators/minting_authority.ak — the swappable
/// minting authority named by `GlobalStateDatum.minting_script_credential_
/// hash` (admin-rotatable via `RotateMintingScript`).
///
/// minting_logic_script.ak (the permanent, CIP-113-registered proxy) requires
/// this validator's withdraw-0 to be present for any transaction that moves
/// the security token's supply, but hands this validator NOTHING
/// pre-verified — this redeemer carries everything needed to decide, and
/// every input is independently re-resolved and re-checked here.
///
/// `MintBurn` never reads the registry at all: the issuance policy it
/// polices is pinned at compile time, and the base layer already
/// authenticates whichever registry node invoked this withdraw-0 in the
/// first place. The other three variants still resolve a registry node —
/// `RegisterMint`/`RegisterStructural` because the node does not exist as a
/// UTxO yet (it is being created), `UpgradeRegistryNode` because IT is the
/// one path that may rewrite the node — for CIP-113 structural invariants
/// only they enforce.
pub type MintingAuthorityWithdrawRedeemer {
  /// Steady state: the registry node already exists as a UTxO and is
  /// supplied as a reference input.
  MintBurn {
    /// Index into `self.inputs` — the same GlobalState UTxO the proxy
    /// resolves (shared, transaction-wide data; a wrong index just fails the
    /// NFT check).
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
  /// The first mint, carried by the CIP-113 registration that creates this
  /// token's registry node. Identical authorisation to `MintBurn` — the node
  /// is simply reached through `self.outputs`, because at insert time it is
  /// an output of this very transaction rather than a pre-existing UTxO.
  ///
  /// The proxy still owns the registration's own structural invariants (that
  /// the node names it, forbids unfracking, and pins this deployment's
  /// GlobalState) and the admin gate on registering at all; this variant
  /// authorises only the mint that rides along with it.
  RegisterMint {
    /// Index into `self.outputs` — the registry node being created. An
    /// insert emits TWO registry-node outputs (the new node and the
    /// re-emitted covering node), so the index alone does not identify ours;
    /// the identity assertion against the proxy's hash disambiguates.
    registry_node_output_index: Int,
    /// Index into `self.inputs` — GlobalState, SPENT so its `MintSecurity`
    /// branch decrements and enforces `mintable_amount`.
    global_state_input_index: Int,
    power_user_node_ref_input_index: Int,
    /// Quantity minted by this registration. Never negative — nothing exists
    /// to burn yet.
    minted_amount: Int,
    destination_actions: List<MintingLogicDestinationAction>,
  }
  /// The CIP-113 UPGRADE path for the OTHER logic scripts.
  ///
  /// `registry_spend`'s in-place update branch (the `None` case, when no
  /// registry NFT is minted) lets a node's `transfer_logic_script`,
  /// `third_party_transfer_logic_script`, `unfracking_logic_script` and
  /// `global_state_cs` be rewritten, while `key`, `next` and
  /// `minting_logic_script` stay frozen forever
  /// (`is_field_updated_registry_node`). It gates that on
  /// `pairs.has_key(self.withdrawals, spent_node.minting_logic_script)` —
  /// i.e. on the permanent proxy, which delegates here. So this validator is
  /// the sole authority over whether this token's transfer rules may change.
  ///
  /// The base layer already guarantees, for this shape: exactly one registry
  /// node output (`expect [cont]`), the frozen fields unchanged, and that
  /// this token's own asset is neither minted nor burned in the same
  /// transaction (`expect !mint_has_policy(self.mint, spent_node.key)`).
  /// What it does NOT constrain is our deployment's own invariants — it
  /// happily lets `global_state_cs` be re-pointed away from our GlobalState
  /// and `unfracking_logic_script` be switched on — so those are re-asserted
  /// here.
  UpgradeRegistryNode {
    /// Index into `self.inputs` — this token's registry node, being spent.
    registry_node_input_index: Int,
    /// Index into `self.outputs` — the continuing node.
    registry_node_output_index: Int,
    /// WHERE GlobalState is — read for the admin credential and the upgrade
    /// lock, nothing more. Deliberately a location rather than a fixed
    /// reference index: this variant makes no claim that depends on the GS
    /// spend validator having run, so pinning it to one list would only forbid
    /// upgrading a registry node in the same transaction that spends
    /// GlobalState (Conway rejects the overlap). Contrast `MintBurn` and
    /// `RegisterMint` below, whose bare `global_state_input_index` is
    /// load-bearing: they MUST spend, or `MintSecurity` never runs and the
    /// supply cap goes unenforced. The type carries that distinction.
    global_state_location: GlobalStateLocation,
  }
  /// A CIP-113 registration that mints nothing — it only creates the registry
  /// node. GlobalState is merely REFERENCED (there is no supply change, so
  /// no cap to enforce and no reason to spend it), and the admin alone
  /// authorises. Asserting that nothing is in fact minted is what keeps this
  /// from being a way around `RegisterMint`'s power-user and receiver gates.
  RegisterStructural {
    /// Index into `self.outputs` — as in `RegisterMint`.
    registry_node_output_index: Int,
    /// WHERE GlobalState is — read for the admin credential only. A location
    /// for the same reason as `UpgradeRegistryNode`: nothing here depends on
    /// the GS spend validator running, and a structural registration should
    /// not be barred from a transaction that also spends GlobalState.
    global_state_location: GlobalStateLocation,
  }
}

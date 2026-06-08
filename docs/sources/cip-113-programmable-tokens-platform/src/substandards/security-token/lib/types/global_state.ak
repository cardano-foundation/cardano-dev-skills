use aiken/builtin
use cardano/address.{Address, Script}
use cardano/assets.{from_asset, quantity_of}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use constants
use utils

/// Free-form metadata attached to a trusted entity (e.g. jurisdiction, provider
/// URL, etc.). Unused by on-chain logic; kept for forward-compat.
pub type TrustedEntityMetadata =
  Data

/// GlobalState datum — authenticated by the single global_state NFT.
///
/// INVARIANT: `transfers_paused` MUST remain at field index 0. The fast
/// pause-read via `is_paused` below relies on `unconstr_fields` + `head_list`
/// to pull the first field without deserialising the whole datum. Reshuffling
/// fields breaks that optimisation.
pub type GlobalStateDatum {
  //If true, no transfer can be executed
  transfers_paused: Bool,
  //Goes to zero when new tokens are minted, increases when tokens are burnt
  mintable_amount: Int,
  //Key-hash of the protocol administrator. Rotatable via RotateAdmin action.
  admin_credential_hash: ByteArray,
  //PowerUsers linked list minting policy
  power_user_linked_list_policy_id: ByteArray,
  //Denylist linked list minting policy (presence = sanctioned)
  denylist_linked_list_policy_id: ByteArray,
  //Regulation (eg. BaFin) compliancy info, not directly used in the contracts
  security_info: Data,
  //Trusted Entity List — sorted ascending by vkey. Key = 32-byte Ed25519 vkey
  //used to verify KYC proofs. Value = free-form metadata (operator-defined).
  trusted_entity_vkeys: Pairs<ByteArray, TrustedEntityMetadata>,
  /// Root hash of the MPF membership tree (32 bytes); empty = no members yet
  member_root_hash: ByteArray,
  // Whether KYC is required for receiving transfers. 
  // If false, only the sender's KYC needs to be verified for a transfer; if true, both sender and receiver KYC are
  requires_receiver_kyc: Bool,
}

/// Asserts the given input is an authentic GS UTxO (carries exactly 1 GS NFT)
/// and returns whether transfers are paused. Reads only the first field of the
/// datum (`transfers_paused`) via UPLC builtins — no full-datum deserialisation.
///
/// Fails (via UPLC error) if:
///   * the input's value does not contain the GS NFT,
///   * the datum is not an inline Constr, or
///   * the first field of the datum is not a Constr (i.e. not a Bool).
///
/// Callers are responsible for locating the GS input first (e.g. via an index
/// carried in the redeemer). Typical usage:
///
///   let gs_input = utils.safe_list_at(self.reference_inputs, redeemer.idx)
///   expect !gs.is_paused(gs_input, global_state_policy_id)
pub fn is_paused(gs_input: Input, global_state_policy_id: ByteArray) -> Bool {
  expect
    quantity_of(
      gs_input.output.value,
      global_state_policy_id,
      constants.global_state_asset_name,
    ) > 0
  expect InlineDatum(gs_datum) = gs_input.output.datum
  let gs_fields = builtin.unconstr_fields(gs_datum)
  let transfers_paused_data = builtin.head_list(gs_fields)
  builtin.unconstr_index(transfers_paused_data) == 1
}

/// Resolves the GS reference input at `ref_index`, authenticates it via the
/// GS NFT, parses its inline datum, and returns the current admin credential
/// hash. Helper for validators (power_users, denylist) that delegate admin
/// checks to the GS datum instead of holding a compile-time owner parameter.
///
/// Fails (UPLC error) if: index out of range, NFT missing, datum non-inline,
/// or datum shape invalid.
pub fn admin_from_ref_input(
  reference_inputs: List<Input>,
  ref_index: Int,
  global_state_policy_id: ByteArray,
) -> ByteArray {
  let gs_ref = utils.safe_list_at(reference_inputs, ref_index)
  expect
    quantity_of(
      gs_ref.output.value,
      global_state_policy_id,
      constants.global_state_asset_name,
    ) > 0
  expect InlineDatum(gs_raw) = gs_ref.output.datum
  expect gs: GlobalStateDatum = gs_raw
  gs.admin_credential_hash
}

/// Spend actions on the global_state UTxO. Admin-gated actions read the
/// current admin credential hash from the input datum — which means the
/// compile-time owner parameter is gone. Rotation happens via `RotateAdmin`
/// with dual-signature (old + new admin).
pub type GlobalStateSpendAction {
  MintSecurity { issuance_policy_redeemer_index: Int }
  PauseTransfers {
    transfers_paused: Bool,
    power_user_node_ref_input_index: Int,
  }
  ModifySecurityInfo { new_security_info: Data }
  AddTrustedEntity { vkey: ByteArray, metadata: TrustedEntityMetadata }
  RemoveTrustedEntity { vkey: ByteArray }
  UpdateTrustedEntity {
    old_vkey: ByteArray,
    new_vkey: ByteArray,
    new_metadata: TrustedEntityMetadata,
  }
  SetRequiresReceiverKyc { enabled: Bool }
  UpdateMemberRootHash { new_member_root_hash: ByteArray }
  RotateAdmin { new_admin_credential_hash: ByteArray }
}

pub type GlobalStateSpendRedeemer {
  config_ref_input_index: Int,
  global_state_output_index: Int,
  action: GlobalStateSpendAction,
}

// ============================================================================
// Tests
// ============================================================================

const test_gs_policy_id: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const test_admin_pkh: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

fn test_gs_input(transfers_paused: Bool) -> Input {
  let datum = GlobalStateDatum {
    transfers_paused,
    mintable_amount: 1_000_000,
    admin_credential_hash: test_admin_pkh,
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_receiver_kyc: False,
  }
  Input {
    output_reference: OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    },
    output: Output {
      address: Address {
        payment_credential: Script(test_gs_policy_id),
        stake_credential: None,
      },
      value: from_asset(test_gs_policy_id, constants.global_state_asset_name, 1),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

// H-1 regression: `is_paused` must read the `transfers_paused` Bool correctly
// via UPLC builtins. The previous implementation in `transfer_logic_script`
// passed the fields *list* to `unconstr_index` (missing a `head_list` step)
// and crashed with UnConstrData on any call — making the pause gate a hard
// revert. These two tests exercise both branches of the flag, and ensure
// the fast-read still works after the datum reshape (TEL + admin added).

test is_paused_returns_false_when_unpaused() {
  is_paused(test_gs_input(False), test_gs_policy_id) == False
}

test is_paused_returns_true_when_paused() {
  is_paused(test_gs_input(True), test_gs_policy_id) == True
}

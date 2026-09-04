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

/// Where in a transaction the GlobalState UTxO is to be found.
///
/// A UTxO cannot be both spent and referenced — Conway rejects a transaction
/// whose `inputs` and `reference_inputs` overlap — so any validator that only
/// needs to READ the GlobalState datum must let the caller say which list it
/// is in, or it silently dictates the shape of every transaction it takes part
/// in. That is not hypothetical: a burn MUST spend GlobalState (only then does
/// `global_state_spend_validator`'s `MintSecurity` branch credit the burned
/// supply back to `mintable_amount`), and any co-running validator hard-wired
/// to `reference_inputs` makes that burn unbuildable.
///
/// Both forms are equally authentic: authenticity comes from the single
/// GlobalState NFT, which is present wherever the UTxO appears. What the two
/// forms do NOT share is whether the spend validator ran — so a caller that
/// needs the datum's constraints ENFORCED (rather than merely read) must
/// require `GlobalStateSpent` itself; this type deliberately does not decide
/// that for anyone.
pub type GlobalStateLocation {
  /// Index into `transaction.inputs`.
  GlobalStateSpent { global_state_input_index: Int }
  /// Index into `transaction.reference_inputs`.
  GlobalStateReferenced { global_state_ref_input_index: Int }
}

/// GlobalState datum — authenticated by the single global_state NFT.
///
/// INVARIANT: `transfers_paused` MUST remain at field index 0. The fast
/// pause-read via `is_paused` below relies on `unconstr_fields` + `head_list`
/// to pull the first field without deserialising the whole datum. Reshuffling
/// fields breaks that optimisation.
pub type GlobalStateDatum {
  //If true, no transfer can be executed
  transfers_paused: Bool,
  // If true, the protocol is deactivated and no action can be executed
  // This flag is irreversible and can only be set to true. It is meant to be used in case of decimissioning the protocol or in case of a critical bug that requires the protocol to be deactivated.
  // Can only be set if transfers are paused. Once set to true, it cannot be reverted back to false.
  deactivated: Bool,
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
  // Whether KYC is required for sending transfers.
  requires_sender_kyc: Bool,
  // Whether KYC is required for receiving transfers.
  requires_receiver_kyc: Bool,
  // Network this deployment targets
  // Bound into every KYC proof payload to prevent cross-network
  // replay. Set once at genesis and IMMUTABLE: every spend branch carries it
  // forward unchanged via `expected_datum`, so no action can ever alter it.
  network_id: Int,
  // Credential hash of the currently-active minting authority script (see
  // validators/minting_authority.ak). `minting_logic_script.ak` — the
  // permanent, CIP-113-registered proxy every registry node's
  // `minting_logic_script` field is frozen to forever — never encodes mint/
  // burn business rules (KYC, denylist, power-user roles) itself; for every
  // steady-state mint/burn it instead requires THIS credential's withdraw-0
  // to also be present in the same transaction, delegating the entire "is
  // this mint authorised" decision to whatever script this field currently
  // names. Rotatable in place via `RotateMintingScript`, admin-signed only —
  // this is the CIP-113 upgrade path: swap the authority implementation
  // (different KYC integration, different compliance rules, a bugfix)
  // without ever touching the registry or redeploying the proxy.
  //
  // DEPLOYMENT REQUIREMENT, not enforced on-chain: this must name a script
  // whose withdraw-0 genuinely decides whether a mint is allowed. Pointing
  // it at any OTHER withdraw-capable script in this deployment silently
  // disables every mint control — `transfer_logic_script` is the worst case,
  // since its withdraw-0 needs no signature at all, so anyone could then
  // mint up to the supply cap with no KYC, denylist or power-user checks.
  //
  // This is deliberately left to off-chain tooling rather than guarded here.
  // An on-chain reserved-hash list would not stop a malicious admin (who
  // would simply deploy their own permissive authority), and it would go
  // STALE the moment `transfer_logic_script` is upgraded through
  // `UpgradeRegistryNode` — the list is fixed at compile time, while the
  // scripts it names are not, and GlobalState cannot be redeployed to
  // refresh it because the NFT lives at its address.
  //
  // Verify instead at deployment and after every rotation, with a smoke test
  // that a mint lacking a power-user signature is REJECTED. The failure mode
  // is silent and fails OPEN, so it will not surface on its own.
  //
  // EXTEND THAT SMOKE TEST TO ALL FIVE POWER-USER ROLES. The warning
  // above is written about this field, but the mechanism is
  // `utils.must_be_signed_by_credential`, which gates `is_admin`, `can_mint`,
  // `can_burn`, `can_pause` and `can_force_transfer` identically. Any of those
  // credentials set to a permissive script hash is satisfiable by a stranger.
  // After granting or rotating any role, assert that an operation exercising
  // it without that operator's signature is REJECTED.
  minting_script_credential_hash: ByteArray,
  // ONE-WAY upgrade lock. While False (the genesis value) both upgrade paths
  // are open; once set True by `LockUpgrades` it can never be cleared — no
  // branch writes it back, and every branch reproduces the datum wholesale,
  // so there is no path that unsets it. Setting it permanently freezes:
  //
  //   * `RotateMintingScript` — the minting authority can no longer be
  //     swapped, so the mint/burn rules in force become final; and
  //   * the CIP-113 registry-node upgrade — `transfer_logic_script` and
  //     `third_party_transfer_logic_script` can no longer be re-pointed, so
  //     the transfer rules in force become final.
  //
  // This is the on-chain form of "this token's rules can no longer change",
  // meaningful to holders and regulators precisely BECAUSE an admin key
  // compromise cannot undo it.
  //
  // CONSEQUENCE OF IT BEING ONE FLAG RATHER THAN TWO: locking gives up the
  // ability to patch a buggy or compromised minting authority as well. After
  // this is set, the only remaining lever over the token is
  // `DeactivateContract`. Lock only when the deployment is considered final.
  upgrades_locked: Bool,
}

// ============================================================================
// Field accessors
// ============================================================================
// Field indices into the GlobalStateDatum Constr — the single source of truth
// for on-chain field order, shared by the getters below and by the spend
// validator's `replace_data_field` write path. Guarded by
// `gs_getters_read_correct_fields` (see Tests): reorder/insert/remove a field
// in GlobalStateDatum and that test fails, flagging every index user.

pub const idx_transfers_paused = 0

pub const idx_deactivated = 1

pub const idx_mintable_amount = 2

pub const idx_admin_credential_hash = 3

pub const idx_power_user_linked_list_policy_id = 4

pub const idx_denylist_linked_list_policy_id = 5

pub const idx_security_info = 6

pub const idx_trusted_entity_vkeys = 7

pub const idx_member_root_hash = 8

pub const idx_requires_sender_kyc = 9

pub const idx_requires_receiver_kyc = 10

pub const idx_network_id = 11

pub const idx_minting_script_credential_hash = 12

pub const idx_upgrades_locked = 13

// Getters take the already-unconstr'd field list (`builtin.unconstr_fields`),
// hiding the index + builtin unwrap behind a typed name. Reading several fields?
// Call `builtin.unconstr_fields` once and pass the list to each getter.

pub fn get_deactivated(fields: List<Data>) -> Bool {
  utils.data_to_bool(utils.safe_list_at(fields, idx_deactivated))
}

pub fn get_transfers_paused(fields: List<Data>) -> Bool {
  utils.data_to_bool(utils.safe_list_at(fields, idx_transfers_paused))
}

pub fn get_mintable_amount(fields: List<Data>) -> Int {
  builtin.un_i_data(utils.safe_list_at(fields, idx_mintable_amount))
}

pub fn get_admin_credential_hash(fields: List<Data>) -> ByteArray {
  builtin.un_b_data(utils.safe_list_at(fields, idx_admin_credential_hash))
}

pub fn get_power_user_linked_list_policy_id(fields: List<Data>) -> ByteArray {
  builtin.un_b_data(
    utils.safe_list_at(fields, idx_power_user_linked_list_policy_id),
  )
}

pub fn get_denylist_linked_list_policy_id(fields: List<Data>) -> ByteArray {
  builtin.un_b_data(
    utils.safe_list_at(fields, idx_denylist_linked_list_policy_id),
  )
}

pub fn get_security_info(fields: List<Data>) -> Data {
  utils.safe_list_at(fields, idx_security_info)
}

pub fn get_trusted_entity_vkeys(
  fields: List<Data>,
) -> Pairs<ByteArray, TrustedEntityMetadata> {
  expect entries: Pairs<ByteArray, TrustedEntityMetadata> = utils.safe_list_at(
    fields,
    idx_trusted_entity_vkeys,
  )
  entries
}

pub fn get_member_root_hash(fields: List<Data>) -> ByteArray {
  builtin.un_b_data(utils.safe_list_at(fields, idx_member_root_hash))
}

pub fn get_requires_sender_kyc(fields: List<Data>) -> Bool {
  utils.data_to_bool(utils.safe_list_at(fields, idx_requires_sender_kyc))
}

pub fn get_requires_receiver_kyc(fields: List<Data>) -> Bool {
  utils.data_to_bool(utils.safe_list_at(fields, idx_requires_receiver_kyc))
}

pub fn get_network_id(fields: List<Data>) -> Int {
  builtin.un_i_data(utils.safe_list_at(fields, idx_network_id))
}

pub fn get_minting_script_credential_hash(fields: List<Data>) -> ByteArray {
  builtin.un_b_data(
    utils.safe_list_at(fields, idx_minting_script_credential_hash),
  )
}

pub fn get_upgrades_locked(fields: List<Data>) -> Bool {
  utils.data_to_bool(utils.safe_list_at(fields, idx_upgrades_locked))
}

// Setters mirror the getters: each rebuilds the GlobalStateDatum `Data` from the
// field list with exactly one field replaced, hiding the constructor index, the
// index, and the typed->Data conversion. Aiken inlines these, so there's no
// runtime cost over the raw builtins. Guarded by `gs_setters_round_trip`.

pub fn set_deactivated(fields: List<Data>, value: Bool) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(fields, idx_deactivated, utils.bool_to_data(value)),
  )
}

pub fn set_transfers_paused(fields: List<Data>, value: Bool) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(
      fields,
      idx_transfers_paused,
      utils.bool_to_data(value),
    ),
  )
}

pub fn set_mintable_amount(fields: List<Data>, value: Int) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(fields, idx_mintable_amount, builtin.i_data(value)),
  )
}

pub fn set_admin_credential_hash(fields: List<Data>, value: ByteArray) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(
      fields,
      idx_admin_credential_hash,
      builtin.b_data(value),
    ),
  )
}

pub fn set_security_info(fields: List<Data>, value: Data) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(fields, idx_security_info, value),
  )
}

pub fn set_trusted_entity_vkeys(
  fields: List<Data>,
  value: Pairs<ByteArray, TrustedEntityMetadata>,
) -> Data {
  let value_data: Data = value
  builtin.constr_data(
    0,
    utils.replace_data_field(fields, idx_trusted_entity_vkeys, value_data),
  )
}

pub fn set_member_root_hash(fields: List<Data>, value: ByteArray) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(
      fields,
      idx_member_root_hash,
      builtin.b_data(value),
    ),
  )
}

pub fn set_requires_sender_kyc(fields: List<Data>, value: Bool) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(
      fields,
      idx_requires_sender_kyc,
      utils.bool_to_data(value),
    ),
  )
}

pub fn set_requires_receiver_kyc(fields: List<Data>, value: Bool) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(
      fields,
      idx_requires_receiver_kyc,
      utils.bool_to_data(value),
    ),
  )
}

pub fn set_upgrades_locked(fields: List<Data>, value: Bool) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(
      fields,
      idx_upgrades_locked,
      utils.bool_to_data(value),
    ),
  )
}

pub fn set_minting_script_credential_hash(
  fields: List<Data>,
  value: ByteArray,
) -> Data {
  builtin.constr_data(
    0,
    utils.replace_data_field(
      fields,
      idx_minting_script_credential_hash,
      builtin.b_data(value),
    ),
  )
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
  get_transfers_paused(builtin.unconstr_fields(gs_datum))
}

pub fn is_deactivated(
  gs_input: Input,
  global_state_policy_id: ByteArray,
) -> Bool {
  expect
    quantity_of(
      gs_input.output.value,
      global_state_policy_id,
      constants.global_state_asset_name,
    ) > 0
  expect InlineDatum(gs_datum) = gs_input.output.datum
  get_deactivated(builtin.unconstr_fields(gs_datum))
}

/// Resolves GlobalState from wherever the caller says it is, authenticates it
/// via the GS NFT, and returns its parsed inline datum.
///
/// Use this instead of `gs_datum_from_ref_input` in any validator that merely
/// READS the datum. Pinning such a validator to reference inputs forbids every
/// transaction that must also spend GlobalState — see `GlobalStateLocation`.
///
/// Fails (UPLC error) if: index out of range, NFT missing, datum non-inline,
/// or datum shape invalid.
pub fn gs_datum_from_location(
  inputs: List<Input>,
  reference_inputs: List<Input>,
  location: GlobalStateLocation,
  global_state_policy_id: ByteArray,
) -> GlobalStateDatum {
  let gs_output = when location is {
    GlobalStateSpent { global_state_input_index } ->
      utils.safe_list_at(inputs, global_state_input_index).output
    GlobalStateReferenced { global_state_ref_input_index } ->
      utils.safe_list_at(reference_inputs, global_state_ref_input_index).output
  }
  gs_datum_from_output(gs_output, global_state_policy_id)
}

/// Resolves the GS reference input at `ref_index`, authenticates it via the GS
/// NFT, and returns its parsed inline datum. Helper for validators (power_users,
/// denylist) that read protocol state from the GS datum instead of holding a
/// compile-time owner parameter.
///
/// Fails (UPLC error) if: index out of range, NFT missing, datum non-inline,
/// or datum shape invalid.
pub fn gs_datum_from_ref_input(
  reference_inputs: List<Input>,
  ref_index: Int,
  global_state_policy_id: ByteArray,
) -> GlobalStateDatum {
  gs_datum_from_output(
    utils.safe_list_at(reference_inputs, ref_index).output,
    global_state_policy_id,
  )
}

/// Authenticates a UTxO as the real GlobalState and returns its datum.
///
/// Holding the single GlobalState NFT is what proves authenticity: it is
/// minted exactly once, at genesis, against a one-shot UTxO reference that
/// can never be consumed again, and `global_state_spend_validator` preserves
/// it in the continuing output on every branch. So a UTxO carrying it IS the
/// GlobalState, wherever it appears — spent as an input or merely
/// referenced. Callers that need the supply cap enforced must additionally
/// ensure it is SPENT (only then does the spend validator's `MintSecurity`
/// branch run); this function alone does not distinguish the two.
pub fn gs_datum_from_output(
  gs_output: Output,
  global_state_policy_id: ByteArray,
) -> GlobalStateDatum {
  expect
    quantity_of(
      gs_output.value,
      global_state_policy_id,
      constants.global_state_asset_name,
    ) == 1
  expect InlineDatum(gs_raw) = gs_output.datum
  expect gs: GlobalStateDatum = gs_raw
  gs
}

/// Read the admin credential from an authenticated GlobalState reference
/// input, rejecting (trapping) if the protocol is `deactivated`.
///
/// Every admin-gated caller uses this one. A plain "read the admin" variant
/// without the deactivation check existed alongside it and was removed as dead
/// code — deliberately, so there is no second reader for a future caller to
/// pick up by mistake. A decommissioned protocol must execute no further
/// administrative action, matching the `deactivated` field contract ("no
/// action can be executed").
pub fn active_admin_from_ref_input(
  reference_inputs: List<Input>,
  ref_index: Int,
  global_state_policy_id: ByteArray,
) -> ByteArray {
  let gs = gs_datum_from_ref_input(
    reference_inputs,
    ref_index,
    global_state_policy_id,
  )
  expect !gs.deactivated
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
  SetRequiresSenderKyc { enabled: Bool }
  SetRequiresReceiverKyc { enabled: Bool }
  UpdateMemberRootHash { new_member_root_hash: ByteArray }
  RotateAdmin { new_admin_credential_hash: ByteArray }
  /// Swaps which script's withdraw-0 minting_logic_script.ak (the permanent
  /// CIP-113 proxy) delegates mint/burn authorisation to. Admin-signed only
  /// — deliberately single-signature, unlike RotateAdmin/dual-sig patterns
  /// elsewhere: the outgoing authority's own consent is not required, since
  /// an authority being replaced (e.g. because it is buggy or compromised)
  /// is exactly the scenario this action needs to handle even when that
  /// script itself can no longer be trusted to co-sign.
  RotateMintingScript { new_minting_script_credential_hash: ByteArray }
  /// ONE-WAY upgrade lock — see `upgrades_locked`. Admin-signed, and
  /// deliberately not reversible: a lock an admin can lift is not a
  /// commitment. Rejected if already locked, so the action is not a silent
  /// no-op.
  ///
  /// ONE NUANCE, recorded rather than blocked. Since `UpgradeRegistryNode`
  /// takes a `GlobalStateLocation`, an admin may put the lock and a final
  /// upgrade in the SAME transaction: the upgrade reads GlobalState as a spent
  /// input, and a spent input is the pre-state, so it sees
  /// `upgrades_locked == False` and proceeds. The lock still takes effect —
  /// every LATER transaction is refused.
  ///
  /// Not treated as a defect: it needs the admin's own signature, and the same
  /// admin can always upgrade first and lock second in two transactions, so it
  /// grants no power that did not already exist. What it does mean is that
  /// "locked at slot N" does not imply "no upgrade at slot N", only "none after
  /// it" — worth knowing when auditing the chain.
  ///
  /// THE SAME SHAPE RECURS BEYOND LockUpgrades, for the identical structural
  /// reason: any admin-only action paired, in the SAME transaction, with a
  /// registry-node upgrade or other structural registration that reads
  /// GlobalState as a spent input sees the pre-state datum. `RotateAdmin` plus
  /// an upgrade signed by the OUTGOING admin in that same transaction still
  /// succeeds, because the upgrade's read of `admin_credential_hash` happens
  /// against the value before this spend's write takes effect.
  /// `DeactivateContract` plus a final upgrade in the same transaction is the
  /// same LockUpgrades-shaped case again. All of these are admin-only and are
  /// recorded on-chain as accepted at the exact moment they happen — nothing
  /// is hidden, only foreclosed one transaction later than a naive reading of
  /// "already locked/rotated/deactivated" would suggest. What none of this
  /// reopens is token movement: that path is closed independently, by
  /// `no_security_token_spent` in the spend validator, which every
  /// non-MintSecurity branch composes regardless of which field it touches.
  LockUpgrades
  /// One-way decommissioning switch. Sets `deactivated = True`. Requires the
  /// contract to already be paused and the admin to sign. Irreversible: no
  /// action sets it back to False, and once set every spend of the
  /// global_state UTxO is rejected (see the terminal guard in the spend
  /// validator), which permanently freezes transfers (stays paused) and
  /// mint/burn (MintSecurity can no longer run).
  DeactivateContract
}

pub type GlobalStateSpendRedeemer {
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
  test_gs_input_with(transfers_paused, False)
}

fn test_gs_input_with(transfers_paused: Bool, deactivated: Bool) -> Input {
  let datum = GlobalStateDatum {
    transfers_paused,
    deactivated,
    mintable_amount: 1_000_000,
    admin_credential_hash: test_admin_pkh,
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: False,
    requires_receiver_kyc: False,
    network_id: 1,
    minting_script_credential_hash: #"",
    upgrades_locked: False,
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

// active_admin_from_ref_input returns the admin when the protocol is live…
test active_admin_returns_admin_when_not_deactivated() {
  active_admin_from_ref_input(
    [test_gs_input_with(True, False)],
    0,
    test_gs_policy_id,
  ) == test_admin_pkh
}

// …and traps (blocking all admin-gated list actions) once deactivated.
test active_admin_traps_when_deactivated() fail {
  active_admin_from_ref_input(
    [test_gs_input_with(True, True)],
    0,
    test_gs_policy_id,
  ) == test_admin_pkh
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

// Shared fixture with a distinct value per field, so a mis-indexed read/write
// is detectable.
fn test_layout_datum() -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: True,
    deactivated: False,
    mintable_amount: 42,
    admin_credential_hash: #"a2",
    power_user_linked_list_policy_id: #"a3",
    denylist_linked_list_policy_id: #"a4",
    security_info: builtin.i_data(5),
    trusted_entity_vkeys: [Pair(#"a6", builtin.i_data(60))],
    member_root_hash: #"a7",
    requires_sender_kyc: True,
    requires_receiver_kyc: True,
    network_id: 9,
    minting_script_credential_hash: #"a8",
    upgrades_locked: True,
  }
}

// Tripwire for the field-index layer. Each getter (index access) is compared to
// the same field accessed BY NAME. Index access is order-dependent; name access
// is not — so reordering, inserting or removing a GlobalStateDatum field breaks
// this test, flagging every index user (the getters AND the spend validator's
// write branches, which go through the setters that share the `idx_*` constants).
test gs_getters_read_correct_fields() {
  let d = test_layout_datum()
  let fields = builtin.unconstr_fields(d)
  and {
    get_transfers_paused(fields) == d.transfers_paused,
    get_deactivated(fields) == d.deactivated,
    get_mintable_amount(fields) == d.mintable_amount,
    get_admin_credential_hash(fields) == d.admin_credential_hash,
    get_power_user_linked_list_policy_id(fields) == d.power_user_linked_list_policy_id,
    get_denylist_linked_list_policy_id(fields) == d.denylist_linked_list_policy_id,
    builtin.equals_data(get_security_info(fields), d.security_info),
    get_trusted_entity_vkeys(fields) == d.trusted_entity_vkeys,
    get_member_root_hash(fields) == d.member_root_hash,
    get_requires_sender_kyc(fields) == d.requires_sender_kyc,
    get_requires_receiver_kyc(fields) == d.requires_receiver_kyc,
    get_network_id(fields) == d.network_id,
    get_minting_script_credential_hash(fields) == d.minting_script_credential_hash,
    get_upgrades_locked(fields) == d.upgrades_locked,
  }
}

// Each setter must equal the same datum rebuilt BY NAME with one field changed —
// pinning the constructor index, the field index, and (for Bools) the 0/1
// encoding that getter tests alone don't cover. New values differ from `d` so
// the change is actually exercised.
test gs_setters_round_trip() {
  let d = test_layout_datum()
  let fields = builtin.unconstr_fields(d)
  and {
    builtin.equals_data(
      set_transfers_paused(fields, False),
      GlobalStateDatum { ..d, transfers_paused: False },
    ),
    builtin.equals_data(
      set_deactivated(fields, True),
      GlobalStateDatum { ..d, deactivated: True },
    ),
    builtin.equals_data(
      set_mintable_amount(fields, 999),
      GlobalStateDatum { ..d, mintable_amount: 999 },
    ),
    builtin.equals_data(
      set_admin_credential_hash(fields, #"de"),
      GlobalStateDatum { ..d, admin_credential_hash: #"de" },
    ),
    builtin.equals_data(
      set_security_info(fields, builtin.i_data(77)),
      GlobalStateDatum { ..d, security_info: builtin.i_data(77) },
    ),
    builtin.equals_data(
      set_trusted_entity_vkeys(fields, [Pair(#"bb", builtin.i_data(1))]),
      GlobalStateDatum {
        ..d,
        trusted_entity_vkeys: [Pair(#"bb", builtin.i_data(1))],
      },
    ),
    builtin.equals_data(
      set_member_root_hash(fields, #"cd"),
      GlobalStateDatum { ..d, member_root_hash: #"cd" },
    ),
    builtin.equals_data(
      set_requires_sender_kyc(fields, False),
      GlobalStateDatum { ..d, requires_sender_kyc: False },
    ),
    builtin.equals_data(
      set_requires_receiver_kyc(fields, False),
      GlobalStateDatum { ..d, requires_receiver_kyc: False },
    ),
    builtin.equals_data(
      set_minting_script_credential_hash(fields, #"ef"),
      GlobalStateDatum { ..d, minting_script_credential_hash: #"ef" },
    ),
    builtin.equals_data(
      set_upgrades_locked(fields, False),
      GlobalStateDatum { ..d, upgrades_locked: False },
    ),
  }
}

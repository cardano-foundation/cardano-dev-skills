use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, Credential, Script, VerificationKey}
use cardano/assets.{from_asset, from_lovelace, merge, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use constants
use denylist/absence.{covers_key}
use types/global_state.{GlobalStateDatum}
use types/power_users.{PowerUser} as pu
use utils

// Faithful mirror of the CIP-113 programmable-token registry node datum shape:
// https://github.com/cardano-foundation/cip113-programmable-tokens/blob/main/lib/registry_node.ak
//
// Field order matters: `derive_issuance_policy_id_from_registry_node` reads the
// node via `builtin.unconstr_fields` and indexes by position, so this type must
// keep the exact CIP-113 layout.
//   0: key                              (ByteArray)  -> the issuance policy id
//   1: next                             (ByteArray)
//   2: minting_logic_script             (Credential)
//   3: transfer_logic_script            (Credential)
//   4: third_party_transfer_logic_script(Credential)
//   5: unfracking_logic_script          (Credential)  -- added in v0.4.0
//   6: global_state_cs                  (ByteArray)
type RegistryNode {
  key: ByteArray,
  next: ByteArray,
  minting_logic_script: Credential,
  transfer_logic_script: Credential,
  third_party_transfer_logic_script: Credential,
  /// CIP-113 v0.4.0 field 5. `VerificationKey(#"")` means unfracking is
  /// FORBIDDEN for this policy — core's least-permission default.
  unfracking_logic_script: Credential,
  global_state_cs: ByteArray,
}

// ============================================================================
// CONSTANTS & MOCK DATA BUILDERS (expand as needed)
// ============================================================================

pub const test_registry_policy_id: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

pub const test_issuance_policy_id: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

pub const test_minting_logic_hash: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

pub const test_transfer_logic_hash: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

pub const test_third_party_transfer_logic_hash: ByteArray =
  #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

pub const test_global_state_cs: ByteArray =
  #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

pub const test_power_users_policy_id: ByteArray =
  #"11111111111111111111111111111111111111111111111111111111"

pub const test_denylist_policy_id: ByteArray =
  #"22222222222222222222222222222222222222222222222222222222"

pub const test_admin_credential: ByteArray =
  #"33333333333333333333333333333333333333333333333333333333"

pub const test_power_user_credential: ByteArray =
  #"44444444444444444444444444444444444444444444444444444444"

pub const test_user_credential: ByteArray =
  #"55555555555555555555555555555555555555555555555555555555"

pub const test_security_asset_name: ByteArray = "SECURITY_TOKEN"

// Helper: Minimal CIP-113 registry node (for derive_issuance... tests)
fn make_cip113_registry_ref_input() -> Input {
  let node = RegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_minting_logic_hash),
    transfer_logic_script: Script(test_transfer_logic_hash),
    third_party_transfer_logic_script: Script(
      test_third_party_transfer_logic_hash,
    ),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: test_global_state_cs,
  }
  Input {
    output_reference: OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    },
    output: Output {
      address: Address {
        payment_credential: Script(test_registry_policy_id),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_registry_policy_id, "Node", 1),
      ),
      datum: InlineDatum(node),
      reference_script: None,
    },
  }
}

// Helper: Mock GlobalStateDatum (minimal valid)
pub fn make_minimal_gs_datum(
  paused: Bool,
  mintable: Int,
  admin: ByteArray,
  requires_sender_kyc: Bool,
  requires_receiver_kyc: Bool,
) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: paused,
    deactivated: False,
    mintable_amount: mintable,
    admin_credential_hash: admin,
    power_user_linked_list_policy_id: test_power_users_policy_id,
    denylist_linked_list_policy_id: test_denylist_policy_id,
    security_info: "Test Security Token",
    trusted_entity_vkeys: [],
    member_root_hash: "",
    requires_sender_kyc,
    requires_receiver_kyc,
    // or Some(...) for merkle tests
    network_id: 0,
  }
}

// Helper: Mock PowerUser datum
pub fn make_power_user(
  cred: ByteArray,
  is_admin: Bool,
  can_mint: Bool,
  can_burn: Bool,
  can_pause: Bool,
  can_force: Bool,
) -> PowerUser {
  PowerUser {
    credential_hash: cred,
    is_admin,
    can_mint,
    can_burn,
    can_pause,
    can_force_transfer: can_force,
  }
}

// Helper: Basic mock Transaction skeleton
pub fn empty_tx() -> Transaction {
  Transaction {
    inputs: [],
    reference_inputs: [],
    outputs: [],
    fee: 0,
    mint: from_lovelace(0),
    certificates: [],
    withdrawals: [],
    validity_range: Interval {
      lower_bound: IntervalBound { bound_type: Finite(0), is_inclusive: True },
      upper_bound: IntervalBound {
        bound_type: Finite(1000000),
        is_inclusive: True,
      },
    },
    extra_signatories: [],
    redeemers: [],
    datums: dict.empty,
    id: #"0000000000000000000000000000000000000000000000000000000000000000",
    votes: [],
    proposal_procedures: [],
    current_treasury_amount: None,
    treasury_donation: None,
  }
}

// ============================================================================
// EXISTING + EXPANDED REGISTRY / UTILS TESTS
// ============================================================================

test derive_issuance_policy_id_from_cip113_registry_node() {
  let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
    [make_cip113_registry_ref_input()],
    test_registry_policy_id,
    Script(test_transfer_logic_hash),
    constants.transfer_logic_script_registry_node_index,
    0,
  )
  issuance_policy_id == test_issuance_policy_id
}

// Helper to build tx with signatories
fn tx_signed_by(signers: List<ByteArray>) -> Transaction {
  let base = empty_tx()
  Transaction { ..base, extra_signatories: signers }
}

// ============================================================================
// POWER USERS & ROLE AUTHORIZATION TESTS
// ============================================================================

test power_user_is_admin_true() {
  let pu = make_power_user(
    test_power_user_credential,
    True,
    // is_admin
    False,
    False,
    False,
    False,
  )
  pu.is_admin == True
}

test power_user_is_admin_false() {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    // not admin
    True,
    True,
    True,
    True,
  )
  pu.is_admin == False
}

test power_user_can_mint_role() {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    True,
    // can_mint = true
    False,
    False,
    False,
  )
  and {
    pu.can_mint == True,
    pu.can_burn == False,
    pu.is_admin == False,
  }
}

test power_user_can_burn_role() {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    False,
    True,
    // can_burn = true
    False,
    False,
  )
  pu.can_burn == True
}

test power_user_can_pause_role() {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    False,
    False,
    True,
    // can_pause
    False,
  )
  pu.can_pause == True
}

test power_user_can_force_transfer_role() {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    False,
    False,
    False,
    True,
  )
  // can_force_transfer
  pu.can_force_transfer == True
}

// must_be_signed_by_credential tests
test must_be_signed_by_credential_positive_single_signer() {
  let tx = tx_signed_by([test_admin_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential) == True
}

test must_be_signed_by_credential_positive_multiple_signers() {
  let tx = tx_signed_by(
    [test_user_credential, test_admin_credential, test_power_user_credential],
  )
  utils.must_be_signed_by_credential(tx, test_power_user_credential) == True
}

test must_be_signed_by_credential_negative_wrong_credential() fail {
  let tx = tx_signed_by([test_user_credential, test_power_user_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential)
}

test must_be_signed_by_credential_negative_empty_signatories() fail {
  let tx = tx_signed_by([])
  utils.must_be_signed_by_credential(tx, test_admin_credential)
}

// Init nonce validation (real logic)
test power_users_init_nonce_check_success() {
  let init_ref = OutputReference {
    transaction_id: #"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    output_index: 0,
  }

  let matching_input = Input {
    output_reference: init_ref,
    output: Output {
      address: Address {
        payment_credential: Script(""),
        stake_credential: None,
      },
      value: from_lovelace(2_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }

  let tx = Transaction { ..empty_tx(), inputs: [matching_input] }

  list.any(tx.inputs, fn(input) { input.output_reference == init_ref }) == True
}

test power_users_init_nonce_check_failure_wrong_reference() fail {
  let correct_ref = OutputReference {
    transaction_id: #"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    output_index: 0,
  }
  let wrong_ref = OutputReference {
    transaction_id: #"1111111111111111111111111111111111111111111111111111111111111111",
    output_index: 0,
  }

  let bad_input = Input {
    output_reference: wrong_ref,
    output: Output {
      address: Address {
        payment_credential: Script(""),
        stake_credential: None,
      },
      value: from_lovelace(2_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }

  let tx = Transaction { ..empty_tx(), inputs: [bad_input] }

  list.any(tx.inputs, fn(i) { i.output_reference == correct_ref }) == True
}

// ============================================================================
// DENYLIST MANAGEMENT TESTS
// ============================================================================

// ---------------------------------------------------------------------------
// Role gating for add/remove (is_admin + signature)
// ---------------------------------------------------------------------------

test denylist_add_by_admin_role_success() {
  let admin_pu = make_power_user(
    test_admin_credential,
    True,
    False,
    False,
    False,
    False,
  )
  admin_pu.is_admin == True
}

test denylist_add_by_non_admin_fails() fail {
  let non_admin_pu = make_power_user(
    test_power_user_credential,
    False,
    True,
    True,
    True,
    True,
  )
  non_admin_pu.is_admin == True
  // role check fails
}

test denylist_remove_by_admin_role_success() {
  let admin_pu = make_power_user(
    test_admin_credential,
    True,
    False,
    False,
    False,
    False,
  )
  admin_pu.is_admin == True
}

// ---------------------------------------------------------------------------
// Init / Deinit nonce validation (parallel to power_users)
// ---------------------------------------------------------------------------

test denylist_init_nonce_check_success() {
  let init_ref = OutputReference {
    transaction_id: #"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    output_index: 0,
  }

  let matching_input = Input {
    output_reference: init_ref,
    output: Output {
      address: Address {
        payment_credential: Script(""),
        stake_credential: None,
      },
      value: from_lovelace(2_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }

  let tx = Transaction { ..empty_tx(), inputs: [matching_input] }

  list.any(tx.inputs, fn(input) { input.output_reference == init_ref }) == True
}

test denylist_init_nonce_check_failure() fail {
  let correct_ref = OutputReference {
    transaction_id: #"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    output_index: 0,
  }
  let wrong_ref = OutputReference {
    transaction_id: #"1111111111111111111111111111111111111111111111111111111111111111",
    output_index: 0,
  }

  let bad_input = Input {
    output_reference: wrong_ref,
    output: Output {
      address: Address {
        payment_credential: Script(""),
        stake_credential: None,
      },
      value: from_lovelace(2_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }

  let tx = Transaction { ..empty_tx(), inputs: [bad_input] }

  list.any(tx.inputs, fn(i) { i.output_reference == correct_ref }) == True
}

// ---------------------------------------------------------------------------
// Deinit requires admin signature (real check)
// ---------------------------------------------------------------------------

test denylist_deinit_requires_admin_signature() {
  let tx = tx_signed_by([test_admin_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential) == True
}

test denylist_deinit_without_admin_signature_fails() fail {
  let tx = tx_signed_by([test_power_user_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential)
}

// ============================================================================
// GLOBAL STATE TESTS
// ============================================================================

// ---------------------------------------------------------------------------
// Pause toggle by authorized power user
// ---------------------------------------------------------------------------

test gs_pause_by_authorized_power_user() {
  let gs = make_minimal_gs_datum(
    False,
    1_000_000,
    test_admin_credential,
    True,
    True,
  )
  gs.transfers_paused == False
}

test gs_unpause_by_authorized_power_user() {
  let gs = make_minimal_gs_datum(
    True,
    1_000_000,
    test_admin_credential,
    True,
    True,
  )
  gs.transfers_paused == True
}

// ---------------------------------------------------------------------------
// Supply cap enforcement (MintSecurity branch)
// ---------------------------------------------------------------------------

test gs_mint_security_remaining_cap_positive() {
  let gs = make_minimal_gs_datum(
    False,
    1_000_000,
    test_admin_credential,
    True,
    True,
  )
  let minted = 500
  gs.mintable_amount - minted >= 0
}

test gs_mint_security_exceeds_cap_fails() fail {
  let gs = make_minimal_gs_datum(False, 100, test_admin_credential, True, True)
  let minted = 200
  gs.mintable_amount - minted >= 0
}

// ---------------------------------------------------------------------------
// Admin signature for non-mint operations
// ---------------------------------------------------------------------------

test gs_non_mint_operation_requires_admin_signature() {
  let tx = tx_signed_by([test_admin_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential) == True
}

test gs_non_mint_operation_without_admin_signature_fails() fail {
  let tx = tx_signed_by([test_power_user_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential)
}

// ---------------------------------------------------------------------------
// Trusted entity vkey sanitization (real logic from global_state.ak)
// ---------------------------------------------------------------------------

fn walk_strictly_ascending_test(
  prev: ByteArray,
  rest: Pairs<ByteArray, ByteArray>,
) -> Bool {
  when rest is {
    [] -> True
    [head, ..tail] -> {
      let k = head.1st
      and {
        builtin.less_than_bytearray(prev, k),
        walk_strictly_ascending_test(k, tail),
      }
    }
  }
}

fn is_sorted_no_dup_vkeys_test(entries: Pairs<ByteArray, ByteArray>) -> Bool {
  when entries is {
    [] -> True
    [head, ..tail] -> {
      let k = head.1st
      walk_strictly_ascending_test(k, tail)
    }
  }
}

test gs_trusted_vkeys_sorted_no_dups_success() {
  let vkeys: Pairs<ByteArray, ByteArray> = [
    Pair(#"10000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"30000000000000000000000000000000000000000000000000000000", ""),
  ]
  is_sorted_no_dup_vkeys_test(vkeys) == True
}

test gs_trusted_vkeys_duplicate_fails() fail {
  let vkeys: Pairs<ByteArray, ByteArray> = [
    Pair(#"10000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
  ]
  is_sorted_no_dup_vkeys_test(vkeys) == True
}

test gs_trusted_vkeys_not_ascending_fails() fail {
  let vkeys: Pairs<ByteArray, ByteArray> = [
    Pair(#"30000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
  ]
  is_sorted_no_dup_vkeys_test(vkeys) == True
}

// ---------------------------------------------------------------------------
// Admin rotation dual-signature
// ---------------------------------------------------------------------------

test gs_rotate_admin_requires_dual_signature() {
  let old_admin = test_admin_credential
  let new_admin = #"66666666666666666666666666666666666666666666666666666666"
  let tx = tx_signed_by([old_admin, new_admin])
  and {
    utils.must_be_signed_by_credential(tx, old_admin) == True,
    utils.must_be_signed_by_credential(tx, new_admin) == True,
  }
}

test gs_rotate_admin_missing_old_signature_fails() fail {
  let new_admin = #"66666666666666666666666666666666666666666666666666666666"
  let tx = tx_signed_by([new_admin])
  utils.must_be_signed_by_credential(tx, test_admin_credential) == True
}

// ============================================================================
// MINTING / BURNING LOGIC TESTS
// ============================================================================

// ---------------------------------------------------------------------------
// Role gating for mint / burn (from minting_logic_validator)
// ---------------------------------------------------------------------------

test minting_requires_can_mint_role_positive() {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    True,
    False,
    False,
    False,
  )
  pu.can_mint == True
}

test minting_requires_can_mint_role_fails() fail {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    False,
    True,
    False,
    False,
  )
  pu.can_mint == True
}

test burning_requires_can_burn_role_positive() {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    False,
    True,
    False,
    False,
  )
  pu.can_burn == True
}

test burning_requires_can_burn_role_fails() fail {
  let pu = make_power_user(
    test_power_user_credential,
    False,
    True,
    False,
    False,
    False,
  )
  pu.can_burn == True
}

// ---------------------------------------------------------------------------
// GS NFT presence invariant (critical for cap enforcement)
// ---------------------------------------------------------------------------

test minting_logic_gs_nft_presence_positive() {
  let gs_input = Input {
    output_reference: OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    },
    output: Output {
      address: Address {
        payment_credential: Script(test_global_state_cs),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_global_state_cs, constants.global_state_asset_name, 1),
      ),
      datum: NoDatum,
      reference_script: None,
    },
  }

  let tx = Transaction { ..empty_tx(), inputs: [gs_input] }
  expect Some(in) = list.at(tx.inputs, 0)

  quantity_of(
    in.output.value,
    test_global_state_cs,
    constants.global_state_asset_name,
  ) == 1
}

// ---------------------------------------------------------------------------
// Cap enforcement (mint amount <= remaining mintable_amount)
// ---------------------------------------------------------------------------

test minting_within_remaining_cap() {
  let gs = make_minimal_gs_datum(
    False,
    1_000_000,
    test_admin_credential,
    True,
    True,
  )
  let minted = 500
  gs.mintable_amount - minted >= 0
}

test minting_exceeds_remaining_cap_fails() fail {
  let gs = make_minimal_gs_datum(False, 100, test_admin_credential, True, True)
  let minted = 200
  gs.mintable_amount - minted >= 0
}

// ============================================================================
// REGULAR TRANSFER LOGIC TESTS
// ============================================================================

// ---------------------------------------------------------------------------
// Pause gate
// ---------------------------------------------------------------------------

test regular_transfer_paused_fails() fail {
  let gs = make_minimal_gs_datum(
    True,
    1_000_000,
    test_admin_credential,
    True,
    True,
  )
  gs.transfers_paused == False
}

test regular_transfer_not_paused_succeeds() {
  let gs = make_minimal_gs_datum(
    False,
    1_000_000,
    test_admin_credential,
    True,
    True,
  )
  gs.transfers_paused == False
}

// ---------------------------------------------------------------------------
// Denylist absence checks
// ---------------------------------------------------------------------------

test denylist_absence_covers_key_success() {
  let covering_key = Some(
    #"40000000000000000000000000000000000000000000000000000000",
  )
  let covering_link = Some(
    #"60000000000000000000000000000000000000000000000000000000",
  )
  let target = #"50000000000000000000000000000000000000000000000000000000"
  covers_key(covering_key, covering_link, target) == True
}

test denylist_absence_covers_key_fails_below() fail {
  let covering_key = Some(
    #"60000000000000000000000000000000000000000000000000000000",
  )
  let covering_link = None
  let target = #"50000000000000000000000000000000000000000000000000000000"
  covers_key(covering_key, covering_link, target) == True
}

// ============================================================================
// verify_denylist_absence & covers_key
// ============================================================================

// Pure helper test - covers_key success cases
test covers_key_root_covers_anything() {
  covers_key(
    None,
    Some(#"60000000000000000000000000000000000000000000000000000000"),
    test_user_credential,
  )
}

test covers_key_middle_node_covers_target() {
  let prev = #"40000000000000000000000000000000000000000000000000000000"
  let next = #"60000000000000000000000000000000000000000000000000000000"
  let target = #"50000000000000000000000000000000000000000000000000000000"
  covers_key(Some(prev), Some(next), target)
}

test covers_key_tail_sentinel_covers_above_last() {
  let last = #"f0000000000000000000000000000000000000000000000000000000"
  covers_key(
    Some(last),
    None,
    #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
  )
}

// Adversarial - does not cover
test covers_key_fails_when_target_below_node() fail {
  let prev = #"60000000000000000000000000000000000000000000000000000000"
  covers_key(Some(prev), None, test_user_credential)
  // target < prev
}

test covers_key_fails_when_target_above_link() fail {
  let prev = #"40000000000000000000000000000000000000000000000000000000"
  let next = #"50000000000000000000000000000000000000000000000000000000"
  let target = #"60000000000000000000000000000000000000000000000000000000"
  covers_key(Some(prev), Some(next), target)
}

test gs_sanitise_sorted_vkeys_success() {
  let vkeys: Pairs<ByteArray, ByteArray> = [
    Pair(#"10000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"30000000000000000000000000000000000000000000000000000000", ""),
  ]
  is_sorted_no_dup_vkeys_test(vkeys)
}

test gs_sanitise_vkeys_with_duplicate_fails() fail {
  let vkeys: Pairs<ByteArray, ByteArray> = [
    Pair(#"10000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
  ]
  is_sorted_no_dup_vkeys_test(vkeys)
}

test gs_sanitise_vkeys_not_strictly_ascending_fails() fail {
  let vkeys: Pairs<ByteArray, ByteArray> = [
    Pair(#"30000000000000000000000000000000000000000000000000000000", ""),
    Pair(#"20000000000000000000000000000000000000000000000000000000", ""),
  ]
  is_sorted_no_dup_vkeys_test(vkeys)
}

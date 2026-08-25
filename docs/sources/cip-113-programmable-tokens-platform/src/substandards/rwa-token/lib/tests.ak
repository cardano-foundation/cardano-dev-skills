use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, Credential, Script, VerificationKey}
use cardano/assets.{from_asset, from_lovelace, merge}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use constants
use denylist/absence.{covers_key}
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

pub const test_admin_credential: ByteArray =
  #"33333333333333333333333333333333333333333333333333333333"

pub const test_power_user_credential: ByteArray =
  #"44444444444444444444444444444444444444444444444444444444"

pub const test_user_credential: ByteArray =
  #"55555555555555555555555555555555555555555555555555555555"

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
    make_cip113_registry_ref_input().output,
    test_registry_policy_id,
    test_transfer_logic_hash,
    constants.transfer_logic_script_registry_node_index,
  )
  issuance_policy_id == test_issuance_policy_id
}

// Helper to build tx with signatories
fn tx_signed_by(signers: List<ByteArray>) -> Transaction {
  let base = empty_tx()
  Transaction { ..base, extra_signatories: signers }
}

// ============================================================================
// SIGNATURE AUTHORIZATION TESTS (utils.must_be_signed_by_credential)
// ============================================================================

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

test denylist_deinit_requires_admin_signature() {
  let tx = tx_signed_by([test_admin_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential) == True
}

test denylist_deinit_without_admin_signature_fails() fail {
  let tx = tx_signed_by([test_power_user_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential)
}

test gs_non_mint_operation_requires_admin_signature() {
  let tx = tx_signed_by([test_admin_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential) == True
}

test gs_non_mint_operation_without_admin_signature_fails() fail {
  let tx = tx_signed_by([test_power_user_credential])
  utils.must_be_signed_by_credential(tx, test_admin_credential)
}

test gs_rotate_admin_missing_old_signature_fails() fail {
  let new_admin = #"66666666666666666666666666666666666666666666666666666666"
  let tx = tx_signed_by([new_admin])
  utils.must_be_signed_by_credential(tx, test_admin_credential) == True
}

// ============================================================================
// DENYLIST ABSENCE — covers_key (real logic from denylist/absence.ak)
// ============================================================================

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

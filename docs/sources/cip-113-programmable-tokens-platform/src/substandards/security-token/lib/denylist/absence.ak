use aiken/builtin
use aiken_design_patterns/linked_list.{get_element_info, run_element_with}
use cardano/transaction.{Input}
use constants
use utils

/// Pure predicate: given a node's own key (`None` = Root) and its link
/// (`None` = tail sentinel), does this node "cover" `target_pkh` for an
/// absence proof? A node covers `target_pkh` iff
///   node.key < target_pkh  (treating Root as -∞)
/// AND
///   target_pkh < node.link (treating tail as +∞).
///
/// Factored out of `verify_denylist_absence` so it can be unit-tested in
/// isolation without constructing a full Input / Element fixture.
pub fn covers_key(
  covering_key_opt: Option<ByteArray>,
  covering_link: Option<ByteArray>,
  target_pkh: ByteArray,
) -> Bool {
  let covers_from_below = when covering_key_opt is {
    None -> True
    Some(covering_key) -> builtin.less_than_bytearray(covering_key, target_pkh)
  }
  let covers_from_above = when covering_link is {
    None -> True
    Some(next_key) -> builtin.less_than_bytearray(target_pkh, next_key)
  }
  covers_from_below && covers_from_above
}

/// Prove that `target_pkh` is NOT present in the denylist linked list.
///
/// Takes a reference-input index pointing at a "covering" denylist node — one
/// whose key strictly precedes `target_pkh` and whose link either points past
/// `target_pkh` or is the tail sentinel. If such a node exists in the
/// reference inputs, we have proved absence.
///
/// The covering-node pattern is the standard CIP-113 absence-proof idiom (see
/// `registry_mint.ak` in the programmable-tokens reference). The denylist LL's
/// sort invariant (ascending key order, maintained by add/remove validators)
/// is what lets a single covering node witness absence in O(1).
///
/// Returns False if the ref-input indexed isn't a valid denylist node, or if
/// it doesn't actually cover the target. Fails loudly (UPLC error) if the
/// reference input doesn't carry the denylist NFT or has a malformed datum.
pub fn verify_denylist_absence(
  target_pkh: ByteArray,
  covering_ref_input_index: Int,
  reference_inputs: List<Input>,
  denylist_policy_id: ByteArray,
) -> Bool {
  let covering_ref = utils.safe_list_at(
    reference_inputs,
    covering_ref_input_index,
  )

  let (covering_key_opt, covering_link) = get_element_info(
    covering_ref.output,
    fn(_lovelace, node_key, _data, link) { (node_key, link) },
  )
    |> run_element_with(
        denylist_policy_id,
        constants.linked_list_root_key,
        constants.linked_list_node_key_prefix,
        constants.linked_list_node_key_prefix_length,
      )

  covers_key(covering_key_opt, covering_link, target_pkh)
}

// ============================================================================
// Tests — `covers_key` structural cases
// ============================================================================
//
// Note: tests for the full `verify_denylist_absence` (which requires
// constructing an authentic denylist Input with the correct NFT + inline
// Element datum) are deferred to integration-level testing — they'd require
// substantial fixture plumbing and the core absence logic is covered here.
// End-to-end coverage lands in PR 2 via run-all.ts scenarios.

const pkh_low: ByteArray =
  #"00000000000000000000000000000000000000000000000000000000"

const pkh_mid: ByteArray =
  #"88888888888888888888888888888888888888888888888888888888"

const pkh_high: ByteArray =
  #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

// Root covers everything: no predecessor, no successor (empty list).
test covers_empty_list_from_root() {
  covers_key(None, None, pkh_mid) == True
}

// Root with a successor covers any target < successor.
test covers_root_before_head() {
  covers_key(None, Some(pkh_high), pkh_mid) == True
}

// Root with a successor does NOT cover a target >= successor.
test covers_root_before_head_sad() {
  covers_key(None, Some(pkh_low), pkh_mid) == False
}

// Node with key < target and next > target covers.
test covers_middle() {
  covers_key(Some(pkh_low), Some(pkh_high), pkh_mid) == True
}

// Tail node (key < target, link = None) covers.
test covers_tail() {
  covers_key(Some(pkh_low), None, pkh_mid) == True
}

// Node whose key equals target does not cover (target is present).
test covers_target_equal_key_sad() {
  covers_key(Some(pkh_mid), None, pkh_mid) == False
}

// Node whose link equals target does not cover (target is the successor).
test covers_target_equal_link_sad() {
  covers_key(Some(pkh_low), Some(pkh_mid), pkh_mid) == False
}

// Node whose key is greater than target does not cover.
test covers_key_above_target_sad() {
  covers_key(Some(pkh_high), None, pkh_mid) == False
}

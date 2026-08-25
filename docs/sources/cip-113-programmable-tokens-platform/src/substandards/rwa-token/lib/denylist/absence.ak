use aiken/builtin
use aiken_design_patterns/linked_list.{get_element_info, run_element_with}
use cardano/address.{Address, Script}
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
  /// The DENYLIST SPEND VALIDATOR's script hash — deliberately not the
  /// list policy id. `denylist_validator` (spend) and `mint` are separate
  /// validators in the same file and therefore have different hashes; the test
  /// fixtures previously reused the policy id as the address only because
  /// nothing checked it.
  denylist_script_hash: ByteArray,
) -> Bool {
  with_covering_node_bounds(
    covering_ref_input_index,
    reference_inputs,
    denylist_policy_id,
    denylist_script_hash,
    fn(covering_key, covering_link) {
      covers_key(covering_key, covering_link, target_pkh)
    },
  )
}

/// Authenticate the denylist element at `covering_ref_input_index` and hand
/// its two bounds — its own key (`None` = Root) and its link (`None` = tail
/// sentinel) — to `continue_with`.
///
/// Authentication is the expensive half of an absence proof: the library
/// re-reads the UTxO's value to find the list NFT, re-parses the datum and
/// re-derives the key from the asset name — and none of it depends on the
/// party being vetted, only on the reference input. A caller that vets many
/// parties against the same covering node (`compliance.verify_parties`) can
/// therefore authenticate once and run `covers_key` per party. The accepted set
/// is identical: the element at a given reference-input index is one immutable
/// UTxO for the whole transaction, so its bounds cannot differ between parties.
/// Continuation style rather than returning a pair keeps the single-party path
/// free of any extra allocation.
///
/// The library authenticates the element: a genuine single-NFT UTxO of
/// `denylist_policy_id`, holding exactly ADA plus that one NFT, with a
/// well-formed `Element` datum and the correct `"Node"` key prefix. It hands
/// back the element's address, its own key, and its link.
///
/// Authentication says nothing about WHERE the element sits, so we pin the
/// address ourselves. Without that, one denylist NFT in a private wallet would
/// authenticate whatever datum its holder writes — and since the key is fixed
/// by the NFT's asset name but the LINK comes from the datum, a wallet-held
/// node keyed at 00…00 with `link: None` would certify absence for every
/// address on chain. Requiring the element to still live at the list's own
/// spend address is what makes "authenticated" mean "in the list".
///
/// Fails loudly (UPLC error) if the reference input does not carry the denylist
/// NFT, has a malformed datum, or does not sit at `denylist_script_hash`.
pub fn with_covering_node_bounds(
  covering_ref_input_index: Int,
  reference_inputs: List<Input>,
  denylist_policy_id: ByteArray,
  denylist_script_hash: ByteArray,
  continue_with: fn(Option<ByteArray>, Option<ByteArray>) -> a,
) -> a {
  let covering_ref = utils.safe_list_at(
    reference_inputs,
    covering_ref_input_index,
  )
  get_element_info(
    covering_ref.output,
    fn(address, _lovelace, node_key, _data, link) {
      expect Address { payment_credential: Script(covering_script), .. } = address
      expect covering_script == denylist_script_hash
      continue_with(node_key, link)
    },
  )
    |> run_element_with(
        denylist_policy_id,
        constants.linked_list_root_key,
        constants.linked_list_node_key_prefix,
        constants.linked_list_node_key_prefix_length,
      )
}

// ============================================================================
// Tests — `covers_key` structural cases
// ============================================================================
//
// The unit tests below exercise `covers_key` in isolation with hand-supplied
// link values. Keep in mind what that does NOT cover: the link-reading bug this
// function was once subject to lived in what `verify_denylist_absence` FEEDS
// `covers_key`, not in `covers_key` itself, so no amount of testing here would
// have caught it. Full `verify_denylist_absence` coverage — an authentic
// denylist Input with the correct NFT and inline Element datum, over a
// multi-node list — lives in `validators/regression.ak`, because a test module
// that imports validators must live in `validators/`. Keep both: this file
// proves the predicate, that one proves the plumbing.

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

use cardano/address.{Credential}
use cardano/transaction.{Transaction}
use denylist/absence.{
  covers_key, verify_denylist_absence, with_covering_node_bounds,
}
use kyc/verify.{verify_kyc_proof}
use types/global_state.{GlobalStateDatum}
use types/kyc_proof.{KycProof}
use utils

/// Vet one party per compliance action, walking both lists in LOCKSTEP.
///
/// Every party that sends or receives the security token has to clear the same
/// two gates — denylist absence, and KYC when the corresponding GlobalState
/// flag is set — and the redeemer supplies one action per party, positionally.
/// Three call sites need exactly this: the transfer path's senders, the
/// transfer path's destinations, and the seizure path's destinations. They used
/// to carry three copies of it.
///
/// Two reasons this is one shared function rather than three near-copies:
///
/// 1. **Correctness drift.** The three copies differed only in which field of
///    the action they read (`source_*` vs `destination_*`). That is precisely
///    the kind of difference a copy-paste gets wrong silently — and this
///    codebase has already had one such regression, where the sender gate read
///    the receiver's KYC flag. The accessors are now passed in, so the
///    difference is one argument at the call site instead of a duplicated body.
///
/// 2. **Cost.** The copies paired party `i` with action `i` using
///    `safe_list_at(actions, i)` inside a fold. `safe_list_at` walks from the
///    head, so aligning n parties cost Σi = O(n²) list steps — pure indexing
///    overhead. Consuming both lists together is O(n).
///
/// FAILS CLOSED on a short action list: `expect [action, ..rest] = actions`
/// traps when the redeemer supplies fewer actions than there are parties, which
/// is the same outcome the old `safe_list_at` produced when it ran off the end.
/// A `list.zip` would instead truncate silently and skip the checks for the
/// unmatched parties — do not "simplify" this into one.
///
/// Extra actions beyond the last party are ignored, exactly as before: they
/// authorise nothing on their own, since every party is checked against the
/// action at its own position.
pub fn verify_parties(
  parties: List<Credential>,
  actions: List<action>,
  proof_of: fn(action) -> KycProof,
  covering_index_of: fn(action) -> Int,
  requires_kyc: Bool,
  gs_datum: GlobalStateDatum,
  issuance_policy_id: ByteArray,
  denylist_script_hash: ByteArray,
  self: Transaction,
) -> Bool {
  when parties is {
    [] -> True
    [party, ..rest_parties] -> {
      expect [action, ..rest_actions] = actions
      and {
        kyc_ok(
          party,
          action,
          proof_of,
          requires_kyc,
          gs_datum,
          issuance_policy_id,
          self,
        ),
        when rest_parties is {
          // One party on this side — by far the commonest shape — takes the
          // plain proof with no memo machinery at all, so it costs exactly
          // what it did before the memo existed.
          [] ->
            verify_denylist_absence(
              utils.credential_hash(party),
              covering_index_of(action),
              self.reference_inputs,
              gs_datum.denylist_linked_list_policy_id,
              denylist_script_hash,
            )
          _ ->
            vet_with_fresh_node(
              party,
              action,
              rest_parties,
              rest_actions,
              proof_of,
              covering_index_of,
              requires_kyc,
              gs_datum,
              issuance_policy_id,
              denylist_script_hash,
              self,
            )
        },
      }
    }
  }
}

/// KYC first, then the denylist. Deliberate, and measured: an earlier revision
/// put the cheaper denylist check first as a "cheap gate first" optimisation
/// and benchmarking made the invalid-KYC reject path ~13% MORE expensive,
/// because the denylist proof it then ran first was work the KYC failure would
/// have made unnecessary.
fn kyc_ok(
  party: Credential,
  action: action,
  proof_of: fn(action) -> KycProof,
  requires_kyc: Bool,
  gs_datum: GlobalStateDatum,
  issuance_policy_id: ByteArray,
  self: Transaction,
) -> Bool {
  if requires_kyc {
    verify_kyc_proof(
      proof_of(action),
      party,
      gs_datum,
      issuance_policy_id,
      gs_datum.network_id,
      self,
    )
  } else {
    True
  }
}

/// Authenticate the covering node `action` cites, vet `party` against it, and
/// continue the walk with that node remembered.
///
/// Authenticating a covering node — the library re-reading the UTxO's value,
/// re-parsing its datum, re-deriving its key — was the dominant per-party cost,
/// and it depends only on the reference input, never on the party. A
/// transaction with a short denylist cites the same covering node for most or
/// all of its parties, so the node was being authenticated once PER PARTY for
/// the same bytes. Now a party that cites the index the previous party cited
/// pays only the `covers_key` comparison (`vet_remembering`); a different index
/// comes back here, is authenticated afresh, and becomes the remembered node.
///
/// Why only the last node and not a map of all of them: three plain arguments
/// cost nothing to carry, whereas a lookup structure costs an allocation per
/// call even for the one-party transfers that dominate real traffic. A builder
/// that orders parties so that those sharing a node are adjacent gets the full
/// benefit; one that interleaves merely pays what it pays today.
///
/// This cannot widen the accepted set: the element at a given index is one
/// immutable UTxO for the whole transaction, so re-authenticating it would
/// return the same bounds (or trap the same way), and the remembered node is
/// ALWAYS one this very call authenticated — there is no "nothing yet"
/// sentinel a redeemer could collide with. A party citing an index that fails
/// authentication still traps, on its first use.
fn vet_with_fresh_node(
  party: Credential,
  action: action,
  rest_parties: List<Credential>,
  rest_actions: List<action>,
  proof_of: fn(action) -> KycProof,
  covering_index_of: fn(action) -> Int,
  requires_kyc: Bool,
  gs_datum: GlobalStateDatum,
  issuance_policy_id: ByteArray,
  denylist_script_hash: ByteArray,
  self: Transaction,
) -> Bool {
  let covering_index = covering_index_of(action)
  with_covering_node_bounds(
    covering_index,
    self.reference_inputs,
    gs_datum.denylist_linked_list_policy_id,
    denylist_script_hash,
    fn(covering_key, covering_link) {
      and {
        // The denylist keys on the BARE HASH: sanctioning a hash must sanction
        // both credential forms, which is the conservative direction. Only the
        // KYC path distinguishes them.
        covers_key(covering_key, covering_link, utils.credential_hash(party)),
        vet_remembering(
          rest_parties,
          rest_actions,
          proof_of,
          covering_index_of,
          requires_kyc,
          gs_datum,
          issuance_policy_id,
          denylist_script_hash,
          self,
          covering_index,
          covering_key,
          covering_link,
        ),
      }
    },
  )
}

/// The walk after the first party: `last_index` / `last_key` / `last_link` are
/// the reference-input index and bounds of the covering node this call most
/// recently authenticated. A party citing the same index reuses the bounds;
/// any other index goes through `vet_with_fresh_node`.
fn vet_remembering(
  parties: List<Credential>,
  actions: List<action>,
  proof_of: fn(action) -> KycProof,
  covering_index_of: fn(action) -> Int,
  requires_kyc: Bool,
  gs_datum: GlobalStateDatum,
  issuance_policy_id: ByteArray,
  denylist_script_hash: ByteArray,
  self: Transaction,
  last_index: Int,
  last_key: Option<ByteArray>,
  last_link: Option<ByteArray>,
) -> Bool {
  when parties is {
    [] -> True
    [party, ..rest_parties] -> {
      expect [action, ..rest_actions] = actions
      and {
        kyc_ok(
          party,
          action,
          proof_of,
          requires_kyc,
          gs_datum,
          issuance_policy_id,
          self,
        ),
        if covering_index_of(action) == last_index {
          and {
            covers_key(last_key, last_link, utils.credential_hash(party)),
            vet_remembering(
              rest_parties,
              rest_actions,
              proof_of,
              covering_index_of,
              requires_kyc,
              gs_datum,
              issuance_policy_id,
              denylist_script_hash,
              self,
              last_index,
              last_key,
              last_link,
            ),
          }
        } else {
          vet_with_fresh_node(
            party,
            action,
            rest_parties,
            rest_actions,
            proof_of,
            covering_index_of,
            requires_kyc,
            gs_datum,
            issuance_policy_id,
            denylist_script_hash,
            self,
          )
        },
      }
    }
  }
}

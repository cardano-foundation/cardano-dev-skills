use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{
  Element, Node, Root, deinit, init, insert_ascending, remove, run_element_with,
  run_root_with, spend_for_adding_or_removing_an_element,
}
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId, from_asset, from_lovelace, merge, tokens, zero}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, find_input,
}
use constants
use types/denylist.{
  AddToDenylist, Deinit, Denylist, Init, MintRedeemer, RemoveFromDenylist,
  SpendRedeemer, StateTransition,
}
use types/global_state.{
  GlobalStateDatum, active_admin_from_ref_input, gs_datum_from_ref_input,
}
use types/power_users.{PowerUser}
use utils.{must_be_signed_by_credential, quantity_of_policy_id}

/// Resolves the GS reference input (for the power-user linked-list policy id)
/// and the power-user node reference input at `power_user_node_ref_input_index`,
/// authenticating the node against that list. Returns the node's credential hash
/// and parsed `PowerUser` data. Callers gate sanctions on `is_admin` + the
/// returned credential's signature.
fn power_user_from_refs(
  self: Transaction,
  global_state_ref_input_index: Int,
  global_state_policy_id: ByteArray,
  power_user_node_ref_input_index: Int,
  power_user_list_script_hash: ByteArray,
) -> (ByteArray, PowerUser) {
  let gs = gs_datum_from_ref_input(
    self.reference_inputs,
    global_state_ref_input_index,
    global_state_policy_id,
  )
  // No sanctions administration on a decommissioned protocol.
  expect !gs.deactivated
  let power_user_node_ref_input = utils.safe_list_at(
    self.reference_inputs,
    power_user_node_ref_input_index,
  )
  utils.authenticated_power_user(
    power_user_node_ref_input.output,
    gs.power_user_linked_list_policy_id,
    power_user_list_script_hash,
  )
}

validator denylist_validator(denylist_linked_list_policy_id: ByteArray) {
  spend(
    _datum_opt: Option<Data>,
    redeemer: SpendRedeemer,
    input_out_ref: OutputReference,
    self: Transaction,
  ) {
    let StateTransition = redeemer
    // Delegate to mint validator. No ModifyUser action — presence IS the
    // state, there's nothing to toggle.
    //
    // `spend_for_adding_or_removing_an_element` only asks whether SOME
    // denylist-policy mint/burn happens anywhere in this transaction — it
    // says nothing about the UTxO actually being spent under this redeemer.
    // Without pinning that, a stray value-bearing UTxO parked at the list
    // address (holding no list NFT, and therefore not list state at all)
    // could be swept up and spent here, riding along with any genuine list
    // mutation elsewhere in the same transaction. Resolving this validator's
    // own input and requiring it to carry the list's NFT closes that: only a
    // genuine list element (root or node) may be spent under
    // `StateTransition`.
    expect Some(own_input) = find_input(self.inputs, input_out_ref)
    and {
      (quantity_of_policy_id(
        own_input.output.value,
        denylist_linked_list_policy_id,
      ) > 0)?,
      spend_for_adding_or_removing_an_element(
        denylist_linked_list_policy_id,
        self.mint,
      ),
    }
  }

  else(_) {
    fail
  }
}

validator mint(
  global_state_policy_id: ByteArray,
  init_input_out_ref: OutputReference,
  /// The POWER-USERS SPEND VALIDATOR's script hash. Not circular: the
  /// power-users validators depend on the GlobalState mint hash, never on the
  /// denylist policy id.
  power_user_list_script_hash: ByteArray,
) {
  mint(redeemer: MintRedeemer, policy_id: PolicyId, self: Transaction) {
    when redeemer is {
      Init { root_output_index } -> {
        // Nonce-gated. GS doesn't exist yet at bootstrap — the operator-held
        // one-shot UTxO is the implicit gate, same pattern as power_users.
        let nonce_validated = list.any(
          self.inputs,
          fn(input) { input.output_reference == init_input_out_ref },
        )
        let root_output = utils.safe_list_at(self.outputs, root_output_index)
        and {
          dict.size(tokens(self.mint, policy_id)) == 1,
          // Genesis: no list node exists yet, so none may be spent.
          (utils.count_inputs_with_policy(self.inputs, policy_id) == 0)?,
          // The library hands this callback the produced root's ADDRESS, so a
          // caller could in principle pin where the root lands. THIS ONE CANNOT,
          // and the reason is worth recording so nobody tries to "fix" it:
          //
          // pinning it would mean passing the list SPEND validator's hash to this
          // MINT validator — but the spend validator is parameterised by the list
          // policy id, which IS this mint validator's own hash. The dependency
          // would be circular, so no compile-time value exists.
          //
          // Genesis is therefore verified off-chain: after `Init`, confirm the
          // root NFT actually sits at the list spend validator's address. `Init`
          // is nonce-gated to a one-shot operator-held UTxO, so the only party
          // who can get this wrong is the deployer, and only once. Every LATER
          // read of a list element does pin the address, so a misplaced root
          // fails closed rather than silently granting authority.
          init(nonce_validated, root_output, self.mint, fn(_, _, _) { True })
            |> run_root_with(policy_id, constants.linked_list_root_key),
        }
      }
      Deinit { global_state_ref_input_index } -> {
        let admin = active_admin_from_ref_input(
          self.reference_inputs,
          global_state_ref_input_index,
          global_state_policy_id,
        )
        and {
          must_be_signed_by_credential(self, admin),
          dict.size(tokens(self.mint, policy_id)) == 1,
          // Only the root is spent, and `deinit` already requires the list to
          // be empty. See the note on the Add branch for why this count is
          // kept alongside the library's own scan.
          (utils.count_inputs_with_policy(self.inputs, policy_id) == 1)?,
          deinit(self.inputs, self.mint, fn(_, _, _) { True })
            |> run_root_with(policy_id, constants.linked_list_root_key),
        }
      }
      AddToDenylist {
        user_pkh,
        anchor_node_output_index,
        appended_node_output_index,
        global_state_ref_input_index,
        power_user_node_ref_input_index,
      } -> {
        // Sanctioning is delegated: any power user holding `is_admin` can add a
        // denylist entry (signed by that user). The GS admin grants the flag.
        let (power_user_credential_hash, power_user_data) = power_user_from_refs(
          self,
          global_state_ref_input_index,
          global_state_policy_id,
          power_user_node_ref_input_index,
          power_user_list_script_hash,
        )
        let anchor_output = utils.safe_list_at(
          self.outputs,
          anchor_node_output_index,
        )
        let new_node_output = utils.safe_list_at(
          self.outputs,
          appended_node_output_index,
        )
        and {
          // A key of any other length can never be the asset name of a real
          // node (`"Node" ++` a 28-byte credential hash), so it could only
          // ever match a node that will never exist — silently locking the
          // sanction out rather than rejecting it up front.
          bytearray.length(user_pkh) == 28,
          power_user_data.is_admin,
          must_be_signed_by_credential(self, power_user_credential_hash),
          dict.size(tokens(self.mint, policy_id)) == 1,
          // An insert spends exactly one element — the anchor, which
          // `insert_ascending` infers from `self.inputs` itself. The new node
          // is an OUTPUT.
          //
          // The library performs its own exact-one scan, so this line is
          // defence in depth. It is kept because the two counts are not
          // identical: the library's scanner only recognises CANONICAL
          // elements (exactly ADA plus one list NFT) and silently IGNORES an
          // input carrying the list policy in any other value shape, whereas
          // this one counts every input bearing the policy. Element outputs
          // are strictly canonical, so the gap should be unreachable — but a
          // list is an access-control structure, and this costs one fold.
          (utils.count_inputs_with_policy(self.inputs, policy_id) == 1)?,
          insert_ascending(
            anchor_output,
            new_node_output,
            self.inputs,
            self.mint,
            fn(
              _anchor_input,
              _lovelace_change,
              _anchor_key,
              _anchor_data,
              _new_lovelace,
              node_key,
              node_data,
              _link,
            ) {
              // Datum type must be correct (metadata is free-form Data).
              expect _parsed: Denylist = node_data
              node_key == user_pkh
            },
          )
            |> run_element_with(
                policy_id,
                constants.linked_list_root_key,
                constants.linked_list_node_key_prefix,
                constants.linked_list_node_key_prefix_length,
              ),
        }
      }
      RemoveFromDenylist {
        user_pkh,
        anchor_node_input_index,
        anchor_node_output_index,
        global_state_ref_input_index,
        power_user_node_ref_input_index,
      } -> {
        // Un-sanctioning is gated the same as adding: a power user holding
        // `is_admin`, signed by that user.
        let (power_user_credential_hash, power_user_data) = power_user_from_refs(
          self,
          global_state_ref_input_index,
          global_state_policy_id,
          power_user_node_ref_input_index,
          power_user_list_script_hash,
        )
        // `remove` finds both spent elements itself; the index only says
        // WHICH of the two is the anchor.
        let anchor_out_ref = utils.safe_list_at(
          self.inputs,
          anchor_node_input_index,
        ).output_reference
        let anchor_output = utils.safe_list_at(
          self.outputs,
          anchor_node_output_index,
        )
        and {
          // Same length pin as the Add branch — see its comment.
          bytearray.length(user_pkh) == 28,
          power_user_data.is_admin,
          must_be_signed_by_credential(self, power_user_credential_hash),
          dict.size(tokens(self.mint, policy_id)) == 1,
          // A remove spends exactly two elements: the anchor and the node
          // being removed. Defence in depth beside the library's own exact-two
          // scan — see the note on the Add branch.
          (utils.count_inputs_with_policy(self.inputs, policy_id) == 2)?,
          remove(
            anchor_out_ref,
            anchor_output,
            self.inputs,
            self.mint,
            fn(
              _anchor_input,
              _lovelace_change,
              _anchor_key,
              _anchor_data,
              _removing_input,
              _rem_lovelace,
              rem_key,
              rem_data,
              _link,
            ) {
              expect _parsed: Denylist = rem_data
              rem_key == user_pkh
            },
          )
            |> run_element_with(
                policy_id,
                constants.linked_list_root_key,
                constants.linked_list_node_key_prefix,
                constants.linked_list_node_key_prefix_length,
              ),
        }
      }
    }
  }

  else(_) {
    fail
  }
}

// ============================================================================
// Tests
// ============================================================================

const t_dl_policy: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const t_gs_policy: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const t_pu_policy: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const t_dl_script_hash: ByteArray =
  #"d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0"

const t_pu_script_hash: ByteArray =
  #"d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1"

const t_gs_script_hash: ByteArray =
  #"0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d"

const t_admin: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"

const t_pu_cred: ByteArray =
  #"0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c"

/// A 28-byte credential hash — the width every node key must have.
const t_key_28: ByteArray =
  #"02020202020202020202020202020202020202020202020202020202"

/// One byte short of a credential hash.
const t_key_27: ByteArray =
  #"030303030303030303030303030303030303030303030303030303"

/// One byte long of a credential hash.
const t_key_29: ByteArray =
  #"0404040404040404040404040404040404040404040404040404040404"

fn t_oref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

fn t_ll_asset_name(key: ByteArray) -> ByteArray {
  bytearray.concat(constants.linked_list_node_key_prefix, key)
}

fn t_base_tx() -> Transaction {
  Transaction {
    inputs: [],
    reference_inputs: [],
    outputs: [],
    fee: 0,
    mint: zero,
    certificates: [],
    withdrawals: [],
    validity_range: Interval {
      lower_bound: IntervalBound {
        bound_type: NegativeInfinity,
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: False,
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

/// A genuine denylist NODE at the list's spend address, carrying the list's
/// NFT.
fn t_dl_node_input(ix: Int, key: ByteArray) -> Input {
  let element: Element<Data, Data> = Element {
    data: Node { data: builtin.constr_data(0, []) },
    link: None,
  }
  Input {
    output_reference: t_oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(t_dl_script_hash),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(t_dl_policy, t_ll_asset_name(key), 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

/// The denylist ROOT with an empty list.
fn t_dl_root_input(ix: Int) -> Input {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link: None,
  }
  Input {
    output_reference: t_oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(t_dl_script_hash),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(t_dl_policy, constants.linked_list_root_key, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

/// The denylist ROOT as an OUTPUT, with a settable link — an insert or
/// remove must reproduce the anchor pointing past the mutation.
fn t_dl_root_output(link: Option<ByteArray>) -> Output {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link,
  }
  Output { ..t_dl_root_input(0).output, datum: InlineDatum(element) }
}

/// The denylist ROOT as an INPUT with a settable link — a remove spends a
/// root that points AT the node being removed.
fn t_dl_root_input_linked(ix: Int, link: Option<ByteArray>) -> Input {
  Input { output_reference: t_oref(ix), output: t_dl_root_output(link) }
}

/// A denylist node whose data is a well-formed `Denylist` — required
/// wherever the mint branch decodes a node's data (`expect _parsed: Denylist
/// = ...`), on both the appended-node output and the removed-node input.
fn t_dl_sanction_node_output(key: ByteArray) -> Output {
  let element: Element<Data, Denylist> = Element {
    data: Node { data: Denylist { metadata: builtin.constr_data(0, []) } },
    link: None,
  }
  Output { ..t_dl_node_input(0, key).output, datum: InlineDatum(element) }
}

/// A UTxO sitting at the denylist's own spend address that carries NO
/// denylist-policy token — e.g. value sent there by mistake. Structurally it
/// looks nothing like a list element (no `Element` datum at all), which is
/// exactly the point: the ONLY thing that made the pre-fix gate treat it as
/// spendable was that some unrelated denylist mint/burn happened anywhere in
/// the same transaction.
fn t_dl_stray_input(ix: Int) -> Input {
  Input {
    output_reference: t_oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(t_dl_script_hash),
        stake_credential: None,
      },
      value: from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

fn t_gs_datum(deactivated: Bool) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    deactivated,
    mintable_amount: 1_000_000_000,
    admin_credential_hash: t_admin,
    power_user_linked_list_policy_id: t_pu_policy,
    denylist_linked_list_policy_id: t_dl_policy,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: False,
    requires_receiver_kyc: False,
    network_id: 1,
    minting_script_credential_hash: t_admin,
    upgrades_locked: False,
  }
}

fn t_gs_utxo(ix: Int, datum: GlobalStateDatum) -> Input {
  Input {
    output_reference: t_oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(t_gs_script_hash),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(t_gs_policy, constants.global_state_asset_name, 1),
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

fn t_power_user(is_admin: Bool) -> PowerUser {
  PowerUser {
    credential_hash: t_pu_cred,
    is_admin,
    can_mint: False,
    can_burn: False,
    can_pause: False,
    can_force_transfer: False,
  }
}

fn t_pu_node_input(ix: Int, pu: PowerUser) -> Input {
  let element: Element<Data, PowerUser> = Element {
    data: Node { data: pu },
    link: None,
  }
  Input {
    output_reference: t_oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(t_pu_script_hash),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(t_pu_policy, t_ll_asset_name(t_pu_cred), 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

// ── Guard 1: the spend gate binds to the UTxO actually being spent ─────────

/// POSITIVE control. A genuine node spend under `StateTransition`, with a
/// genuine denylist mint/burn present — the ordinary shape of every
/// insert/remove's element-side spend. Must still succeed.
test denylist_spend_accepts_a_genuine_node_spend_alongside_a_mutation() {
  let no_datum: Option<Data> = None
  let tx = Transaction {
    ..t_base_tx(),
    inputs: [t_dl_node_input(0, t_key_28)],
    mint: from_asset(t_dl_policy, t_ll_asset_name(t_key_28), 1),
  }
  denylist_validator.spend(
    t_dl_policy,
    no_datum,
    StateTransition,
    t_oref(0),
    tx,
  )
}

/// THE GUARD under test. A UTxO sitting at the denylist address with NO
/// denylist-policy token — not list state at all — spent under
/// `StateTransition` while a genuine denylist mint/burn happens elsewhere in
/// the very same transaction. Before this fix, `spend_for_adding_or_removing_
/// an_element` asked only "does the mint field carry this policy anywhere",
/// so this stray UTxO's value could be swept out alongside any real
/// insert/remove. Now the validator additionally resolves ITS OWN spent
/// input and requires that specific UTxO to carry the list token, so the new
/// `(quantity_of_policy_id(own_input.output.value, ...) > 0)?` conjunct is
/// False and the `and { }` block returns False — hence `!`, not `fail`.
test denylist_spend_rejects_a_stray_no_token_utxo_swept_alongside_a_mutation() {
  let no_datum: Option<Data> = None
  let tx = Transaction {
    ..t_base_tx(),
    inputs: [t_dl_stray_input(0)],
    mint: from_asset(t_dl_policy, t_ll_asset_name(t_key_28), 1),
  }
  !denylist_validator.spend(
    t_dl_policy,
    no_datum,
    StateTransition,
    t_oref(0),
    tx,
  )
}

// ── Guard 2: node keys must be exactly 28 bytes ─────────────────────────────

fn t_dl_insert_tx(key: ByteArray) -> Transaction {
  Transaction {
    ..t_base_tx(),
    inputs: [t_dl_root_input(0)],
    reference_inputs: [
      t_gs_utxo(0, t_gs_datum(False)),
      t_pu_node_input(1, t_power_user(True)),
    ],
    mint: from_asset(t_dl_policy, t_ll_asset_name(key), 1),
    outputs: [t_dl_root_output(Some(key)), t_dl_sanction_node_output(key)],
    extra_signatories: [t_pu_cred],
  }
}

fn t_run_denylist_add(key: ByteArray, tx: Transaction) -> Bool {
  mint.mint(
    t_gs_policy,
    t_oref(99),
    t_pu_script_hash,
    AddToDenylist {
      user_pkh: key,
      anchor_node_output_index: 0,
      appended_node_output_index: 1,
      global_state_ref_input_index: 0,
      power_user_node_ref_input_index: 1,
    },
    t_dl_policy,
    tx,
  )
}

/// POSITIVE control for the insert length checks below — everything else
/// about `t_dl_insert_tx` is exactly what the negatives reuse, differing
/// only in the key's length.
test denylist_insert_accepts_a_28_byte_key() {
  t_run_denylist_add(t_key_28, t_dl_insert_tx(t_key_28))
}

/// THE GUARD under test, one byte short. `bytearray.length(user_pkh) == 28`
/// is the FIRST conjunct of the branch's `and { }`, so it short-circuits
/// before `insert_ascending` ever runs — the failure is exactly this check,
/// not some downstream key comparison. Returns False, hence `!`.
test denylist_insert_rejects_a_27_byte_key() {
  !t_run_denylist_add(t_key_27, t_dl_insert_tx(t_key_27))
}

/// Same guard, one byte long.
test denylist_insert_rejects_a_29_byte_key() {
  !t_run_denylist_add(t_key_29, t_dl_insert_tx(t_key_29))
}

fn t_dl_remove_tx(key: ByteArray) -> Transaction {
  Transaction {
    ..t_base_tx(),
    inputs: [
      t_dl_root_input_linked(0, Some(key)),
      Input {
        output_reference: t_oref(1),
        output: t_dl_sanction_node_output(key),
      },
    ],
    reference_inputs: [
      t_gs_utxo(0, t_gs_datum(False)),
      t_pu_node_input(1, t_power_user(True)),
    ],
    mint: from_asset(t_dl_policy, t_ll_asset_name(key), -1),
    outputs: [t_dl_root_output(None)],
    extra_signatories: [t_pu_cred],
  }
}

fn t_run_denylist_remove(key: ByteArray, tx: Transaction) -> Bool {
  mint.mint(
    t_gs_policy,
    t_oref(99),
    t_pu_script_hash,
    RemoveFromDenylist {
      user_pkh: key,
      anchor_node_input_index: 0,
      anchor_node_output_index: 0,
      global_state_ref_input_index: 0,
      power_user_node_ref_input_index: 1,
    },
    t_dl_policy,
    tx,
  )
}

/// POSITIVE control for the remove length checks below.
test denylist_remove_accepts_a_28_byte_key() {
  t_run_denylist_remove(t_key_28, t_dl_remove_tx(t_key_28))
}

/// THE GUARD under test on the Remove branch, one byte short. Same
/// short-circuit reasoning as the insert case: the length conjunct is first,
/// so `remove` never runs. Returns False, hence `!`.
test denylist_remove_rejects_a_27_byte_key() {
  !t_run_denylist_remove(t_key_27, t_dl_remove_tx(t_key_27))
}

/// Same guard, one byte long.
test denylist_remove_rejects_a_29_byte_key() {
  !t_run_denylist_remove(t_key_29, t_dl_remove_tx(t_key_29))
}

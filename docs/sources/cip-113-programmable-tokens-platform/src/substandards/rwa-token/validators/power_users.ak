use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{
  Element, Node, Root, deinit, init, insert_ascending, remove, run_element_with,
  run_root_with, spend_for_adding_or_removing_an_element,
  spend_for_updating_elements_data,
}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{PolicyId, from_asset, from_lovelace, merge, tokens, zero}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, find_input,
}
use constants
use types/global_state.{GlobalStateDatum, active_admin_from_ref_input}
use types/power_users.{
  AddPowerUser, Deinit, Init, MintRedeemer, ModifyPowerUser, PowerUser,
  RemovePowerUser, SpendRedeemer, StateTransition,
}
use utils.{must_be_signed_by_credential, quantity_of_policy_id}

validator power_users_validator(
  global_state_policy_id: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
) {
  spend(
    _datum_opt: Option<Data>,
    redeemer: SpendRedeemer,
    input_out_ref: OutputReference,
    self: Transaction,
  ) {
    when redeemer is {
      StateTransition -> {
        // Delegating responsibility to the mint validator — but the
        // library's gate only asks whether SOME power-users-policy mint/burn
        // happens anywhere in this transaction, not that the UTxO actually
        // being spent under this redeemer is a genuine list element. Without
        // pinning that, a stray value-bearing UTxO parked at the list
        // address (holding no list NFT, and therefore not list state at
        // all) could be swept up here, riding along with any genuine list
        // mutation elsewhere in the same transaction. Resolving this
        // validator's own input and requiring it to carry the list's NFT
        // closes that: only a genuine list element (root or node) may be
        // spent under `StateTransition`.
        expect Some(own_input) = find_input(self.inputs, input_out_ref)
        and {
          (quantity_of_policy_id(
            own_input.output.value,
            power_users_linked_list_policy_id,
          ) > 0)?,
          spend_for_adding_or_removing_an_element(
            power_users_linked_list_policy_id,
            self.mint,
          ),
        }
      }
      ModifyPowerUser {
        own_input_index,
        own_output_index,
        wanted_user_state,
        global_state_ref_input_index,
      } -> {
        let admin = active_admin_from_ref_input(
          self.reference_inputs,
          global_state_ref_input_index,
          global_state_policy_id,
        )
        and {
          must_be_signed_by_credential(self, admin),
          //Ensure you're only modifying data, and output has the desired data
          spend_for_updating_elements_data(
            own_input_index,
            own_output_index,
            input_out_ref,
            self.inputs,
            self.outputs,
            self.mint,
            fn(
              _address,
              _lovelace_change,
              _node_key,
              _old_data,
              new_data,
              _link,
            ) {
              expect power_user_data: PowerUser = new_data
              power_user_data == wanted_user_state
            },
          )
            |> run_element_with(
                power_users_linked_list_policy_id,
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

validator mint(
  global_state_policy_id: ByteArray,
  init_input_out_ref: OutputReference,
) {
  mint(redeemer: MintRedeemer, policy_id: PolicyId, self: Transaction) {
    when redeemer is {
      Init { root_output_index } -> {
        // Init is nonce-gated — GS doesn't exist yet at bootstrap time, so
        // admin-via-datum lookup isn't feasible. The one-shot UTxO is
        // operator-held, which implicitly gates this action to the operator.
        let nonce_validated = list.any(
          self.inputs,
          fn(input) { input.output_reference == init_input_out_ref },
        )
        let root_output = utils.safe_list_at(self.outputs, root_output_index)
        and {
          //Only 1 token of this policy must be minted (the root NFT)
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
          // L-6: Deinit must require admin signature. Without this, anyone
          // can burn the root NFT while the list is empty. Admin now comes
          // from GS datum (rotatable); previously compile-time owner.
          must_be_signed_by_credential(self, admin),
          dict.size(tokens(self.mint, policy_id)) == 1,
          // Only the root is spent, and `deinit` already requires the list to
          // be empty. Defence in depth beside the library's own scan — see the
          // note on the Add branch.
          (utils.count_inputs_with_policy(self.inputs, policy_id) == 1)?,
          deinit(self.inputs, self.mint, fn(_, _, _) { True })
            |> run_root_with(policy_id, constants.linked_list_root_key),
        }
      }
      AddPowerUser {
        new_power_user_key,
        anchor_node_output_index,
        appended_node_output_index,
        global_state_ref_input_index,
      } -> {
        let admin = active_admin_from_ref_input(
          self.reference_inputs,
          global_state_ref_input_index,
          global_state_policy_id,
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
          // grant out rather than rejecting it up front.
          bytearray.length(new_power_user_key) == 28,
          must_be_signed_by_credential(self, admin),
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
              expect _parsed: PowerUser = node_data
              node_key == new_power_user_key
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
      RemovePowerUser {
        power_user_key_to_remove,
        anchor_node_input_index,
        anchor_node_output_index,
        global_state_ref_input_index,
      } -> {
        let admin = active_admin_from_ref_input(
          self.reference_inputs,
          global_state_ref_input_index,
          global_state_policy_id,
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
          bytearray.length(power_user_key_to_remove) == 28,
          must_be_signed_by_credential(self, admin),
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
              expect _parsed: PowerUser = rem_data
              rem_key == power_user_key_to_remove
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

const t_gs_policy: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const t_pu_policy: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const t_gs_script_hash: ByteArray =
  #"0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d"

const t_pu_script_hash: ByteArray =
  #"d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1"

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

fn t_power_user(
  is_admin: Bool,
  can_mint: Bool,
  can_burn: Bool,
  can_pause: Bool,
  can_force_transfer: Bool,
) -> PowerUser {
  PowerUser {
    credential_hash: t_pu_cred,
    is_admin,
    can_mint,
    can_burn,
    can_pause,
    can_force_transfer,
  }
}

/// A genuine power-user NODE at the list's spend address, carrying the
/// list's NFT, keyed at `t_pu_cred` (i.e. `pu.credential_hash` must be
/// `t_pu_cred` for the asset name to match the datum).
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

/// The same node continued as an OUTPUT — same key, same address, a
/// possibly different `PowerUser` datum. Used by the `ModifyPowerUser`
/// tests, where the input and continuing output must agree on everything
/// except the data.
fn t_pu_node_output(pu: PowerUser) -> Output {
  t_pu_node_input(0, pu).output
}

/// A UTxO sitting at the power-users' own spend address that carries NO
/// power-users-policy token — e.g. value sent there by mistake.
fn t_pu_stray_input(ix: Int) -> Input {
  Input {
    output_reference: t_oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(t_pu_script_hash),
        stake_credential: None,
      },
      value: from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

/// The power-users ROOT with an empty list.
fn t_pu_root_input(ix: Int) -> Input {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
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
        from_asset(t_pu_policy, constants.linked_list_root_key, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

/// The power-users ROOT as an OUTPUT, with a settable link.
fn t_pu_root_output(link: Option<ByteArray>) -> Output {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link,
  }
  Output { ..t_pu_root_input(0).output, datum: InlineDatum(element) }
}

/// The power-users ROOT as an INPUT with a settable link — a remove spends a
/// root that points AT the operator being revoked.
fn t_pu_root_input_linked(ix: Int, link: Option<ByteArray>) -> Input {
  Input { output_reference: t_oref(ix), output: t_pu_root_output(link) }
}

/// A power-user node output keyed at an arbitrary `key` — `t_pu_node_input`
/// is hardwired to `t_pu_cred`, but an insert must produce a node at the key
/// the redeemer names.
fn t_pu_new_node_output(key: ByteArray) -> Output {
  let pu = PowerUser {
    credential_hash: key,
    is_admin: False,
    can_mint: False,
    can_burn: False,
    can_pause: False,
    can_force_transfer: False,
  }
  let element: Element<Data, PowerUser> = Element {
    data: Node { data: pu },
    link: None,
  }
  Output {
    address: Address {
      payment_credential: Script(t_pu_script_hash),
      stake_credential: None,
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(t_pu_policy, t_ll_asset_name(key), 1),
    ),
    datum: InlineDatum(element),
    reference_script: None,
  }
}

fn t_gs_datum(deactivated: Bool) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    deactivated,
    mintable_amount: 1_000_000_000,
    admin_credential_hash: t_admin,
    power_user_linked_list_policy_id: t_pu_policy,
    denylist_linked_list_policy_id: #"",
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

/// A plain UTxO used as the one-shot genesis nonce.
fn t_nonce_input(ix: Int) -> Input {
  Input {
    output_reference: t_oref(ix),
    output: Output {
      address: Address {
        payment_credential: VerificationKey(t_admin),
        stake_credential: None,
      },
      value: from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

// ── Guard 1: the spend gate binds to the UTxO actually being spent ─────────

/// POSITIVE control. A genuine node spend under `StateTransition`, with a
/// genuine power-users mint/burn present — the ordinary shape of every
/// insert/remove's element-side spend. Must still succeed.
test power_users_spend_accepts_a_genuine_node_spend_alongside_a_mutation() {
  let no_datum: Option<Data> = None
  let tx = Transaction {
    ..t_base_tx(),
    inputs: [
      t_pu_node_input(0, t_power_user(False, False, False, False, False)),
    ],
    mint: from_asset(t_pu_policy, t_ll_asset_name(t_pu_cred), 1),
  }
  power_users_validator.spend(
    t_gs_policy,
    t_pu_policy,
    no_datum,
    StateTransition,
    t_oref(0),
    tx,
  )
}

/// THE GUARD under test. A UTxO sitting at the power-users address with NO
/// power-users-policy token — not list state at all — spent under
/// `StateTransition` while a genuine power-users mint/burn happens elsewhere
/// in the very same transaction. Before this fix,
/// `spend_for_adding_or_removing_an_element` asked only "does the mint field
/// carry this policy anywhere", so this stray UTxO's value could be swept
/// out alongside any real insert/remove. Now the validator additionally
/// resolves ITS OWN spent input and requires that specific UTxO to carry the
/// list token, so the new `(quantity_of_policy_id(own_input.output.value,
/// ...) > 0)?` conjunct is False and the `and { }` block returns False —
/// hence `!`, not `fail`.
test power_users_spend_rejects_a_stray_no_token_utxo_swept_alongside_a_mutation() {
  let no_datum: Option<Data> = None
  let tx = Transaction {
    ..t_base_tx(),
    inputs: [t_pu_stray_input(0)],
    mint: from_asset(t_pu_policy, t_ll_asset_name(t_pu_cred), 1),
  }
  !power_users_validator.spend(
    t_gs_policy,
    t_pu_policy,
    no_datum,
    StateTransition,
    t_oref(0),
    tx,
  )
}

// ── Guard 2: node keys must be exactly 28 bytes ─────────────────────────────

fn t_pu_insert_tx(key: ByteArray) -> Transaction {
  Transaction {
    ..t_base_tx(),
    inputs: [t_pu_root_input(0)],
    reference_inputs: [t_gs_utxo(0, t_gs_datum(False))],
    mint: from_asset(t_pu_policy, t_ll_asset_name(key), 1),
    outputs: [t_pu_root_output(Some(key)), t_pu_new_node_output(key)],
    extra_signatories: [t_admin],
  }
}

fn t_run_pu_add(key: ByteArray, tx: Transaction) -> Bool {
  mint.mint(
    t_gs_policy,
    t_oref(99),
    AddPowerUser {
      new_power_user_key: key,
      anchor_node_output_index: 0,
      appended_node_output_index: 1,
      global_state_ref_input_index: 0,
    },
    t_pu_policy,
    tx,
  )
}

/// POSITIVE control for the insert length checks below — everything else
/// about `t_pu_insert_tx` is exactly what the negatives reuse, differing
/// only in the key's length.
test power_users_insert_accepts_a_28_byte_key() {
  t_run_pu_add(t_key_28, t_pu_insert_tx(t_key_28))
}

/// THE GUARD under test, one byte short. `bytearray.length(new_power_user_key)
/// == 28` is the FIRST conjunct of the branch's `and { }`, so it
/// short-circuits before `insert_ascending` ever runs. Returns False, hence
/// `!`.
test power_users_insert_rejects_a_27_byte_key() {
  !t_run_pu_add(t_key_27, t_pu_insert_tx(t_key_27))
}

/// Same guard, one byte long.
test power_users_insert_rejects_a_29_byte_key() {
  !t_run_pu_add(t_key_29, t_pu_insert_tx(t_key_29))
}

fn t_pu_remove_tx(key: ByteArray) -> Transaction {
  Transaction {
    ..t_base_tx(),
    inputs: [
      t_pu_root_input_linked(0, Some(key)),
      Input { output_reference: t_oref(1), output: t_pu_new_node_output(key) },
    ],
    reference_inputs: [t_gs_utxo(0, t_gs_datum(False))],
    mint: from_asset(t_pu_policy, t_ll_asset_name(key), -1),
    outputs: [t_pu_root_output(None)],
    extra_signatories: [t_admin],
  }
}

fn t_run_pu_remove(key: ByteArray, tx: Transaction) -> Bool {
  mint.mint(
    t_gs_policy,
    t_oref(99),
    RemovePowerUser {
      power_user_key_to_remove: key,
      anchor_node_input_index: 0,
      anchor_node_output_index: 0,
      global_state_ref_input_index: 0,
    },
    t_pu_policy,
    tx,
  )
}

/// POSITIVE control for the remove length checks below.
test power_users_remove_accepts_a_28_byte_key() {
  t_run_pu_remove(t_key_28, t_pu_remove_tx(t_key_28))
}

/// THE GUARD under test on the Remove branch, one byte short. Same
/// short-circuit reasoning as the insert case: the length conjunct is
/// first, so `remove` never runs. Returns False, hence `!`.
test power_users_remove_rejects_a_27_byte_key() {
  !t_run_pu_remove(t_key_27, t_pu_remove_tx(t_key_27))
}

/// Same guard, one byte long.
test power_users_remove_rejects_a_29_byte_key() {
  !t_run_pu_remove(t_key_29, t_pu_remove_tx(t_key_29))
}

// ── ModifyPowerUser branch coverage ─────────────────────────────────────────

fn t_pu_modify_tx(old_pu: PowerUser, new_pu: PowerUser) -> Transaction {
  Transaction {
    ..t_base_tx(),
    inputs: [t_pu_node_input(0, old_pu)],
    outputs: [t_pu_node_output(new_pu)],
    reference_inputs: [t_gs_utxo(0, t_gs_datum(False))],
    extra_signatories: [t_admin],
  }
}

fn t_run_pu_modify(wanted: PowerUser, tx: Transaction) -> Bool {
  let no_datum: Option<Data> = None
  power_users_validator.spend(
    t_gs_policy,
    t_pu_policy,
    no_datum,
    ModifyPowerUser {
      own_input_index: 0,
      own_output_index: 0,
      wanted_user_state: wanted,
      global_state_ref_input_index: 0,
    },
    t_oref(0),
    tx,
  )
}

/// POSITIVE control. Admin-signed, and the continuing output's datum equals
/// exactly the redeemer's `wanted_user_state`. The ordinary role-grant flow.
test power_user_modify_accepts_an_admin_signed_change_matching_the_wanted_state() {
  let old_pu = t_power_user(False, False, False, False, False)
  let new_pu = PowerUser { ..old_pu, can_mint: True }
  t_run_pu_modify(new_pu, t_pu_modify_tx(old_pu, new_pu))
}

/// Without the admin's signature, a role change must be rejected — otherwise
/// anyone could grant themselves (or anyone else) any role. `must_be_signed_
/// by_credential` is the FIRST conjunct of the branch's `and { }`, so it
/// short-circuits before `spend_for_updating_elements_data` ever runs.
/// Returns False, hence `!`.
test power_user_modify_rejects_a_missing_admin_signature() {
  let old_pu = t_power_user(False, False, False, False, False)
  let new_pu = PowerUser { ..old_pu, can_mint: True }
  !t_run_pu_modify(
    new_pu,
    Transaction { ..t_pu_modify_tx(old_pu, new_pu), extra_signatories: [] },
  )
}

/// THE GUARD under test: the continuing output's ACTUAL datum
/// (`can_burn: True`) disagrees with the redeemer's claimed
/// `wanted_user_state` (`can_mint: True`) — an admin could otherwise declare
/// one role change and grant a different one. The mismatch is caught inside
/// the library's `spend_for_updating_elements_data`, whose
/// `additional_validations` callback returns `power_user_data ==
/// wanted_user_state` — False here — and the library wraps that call in
/// `expect additional_validations(...)`, which TRAPS on False. Hence `fail`,
/// not `!`.
test power_user_modify_rejects_an_output_datum_that_disagrees_with_the_wanted_state() fail {
  let old_pu = t_power_user(False, False, False, False, False)
  let claimed_new_pu = PowerUser { ..old_pu, can_mint: True }
  let actual_new_pu = PowerUser { ..old_pu, can_burn: True }
  t_run_pu_modify(claimed_new_pu, t_pu_modify_tx(old_pu, actual_new_pu))
}

// ── Init / Deinit branch coverage ───────────────────────────────────────────

/// `Init` — genesis. The nonce UTxO must be spent and no list element may
/// exist yet.
test power_users_init_succeeds_on_the_nonce_utxo() {
  mint.mint(
    t_gs_policy,
    t_oref(50),
    Init { root_output_index: 0 },
    t_pu_policy,
    Transaction {
      ..t_base_tx(),
      inputs: [t_nonce_input(50)],
      mint: from_asset(t_pu_policy, constants.linked_list_root_key, 1),
      outputs: [t_pu_root_output(None)],
    },
  )
}

/// Without the one-shot nonce input, genesis must fail — otherwise anyone
/// could create a second, parallel power-users list and point a deployment
/// at it. The library's `init` guards this with `expect nonce_validated`,
/// which TRAPS, hence `fail`.
test power_users_init_rejects_a_missing_nonce() fail {
  mint.mint(
    t_gs_policy,
    t_oref(50),
    Init { root_output_index: 0 },
    t_pu_policy,
    Transaction {
      ..t_base_tx(),
      inputs: [],
      mint: from_asset(t_pu_policy, constants.linked_list_root_key, 1),
      outputs: [t_pu_root_output(None)],
    },
  )
}

/// `Deinit` — burning the root. Admin-signed, and only on an empty list.
test power_users_deinit_succeeds_for_the_admin_on_an_empty_list() {
  mint.mint(
    t_gs_policy,
    t_oref(99),
    Deinit { global_state_ref_input_index: 0 },
    t_pu_policy,
    Transaction {
      ..t_base_tx(),
      inputs: [t_pu_root_input(0)],
      reference_inputs: [t_gs_utxo(0, t_gs_datum(False))],
      mint: from_asset(t_pu_policy, constants.linked_list_root_key, -1),
      extra_signatories: [t_admin],
    },
  )
}

/// Unsigned by the admin, the root cannot be burnt — otherwise anyone could
/// destroy the operator list while it happened to be empty. `must_be_signed_
/// by_credential` is the FIRST conjunct of the branch's `and { }`, so it
/// short-circuits before `deinit` ever runs. Returns False, hence `!`.
test power_users_deinit_rejects_a_missing_admin_signature() {
  !mint.mint(
    t_gs_policy,
    t_oref(99),
    Deinit { global_state_ref_input_index: 0 },
    t_pu_policy,
    Transaction {
      ..t_base_tx(),
      inputs: [t_pu_root_input(0)],
      reference_inputs: [t_gs_utxo(0, t_gs_datum(False))],
      mint: from_asset(t_pu_policy, constants.linked_list_root_key, -1),
    },
  )
}

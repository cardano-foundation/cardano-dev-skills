//// ============================================================================
//// SECURITY REGRESSION SUITE
//// ============================================================================
////
//// Every test here pins a security property that a past defect broke. Most
//// construct a MALICIOUS transaction and assert the validator refuses it; a
//// few construct a perfectly LEGITIMATE one and assert the validator accepts
//// it, because several of the defects fixed here failed in both directions —
//// they let attackers through AND locked honest holders out.
////
////   test foo()          -> validator ACCEPTS. A legitimate flow must work.
////   test foo() { !.. }  -> validator REJECTS by returning False. Use this
////                          when the failing check is a conjunct of an
////                          `and { }` block.
////   test foo() fail     -> validator TRAPS. Use this when the failing check
////                          is an `expect`.
////
//// Getting that distinction wrong produces a test that passes for the wrong
//// reason. When adding a test, run it and read the trace: the runner prints
//// `the validator crashed / exited prematurely` for a trap, and names the
//// assertion that fired. Confirm it is the one you meant.
////
//// Every negative test that guards a NEW check is paired with a POSITIVE
//// CONTROL built from the same fixtures. Without one, a negative test still
//// passes when the whole path is broken for an unrelated reason — and that is
//// not hypothetical: writing the controls here caught two fixture bugs that
//// had let negative tests pass for the wrong reason.
////
//// This is a *test module* in the Aiken sense (it exports no public
//// definitions), which is what allows it to import the validators. That is
//// also why it lives in `validators/` — a pub-free module in `lib/` is still
//// rejected with `aiken::check::illegal::import`.
////
//// Run with:  aiken check -m "regression.{..}"
//// (`-m regression` alone matches nothing.)

use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{Element, Node, Root}
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{Value, from_asset, from_lovelace, merge, zero}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use constants
use denylist as v_denylist
use denylist/absence.{verify_denylist_absence}
use minting_authority as v_minting_authority
use power_users as v_power_users
use transfer_logic_script as v_transfer
use types/denylist.{
  AddToDenylist, Deinit as DenylistDeinit, Denylist, Init as DenylistInit,
  RemoveFromDenylist, StateTransition as DenylistStateTransition,
}
use types/global_state.{GlobalStateDatum, GlobalStateReferenced}
use types/kyc_proof.{Attestation, AttestationProof, KycProof}
use types/minting_authority.{
  MintBurn, MintingAuthorityWithdrawRedeemer, MintingLogicDestinationAction,
}
use types/power_users.{
  AddPowerUser, PowerUser, RemovePowerUser, StateTransition as PuStateTransition,
}
use types/transfer_logic_script.{
  TransferLogicScriptAction, TransferLogicScriptDestinationAction,
  TransferLogicScriptWithdrawRedeemer,
}

// ============================================================================
// The world
// ============================================================================

const sec_name: ByteArray = "SEC"

const gs_policy: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

/// The REAL security token's issuance policy id — the `key` of this
/// deployment's CIP-113 registry node.
const issuance_policy: ByteArray =
  #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

const registry_policy: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const denylist_policy: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const pu_policy: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

/// minting_logic_script.ak — the permanent CIP-113 proxy.
const proxy_hash: ByteArray =
  #"f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1"

const transfer_hash: ByteArray =
  #"f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2"

const third_party_hash: ByteArray =
  #"f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3"

const authority_hash: ByteArray =
  #"f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4"

/// CIP-113 programmable-logic-base script — the shared payment credential of
/// every compliant token UTxO.
/// The CIP-68 reference NFT's asset name, under the same issuance policy as
/// the security asset.
const reference_name: ByteArray = "REF"

const plb_hash: ByteArray =
  #"05050505050505050505050505050505050505050505050505050505"

const gs_script_hash: ByteArray =
  #"0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d"

/// The denylist SPEND validator's hash — deliberately NOT
/// `denylist_policy`. `denylist_validator` (spend) and `mint` are separate
/// validators in the same file and therefore have different hashes; the
/// original fixtures reused the policy id as the address only because nothing
/// checked it — which is precisely what the wallet-held-node defect exploited.
const denylist_script_hash: ByteArray =
  #"d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0"

/// The power-users SPEND validator's hash, likewise distinct from
/// `pu_policy`.
const pu_script_hash: ByteArray =
  #"d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1"

const admin: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"

const pu_cred: ByteArray =
  #"0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c"

const attacker_wallet: ByteArray =
  #"0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e"

const clean_stake: ByteArray =
  #"0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"

// ── Denylist keys, chosen to exercise the prefix-strip mismatch ──────────────
//
// `insert_ascending` writes a node's `link` as the successor's BARE key
// (linked-list.ak check 5), but `get_element_info` reads it back through
// `bytearray.drop(4)` — stripping the 4-byte "Node" prefix a second time from a
// value that never carried it. So the successor key the absence check compares
// against is the real key with its first 4 bytes chopped off.

/// Predecessor node ("P"). Sorts before every other key used below.
const dl_pred_key: ByteArray =
  #"01010101010101010101010101010101010101010101010101010101"

/// A SANCTIONED holder ("S"), present in the denylist. Chosen so that
/// `S < drop(4, S)` — which holds whenever byte 0 < byte 4, i.e. for roughly
/// half of all credential hashes. No grinding required.
const dl_sanctioned_key: ByteArray =
  #"0a0a0a0a555555555555555555555555555555555555555555555555"

/// A CLEAN holder that the same bug locks out permanently.
const dl_frozen_key: ByteArray =
  #"02020202020202020202020202020202020202020202020202020202"

/// A successor key whose 4-byte-stripped form (24 zero bytes) sorts below every
/// possible 28-byte key, so no target can be proven absent through a
/// predecessor that links to it.
const dl_hostile_next_key: ByteArray =
  #"aaaaaaaa000000000000000000000000000000000000000000000000"

/// Lowest possible key — a forged covering node keyed here covers everything.
const dl_lowest_key: ByteArray =
  #"00000000000000000000000000000000000000000000000000000000"

// ============================================================================
// Fixtures
// ============================================================================

fn oref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

/// Faithful mirror of the CIP-113 registry node layout. Field order is
/// load-bearing: minting=2, transfer=3, third-party=4, unfracking=5, gs_cs=6.
type RegNode {
  key: ByteArray,
  next: ByteArray,
  minting_logic_script: Credential,
  transfer_logic_script: Credential,
  third_party_transfer_logic_script: Credential,
  unfracking_logic_script: Credential,
  global_state_cs: ByteArray,
}

/// THIS deployment's genuine registry node.
fn genuine_node() -> RegNode {
  RegNode {
    key: issuance_policy,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(proxy_hash),
    transfer_logic_script: Script(transfer_hash),
    third_party_transfer_logic_script: Script(third_party_hash),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: gs_policy,
  }
}

fn registry_node_input(ix: Int, node: RegNode) -> Input {
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(registry_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(registry_policy, "Node", 1),
      ),
      datum: InlineDatum(node),
      reference_script: None,
    },
  }
}

fn gs_datum(
  paused: Bool,
  deactivated: Bool,
  req_sender: Bool,
  req_receiver: Bool,
) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: paused,
    deactivated,
    mintable_amount: 1_000_000_000,
    admin_credential_hash: admin,
    power_user_linked_list_policy_id: pu_policy,
    denylist_linked_list_policy_id: denylist_policy,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: req_sender,
    requires_receiver_kyc: req_receiver,
    network_id: 1,
    minting_script_credential_hash: authority_hash,
    upgrades_locked: False,
  }
}

fn gs_value(lovelace: Int) -> Value {
  merge(
    from_lovelace(lovelace),
    from_asset(gs_policy, constants.global_state_asset_name, 1),
  )
}

fn gs_output(lovelace: Int, datum: GlobalStateDatum) -> Output {
  Output {
    address: Address {
      payment_credential: Script(gs_script_hash),
      stake_credential: None,
    },
    value: gs_value(lovelace),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

fn gs_utxo(ix: Int, lovelace: Int, datum: GlobalStateDatum) -> Input {
  Input { output_reference: oref(ix), output: gs_output(lovelace, datum) }
}

/// A GlobalState-shaped UTxO carrying NO GlobalState NFT.
fn gs_forged(ix: Int, datum: GlobalStateDatum) -> Input {
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(gs_script_hash),
        stake_credential: None,
      },
      value: from_lovelace(2_000_000),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

fn ll_asset_name(key: ByteArray) -> ByteArray {
  bytearray.concat(constants.linked_list_node_key_prefix, key)
}

/// A genuine denylist NODE element at the denylist SPEND validator's address.
/// `link` holds the successor's BARE key, exactly as `insert_ascending` writes
/// it.
fn dl_node_input(ix: Int, key: ByteArray, link: Option<ByteArray>) -> Input {
  let element: Element<Data, Data> = Element {
    data: Node { data: builtin.constr_data(0, []) },
    link,
  }
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(denylist_script_hash),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(denylist_policy, ll_asset_name(key), 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

/// The denylist ROOT with an empty list — covers every key.
fn dl_root_input(ix: Int) -> Input {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link: None,
  }
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(denylist_script_hash),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(denylist_policy, constants.linked_list_root_key, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

/// The denylist ROOT as an OUTPUT, with a settable link — an insert must
/// reproduce the anchor pointing at the new node.
fn dl_root_output(link: Option<ByteArray>) -> Output {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link,
  }
  Output { ..dl_root_input(0).output, datum: InlineDatum(element) }
}

/// A denylist node output whose data is a well-formed `Denylist` — required
/// by the mint branch's `expect _parsed: Denylist = node_data`.
fn dl_sanction_node_output(key: ByteArray, link: Option<ByteArray>) -> Output {
  let element: Element<Data, Denylist> = Element {
    data: Node { data: Denylist { metadata: builtin.constr_data(0, []) } },
    link,
  }
  Output { ..dl_node_input(0, key, link).output, datum: InlineDatum(element) }
}

/// A denylist node INPUT whose data is a well-formed `Denylist` — needed where
/// a mint branch decodes the node being removed.
fn dl_node_sanction_input(
  ix: Int,
  key: ByteArray,
  link: Option<ByteArray>,
) -> Input {
  Input {
    output_reference: oref(ix),
    output: dl_sanction_node_output(key, link),
  }
}

/// The denylist ROOT as an INPUT with a settable link — a remove spends a root
/// that points AT the node being removed.
fn dl_root_input_linked(ix: Int, link: Option<ByteArray>) -> Input {
  Input { output_reference: oref(ix), output: dl_root_output(link) }
}

/// A plain UTxO used as the one-shot genesis nonce.
fn nonce_input(ix: Int) -> Input {
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address {
        payment_credential: VerificationKey(admin),
        stake_credential: None,
      },
      value: from_lovelace(5_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

/// A denylist "node" sitting in an ATTACKER'S OWN WALLET. Structurally identical
/// to a real one — `authenticate_element_utxo_and_get_info` never looks at the
/// element's address — with an attacker-authored `link`.
fn dl_forged_node_at_attacker(
  ix: Int,
  key: ByteArray,
  link: Option<ByteArray>,
) -> Input {
  let element: Element<Data, Data> = Element {
    data: Node { data: builtin.constr_data(0, []) },
    link,
  }
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address {
        payment_credential: VerificationKey(attacker_wallet),
        stake_credential: Some(Inline(VerificationKey(attacker_wallet))),
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(denylist_policy, ll_asset_name(key), 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

fn power_user(
  is_admin: Bool,
  can_mint: Bool,
  can_burn: Bool,
  can_pause: Bool,
  can_force_transfer: Bool,
) -> PowerUser {
  PowerUser {
    credential_hash: pu_cred,
    is_admin,
    can_mint,
    can_burn,
    can_pause,
    can_force_transfer,
  }
}

fn pu_node_input(ix: Int, pu: PowerUser) -> Input {
  pu_node_at(ix, pu, Script(pu_script_hash))
}

/// The same node at a caller-chosen address, so the address pin can be
/// exercised in both directions.
fn pu_node_at(ix: Int, pu: PowerUser, payment: Credential) -> Input {
  let element: Element<Data, PowerUser> = Element {
    data: Node { data: pu },
    link: None,
  }
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address { payment_credential: payment, stake_credential: None },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(pu_policy, ll_asset_name(pu_cred), 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

/// A power-user node output keyed at an arbitrary `key` — `pu_node_input` is
/// hardwired to `pu_cred`, but an insert must produce a node at the key the
/// redeemer names.
fn pu_new_node_output(key: ByteArray) -> Output {
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
      payment_credential: Script(pu_script_hash),
      stake_credential: None,
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(pu_policy, ll_asset_name(key), 1),
    ),
    datum: InlineDatum(element),
    reference_script: None,
  }
}

/// The power-users ROOT as an OUTPUT, with a settable link.
fn pu_root_output(link: Option<ByteArray>) -> Output {
  let element: Element<Data, PowerUser> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link,
  }
  Output { ..pu_root_input(0).output, datum: InlineDatum(element) }
}

/// The power-users ROOT with an empty list.
fn pu_root_input(ix: Int) -> Input {
  let element: Element<Data, PowerUser> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link: None,
  }
  Input {
    output_reference: oref(ix),
    output: Output {
      address: Address {
        payment_credential: Script(pu_script_hash),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(pu_policy, constants.linked_list_root_key, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

/// A compliant token UTxO: PLB script payment credential + inline owner stake
/// credential.
fn token_utxo(policy: ByteArray, stake: ByteArray, amount: Int) -> Output {
  token_utxo_at(Script(plb_hash), policy, stake, amount)
}

fn token_utxo_at(
  payment: Credential,
  policy: ByteArray,
  stake: ByteArray,
  amount: Int,
) -> Output {
  Output {
    address: Address {
      payment_credential: payment,
      stake_credential: Some(Inline(VerificationKey(stake))),
    },
    value: merge(from_lovelace(2_000_000), from_asset(policy, sec_name, amount)),
    datum: NoDatum,
    reference_script: None,
  }
}

fn token_input(
  ix: Int,
  policy: ByteArray,
  stake: ByteArray,
  amount: Int,
) -> Input {
  Input {
    output_reference: oref(ix),
    output: token_utxo(policy, stake, amount),
  }
}

/// A compliant token UTxO whose owner is an arbitrary `Credential`, so a
/// test can put the SAME 28-byte hash behind both constructors.
fn token_utxo_owned_by(owner: Credential, amount: Int) -> Output {
  Output {
    address: Address {
      payment_credential: Script(plb_hash),
      stake_credential: Some(Inline(owner)),
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(issuance_policy, sec_name, amount),
    ),
    datum: NoDatum,
    reference_script: None,
  }
}

fn token_input_owned_by(ix: Int, owner: Credential, amount: Int) -> Input {
  Input {
    output_reference: oref(ix),
    output: token_utxo_owned_by(owner, amount),
  }
}

fn attacker_held_ll_nft(policy: ByteArray, key: ByteArray) -> Output {
  Output {
    address: Address {
      payment_credential: VerificationKey(attacker_wallet),
      stake_credential: None,
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(policy, ll_asset_name(key), 1),
    ),
    datum: NoDatum,
    reference_script: None,
  }
}

fn base_tx() -> Transaction {
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

fn dummy_proof() -> KycProof {
  Attestation {
    kyc_proof: AttestationProof {
      payload: #"",
      signature: #"",
      issuer_vkey: #"",
    },
  }
}

fn src_action(covering_ix: Int) -> TransferLogicScriptAction {
  TransferLogicScriptAction {
    source_proof: dummy_proof(),
    source_denylist_covering_ref_input_index: covering_ix,
  }
}

fn dst_action(covering_ix: Int) -> TransferLogicScriptDestinationAction {
  TransferLogicScriptDestinationAction {
    destination_proof: dummy_proof(),
    destination_denylist_covering_ref_input_index: covering_ix,
  }
}

fn mint_dst_action(covering_ix: Int) -> MintingLogicDestinationAction {
  MintingLogicDestinationAction {
    destination_proof: dummy_proof(),
    destination_denylist_covering_ref_input_index: covering_ix,
  }
}

// ── Handler runners ─────────────────────────────────────────────────────────

fn run_transfer(
  redeemer: TransferLogicScriptWithdrawRedeemer,
  tx: Transaction,
) -> Bool {
  v_transfer.transfer_logic_validator.withdraw(
    sec_name,
    gs_policy,
    issuance_policy,
    denylist_script_hash,
    redeemer,
    Script(transfer_hash),
    tx,
  )
}

fn run_authority(
  redeemer: MintingAuthorityWithdrawRedeemer,
  tx: Transaction,
) -> Bool {
  v_minting_authority.minting_authority_validator.withdraw(
    sec_name,
    gs_policy,
    registry_policy,
    pu_policy,
    proxy_hash,
    issuance_policy,
    denylist_script_hash,
    pu_script_hash,
    reference_name,
    redeemer,
    Script(authority_hash),
    tx,
  )
}

// ============================================================================
// PROPERTY: every movement of the security token is gated by a live
// denylist-absence proof and, when required, a valid KYC proof.
// ============================================================================

// The decoy-registry-node bypass test formerly here is gone: this property
// is now delegated to the base layer. `transfer_logic_validator` no longer
// reads a registry node at all — the policy it polices is pinned at compile
// time — so a decoy node naming this script (registry field 3 is a FREE
// CIP-113 field) has nothing to bypass any more.

/// A SANCTIONED holder attempts to move the real token with sender AND
/// receiver KYC both switched on and their own denylist entry sitting in the
/// reference inputs. The sanctioned party's own node is the covering
/// candidate, and `covers_key` (lib/denylist/absence.ak:23) rejects a node
/// whose key equals the target.
test transfer_rejects_a_sanctioned_sender_via_the_genuine_node() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [token_input(10, issuance_policy, dl_sanctioned_key, 1_000)],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_sanctioned_key, None),
    ],
    outputs: [token_utxo(issuance_policy, dl_sanctioned_key, 1_000)],
  }
  !run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

// ============================================================================
// PROPERTY: a covering-node absence proof succeeds exactly when the target is
// absent from the list — no more, and no less. Both directions matter: the
// defect this pins let a sanctioned key prove its own absence AND stranded
// clean holders who could not prove theirs.
// ============================================================================

/// THE DEFECT. The link-prefix mismatch in isolation. The denylist holds
/// P(key=0x0101..) -> S(key=0x0a0a0a0a5555..). `insert_ascending` (check 5)
/// stored P.link as the BARE key S, but `get_element_info`
/// (linked-list.ak:1109-1114) hands it back as `drop(4, S)` = 0x5555.. — so
/// `covers_key` compares S against 0x5555.., concludes S precedes the successor,
/// and certifies the SANCTIONED key as absent.
///
/// The condition is just `S[0] < S[4]`: true for roughly half of all credential
/// hashes, grindable in minutes for the rest.
///
/// THE GUARD. `verify_denylist_absence` reads the link from the
/// node's DATUM instead of from `get_element_info`, so `covers_from_above`
/// compares S against S and correctly refuses to certify a present key.
/// Returns False rather than trapping, hence `!`.
test denylisted_key_cannot_prove_its_own_absence() {
  !verify_denylist_absence(
    dl_sanctioned_key,
    0,
    [dl_node_input(0, dl_pred_key, Some(dl_sanctioned_key))],
    denylist_policy,
    denylist_script_hash,
  )
}

/// The end-to-end coverage `lib/denylist/absence.ak` said was "deferred to
/// integration-level testing" — the gap hid in. A one-entry list cannot
/// expose the bug (a `Root` element's link is returned unstripped), so this
/// runs a real two-node list and checks the proof in BOTH directions.
test denylist_absence_is_sound_and_complete_over_a_real_list() {
  let dl = [
    // P -> S
    dl_node_input(0, dl_pred_key, Some(dl_sanctioned_key)),
    // S -> tail
    dl_node_input(1, dl_sanctioned_key, None),
  ]
  and {
    // `dl_frozen_key` sorts strictly between P and S: absent, and provable
    // through P. This is the direction broke by stranding honest holders.
    verify_denylist_absence(
      dl_frozen_key,
      0,
      dl,
      denylist_policy,
      denylist_script_hash,
    ),
    // S is PRESENT. No node in the list may certify its absence — neither its
    // predecessor (the bypass) nor S itself.
    !verify_denylist_absence(
      dl_sanctioned_key,
      0,
      dl,
      denylist_policy,
      denylist_script_hash,
    ),
    !verify_denylist_absence(
      dl_sanctioned_key,
      1,
      dl,
      denylist_policy,
      denylist_script_hash,
    ),
  }
}

/// THE DEFECT, end to end. The same bug driven through the real validator with THIS
/// token's genuine registry node: a sanctioned holder transfers the security
/// token while their denylist entry is live on chain.
///
/// THE GUARD. The absence proof returns False, which flows into
/// the `and { }` result rather than trapping, hence `!`.
test transfer_rejects_a_sanctioned_holder_end_to_end() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [token_input(10, issuance_policy, dl_sanctioned_key, 1_000)],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, Some(dl_sanctioned_key)),
    ],
    outputs: [token_utxo(issuance_policy, dl_sanctioned_key, 1_000)],
  }
  !run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

/// THE DEFECT — a denial of service: the same bug in the other direction, and the one that strands
/// funds. `dl_frozen_key` is NOT sanctioned and P is genuinely its covering node
/// (P.key < target < P.link). But P.link reads back as
/// `drop(4, 0xaaaaaaaa0000..)` = 24 zero bytes, which sorts below every possible
/// 28-byte key, so `covers_from_above` can never hold. In a sorted list no other
/// node can cover the target either — the holder's tokens are unspendable until
/// an operator happens to rewrite that link.
///
/// THE GUARD, and a POSITIVE one, and the only one in this file
/// that asserts ACCEPTANCE. P's link is read from the datum as the bare key
/// `dl_hostile_next_key`, which correctly sorts above `dl_frozen_key`, so the
/// legitimate transfer must SUCCEED. If someone reverts the fix this test
/// flips back to failing.
test transfer_accepts_a_clean_holder_with_a_high_successor_link() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [token_input(10, issuance_policy, dl_frozen_key, 1_000)],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, Some(dl_hostile_next_key)),
    ],
    outputs: [token_utxo(issuance_policy, dl_frozen_key, 1_000)],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

// ============================================================================
// PROPERTY: a linked-list element is authoritative only while it lives at its
// list's script address — and its NFT cannot be carried out of the list.
// ============================================================================

/// THE DEFECT. `authenticate_element_utxo_and_get_info` checks the datum shape and
/// the single NFT — never the element's ADDRESS. So one denylist-policy NFT in
/// an attacker's own wallet, with an attacker-authored `link`, is accepted as a
/// covering node for ANY target. Keyed at the lowest possible key with no
/// successor, it certifies absence for every credential on chain.
///
/// THE GUARD. `verify_denylist_absence` takes the denylist
/// SPEND validator's hash as a compile-time parameter and requires the covering
/// element to still live there. The forged node sits at a `VerificationKey`
/// address, so the `expect Script(...)` pattern match TRAPS — hence `fail`,
/// not `!`.
test absence_proof_rejects_a_covering_node_in_a_wallet() fail {
  verify_denylist_absence(
    dl_sanctioned_key,
    0,
    [dl_forged_node_at_attacker(0, dl_lowest_key, None)],
    denylist_policy,
    denylist_script_hash,
  )
}

/// THE DEFECT — how the NFT gets out. `denylist_validator.spend` delegates
/// everything to the mint validator and asks only "is SOME denylist token
/// minted or burnt in this transaction". The mint validator's
/// `insert_ascending` inspects exactly three element UTxOs, so any FOURTH
/// denylist node spent alongside a legitimate insert is unconstrained — its NFT
/// can go anywhere, including an attacker's wallet, which is exactly the
/// precondition `absence_proof_rejects_a_covering_node_in_a_wallet` needs.
///
/// REWRITTEN to invoke the MINT validator.
/// The `spend` handler is unchanged by the fix (it still just asks the mint
/// field a question), so probing it would prove nothing; the constraint lives
/// in the mint branches, which must run for any list mutation. This is a
/// legitimate `AddToDenylist` insert — admin power user, correct anchor, one
/// NFT minted — with ONE EXTRA denylist node spent alongside. The branch pins
/// the list-policy input count at 1, so it returns False, hence `!`.
test denylist_insert_rejects_a_smuggled_extra_node_input() {
  // Exactly `dl_insert_tx`'s shape — proven valid by
  // `denylist_insert_succeeds_for_an_admin_power_user_in_the_list` — with
  // ONE EXTRA denylist node spent alongside, whose NFT would otherwise be free
  // to land in `attacker_held_ll_nft` below. Building on the known-good shape
  // is what makes this test isolate the input count rather than pass for some
  // unrelated reason.
  let valid = dl_insert_tx(
    pu_node_input(1, power_user(True, False, False, False, False)),
  )
  let tx = Transaction {
    ..valid,
    inputs: [dl_root_input(0), dl_node_input(1, dl_sanctioned_key, None)],
    outputs: list.concat(
      valid.outputs,
      [attacker_held_ll_nft(denylist_policy, dl_sanctioned_key)],
    ),
  }
  !run_denylist_add(tx)
}

// ── Remove, Init and Deinit through the mint validators ─────────────────────
//
// These branches changed shape most in the v1.8.0 linked-list migration:
// `remove` no longer takes two input indices, it takes the anchor's
// OutputReference and finds both spent elements itself. The tests below pin
// that the anchor is still identified correctly and that a wrong index FAILS
// rather than silently removing the wrong entry.

/// A legitimate `RemoveFromDenylist`: the root anchor and the node being
/// removed are both spent, the root is reproduced pointing past it, and the
/// node's NFT is burnt.
fn dl_remove_tx() -> Transaction {
  Transaction {
    ..base_tx(),
    // The anchor must LINK to the node being removed, and its reproduction
    // inherits that node's own link — here `None`, since the list is
    // root -> frozen -> tail.
    inputs: [
      dl_root_input_linked(0, Some(dl_frozen_key)),
      dl_node_sanction_input(1, dl_frozen_key, None),
    ],
    reference_inputs: [
      gs_utxo(0, 2_000_000, gs_datum(False, False, False, False)),
      pu_node_input(1, power_user(True, False, False, False, False)),
    ],
    mint: from_asset(denylist_policy, ll_asset_name(dl_frozen_key), -1),
    outputs: [dl_root_output(None)],
    extra_signatories: [pu_cred],
  }
}

fn run_denylist_remove(anchor_ix: Int, tx: Transaction) -> Bool {
  v_denylist.mint.mint(
    gs_policy,
    oref(99),
    pu_script_hash,
    RemoveFromDenylist {
      user_pkh: dl_frozen_key,
      anchor_node_input_index: anchor_ix,
      anchor_node_output_index: 0,
      global_state_ref_input_index: 0,
      power_user_node_ref_input_index: 1,
    },
    denylist_policy,
    tx,
  )
}

/// POSITIVE control. Index 0 is the root, which is the anchor.
test denylist_remove_succeeds_for_an_admin_power_user() {
  run_denylist_remove(0, dl_remove_tx())
}

/// The anchor index names the REMOVED node instead of the root. The library
/// resolves the anchor by OutputReference, so this must fail rather than
/// quietly treating the wrong element as the anchor.
test denylist_remove_rejects_a_wrong_anchor_index() fail {
  run_denylist_remove(1, dl_remove_tx())
}

/// The removal is bound to the key the redeemer names: the transaction removes
/// `dl_frozen_key`, so a redeemer claiming a different key must fail. Without
/// this, an admin could declare one un-sanctioning and perform another.
test denylist_remove_is_bound_to_the_declared_key() fail {
  v_denylist.mint.mint(
    gs_policy,
    oref(99),
    pu_script_hash,
    RemoveFromDenylist {
      user_pkh: dl_sanctioned_key,
      anchor_node_input_index: 0,
      anchor_node_output_index: 0,
      global_state_ref_input_index: 0,
      power_user_node_ref_input_index: 1,
    },
    denylist_policy,
    dl_remove_tx(),
  )
}

/// A non-admin power user cannot un-sanction, exactly as they cannot sanction.
test denylist_remove_rejects_a_non_admin_power_user() {
  !run_denylist_remove(
    0,
    Transaction {
      ..dl_remove_tx(),
      reference_inputs: [
        gs_utxo(0, 2_000_000, gs_datum(False, False, False, False)),
        pu_node_input(1, power_user(False, True, True, True, True)),
      ],
    },
  )
}

/// `Init` — genesis. The nonce UTxO must be spent and no list element may
/// exist yet.
test denylist_init_succeeds_on_the_nonce_utxo() {
  v_denylist.mint.mint(
    gs_policy,
    oref(50),
    pu_script_hash,
    DenylistInit { root_output_index: 0 },
    denylist_policy,
    Transaction {
      ..base_tx(),
      inputs: [nonce_input(50)],
      mint: from_asset(denylist_policy, constants.linked_list_root_key, 1),
      outputs: [dl_root_output(None)],
    },
  )
}

/// Without the one-shot nonce input, genesis must fail — otherwise anyone
/// could create a second, parallel "denylist" and point a deployment at it.
/// `init` guards this with `expect nonce_validated`, which TRAPS, hence `fail`.
test denylist_init_rejects_a_missing_nonce() fail {
  v_denylist.mint.mint(
    gs_policy,
    oref(50),
    pu_script_hash,
    DenylistInit { root_output_index: 0 },
    denylist_policy,
    Transaction {
      ..base_tx(),
      inputs: [],
      mint: from_asset(denylist_policy, constants.linked_list_root_key, 1),
      outputs: [dl_root_output(None)],
    },
  )
}

/// `Deinit` — burning the root. Admin-signed, and only on an empty list.
test denylist_deinit_succeeds_for_the_admin_on_an_empty_list() {
  v_denylist.mint.mint(
    gs_policy,
    oref(99),
    pu_script_hash,
    DenylistDeinit { global_state_ref_input_index: 0 },
    denylist_policy,
    Transaction {
      ..base_tx(),
      inputs: [dl_root_input(0)],
      reference_inputs: [
        gs_utxo(0, 2_000_000, gs_datum(False, False, False, False)),
      ],
      mint: from_asset(denylist_policy, constants.linked_list_root_key, -1),
      extra_signatories: [admin],
    },
  )
}

/// Unsigned by the admin, the root cannot be burnt — otherwise anyone could
/// destroy the sanctions list while it happened to be empty.
test denylist_deinit_rejects_a_missing_admin_signature() {
  !v_denylist.mint.mint(
    gs_policy,
    oref(99),
    pu_script_hash,
    DenylistDeinit { global_state_ref_input_index: 0 },
    denylist_policy,
    Transaction {
      ..base_tx(),
      inputs: [dl_root_input(0)],
      reference_inputs: [
        gs_utxo(0, 2_000_000, gs_datum(False, False, False, False)),
      ],
      mint: from_asset(denylist_policy, constants.linked_list_root_key, -1),
    },
  )
}

/// The `spend` handler, kept as an explicit record that
/// the input-count fix did NOT change it. It still delegates wholesale to the mint
/// validator, so on its own it accepts. That is fine — it is no longer
/// reachable with an unconstrained extra element, because the mint validator
/// must also run and now counts inputs.
test denylist_spend_handler_is_pure_delegation() {
  let no_datum: Option<Data> = None
  v_denylist.denylist_validator.spend(
    denylist_policy,
    no_datum,
    DenylistStateTransition,
    oref(0),
    Transaction {
      ..base_tx(),
      inputs: [dl_node_input(0, dl_sanctioned_key, None)],
      mint: from_asset(denylist_policy, ll_asset_name(dl_pred_key), 1),
      outputs: [attacker_held_ll_nft(denylist_policy, dl_sanctioned_key)],
    },
  )
}

// ── The denylist's own power-user read ──────────────────────────────────────
//
// `denylist.mint`'s `power_user_from_refs` authenticates the power-user node
// that authorises a sanction. Like every other element read it ignored the
// address, so a power-user NFT in a wallet could authorise sanctions with
// whatever role flags its holder wrote. The smuggled-input test above stops at
// the input-count check, so these cover the address pin directly.

/// A legitimate `AddToDenylist`: an admin power user in the list, one anchor
/// spent, the root reproduced pointing at the new node. The positive control —
/// without it the negative below would also pass if the branch were broken.
fn dl_insert_tx(pu_node: Input) -> Transaction {
  Transaction {
    ..base_tx(),
    inputs: [dl_root_input(0)],
    reference_inputs: [
      gs_utxo(0, 2_000_000, gs_datum(False, False, False, False)),
      pu_node,
    ],
    mint: from_asset(denylist_policy, ll_asset_name(dl_frozen_key), 1),
    // The appended node's data must decode as `Denylist` — the mint branch
    // asserts it. `dl_node_output`'s placeholder datum is fine for the absence
    // proof (which reads only the link) but not for an insert.
    outputs: [
      dl_root_output(Some(dl_frozen_key)),
      dl_sanction_node_output(dl_frozen_key, None),
    ],
    extra_signatories: [pu_cred],
  }
}

fn run_denylist_add(tx: Transaction) -> Bool {
  v_denylist.mint.mint(
    gs_policy,
    oref(99),
    pu_script_hash,
    AddToDenylist {
      user_pkh: dl_frozen_key,
      anchor_node_output_index: 0,
      appended_node_output_index: 1,
      global_state_ref_input_index: 0,
      power_user_node_ref_input_index: 1,
    },
    denylist_policy,
    tx,
  )
}

test denylist_insert_succeeds_for_an_admin_power_user_in_the_list() {
  run_denylist_add(
    dl_insert_tx(pu_node_input(1, power_user(True, False, False, False, False))),
  )
}

/// Same node, same NFT, same `is_admin` datum — in a wallet. The
/// `expect Script(..)` pattern match traps, hence `fail`.
test wallet_held_power_user_node_cannot_authorise_a_sanction() fail {
  run_denylist_add(
    dl_insert_tx(
      pu_node_at(
        1,
        power_user(True, False, False, False, False),
        VerificationKey(attacker_wallet),
      ),
    ),
  )
}

/// And parked at some other SCRIPT address, which reaches the equality
/// assertion rather than the pattern match.
test misplaced_power_user_node_cannot_authorise_a_sanction() fail {
  run_denylist_add(
    dl_insert_tx(
      pu_node_at(
        1,
        power_user(True, False, False, False, False),
        Script(denylist_script_hash),
      ),
    ),
  )
}

/// THE DEFECT — the same hole in the power-users list. A power-user node NFT can be
/// carried out of the list script during any list mint. Because
/// `get_element_info` ignores the address, that NFT then authenticates a
/// power-user datum with EVERY role flag set, wherever it sits.
///
/// Rewritten against `power_users.mint` for the
/// same reason as its denylist twin. A legitimate admin-signed `AddPowerUser`
/// insert with
/// one extra power-user node spent alongside; the branch pins the list-policy
/// input count at 1.
/// A legitimate admin-signed `AddPowerUser`: the root anchor spent and
/// reproduced pointing at the new node, one NFT minted. Positive control for
/// the smuggled-input test below — without it, that test could pass for a
/// reason unrelated to the input count.
fn pu_insert_tx() -> Transaction {
  Transaction {
    ..base_tx(),
    inputs: [pu_root_input(0)],
    reference_inputs: [
      gs_utxo(0, 2_000_000, gs_datum(False, False, False, False)),
    ],
    mint: from_asset(pu_policy, ll_asset_name(clean_stake), 1),
    outputs: [
      pu_root_output(Some(clean_stake)),
      pu_new_node_output(clean_stake),
    ],
    extra_signatories: [admin],
  }
}

fn run_power_users_add(tx: Transaction) -> Bool {
  v_power_users.mint.mint(
    gs_policy,
    oref(99),
    AddPowerUser {
      new_power_user_key: clean_stake,
      anchor_node_output_index: 0,
      appended_node_output_index: 1,
      global_state_ref_input_index: 0,
    },
    pu_policy,
    tx,
  )
}

test power_user_insert_succeeds_when_the_admin_signs() {
  run_power_users_add(pu_insert_tx())
}

test power_user_insert_rejects_a_smuggled_extra_node_input() {
  // `pu_insert_tx`'s shape with ONE EXTRA power-user node spent alongside —
  // the node whose NFT then lands in the attacker's wallet, still
  // authenticating a datum with every role flag set.
  let valid = pu_insert_tx()
  let tx = Transaction {
    ..valid,
    inputs: [
      pu_root_input(0),
      pu_node_input(1, power_user(True, True, True, True, True)),
    ],
    outputs: list.concat(
      valid.outputs,
      [attacker_held_ll_nft(pu_policy, pu_cred)],
    ),
  }
  !run_power_users_add(tx)
}

/// The power-users ROOT as an INPUT with a settable link.
fn pu_root_input_linked(ix: Int, link: Option<ByteArray>) -> Input {
  Input { output_reference: oref(ix), output: pu_root_output(link) }
}

/// A legitimate `RemovePowerUser`: the root anchor links to the operator being
/// revoked, both are spent, and the node's NFT is burnt.
fn pu_remove_tx() -> Transaction {
  Transaction {
    ..base_tx(),
    inputs: [
      pu_root_input_linked(0, Some(clean_stake)),
      Input {
        output_reference: oref(1),
        output: pu_new_node_output(clean_stake),
      },
    ],
    reference_inputs: [
      gs_utxo(0, 2_000_000, gs_datum(False, False, False, False)),
    ],
    mint: from_asset(pu_policy, ll_asset_name(clean_stake), -1),
    outputs: [pu_root_output(None)],
    extra_signatories: [admin],
  }
}

fn run_power_users_remove(anchor_ix: Int, tx: Transaction) -> Bool {
  v_power_users.mint.mint(
    gs_policy,
    oref(99),
    RemovePowerUser {
      power_user_key_to_remove: clean_stake,
      anchor_node_input_index: anchor_ix,
      anchor_node_output_index: 0,
      global_state_ref_input_index: 0,
    },
    pu_policy,
    tx,
  )
}

/// POSITIVE control. Revoking an operator must work — this is the mechanism
/// the whole role model depends on.
test power_user_remove_succeeds_when_the_admin_signs() {
  run_power_users_remove(0, pu_remove_tx())
}

/// The anchor index names the node being removed rather than the root.
/// Must fail closed.
test power_user_remove_rejects_a_wrong_anchor_index() fail {
  run_power_users_remove(1, pu_remove_tx())
}

/// Revocation is bound to the key the redeemer declares.
test power_user_remove_is_bound_to_the_declared_key() fail {
  v_power_users.mint.mint(
    gs_policy,
    oref(99),
    RemovePowerUser {
      power_user_key_to_remove: pu_cred,
      anchor_node_input_index: 0,
      anchor_node_output_index: 0,
      global_state_ref_input_index: 0,
    },
    pu_policy,
    pu_remove_tx(),
  )
}

/// Without the admin signature an operator cannot be revoked — and, more to
/// the point, cannot revoke someone else.
test power_user_remove_rejects_a_missing_admin_signature() {
  !run_power_users_remove(
    0,
    Transaction { ..pu_remove_tx(), extra_signatories: [] },
  )
}

/// As for the denylist, the power-users `spend` handler is unchanged by
/// the input-count fix and still delegates wholesale.
test power_user_spend_handler_is_pure_delegation() {
  let no_datum: Option<Data> = None
  v_power_users.power_users_validator.spend(
    gs_policy,
    pu_policy,
    no_datum,
    PuStateTransition,
    oref(0),
    Transaction {
      ..base_tx(),
      inputs: [pu_node_input(0, power_user(True, True, True, True, True))],
      mint: from_asset(pu_policy, ll_asset_name(clean_stake), 1),
      outputs: [attacker_held_ll_nft(pu_policy, pu_cred)],
    },
  )
}

// ============================================================================
// PROPERTY (deliberately NARROW): `transfers_paused` halts TRANSFERS. It does
// not halt issuance — see the two tests below, which assert intended behaviour.
// ============================================================================

/// ACCEPTED RISK — this test asserts the INTENDED behaviour and is left
/// passing deliberately. Do not "fix" it.
///
/// `verify_mint_or_burn` reads `deactivated` but never `transfers_paused`, so
/// new supply can be issued during a pause. PRODUCT DECISION (on record):
/// pause gates the two TRANSFER logic scripts only, mirroring the CMTAT
/// reference implementation, where mint/burn go through `_update` rather than
/// the pause-checked transfer path — and mirroring the seizure exemption
/// `third_party_transfer_logic_script.ak` already documents. The rationale and
/// the one-line change that would reverse it live beside the deactivation
/// check in `validators/minting_authority.ak`.
///
/// Note the coupling: pause is the emergency brake, so its scope matters. Since
/// closed the registry-confusion bypass, pause is no longer the only thing
/// standing between an attacker and an uncontrolled transfer.
test mint_succeeds_while_transfers_are_paused_by_design() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [gs_utxo(0, 2_000_000, gs_datum(True, False, False, False))],
    reference_inputs: [
      pu_node_input(0, power_user(False, True, False, False, False)),
      registry_node_input(1, genuine_node()),
      dl_root_input(2),
    ],
    outputs: [token_utxo(issuance_policy, clean_stake, 1_000)],
    mint: from_asset(issuance_policy, sec_name, 1_000),
    extra_signatories: [pu_cred],
  }
  run_authority(
    MintBurn {
      global_state_input_index: 0,
      power_user_node_ref_input_index: 0,
      minted_amount: 1_000,
      destination_actions: [mint_dst_action(2)],
    },
    tx,
  )
}

/// ACCEPTED RISK, as for minting — asserts intended behaviour, left passing
/// deliberately. Burning is equally unaffected by the pause. A court- or
/// regulator-ordered burn must not have to wait for an unpause, which is the
/// same reasoning that exempts forced transfers.
test burn_succeeds_while_transfers_are_paused_by_design() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [gs_utxo(0, 2_000_000, gs_datum(True, False, False, False))],
    reference_inputs: [
      pu_node_input(0, power_user(False, False, True, False, False)),
      registry_node_input(1, genuine_node()),
      dl_root_input(2),
    ],
    outputs: [],
    mint: from_asset(issuance_policy, sec_name, -1_000),
    extra_signatories: [pu_cred],
  }
  run_authority(
    MintBurn {
      global_state_input_index: 0,
      power_user_node_ref_input_index: 0,
      minted_amount: -1_000,
      destination_actions: [],
    },
    tx,
  )
}

// ============================================================================
// PROPERTY: supply lands and stays inside the CIP-113 programmable-logic base,
// where transfer logic can reach it.
// ============================================================================

// The mint- and transfer-path "destination outside the programmable base"
// tests formerly here are gone: that property is now delegated to the base
// layer. `issuance_mint`'s `no_escape` (mint) and transfer conservation
// (`tokens.contains(PLB outputs, PLB inputs)` per policy, transfer) were
// verified 2026-08-19 to already forbid this independently of the payment-
// credential pins this repo used to assert on top of them.

// ── The two credential forms of one hash are two parties ────────────────────
//
// An earlier revision identified holders by a bare 28-byte hash, so
// `VerificationKey(H)` and `Script(H)` collapsed into ONE party sharing ONE KYC
// proof. The base layer authorises them differently
// (`programmable_logic/owner.ak`: signature vs withdraw-0), so they are not one
// party. Deduplication now runs over the full `Credential`.
//
// Two dedup implementations exist and both are covered here: the in-fold
// `list.has` dedupe in the transfer path, and the hand-rolled recursion in
// `minting_authority.verify_mint_destinations`.

/// POSITIVE. One holder hash behind BOTH credential forms, each supplying its
/// own action. Two senders and two destinations, so two of each. Must succeed.
test transfer_treats_key_and_script_forms_of_one_hash_as_two_parties() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [
      token_input_owned_by(10, VerificationKey(clean_stake), 1_000),
      token_input_owned_by(11, Script(clean_stake), 1_000),
    ],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, None),
    ],
    outputs: [
      token_utxo_owned_by(VerificationKey(clean_stake), 1_000),
      token_utxo_owned_by(Script(clean_stake), 1_000),
    ],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2), src_action(2)],
      destination_actions: [dst_action(2), dst_action(2)],
    },
    tx,
  )
}

/// NEGATIVE, and the one that proves the dedup actually changed. The identical
/// transaction with only ONE sender action: pre-the two forms merged into a
/// single party and one action sufficed. Now there are two parties, so
/// `safe_list_at` runs off the end of the action list and TRAPS — hence `fail`.
test transfer_rejects_one_action_covering_both_credential_forms() fail {
  let tx = Transaction {
    ..base_tx(),
    inputs: [
      token_input_owned_by(10, VerificationKey(clean_stake), 1_000),
      token_input_owned_by(11, Script(clean_stake), 1_000),
    ],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, None),
    ],
    outputs: [
      token_utxo_owned_by(VerificationKey(clean_stake), 1_000),
      token_utxo_owned_by(Script(clean_stake), 1_000),
    ],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2)],
      destination_actions: [dst_action(2), dst_action(2)],
    },
    tx,
  )
}

// ============================================================================
// PROPERTY: only a `can_mint` power user creates supply, and every mint
// destination is vetted.
// ============================================================================

// The mint-path "registry node keyed to a foreign policy" test formerly here
// is gone: `MintBurn` no longer reads a registry node at all, so a decoy
// node has nothing left to name. The policy this branch mints/burns is
// pinned at compile time (`expected_issuance_policy_id`), and the base layer
// already authenticates whichever registry node invoked this withdraw-0.

/// on the MINT path, which uses a DIFFERENT dedup implementation — the
/// hand-rolled recursion in `verify_mint_destinations`, not the transfer
/// path's in-fold `list.has` dedupe. Two
/// destinations sharing a hash behind different credential forms need two
/// actions. POSITIVE control.
test mint_treats_key_and_script_forms_of_one_hash_as_two_destinations() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [gs_utxo(0, 2_000_000, gs_datum(False, False, False, False))],
    reference_inputs: [
      pu_node_input(0, power_user(False, True, False, False, False)),
      registry_node_input(1, genuine_node()),
      dl_root_input(2),
    ],
    outputs: [
      token_utxo_owned_by(VerificationKey(clean_stake), 500),
      token_utxo_owned_by(Script(clean_stake), 500),
    ],
    mint: from_asset(issuance_policy, sec_name, 1_000),
    extra_signatories: [pu_cred],
  }
  run_authority(
    MintBurn {
      global_state_input_index: 0,
      power_user_node_ref_input_index: 0,
      minted_amount: 1_000,
      destination_actions: [mint_dst_action(2), mint_dst_action(2)],
    },
    tx,
  )
}

/// NEGATIVE mirror: one action for the pair. `verify_mint_destinations` hits
/// `expect [action, ..rest_actions] = actions` with an empty list on the second
/// destination and TRAPS — hence `fail`. This is what proves `seen` dedupes on
/// the full `Credential` and not on the bare hash.
test mint_rejects_one_action_covering_both_credential_forms() fail {
  let tx = Transaction {
    ..base_tx(),
    inputs: [gs_utxo(0, 2_000_000, gs_datum(False, False, False, False))],
    reference_inputs: [
      pu_node_input(0, power_user(False, True, False, False, False)),
      registry_node_input(1, genuine_node()),
      dl_root_input(2),
    ],
    outputs: [
      token_utxo_owned_by(VerificationKey(clean_stake), 500),
      token_utxo_owned_by(Script(clean_stake), 500),
    ],
    mint: from_asset(issuance_policy, sec_name, 1_000),
    extra_signatories: [pu_cred],
  }
  run_authority(
    MintBurn {
      global_state_input_index: 0,
      power_user_node_ref_input_index: 0,
      minted_amount: 1_000,
      destination_actions: [mint_dst_action(2)],
    },
    tx,
  )
}

// ============================================================================
// Refuted attacks — the load-bearing defences
// ============================================================================

/// A GlobalState-shaped datum with no GlobalState NFT traps in
/// `global_state.is_paused` (lib/types/global_state.ak:345). The NFT is what
/// makes GlobalState authentic, and that check is genuinely load-bearing:
/// without it a forged GlobalState could forge `transfers_paused` and the
/// denylist policy id itself.
///
/// Uses the GENUINE registry node (unused by the validator, kept in this
/// fixture) so the transaction exercises the GlobalState NFT check itself,
/// not some other trap.
test transfer_rejects_a_global_state_without_its_nft() fail {
  let tx = Transaction {
    ..base_tx(),
    inputs: [token_input(10, issuance_policy, dl_sanctioned_key, 1_000)],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_forged(1, gs_datum(False, False, False, False)),
    ],
    outputs: [token_utxo(issuance_policy, dl_sanctioned_key, 1_000)],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [],
      destination_actions: [],
    },
    tx,
  )
}

/// The pause gate reads the REAL GlobalState — its NFT is what makes it
/// authentic — so a transfer that is otherwise entirely valid (genuine
/// covering node, no KYC required) is still rejected while
/// `transfers_paused` is set.
test pause_blocks_an_otherwise_valid_transfer() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [token_input(10, issuance_policy, clean_stake, 1_000)],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(True, False, False, False)),
      dl_node_input(2, dl_pred_key, None),
    ],
    outputs: [token_utxo(issuance_policy, clean_stake, 1_000)],
  }
  !run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

/// The control for the pause test above: the SAME transaction with the pause
/// lifted must be accepted. Without this, that test would still pass if the
/// transfer path broke for some unrelated reason.
test the_same_transfer_succeeds_once_unpaused() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [token_input(10, issuance_policy, clean_stake, 1_000)],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, None),
    ],
    outputs: [token_utxo(issuance_policy, clean_stake, 1_000)],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

// The "registry node that does not name it" test formerly here is gone:
// `derive_issuance_policy_id_from_registry_node`'s identity assertion was
// the single binding the decoy-node bypass had to satisfy, and the whole
// derivation is gone from this handler now — there is no node identity left
// to assert. The compile-time policy pin (`expected_issuance_policy_id`) is
// the sole remaining authentication of which policy this script polices.

// ============================================================================
// PROPERTY: vetting many parties against one denylist covering node authenticates
// that node once and still runs the covering check for every party.
// ============================================================================
//
// `compliance.verify_parties` remembers the covering node it last
// authenticated (reference-input index + key + link) and, for the next party
// citing the SAME index, skips straight to `covers_key`. The tests below pin
// what that must never change: every party is still compared against the
// node's bounds, an index that is not a genuine list element still traps on
// first use, and a negative index never resolves to anything — in particular
// not to a remembered node.

/// A second clean key that P (01…01 → S) also covers: strictly between them.
const dl_second_clean_key: ByteArray =
  #"03030303030303030303030303030303030303030303030303030303"

/// POSITIVE control for the two tests that follow: two senders, both covered
/// by P, both citing P. The second sender is vetted against the remembered
/// bounds and passes. Must succeed.
test shared_covering_node_accepts_two_covered_senders() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [
      token_input(10, issuance_policy, dl_frozen_key, 1_000),
      token_input(11, issuance_policy, dl_second_clean_key, 1_000),
    ],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, Some(dl_sanctioned_key)),
    ],
    outputs: [token_utxo(issuance_policy, dl_frozen_key, 2_000)],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2), src_action(2)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

/// Same transaction, but the SECOND sender is S itself — P's link, so P does
/// not cover it. The first sender primes the remembered node; the second must
/// still be compared against its bounds and fail. `covers_key` returns False,
/// which flows into the `and { }` result, hence `!`.
test shared_covering_node_still_rejects_an_uncovered_second_sender() {
  let tx = Transaction {
    ..base_tx(),
    inputs: [
      token_input(10, issuance_policy, dl_frozen_key, 1_000),
      token_input(11, issuance_policy, dl_sanctioned_key, 1_000),
    ],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, Some(dl_sanctioned_key)),
    ],
    outputs: [token_utxo(issuance_policy, dl_frozen_key, 2_000)],
  }
  !run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2), src_action(2)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

/// A negative covering index on the FIRST party is not a valid reference input
/// and must trap (`safe_list_at` rejects it) — it must never read as "a node
/// was already remembered". Traps, hence `fail`.
test negative_covering_index_traps_on_the_first_party() fail {
  let tx = Transaction {
    ..base_tx(),
    inputs: [token_input(10, issuance_policy, dl_frozen_key, 1_000)],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, Some(dl_sanctioned_key)),
    ],
    outputs: [token_utxo(issuance_policy, dl_frozen_key, 1_000)],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(-1)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

/// The same on a LATER party: the first sender is vetted against P, the
/// second cites -1. A remembered node must not be mistaken for index -1; the
/// index is resolved afresh and traps. Traps, hence `fail`.
test negative_covering_index_traps_on_a_later_party() fail {
  let tx = Transaction {
    ..base_tx(),
    inputs: [
      token_input(10, issuance_policy, dl_frozen_key, 1_000),
      token_input(11, issuance_policy, dl_second_clean_key, 1_000),
    ],
    reference_inputs: [
      registry_node_input(0, genuine_node()),
      gs_utxo(1, 2_000_000, gs_datum(False, False, False, False)),
      dl_node_input(2, dl_pred_key, Some(dl_sanctioned_key)),
    ],
    outputs: [token_utxo(issuance_policy, dl_frozen_key, 2_000)],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 1,
      },
      actions_for_each_input: [src_action(2), src_action(-1)],
      destination_actions: [dst_action(2)],
    },
    tx,
  )
}

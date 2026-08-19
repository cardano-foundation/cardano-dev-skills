use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{
  Element, Node, Root, get_element_info, run_element_with,
}
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{from_asset, from_lovelace, merge, quantity_of}
use cardano/certificate.{Certificate, RegisterCredential}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use constants
use denylist/absence.{verify_denylist_absence}
use kyc/verify.{verify_kyc_proof}
use types/global_state.{GlobalStateDatum}
use types/kyc_proof.{Attestation, AttestationProof, KycProof}
use types/power_users.{PowerUser}
use types/third_party_transfer_logic_script.{
  ThirdPartyDestinationAction, ThirdPartyTransferLogicScriptWithdrawRedeemer,
}
use utils.{must_be_signed_by_credential}

/// Third-party (force) transfer logic for emergency regulatory flows.
///
/// Per-destination check (for each unique destination stake credential):
///   1. If GS.requires_receiver_kyc, a valid KYC proof for the destination (attested by a TEL entity) or the pkh is in the merkle tree root.
///   2. The destination is NOT in the denylist.
///
/// NO source checks — force transfer is an admin override: the source may be
/// denylisted or have expired KYC. That is the point.
///
/// Plus:
///   - Deactivation gate: rejected only once the protocol is `deactivated`.
///     A force transfer is deliberately NOT blocked by a mere pause —
///     enforcement/seizure must remain available during an incident pause (e.g.
///     a regulator- or court-ordered seizure cannot wait for an unpause).
///     PRODUCT DECISION (on record): this follows the CMTAT *reference
///     implementation*, where `forcedTransfer` calls `_transfer` directly and
///     never hits the pause check. It is intentionally *stricter* than that
///     reference (we still block once fully `deactivated`) and intentionally
///     *looser* than a literal reading of the CMTA functional spec's pause
///     ("prevent all transfers"), because enforcement availability is judged
///     more important than a hard "all transfers stop" reading of pause.
///   - Must actually seize: at least one spent input carries the security
///     token (see `at_least_one_seized_input`).
///   - `can_force_transfer` power user signs.
validator third_party_transfer_logic_validator(
  security_asset_name: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
  global_state_policy_id: ByteArray,
  registry_policy_id: ByteArray,
) {
  withdraw(
    redeemer: ThirdPartyTransferLogicScriptWithdrawRedeemer,
    credential: Credential,
    self: Transaction,
  ) {
    let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
      self.reference_inputs,
      registry_policy_id,
      credential,
      constants.third_party_transfer_logic_script_registry_node_index,
      redeemer.registry_node_ref_input_index,
    )

    // Pause + GS-datum decode.
    let gs_input = utils.safe_list_at(
      self.reference_inputs,
      redeemer.global_state_ref_input_index,
    )
    let transfers_deactivated = global_state.is_deactivated(
      gs_input,
      global_state_policy_id,
    )
    expect InlineDatum(gs_datum_raw) = gs_input.output.datum
    expect gs_datum: GlobalStateDatum = gs_datum_raw

    // Unique destination stake-cred hashes from outputs carrying the token.
    let outputs_user_stake_cred_hash = list.unique(
      list.foldr(
        self.outputs,
        [],
        fn(output, result) {
          if quantity_of(output.value, issuance_policy_id, security_asset_name) > 0 {
            expect Some(Inline(stake_cred)) = output.address.stake_credential
            let credential_hash = when stake_cred is {
              VerificationKey(hash) -> hash
              Script(hash) -> hash
            }
            list.push(result, credential_hash)
          } else {
            result
          }
        },
      ),
    )

    // Per-destination: KYC proof + denylist absence.
    let all_destinations_ok = list.indexed_foldr(
      outputs_user_stake_cred_hash,
      True,
      fn(index, dest_pkh, acc) {
        expect acc
        let action = utils.safe_list_at(redeemer.destination_actions, index)
        let kyc_ok = if gs_datum.requires_receiver_kyc {
          verify_kyc_proof(
            action.destination_proof,
            dest_pkh,
            gs_datum,
            issuance_policy_id,
            gs_datum.network_id,
            self,
          )
        } else {
          True
        }
        let denylist_ok = verify_denylist_absence(
          dest_pkh,
          action.destination_denylist_covering_ref_input_index,
          self.reference_inputs,
          gs_datum.denylist_linked_list_policy_id,
        )
        and {
          kyc_ok,
          denylist_ok,
        }
      },
    )

    // Admin-authorised power user with can_force_transfer.
    let power_user_ref_input = utils.safe_list_at(
      self.reference_inputs,
      redeemer.power_user_node_ref_input_index,
    )
    let (power_user_node_key, power_user_data) = get_element_info(
      power_user_ref_input.output,
      fn(_lovelace, node_key, data, _link) {
        expect Some(key) = node_key
        expect power_user_data: PowerUser = data
        (key, power_user_data)
      },
    )
      |> run_element_with(
          power_users_linked_list_policy_id,
          constants.linked_list_root_key,
          constants.linked_list_node_key_prefix,
          constants.linked_list_node_key_prefix_length,
        )

    // H-3(b): a force transfer must actually seize something — at least one
    // spent input must carry the security token. Without this a `can_force_
    // transfer` operator could invoke the third-party path on a transaction
    // that moves no seized tokens (e.g. to satisfy the base layer's logic-
    // script-invoked check while doing something unrelated), or emit spurious
    // "seizure" transactions. Bind the action to real seized value.
    let at_least_one_seized_input = list.any(
      self.inputs,
      fn(input) {
        quantity_of(input.output.value, issuance_policy_id, security_asset_name) > 0
      },
    )

    and {
      transfers_deactivated == False,
      at_least_one_seized_input,
      all_destinations_ok,
      power_user_data.can_force_transfer,
      must_be_signed_by_credential(self, power_user_node_key),
    }
  }

  // Whitelist RegisterCredential only — see minting_logic_script for rationale.
  publish(_r: Data, c: Certificate, _s: Transaction) {
    when c is {
      RegisterCredential { .. } -> True
      _ -> False
    }
  }

  else(_) {
    fail
  }
}

// ============================================================================
// Tests — third_party_transfer_logic_validator.withdraw (handler-level)
// ============================================================================
// Reference-input order: 0 = registry node, 1 = GlobalState, 2 = denylist root,
// 3 = power-user node. The registry node carries DISTINCT transfer (index 3)
// and third-party (index 4) credentials, so the happy-path test doubles as the
// F-1 regression: this validator derives via index 4, so under the old bug
// (index 3) it would authenticate against the transfer credential and trap.

const p_sec_name: ByteArray = "SEC"

const p_gs_policy: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const p_issuance_policy: ByteArray =
  #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

const p_registry_policy: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const p_denylist_policy: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const p_pu_policy: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const p_minting_hash: ByteArray =
  #"f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1"

const p_transfer_hash: ByteArray =
  #"f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2"

// This validator's OWN credential — must equal registry field index 4.
const p_third_party_hash: ByteArray =
  #"f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3"

const p_plb_hash: ByteArray =
  #"05050505050505050505050505050505050505050505050505050505"

const p_pu_cred: ByteArray =
  #"0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c"

const p_source_stake: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"

const p_dest_stake: ByteArray =
  #"0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"

type PRegNode {
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

fn p_out_ref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

fn p_gs_ref_input(paused: Bool, deactivated: Bool, req_receiver: Bool) -> Input {
  let datum = GlobalStateDatum {
    transfers_paused: paused,
    deactivated,
    mintable_amount: 1_000_000,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: p_pu_policy,
    denylist_linked_list_policy_id: p_denylist_policy,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: False,
    requires_receiver_kyc: req_receiver,
    network_id: 1,
  }
  Input {
    output_reference: p_out_ref(1),
    output: Output {
      address: Address {
        payment_credential: Script(p_gs_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(p_gs_policy, constants.global_state_asset_name, 1),
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

fn p_registry_ref_input() -> Input {
  let node = PRegNode {
    key: p_issuance_policy,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(p_minting_hash),
    transfer_logic_script: Script(p_transfer_hash),
    third_party_transfer_logic_script: Script(p_third_party_hash),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: p_gs_policy,
  }
  Input {
    output_reference: p_out_ref(0),
    output: Output {
      address: Address {
        payment_credential: Script(p_registry_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(p_registry_policy, "Node", 1),
      ),
      datum: InlineDatum(node),
      reference_script: None,
    },
  }
}

fn p_denylist_root_ref_input() -> Input {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link: None,
  }
  Input {
    output_reference: p_out_ref(2),
    output: Output {
      address: Address {
        payment_credential: Script(p_denylist_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(p_denylist_policy, constants.linked_list_root_key, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

fn p_pu_node_ref_input(can_force_transfer: Bool) -> Input {
  let pu = PowerUser {
    credential_hash: p_pu_cred,
    is_admin: False,
    can_mint: False,
    can_burn: False,
    can_pause: False,
    can_force_transfer,
  }
  let element: Element<Data, PowerUser> = Element {
    data: Node { data: pu },
    link: None,
  }
  let node_asset_name = bytearray.concat(
    constants.linked_list_node_key_prefix,
    p_pu_cred,
  )
  Input {
    output_reference: p_out_ref(3),
    output: Output {
      address: Address {
        payment_credential: Script(p_pu_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(p_pu_policy, node_asset_name, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

fn p_token_utxo(stake_hash: ByteArray, amount: Int) -> Output {
  Output {
    address: Address {
      payment_credential: Script(p_plb_hash),
      stake_credential: Some(Inline(VerificationKey(stake_hash))),
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(p_issuance_policy, p_sec_name, amount),
    ),
    datum: NoDatum,
    reference_script: None,
  }
}

// A non-token input (no security token) — used for the "nothing seized" case.
fn p_ada_input() -> Input {
  Input {
    output_reference: p_out_ref(11),
    output: Output {
      address: Address {
        payment_credential: Script(p_plb_hash),
        stake_credential: Some(Inline(VerificationKey(p_source_stake))),
      },
      value: from_lovelace(2_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

fn p_seized_input() -> Input {
  Input {
    output_reference: p_out_ref(10),
    output: p_token_utxo(p_source_stake, 1_000),
  }
}

fn p_dummy_proof() -> KycProof {
  Attestation {
    kyc_proof: AttestationProof {
      payload: #"",
      signature: #"",
      issuer_vkey: #"",
    },
  }
}

fn p_dest_action() -> ThirdPartyDestinationAction {
  ThirdPartyDestinationAction {
    destination_proof: p_dummy_proof(),
    destination_denylist_covering_ref_input_index: 2,
  }
}

fn p_redeemer() -> ThirdPartyTransferLogicScriptWithdrawRedeemer {
  ThirdPartyTransferLogicScriptWithdrawRedeemer {
    registry_node_ref_input_index: 0,
    global_state_ref_input_index: 1,
    power_user_node_ref_input_index: 3,
    destination_actions: [p_dest_action()],
  }
}

fn p_tx(
  paused: Bool,
  deactivated: Bool,
  req_receiver: Bool,
  can_force_transfer: Bool,
  inputs: List<Input>,
  signatories: List<ByteArray>,
) -> Transaction {
  Transaction {
    inputs,
    reference_inputs: [
      p_registry_ref_input(),
      p_gs_ref_input(paused, deactivated, req_receiver),
      p_denylist_root_ref_input(),
      p_pu_node_ref_input(can_force_transfer),
    ],
    outputs: [p_token_utxo(p_dest_stake, 1_000)],
    fee: 0,
    mint: assets.zero,
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
    extra_signatories: signatories,
    redeemers: [],
    datums: dict.empty,
    id: #"0000000000000000000000000000000000000000000000000000000000000000",
    votes: [],
    proposal_procedures: [],
    current_treasury_amount: None,
    treasury_donation: None,
  }
}

fn run_third_party(
  redeemer: ThirdPartyTransferLogicScriptWithdrawRedeemer,
  tx: Transaction,
) -> Bool {
  third_party_transfer_logic_validator.withdraw(
    p_sec_name,
    p_pu_policy,
    p_gs_policy,
    p_registry_policy,
    redeemer,
    Script(p_third_party_hash),
    tx,
  )
}

test force_transfer_succeeds_when_clean() {
  // Not deactivated; a seized token input is present; destination clean; power
  // user has can_force_transfer and signs. Also the F-1 regression: derivation
  // uses registry index 4 (third_party), distinct from index 3 (transfer).
  run_third_party(
    p_redeemer(),
    p_tx(False, False, False, True, [p_seized_input()], [p_pu_cred]),
  )
}

test force_transfer_works_while_paused() {
  // Recorded decision: a forced transfer/seizure is NOT blocked by a mere pause
  // (only by full deactivation). Proves enforcement remains available.
  run_third_party(
    p_redeemer(),
    p_tx(True, False, False, True, [p_seized_input()], [p_pu_cred]),
  )
}

test force_transfer_rejected_when_deactivated() {
  !run_third_party(
    p_redeemer(),
    p_tx(True, True, False, True, [p_seized_input()], [p_pu_cred]),
  )
}

test force_transfer_rejected_when_no_seized_input() {
  // H-3(b): no input carries the security token → nothing is actually seized.
  !run_third_party(
    p_redeemer(),
    p_tx(False, False, False, True, [p_ada_input()], [p_pu_cred]),
  )
}

test force_transfer_rejected_without_can_force_transfer() {
  !run_third_party(
    p_redeemer(),
    p_tx(False, False, False, False, [p_seized_input()], [p_pu_cred]),
  )
}

test force_transfer_rejected_when_not_signed() {
  !run_third_party(
    p_redeemer(),
    p_tx(False, False, False, True, [p_seized_input()], []),
  )
}

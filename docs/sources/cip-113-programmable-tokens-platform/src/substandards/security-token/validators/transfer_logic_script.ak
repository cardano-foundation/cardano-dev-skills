use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken_design_patterns/linked_list.{Element, Root}
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
use types/transfer_logic_script.{
  TransferLogicScriptAction, TransferLogicScriptDestinationAction,
  TransferLogicScriptWithdrawRedeemer,
}
use utils

/// Transfer logic for a BAFIN security token (Track 4, TEL+denylist model).
///
/// Per-input check (for each unique sender stake credential):
///   1. The redeemer's matching KYC proof validates against GS.trusted_entity_vkeys or the pkh of the sender is in the GS's merkle tree.
///   2. The sender is NOT in the denylist (covering-node absence proof).
///
/// Per-output check (for each unique destination stake credential):
///   3. The destination is NOT in the denylist. 
///   4. If GS.requires_receiver_kyc, the redeemer's matching KYC proof validates against GS.trusted_entity_vkeys as well (same checks as for senders)
///      or if the pkh of the receiver is in the GS's merkle tree. 
///
/// Plus the pause gate (GS must not be paused).
validator transfer_logic_validator(
  security_asset_name: ByteArray,
  global_state_policy_id: ByteArray,
  registry_policy_id: ByteArray,
) {
  withdraw(
    redeemer: TransferLogicScriptWithdrawRedeemer,
    credential: Credential,
    self: Transaction,
  ) {
    let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
      self.reference_inputs,
      registry_policy_id,
      credential,
      constants.transfer_logic_script_registry_node_index,
      redeemer.registry_node_ref_input_index,
    )

    // 1. Resolve GS reference input and fast-check pause flag.
    let gs_input = utils.safe_list_at(
      self.reference_inputs,
      redeemer.global_state_ref_input_index,
    )
    let transfers_paused = global_state.is_paused(
      gs_input,
      global_state_policy_id,
    )
    let transfers_deactivated = global_state.is_deactivated(
      gs_input,
      global_state_policy_id,
    )

    // 2. Full-parse GS datum so we can read the TEL and denylist policy id.
    expect InlineDatum(gs_datum_raw) = gs_input.output.datum
    expect gs_datum: GlobalStateDatum = gs_datum_raw
    // 3. Aggregate unique sender stake-cred hashes from inputs carrying the
    //    security token.
    let inputs_user_stake_cred_hash = list.unique(
      list.foldr(
        self.inputs,
        [],
        fn(input, result) {
          if quantity_of(
            input.output.value,
            issuance_policy_id,
            security_asset_name,
          ) > 0 {
            expect Some(Inline(stake_cred)) = input.output.address.stake_credential
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

    // 4. Aggregate unique destination stake-cred hashes from outputs carrying
    //    the security token.
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

    // 5. Per-sender: valid KYC proof + denylist absence.
    let all_senders_ok = list.indexed_foldr(
      inputs_user_stake_cred_hash,
      True,
      fn(index, sender_pkh, acc) {
        expect acc
        let action = utils.safe_list_at(redeemer.actions_for_each_input, index)
        let kyc_ok = if gs_datum.requires_sender_kyc {
          verify_kyc_proof(
            action.source_proof,
            sender_pkh,
            gs_datum,
            issuance_policy_id,
            gs_datum.network_id,
            self,
          )
        } else {
          True
        }
        let denylist_ok = verify_denylist_absence(
          sender_pkh,
          action.source_denylist_covering_ref_input_index,
          self.reference_inputs,
          gs_datum.denylist_linked_list_policy_id,
        )
        and {
          kyc_ok,
          denylist_ok,
        }
      },
    )

    // 6. Per-destination: valid KYC proof + denylist absence. Swiss CO
    //    Art. 973e / eWpG §14 / ERC-3643 norm all demand that the recipient
    //    be KYC'd at transfer time (a named creditor / registered holder).
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

    and {
      //General transfers of this token must NOT be paused
      transfers_paused == False,
      transfers_deactivated == False,
      all_senders_ok,
      all_destinations_ok,
    }
  }

  // Whitelist RegisterCredential only — see minting_logic_script for rationale.
  // A rubber-stamp publish would let anyone de-register this script's stake
  // credential via UnregisterCredential, bricking every transfer until
  // re-registered (and paying the attacker the 2 ADA deposit refund).
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
// Tests — transfer_logic_validator.withdraw (handler-level)
// ============================================================================
// Fixtures model the real programmable-token address shape (PLB script payment
// credential + inline owner stake credential) and the CIP-113 registry node
// (this validator's credential at field index 3). GS is a REFERENCE input.
// Reference-input order: 0 = registry node, 1 = GlobalState, 2 = denylist root.

const t_sec_name: ByteArray = "SEC"

const t_gs_policy: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const t_issuance_policy: ByteArray =
  #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

const t_registry_policy: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const t_denylist_policy: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const t_minting_hash: ByteArray =
  #"f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1"

// This validator's OWN credential — must equal registry field index 3.
const t_transfer_hash: ByteArray =
  #"f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2"

const t_third_party_hash: ByteArray =
  #"f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3"

const t_plb_hash: ByteArray =
  #"05050505050505050505050505050505050505050505050505050505"

const t_sender_stake: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"

const t_dest_stake: ByteArray =
  #"0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"

type TRegNode {
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

fn t_out_ref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

fn t_gs_datum(
  paused: Bool,
  deactivated: Bool,
  req_sender: Bool,
  req_receiver: Bool,
) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: paused,
    deactivated,
    mintable_amount: 1_000_000,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: t_denylist_policy,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: req_sender,
    requires_receiver_kyc: req_receiver,
    network_id: 1,
  }
}

fn t_gs_ref_input(
  paused: Bool,
  deactivated: Bool,
  req_sender: Bool,
  req_receiver: Bool,
) -> Input {
  Input {
    output_reference: t_out_ref(1),
    output: Output {
      address: Address {
        payment_credential: Script(t_gs_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(t_gs_policy, constants.global_state_asset_name, 1),
      ),
      datum: InlineDatum(
        t_gs_datum(paused, deactivated, req_sender, req_receiver),
      ),
      reference_script: None,
    },
  }
}

fn t_registry_ref_input() -> Input {
  let node = TRegNode {
    key: t_issuance_policy,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(t_minting_hash),
    transfer_logic_script: Script(t_transfer_hash),
    third_party_transfer_logic_script: Script(t_third_party_hash),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: t_gs_policy,
  }
  Input {
    output_reference: t_out_ref(0),
    output: Output {
      address: Address {
        payment_credential: Script(t_registry_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(t_registry_policy, "Node", 1),
      ),
      datum: InlineDatum(node),
      reference_script: None,
    },
  }
}

fn t_denylist_root_ref_input() -> Input {
  let element: Element<Data, Data> = Element {
    data: Root { data: builtin.constr_data(0, []) },
    link: None,
  }
  Input {
    output_reference: t_out_ref(2),
    output: Output {
      address: Address {
        payment_credential: Script(t_denylist_policy),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(t_denylist_policy, constants.linked_list_root_key, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

fn t_token_utxo(stake_hash: ByteArray, amount: Int) -> Output {
  Output {
    address: Address {
      payment_credential: Script(t_plb_hash),
      stake_credential: Some(Inline(VerificationKey(stake_hash))),
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(t_issuance_policy, t_sec_name, amount),
    ),
    datum: NoDatum,
    reference_script: None,
  }
}

fn t_sender_input(stake_hash: ByteArray, amount: Int) -> Input {
  Input {
    output_reference: t_out_ref(10),
    output: t_token_utxo(stake_hash, amount),
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

// Covering-node index 2 = the empty denylist root (covers every key).
fn t_source_action() -> TransferLogicScriptAction {
  TransferLogicScriptAction {
    source_proof: dummy_proof(),
    source_denylist_covering_ref_input_index: 2,
  }
}

fn t_dest_action() -> TransferLogicScriptDestinationAction {
  TransferLogicScriptDestinationAction {
    destination_proof: dummy_proof(),
    destination_denylist_covering_ref_input_index: 2,
  }
}

fn t_transfer_tx(
  paused: Bool,
  deactivated: Bool,
  req_sender: Bool,
  req_receiver: Bool,
) -> Transaction {
  Transaction {
    inputs: [t_sender_input(t_sender_stake, 1_000)],
    reference_inputs: [
      t_registry_ref_input(),
      t_gs_ref_input(paused, deactivated, req_sender, req_receiver),
      t_denylist_root_ref_input(),
    ],
    outputs: [t_token_utxo(t_dest_stake, 1_000)],
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

fn run_transfer(
  redeemer: TransferLogicScriptWithdrawRedeemer,
  tx: Transaction,
) -> Bool {
  transfer_logic_validator.withdraw(
    t_sec_name,
    t_gs_policy,
    t_registry_policy,
    redeemer,
    Script(t_transfer_hash),
    tx,
  )
}

fn t_redeemer() -> TransferLogicScriptWithdrawRedeemer {
  TransferLogicScriptWithdrawRedeemer {
    registry_node_ref_input_index: 0,
    global_state_ref_input_index: 1,
    actions_for_each_input: [t_source_action()],
    destination_actions: [t_dest_action()],
  }
}

test transfer_succeeds_when_clean() {
  // Not paused, not deactivated, no KYC required, sender & receiver absent from
  // the (empty) denylist.
  run_transfer(t_redeemer(), t_transfer_tx(False, False, False, False))
}

test transfer_rejected_when_paused() {
  !run_transfer(t_redeemer(), t_transfer_tx(True, False, False, False))
}

test transfer_rejected_when_deactivated() {
  // Deactivation implies paused; the explicit `transfers_deactivated == False`
  // gate rejects independently.
  !run_transfer(t_redeemer(), t_transfer_tx(True, True, False, False))
}

test transfer_rejected_when_sender_kyc_required_and_proof_invalid() {
  // F-20 regression: sender gate must read `requires_sender_kyc`. With sender
  // KYC required (receiver OFF) and an invalid sender proof, the transfer is
  // rejected. Under the OLD bug (sender gate read `requires_receiver_kyc`),
  // sender KYC would be SKIPPED here and this would wrongly pass.
  !run_transfer(t_redeemer(), t_transfer_tx(False, False, True, False))
}

test transfer_allowed_when_sender_kyc_not_required() {
  // Same invalid sender proof, but sender KYC not required → skipped → allowed.
  // Confirms the sender flag actually gates the sender check.
  run_transfer(t_redeemer(), t_transfer_tx(False, False, False, False))
}

test transfer_rejected_when_receiver_kyc_required_and_proof_invalid() {
  // Receiver gate reads `requires_receiver_kyc`; invalid receiver proof → reject.
  !run_transfer(t_redeemer(), t_transfer_tx(False, False, False, True))
}

use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/fuzz
use aiken/interval.{
  Finite, Interval, IntervalBound, NegativeInfinity, PositiveInfinity,
}
use aiken/merkle_patricia_forestry as mpf
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{Element, Root}
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{from_asset, from_lovelace, merge, quantity_of}
use cardano/certificate.{Certificate, RegisterCredential}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use compliance
use constants
use kyc/verify.{membership_leaf_key, membership_leaf_value}
use types/global_state.{
  GlobalStateDatum, GlobalStateLocation, GlobalStateReferenced, GlobalStateSpent,
  gs_datum_from_location,
}
use types/kyc_proof.{
  Attestation, AttestationProof, KycProof, Membership, MembershipProof,
}
use types/transfer_logic_script.{
  TransferLogicScriptAction, TransferLogicScriptDestinationAction,
  TransferLogicScriptWithdrawRedeemer,
}

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
  /// The issuance policy this deployment's transfer logic exists to
  /// police, pinned at compile time.
  ///
  /// NOT circular: a CIP-113 registry node's `key` is derived from the MINTING
  /// logic hash, never from this script's hash, so the issuance policy id is
  /// known before this validator is ever compiled. Dependency order is
  /// `gs_policy → proxy hash → issuance_policy_id → this script`.
  ///
  /// This is the ONLY authentication of which policy this script polices —
  /// the withdraw handler no longer reads a CIP-113 registry node at all. The
  /// base layer already authenticates whichever registry node invoked this
  /// withdraw-0 (that authentication is what makes this script run in the
  /// first place), so re-deriving the policy from that same node here would
  /// only re-prove what already held. And the old "this node names me"
  /// identity assertion was never the real defence anyway: registry field 3
  /// is a FREE CIP-113 field, so any wallet may permissionlessly register a
  /// throwaway node naming this script — under the old design that decoy's
  /// foreign policy made every scan below vacuous. The compile-time pin is
  /// what closes that; nothing about "did some node name me" was ever
  /// load-bearing.
  expected_issuance_policy_id: ByteArray,
  /// The DENYLIST SPEND VALIDATOR's script hash, threaded into
  /// `verify_denylist_absence`. See its doc comment.
  denylist_script_hash: ByteArray,
) {
  withdraw(
    redeemer: TransferLogicScriptWithdrawRedeemer,
    credential: Credential,
    self: Transaction,
  ) {
    // A withdrawal credential may be a verification key, so this is a real
    // assertion, not a formality.
    expect Script(_) = credential
    let issuance_policy_id = expected_issuance_policy_id

    // 1. Resolve and AUTHENTICATE GlobalState, then read every flag from the
    //    one parsed datum.
    //
    //    This needs the full datum anyway — for the TEL, the denylist policy id
    //    and the two KYC flags — so the cheap first-field readers
    //    (`is_paused` / `is_deactivated`) buy nothing here and cost real work:
    //    each re-scans the value for the GlobalState NFT and re-decodes the
    //    datum. On the hot path that was two NFT scans and three datum decodes
    //    for one UTxO.
    //
    //    It is also the safer shape. A bare `expect gs: GlobalStateDatum`
    //    authenticates NOTHING — it only checks that the bytes parse — so the
    //    previous form depended on `is_paused` having run first to prove the
    //    NFT was there. `gs_datum_from_ref_input` does the NFT check (`== 1`,
    //    stricter than the `> 0` those readers use) and the parse together, so
    //    the authentication cannot be separated from the read by a later edit.
    let gs_datum: GlobalStateDatum = gs_datum_from_location(
      self.inputs,
      self.reference_inputs,
      redeemer.global_state_location,
      global_state_policy_id,
    )

    // 2. Aggregate unique sender stake-cred hashes from inputs carrying the
    //    security token.
    // The full `Credential` is carried, not a bare 28-byte hash. The
    // constructor is part of the holder's identity: the CIP-113 base layer
    // authorises a `VerificationKey` owner by signature and a `Script` owner by
    // withdraw-0, so they are genuinely different parties. Deduplicating on
    // `Credential` therefore treats them as two, which is what lets the KYC
    // check below bind to the right one. The denylist deliberately keeps
    // keying on the bare hash — see its call site.
    //
    // Deduplicated DURING the fold: `list.has` walks the accumulator without
    // rebuilding it, whereas `list.unique` afterwards filters and re-allocates
    // the remaining list once per element — the same comparisons twice over,
    // plus an allocation per party. Left fold + final reverse keeps the
    // first-occurrence order of the old `foldr`+`unique`, and the order is
    // part of the redeemer contract (actions are matched positionally).
    let inputs_user_credentials = list.reverse(
      list.foldl(
        self.inputs,
        [],
        fn(input, result) {
          if quantity_of(
            input.output.value,
            issuance_policy_id,
            security_asset_name,
          ) > 0 {
            // Senders must also sit INSIDE the programmable-logic base.
            // Guaranteed by the base layer's transfer conservation
            // (`tokens.contains(PLB outputs, PLB inputs)` per policy) — an
            // input carrying this token cannot sit anywhere else, so nothing
            // further to assert here.
            expect Some(Inline(stake_cred)) = input.output.address.stake_credential
            if list.has(result, stake_cred) {
              result
            } else {
              [stake_cred, ..result]
            }
          } else {
            result
          }
        },
      ),
    )

    // 3. Aggregate unique destination stake-cred hashes from outputs carrying
    //    the security token.
    let outputs_user_credentials = list.reverse(
      list.foldl(
        self.outputs,
        [],
        fn(output, result) {
          if quantity_of(output.value, issuance_policy_id, security_asset_name) > 0 {
            // Destinations must sit INSIDE the programmable-logic base.
            // Guaranteed by the base layer: `issuance_mint`'s `no_escape`
            // bars this policy from any non-PLB output on a mint, and
            // transfer conservation (`tokens.contains(PLB outputs, PLB
            // inputs)` per policy) forbids it on a transfer too — verified
            // 2026-08-19 against the deployed base layer.
            expect Some(Inline(stake_cred)) = output.address.stake_credential
            if list.has(result, stake_cred) {
              result
            } else {
              [stake_cred, ..result]
            }
          } else {
            result
          }
        },
      ),
    )

    // 4. Per-sender and per-destination: denylist absence, plus KYC when the
    //    corresponding flag is set. Swiss CO Art. 973e / eWpG §14 / ERC-3643
    //    all require the RECIPIENT to be KYC'd at transfer time (a named
    //    creditor / registered holder), which is why both sides are vetted.
    let all_senders_ok = compliance.verify_parties(
      inputs_user_credentials,
      redeemer.actions_for_each_input,
      fn(action) { action.source_proof },
      fn(action) { action.source_denylist_covering_ref_input_index },
      gs_datum.requires_sender_kyc,
      gs_datum,
      issuance_policy_id,
      denylist_script_hash,
      self,
    )

    let all_destinations_ok = compliance.verify_parties(
      outputs_user_credentials,
      redeemer.destination_actions,
      fn(action) { action.destination_proof },
      fn(action) { action.destination_denylist_covering_ref_input_index },
      gs_datum.requires_receiver_kyc,
      gs_datum,
      issuance_policy_id,
      denylist_script_hash,
      self,
    )

    and {
      //General transfers of this token must NOT be paused
      gs_datum.transfers_paused == False,
      gs_datum.deactivated == False,
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

// The denylist SPEND validator's hash — distinct from the denylist
// POLICY id (mint and spend are separate validators). Node fixtures live here.
const t_denylist_script_hash: ByteArray =
  #"d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0"

const t_plb_hash: ByteArray =
  #"05050505050505050505050505050505050505050505050505050505"

const t_sender_stake: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"

const t_dest_stake: ByteArray =
  #"0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"

// ── Genuine KYC-attestation fixtures ──────────────────────────────────────────
// Produced by `scripts/kyc-test-vectors.mjs` (fixed seed, reproducible; same
// key pair as `lib/kyc/verify.ak`'s `test_issuer_vkey`). Used by the
// end-to-end positive controls below, which require an ACTUAL Ed25519
// signature — a proof that always fails (`dummy_proof`) cannot exercise the
// accept path.

// Public half of the fixed-seed issuer key. Add this to a TEL to make the two
// vectors below verify.
const t_kyc_issuer_vkey: ByteArray =
  #"03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8"

// t_transfer_tx's own validity_range upper bound is PositiveInfinity, which
// verify_attestation_proof always rejects (Finite required); the positive
// controls below use `t_transfer_tx_with_tel` instead, which sets a Finite
// upper bound of t_kyc_tx_upper — strictly below the 100_000_000 ms
// valid_until_ms baked into the payloads below.
const t_kyc_tx_upper: Int = 50_000_000

// Genuine attestation for t_sender_stake as a VerificationKey credential
// (matches how `t_token_utxo` constructs the stake credential), tier User,
// valid_until_ms = 100_000_000 (encoded at payload bytes 29-36), for
// t_issuance_policy on network 1.
const t_sender_kyc_payload: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a010000000005f5e100eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0100"

const t_sender_kyc_signature: ByteArray =
  #"476dfda4292d4be32e012d3afb29fe863082af61d84a9fa9951bb6a835557acc3ba6db9685d828f10371bea53658911c3516a20907662e37c8ddc61cb2fb8a0d"

// Same, for t_dest_stake.
const t_dest_kyc_payload: ByteArray =
  #"0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b010000000005f5e100eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0100"

const t_dest_kyc_signature: ByteArray =
  #"cd6a9d7957c6c9ddd3c10e99fea92d55e2ba7a391037783b19c19045c627532827cf6b7b9e668039a5d60231cc23d077ab37d58d3297299a67d8c6a0ef9b4409"

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
    minting_script_credential_hash: #"",
    upgrades_locked: False,
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
        payment_credential: Script(t_denylist_script_hash),
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
    t_issuance_policy,
    t_denylist_script_hash,
    redeemer,
    Script(t_transfer_hash),
    tx,
  )
}

fn t_redeemer() -> TransferLogicScriptWithdrawRedeemer {
  TransferLogicScriptWithdrawRedeemer {
    global_state_location: GlobalStateReferenced {
      global_state_ref_input_index: 1,
    },
    actions_for_each_input: [t_source_action()],
    destination_actions: [t_dest_action()],
  }
}

// ── KYC positive-control fixtures ─────────────────────────────────────────────
// Siblings of the fixtures above, extended with a Trusted Entity List — needed
// to exercise a genuine `Attestation` proof end to end. The originals
// (`t_gs_datum`, `t_gs_ref_input`, `t_transfer_tx`, `t_redeemer`) are left
// completely untouched, so every existing test keeps its original behaviour.

/// A Trusted Entity List containing exactly one issuer vkey.
fn t_tel_with(vkey: ByteArray) -> Pairs<ByteArray, Data> {
  [Pair(vkey, builtin.constr_data(0, []))]
}

/// Sibling of `t_gs_datum` that also carries a TEL.
fn t_gs_datum_with_tel(
  req_sender: Bool,
  req_receiver: Bool,
  trusted_keys: Pairs<ByteArray, Data>,
) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    deactivated: False,
    mintable_amount: 1_000_000,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: t_denylist_policy,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: trusted_keys,
    member_root_hash: #"",
    requires_sender_kyc: req_sender,
    requires_receiver_kyc: req_receiver,
    network_id: 1,
    minting_script_credential_hash: #"",
    upgrades_locked: False,
  }
}

/// Sibling of `t_gs_ref_input` carrying the TEL-aware datum above.
fn t_gs_ref_input_with_tel(
  req_sender: Bool,
  req_receiver: Bool,
  trusted_keys: Pairs<ByteArray, Data>,
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
        t_gs_datum_with_tel(req_sender, req_receiver, trusted_keys),
      ),
      reference_script: None,
    },
  }
}

/// A KYC proof carrying a genuine Ed25519 attestation, signed by the fixed-seed
/// issuer key whose public half is `t_kyc_issuer_vkey`.
fn t_genuine_proof(payload: ByteArray, signature: ByteArray) -> KycProof {
  Attestation {
    kyc_proof: AttestationProof {
      payload,
      signature,
      issuer_vkey: t_kyc_issuer_vkey,
    },
  }
}

fn t_source_action_with_proof(proof: KycProof) -> TransferLogicScriptAction {
  TransferLogicScriptAction {
    source_proof: proof,
    source_denylist_covering_ref_input_index: 2,
  }
}

fn t_dest_action_with_proof(
  proof: KycProof,
) -> TransferLogicScriptDestinationAction {
  TransferLogicScriptDestinationAction {
    destination_proof: proof,
    destination_denylist_covering_ref_input_index: 2,
  }
}

/// Sibling of `t_transfer_tx` that (a) accepts a TEL for the GlobalState
/// reference input, so a genuine attestation can find its issuer, and (b)
/// gives the transaction a FINITE validity upper bound (`t_kyc_tx_upper`) —
/// `t_transfer_tx`'s own upper bound is PositiveInfinity, which
/// `verify_attestation_proof` always rejects (it requires a Finite bound
/// no later than the attestation's `valid_until_ms`).
fn t_transfer_tx_with_tel(
  req_sender: Bool,
  req_receiver: Bool,
  trusted_keys: Pairs<ByteArray, Data>,
) -> Transaction {
  Transaction {
    inputs: [t_sender_input(t_sender_stake, 1_000)],
    reference_inputs: [
      t_registry_ref_input(),
      t_gs_ref_input_with_tel(req_sender, req_receiver, trusted_keys),
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
        bound_type: Finite(t_kyc_tx_upper),
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

fn t_redeemer_with(
  source_action: TransferLogicScriptAction,
  dest_action: TransferLogicScriptDestinationAction,
) -> TransferLogicScriptWithdrawRedeemer {
  TransferLogicScriptWithdrawRedeemer {
    global_state_location: GlobalStateReferenced {
      global_state_ref_input_index: 1,
    },
    actions_for_each_input: [source_action],
    destination_actions: [dest_action],
  }
}

test transfer_succeeds_when_clean() {
  // Not paused, not deactivated, no KYC required, sender & receiver absent from
  // the (empty) denylist.
  run_transfer(t_redeemer(), t_transfer_tx(False, False, False, False))
}

// This validator no longer reads a CIP-113 registry node at all — the policy
// it polices is pinned at compile time. Every fixture above still carries
// `t_registry_ref_input()` at reference index 0 (unused, kept to minimise
// their diff); this one omits it entirely to prove the removal is real.
// GlobalState moves to index 0 and the denylist root to index 1.
test transfer_succeeds_without_any_registry_reference_input() {
  let tx = Transaction {
    ..t_transfer_tx(False, False, False, False),
    reference_inputs: [
      t_gs_ref_input(False, False, False, False),
      t_denylist_root_ref_input(),
    ],
  }
  run_transfer(
    TransferLogicScriptWithdrawRedeemer {
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 0,
      },
      actions_for_each_input: [
        TransferLogicScriptAction {
          source_proof: dummy_proof(),
          source_denylist_covering_ref_input_index: 1,
        },
      ],
      destination_actions: [
        TransferLogicScriptDestinationAction {
          destination_proof: dummy_proof(),
          destination_denylist_covering_ref_input_index: 1,
        },
      ],
    },
    tx,
  )
}

// ── GlobalState may be spent instead of referenced ──────────────────────────
//
// `global_state_location` widened this validator to accept a SPENT GlobalState,
// so the spent branch is exercised here rather than left as an unverified
// branch of shared, security-relevant code. Nothing in the platform builds this
// combination today — a plain transfer references GlobalState — but the point of
// the widening is that a transfer chained with a mint, a burn or an admin action
// stays buildable, and those all SPEND it.
//
// GlobalState is absent from `reference_inputs` here, exactly as it would be in
// such a transaction, which shifts the denylist root from index 2 to 1.

fn t_spent_gs_tx() -> Transaction {
  Transaction {
    ..t_transfer_tx(False, False, False, False),
    inputs: [
      t_sender_input(t_sender_stake, 1_000),
      t_gs_ref_input(False, False, False, False),
    ],
    reference_inputs: [t_registry_ref_input(), t_denylist_root_ref_input()],
  }
}

fn t_spent_gs_redeemer(
  location: GlobalStateLocation,
) -> TransferLogicScriptWithdrawRedeemer {
  TransferLogicScriptWithdrawRedeemer {
    global_state_location: location,
    actions_for_each_input: [
      TransferLogicScriptAction {
        source_proof: dummy_proof(),
        source_denylist_covering_ref_input_index: 1,
      },
    ],
    destination_actions: [
      TransferLogicScriptDestinationAction {
        destination_proof: dummy_proof(),
        destination_denylist_covering_ref_input_index: 1,
      },
    ],
  }
}

test transfer_succeeds_when_global_state_is_spent() {
  run_transfer(
    t_spent_gs_redeemer(GlobalStateSpent { global_state_input_index: 1 }),
    t_spent_gs_tx(),
  )
}

test transfer_rejected_when_location_names_the_wrong_list() fail {
  // What gives the test above its meaning: same transaction, same index, read
  // from the reference list instead. Reference input 1 is the denylist root and
  // carries no GlobalState NFT, so authentication traps — the constructor really
  // does select which list is read.
  run_transfer(
    t_spent_gs_redeemer(
      GlobalStateReferenced { global_state_ref_input_index: 1 },
    ),
    t_spent_gs_tx(),
  )
}

test transfer_rejected_when_spent_index_is_not_global_state() fail {
  // Input 0 is the sender's token UTxO. `GlobalStateSpent` may be pointed
  // anywhere; the NFT is still what decides whether the datum is believed.
  run_transfer(
    t_spent_gs_redeemer(GlobalStateSpent { global_state_input_index: 0 }),
    t_spent_gs_tx(),
  )
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

// ── KYC positive controls (end-to-end) ────────────────────────────────────────
// Every KYC-related test above proves a rejection. None of them proves the
// sender/receiver KYC gate can ever be satisfied by a real proof — a
// `verify_kyc_proof` that always returns False would pass every test above
// too. These run the FULL validator with a genuine Ed25519 attestation.

test transfer_succeeds_when_sender_kyc_required_and_proof_is_genuine() {
  let trusted_keys = t_tel_with(t_kyc_issuer_vkey)
  let source_action = t_source_action_with_proof(
    t_genuine_proof(t_sender_kyc_payload, t_sender_kyc_signature),
  )
  run_transfer(
    t_redeemer_with(source_action, t_dest_action()),
    t_transfer_tx_with_tel(True, False, trusted_keys),
  )
}

/// The receiver-side twin: `requires_receiver_kyc = True`, a genuine
/// attestation for `t_dest_stake`, sender KYC not required.
test transfer_succeeds_when_receiver_kyc_required_and_proof_is_genuine() {
  let trusted_keys = t_tel_with(t_kyc_issuer_vkey)
  let dest_action = t_dest_action_with_proof(
    t_genuine_proof(t_dest_kyc_payload, t_dest_kyc_signature),
  )
  run_transfer(
    t_redeemer_with(t_source_action(), dest_action),
    t_transfer_tx_with_tel(False, True, trusted_keys),
  )
}

/// Positive-control pairing: the EXACT same genuine proof as
/// `transfer_succeeds_when_sender_kyc_required_and_proof_is_genuine`, but the
/// GlobalState's TEL does not contain the issuer vkey. Pins that acceptance
/// above depends on TEL membership, not merely on the signature being
/// well-formed.
test transfer_rejected_when_genuine_proof_but_issuer_not_in_tel() {
  let source_action = t_source_action_with_proof(
    t_genuine_proof(t_sender_kyc_payload, t_sender_kyc_signature),
  )
  !run_transfer(
    t_redeemer_with(source_action, t_dest_action()),
    t_transfer_tx_with_tel(True, False, []),
  )
}

// ============================================================================
// Membership KYC end-to-end
// ============================================================================
// Every KYC test above exercises the `Attestation` proof variant. These drive
// the OTHER variant — `Membership`, checked against an on-chain Merkle
// Patricia Forestry root — through the real withdraw handler, using a root
// built with the vendored MPF library itself (never hand-pasted), the same way
// `lib/kyc/verify.ak`'s `membership_succeeds_with_a_genuine_single_leaf_root`
// does.

/// Sibling of `t_gs_datum` that carries a membership root instead of a TEL.
fn t_gs_datum_with_member_root(
  req_sender: Bool,
  req_receiver: Bool,
  member_root_hash: ByteArray,
) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    deactivated: False,
    mintable_amount: 1_000_000,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: t_denylist_policy,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash,
    requires_sender_kyc: req_sender,
    requires_receiver_kyc: req_receiver,
    network_id: 1,
    minting_script_credential_hash: #"",
    upgrades_locked: False,
  }
}

/// Sibling of `t_gs_ref_input` carrying the member-root-aware datum above.
fn t_gs_ref_input_with_member_root(
  req_sender: Bool,
  req_receiver: Bool,
  member_root_hash: ByteArray,
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
        t_gs_datum_with_member_root(req_sender, req_receiver, member_root_hash),
      ),
      reference_script: None,
    },
  }
}

/// Sibling of `t_transfer_tx_with_tel`: same Finite validity upper bound (a
/// membership proof also needs one — `verify_membership_proof` requires the
/// tx's validity upper bound to be Finite and <= the proof's `valid_until_ms`)
/// but GlobalState carries a membership root instead of a TEL.
fn t_transfer_tx_with_member_root(
  req_sender: Bool,
  req_receiver: Bool,
  member_root_hash: ByteArray,
) -> Transaction {
  Transaction {
    inputs: [t_sender_input(t_sender_stake, 1_000)],
    reference_inputs: [
      t_registry_ref_input(),
      t_gs_ref_input_with_member_root(
        req_sender,
        req_receiver,
        member_root_hash,
      ),
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
        bound_type: Finite(t_kyc_tx_upper),
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

/// POSIX millisecond TTL used by the membership fixtures below — comfortably
/// beyond `t_kyc_tx_upper`, exactly like the attestation fixtures' TTL.
const t_membership_valid_until_ms: Int = 100_000_000

/// A genuine single-leaf MPF root committing to `credential`'s membership,
/// built the same way `lib/kyc/verify.ak`'s positive-control tests do:
/// `mpf.empty |> mpf.insert(membership_leaf_key(cred), membership_leaf_value(...), [])
/// |> mpf.root`. An empty proof list is correct for a one-leaf trie.
fn t_membership_root_for(
  credential: Credential,
  valid_until_ms: Int,
) -> ByteArray {
  mpf.empty
    |> mpf.insert(
        membership_leaf_key(credential),
        membership_leaf_value(valid_until_ms, t_issuance_policy, 1),
        [],
      )
    |> mpf.root()
}

fn t_membership_proof(pkh: ByteArray, valid_until_ms: Int) -> KycProof {
  Membership {
    membership_proof: MembershipProof { pkh, valid_until_ms, mpf_proof: [] },
  }
}

/// POSITIVE. A genuine single-leaf root for `t_sender_stake` as a
/// VerificationKey credential (matches how `t_sender_input` constructs the
/// stake credential), set as GlobalState's `member_root_hash` with
/// `requires_sender_kyc = True`, driven through a `Membership` proof with an
/// empty inclusion proof. Must succeed.
test transfer_succeeds_when_sender_membership_proof_is_genuine() {
  let root = t_membership_root_for(
    VerificationKey(t_sender_stake),
    t_membership_valid_until_ms,
  )
  let source_action = t_source_action_with_proof(
    t_membership_proof(t_sender_stake, t_membership_valid_until_ms),
  )
  run_transfer(
    t_redeemer_with(source_action, t_dest_action()),
    t_transfer_tx_with_member_root(True, False, root),
  )
}

/// NEGATIVE TWIN. Identical transaction and proof, but the on-chain root
/// commits to a DIFFERENT credential (`t_dest_stake`, not the sender's
/// `t_sender_stake`) — the same leaf-mismatch shape
/// `membership_genuine_root_rejects_other_credential` pins in
/// `lib/kyc/verify.ak`. The sender's leaf is not in this tree, so `mpf.has`
/// returns False and the transfer is rejected. Rejection is a clean `False`,
/// not a trap, hence `!` rather than `fail`.
test transfer_rejected_when_sender_membership_root_is_for_another_credential() {
  let root = t_membership_root_for(
    VerificationKey(t_dest_stake),
    t_membership_valid_until_ms,
  )
  let source_action = t_source_action_with_proof(
    t_membership_proof(t_sender_stake, t_membership_valid_until_ms),
  )
  !run_transfer(
    t_redeemer_with(source_action, t_dest_action()),
    t_transfer_tx_with_member_root(True, False, root),
  )
}

// ============================================================================
// Benchmarks — cost scaling vs. party count
// ============================================================================
// `aiken bench -m "transfer_logic_script"` runs this. It builds a transfer
// with `n` distinct senders and `n` distinct destinations (unique
// VerificationKey stake credentials on both sides), denylist-only
// (`requires_sender_kyc = requires_receiver_kyc = False` — the additive cost
// of KYC is read off the existing `transfer_succeeds_when_clean` vs.
// `..._kyc_required_and_proof_is_genuine` tests' ex-units instead, since a
// bench can't easily vary per-party proof bytes and Ed25519-verify cost
// independently of party count), every action citing reference input 2 —
// the same root-only denylist covering node the fixtures above already use,
// which covers every key.
//
// The sampler is `fuzz.constant(size)`: `n` is exactly the current growth
// step of `--max-size`, with NO randomness. Cost must be a pure function of
// `n` for the linear fit in the bench report to mean anything — a randomised
// size-to-n mapping would reintroduce noise the report would then have to
// explain away.
//
// `n = 1` reproduces `transfer_succeeds_when_clean`'s SHAPE (one sender, one
// PLB-address VerificationKey stake credential, one matching destination, GS
// referenced, no KYC) as a sanity anchor between the two suites — not its
// exact bytes, since the party hashes below are derived rather than the
// fixed `t_sender_stake` / `t_dest_stake` constants.

/// Deterministic i-th 28-byte stake-credential hash: a 4-byte big-endian
/// index followed by a fixed 24-byte tail. Distinct tails for senders vs.
/// destinations so index `i` never collides across the two roles — not
/// required for correctness (the two credential lists are aggregated and
/// checked independently) but keeps "n distinct parties per side" honest.
fn t_bench_hash(i: Int, tail: ByteArray) -> ByteArray {
  bytearray.concat(bytearray.from_int_big_endian(i, 4), tail)
}

const t_bench_sender_tail: ByteArray =
  #"1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a"

const t_bench_dest_tail: ByteArray =
  #"2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b"

fn t_bench_sender_input(i: Int) -> Input {
  Input {
    output_reference: t_out_ref(100 + i),
    output: t_token_utxo(t_bench_hash(i, t_bench_sender_tail), 1_000),
  }
}

fn t_bench_dest_output(i: Int) -> Output {
  t_token_utxo(t_bench_hash(i, t_bench_dest_tail), 1_000)
}

/// Sampler: the bench size IS the party count `n`, via `fuzz.constant` — see
/// the section note above for why this must not be randomised.
fn n_parties(size: Int) -> Fuzzer<Int> {
  fuzz.constant(size)
}

bench transfer_cost_by_party_count(n via n_parties) {
  let redeemer = TransferLogicScriptWithdrawRedeemer {
    global_state_location: GlobalStateReferenced {
      global_state_ref_input_index: 1,
    },
    actions_for_each_input: list.repeat(t_source_action(), n),
    destination_actions: list.repeat(t_dest_action(), n),
  }
  let tx = Transaction {
    ..t_transfer_tx(False, False, False, False),
    inputs: list.map(list.range(0, n - 1), t_bench_sender_input),
    outputs: list.map(list.range(0, n - 1), t_bench_dest_output),
  }
  // Assert rather than `fail`-annotate: a bench body that silently accepted
  // a False here would keep reporting plausible-looking mem/cpu numbers for
  // a validator run that actually rejected the transaction, which would make
  // every downstream cost-scaling conclusion meaningless.
  expect run_transfer(redeemer, tx)
}

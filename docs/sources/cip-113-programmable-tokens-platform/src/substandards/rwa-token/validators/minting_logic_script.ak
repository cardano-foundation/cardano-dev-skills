use aiken/builtin
use aiken/collection/dict
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use cardano/address.{Address, Credential, Script}
use cardano/assets.{from_asset, from_lovelace, merge, zero}
use cardano/certificate.{Certificate, RegisterCredential, UnregisterCredential}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use constants
use types/global_state.{
  GlobalStateDatum, GlobalStateLocation, GlobalStateReferenced, GlobalStateSpent,
  gs_datum_from_output,
}
use utils.{must_run_script_withdrawal}

/// The permanent, CIP-113-registered PROXY for this token's minting path.
///
/// Every registry node's `minting_logic_script` field is frozen to this
/// script's hash forever, and the token's own issuance policy id is derived
/// from that hash — so nothing in this file can ever change after deployment
/// without minting a different token. It therefore contains as close to
/// nothing as is possible: it resolves GlobalState, reads which script is
/// currently the minting authority, and requires that script to be running
/// in this transaction. That is the whole validator.
///
/// EVERY substantive rule — the supply cap, power-user roles, KYC, denylist,
/// mint destinations, the CIP-113 registration's structural invariants, the
/// admin gate, and the guard against riding along on a registry-node update
/// — lives in validators/minting_authority.ak, which the admin can replace
/// at any time via `RotateMintingScript`. Maximum upgradability, by
/// construction: the only thing that can never be fixed is this file, so
/// this file decides as little as possible.
///
/// The corollary, stated plainly because it is the price of that design: a
/// replacement authority inherits the FULL burden of correctness. Nothing
/// here will catch its mistakes. See the "INVARIANTS ANY REPLACEMENT
/// AUTHORITY MUST PRESERVE" note in validators/minting_authority.ak.
validator minting_logic_validator(global_state_policy_id: ByteArray) {
  /// The redeemer is exactly `GlobalStateLocation` — the proxy needs one thing
  /// from the caller, where to find GlobalState, and every other decision
  /// belongs to the authority (see types/minting_authority.ak). It had a
  /// private two-constructor type of its own until that type and
  /// `GlobalStateLocation` became byte-for-byte the same declaration; the
  /// shared one is now the single encoding of "which list is GlobalState in"
  /// for every validator where the choice is free.
  withdraw(
    redeemer: GlobalStateLocation,
    credential: Credential,
    self: Transaction,
  ) {
    expect Script(own_hash) = credential

    // Resolved INLINE rather than through `gs_datum_from_location`, which is
    // the same logic and is what every other validator here calls.
    //
    // This one file may not change its compiled bytes. Its hash is frozen into
    // every registry node this deployment has ever inserted, and the token's
    // issuance policy id is derived from it — so a different hash is a
    // different token, and every already-issued one becomes unreachable. Going
    // through the shared helper was measured to move the hash
    // (6defc595… -> b6e4e07a…): same behaviour, different UPLC. The redeemer
    // TYPE is shared, because a type name is not compiled; the resolution is
    // not. Do not "tidy" this into the helper without re-checking the hash.
    let gs_output: Output = when redeemer is {
      GlobalStateSpent { global_state_input_index } ->
        utils.safe_list_at(self.inputs, global_state_input_index).output
      GlobalStateReferenced { global_state_ref_input_index } ->
        utils.safe_list_at(self.reference_inputs, global_state_ref_input_index).output
    }
    // NFT presence is what makes this the real GlobalState rather than a
    // datum an attacker fabricated to name an authority they control.
    let gs_datum: GlobalStateDatum = gs_datum_from_output(
      gs_output,
      global_state_policy_id,
    )

    and {
      // Decline if the protocol is deactivated
      (gs_datum.deactivated == False)?,
      // Self-authorisation footgun: this withdraw-0 is, by construction,
      // always present while this code is running, so an authority hash
      // equal to `own_hash` would be trivially self-satisfying. No
      // circularity concern — `own_hash` is a runtime value from
      // `credential`, not a compile-time parameter.
      (gs_datum.minting_script_credential_hash != own_hash)?,
      // Deliberately `must_run_script_withdrawal`, NOT
      // `must_be_signed_by_credential`: the latter also accepts a bare key
      // signature, which would satisfy this gate without the authority
      // script ever executing — and since this proxy checks nothing else at
      // all, that would be a total bypass of every rule the token has. Only
      // a genuine withdraw-0 proves the authority's own logic ran and
      // approved this specific transaction.
      must_run_script_withdrawal(self, gs_datum.minting_script_credential_hash)?,
    }
  }

  // Whitelist RegisterCredential only. Rejecting UnregisterCredential prevents
  // a ~2 ADA griefing DoS: a rubber-stamp publish would allow anyone to
  // de-register this script's stake credential, which would brick every
  // withdraw-zero mint/burn until re-registered. Also rejects delegation and
  // DRep/committee cert types — this credential exists solely for withdraw-0.
  // Tradeoff: the stake credential becomes permanent (2 ADA locked forever).
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
// Tests — the whole validator is one delegation decision, so these cover
// exactly that: can the gate be satisfied by anything other than the
// currently-named authority genuinely running?
// ============================================================================

const test_gs_policy_id: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

// This proxy's own credential, as the ledger passes it to `withdraw`.
const test_minting_logic_hash: ByteArray =
  #"f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1"

// The currently-active minting authority (validators/minting_authority.ak),
// as named by GlobalState.minting_script_credential_hash.
const test_minting_authority_hash: ByteArray =
  #"06060606060606060606060606060606060606060606060606060606"

// A second, distinct authority — what `RotateMintingScript` points
// GlobalState at. Used to prove rotation actually re-points the delegation.
const test_new_minting_authority_hash: ByteArray =
  #"07070707070707070707070707070707070707070707070707070707"

fn test_out_ref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

fn make_gs_output(authority: ByteArray, deactivated: Bool) -> Output {
  let gs_datum = GlobalStateDatum {
    transfers_paused: False,
    deactivated,
    mintable_amount: 1_000_000,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: False,
    requires_receiver_kyc: False,
    network_id: 1,
    minting_script_credential_hash: authority,
    upgrades_locked: False,
  }
  Output {
    address: Address {
      payment_credential: Script(test_gs_policy_id),
      stake_credential: None,
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(test_gs_policy_id, constants.global_state_asset_name, 1),
    ),
    datum: InlineDatum(gs_datum),
    reference_script: None,
  }
}

fn make_gs_input(authority: ByteArray, deactivated: Bool) -> Input {
  Input {
    output_reference: test_out_ref(0),
    output: make_gs_output(authority, deactivated),
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

// GS spent (the mint/burn shape), with the named authority's withdraw-0
// present or absent.
fn spent_tx(authority: ByteArray, withdrawal: Option<ByteArray>) -> Transaction {
  Transaction {
    ..base_tx(),
    inputs: [make_gs_input(authority, False)],
    withdrawals: when withdrawal is {
      Some(h) -> [Pair(Script(h), 0)]
      None -> []
    },
  }
}

fn run_withdraw(redeemer: GlobalStateLocation, tx: Transaction) {
  minting_logic_validator.withdraw(
    test_gs_policy_id,
    redeemer,
    Script(test_minting_logic_hash),
    tx,
  )
}

fn spent_redeemer() -> GlobalStateLocation {
  GlobalStateSpent { global_state_input_index: 0 }
}

// ── the delegation gate ──────────────────────────────────────────────────────

test succeeds_when_the_named_authority_runs() {
  run_withdraw(
    spent_redeemer(),
    spent_tx(test_minting_authority_hash, Some(test_minting_authority_hash)),
  )
}

test succeeds_when_global_state_is_only_referenced() {
  // A structural registration references GS rather than spending it. The
  // proxy accepts either — deciding which is appropriate for the operation
  // at hand is the authority's job, not this validator's.
  run_withdraw(
    GlobalStateReferenced { global_state_ref_input_index: 0 },
    Transaction {
      ..base_tx(),
      reference_inputs: [make_gs_input(test_minting_authority_hash, False)],
      withdrawals: [Pair(Script(test_minting_authority_hash), 0)],
    },
  )
}

test fails_without_the_authority_withdrawal() {
  // This is the entire validator: with no authority running, nothing else
  // here could possibly authorise anything.
  !run_withdraw(spent_redeemer(), spent_tx(test_minting_authority_hash, None))
}

test fails_when_the_authority_is_merely_signed_for() {
  // The gate must accept ONLY a real withdraw-0 of the named script, never a
  // bare signature — `must_be_signed_by_credential` treats the two as
  // interchangeable, which here would let the authority be skipped entirely
  // and, since this proxy checks nothing else, bypass every rule the token
  // has.
  !run_withdraw(
    spent_redeemer(),
    Transaction {
      ..spent_tx(test_minting_authority_hash, None),
      extra_signatories: [test_minting_authority_hash],
    },
  )
}

test fails_when_a_different_script_runs() {
  // An unrelated script's withdraw-0 is not the named authority's.
  !run_withdraw(
    spent_redeemer(),
    spent_tx(test_minting_authority_hash, Some(test_new_minting_authority_hash)),
  )
}

test fails_when_the_authority_is_this_proxy_itself() {
  // Self-authorisation footgun: this withdraw-0 is always present while this
  // code runs, so `own_hash` as the authority would be free.
  !run_withdraw(
    spent_redeemer(),
    spent_tx(test_minting_logic_hash, Some(test_minting_logic_hash)),
  )
}

// ── the upgrade property ─────────────────────────────────────────────────────

test superseded_authority_stops_working_after_rotation() {
  // Which script satisfies the gate is read live from GlobalState on every
  // transaction, so rotating `minting_script_credential_hash` genuinely
  // re-points the delegation — otherwise a superseded (e.g. compromised)
  // authority would keep working forever and "rotation" would be cosmetic.
  !run_withdraw(
    spent_redeemer(),
    spent_tx(test_new_minting_authority_hash, Some(test_minting_authority_hash)),
  )
}

test rotated_authority_starts_working() {
  // Positive mirror of the test above, same GlobalState.
  run_withdraw(
    spent_redeemer(),
    spent_tx(
      test_new_minting_authority_hash,
      Some(test_new_minting_authority_hash),
    ),
  )
}

// ── GlobalState authentication ───────────────────────────────────────────────

test fails_when_global_state_is_forged() fail {
  // Without the NFT check an attacker could supply any UTxO carrying a
  // GlobalState-shaped datum that names an authority they control, and the
  // gate would happily delegate to it.
  let forged = Output {
    ..make_gs_output(test_new_minting_authority_hash, False),
    value: from_lovelace(2_000_000),
  }
  run_withdraw(
    spent_redeemer(),
    Transaction {
      ..base_tx(),
      inputs: [Input { output_reference: test_out_ref(0), output: forged }],
      withdrawals: [Pair(Script(test_new_minting_authority_hash), 0)],
    },
  )
}

test fails_when_index_points_at_a_non_global_state_utxo() fail {
  let unrelated = Output {
    address: Address {
      payment_credential: Script(test_gs_policy_id),
      stake_credential: None,
    },
    value: from_lovelace(2_000_000),
    datum: NoDatum,
    reference_script: None,
  }
  run_withdraw(
    spent_redeemer(),
    Transaction {
      ..spent_tx(test_minting_authority_hash, Some(test_minting_authority_hash)),
      inputs: [Input { output_reference: test_out_ref(1), output: unrelated }],
    },
  )
}

// ── publish handler ──────────────────────────────────────────────────────────

test publish_accepts_credential_registration() {
  minting_logic_validator.publish(
    test_gs_policy_id,
    builtin.constr_data(0, []),
    RegisterCredential {
      credential: Script(test_minting_logic_hash),
      deposit: Never,
    },
    base_tx(),
  )
}

test publish_rejects_credential_deregistration() {
  // Pins the anti-griefing rule the handler documents: a rubber-stamp publish
  // would let anyone de-register this script's stake credential for ~2 ADA,
  // bricking every withdraw-0 mint and burn until it was re-registered.
  !minting_logic_validator.publish(
    test_gs_policy_id,
    builtin.constr_data(0, []),
    UnregisterCredential {
      credential: Script(test_minting_logic_hash),
      refund: Never,
    },
    base_tx(),
  )
}

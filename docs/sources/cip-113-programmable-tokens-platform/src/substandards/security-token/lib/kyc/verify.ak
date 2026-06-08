use aiken/builtin
use aiken/collection/dict
use aiken/collection/pairs
use aiken/crypto.{verify_ed25519_signature}
use aiken/interval.{
  Finite, Interval, IntervalBound, NegativeInfinity, PositiveInfinity,
}
use aiken/merkle_patricia_forestry as mpf
use aiken/primitive/bytearray
use cardano/assets
use cardano/transaction.{Transaction}
use types/global_state.{GlobalStateDatum}
use types/kyc_proof.{
  Attestation, AttestationProof, KycProof, Membership, MembershipProof,
  issuer_vkey_length, offset_network_id, offset_security_policy_id,
  offset_user_kyc_tier, offset_user_pkh, offset_valid_until_ms, payload_length,
  signature_length, tier_invalid, width_security_policy_id, width_user_pkh,
  width_valid_until_ms,
}

/// Verify a KYC proof for a specific expected PKH + security token + network.
///
/// Returns True iff:
///   1. Payload / signature / vkey all have the expected byte lengths.
///   2. Payload's embedded user_pkh matches `expected_user_pkh`.
///   3. Payload's embedded user_kyc_tier is not the invalid sentinel (0x00).
///   4. Payload's embedded valid_until_ms >= tx validity-range upper bound.
///   5. Payload's embedded security_policy_id matches `security_policy_id`.
///   6. Payload's embedded network_id matches `network_id`.
///   7. Proof's issuer_vkey is present in `gs_datum.trusted_entity_vkeys`.
///   8. The Ed25519 signature verifies under `proof.issuer_vkey` over `payload`.
///
/// Any failure returns False. Pure function — all state flows through
/// arguments. Callers typically compose many verify_kyc_proof results with
/// `and` in a fold over inputs.
pub fn verify_attestation_proof(
  proof: AttestationProof,
  expected_user_pkh: ByteArray,
  gs_datum: GlobalStateDatum,
  security_policy_id: ByteArray,
  network_id: Int,
  tx: Transaction,
) -> Bool {
  let payload = proof.payload
  let signature = proof.signature
  let issuer_vkey = proof.issuer_vkey

  // 1. Structural lengths. Short-circuit if malformed — subsequent slices
  // would otherwise risk out-of-bounds panics.
  let lengths_ok = and {
    bytearray.length(payload) == payload_length,
    bytearray.length(signature) == signature_length,
    bytearray.length(issuer_vkey) == issuer_vkey_length,
  }

  // 2–6. Payload field checks (guarded).
  let fields_ok = if lengths_ok {
    // bytearray.slice takes (start, end_inclusive), so end = start+width-1.
    let payload_user_pkh = bytearray.slice(
      payload,
      offset_user_pkh,
      offset_user_pkh + width_user_pkh - 1,
    )
    let payload_tier = builtin.index_bytearray(payload, offset_user_kyc_tier)
    let payload_ttl = bytearray.to_int_big_endian(
      bytearray.slice(
        payload,
        offset_valid_until_ms,
        offset_valid_until_ms + width_valid_until_ms - 1,
      ),
    )
    let payload_policy = bytearray.slice(
      payload,
      offset_security_policy_id,
      offset_security_policy_id + width_security_policy_id - 1,
    )
    let payload_network = builtin.index_bytearray(payload, offset_network_id)

    let ttl_ok = when tx.validity_range.upper_bound.bound_type is {
      Finite(tx_upper) -> tx_upper <= payload_ttl
      _ -> False
    }

    and {
      payload_user_pkh == expected_user_pkh,
      payload_tier != tier_invalid,
      ttl_ok,
      payload_policy == security_policy_id,
      payload_network == network_id,
    }
  } else {
    False
  }

  // 7. Issuer membership in TEL.
  let issuer_ok = pairs.has_key(gs_datum.trusted_entity_vkeys, issuer_vkey)

  // 8. Ed25519 signature (only invoked when prior gates pass — saves gas on
  // the sad path where lengths/membership already failed).
  let sig_ok = if lengths_ok && issuer_ok {
    verify_ed25519_signature(issuer_vkey, payload, signature)
  } else {
    False
  }

  and {
    lengths_ok,
    fields_ok,
    issuer_ok,
    sig_ok,
  }
}

/// Encode a millisecond timestamp as an 8-byte big-endian ByteArray.
pub fn encode_valid_until(ms: Int) -> ByteArray {
  bytearray.from_int_big_endian(ms, 8)
}

/// Verify a Merkle Patricia Forestry membership proof for a given PKH.
///
/// Returns True iff:
///   1. proof.pkh matches expected_user_pkh — binds the proof to the correct sender.
///   2. Tx validity upper bound is Finite and <= proof.valid_until_ms — the
///      membership has not expired relative to the transaction deadline.
///   3. (proof.pkh → encode_valid_until(proof.valid_until_ms)) is a valid leaf
///      in the MPF tree committed to by gs_datum.member_root_hash.
///
/// Pure function — all state flows through arguments.
pub fn verify_membership_proof(
  proof: MembershipProof,
  expected_user_pkh: ByteArray,
  gs_datum: GlobalStateDatum,
  tx: Transaction,
) -> Bool {
  and {
    // 1. Proof must reference the correct sender.
    proof.pkh == expected_user_pkh,
    // 2. Tx validity upper bound must be finite and within the membership TTL.
    when tx.validity_range.upper_bound.bound_type is {
      Finite(tx_upper) -> tx_upper <= proof.valid_until_ms
      _ -> False
    },
    // 3. (pkh → encode_valid_until(valid_until_ms)) must exist as a leaf in
    //    the on-chain MPF tree committed to by member_root_hash.
    mpf.has(
      mpf.from_root(gs_datum.member_root_hash),
      proof.pkh,
      encode_valid_until(proof.valid_until_ms),
      proof.mpf_proof,
    ),
  }
}

/// Dispatch a KYC proof to the appropriate verifier based on its variant.
///
/// - `Attestation`: delegates to `verify_attestation_proof` — the issuer signs a
///   payload that embeds the user's PKH, tier, TTL, security policy, and network.
/// - `Membership`: delegates to `verify_membership_proof` — the user PKH and
///   TTL must exist as a leaf in the on-chain MPF membership tree.
///
/// Returns True iff the selected verifier returns True.
/// Pure function — all state flows through arguments.
pub fn verify_kyc_proof(
  proof: KycProof,
  expected_user_pkh: ByteArray,
  gs_datum: GlobalStateDatum,
  security_policy_id: ByteArray,
  network_id: Int,
  tx: Transaction,
) -> Bool {
  when proof is {
    Attestation { kyc_proof } ->
      verify_attestation_proof(
        kyc_proof,
        expected_user_pkh,
        gs_datum,
        security_policy_id,
        network_id,
        tx,
      )
    Membership { membership_proof } ->
      verify_membership_proof(membership_proof, expected_user_pkh, gs_datum, tx)
  }
}

// ============================================================================
// Tests
// ============================================================================

// ── Test constants ────────────────────────────────────────────────────────────

// 28-byte payment key hash used across all proof tests.
const test_user_pkh: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

// 28-byte security token policy ID used in attestation tests.
const test_security_policy_id: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

// 32-byte Ed25519 verification key representing the trusted issuer.
const test_issuer_vkey: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

// 64 placeholder bytes — not a valid Ed25519 signature. Used in negative tests
// where correct byte length is required but sig_ok = True is not.
const test_invalid_signature: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

// POSIX millisecond TTL well beyond test_tx_upper.
const test_ttl_ms: Int = 100_000_000

// Transaction validity upper bound strictly below test_ttl_ms.
const test_tx_upper: Int = 50_000_000

// preprod network identifier.
const test_network_id: Int = 1

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Build the 66-byte attestation payload from explicit field values.
/// Layout mirrors the KycProof spec: pkh(28)|tier(1)|ttl(8)|policy(28)|net(1).
fn make_payload(
  user_pkh: ByteArray,
  tier: Int,
  ttl_ms: Int,
  security_policy_id: ByteArray,
  network_id: Int,
) -> ByteArray {
  bytearray.concat(
    bytearray.concat(
      bytearray.concat(
        bytearray.concat(user_pkh, bytearray.from_int_big_endian(tier, 1)),
        encode_valid_until(ttl_ms),
      ),
      security_policy_id,
    ),
    bytearray.from_int_big_endian(network_id, 1),
  )
}

/// Return a Trusted Entity List containing only test_issuer_vkey.
fn test_tel() -> Pairs<ByteArray, Data> {
  [Pair(test_issuer_vkey, builtin.constr_data(0, []))]
}

/// GlobalStateDatum with the given TEL and an empty membership tree.
fn test_gs_datum_with_tel(
  trusted_keys: Pairs<ByteArray, Data>,
) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    mintable_amount: 0,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: trusted_keys,
    member_root_hash: #"",
    requires_receiver_kyc: True,
  }
}

/// GlobalStateDatum with an empty TEL and the given MPF root hash.
fn test_gs_datum_with_root(root: ByteArray) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    mintable_amount: 0,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: root,
    requires_receiver_kyc: True,
  }
}

/// Transaction whose validity window closes at `upper` ms (Finite upper bound).
fn tx_with_upper_bound(upper: Int) -> Transaction {
  Transaction {
    inputs: [],
    reference_inputs: [],
    outputs: [],
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
        bound_type: Finite(upper),
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

/// Transaction with no deadline (PositiveInfinity upper bound).
fn tx_with_infinite_upper() -> Transaction {
  Transaction {
    inputs: [],
    reference_inputs: [],
    outputs: [],
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

// ── encode_valid_until ────────────────────────────────────────────────────────

test encode_valid_until_encodes_zero_as_eight_zero_bytes() {
  encode_valid_until(0) == #"0000000000000000"
}

test encode_valid_until_encodes_value_big_endian() {
  // 100_000_000 = 0x05F5E100 — verify 8-byte big-endian layout
  encode_valid_until(100_000_000) == #"0000000005f5e100"
}

// ── verify_attestation_proof — length guards (lengths_ok = False) ─────────────
// When any length is wrong the function short-circuits before touching payload
// fields, so TEL contents and TTL are irrelevant in these tests.

test attestation_fails_when_payload_too_short() {
  let proof = AttestationProof {
    payload: #"aabb",
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel([]),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_payload_too_long() {
  let valid = make_payload(
    test_user_pkh,
    1,
    test_ttl_ms,
    test_security_policy_id,
    test_network_id,
  )
  let proof = AttestationProof {
    payload: bytearray.concat(valid, #"ff"),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel([]),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_signature_wrong_length() {
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: #"aabb",
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel([]),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_vkey_wrong_length() {
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: #"cccc",
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel([]),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── verify_attestation_proof — payload field checks (fields_ok = False) ───────

test attestation_fails_when_user_pkh_mismatch() {
  let wrong_pkh = #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  let proof = AttestationProof {
    payload: make_payload(
      wrong_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_tier_is_invalid() {
  // tier = 0x00 is the tier_invalid sentinel
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      0,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_ttl_expired() {
  // payload_ttl = tx_upper - 1 → tx_upper <= payload_ttl is False
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_tx_upper - 1,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_upper_bound_is_infinite() {
  // PositiveInfinity matches the `_ -> False` branch in ttl_ok
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_infinite_upper(),
  )
}

test attestation_fails_when_security_policy_mismatch() {
  let wrong_policy = #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      wrong_policy,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_network_id_mismatch() {
  // Payload encodes mainnet (2); caller expects preprod (1)
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      2,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── verify_attestation_proof — issuer / signature gates ───────────────────────

test attestation_fails_when_issuer_not_in_tel() {
  // TEL is empty — issuer_ok = False short-circuits sig_ok computation
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel([]),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test attestation_fails_when_signature_is_invalid() {
  // lengths_ok, fields_ok, and issuer_ok all pass; only sig_ok = False
  // (test_invalid_signature is not a valid Ed25519 sig over the payload)
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── verify_membership_proof ───────────────────────────────────────────────────

test membership_fails_when_pkh_mismatch() {
  // proof.pkh != expected_user_pkh → short-circuits before TTL / MPF checks
  let different_pkh = #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  let proof = MembershipProof {
    pkh: test_user_pkh,
    valid_until_ms: test_ttl_ms,
    mpf_proof: [],
  }
  !verify_membership_proof(
    proof,
    different_pkh,
    test_gs_datum_with_root(#""),
    tx_with_upper_bound(test_tx_upper),
  )
}

test membership_fails_when_ttl_expired() {
  // valid_until_ms = tx_upper - 1 → tx_upper <= valid_until_ms is False
  let proof = MembershipProof {
    pkh: test_user_pkh,
    valid_until_ms: test_tx_upper - 1,
    mpf_proof: [],
  }
  !verify_membership_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_root(#""),
    tx_with_upper_bound(test_tx_upper),
  )
}

test membership_fails_when_upper_bound_is_infinite() {
  // PositiveInfinity hits the `_ -> False` branch
  let proof = MembershipProof {
    pkh: test_user_pkh,
    valid_until_ms: test_ttl_ms,
    mpf_proof: [],
  }
  !verify_membership_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_root(#""),
    tx_with_infinite_upper(),
  )
}

test membership_fails_when_mpf_proof_is_wrong() {
  // pkh and TTL checks pass; empty proof cannot satisfy a real 32-byte root.
  // mpf.from_root requires exactly 32 bytes (blake2b_256 digest size).
  let fake_root = #"0000000000000000000000000000000000000000000000000000000000000000"
  let proof = MembershipProof {
    pkh: test_user_pkh,
    valid_until_ms: test_ttl_ms,
    mpf_proof: [],
  }
  !verify_membership_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_root(fake_root),
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── verify_kyc_proof — dispatch ───────────────────────────────────────────────

test kyc_proof_routes_attestation_variant() {
  // Short payload → verify_attestation_proof returns False (lengths_ok = False),
  // confirming the Attestation branch is reached.
  let proof = Attestation {
    kyc_proof: AttestationProof {
      payload: #"aa",
      signature: test_invalid_signature,
      issuer_vkey: test_issuer_vkey,
    },
  }
  !verify_kyc_proof(
    proof,
    test_user_pkh,
    test_gs_datum_with_tel([]),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test kyc_proof_routes_membership_variant() {
  // PKH mismatch → verify_membership_proof returns False,
  // confirming the Membership branch is reached.
  let different_pkh = #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  let proof = Membership {
    membership_proof: MembershipProof {
      pkh: test_user_pkh,
      valid_until_ms: test_ttl_ms,
      mpf_proof: [],
    },
  }
  !verify_kyc_proof(
    proof,
    different_pkh,
    test_gs_datum_with_root(#""),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

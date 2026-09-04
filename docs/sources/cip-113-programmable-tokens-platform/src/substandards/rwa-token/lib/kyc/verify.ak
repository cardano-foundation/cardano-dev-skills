use aiken/builtin
use aiken/collection/dict
use aiken/collection/pairs
use aiken/crypto.{verify_ed25519_signature}
use aiken/interval.{
  Finite, Interval, IntervalBound, NegativeInfinity, PositiveInfinity,
}
use aiken/merkle_patricia_forestry as mpf
use aiken/primitive/bytearray
use cardano/address.{Credential, Script, VerificationKey}
use cardano/assets
use cardano/transaction.{Transaction}
use types/global_state.{GlobalStateDatum}
use types/kyc_proof.{
  Attestation, AttestationProof, KycProof, Membership, MembershipProof,
  credential_type_key, credential_type_script, issuer_vkey_length,
  offset_credential_type, offset_network_id, offset_security_policy_id,
  offset_user_kyc_tier, offset_user_pkh, offset_valid_until_ms, payload_length,
  signature_length, tier_invalid, width_security_policy_id, width_user_pkh,
  width_valid_until_ms,
}
use utils

/// Verify a KYC proof for a specific expected PKH + security token + network.
///
/// Returns True iff:
///   1. Payload / signature / vkey all have the expected byte lengths.
///   2. Payload's embedded user_pkh AND credential_type match
///      `expected_credential` — both halves of the identity, not just the hash.
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
  expected_credential: Credential,
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
    // The credential constructor the attestation was issued for.
    let payload_credential_type = builtin.index_bytearray(
      payload,
      offset_credential_type,
    )

    let ttl_ok = when tx.validity_range.upper_bound.bound_type is {
      Finite(tx_upper) -> tx_upper <= payload_ttl
      _ -> False
    }

    and {
      payload_user_pkh == utils.credential_hash(expected_credential),
      // A key credential and a script credential sharing a hash are
      // DIFFERENT holders — the base layer authorises them differently — so an
      // attestation must name which one it was issued for.
      payload_credential_type == utils.credential_type_byte(expected_credential),
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

/// Build the MPF LEAF KEY for a membership entry.
///
/// `credential_type_byte ‖ hash` (29 bytes), not the bare 28-byte hash, so
/// a key credential and a script credential sharing a hash are DIFFERENT leaves
/// and cannot inherit each other's membership.
pub fn membership_leaf_key(credential: Credential) -> ByteArray {
  bytearray.concat(
    bytearray.from_int_big_endian(utils.credential_type_byte(credential), 1),
    utils.credential_hash(credential),
  )
}

/// Build the MPF LEAF VALUE for a membership entry.
///
/// `valid_until_ms(8) ‖ security_policy_id(28) ‖ network_id(1)` — the same
/// three bindings the attestation payload carries, so the two proof types are
/// genuinely interchangeable. Previously the value was the TTL alone, which left
/// a membership root portable between deployments and across networks.
pub fn membership_leaf_value(
  valid_until_ms: Int,
  security_policy_id: ByteArray,
  network_id: Int,
) -> ByteArray {
  bytearray.concat(
    bytearray.concat(encode_valid_until(valid_until_ms), security_policy_id),
    bytearray.from_int_big_endian(network_id, 1),
  )
}

/// Verify a Merkle Patricia Forestry membership proof for a given holder.
///
/// Returns True iff:
///   1. `proof.pkh` matches the expected credential's hash — a redundant but
///      cheap sanity binding; the authoritative key is derived below.
///   2. Tx validity upper bound is Finite and <= proof.valid_until_ms — the
///      membership has not expired relative to the transaction deadline.
///   3. `membership_leaf_key(expected_credential) → membership_leaf_value(...)`
///      is a valid leaf in the MPF tree committed to by `member_root_hash`.
///
/// Pure function — all state flows through arguments.
///
/// This variant commits to exactly what the attestation payload commits to: the
/// holder's credential CONSTRUCTOR as well as its hash (leaf key), and the
/// security policy id and network id (leaf value). An earlier revision bound
/// neither policy nor network, so two deployments sharing a membership root
/// accepted each other's proofs and a proof was not pinned to a network; and it
/// keyed on a bare hash, so a script credential inherited a verification key's
/// membership. The two proof types must be interchangeable, which means they
/// must bind the same things.
///
/// BREAKING, off-chain must move in LOCKSTEP: the leaf encoding changed on both
/// halves, so every existing membership root must be rebuilt with
/// `membership_leaf_key` / `membership_leaf_value` before
/// `UpdateMemberRootHash` is called. A root built the old way will simply fail
/// every proof — it fails CLOSED, not open.
///
/// KNOWN, UNHANDLED: `ttl_ok` on both proof paths ignores the validity bound's
/// `is_inclusive` flag. At most a 1 ms edge.
pub fn verify_membership_proof(
  proof: MembershipProof,
  expected_credential: Credential,
  gs_datum: GlobalStateDatum,
  security_policy_id: ByteArray,
  network_id: Int,
  tx: Transaction,
) -> Bool {
  and {
    // 1. Proof must reference the correct sender.
    proof.pkh == utils.credential_hash(expected_credential),
    // 2. Tx validity upper bound must be finite and within the membership TTL.
    when tx.validity_range.upper_bound.bound_type is {
      Finite(tx_upper) -> tx_upper <= proof.valid_until_ms
      _ -> False
    },
    // 3. The leaf must exist in the on-chain MPF tree committed to by
    //    member_root_hash. Key and value are derived from the EXPECTED
    //    credential and this deployment's own policy/network — never from the
    //    proof — so a proof cannot select which deployment it belongs to.
    mpf.has(
      mpf.from_root(gs_datum.member_root_hash),
      membership_leaf_key(expected_credential),
      membership_leaf_value(
        proof.valid_until_ms,
        security_policy_id,
        network_id,
      ),
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
/// Both variants take the holder's full `Credential`, not a bare hash —
/// the constructor is part of the identity being attested.
///
/// Returns True iff the selected verifier returns True.
/// Pure function — all state flows through arguments.
pub fn verify_kyc_proof(
  proof: KycProof,
  expected_credential: Credential,
  gs_datum: GlobalStateDatum,
  security_policy_id: ByteArray,
  network_id: Int,
  tx: Transaction,
) -> Bool {
  when proof is {
    Attestation { kyc_proof } ->
      verify_attestation_proof(
        kyc_proof,
        expected_credential,
        gs_datum,
        security_policy_id,
        network_id,
        tx,
      )
    Membership { membership_proof } ->
      verify_membership_proof(
        membership_proof,
        expected_credential,
        gs_datum,
        security_policy_id,
        network_id,
        tx,
      )
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

// 32-byte Ed25519 verification key representing the trusted issuer. This is
// a GENUINE key, not a placeholder: it is the public half of the fixed-seed
// key pair derived by `scripts/kyc-test-vectors.mjs`, so both the negative
// tests below (which never verify a real signature against it) and the
// positive tests (which do) share one issuer identity. Re-run the script to
// reproduce this value.
const test_issuer_vkey: ByteArray =
  #"03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8"

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

// ── Genuine signature fixtures ───────────────────────────────────────────────
// Produced by `scripts/kyc-test-vectors.mjs` (fixed seed, reproducible) —
// see that script for the payload layout and how to re-derive these bytes.
// `test_issuer_vkey` above is the public half of the same key pair.

// Genuine Ed25519 signature over
// `make_payload(test_user_pkh, 1, test_ttl_ms, test_security_policy_id,
// test_network_id)` — vector (a), VerificationKey credential form.
const test_genuine_signature_key_cred: ByteArray =
  #"e21761b04b625ba34551d8fd4203d0af1087606ff16f7af2aa34164b94e31063947229dde38f53ae65f203006ebd828af8f266fb5ff761c9ce83bf640f12160e"

// Genuine Ed25519 signature over
// `make_payload_for(test_user_pkh, 1, test_ttl_ms, test_security_policy_id,
// test_network_id, credential_type_script)` — vector (b), Script credential
// form.
const test_genuine_signature_script_cred: ByteArray =
  #"e4ee6d9812a57c619895b08b5e1413c070d9e68f1ee22cdafcb364841421b2b72519d3620fb7f0ce4a868dd51b30aa723814acc01e1d4e5724ba0c353c86ec0e"

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Build the 67-byte attestation payload from explicit field values.
/// Layout mirrors the KycProof spec:
/// pkh(28)|tier(1)|ttl(8)|policy(28)|net(1)|cred_type(1).
fn make_payload(
  user_pkh: ByteArray,
  tier: Int,
  ttl_ms: Int,
  security_policy_id: ByteArray,
  network_id: Int,
) -> ByteArray {
  make_payload_for(
    user_pkh,
    tier,
    ttl_ms,
    security_policy_id,
    network_id,
    credential_type_key,
  )
}

/// Same, with the credential-type byte varied — the discriminator is what
/// stops an attestation issued for a verification key being replayed for a
/// script credential sharing its hash.
fn make_payload_for(
  user_pkh: ByteArray,
  tier: Int,
  ttl_ms: Int,
  security_policy_id: ByteArray,
  network_id: Int,
  credential_type: Int,
) -> ByteArray {
  bytearray.concat(
    bytearray.concat(
      bytearray.concat(
        bytearray.concat(
          bytearray.concat(user_pkh, bytearray.from_int_big_endian(tier, 1)),
          encode_valid_until(ttl_ms),
        ),
        security_policy_id,
      ),
      bytearray.from_int_big_endian(network_id, 1),
    ),
    bytearray.from_int_big_endian(credential_type, 1),
  )
}

/// The test holder as a verification-key credential.
fn test_user_cred() -> Credential {
  VerificationKey(test_user_pkh)
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
    deactivated: False,
    mintable_amount: 0,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: trusted_keys,
    member_root_hash: #"",
    requires_sender_kyc: True,
    requires_receiver_kyc: True,
    network_id: test_network_id,
    minting_script_credential_hash: #"",
    upgrades_locked: False,
  }
}

/// GlobalStateDatum with an empty TEL and the given MPF root hash.
fn test_gs_datum_with_root(root: ByteArray) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    deactivated: False,
    mintable_amount: 0,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: root,
    requires_sender_kyc: True,
    requires_receiver_kyc: True,
    network_id: test_network_id,
    minting_script_credential_hash: #"",
    upgrades_locked: False,
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
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
    test_user_cred(),
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

/// The attestation was issued for a VERIFICATION KEY credential. The very same
/// 28-byte hash presented as a SCRIPT credential must not satisfy it — before
/// the discriminator byte existed, it did. This is the whole point of the
/// credential-type byte.
test attestation_fails_when_credential_type_mismatches() {
  let proof = AttestationProof {
    payload: make_payload_for(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
      credential_type_key,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    Script(test_user_pkh),
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

/// The mirror: a payload issued for a SCRIPT credential does not satisfy
/// the verification key with the same hash either. Both directions matter — a
/// one-directional check would still let one form impersonate the other.
test attestation_fails_when_script_payload_used_for_a_key() {
  let proof = AttestationProof {
    payload: make_payload_for(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
      credential_type_script,
    ),
    signature: test_invalid_signature,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_cred(),
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── verify_attestation_proof — positive controls ──────────────────────────────
// Every negative test above proves the verifier rejects a specific defect.
// None of them proves the verifier can ever accept anything: a verifier that
// always returns False passes every test above too. These pin the accept
// path with a genuine Ed25519 signature produced by
// `scripts/kyc-test-vectors.mjs` over the fixed seed key whose public half is
// `test_issuer_vkey`.

/// A genuine signature, over a well-formed payload, from an issuer present in
/// the TEL, within the TTL, for the right policy/network/credential — every
/// gate satisfied — must verify.
test attestation_succeeds_with_a_genuine_signature() {
  let proof = AttestationProof {
    payload: make_payload(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
    ),
    signature: test_genuine_signature_key_cred,
    issuer_vkey: test_issuer_vkey,
  }
  verify_attestation_proof(
    proof,
    test_user_cred(),
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

/// The Script-credential twin of the above: a genuine signature issued for a
/// Script-form holder, checked against `Script(test_user_pkh)`, must verify.
test attestation_succeeds_for_a_script_credential() {
  let proof = AttestationProof {
    payload: make_payload_for(
      test_user_pkh,
      1,
      test_ttl_ms,
      test_security_policy_id,
      test_network_id,
      credential_type_script,
    ),
    signature: test_genuine_signature_script_cred,
    issuer_vkey: test_issuer_vkey,
  }
  verify_attestation_proof(
    proof,
    Script(test_user_pkh),
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

/// Pins that the positive test above passes for the RIGHT reason: the
/// signature is actually checked against the payload bytes, not merely
/// present. Reusing the exact genuine signature but flipping the tier byte
/// (0x01 → 0x02 — still a non-invalid tier, so `fields_ok` stays True and
/// every OTHER gate is unaffected) isolates `sig_ok` as the sole possible
/// cause of failure. If a regression made `sig_ok` vacuously True (e.g. the
/// signature check were skipped or short-circuited), this test would catch
/// it even though `attestation_succeeds_with_a_genuine_signature` would not.
test attestation_genuine_signature_fails_when_payload_is_altered() {
  let altered_payload = make_payload(
    test_user_pkh,
    2,
    test_ttl_ms,
    test_security_policy_id,
    test_network_id,
  )
  let proof = AttestationProof {
    payload: altered_payload,
    signature: test_genuine_signature_key_cred,
    issuer_vkey: test_issuer_vkey,
  }
  !verify_attestation_proof(
    proof,
    test_user_cred(),
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── Membership leaf encoding ─────────────────────────────────────────────────

/// The two credential forms of one hash must produce DIFFERENT leaf keys,
/// otherwise a script credential inherits a verification key's membership.
test membership_leaf_key_separates_credential_forms() {
  and {
    membership_leaf_key(VerificationKey(test_user_pkh)) != membership_leaf_key(
      Script(test_user_pkh),
    ),
    // …and each is the 1-byte tag followed by the hash, so the tag cannot be
    // confused with the first byte of a hash.
    membership_leaf_key(VerificationKey(test_user_pkh)) == bytearray.concat(
      #"00",
      test_user_pkh,
    ),
    membership_leaf_key(Script(test_user_pkh)) == bytearray.concat(
      #"01",
      test_user_pkh,
    ),
  }
}

/// The leaf value must commit to the policy id and the network id, not
/// just the TTL — otherwise a membership root is portable between deployments
/// and across networks.
test membership_leaf_value_binds_policy_and_network() {
  let other_policy = #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  and {
    membership_leaf_value(test_ttl_ms, test_security_policy_id, 1) != membership_leaf_value(
      test_ttl_ms,
      other_policy,
      1,
    ),
    membership_leaf_value(test_ttl_ms, test_security_policy_id, 1) != membership_leaf_value(
      test_ttl_ms,
      test_security_policy_id,
      2,
    ),
    // 8-byte TTL + 28-byte policy + 1-byte network.
    bytearray.length(
      membership_leaf_value(test_ttl_ms, test_security_policy_id, 1),
    ) == 37,
  }
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
    VerificationKey(different_pkh),
    test_gs_datum_with_root(#""),
    test_security_policy_id,
    test_network_id,
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
    test_user_cred(),
    test_gs_datum_with_root(#""),
    test_security_policy_id,
    test_network_id,
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
    test_user_cred(),
    test_gs_datum_with_root(#""),
    test_security_policy_id,
    test_network_id,
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
    test_user_cred(),
    test_gs_datum_with_root(fake_root),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── verify_membership_proof — positive controls ───────────────────────────────
// Every negative test above proves the verifier rejects a specific defect —
// none of them proves it can ever accept anything true. These build a REAL
// root with the vendored MPF library itself (never hand-pasted) so the
// verifier is checked against a root nobody could get right by accident.

/// A single-leaf tree containing exactly the expected credential's leaf, with
/// an empty inclusion proof (correct for a one-leaf trie), must verify.
test membership_succeeds_with_a_genuine_single_leaf_root() {
  let root = mpf.empty
    |> mpf.insert(
        membership_leaf_key(test_user_cred()),
        membership_leaf_value(
          test_ttl_ms,
          test_security_policy_id,
          test_network_id,
        ),
        [],
      )
    |> mpf.root()
  let proof = MembershipProof {
    pkh: test_user_pkh,
    valid_until_ms: test_ttl_ms,
    mpf_proof: [],
  }
  verify_membership_proof(
    proof,
    test_user_cred(),
    test_gs_datum_with_root(root),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

/// The Script-credential twin: a single-leaf tree built for
/// `Script(test_user_pkh)` (a DIFFERENT leaf key than the VerificationKey
/// form — see `membership_leaf_key_separates_credential_forms`) must verify
/// against that same Script credential.
test membership_succeeds_with_a_genuine_single_leaf_root_for_a_script_credential() {
  let script_cred = Script(test_user_pkh)
  let root = mpf.empty
    |> mpf.insert(
        membership_leaf_key(script_cred),
        membership_leaf_value(
          test_ttl_ms,
          test_security_policy_id,
          test_network_id,
        ),
        [],
      )
    |> mpf.root()
  let proof = MembershipProof {
    pkh: test_user_pkh,
    valid_until_ms: test_ttl_ms,
    mpf_proof: [],
  }
  verify_membership_proof(
    proof,
    script_cred,
    test_gs_datum_with_root(root),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

/// Pins that the positive test above passes for the RIGHT reason: the SAME
/// genuine root — built for the VerificationKey form only — does not also
/// satisfy the Script form of the identical hash. `membership_leaf_key`
/// making the two forms different leaves is only meaningful if
/// `verify_membership_proof` actually looks up the right one; this proves it
/// does, using a real library-computed root rather than an empty placeholder.
test membership_genuine_root_rejects_other_credential() {
  let root = mpf.empty
    |> mpf.insert(
        membership_leaf_key(test_user_cred()),
        membership_leaf_value(
          test_ttl_ms,
          test_security_policy_id,
          test_network_id,
        ),
        [],
      )
    |> mpf.root()
  let proof = MembershipProof {
    pkh: test_user_pkh,
    valid_until_ms: test_ttl_ms,
    mpf_proof: [],
  }
  !verify_membership_proof(
    proof,
    Script(test_user_pkh),
    test_gs_datum_with_root(root),
    test_security_policy_id,
    test_network_id,
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
    test_user_cred(),
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
    VerificationKey(different_pkh),
    test_gs_datum_with_root(#""),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

// ── verify_kyc_proof — dispatch positive controls ─────────────────────────────
// The two tests above prove routing on the REJECT path — they'd pass even if
// `verify_kyc_proof` always returned False. These prove the ACCEPT path is
// reachable through the dispatcher too, using the same genuine fixtures as
// the two verifiers' own positive controls above.

test kyc_proof_routes_attestation_variant_and_accepts_a_genuine_proof() {
  let proof = Attestation {
    kyc_proof: AttestationProof {
      payload: make_payload(
        test_user_pkh,
        1,
        test_ttl_ms,
        test_security_policy_id,
        test_network_id,
      ),
      signature: test_genuine_signature_key_cred,
      issuer_vkey: test_issuer_vkey,
    },
  }
  verify_kyc_proof(
    proof,
    test_user_cred(),
    test_gs_datum_with_tel(test_tel()),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

test kyc_proof_routes_membership_variant_and_accepts_a_genuine_proof() {
  let root = mpf.empty
    |> mpf.insert(
        membership_leaf_key(test_user_cred()),
        membership_leaf_value(
          test_ttl_ms,
          test_security_policy_id,
          test_network_id,
        ),
        [],
      )
    |> mpf.root()
  let proof = Membership {
    membership_proof: MembershipProof {
      pkh: test_user_pkh,
      valid_until_ms: test_ttl_ms,
      mpf_proof: [],
    },
  }
  verify_kyc_proof(
    proof,
    test_user_cred(),
    test_gs_datum_with_root(root),
    test_security_policy_id,
    test_network_id,
    tx_with_upper_bound(test_tx_upper),
  )
}

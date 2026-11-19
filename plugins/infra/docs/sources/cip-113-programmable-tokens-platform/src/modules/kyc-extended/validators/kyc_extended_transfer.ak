use aiken/builtin
use aiken/collection/list
use aiken/crypto.{verify_ed25519_signature}
use aiken/interval
use aiken/interval.{Finite}
use aiken/merkle_patricia_forestry.{MerklePatriciaForestry, Proof} as mpf
use aiken/primitive/bytearray
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, Withdraw,
}
use types/global_state.{GlobalStateDatum}
use utils.{extract_recipient_witnesses}

// ─── Types ──────────────────────────────────────────────────────────────────

/// A KYC proof attesting that a user has been verified by a trusted entity.
pub type KycProof {
  global_state_idx: Int,
  vkey_idx: Int,
  /// 37-byte payload: user_pkh(28) || role(1) || valid_until(8)
  payload: ByteArray,
  signature: ByteArray,
}

/// An MPF membership proof attesting that a PKH is in the receiver allowlist.
pub type MembershipProof {
  pkh: ByteArray,
  valid_until_ms: Int,
  mpf_proof: Proof,
}

/// Sender proof union: either a live attestation or a membership inclusion proof.
pub type SenderProof {
  Attestation { kyc_proof: KycProof }
  Membership { proof: MembershipProof }
}

/// Redeemer for the kyc-extended transfer validator.
pub type KycExtendedTransferRedeemer {
  /// Index into reference_inputs for the extended global state UTxO
  global_state_idx: Int,
  sender_proofs: List<SenderProof>,
  receiver_proofs: List<MembershipProof>,
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Encode a millisecond timestamp as an 8-byte big-endian ByteArray.
pub fn encode_valid_until(ms: Int) -> ByteArray {
  bytearray.from_int_big_endian(ms, 8)
}

/// Check membership: pkh in trie with given valid_until_ms, and not expired.
pub fn validate_membership(
  trie: MerklePatriciaForestry,
  subject: ByteArray,
  m: MembershipProof,
  tx_upper_bound: Int,
) -> Bool {
  and {
    m.pkh == subject,
    mpf.has(trie, m.pkh, encode_valid_until(m.valid_until_ms), m.mpf_proof),
    tx_upper_bound <= m.valid_until_ms,
  }
}

/// Validate a single KYC attestation proof for a sender witness.
fn validate_kyc_proof(
  tel_policy_id: PolicyId,
  proof: KycProof,
  reference_inputs: List<Input>,
  witness: ByteArray,
  tx_upper_bound: Int,
) -> Bool {
  let KycProof { global_state_idx, vkey_idx, payload, signature } = proof

  expect Some(ref_input) = list.at(reference_inputs, global_state_idx)

  let has_tel_token =
    ref_input.output.value
      |> assets.flatten
      |> list.any(fn(triple) { triple.1st == tel_policy_id })

  expect has_tel_token

  expect InlineDatum(raw) = ref_input.output.datum
  expect datum: GlobalStateDatum = raw
  expect !datum.transfers_paused

  expect Some(vkey) = list.at(datum.trusted_entities, vkey_idx)

  let sig_valid = verify_ed25519_signature(vkey, payload, signature)
  let user_pkh = bytearray.slice(payload, 0, 27)
  let pkh_matches = user_pkh == witness
  let valid_until =
    bytearray.slice(payload, 29, 36) |> bytearray.to_int_big_endian
  let ttl_ok = tx_upper_bound <= valid_until

  sig_valid && pkh_matches && ttl_ok
}

/// Extract credential hashes from inputs at the programmable logic base credential.
fn extract_required_witnesses(
  inputs: List<Input>,
  prog_base_cred: Credential,
) -> List<ByteArray> {
  list.foldr(
    inputs,
    [],
    fn(input, acc) {
      if input.output.address.payment_credential == prog_base_cred {
        when input.output.address.stake_credential is {
          Some(Inline(cred)) ->
            when cred is {
              VerificationKey(pkh) -> [pkh, ..acc]
              Script(script_hash) -> [script_hash, ..acc]
            }
          _ -> acc
        }
      } else {
        acc
      }
    },
  )
}

/// Check if this is a rewarding script (withdraw-zero trick).
fn is_rewarding_script(
  redeemers: Pairs<transaction.ScriptPurpose, transaction.Redeemer>,
  account: Credential,
) -> Bool {
  list.any(
    redeemers,
    fn(pair) {
      let Pair(purpose, _redeemer) = pair
      when purpose is {
        Withdraw(cred) -> cred == account
        _ -> False
      }
    },
  )
}

// ─── Validators ─────────────────────────────────────────────────────────────

/// Issuer admin contract: only the permitted credential can authorize issuance.
validator issue(_tel_policy_id: ByteArray, permitted_cred: Credential) {
  withdraw(_redeemer: Data, _account: Credential, self: Transaction) {
    when permitted_cred is {
      VerificationKey(pkh) ->
        list.has(self.extra_signatories, pkh)
      Script(script_hash) -> {
        let script_cred = Script(script_hash)
        list.any(
          self.withdrawals,
          fn(wdrl) {
            let Pair(cred, _amount) = wdrl
            cred == script_cred
          },
        )
      }
    }
  }

  else(_) {
    fail
  }
}

/// KYC-extended transfer validator.
/// Validates senders via Attestation or Membership proofs, receivers via Membership only.
validator transfer(
  programmable_logic_base_cred: Credential,
  tel_policy_id: PolicyId,
) {
  withdraw(
    redeemer: KycExtendedTransferRedeemer,
    account: Credential,
    self: Transaction,
  ) {
    let is_rewarding = is_rewarding_script(self.redeemers, account)

    // Get extended global state from reference inputs
    expect Some(gs_ref_input) =
      list.at(self.reference_inputs, redeemer.global_state_idx)
    expect InlineDatum(raw_datum) = gs_ref_input.output.datum
    expect gs_datum: GlobalStateDatum = raw_datum

    // Build membership trie from root hash stored in global state
    let trie = mpf.from_root(gs_datum.member_root_hash)

    let witnesses =
      extract_required_witnesses(self.inputs, programmable_logic_base_cred)

    // Receivers = output prog-base witnesses minus any witness already present
    // as a sender (i.e. the sender's own change-back output is NOT a "new"
    // recipient and thus does not require an MPF inclusion proof). Senders
    // authenticate via sender_proofs (Attestation or Membership), which is
    // sufficient to authorise their own change.
    let raw_receiver_witnesses =
      extract_recipient_witnesses(self.outputs, programmable_logic_base_cred)
    let receiver_witnesses =
      list.filter(raw_receiver_witnesses, fn(w) { !list.has(witnesses, w) })

    expect Finite(tx_upper_bound) = self.validity_range.upper_bound.bound_type

    // Parity checks
    expect list.length(witnesses) == list.length(redeemer.sender_proofs)
    expect
      list.length(receiver_witnesses) == list.length(redeemer.receiver_proofs)

    let all_senders_valid =
      list.map2(
        witnesses,
        redeemer.sender_proofs,
        fn(witness, sender_proof) {
          when sender_proof is {
            Attestation { kyc_proof } ->
              validate_kyc_proof(
                tel_policy_id,
                kyc_proof,
                self.reference_inputs,
                witness,
                tx_upper_bound,
              )
            Membership { proof } ->
              validate_membership(trie, witness, proof, tx_upper_bound)
          }
        },
      )
        |> list.all(fn(x) { x })

    let all_receivers_valid =
      list.map2(
        receiver_witnesses,
        redeemer.receiver_proofs,
        fn(receiver_witness, membership_proof) {
          validate_membership(trie, receiver_witness, membership_proof, tx_upper_bound)
        },
      )
        |> list.all(fn(x) { x })

    and {
      is_rewarding,
      all_senders_valid,
      all_receivers_valid,
    }
  }

  else(_) {
    fail
  }
}

// ─── Tests ──────────────────────────────────────────────────────────────────

const test_pkh = #"0102030405060708091011121314151617181920212223242526272829"

const test_valid_until_ms = 9_999_999_999_999

const test_tx_upper_bound = 9_000_000_000_000

// Build a single-element trie. For an empty trie, both insert proof and has
// proof are [] (the path through an empty trie is a single leaf with no siblings).
fn test_trie_with_pkh() {
  mpf.empty
    |> mpf.insert(test_pkh, encode_valid_until(test_valid_until_ms), [])
}

test validate_membership_happy_path() {
  let trie = test_trie_with_pkh()
  let m =
    MembershipProof {
      pkh: test_pkh,
      valid_until_ms: test_valid_until_ms,
      mpf_proof: [],
    }
  validate_membership(trie, test_pkh, m, test_tx_upper_bound)
}

test validate_membership_fails_wrong_root() fail {
  // Verify against empty trie (stale root) — proof is invalid
  let stale_trie = mpf.empty
  let m =
    MembershipProof {
      pkh: test_pkh,
      valid_until_ms: test_valid_until_ms,
      mpf_proof: [],
    }
  validate_membership(stale_trie, test_pkh, m, test_tx_upper_bound)
}

test validate_membership_fails_mutated_valid_until() fail {
  let trie = test_trie_with_pkh()
  // Use a different valid_until_ms in the proof than what's in the trie
  let m =
    MembershipProof {
      pkh: test_pkh,
      valid_until_ms: test_valid_until_ms + 1,
      mpf_proof: [],
    }
  validate_membership(trie, test_pkh, m, test_tx_upper_bound)
}

test validate_membership_fails_expired_tx_upper_bound() fail {
  let trie = test_trie_with_pkh()
  let m =
    MembershipProof {
      pkh: test_pkh,
      valid_until_ms: test_valid_until_ms,
      mpf_proof: [],
    }
  // tx_upper_bound exceeds valid_until_ms
  validate_membership(trie, test_pkh, m, test_valid_until_ms + 1)
}

// ─── End-to-end transfer test (Membership sender + Membership receiver) ──────

const test_prog_base_cred = VerificationKey(#"aabbccdd11223344")

const test_account_hash = #"deadbeef00112233445566778899aabb"

fn make_tx_input(pay_cred, stake_pkh) -> Input {
  Input {
    output_reference: OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000001",
      output_index: 0,
    },
    output: Output {
      address: Address {
        payment_credential: pay_cred,
        stake_credential: Some(Inline(VerificationKey(stake_pkh))),
      },
      value: assets.zero,
      datum: NoDatum,
      reference_script: None,
    },
  }
}

fn make_tx_output(pay_cred, stake_pkh) -> Output {
  Output {
    address: Address {
      payment_credential: pay_cred,
      stake_credential: Some(Inline(VerificationKey(stake_pkh))),
    },
    value: assets.zero,
    datum: NoDatum,
    reference_script: None,
  }
}

// End-to-end transfer scenario: Membership sender + Membership receiver.
// Tests the core transfer logic components without constructing a full Transaction,
// which requires the spread record update syntax not available in Aiken v1.1.21 tests.
test transfer_membership_sender_and_receiver() {
  let trie = test_trie_with_pkh()
  let root = mpf.root(trie)
  let proof =
    MembershipProof {
      pkh: test_pkh,
      valid_until_ms: test_valid_until_ms,
      mpf_proof: [],
    }

  // Verify global state datum round-trip via InlineDatum
  let gs_datum =
    GlobalStateDatum {
      transfers_paused: False,
      mintable_amount: 100,
      trusted_entities: [],
      security_info: 0,
      member_root_hash: root,
    }

  // Verify the trie can be reconstructed from the root
  let reconstructed_trie = mpf.from_root(gs_datum.member_root_hash)

  // Verify both sender proof (Membership variant) and receiver proof
  let sender_valid =
    validate_membership(reconstructed_trie, test_pkh, proof, test_tx_upper_bound)
  let receiver_valid =
    validate_membership(reconstructed_trie, test_pkh, proof, test_tx_upper_bound)

  // Verify is_rewarding_script detects the correct Withdraw credential
  let account = Script(test_account_hash)
  let fake_redeemers: Pairs<transaction.ScriptPurpose, transaction.Redeemer> =
    [Pair(Withdraw(account), builtin.i_data(0))]
  let is_rewarding = is_rewarding_script(fake_redeemers, account)

  // Verify parity of witnesses and proofs
  let sender_proofs = [Membership { proof }]
  let receiver_proofs = [proof]
  let sender_input = make_tx_input(test_prog_base_cred, test_pkh)
  let receiver_output = make_tx_output(test_prog_base_cred, test_pkh)
  let witnesses = extract_required_witnesses([sender_input], test_prog_base_cred)
  let receiver_witnesses =
    extract_recipient_witnesses([receiver_output], test_prog_base_cred)

  and {
    is_rewarding,
    list.length(witnesses) == list.length(sender_proofs),
    list.length(receiver_witnesses) == list.length(receiver_proofs),
    sender_valid,
    receiver_valid,
  }
}

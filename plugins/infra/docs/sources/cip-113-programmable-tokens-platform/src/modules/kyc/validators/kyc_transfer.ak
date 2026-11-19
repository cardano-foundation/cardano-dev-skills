use aiken/collection/list
use aiken/crypto.{verify_ed25519_signature}
use aiken/interval.{Finite}
use aiken/primitive/bytearray
use cardano/address.{Credential, Inline, Script, VerificationKey}
use cardano/assets.{PolicyId}
use cardano/transaction.{InlineDatum, Input, Transaction, Withdraw}
use types/global_state.{GlobalStateDatum}

// ─── Types ──────────────────────────────────────────────────────────────────

/// A KYC proof attesting that a user has been verified by a trusted entity.
/// The trusted entity's vkey is looked up from the global state UTxO datum.
pub type KycProof {
  /// Index of the global state UTxO in the transaction's reference inputs
  global_state_idx: Int,
  /// Index of the trusted entity's vkey in the global state datum list
  vkey_idx: Int,
  /// 37-byte payload: user_pkh(28) || role(1) || valid_until(8)
  payload: ByteArray,
  /// 64-byte Ed25519 signature over `payload`, produced by the trusted entity
  signature: ByteArray,
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Extract credential hashes from inputs with the programmable logic base credential.
/// These are the "witnesses" that need valid KYC attestations.
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

/// Validate a single KYC proof for a given witness.
///
/// Checks:
///   1. The referenced global state UTxO carries a token from `tel_policy_id`
///   2. Transfers are not paused in the global state datum
///   3. The vkey at `vkey_idx` in the global state datum is used to verify
///   4. The entity's Ed25519 signature over the payload is valid
///   5. The first 28 bytes of the payload match the witness credential hash
///   6. The transaction TTL does not exceed the proof's valid_until timestamp
fn validate_kyc_proof(
  tel_policy_id: PolicyId,
  proof: KycProof,
  reference_inputs: List<Input>,
  witness: ByteArray,
  tx_upper_bound: Int,
) -> Bool {
  let KycProof { global_state_idx, vkey_idx, payload, signature } = proof

  // 1. Get the global state UTxO from reference inputs at the given index
  expect Some(ref_input) = list.at(reference_inputs, global_state_idx)

  // 2. Check the reference input carries a global state token (authenticity)
  let has_tel_token =
    ref_input.output.value
      |> assets.flatten
      |> list.any(fn(triple) { triple.1st == tel_policy_id })

  expect has_tel_token

  // 3. Extract datum and check transfers are not paused
  expect InlineDatum(raw) = ref_input.output.datum
  expect datum: GlobalStateDatum = raw
  expect !datum.transfers_paused

  // 4. Extract vkey from the global state datum's trusted entity list
  expect Some(vkey) = list.at(datum.trusted_entities, vkey_idx)

  // 5. Verify the entity's signature over the payload
  let sig_valid = verify_ed25519_signature(vkey, payload, signature)

  // 6. First 28 bytes of payload must match the witness credential hash
  let user_pkh = bytearray.slice(payload, 0, 27)
  let pkh_matches = user_pkh == witness

  // 7. Transaction upper bound must not exceed valid_until from payload
  let valid_until =
    bytearray.slice(payload, 29, 36) |> bytearray.to_int_big_endian
  let ttl_ok = tx_upper_bound <= valid_until

  sig_valid && pkh_matches && ttl_ok
}

/// Check if this is a rewarding script (withdraw-zero trick)
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
/// Parameterised by the TEL policy ID (makes each token unique) and the admin credential.
validator issue(_tel_policy_id: ByteArray, permitted_cred: Credential) {
  withdraw(_redeemer: Data, _account: Credential, self: Transaction) {
    when permitted_cred is {
      VerificationKey(pkh) -> list.has(self.extra_signatories, pkh)
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

/// KYC transfer logic validator.
/// Validates that all senders of programmable tokens have valid KYC attestations
/// from entities in the Trusted Entity List (TEL) stored in the global state UTxO.
///
/// Parameters:
///   - programmable_logic_base_cred: payment credential of all programmable token UTxOs
///   - tel_policy_id: policy ID of the global state NFT (= global_state_cs from registry)
///
/// Redeemer: List<KycProof> — one proof per sender credential
validator transfer(
  programmable_logic_base_cred: Credential,
  tel_policy_id: PolicyId,
) {
  withdraw(proofs: List<KycProof>, account: Credential, self: Transaction) {
    // 1. Verify this is invoked as a rewarding script (withdraw-zero trick)
    let is_rewarding = is_rewarding_script(self.redeemers, account)

    // 2. Extract all credential hashes from programmable logic base inputs
    let witnesses =
      extract_required_witnesses(self.inputs, programmable_logic_base_cred)

    // 3. Extract the transaction's upper bound for TTL checking
    expect Finite(tx_upper_bound) = self.validity_range.upper_bound.bound_type

    // 4. Validate each witness has a corresponding valid KYC proof
    let all_proofs_valid =
      list.map2(
        witnesses,
        proofs,
        fn(witness, proof) {
          validate_kyc_proof(
            tel_policy_id,
            proof,
            self.reference_inputs,
            witness,
            tx_upper_bound,
          )
        },
      )
        |> list.all(fn(x) { x })

    and {
      is_rewarding,
      all_proofs_valid,
    }
  }

  else(_) {
    fail
  }
}

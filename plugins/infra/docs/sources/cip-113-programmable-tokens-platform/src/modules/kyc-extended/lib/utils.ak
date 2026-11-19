use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Credential, Inline, Script, VerificationKey}
use cardano/assets.{PolicyId, Value, tokens}
use cardano/transaction.{Output, Transaction}

/// Check if the transaction is signed by the given credential hash,
/// either via extra_signatories (vkey) or via withdrawals (script).
pub fn must_be_signed_by_credential(
  transaction: Transaction,
  credential_hash: ByteArray,
) {
  or {
    list.has(transaction.extra_signatories, credential_hash),
    pairs.has_key(transaction.withdrawals, Script(credential_hash)),
  }
}

/// Safe list indexing that fails on negative or out-of-bounds index.
pub fn safe_list_at(self: List<a>, index: Int) -> a {
  expect index >= 0
  do_list_at(self, index)
}

fn do_list_at(self: List<a>, index: Int) -> a {
  if index == 0 {
    builtin.head_list(self)
  } else {
    do_list_at(builtin.tail_list(self), index - 1)
  }
}

/// Returns the total quantity of all tokens with the given policyId.
pub fn quantity_of_policy_id(value: Value, policy_id: PolicyId) {
  dict.foldl(tokens(value, policy_id), 0, fn(_k, v, result) { v + result })
}

/// Extract stake credential hashes from outputs whose payment credential matches
/// prog_base_cred. Fails hard on outputs missing an inline stake credential of
/// a supported shape (VerificationKey or Script) — no silent skipping.
pub fn extract_recipient_witnesses(
  outputs: List<Output>,
  prog_base_cred: Credential,
) -> List<ByteArray> {
  list.foldr(
    outputs,
    [],
    fn(output, acc) {
      if output.address.payment_credential == prog_base_cred {
        when output.address.stake_credential is {
          Some(Inline(cred)) ->
            when cred is {
              VerificationKey(pkh) -> [pkh, ..acc]
              Script(script_hash) -> [script_hash, ..acc]
            }
          _ -> fail @"kyc-extended: output at prog_base_cred missing inline stake credential"
        }
      } else {
        acc
      }
    },
  )
}

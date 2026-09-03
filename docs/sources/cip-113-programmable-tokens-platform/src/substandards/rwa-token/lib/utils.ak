use aiken/builtin.{head_list, tail_list}
use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken_design_patterns/linked_list.{get_node_element_info, run_node_with}
use cardano/address.{Address, Credential, Script, VerificationKey}
use cardano/assets.{PolicyId, Value, tokens}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants
use types/kyc_proof
use types/power_users.{PowerUser}

/// Consent from a credential that may legitimately be EITHER a key or a
/// script — an admin, a power user, an operator. A key signature and a
/// script's withdraw-0 are equally valid evidence for those.
///
/// Do NOT use this where the credential must be a script that independently
/// re-decides something (i.e. where the point is that specific script's
/// LOGIC runs). A bare signature satisfies this function, so such a check
/// would be satisfiable without the script ever executing. Use
/// `must_run_script_withdrawal` instead — see its doc comment.
///
/// THE SAME FOOTGUN APPLIES TO EVERY CREDENTIAL THIS HELPER GATES, not just to
/// `minting_script_credential_hash` (whose case `lib/types/global_state.ak`
/// documents at length). That is all five power-user roles — `is_admin`,
/// `can_mint`, `can_burn`, `can_pause`, `can_force_transfer` — AND
/// `GlobalStateDatum.admin_credential_hash`, which gates ten of the twelve
/// GlobalState spend branches. A credential naming a permissive SCRIPT rather
/// than a key is satisfiable by anyone who can make that script run.
///
/// Two worst instances. Point `can_force_transfer` at `transfer_logic_script`,
/// whose withdraw-0 requires no signature at all, and seizure powers become
/// public. Set `admin_credential_hash` the same way at genesis and the whole
/// protocol does — including `RotateAdmin`, because the outgoing-admin half of
/// its dual signature would be trivially satisfiable too, so the mistake could
/// not even be corrected by rotating away from it.
///
/// `sanitise_initial_datum` length-checks `admin_credential_hash` but cannot
/// check this: whether a hash names something that genuinely decides is not
/// visible on chain.
///
/// DEPLOYMENT REQUIREMENT, not enforced on-chain: after granting OR rotating
/// ANY power-user role, run the smoke test prescribed in
/// `lib/types/global_state.ak` — assert that an operation exercising that role
/// WITHOUT the operator's signature is REJECTED. The failure mode is silent and
/// fails OPEN, so it will never surface on its own.
pub fn must_be_signed_by_credential(
  transaction: Transaction,
  credential_hash: ByteArray,
) {
  or {
    list.has(transaction.extra_signatories, credential_hash),
    pairs.has_key(transaction.withdrawals, Script(credential_hash)),
  }
}

/// Strictly "this SCRIPT ran and succeeded in this transaction" — the
/// withdraw-0 half of `must_be_signed_by_credential`, with the
/// signature-equivalence deliberately removed.
///
/// A script named as a withdrawal key must be executed and must succeed for
/// the transaction to validate at all (Plutus phase-2 validation is
/// all-or-nothing across every script purpose in a transaction), so presence
/// of the key here really does prove that script's own logic approved this
/// transaction. That is a strictly stronger claim than
/// `must_be_signed_by_credential` makes, and it is the claim required
/// wherever one validator delegates a decision to another.
pub fn must_run_script_withdrawal(
  transaction: Transaction,
  script_hash: ByteArray,
) -> Bool {
  pairs.has_key(transaction.withdrawals, Script(script_hash))
}

pub fn safe_list_at(self: List<a>, index: Int) -> a {
  expect index >= 0
  do_list_at(self, index)
}

fn do_list_at(elems: List<a>, at: Int) -> a {
  if at >= 2 {
    do_list_at(tail_list(tail_list(elems)), at - 2)
  } else {
    head_list(
      if at == 1 {
        tail_list(elems)
      } else {
        elems
      },
    )
  }
}

/// Returns the quantity of all tokens with the policyId
pub fn quantity_of_policy_id(value: Value, policyId: PolicyId) {
  dict.foldl(tokens(value, policyId), 0, fn(_k, v, result) { v + result })
}

/// Authenticate a power-user linked-list node and return its key and role
/// flags.
///
/// Three things have to hold before a node may grant anything, and this is the
/// single place they are all checked:
///
/// 1. It is a genuine element of `power_user_list_policy_id` — the library
///    requires a UTxO holding exactly ADA plus one NFT of that policy, with a
///    well-formed inline `Element` datum.
/// 2. It is a NODE, not the list root. `get_node_element_info` enforces this
///    structurally, so there is no `expect Some(key)` to get wrong.
/// 3. It still LIVES AT THE LIST'S SPEND ADDRESS. Authentication says nothing
///    about where an element sits, and that omission is load-bearing: the key
///    is fixed by the NFT's asset name, but the ROLE FLAGS come from the datum.
///    A power-user NFT carried out of the list into a private wallet would
///    otherwise keep granting whatever flags its holder writes, so a revoked
///    operator would keep their powers. Pinning the address is what makes
///    revocation stick.
///
/// Every caller that reads power-user authority goes through here — the
/// denylist mint, the minting authority, the seizure logic and the GlobalState
/// pause branch — so the three checks cannot drift apart between them.
pub fn authenticated_power_user(
  node_output: Output,
  power_user_list_policy_id: PolicyId,
  power_user_list_script_hash: ByteArray,
) -> (ByteArray, PowerUser) {
  get_node_element_info(
    node_output,
    fn(address, _lovelace, node_key, data, _link) {
      expect Address { payment_credential: Script(node_script), .. } = address
      expect node_script == power_user_list_script_hash
      expect power_user_data: PowerUser = data
      (node_key, power_user_data)
    },
  )
    |> run_node_with(
        power_user_list_policy_id,
        constants.linked_list_node_key_prefix,
        constants.linked_list_node_key_prefix_length,
      )
}

/// The 28-byte hash inside a credential, with the constructor DISCARDED.
///
/// Use this only where collapsing a key and a script to the same identity is
/// deliberate and conservative — the denylist, where sanctioning one form must
/// sanction both. Anywhere the constructor carries meaning (KYC attestations,
/// the holder register), carry the `Credential` itself and pair this with
/// `credential_type_byte`.
pub fn credential_hash(credential: Credential) -> ByteArray {
  when credential is {
    VerificationKey(hash) -> hash
    Script(hash) -> hash
  }
}

/// The credential's constructor as the 1-byte discriminator committed
/// into a KYC attestation payload (byte 66) and into the membership tree's
/// leaf key. `0x00` = `VerificationKey`, `0x01` = `Script`.
///
/// The CIP-113 base layer treats these as different owners — a
/// `VerificationKey` owner consents by signature, a `Script` owner by
/// withdraw-0 (`programmable_logic/owner.ak`) — so an attestation that does
/// not commit to which one it was issued for is transferable between them.
pub fn credential_type_byte(credential: Credential) -> Int {
  when credential is {
    VerificationKey(_) -> kyc_proof.credential_type_key
    Script(_) -> kyc_proof.credential_type_script
  }
}

/// How many of `inputs` carry at least one token of `policy_id`.
///
/// The linked-list library authenticates exactly the three element UTxOs an
/// insert or a remove touches (anchor, its reproduction, and the new/removed
/// node) and says nothing about a FOURTH. Both list `spend` handlers delegate
/// wholesale to their mint validator, which only asks whether SOME token of the
/// policy is in the mint field — so an extra list node spent alongside a
/// legitimate insert is constrained by nothing: the mint field carries one
/// asset at +1, that fourth NFT is conserved by the ledger, and no validator
/// says where it must land. It can go to a private wallet, where (because
/// element authentication never inspects the address) it keeps authenticating
/// whatever datum its holder writes — and the list is permanently corrupted,
/// since its predecessor still links to a key no longer at the script.
///
/// Pinning the input count per mint branch is the cheapest place to close this:
/// the mint validator already knows the operation shape and must run for any
/// list mutation. Outputs need no separate constraint — with inputs pinned and
/// the mint field already restricted to a single asset, value conservation
/// forces the count, and the library already requires each element output to
/// hold exactly one NFT of the policy.
pub fn count_inputs_with_policy(inputs: List<Input>, policy_id: PolicyId) -> Int {
  list.foldl(
    inputs,
    0,
    fn(input, acc) {
      if quantity_of_policy_id(input.output.value, policy_id) > 0 {
        acc + 1
      } else {
        acc
      }
    },
  )
}

/// Rebuild a Constr field list, replacing the element at `index` with
/// `new_value`. Every other field is carried through as opaque `Data` (no unwrap/rewrap).
pub fn replace_data_field(
  fields: List<Data>,
  index: Int,
  new_value: Data,
) -> List<Data> {
  if index == 0 {
    [new_value, ..tail_list(fields)]
  } else {
    [
      head_list(fields),
      ..replace_data_field(tail_list(fields), index - 1, new_value)
    ]
  }
}

/// Bool <-> Plutus Data codec. The 0/1 constructor convention lives here in one
/// place: False = Constr 0 [], True = Constr 1 [].
pub fn data_to_bool(value: Data) -> Bool {
  builtin.unconstr_index(value) == 1
}

pub fn bool_to_data(value: Bool) -> Data {
  if value {
    builtin.constr_data(1, [])
  } else {
    builtin.constr_data(0, [])
  }
}

pub fn expect_inline_datum(output: Output) -> Data {
  expect InlineDatum(d) = output.datum
  d
}

/// Derive this token's issuance policy id from a CIP-113 registry node, and
/// prove the node is the one that names `expected_script_hash`.
///
/// Takes the node as an `Output` so one function serves both shapes: in steady
/// state the caller resolves a reference input, and during a CIP-113 insert the
/// node is an OUTPUT of the very transaction creating it and does not exist as
/// a spendable UTxO yet. Neither source is weaker — `has_any_nft_strict`
/// requires a genuine registry NFT, and such an NFT can only enter an output by
/// being minted (`registry_mint` runs, enforcing CIP-113's cryptographic
/// `key` ↔ `minting_logic_script` binding) or by being carried forward from an
/// existing node (`registry_spend` runs, enforcing its own rules).
///
/// THE NODE IS ADDRESSED BY INDEX at every call site, never located by search.
/// Searching on the registry policy alone returns the FIRST matching reference
/// input, and every CIP-113 programmable token's node carries that same policy
/// — so a transaction touching a second programmable token would resolve
/// whichever node sorts first and then trap here. Reference inputs are
/// ledger-sorted by output reference, so off-chain cannot reorder its way out
/// of it; the caller must say which node is theirs.
///
/// WHAT THIS PROVES, AND WHERE IT STOPS. A caller-supplied index grants no
/// privilege ON THE MINTING PATH (field index 2): the NFT check requires a
/// genuine single-NFT registry node, the identity assertion requires that node
/// to name the given script at the given field, and CIP-113 derives a node's
/// key from the minting-logic hash while the registry forbids duplicate keys —
/// so at most one node can satisfy both, and a wrong index only traps.
///
/// That last clause is a property of the BASE LAYER, which this repository does
/// not vendor: `registry_mint`'s `is_programmable_token_id_valid` binds field 2
/// to the key, and its linked-list insert rules forbid duplicate keys. Verified
/// true of the deployed version — re-check after any base-layer upgrade.
///
/// IT DOES NOT CARRY OVER TO FIELD INDEX 3 OR 4. CIP-113 binds only field 2 to
/// the key; `transfer_logic_script` and `third_party_transfer_logic_script` are
/// free fields — the base layer only checks they are 28 bytes long — so any
/// wallet may set them to any hash in a permissionless registry insert. For
/// those callers the identity assertion below proves only "some node names me",
/// not "this is MY node", and the derived policy id is attacker-chosen.
///
/// EVERY CALLER PASSING FIELD INDEX 3 OR 4 MUST additionally compare the
/// returned policy id against a compile-time `expected_issuance_policy_id`.
/// Both transfer validators do, on the line immediately after the call.
///
/// Takes the script HASH rather than a `Credential`: callers either hold a hash
/// already, or unwrap their withdrawal credential at the call site, where the
/// `expect Script(..)` is a real assertion because a withdrawal credential may
/// legitimately be a verification key.
pub fn derive_issuance_policy_id_from_registry_node(
  node_output: Output,
  registry_policy_id: ByteArray,
  expected_script_hash: ByteArray,
  // The index of the registry node field which is taken into account for checking the correctnes of the registry node
  // and extracting the hashed params which are used to derive the issuance policy id
  registry_node_field_index: Int,
) -> PolicyId {
  expect assets.has_any_nft_strict(node_output.value, registry_policy_id)
  let registry_raw: Data = expect_inline_datum(node_output)
  let registry_fields: List<Data> = builtin.unconstr_fields(registry_raw)
  // The indexed registry field holds the script `Credential` of the logic
  // running this withdraw-0 (e.g. CIP-113's `minting_logic_script` /
  // `transfer_logic_script` / `third_party_transfer_logic_script`). Decode it as
  // a `Credential` and pull out the script hash to compare with the redeemer.
  expect Some(reg_credential_data) = list.at(
    registry_fields,
    registry_node_field_index,
  )
  expect reg_credential: Credential = reg_credential_data
  expect Script(reg_hashed_params) = reg_credential
  // Checking if the hashed params in the registry match the hashed params provided in the redeemer
  // Which if it's the case the key of the node_registry is the issuance_policy_id
  expect reg_hashed_params == expected_script_hash
  builtin.un_b_data(builtin.head_list(registry_fields))
}

use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{
  Element, Node, Root, get_element_info, run_element_with,
}
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{Value, from_asset, from_lovelace, merge, quantity_of}
use cardano/certificate.{Certificate, RegisterCredential, UnregisterCredential}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use constants
use denylist/absence.{verify_denylist_absence}
use kyc/verify.{verify_kyc_proof}
use types/global_state.{GlobalStateDatum}
use types/kyc_proof.{Attestation, AttestationProof}
use types/minting_logic_script.{
  MintBurn, MintingLogicDestinationAction, MintingLogicScriptWithdrawRedeemer,
  RegisterToken,
}
use types/power_users.{PowerUser}
use utils.{must_be_signed_by_credential}

validator minting_logic_validator(
  security_asset_name: ByteArray,
  global_state_policy_id: ByteArray,
  registry_policy_id: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
) {
  withdraw(
    redeemer: MintingLogicScriptWithdrawRedeemer,
    credential: Credential,
    self: Transaction,
  ) {
    when redeemer is {
      RegisterToken {
        registry_node_output_index,
        global_state_ref_input_index,
        global_state_input_index,
        power_user_node_ref_input_index,
        minted_amount,
        destination_actions,
      } ->
        verify_token_registration(
          registry_node_output_index,
          global_state_ref_input_index,
          global_state_input_index,
          power_user_node_ref_input_index,
          minted_amount,
          destination_actions,
          credential,
          registry_policy_id,
          global_state_policy_id,
          security_asset_name,
          power_users_linked_list_policy_id,
          self,
        )
      MintBurn {
        registry_node_ref_input_index,
        global_state_input_index,
        power_user_node_ref_input_index,
        minted_amount: expected_minted_amount,
        destination_actions,
      } -> {
        let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
          self.reference_inputs,
          registry_policy_id,
          credential,
          constants.minting_logic_script_registry_node_index,
          registry_node_ref_input_index,
        )

        let minted_amount = quantity_of(
          self.mint,
          issuance_policy_id,
          security_asset_name,
        )

        verify_mint_or_burn(
          issuance_policy_id,
          minted_amount,
          expected_minted_amount,
          global_state_input_index,
          power_user_node_ref_input_index,
          destination_actions,
          global_state_policy_id,
          security_asset_name,
          power_users_linked_list_policy_id,
          self,
        )
      }
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

/// CIP-113 registry insertion for this token.
///
/// `registry_mint`'s `RegistryInsert` requires this validator's withdraw-0 to
/// be present — the substandard's "proof of instance". At that moment the node
/// is an OUTPUT, so the steady-state reference-input lookup cannot see it.
///
/// What CIP-113 guarantees for us, and what it does not: `registry_mint` binds
/// `key` to `minting_logic_script` cryptographically (`is_programmable_token_id_valid`),
/// so the policy id cannot lie about which minting logic governs it. It binds
/// NOTHING about `transfer_logic_script`, `third_party_transfer_logic_script`,
/// `unfracking_logic_script` or `global_state_cs`. Those are free fields, and
/// this validator's withdrawal is the ONLY thing standing between an attacker
/// and a registration that names permissive logic scripts for this token —
/// which would bypass every compliance gate from genesis. Hence the admin
/// signature and the field checks below.
fn verify_token_registration(
  registry_node_output_index: Int,
  global_state_ref_input_index: Int,
  global_state_input_index: Int,
  power_user_node_ref_input_index: Int,
  expected_minted_amount: Int,
  destination_actions: List<MintingLogicDestinationAction>,
  credential: Credential,
  registry_policy_id: ByteArray,
  global_state_policy_id: ByteArray,
  security_asset_name: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
  self: Transaction,
) -> Bool {
  expect Script(own_hash) = credential

  // INSERT only: `registry_mint` mints exactly one node NFT for a
  // `RegistryInsert`. `registry_spend`'s in-place UPDATE path mints no node
  // NFT and also requires this withdraw-0, so failing here leaves node updates
  // rejected — deliberately. An update may re-point `transfer_logic_script`,
  // and this validator is its only gate, so enabling it is a separate decision
  // needing its own authorisation design.
  expect utils.quantity_of_policy_id(self.mint, registry_policy_id) > 0

  let node_output = utils.safe_list_at(self.outputs, registry_node_output_index)
  expect assets.has_any_nft_strict(node_output.value, registry_policy_id)
  let node_fields: List<Data> = builtin.unconstr_fields(
    utils.expect_inline_datum(node_output),
  )

  // Identity. An insert emits TWO registry-node outputs — the new node and the
  // re-emitted covering node — so the index alone does not identify ours.
  expect Some(minting_logic_data) = list.at(
    node_fields,
    constants.minting_logic_script_registry_node_index,
  )
  expect node_minting_logic: Credential = minting_logic_data
  expect Script(node_minting_logic_hash) = node_minting_logic
  expect node_minting_logic_hash == own_hash

  // Unfracking must stay FORBIDDEN. This repo ships no unfracking hook, and
  // unfracking lets a holder split one policy out of a shared UTxO WITHOUT
  // that policy's transfer logic running — precisely the gate this token
  // depends on. `empty_vkey` is core's least-permission value; no ledger
  // transaction can carry a withdrawal keyed by an empty hash.
  expect Some(unfracking_data) = list.at(
    node_fields,
    constants.unfracking_logic_script_registry_node_index,
  )
  expect node_unfracking: Credential = unfracking_data
  expect node_unfracking == VerificationKey(#"")

  // The node must declare THIS deployment's GlobalState.
  expect Some(global_state_cs_data) = list.at(
    node_fields,
    constants.global_state_cs_registry_node_index,
  )
  expect node_global_state_cs: ByteArray = global_state_cs_data
  expect node_global_state_cs == global_state_policy_id

  let issuance_policy_id = builtin.un_b_data(builtin.head_list(node_fields))

  // Only the security asset may appear under the issuance policy. Checked as a
  // SHAPE, not a sum: `quantity_of_policy_id(...) == 0` would also accept +N of
  // the security asset netted against −N of another asset name under the same
  // policy. `issuance_mint` constrains no asset names — it delegates entirely
  // to this validator — so a second name is possible.
  expect
    when dict.to_pairs(assets.tokens(self.mint, issuance_policy_id)) is {
      [] -> True
      [Pair(asset_name, _)] -> asset_name == security_asset_name
      _ -> False
    }
  let minted_amount = quantity_of(
    self.mint,
    issuance_policy_id,
    security_asset_name,
  )
  // Nothing exists to burn at registration.
  expect minted_amount >= 0

  if minted_amount == 0 {
    // Structural registration: GS is only REFERENCED, so read the admin
    // credential from there. No GS spend action permits a no-op re-emit.
    let gs_ref_input = utils.safe_list_at(
      self.reference_inputs,
      global_state_ref_input_index,
    )
    expect
      quantity_of(
        gs_ref_input.output.value,
        global_state_policy_id,
        constants.global_state_asset_name,
      ) == 1
    expect InlineDatum(gs_datum_raw) = gs_ref_input.output.datum
    expect gs_datum: GlobalStateDatum = gs_datum_raw
    and {
      (expected_minted_amount == 0)?,
      !gs_datum.deactivated,
      must_be_signed_by_credential(self, gs_datum.admin_credential_hash)?,
    }
  } else {
    // Registration carrying the first mint. CIP-113 allows this shape, and
    // `issuance_mint` checks only that the node is genuine and that no token
    // escapes the PLB — so every mint condition is this validator's job. GS
    // must therefore be SPENT (not referenced) so its `MintSecurity` branch
    // decrements and enforces the cap, and the admin credential is read from
    // that same spent datum.
    let gs_input = utils.safe_list_at(self.inputs, global_state_input_index)
    expect
      quantity_of(
        gs_input.output.value,
        global_state_policy_id,
        constants.global_state_asset_name,
      ) == 1
    expect InlineDatum(gs_datum_raw) = gs_input.output.datum
    expect gs_datum: GlobalStateDatum = gs_datum_raw
    and {
      // The admin authorises the registration itself...
      must_be_signed_by_credential(self, gs_datum.admin_credential_hash)?,
      // ...and the mint half passes exactly the checks the steady-state path
      // applies — power user with `can_mint`, plus the receiver gates.
      verify_mint_or_burn(
        issuance_policy_id,
        minted_amount,
        expected_minted_amount,
        global_state_input_index,
        power_user_node_ref_input_index,
        destination_actions,
        global_state_policy_id,
        security_asset_name,
        power_users_linked_list_policy_id,
        self,
      )?,
    }
  }
}

/// The mint/burn authority, shared by the steady-state `MintBurn` path and by
/// a `RegisterToken` that carries the first mint, so both are gated
/// identically. Resolves GlobalState from `self.inputs` — it must be SPENT, so
/// its `MintSecurity` branch enforces the supply cap; NFT presence on an input
/// implies that spend validator is running, and by the
/// non-Mint-branches-reject-mint invariant in global_state.ak only
/// `MintSecurity` permits a security-token mint.
fn verify_mint_or_burn(
  issuance_policy_id: ByteArray,
  minted_amount: Int,
  expected_minted_amount: Int,
  global_state_input_index: Int,
  power_user_node_ref_input_index: Int,
  destination_actions: List<MintingLogicDestinationAction>,
  global_state_policy_id: ByteArray,
  security_asset_name: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
  self: Transaction,
) -> Bool {
  let gs_input = utils.safe_list_at(self.inputs, global_state_input_index)
  expect
    quantity_of(
      gs_input.output.value,
      global_state_policy_id,
      constants.global_state_asset_name,
    ) == 1
  // Failing fast if the Token is deactivated
  expect !global_state.is_deactivated(gs_input, global_state_policy_id)
  let power_user_ref_input = utils.safe_list_at(
    self.reference_inputs,
    power_user_node_ref_input_index,
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

  // Destination verification (mirrors transfer_logic_script's per-output
  // gate): CMTAT v3.2.0 refuses to mint to a frozen address (core) and to
  // a non-allowlisted receiver (Allowlist variant). When minting, every
  // unique destination stake credential among outputs carrying the
  // security token needs a denylist-absence covering proof, plus — when
  // GS.requires_receiver_kyc — a KYC check that passes if EITHER a valid
  // KYC proof is presented OR the receiver is the power user authorising
  // this mint (`power_user_node_key`, already resolved above; it holds
  // `can_mint` and signed the tx).
  //
  // DELIBERATE DEVIATION (on record): CMTAT's Allowlist variant requires the
  // mint receiver — the minter/treasury included — to be allowlisted. Here a
  // `can_mint` power user may mint to their OWN list-authenticated credential
  // without a separate KYC attestation. Rationale: under the CIP-113 address
  // model the destination's stake credential IS the owner identity, and this
  // is a signed, list-authenticated operator minting to itself; requiring the
  // operator to also hold an off-chain KYC attestation adds no compliance
  // value. The denylist-absence check still applies to the operator, so a
  // sanctioned operator cannot mint to itself. (If you prefer exact CMTAT
  // Allowlist behaviour, drop this branch and issue the treasury a KYC
  // attestation at setup.)
  //
  // Burns have no destinations — the holder side is vetted by the CIP-113
  // spend path.
  //
  // The checks themselves live in `verify_mint_destinations` below.
  let destinations_ok = if minted_amount > 0 {
    expect InlineDatum(gs_datum_raw) = gs_input.output.datum
    expect gs_datum: GlobalStateDatum = gs_datum_raw
    verify_mint_destinations(
      self.outputs,
      destination_actions,
      [],
      issuance_policy_id,
      security_asset_name,
      gs_datum,
      power_user_node_key,
      self,
    )
  } else {
    True
  }

  and {
    //Redeemer contains the amount just for easy reference for eventual other contracts
    (minted_amount == expected_minted_amount)?,
    //A power user must have signed the transaction
    must_be_signed_by_credential(self, power_user_node_key)?,
    //If minted_amount > 0, power user must be minter
    //If minted_amount < 0, power user must be burner
    if minted_amount > 0 {
      power_user_data.can_mint
    } else {
      power_user_data.can_burn
    }?,
    //Mint destinations must be vetted (denylist absence + optional KYC)
    destinations_ok?,
  }
}

/// The CMTAT rationale for the two gates below — and the DELIBERATE DEVIATION
/// permitting a `can_mint` power user to mint to itself without a KYC
/// attestation — is documented at the call site in `withdraw`.
fn verify_mint_destinations(
  outputs: List<Output>,
  actions: List<MintingLogicDestinationAction>,
  seen: List<ByteArray>,
  issuance_policy_id: ByteArray,
  security_asset_name: ByteArray,
  gs_datum: GlobalStateDatum,
  power_user_node_key: ByteArray,
  self: Transaction,
) -> Bool {
  when outputs is {
    [] -> True
    [output, ..rest_outputs] ->
      if quantity_of(output.value, issuance_policy_id, security_asset_name) > 0 {
        // Mints must go to an identifiable owner: the CIP-113 payment
        // credential is the shared PLB script, so the inline STAKE credential
        // is the only identity to vet. An enterprise address traps here.
        expect Some(Inline(stake_cred)) = output.address.stake_credential
        let dest_pkh = when stake_cred is {
          VerificationKey(hash) -> hash
          Script(hash) -> hash
        }
        if list.has(seen, dest_pkh) {
          // Already vetted by an earlier output — consume no action, so the
          // redeemer stays indexed by unique destination rather than by output.
          verify_mint_destinations(
            rest_outputs,
            actions,
            seen,
            issuance_policy_id,
            security_asset_name,
            gs_datum,
            power_user_node_key,
            self,
          )
        } else {
          // Mirrors the old `safe_list_at`: a destination with no matching
          // action traps rather than being waved through.
          expect [action, ..rest_actions] = actions
          and {
            if gs_datum.requires_receiver_kyc {
              or {
                // The receiver is the power user authorising this mint.
                dest_pkh == power_user_node_key,
                // …or a valid KYC proof is presented for the receiver.
                verify_kyc_proof(
                  action.destination_proof,
                  dest_pkh,
                  gs_datum,
                  issuance_policy_id,
                  gs_datum.network_id,
                  self,
                ),
              }
            } else {
              True
            },
            verify_denylist_absence(
              dest_pkh,
              action.destination_denylist_covering_ref_input_index,
              self.reference_inputs,
              gs_datum.denylist_linked_list_policy_id,
            ),
            verify_mint_destinations(
              rest_outputs,
              rest_actions,
              [dest_pkh, ..seen],
              issuance_policy_id,
              security_asset_name,
              gs_datum,
              power_user_node_key,
              self,
            ),
          }
        }
      } else {
        verify_mint_destinations(
          rest_outputs,
          actions,
          seen,
          issuance_policy_id,
          security_asset_name,
          gs_datum,
          power_user_node_key,
          self,
        )
      }
  }
}

// ============================================================================
// Tests — withdraw handler (validator-level)
// ============================================================================
//
// Fixtures follow the aiken-design-patterns linked-list conventions verified
// against the vendored library: an element UTxO carries exactly ADA + one
// list NFT, an inline `Element` datum, and no reference script. The root's
// NFT asset name equals the root key (empty), a node's equals
// "Node" ++ key. The denylist-absence fixtures exercise the real
// covering-node proof through `verify_denylist_absence`.

const test_security_asset_name: ByteArray = "SEC"

const test_gs_policy_id: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const test_pu_policy_id: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const test_registry_policy_id: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const test_denylist_policy_id: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

// Registry node `key` == the issuance policy id the mint must use.
const test_issuance_policy_id: ByteArray =
  #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

const test_minting_logic_hash: ByteArray =
  #"f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1"

const test_transfer_logic_hash: ByteArray =
  #"f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2"

const test_third_party_logic_hash: ByteArray =
  #"f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3"

const test_pu_credential_hash: ByteArray =
  #"01010101010101010101010101010101010101010101010101010101"

const test_dest_stake_hash: ByteArray =
  #"02020202020202020202020202020202020202020202020202020202"

// A second, distinct destination — must sort strictly above the first so the
// empty-denylist root covers both, and so the two are aggregated as separate
// unique destinations (exercising destination_actions index 1).
const test_dest_stake_hash_2: ByteArray =
  #"04040404040404040404040404040404040404040404040404040404"

// The real programmable-token custody address: payment credential is the
// shared CIP-113 programmable-logic-base (PLB) SCRIPT, and the per-owner
// identity is the inline STAKE credential. Fixtures model this shape so a
// test can't silently pass under a broken PLB invariant.
const test_plb_hash: ByteArray =
  #"05050505050505050505050505050505050505050505050505050505"

// Faithful mirror of the CIP-113 registry node layout (field order is
// load-bearing: minting=2, transfer=3, third-party=4).
type TestRegistryNode {
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

fn test_out_ref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

// GS input — NFT presence gates the cap path; the datum now also feeds the
// destination checks (denylist policy id, receiver-KYC toggle, network id).
fn make_gs_input(requires_receiver_kyc: Bool) -> Input {
  let gs_datum = GlobalStateDatum {
    transfers_paused: False,
    deactivated: False,
    mintable_amount: 1_000_000,
    admin_credential_hash: #"",
    power_user_linked_list_policy_id: test_pu_policy_id,
    denylist_linked_list_policy_id: test_denylist_policy_id,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: False,
    requires_receiver_kyc,
    network_id: 1,
  }
  Input {
    output_reference: test_out_ref(0),
    output: Output {
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
    },
  }
}

// Power-user linked-list node: asset name = "Node" ++ credential_hash, datum
// wraps a PowerUser as Node data.
fn make_pu_node_ref_input(can_mint: Bool, can_burn: Bool) -> Input {
  let pu = PowerUser {
    credential_hash: test_pu_credential_hash,
    is_admin: False,
    can_mint,
    can_burn,
    can_pause: False,
    can_force_transfer: False,
  }
  let element: Element<Data, PowerUser> = Element {
    data: Node { data: pu },
    link: None,
  }
  let node_asset_name = bytearray.concat(
    constants.linked_list_node_key_prefix,
    test_pu_credential_hash,
  )
  Input {
    output_reference: test_out_ref(1),
    output: Output {
      address: Address {
        payment_credential: Script(test_pu_policy_id),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_pu_policy_id, node_asset_name, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

// CIP-113 registry node ref input: exactly one registry NFT so
// `has_any_nft_strict` locates it; field 2 must equal the withdraw credential.
fn make_registry_ref_input() -> Input {
  let node = TestRegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_minting_logic_hash),
    transfer_logic_script: Script(test_transfer_logic_hash),
    third_party_transfer_logic_script: Script(test_third_party_logic_hash),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: test_gs_policy_id,
  }
  Input {
    output_reference: test_out_ref(2),
    output: Output {
      address: Address {
        payment_credential: Script(test_registry_policy_id),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_registry_policy_id, "Node", 1),
      ),
      datum: InlineDatum(node),
      reference_script: None,
    },
  }
}

// A registry node belonging to a DIFFERENT programmable token: same registry
// policy (all CIP-113 nodes share it) and a well-formed single NFT, but its
// logic-script fields name other scripts entirely. Models the reference input
// a transaction picks up when it moves a second programmable token alongside
// this one. A lookup that searches on the registry policy alone would resolve
// THIS node instead of the token's own.
fn make_decoy_registry_ref_input() -> Input {
  let node = TestRegistryNode {
    key: #"9999999999999999999999999999999999999999999999999999999999",
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(
      #"aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11",
    ),
    transfer_logic_script: Script(
      #"bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22",
    ),
    third_party_transfer_logic_script: Script(
      #"cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33",
    ),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: #"dd44dd44dd44dd44dd44dd44dd44dd44dd44dd44dd44dd44dd44dd44",
  }
  Input {
    output_reference: test_out_ref(9),
    output: Output {
      address: Address {
        payment_credential: Script(test_registry_policy_id),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_registry_policy_id, "Node", 1),
      ),
      datum: InlineDatum(node),
      reference_script: None,
    },
  }
}

// Denylist ROOT element with an empty list (`link: None`) — the root covers
// every possible key, so it is a valid absence proof for any target.
fn make_denylist_root_ref_input() -> Input {
  let root_info: Data = builtin.constr_data(0, [])
  let element: Element<Data, Data> = Element {
    data: Root { data: root_info },
    link: None,
  }
  Input {
    output_reference: test_out_ref(3),
    output: Output {
      address: Address {
        payment_credential: Script(test_denylist_policy_id),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_denylist_policy_id, constants.linked_list_root_key, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

// Denylist NODE keyed exactly at `pkh` — the target IS denylisted, so this
// node cannot witness its absence (covers_from_below: key < target is
// false when key == target). Models the "destination is sanctioned" case.
fn make_denylist_node_ref_input(pkh: ByteArray) -> Input {
  let node_info: Data = builtin.constr_data(0, [])
  let element: Element<Data, Data> = Element {
    data: Node { data: node_info },
    link: None,
  }
  let node_asset_name = bytearray.concat(
    constants.linked_list_node_key_prefix,
    pkh,
  )
  Input {
    output_reference: test_out_ref(3),
    output: Output {
      address: Address {
        payment_credential: Script(test_denylist_policy_id),
        stake_credential: None,
      },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(test_denylist_policy_id, node_asset_name, 1),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

// Mint destination: a base address whose stake credential is the identity
// the destination checks must vet.
fn make_dest_output(amount: Int) -> Output {
  make_dest_output_for(amount, test_dest_stake_hash)
}

// Same, but parameterised on the destination stake credential — used to build
// a mint with two distinct destinations.
fn make_dest_output_for(amount: Int, stake_hash: ByteArray) -> Output {
  Output {
    // Real programmable-token shape: PLB script payment credential + inline
    // owner stake credential (the identity the destination checks vet).
    address: Address {
      payment_credential: Script(test_plb_hash),
      stake_credential: Some(Inline(VerificationKey(stake_hash))),
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(test_issuance_policy_id, test_security_asset_name, amount),
    ),
    datum: NoDatum,
    reference_script: None,
  }
}

// A token-bearing output with NO stake credential (an enterprise address).
// Used to pin the intentional trap in the destination aggregation.
fn make_enterprise_dest_output(amount: Int) -> Output {
  Output {
    address: Address {
      payment_credential: Script(test_plb_hash),
      stake_credential: None,
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(test_issuance_policy_id, test_security_asset_name, amount),
    ),
    datum: NoDatum,
    reference_script: None,
  }
}

// Reference-input order: 0 = power-user node, 1 = registry node,
// 2 = denylist covering node (the index the destination actions cite).
fn make_withdraw_tx(
  minted_amount: Int,
  can_mint: Bool,
  can_burn: Bool,
  requires_receiver_kyc: Bool,
  denylist_ref: Input,
  outputs: List<Output>,
  signatories: List<ByteArray>,
) -> Transaction {
  Transaction {
    inputs: [make_gs_input(requires_receiver_kyc)],
    reference_inputs: [
      make_pu_node_ref_input(can_mint, can_burn),
      make_registry_ref_input(),
      denylist_ref,
    ],
    outputs,
    fee: 0,
    mint: from_asset(
      test_issuance_policy_id,
      test_security_asset_name,
      minted_amount,
    ),
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

// Same tx, but a decoy registry node for an unrelated programmable token is
// prepended to the reference inputs — the shape produced by moving two
// programmable tokens in one transaction. Reference-input order shifts to
// 0 = decoy registry, 1 = power-user node, 2 = registry node, 3 = denylist.
fn make_withdraw_tx_with_decoy_registry(
  minted_amount: Int,
  outputs: List<Output>,
) -> Transaction {
  let base = make_withdraw_tx(
    minted_amount,
    True,
    False,
    False,
    make_denylist_root_ref_input(),
    outputs,
    [test_pu_credential_hash],
  )
  Transaction {
    ..base,
    reference_inputs: list.push(
      base.reference_inputs,
      make_decoy_registry_ref_input(),
    ),
  }
}

// Structurally invalid KYC proof — only reachable when receiver KYC is
// required, where it must make the destination check fail.
fn dummy_proof() {
  Attestation {
    kyc_proof: AttestationProof {
      payload: #"",
      signature: #"",
      issuer_vkey: #"",
    },
  }
}

fn clean_dest_action() -> MintingLogicDestinationAction {
  MintingLogicDestinationAction {
    destination_proof: dummy_proof(),
    destination_denylist_covering_ref_input_index: 2,
  }
}

fn run_withdraw(redeemer: MintingLogicScriptWithdrawRedeemer, tx: Transaction) {
  minting_logic_validator.withdraw(
    test_security_asset_name,
    test_gs_policy_id,
    test_registry_policy_id,
    test_pu_policy_id,
    redeemer,
    Script(test_minting_logic_hash),
    tx,
  )
}

// ── destination verification ─────────────────────────────────────────────────

test mint_succeeds_with_clean_destination_no_receiver_kyc() {
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [make_dest_output(amount)],
      [test_pu_credential_hash],
    ),
  )
}

test mint_fails_when_destination_denylisted() {
  // The provided covering node is keyed exactly at the destination — i.e.
  // the destination IS in the denylist, so no absence proof exists for it.
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  !run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      False,
      make_denylist_node_ref_input(test_dest_stake_hash),
      [make_dest_output(amount)],
      [test_pu_credential_hash],
    ),
  )
}

test mint_succeeds_with_two_clean_destinations() {
  // Two distinct destinations in one mint. Both are absent from the (empty)
  // denylist, so both need a covering proof at ref index 2. This exercises
  // destination_actions index 0 AND index 1 — a short action list or an
  // index-mapping regression would trap on the second destination.
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action(), clean_dest_action()],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [
        make_dest_output_for(amount, test_dest_stake_hash),
        make_dest_output_for(amount, test_dest_stake_hash_2),
      ],
      [test_pu_credential_hash],
    ),
  )
}

test mint_fails_when_receiver_kyc_required_but_proof_invalid() {
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  !run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      True,
      make_denylist_root_ref_input(),
      [make_dest_output(amount)],
      [test_pu_credential_hash],
    ),
  )
}

test mint_to_authorizing_power_user_bypasses_receiver_kyc() {
  // requires_receiver_kyc = true and only an invalid (dummy) KYC proof is
  // supplied — but the sole destination IS the power user authorizing this
  // mint (dest stake credential == test_pu_credential_hash). The receiver
  // check must pass via the power-user exemption, not via KYC.
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      True,
      make_denylist_root_ref_input(),
      [make_dest_output_for(amount, test_pu_credential_hash)],
      [test_pu_credential_hash],
    ),
  )
}

test mint_fails_when_destination_action_missing() fail {
  // A destination exists but no matching action was supplied — indexing the
  // empty action list must trap.
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [make_dest_output(amount)],
      [test_pu_credential_hash],
    ),
  )
}

test burn_succeeds_without_destination_checks() {
  let amount = -1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      False,
      True,
      False,
      make_denylist_root_ref_input(),
      [],
      [test_pu_credential_hash],
    ),
  )
}

// ── registry-node resolution ─────────────────────────────────────────────────

test mint_succeeds_when_another_tokens_registry_node_sorts_first() {
  // Regression pin for the positional-lookup defect. A second programmable
  // token's registry node precedes this token's in `reference_inputs`, and
  // reference inputs are ledger-sorted by output reference, so off-chain
  // cannot reorder them. Locating the node by "first UTxO holding a registry
  // NFT" resolves the decoy and traps on the identity assertion; naming the
  // index resolves the right node and the mint succeeds.
  let amount = 1_000
  let redeemer = MintBurn {
    // Shifted by one: the decoy occupies index 0.
    registry_node_ref_input_index: 2,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 1,
    minted_amount: amount,
    destination_actions: [
      MintingLogicDestinationAction {
        destination_proof: dummy_proof(),
        destination_denylist_covering_ref_input_index: 3,
      },
    ],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx_with_decoy_registry(amount, [make_dest_output(amount)]),
  )
}

test mint_fails_when_registry_index_points_at_another_tokens_node() fail {
  // The caller-supplied index is not a privilege: pointing it at a genuine
  // registry node that belongs to a different token must still trap on the
  // identity assertion, since that node names another minting logic script.
  let amount = 1_000
  let redeemer = MintBurn {
    // The decoy, not this token's node.
    registry_node_ref_input_index: 0,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 1,
    minted_amount: amount,
    destination_actions: [
      MintingLogicDestinationAction {
        destination_proof: dummy_proof(),
        destination_denylist_covering_ref_input_index: 3,
      },
    ],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx_with_decoy_registry(amount, [make_dest_output(amount)]),
  )
}

test mint_fails_when_registry_index_points_at_a_non_registry_utxo() fail {
  // Index 1 is the power-user linked-list node: an inline-datum UTxO with a
  // single NFT, but of the power-users policy. `has_any_nft_strict` against
  // the registry policy must reject it rather than decoding its datum as a
  // registry node.
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 0,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [make_dest_output(amount)],
      [test_pu_credential_hash],
    ),
  )
}

// ── CIP-113 registration (RegisterToken) ─────────────────────────────────────
//
// Models a real `registry_mint` RegistryInsert: the covering node is spent,
// TWO registry-node outputs are produced (the re-emitted covering node at
// index 0 and this token's new node at index 1), exactly one registry node
// NFT is minted, and GlobalState is a reference input carrying the admin
// credential that authorises the registration.

const test_admin_hash: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"

// A previously-registered token's node — the one this insert splits.
const test_covering_minting_hash: ByteArray =
  #"0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"

fn make_registry_node_output(
  key: ByteArray,
  minting_logic_hash: ByteArray,
  unfracking: Credential,
  global_state_cs: ByteArray,
) -> Output {
  let node = TestRegistryNode {
    key,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(minting_logic_hash),
    transfer_logic_script: Script(test_transfer_logic_hash),
    third_party_transfer_logic_script: Script(test_third_party_logic_hash),
    unfracking_logic_script: unfracking,
    global_state_cs,
  }
  Output {
    address: Address {
      payment_credential: Script(test_registry_policy_id),
      stake_credential: None,
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(test_registry_policy_id, "Node", 1),
    ),
    datum: InlineDatum(node),
    reference_script: None,
  }
}

// The well-formed node for THIS token: names this minting logic, unfracking
// left unset (forbidden), and points at this deployment's GlobalState.
fn make_own_registry_node_output() -> Output {
  make_registry_node_output(
    test_issuance_policy_id,
    test_minting_logic_hash,
    VerificationKey(#""),
    test_gs_policy_id,
  )
}

fn make_gs_registration_ref_input() -> Input {
  let base = make_gs_input(False)
  expect InlineDatum(raw) = base.output.datum
  expect gs_datum: GlobalStateDatum = raw
  Input {
    output_reference: test_out_ref(5),
    output: Output {
      ..base.output,
      datum: InlineDatum(
        GlobalStateDatum { ..gs_datum, admin_credential_hash: test_admin_hash },
      ),
    },
  }
}

fn make_registration_tx(
  new_node: Output,
  mint: Value,
  signatories: List<ByteArray>,
) -> Transaction {
  let base = make_withdraw_tx(
    0,
    True,
    False,
    False,
    make_denylist_root_ref_input(),
    [],
    [],
  )
  Transaction {
    ..base,
    inputs: [
      Input {
        output_reference: test_out_ref(6),
        output: make_registry_node_output(
          #"1111111111111111111111111111111111111111111111111111111111",
          test_covering_minting_hash,
          VerificationKey(#""),
          test_gs_policy_id,
        ),
      },
    ],
    reference_inputs: [make_gs_registration_ref_input()],
    outputs: [
      // 0: the re-emitted covering node (belongs to another token)
      make_registry_node_output(
        #"1111111111111111111111111111111111111111111111111111111111",
        test_covering_minting_hash,
        VerificationKey(#""),
        test_gs_policy_id,
      ),
      // 1: this token's new node
      new_node,
    ],
    mint,
    extra_signatories: signatories,
  }
}

fn one_registry_nft() -> Value {
  from_asset(test_registry_policy_id, "Node", 1)
}

fn register_redeemer() -> MintingLogicScriptWithdrawRedeemer {
  register_redeemer_at(1)
}

// Structural registration (no first mint): GS is REFERENCED at index 0, so the
// spend/power-user indices are unused.
fn register_redeemer_at(node_index: Int) -> MintingLogicScriptWithdrawRedeemer {
  RegisterToken {
    registry_node_output_index: node_index,
    global_state_ref_input_index: 0,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: 0,
    destination_actions: [],
  }
}

test registration_succeeds_when_admin_signs() {
  run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_own_registry_node_output(),
      one_registry_nft(),
      [test_admin_hash],
    ),
  )
}

test registration_fails_without_admin_signature() {
  // The registration is otherwise perfect. Without this gate anyone could
  // register the token naming a permissive transfer logic — CIP-113 binds
  // only `minting_logic_script` to the policy id, not the other fields.
  !run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_own_registry_node_output(),
      one_registry_nft(),
      [test_pu_credential_hash],
    ),
  )
}

test registration_fails_when_node_names_another_minting_logic() fail {
  // Identity gate: this validator must only authorise ITS OWN node.
  run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_registry_node_output(
        test_issuance_policy_id,
        test_covering_minting_hash,
        VerificationKey(#""),
        test_gs_policy_id,
      ),
      one_registry_nft(),
      [test_admin_hash],
    ),
  )
}

test registration_fails_when_index_points_at_the_covering_node() fail {
  // An insert emits two registry-node outputs. Index 0 is the re-emitted
  // covering node, which belongs to a different token — the identity gate
  // must reject it rather than rubber-stamping whatever the index names.
  run_withdraw(
    register_redeemer_at(0),
    make_registration_tx(
      make_own_registry_node_output(),
      one_registry_nft(),
      [test_admin_hash],
    ),
  )
}

test registration_fails_when_unfracking_hook_is_set() fail {
  // Unfracking lets a holder split this policy out of a shared UTxO WITHOUT
  // the transfer logic running. Registering a live hook would open that
  // bypass permanently, so the node must keep core's least-permission value.
  run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_registry_node_output(
        test_issuance_policy_id,
        test_minting_logic_hash,
        Script(#"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"),
        test_gs_policy_id,
      ),
      one_registry_nft(),
      [test_admin_hash],
    ),
  )
}

test registration_fails_when_global_state_cs_mismatches() fail {
  // Nothing in CIP-113 binds `global_state_cs`; a node pointing at a foreign
  // GlobalState would mislead the base layer and every other integrator.
  run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_registry_node_output(
        test_issuance_policy_id,
        test_minting_logic_hash,
        VerificationKey(#""),
        #"9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c9c",
      ),
      one_registry_nft(),
      [test_admin_hash],
    ),
  )
}

test registration_fails_when_mint_present_but_redeemer_says_structural() fail {
  // The redeemer claims `minted_amount: 0` while the tx mints 1000. The
  // structural path must not be reachable with a live mint — it resolves GS as
  // a REFERENCE input and never runs a power-user or receiver check.
  run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_own_registry_node_output(),
      merge(
        one_registry_nft(),
        from_asset(test_issuance_policy_id, test_security_asset_name, 1_000),
      ),
      [test_admin_hash],
    ),
  )
}

// ── registration carrying the first mint ─────────────────────────────────────
//
// CIP-113 supports register+mint in one transaction (`issuance_mint`'s
// `OutputIndex` proof explicitly covers "a genuine first mint"), and it checks
// only that the node is genuine and that no token escapes the PLB. Every mint
// condition is therefore this validator's responsibility, so this shape runs
// the admin gate AND the full `MintBurn` checks.
//
// inputs:           0 = GlobalState (SPENT -> MintSecurity enforces the cap)
//                   1 = covering registry node
// reference_inputs: 0 = power-user node, 1 = denylist root
// outputs:          0 = re-emitted covering node, 1 = this token's new node,
//                   2 = the mint destination

fn make_registration_mint_tx(
  amount: Int,
  can_mint: Bool,
  signatories: List<ByteArray>,
) -> Transaction {
  let base = make_registration_tx(
    make_own_registry_node_output(),
    merge(
      one_registry_nft(),
      from_asset(test_issuance_policy_id, test_security_asset_name, amount),
    ),
    signatories,
  )
  Transaction {
    ..base,
    inputs: list.push(base.inputs, make_gs_registration_ref_input()),
    reference_inputs: [
      make_pu_node_ref_input(can_mint, False),
      make_denylist_root_ref_input(),
    ],
    outputs: list.concat(base.outputs, [make_dest_output(amount)]),
  }
}

fn register_and_mint_redeemer(amount: Int) -> MintingLogicScriptWithdrawRedeemer {
  RegisterToken {
    registry_node_output_index: 1,
    global_state_ref_input_index: 0,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [
      MintingLogicDestinationAction {
        destination_proof: dummy_proof(),
        destination_denylist_covering_ref_input_index: 1,
      },
    ],
  }
}

test registration_with_first_mint_succeeds() {
  run_withdraw(
    register_and_mint_redeemer(1_000),
    make_registration_mint_tx(
      1_000,
      True,
      [test_admin_hash, test_pu_credential_hash],
    ),
  )
}

test registration_with_first_mint_fails_without_admin_signature() {
  // The power user alone cannot register — the registration half still needs
  // the admin, since the node's transfer-logic fields are unbound.
  !run_withdraw(
    register_and_mint_redeemer(1_000),
    make_registration_mint_tx(1_000, True, [test_pu_credential_hash]),
  )
}

test registration_with_first_mint_fails_without_power_user_signature() {
  // The admin alone cannot mint — the mint half is gated exactly like any
  // later mint, so a genesis mint is auditable on the same terms.
  !run_withdraw(
    register_and_mint_redeemer(1_000),
    make_registration_mint_tx(1_000, True, [test_admin_hash]),
  )
}

test registration_with_first_mint_fails_when_power_user_cannot_mint() {
  !run_withdraw(
    register_and_mint_redeemer(1_000),
    make_registration_mint_tx(
      1_000,
      False,
      [test_admin_hash, test_pu_credential_hash],
    ),
  )
}

test registration_with_first_mint_fails_when_amount_disagrees() {
  !run_withdraw(
    register_and_mint_redeemer(999),
    make_registration_mint_tx(
      1_000,
      True,
      [test_admin_hash, test_pu_credential_hash],
    ),
  )
}

test registration_with_first_mint_fails_when_gs_is_not_spent() fail {
  // GS must be SPENT so `MintSecurity` decrements the cap. Pointing
  // `global_state_input_index` at the covering registry node instead must trap
  // rather than mint uncapped.
  run_withdraw(
    RegisterToken {
      registry_node_output_index: 1,
      global_state_ref_input_index: 0,
      // input 1 is the covering registry node, not GlobalState
      global_state_input_index: 1,
      power_user_node_ref_input_index: 0,
      minted_amount: 1_000,
      destination_actions: [
        MintingLogicDestinationAction {
          destination_proof: dummy_proof(),
          destination_denylist_covering_ref_input_index: 1,
        },
      ],
    },
    make_registration_mint_tx(
      1_000,
      True,
      [test_admin_hash, test_pu_credential_hash],
    ),
  )
}

test registration_fails_when_security_token_is_burned() fail {
  // Nothing exists to burn before registration — `issuance_mint` needs a
  // registry-node proof, so no supply can predate this transaction. Without
  // the `minted_amount >= 0` guard a negative mint would fall into the mint
  // branch and be waved through as an ordinary `can_burn` operation, so the
  // power user here deliberately HOLDS can_burn.
  let base = make_registration_tx(
    make_own_registry_node_output(),
    merge(
      one_registry_nft(),
      from_asset(test_issuance_policy_id, test_security_asset_name, -1_000),
    ),
    [test_admin_hash, test_pu_credential_hash],
  )
  run_withdraw(
    RegisterToken {
      registry_node_output_index: 1,
      global_state_ref_input_index: 0,
      global_state_input_index: 0,
      power_user_node_ref_input_index: 0,
      minted_amount: -1_000,
      destination_actions: [],
    },
    Transaction {
      ..base,
      inputs: list.push(base.inputs, make_gs_registration_ref_input()),
      reference_inputs: [
        make_pu_node_ref_input(False, True),
        make_denylist_root_ref_input(),
      ],
    },
  )
}

test registration_with_first_mint_fails_when_second_asset_name_present() fail {
  // An otherwise-valid register+mint that ALSO burns another asset name under
  // the issuance policy. Everything the mint branch checks still passes — the
  // security-asset quantity matches the redeemer — so only the asset-name
  // shape check stands between this and a silent second-asset emission.
  let base = make_registration_mint_tx(
    1_000,
    True,
    [test_admin_hash, test_pu_credential_hash],
  )
  run_withdraw(
    register_and_mint_redeemer(1_000),
    Transaction {
      ..base,
      mint: merge(
        base.mint,
        from_asset(test_issuance_policy_id, "OTHER", -1_000),
      ),
    },
  )
}

test registration_with_first_mint_fails_when_destination_denylisted() {
  // The receiver gates apply to the genesis mint too.
  let base = make_registration_mint_tx(
    1_000,
    True,
    [test_admin_hash, test_pu_credential_hash],
  )
  !run_withdraw(
    register_and_mint_redeemer(1_000),
    Transaction {
      ..base,
      reference_inputs: [
        make_pu_node_ref_input(True, False),
        make_denylist_node_ref_input(test_dest_stake_hash),
      ],
    },
  )
}

test registration_fails_when_security_token_mint_is_netted_to_zero() fail {
  // The evasion a summing guard would miss: +1000 of the security asset and
  // −1000 of a second asset name under the SAME issuance policy sum to zero,
  // so a `quantity_of_policy_id(...) == 0` test would wave it through and mint
  // 1000 tokens with no cap check, no `can_mint` check and no receiver gates.
  run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_own_registry_node_output(),
      merge(
        one_registry_nft(),
        merge(
          from_asset(test_issuance_policy_id, test_security_asset_name, 1_000),
          from_asset(test_issuance_policy_id, "OTHER", -1_000),
        ),
      ),
      [test_admin_hash],
    ),
  )
}

test registration_rejects_the_in_place_node_update_path() fail {
  // `registry_spend`'s update path mints no registry NFT and also demands
  // this withdraw-0. It can re-point `transfer_logic_script`, and this
  // validator is its only gate, so it stays rejected pending a deliberate
  // authorisation design. Pins that decision.
  run_withdraw(
    register_redeemer(),
    make_registration_tx(
      make_own_registry_node_output(),
      from_lovelace(0),
      [test_admin_hash],
    ),
  )
}

// ── publish handler ──────────────────────────────────────────────────────────

test publish_accepts_credential_registration() {
  minting_logic_validator.publish(
    test_security_asset_name,
    test_gs_policy_id,
    test_registry_policy_id,
    test_pu_policy_id,
    builtin.constr_data(0, []),
    RegisterCredential {
      credential: Script(test_minting_logic_hash),
      deposit: Never,
    },
    make_withdraw_tx(
      0,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [],
      [],
    ),
  )
}

test publish_rejects_credential_deregistration() {
  // Pins the anti-griefing rule the handler documents: a rubber-stamp publish
  // would let anyone de-register this script's stake credential for ~2 ADA,
  // bricking every withdraw-0 mint and burn until it was re-registered.
  !minting_logic_validator.publish(
    test_security_asset_name,
    test_gs_policy_id,
    test_registry_policy_id,
    test_pu_policy_id,
    builtin.constr_data(0, []),
    UnregisterCredential {
      credential: Script(test_minting_logic_hash),
      refund: Never,
    },
    make_withdraw_tx(
      0,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [],
      [],
    ),
  )
}

// ── pre-existing behavior pins ───────────────────────────────────────────────

test withdraw_fails_when_not_signed_by_power_user() {
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  !run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [make_dest_output(amount)],
      [],
    ),
  )
}

test withdraw_fails_when_minting_without_mint_permission() {
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  !run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      False,
      True,
      False,
      make_denylist_root_ref_input(),
      [make_dest_output(amount)],
      [test_pu_credential_hash],
    ),
  )
}

test mint_to_enterprise_address_is_rejected() fail {
  // A token-bearing mint output with no stake credential (enterprise address)
  // must trap the destination aggregation (`expect Some(Inline(stake_cred))`).
  // Pins the intentional "mints must go to an identifiable owner" behavior.
  let amount = 1_000
  let redeemer = MintBurn {
    registry_node_ref_input_index: 1,
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  run_withdraw(
    redeemer,
    make_withdraw_tx(
      amount,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [make_enterprise_dest_output(amount)],
      [test_pu_credential_hash],
    ),
  )
}

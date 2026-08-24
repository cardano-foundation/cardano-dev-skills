use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{get_element_info, run_element_with}
use cardano/address.{Address, Script}
use cardano/assets.{
  PolicyId, Value, from_asset, from_lovelace, merge, quantity_of,
  without_lovelace, zero,
}
use cardano/transaction.{
  InlineDatum, Input, Mint, Output, OutputReference, Transaction, find_input,
}
use constants
use types/global_state.{
  AddTrustedEntity, DeactivateContract, GlobalStateDatum,
  GlobalStateSpendRedeemer, MintSecurity, ModifySecurityInfo, PauseTransfers,
  RemoveTrustedEntity, RotateAdmin, SetRequiresReceiverKyc, SetRequiresSenderKyc,
  TrustedEntityMetadata, UpdateMemberRootHash, UpdateTrustedEntity,
  set_admin_credential_hash, set_deactivated, set_member_root_hash,
  set_mintable_amount, set_requires_receiver_kyc, set_requires_sender_kyc,
  set_security_info, set_transfers_paused, set_trusted_entity_vkeys,
}
use types/power_users.{PowerUser}
use utils.{must_be_signed_by_credential, quantity_of_policy_id}

// ============================================================================
// Sanitisation helpers (used by mint validator at genesis)
// ============================================================================

fn walk_strictly_ascending(
  prev: ByteArray,
  rest: Pairs<ByteArray, TrustedEntityMetadata>,
) -> Bool {
  when rest is {
    [] -> True
    [head, ..tail] -> {
      let k = head.1st
      and {
        bytearray.length(k) == 32,
        builtin.less_than_bytearray(prev, k),
        walk_strictly_ascending(k, tail),
      }
    }
  }
}

fn is_sorted_no_dup_vkeys(
  entries: Pairs<ByteArray, TrustedEntityMetadata>,
) -> Bool {
  when entries is {
    [] -> True
    [head, ..tail] -> {
      let k = head.1st
      and {
        bytearray.length(k) == 32,
        walk_strictly_ascending(k, tail),
      }
    }
  }
}

fn sanitise_initial_datum(datum: GlobalStateDatum, self_mint: Value) -> Bool {
  let root_len = bytearray.length(datum.member_root_hash)
  and {
    !datum.transfers_paused,
    // A born-deactivated protocol would be permanently unspendable at genesis.
    !datum.deactivated,
    datum.mintable_amount >= 0,
    bytearray.length(datum.admin_credential_hash) == 28,
    // network_id is IMMUTABLE and must fit the 1-byte field encoded into every
    // KYC-attestation payload (0–255). An out-of-range value would silently and
    // permanently disable attestation-based transfers.
    datum.network_id >= 0,
    datum.network_id <= 255,
    // member_root_hash must be empty (no membership tree yet) or a 32-byte
    // blake2b-256 digest; any other length makes `mpf.from_root` trap on every
    // membership-proof transfer.
    or {
      root_len == 0,
      root_len == 32,
    },
    // power_users LL root and denylist LL root must be minted in this tx
    quantity_of_policy_id(self_mint, datum.power_user_linked_list_policy_id) >= 1,
    quantity_of_policy_id(self_mint, datum.denylist_linked_list_policy_id) >= 1,
    is_sorted_no_dup_vkeys(datum.trusted_entity_vkeys),
  }
}

// ============================================================================
// Mint validator
// ============================================================================
// Only used at genesis to mint the global_state NFT with the initial datum. 
// Verifies the following:
// - The one-and-only global_state NFT is being minted, and goes to the output.
// - The initial datum is well-formed (basic field checks + trusted entity vkey list is sorted and has no duplicates + power user ll and denylist ll roots are minted).
// Note: No Check of the receiver address is performed here; the NFT can be sent to any address. 
//       It MUST be sent to the address of the global_state spend validator address, which we don't know on initialization due to circular dependency.
//       The global_state spend validator will ensure that the NFT never leaves the script address after this initial minting step.
validator global_state_mint_validator(tx0: ByteArray, index0: Int) {
  mint(_redeemer: Data, policy_id: PolicyId, self: Transaction) {
    let one_time_utxo = OutputReference(tx0, index0)
    //we won't use input_present, we just need it to be there, otherwise error
    expect Some(_input_present) = find_input(self.inputs, one_time_utxo)

    let output_parameters = list.expect_find(
      self.outputs,
      fn(output) {
        assets.has_nft_strict(
          output.value,
          policy_id,
          constants.global_state_asset_name,
        )
      },
    )

    expect InlineDatum(output_datum_raw) = output_parameters.datum
    expect output_datum: GlobalStateDatum = output_datum_raw

    and {
      // No other asset names under this policy are minted alongside the NFT.
      quantity_of_policy_id(self.mint, policy_id) == 1,
      // Exactly one global_state NFT is minted.
      quantity_of(self.mint, policy_id, constants.global_state_asset_name) == 1,
      //Initial datum is well-formed (sort, no duplicates, correct field widths,
      //LL root NFTs also minted in this tx).
      sanitise_initial_datum(output_datum, self.mint),
    }
  }

  else(_) {
    fail
  }
}

// ============================================================================
// Spend validator
// ============================================================================
// NOTE: All values in the utxo must be preserved by this validator.
// INVARIANT: the global_state NFT must never leave this script address.
// Every branch below preserves `global_state_output.address.payment_credential
// == own_input.output.address.payment_credential`. If you add a new branch, you
// MUST preserve this — it's what `minting_logic_script` relies on to prove that
// NFT-in-output implies this spend validator ran.
//
// INVARIANT: non-Mint branches MUST reject concurrent security-token mints.
// Together with the minting_logic_script input-branch check, this is what
// makes `mintable_amount` a truly binding supply cap: the only way to mint a
// security token in steady state is through MintSecurity, which decrements
// `mintable_amount`.
//
// ADMIN: admin credential hash now lives in the input datum (field
// `admin_credential_hash`). No compile-time owner parameter. Rotation via the
// `RotateAdmin` action requires dual signature (old + new).
validator global_state_spend_validator(
  security_asset_name: ByteArray,
  issuance_policy_id: ByteArray,
  global_state_policy_id: ByteArray,
) {
  spend(
    datum_opt: Option<GlobalStateDatum>,
    redeemer: GlobalStateSpendRedeemer,
    input_out_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(input_datum) = datum_opt
    expect Some(own_input) = find_input(self.inputs, input_out_ref)

    // TERMINAL GUARD (irreversibility): once `deactivated` is set, the
    // global_state UTxO can never be spent again — every action is rejected
    // here, before the branch dispatch, so no branch can ever unset the flag.
    // Deactivation is a permanent, fully-frozen tombstone: minting dies
    // (MintSecurity can no longer run) and transfers stay frozen (pause can no
    // longer be lifted).
    //
    // The CMTA functional spec permits deactivation with the existing tokens
    // either *cancelled* (burned first) OR *immobilised* (frozen in place) — the
    // latter is what an insolvency freeze needs: state preserved exactly as-is
    // with no further token-level updates. This validator supports both: it
    // does NOT require supply to be zero at deactivation, so the operator may
    // burn down beforehand or immobilise as-is. It only guarantees the state is
    // final afterwards.
    expect !input_datum.deactivated

    let global_state_output = utils.safe_list_at(
      self.outputs,
      redeemer.global_state_output_index,
    )
    expect InlineDatum(global_state_output_datum) = global_state_output.datum

    // Raw Data field list of the (already validated) input datum. Each branch
    // proves the output datum equals this with exactly one field replaced,
    // sharing every unchanged field as opaque Data — no unwrap/rewrap, and no
    // full-datum re-validation of the output.
    let input_datum_data: Data = input_datum
    let input_fields = builtin.unconstr_fields(input_datum_data)

    // All branches share these address/NFT preservation invariants.
    let address_preserved = global_state_output.address == own_input.output.address
    // ensuring the nft is preserved is what enforces that the same global state UTxO is carried forward after the spend.
    let nft_preserved = quantity_of(
      global_state_output.value,
      global_state_policy_id,
      constants.global_state_asset_name,
    ) == 1
    // ensuring the token amount in the Utxo is preserverd - excluding lovelace
    let value_preserved = without_lovelace(own_input.output.value) == without_lovelace(
      global_state_output.value,
    )

    // Non-MintSecurity branches reject concurrent security mint (preserves
    // supply-cap integrity across all non-cap-aware admin flows).
    let no_concurrent_security_mint = quantity_of(
      self.mint,
      issuance_policy_id,
      security_asset_name,
    ) == 0

    when redeemer.action is {
      MintSecurity { issuance_policy_redeemer_index } -> {
        //issuance_logic.mint validator must be called
        let issuance_policy_redeemer = utils.safe_list_at(
          self.redeemers,
          issuance_policy_redeemer_index,
        )
        expect issuance_policy_redeemer.1st == Mint(issuance_policy_id)
        let minted_amount = quantity_of(
          self.mint,
          issuance_policy_id,
          security_asset_name,
        )
        let remaining_amount = input_datum.mintable_amount - minted_amount
        let expected_output_datum = set_mintable_amount(
          input_fields,
          remaining_amount,
        )
        and {
          //Remaining amount must NOT be negative
          remaining_amount >= 0,
          address_preserved,
          nft_preserved,
          value_preserved,
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      PauseTransfers { transfers_paused, power_user_node_ref_input_index } -> {
        let power_user_node_ref_input = utils.safe_list_at(
          self.reference_inputs,
          power_user_node_ref_input_index,
        )

        let (power_user_credential_hash, power_user_data) = get_element_info(
          power_user_node_ref_input.output,
          fn(_lovelace, node_key, data, _link) {
            expect Some(key) = node_key
            expect power_user_data: PowerUser = data
            (key, power_user_data)
          },
        )
          |> run_element_with(
              input_datum.power_user_linked_list_policy_id,
              constants.linked_list_root_key,
              constants.linked_list_node_key_prefix,
              constants.linked_list_node_key_prefix_length,
            )

        let expected_output_datum = set_transfers_paused(
          input_fields,
          transfers_paused,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          //Must have permission to pause/unpause transfers
          power_user_data.can_pause,
          //Must be signed by the power user
          must_be_signed_by_credential(self, power_user_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      ModifySecurityInfo { new_security_info } -> {
        let expected_output_datum = set_security_info(
          input_fields,
          new_security_info,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          //Must be signed by the current admin (from input datum)
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      AddTrustedEntity { vkey, metadata } -> {
        // Reject duplicate entry, insert in sorted order
        let has_key = pairs.has_key(input_datum.trusted_entity_vkeys, vkey)
        let updated_entities = pairs.insert_by_ascending_key(
          input_datum.trusted_entity_vkeys,
          vkey,
          metadata,
          bytearray.compare,
        )
        let expected_output_datum = set_trusted_entity_vkeys(
          input_fields,
          updated_entities,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          bytearray.length(vkey) == 32,
          !has_key,
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      RemoveTrustedEntity { vkey } -> {
        let has_key = pairs.has_key(input_datum.trusted_entity_vkeys, vkey)
        let updated_entities = list.filter(
          input_datum.trusted_entity_vkeys,
          fn(p) { p.1st != vkey },
        )
        let expected_output_datum = set_trusted_entity_vkeys(
          input_fields,
          updated_entities,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          has_key,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      UpdateTrustedEntity { old_vkey, new_vkey, new_metadata } -> {
        let old_exists = pairs.has_key(
          input_datum.trusted_entity_vkeys,
          old_vkey,
        )
        // If renaming (old_vkey != new_vkey), new_vkey must not exist yet.
        // If just updating metadata (old_vkey == new_vkey), this constraint
        // trivially passes — `new_exists_check` becomes True.
        let new_clash_ok = if old_vkey == new_vkey {
          True
        } else {
          !pairs.has_key(input_datum.trusted_entity_vkeys, new_vkey)
        }
        let without_old = list.filter(
          input_datum.trusted_entity_vkeys,
          fn(p) { p.1st != old_vkey },
        )
        let updated_entities = pairs.insert_by_ascending_key(
          without_old,
          new_vkey,
          new_metadata,
          bytearray.compare,
        )
        let expected_output_datum = set_trusted_entity_vkeys(
          input_fields,
          updated_entities,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          old_exists,
          new_clash_ok,
          bytearray.length(new_vkey) == 32,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      SetRequiresSenderKyc { enabled } -> {
        let expected_output_datum = set_requires_sender_kyc(
          input_fields,
          enabled,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      SetRequiresReceiverKyc { enabled } -> {
        let expected_output_datum = set_requires_receiver_kyc(
          input_fields,
          enabled,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      UpdateMemberRootHash { new_member_root_hash } -> {
        let expected_output_datum = set_member_root_hash(
          input_fields,
          new_member_root_hash,
        )
        let new_root_len = bytearray.length(new_member_root_hash)
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          // Keep the membership root well-formed: empty or a 32-byte digest;
          // any other length makes `mpf.from_root` trap on every transfer.
          or {
            new_root_len == 0,
            new_root_len == 32,
          },
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      RotateAdmin { new_admin_credential_hash } -> {
        let expected_output_datum = set_admin_credential_hash(
          input_fields,
          new_admin_credential_hash,
        )
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          bytearray.length(new_admin_credential_hash) == 28,
          //Dual-sig: both old (from input datum) and new admins must sign.
          //Prevents silent takeover; prevents lost-key soft-brick by
          //forcing continuity.
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          must_be_signed_by_credential(self, new_admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      DeactivateContract -> {
        let expected_output_datum = set_deactivated(input_fields, True)
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          //Can only deactivate from a paused state (mirrors CMTAT
          //`deactivateContract`, which requires the contract be paused first).
          input_datum.transfers_paused,
          //Admin must authorise the (irreversible) decommissioning.
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          //Output flips exactly one field: deactivated -> True.
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
    }
  }

  else(_) {
    fail
  }
}

// ============================================================================
// Tests — spend validator, DeactivateContract action + terminal irreversibility
// ============================================================================

const t_gs_policy: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const t_issuance_policy: ByteArray =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const t_admin: ByteArray =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const t_gs_script_hash: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const t_sec_name: ByteArray = "SEC"

fn t_out_ref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

fn t_datum(transfers_paused: Bool, deactivated: Bool) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused,
    deactivated,
    mintable_amount: 1_000_000,
    admin_credential_hash: t_admin,
    power_user_linked_list_policy_id: #"",
    denylist_linked_list_policy_id: #"",
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash: #"",
    requires_sender_kyc: False,
    requires_receiver_kyc: False,
    network_id: 1,
  }
}

fn t_gs_value() -> Value {
  merge(
    from_lovelace(2_000_000),
    from_asset(t_gs_policy, constants.global_state_asset_name, 1),
  )
}

fn t_input(datum: GlobalStateDatum) -> Input {
  Input {
    output_reference: t_out_ref(0),
    output: Output {
      address: Address {
        payment_credential: Script(t_gs_script_hash),
        stake_credential: None,
      },
      value: t_gs_value(),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

fn t_output(datum: GlobalStateDatum) -> Output {
  Output {
    address: Address {
      payment_credential: Script(t_gs_script_hash),
      stake_credential: None,
    },
    value: t_gs_value(),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

fn t_tx(
  input_datum: GlobalStateDatum,
  output_datum: GlobalStateDatum,
  signatories: List<ByteArray>,
) -> Transaction {
  Transaction {
    inputs: [t_input(input_datum)],
    reference_inputs: [],
    outputs: [t_output(output_datum)],
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

fn deactivate_redeemer() -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    config_ref_input_index: 0,
    global_state_output_index: 0,
    action: DeactivateContract,
  }
}

fn run_spend(
  input_datum: GlobalStateDatum,
  redeemer: GlobalStateSpendRedeemer,
  tx: Transaction,
) -> Bool {
  global_state_spend_validator.spend(
    t_sec_name,
    t_issuance_policy,
    t_gs_policy,
    Some(input_datum),
    redeemer,
    t_out_ref(0),
    tx,
  )
}

// ── DeactivateContract — success + guard on preconditions ────────────────────

test deactivate_succeeds_when_paused_and_admin_signs() {
  let input_datum = t_datum(True, False)
  let output_datum = GlobalStateDatum { ..input_datum, deactivated: True }
  run_spend(
    input_datum,
    deactivate_redeemer(),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test deactivate_fails_when_not_paused() {
  // transfers_paused == False → the paused precondition rejects.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum { ..input_datum, deactivated: True }
  !run_spend(
    input_datum,
    deactivate_redeemer(),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test deactivate_fails_without_admin_signature() {
  let input_datum = t_datum(True, False)
  let output_datum = GlobalStateDatum { ..input_datum, deactivated: True }
  !run_spend(
    input_datum,
    deactivate_redeemer(),
    t_tx(input_datum, output_datum, []),
  )
}

test deactivate_fails_when_output_not_marked_deactivated() {
  // Output keeps deactivated == False → the expected-datum equality fails.
  let input_datum = t_datum(True, False)
  let output_datum = input_datum
  !run_spend(
    input_datum,
    deactivate_redeemer(),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── Terminal irreversibility — a deactivated GS UTxO cannot be spent at all ──

test deactivated_input_rejects_further_deactivate() fail {
  // Already deactivated → the top-level terminal guard traps.
  let input_datum = t_datum(True, True)
  let output_datum = input_datum
  run_spend(
    input_datum,
    deactivate_redeemer(),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test deactivated_input_rejects_modify_security_info() fail {
  // A normally-valid ModifySecurityInfo on a deactivated GS must still be
  // rejected by the terminal guard (proves the guard blocks all non-burn
  // actions, not just DeactivateContract). Without the guard this succeeds.
  let input_datum = t_datum(True, True)
  let new_info: Data = builtin.constr_data(0, [builtin.i_data(7)])
  let input_fields = builtin.unconstr_fields(input_datum)
  expect output_datum: GlobalStateDatum = set_security_info(
    input_fields,
    new_info,
  )
  let redeemer = GlobalStateSpendRedeemer {
    config_ref_input_index: 0,
    global_state_output_index: 0,
    action: ModifySecurityInfo { new_security_info: new_info },
  }
  run_spend(input_datum, redeemer, t_tx(input_datum, output_datum, [t_admin]))
}

// ── Post-deactivation: burns allowed, mints rejected ────────────────────────

// A MintSecurity transaction: `mint_delta` of the security token (negative =
// burn, positive = mint) plus the issuance-policy Mint redeemer the branch
// requires, on top of the shared GS input/output.
fn t_mintsecurity_tx(
  input_datum: GlobalStateDatum,
  output_datum: GlobalStateDatum,
  mint_delta: Int,
  signatories: List<ByteArray>,
) -> Transaction {
  Transaction {
    ..t_tx(input_datum, output_datum, signatories),
    mint: from_asset(t_issuance_policy, t_sec_name, mint_delta),
    redeemers: [Pair(Mint(t_issuance_policy), builtin.constr_data(0, []))],
  }
}

fn mintsecurity_redeemer() -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    config_ref_input_index: 0,
    global_state_output_index: 0,
    action: MintSecurity { issuance_policy_redeemer_index: 0 },
  }
}

test deactivated_input_rejects_burn() fail {
  // Deactivation is fully terminal: even a burn (negative security-mint) is
  // rejected by the terminal guard — no token-level update of any kind after
  // deactivation, so an immobilised (frozen-as-is) state stays exactly as-is.
  let input_datum = t_datum(True, True)
  let burn = -100
  let output_datum = GlobalStateDatum {
    ..input_datum,
    mintable_amount: input_datum.mintable_amount - burn,
  }
  run_spend(
    input_datum,
    mintsecurity_redeemer(),
    t_mintsecurity_tx(input_datum, output_datum, burn, [t_admin]),
  )
}

test deactivated_input_rejects_mint() fail {
  // No minting after deactivation — a positive security-mint on a deactivated
  // GS is rejected by the terminal guard (traps).
  let input_datum = t_datum(True, True)
  let mint = 100
  let output_datum = GlobalStateDatum {
    ..input_datum,
    mintable_amount: input_datum.mintable_amount - mint,
  }
  run_spend(
    input_datum,
    mintsecurity_redeemer(),
    t_mintsecurity_tx(input_datum, output_datum, mint, [t_admin]),
  )
}

test live_contract_still_allows_mint() {
  // Sanity: a normal (non-deactivated) mint still works — the burn-only guard
  // only bites once deactivated.
  let input_datum = t_datum(False, False)
  let mint = 100
  let output_datum = GlobalStateDatum {
    ..input_datum,
    mintable_amount: input_datum.mintable_amount - mint,
  }
  run_spend(
    input_datum,
    mintsecurity_redeemer(),
    t_mintsecurity_tx(input_datum, output_datum, mint, [t_admin]),
  )
}

// ── F-18: genesis KYC-config validation ─────────────────────────────────────

const t_pu_ll_policy: ByteArray =
  #"11111111111111111111111111111111111111111111111111111111"

const t_dl_ll_policy: ByteArray =
  #"22222222222222222222222222222222222222222222222222222222"

const t_root32: ByteArray =
  #"3333333333333333333333333333333333333333333333333333333333333333"

fn sanitise_datum(
  member_root_hash: ByteArray,
  network_id: Int,
) -> GlobalStateDatum {
  GlobalStateDatum {
    transfers_paused: False,
    deactivated: False,
    mintable_amount: 1_000,
    admin_credential_hash: t_admin,
    power_user_linked_list_policy_id: t_pu_ll_policy,
    denylist_linked_list_policy_id: t_dl_ll_policy,
    security_info: builtin.constr_data(0, []),
    trusted_entity_vkeys: [],
    member_root_hash,
    requires_sender_kyc: False,
    requires_receiver_kyc: False,
    network_id,
  }
}

fn sanitise_mint() -> Value {
  merge(
    from_asset(t_pu_ll_policy, constants.linked_list_root_key, 1),
    from_asset(t_dl_ll_policy, constants.linked_list_root_key, 1),
  )
}

test sanitise_accepts_valid_config() {
  sanitise_initial_datum(sanitise_datum(#"", 1), sanitise_mint())
}

test sanitise_accepts_32_byte_root() {
  sanitise_initial_datum(sanitise_datum(t_root32, 2), sanitise_mint())
}

test sanitise_rejects_network_id_above_255() {
  !sanitise_initial_datum(sanitise_datum(#"", 256), sanitise_mint())
}

test sanitise_rejects_negative_network_id() {
  !sanitise_initial_datum(sanitise_datum(#"", -1), sanitise_mint())
}

test sanitise_rejects_bad_root_hash_length() {
  // 2 bytes — neither empty nor 32.
  !sanitise_initial_datum(sanitise_datum(#"aabb", 1), sanitise_mint())
}

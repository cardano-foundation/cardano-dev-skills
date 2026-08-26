use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{Element, Node}
use cardano/address.{Address, Credential, Script, VerificationKey}
use cardano/assets.{
  PolicyId, Value, from_asset, from_lovelace, merge, quantity_of,
  without_lovelace, zero,
}
use cardano/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, Transaction,
  find_input,
}
use constants
use types/global_state.{
  AddTrustedEntity, DeactivateContract, GlobalStateDatum,
  GlobalStateSpendRedeemer, LockUpgrades, MintSecurity, ModifySecurityInfo,
  PauseTransfers, RemoveTrustedEntity, RotateAdmin, RotateMintingScript,
  SetRequiresReceiverKyc, SetRequiresSenderKyc, TrustedEntityMetadata,
  UpdateMemberRootHash, UpdateTrustedEntity, set_admin_credential_hash,
  set_deactivated, set_member_root_hash, set_mintable_amount,
  set_minting_script_credential_hash, set_requires_receiver_kyc,
  set_requires_sender_kyc, set_security_info, set_transfers_paused,
  set_trusted_entity_vkeys, set_upgrades_locked,
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

/// Every trusted entity's metadata, individually, within
/// `constants.max_trusted_entity_metadata_bytes` once CBOR-serialised.
fn all_metadata_within_bound(
  entries: Pairs<ByteArray, TrustedEntityMetadata>,
) -> Bool {
  list.all(
    entries,
    fn(entry) {
      bytearray.length(builtin.serialise_data(entry.2nd)) <= constants.max_trusted_entity_metadata_bytes
    },
  )
}

fn sanitise_initial_datum(datum: GlobalStateDatum, self_mint: Value) -> Bool {
  let root_len = bytearray.length(datum.member_root_hash)
  and {
    !datum.transfers_paused,
    // A born-deactivated protocol would be permanently unspendable at genesis.
    !datum.deactivated,
    datum.mintable_amount >= 0,
    bytearray.length(datum.admin_credential_hash) == 28,
    bytearray.length(datum.minting_script_credential_hash) == 28,
    // Born unlocked. Locking is a single admin transaction away, so a
    // deployment that wants immutability from day one loses nothing — but a
    // token that started locked could never be corrected at all.
    !datum.upgrades_locked,
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
    // The two lists must not be the same list. If the ids were equal,
    // every power-user node would double as a denylist node — and since a
    // power-user node's link is unconstrained by the denylist's ordering, the
    // sanctions list would be satisfiable from day one and never bind. Both
    // fields are IMMUTABLE after genesis (every spend branch reproduces the
    // datum wholesale), so this is the only chance to catch it.
    //
    // The length checks are the same defence one step earlier: a malformed id
    // can never name a real minting policy, so the corresponding list would be
    // permanently un-initialisable. Off-chain must additionally verify both ids
    // against the compiled list-validator hashes before signing genesis — that
    // binding is not checkable here.
    datum.power_user_linked_list_policy_id != datum.denylist_linked_list_policy_id,
    bytearray.length(datum.power_user_linked_list_policy_id) == 28,
    bytearray.length(datum.denylist_linked_list_policy_id) == 28,
    is_sorted_no_dup_vkeys(datum.trusted_entity_vkeys),
    // Datum growth caps — defence in depth, see `constants.max_*` doc
    // comment. Enforced once here at genesis, and again on every spend
    // branch able to grow the same field afterwards.
    list.length(datum.trusted_entity_vkeys) <= constants.max_trusted_entities,
    bytearray.length(builtin.serialise_data(datum.security_info)) <= constants.max_security_info_bytes,
    all_metadata_within_bound(datum.trusted_entity_vkeys),
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
  /// The POWER-USERS SPEND VALIDATOR's script hash — not the list
  /// policy id. Element authentication ignores the address, so a power-user
  /// NFT carried out of the list into a private wallet keeps authenticating
  /// whatever ROLE FLAGS its holder writes into the datum. Here that would let
  /// a revoked operator keep pausing the protocol. Not circular: the
  /// power-users validators depend on the GlobalState MINT hash, never on this
  /// spend validator's.
  power_user_list_script_hash: ByteArray,
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

    // Non-MintSecurity branches additionally forbid the security token from
    // moving through the transaction at all — not merely from being minted or
    // burned. Every validator that reads GlobalState as a SPENT input
    // (transfer, seizure, registry upgrade, the proxy) sees the PRE-state
    // datum, so without this guard a `can_pause` power user could
    // pause-and-transfer, or an admin could flip a KYC flag, remove a trusted
    // entity, change the member root, or deactivate the protocol and still
    // move the security token in the very same transaction — under the rules
    // that were true a moment before the action took effect. No admin action
    // has any legitimate need to move the security token, so forbidding it
    // here costs little and removes the atomicity bypass. `MintSecurity` is
    // exempt: it is the one branch that legitimately mints, burns, and
    // otherwise moves the token.
    //
    // Only the INPUTS are scanned. Every branch that composes this also
    // composes `no_concurrent_security_mint` (nothing minted or burned under
    // the security asset), and the ledger conserves value — every unit in an
    // output comes from an input or from the mint field — so with no unit
    // spent and none minted, no output can carry the token either. Scanning
    // the outputs as well would only re-prove ledger conservation.
    let no_security_token_spent = list.all(
      self.inputs,
      fn(input) {
        quantity_of(input.output.value, issuance_policy_id, security_asset_name) == 0
      },
    )

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

        let (power_user_credential_hash, power_user_data) = utils.authenticated_power_user(
          power_user_node_ref_input.output,
          input_datum.power_user_linked_list_policy_id,
          power_user_list_script_hash,
        )

        let expected_output_datum = set_transfers_paused(
          input_fields,
          transfers_paused,
        )
        and {
          no_concurrent_security_mint,
          no_security_token_spent,
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
          no_security_token_spent,
          address_preserved,
          nft_preserved,
          value_preserved,
          // Datum growth cap — see `constants.max_security_info_bytes`.
          bytearray.length(builtin.serialise_data(new_security_info)) <= constants.max_security_info_bytes,
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
          no_security_token_spent,
          address_preserved,
          nft_preserved,
          value_preserved,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          bytearray.length(vkey) == 32,
          !has_key,
          // Datum growth caps — see `constants.max_trusted_entities` /
          // `constants.max_trusted_entity_metadata_bytes`.
          list.length(updated_entities) <= constants.max_trusted_entities,
          bytearray.length(builtin.serialise_data(metadata)) <= constants.max_trusted_entity_metadata_bytes,
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
          no_security_token_spent,
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
          no_security_token_spent,
          address_preserved,
          nft_preserved,
          value_preserved,
          old_exists,
          new_clash_ok,
          bytearray.length(new_vkey) == 32,
          // Datum growth cap — see `constants.max_trusted_entity_metadata_bytes`.
          bytearray.length(builtin.serialise_data(new_metadata)) <= constants.max_trusted_entity_metadata_bytes,
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
          no_security_token_spent,
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
          no_security_token_spent,
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
          no_security_token_spent,
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
          no_security_token_spent,
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
      RotateMintingScript { new_minting_script_credential_hash } -> {
        let expected_output_datum = set_minting_script_credential_hash(
          input_fields,
          new_minting_script_credential_hash,
        )
        and {
          no_concurrent_security_mint,
          no_security_token_spent,
          address_preserved,
          nft_preserved,
          value_preserved,
          bytearray.length(new_minting_script_credential_hash) == 28,
          // The one-way upgrade lock closes this path permanently. See
          // `upgrades_locked` on GlobalStateDatum.
          !input_datum.upgrades_locked,
          // Admin-only, single-signature — see the doc comment on
          // RotateMintingScript: unlike RotateAdmin, the OUTGOING authority's
          // consent is deliberately not required, since replacing a buggy or
          // compromised authority is exactly the case this must still work
          // for. minting_logic_script.ak independently refuses to ever
          // delegate to itself (own-hash self-authorisation guard), so this
          // action does not need to defend against that specific value here.
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      LockUpgrades -> {
        let expected_output_datum = set_upgrades_locked(input_fields, True)
        and {
          no_concurrent_security_mint,
          no_security_token_spent,
          address_preserved,
          nft_preserved,
          value_preserved,
          // One-way: refuse to re-lock, so the action is never a silent
          // no-op and the transition True->True cannot be used to churn the
          // UTxO. Nothing anywhere sets this field back to False — every
          // branch reproduces the datum wholesale and only this branch
          // touches it — so False is reachable exactly once, at genesis.
          !input_datum.upgrades_locked,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          builtin.equals_data(expected_output_datum, global_state_output_datum),
        }
      }
      DeactivateContract -> {
        let expected_output_datum = set_deactivated(input_fields, True)
        and {
          no_concurrent_security_mint,
          no_security_token_spent,
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

// The power-users SPEND validator's hash. No PauseTransfers fixture
// exercises it yet — see the note in the test section.
const t_pu_script_hash: ByteArray =
  #"d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1"

const t_gs_script_hash: ByteArray =
  #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const t_new_admin: ByteArray =
  #"1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c"

const t_sec_name: ByteArray = "SEC"

const t_minting_script: ByteArray =
  #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

const t_new_minting_script: ByteArray =
  #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

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
    minting_script_credential_hash: t_minting_script,
    upgrades_locked: False,
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
    t_pu_script_hash,
    Some(input_datum),
    redeemer,
    t_out_ref(0),
    tx,
  )
}

// ── RotateMintingScript — admin-only, single-signature ───────────────────────

fn rotate_minting_script_redeemer(
  new_minting_script_credential_hash: ByteArray,
) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: RotateMintingScript { new_minting_script_credential_hash },
  }
}

test rotate_minting_script_succeeds_when_admin_signs() {
  // Admin alone is sufficient — note the signatory list holds neither the
  // outgoing nor the incoming authority. Deliberately NOT dual-sig:
  // replacing a buggy or compromised authority has to work precisely when
  // that authority can no longer be trusted to co-sign its own removal.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    minting_script_credential_hash: t_new_minting_script,
    upgrades_locked: False,
  }
  run_spend(
    input_datum,
    rotate_minting_script_redeemer(t_new_minting_script),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test rotate_minting_script_fails_without_admin_signature() {
  // Deliberately NOT dual-sig: only the admin's signature is checked, so
  // this must fail on a missing ADMIN signature alone — no signature from
  // the outgoing minting script is required or checked at all.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    minting_script_credential_hash: t_new_minting_script,
    upgrades_locked: False,
  }
  !run_spend(
    input_datum,
    rotate_minting_script_redeemer(t_new_minting_script),
    t_tx(input_datum, output_datum, []),
  )
}

test rotate_minting_script_cannot_smuggle_another_field_change() {
  // A rotation must change exactly one field. Without the whole-datum
  // equality check an admin-signed rotation would be a carrier for any
  // other datum edit — e.g. silently raising the supply cap alongside it.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    minting_script_credential_hash: t_new_minting_script,
    upgrades_locked: False,
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    rotate_minting_script_redeemer(t_new_minting_script),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test rotate_admin_succeeds_when_both_sign() {
  // Dual-sig by design: requiring the INCOMING admin's signature too proves
  // the new credential is live, so a typo cannot strand the protocol with an
  // admin nobody controls.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    admin_credential_hash: t_new_admin,
  }
  run_spend(
    input_datum,
    rotate_admin_redeemer(t_new_admin),
    t_tx(input_datum, output_datum, [t_admin, t_new_admin]),
  )
}

test rotate_admin_fails_without_outgoing_admin_signature() {
  // Blocks silent takeover: whoever holds the new key cannot install it alone.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    admin_credential_hash: t_new_admin,
  }
  !run_spend(
    input_datum,
    rotate_admin_redeemer(t_new_admin),
    t_tx(input_datum, output_datum, [t_new_admin]),
  )
}

test rotate_admin_fails_without_incoming_admin_signature() {
  // The lost-key soft-brick guard: the outgoing admin alone cannot hand the
  // protocol to a credential that has not proven it can sign.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    admin_credential_hash: t_new_admin,
  }
  !run_spend(
    input_datum,
    rotate_admin_redeemer(t_new_admin),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test rotate_admin_cannot_smuggle_another_field_change() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    admin_credential_hash: t_new_admin,
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    rotate_admin_redeemer(t_new_admin),
    t_tx(input_datum, output_datum, [t_admin, t_new_admin]),
  )
}

fn rotate_admin_redeemer(
  new_admin_credential_hash: ByteArray,
) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: RotateAdmin { new_admin_credential_hash },
  }
}

test rotate_minting_script_fails_when_length_invalid() {
  let input_datum = t_datum(False, False)
  let bad_hash = #"ab"
  let output_datum = GlobalStateDatum {
    ..input_datum,
    minting_script_credential_hash: bad_hash,
    upgrades_locked: False,
  }
  !run_spend(
    input_datum,
    rotate_minting_script_redeemer(bad_hash),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test deactivated_input_rejects_rotate_minting_script() fail {
  let input_datum = t_datum(True, True)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    minting_script_credential_hash: t_new_minting_script,
    upgrades_locked: False,
  }
  run_spend(
    input_datum,
    rotate_minting_script_redeemer(t_new_minting_script),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── LockUpgrades — the one-way upgrade lock ─────────────────────────────────

fn lock_upgrades_redeemer() -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: LockUpgrades,
  }
}

fn t_datum_locked() -> GlobalStateDatum {
  GlobalStateDatum { ..t_datum(False, False), upgrades_locked: True }
}

test lock_upgrades_succeeds_when_admin_signs() {
  let input_datum = t_datum(False, False)
  run_spend(
    input_datum,
    lock_upgrades_redeemer(),
    t_tx(input_datum, t_datum_locked(), [t_admin]),
  )
}

test lock_upgrades_fails_without_admin_signature() {
  let input_datum = t_datum(False, False)
  !run_spend(
    input_datum,
    lock_upgrades_redeemer(),
    t_tx(input_datum, t_datum_locked(), []),
  )
}

test lock_upgrades_is_one_way() {
  // Re-locking is refused, so the action is never a silent no-op...
  let input_datum = t_datum_locked()
  !run_spend(
    input_datum,
    lock_upgrades_redeemer(),
    t_tx(input_datum, t_datum_locked(), [t_admin]),
  )
}

test lock_upgrades_cannot_be_undone() {
  // ...and no action can clear it. Every branch reproduces the datum
  // wholesale via `equals_data`, and only LockUpgrades touches this field —
  // which sets it True — so False is reachable exactly once, at genesis.
  // Attempting to unlock is checked here against LockUpgrades itself; the
  // whole-datum equality is what blocks every other branch from doing it.
  let input_datum = t_datum_locked()
  !run_spend(
    input_datum,
    lock_upgrades_redeemer(),
    t_tx(input_datum, t_datum(False, False), [t_admin]),
  )
}

test lock_upgrades_cannot_smuggle_another_field_change() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..t_datum_locked(),
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    lock_upgrades_redeemer(),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test rotate_minting_script_fails_once_upgrades_are_locked() {
  // The lock closes the minting-authority upgrade path permanently.
  let input_datum = t_datum_locked()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    minting_script_credential_hash: t_new_minting_script,
  }
  !run_spend(
    input_datum,
    rotate_minting_script_redeemer(t_new_minting_script),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test sanitise_rejects_genesis_that_is_born_locked() {
  // A token locked at birth could never be corrected at all; locking is one
  // admin transaction away, so nothing is lost by refusing it here.
  let datum = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    upgrades_locked: True,
  }
  !sanitise_initial_datum(datum, sanitise_mint())
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

// ── DeactivateContract — no_security_token_spent ─────────────────────────
//
// `with_security_token_input`/`with_security_token_output` are defined below,
// alongside the MintSecurity fixtures — Aiken resolves top-level bindings
// module-wide, so the forward reference is fine.

test deactivate_succeeds_when_security_token_absent_from_tx() {
  // Positive control paired with the two negatives below — same fixture as
  // `deactivate_succeeds_when_paused_and_admin_signs`, named here to make the
  // pairing with the guard explicit.
  let input_datum = t_datum(True, False)
  let output_datum = GlobalStateDatum { ..input_datum, deactivated: True }
  run_spend(
    input_datum,
    deactivate_redeemer(),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test deactivate_rejects_when_an_input_carries_the_security_token() {
  let input_datum = t_datum(True, False)
  let output_datum = GlobalStateDatum { ..input_datum, deactivated: True }
  !run_spend(
    input_datum,
    deactivate_redeemer(),
    with_security_token_input(t_tx(input_datum, output_datum, [t_admin])),
  )
}

test deactivate_rejects_when_the_security_token_is_minted_into_an_output() {
  let input_datum = t_datum(True, False)
  let output_datum = GlobalStateDatum { ..input_datum, deactivated: True }
  !run_spend(
    input_datum,
    deactivate_redeemer(),
    with_security_token_minted_into_an_output(
      t_tx(input_datum, output_datum, [t_admin]),
    ),
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
    global_state_output_index: 0,
    action: MintSecurity { issuance_policy_redeemer_index: 0 },
  }
}

// ── no_security_token_spent — shared fixtures ───────────────────────────────
//
// Every non-MintSecurity branch composes `no_security_token_spent`. These
// helpers append one extra input, or one extra output, carrying the security
// token to an otherwise-unmodified transaction — reused by every branch's
// guard tests below, and by the MintSecurity positive control that proves
// the branch is deliberately exempt.

const t_wallet_vkey: ByteArray =
  #"77777777777777777777777777777777777777777777777777777777"

fn t_security_token_value() -> Value {
  merge(from_lovelace(2_000_000), from_asset(t_issuance_policy, t_sec_name, 1))
}

/// An extra input carrying one unit of the security token, parked in a plain
/// wallet — proves `no_security_token_spent` rejects the token appearing
/// as an INPUT, independent of which branch or datum is under test.
fn t_security_token_input() -> Input {
  Input {
    output_reference: t_out_ref(9),
    output: Output {
      address: Address {
        payment_credential: VerificationKey(t_wallet_vkey),
        stake_credential: None,
      },
      value: t_security_token_value(),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

/// Same, but as an extra OUTPUT. On its own an output with no matching input
/// is ledger-impossible (value is conserved), so the fixture that uses this
/// also MINTS the unit — the output side is covered by
/// `no_concurrent_security_mint`, not by an output scan.
fn t_security_token_output() -> Output {
  Output {
    address: Address {
      payment_credential: VerificationKey(t_wallet_vkey),
      stake_credential: None,
    },
    value: t_security_token_value(),
    datum: NoDatum,
    reference_script: None,
  }
}

fn with_security_token_input(tx: Transaction) -> Transaction {
  Transaction {
    ..tx,
    inputs: list.concat(tx.inputs, [t_security_token_input()]),
  }
}

/// An extra OUTPUT carrying the unit that `with_security_token_input` spends
/// — a ledger-consistent pass-through, used by the MintSecurity exemption
/// test (the one branch allowed to move the token).
fn with_security_token_output(tx: Transaction) -> Transaction {
  Transaction {
    ..tx,
    outputs: list.concat(tx.outputs, [t_security_token_output()]),
  }
}

/// The only ledger-valid way for the token to appear in an output without
/// being spent is to mint it; `no_concurrent_security_mint` rejects that.
fn with_security_token_minted_into_an_output(tx: Transaction) -> Transaction {
  Transaction {
    ..tx,
    mint: merge(tx.mint, from_asset(t_issuance_policy, t_sec_name, 1)),
    outputs: list.concat(tx.outputs, [t_security_token_output()]),
  }
}

/// The supply-cap branch must change exactly `mintable_amount` and nothing
/// else. It is the highest-value branch to pin: a mint is the one routine
/// operation that legitimately rewrites the datum, so if it could carry a
/// second edit it would be the natural vehicle for one — rotating the admin,
/// clearing a KYC flag or unlocking upgrades under cover of an ordinary
/// issuance. The whole-datum equality is what prevents that; this test is its
/// guard.
test mint_security_cannot_smuggle_another_field_change() {
  let input_datum = t_datum(False, False)
  let mint = 100
  let output_datum = GlobalStateDatum {
    ..input_datum,
    mintable_amount: input_datum.mintable_amount - mint,
    // …plus one edit that has no business riding along.
    admin_credential_hash: t_new_admin,
  }
  !run_spend(
    input_datum,
    mintsecurity_redeemer(),
    t_mintsecurity_tx(input_datum, output_datum, mint, [t_admin]),
  )
}

/// The control: the same transaction WITHOUT the smuggled edit is accepted.
/// Without this, the test above would pass even if the whole branch were
/// broken.
test mint_security_accepts_a_clean_cap_decrement() {
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

/// The cap must actually be decremented. Here the datum is reproduced
/// unchanged while 100 tokens are issued, which would leave headroom for the
/// full original cap on top of live supply — the simplest form of the
/// inflation this branch exists to prevent.
test mint_security_rejects_a_cap_that_does_not_decrement() {
  let input_datum = t_datum(False, False)
  let output_datum = input_datum
  !run_spend(
    input_datum,
    mintsecurity_redeemer(),
    t_mintsecurity_tx(input_datum, output_datum, 100, [t_admin]),
  )
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

/// MintSecurity is deliberately EXEMPT from `no_security_token_spent` — it
/// is the one branch that legitimately mints, burns, and otherwise moves the
/// token. On top of the ordinary mint-delta this transaction ALSO carries an
/// unrelated security-token input and output — exactly the shape every other
/// branch's negative controls below reject — and the branch still succeeds.
test mint_security_allows_security_token_input_and_output() {
  let input_datum = t_datum(False, False)
  let mint = 100
  let output_datum = GlobalStateDatum {
    ..input_datum,
    mintable_amount: input_datum.mintable_amount - mint,
  }
  let tx = t_mintsecurity_tx(input_datum, output_datum, mint, [t_admin])
    |> with_security_token_input
    |> with_security_token_output
  run_spend(input_datum, mintsecurity_redeemer(), tx)
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
    minting_script_credential_hash: t_minting_script,
    upgrades_locked: False,
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

// ── Datum growth caps — genesis ─────────────────────────────────────────────

/// `count` strictly-ascending 32-byte vkeys (big-endian encoding of 1..count,
/// so ascending order is guaranteed automatically), each paired with trivial
/// metadata — used to exercise the trusted-entity list length cap without
/// hand-writing dozens of fixtures.
fn t_many_entities(count: Int) -> Pairs<ByteArray, TrustedEntityMetadata> {
  list.map(
    list.range(1, count),
    fn(i) { Pair(bytearray.from_int_big_endian(i, 32), builtin.i_data(i)) },
  )
}

/// An arbitrary `Data` value (a plain byte string) whose serialised (CBOR)
/// size, in bytes, is a function of `raw_len`. Plutus Data serialises a
/// ByteArray longer than 64 bytes as an indefinite-length, 64-byte-chunked
/// byte string, so the size is not simply `raw_len` plus a fixed constant.
/// The `t_*_len_at_cap` / `t_*_len_over_cap` constants below were chosen so
/// this lands the serialised size exactly on, or one byte over, the two
/// size bounds this file exercises.
fn t_data_of_raw_length(raw_len: Int) -> Data {
  builtin.b_data(bytearray.from_int_big_endian(0, raw_len))
}

const t_security_info_len_at_cap: Int = 3969

const t_security_info_len_over_cap: Int = 3970

const t_metadata_len_at_cap: Int = 494

const t_metadata_len_over_cap: Int = 495

test sanitise_accepts_trusted_entity_count_at_the_cap() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    trusted_entity_vkeys: t_many_entities(constants.max_trusted_entities),
  }
  sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_rejects_trusted_entity_count_over_the_cap() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    trusted_entity_vkeys: t_many_entities(constants.max_trusted_entities + 1),
  }
  !sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_accepts_security_info_at_the_size_cap() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    security_info: t_data_of_raw_length(t_security_info_len_at_cap),
  }
  sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_rejects_security_info_one_byte_over_the_size_cap() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    security_info: t_data_of_raw_length(t_security_info_len_over_cap),
  }
  !sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_accepts_trusted_entity_metadata_at_the_size_cap() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    trusted_entity_vkeys: [
      Pair(t_vkey_10, t_data_of_raw_length(t_metadata_len_at_cap)),
    ],
  }
  sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_rejects_trusted_entity_metadata_one_byte_over_the_size_cap() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    trusted_entity_vkeys: [
      Pair(t_vkey_10, t_data_of_raw_length(t_metadata_len_over_cap)),
    ],
  }
  !sanitise_initial_datum(d, sanitise_mint())
}

// ── Genesis sanitisation negatives ──────────────────────────────────────────

test sanitise_rejects_negative_mintable_amount() {
  let d = GlobalStateDatum { ..sanitise_datum(#"", 1), mintable_amount: -1 }
  !sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_rejects_short_admin_credential_hash() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    admin_credential_hash: #"ab",
  }
  !sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_rejects_short_minting_script_credential_hash() {
  let d = GlobalStateDatum {
    ..sanitise_datum(#"", 1),
    minting_script_credential_hash: #"ab",
  }
  !sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_rejects_born_paused() {
  let d = GlobalStateDatum { ..sanitise_datum(#"", 1), transfers_paused: True }
  !sanitise_initial_datum(d, sanitise_mint())
}

test sanitise_rejects_born_deactivated() {
  let d = GlobalStateDatum { ..sanitise_datum(#"", 1), deactivated: True }
  !sanitise_initial_datum(d, sanitise_mint())
}

// ── Genesis mint validator ───────────────────────────────────────────────────

const t_mint_tx0: ByteArray =
  #"9999999999999999999999999999999999999999999999999999999999999999"

const t_mint_index0: Int = 0

const t_mint_receiver_vkey: ByteArray =
  #"88888888888888888888888888888888888888888888888888888888"

/// Invokes `global_state_mint_validator.mint` end-to-end, fixing the
/// compile-time one-shot UTxO reference (`t_mint_tx0`/`t_mint_index0`) and
/// the (unused) redeemer so each test only has to vary `policy_id` and `self`.
fn run_mint(policy_id: PolicyId, self: Transaction) -> Bool {
  global_state_mint_validator.mint(
    t_mint_tx0,
    t_mint_index0,
    builtin.constr_data(0, []),
    policy_id,
    self,
  )
}

/// The one-shot nonce UTxO the mint validator requires as an input.
fn t_nonce_input() -> Input {
  Input {
    output_reference: OutputReference {
      transaction_id: t_mint_tx0,
      output_index: t_mint_index0,
    },
    output: Output {
      address: Address {
        payment_credential: VerificationKey(t_mint_receiver_vkey),
        stake_credential: None,
      },
      value: from_lovelace(2_000_000),
      datum: NoDatum,
      reference_script: None,
    },
  }
}

/// The output carrying the freshly-minted global_state NFT plus a datum.
fn t_mint_output(datum: GlobalStateDatum) -> Output {
  Output {
    address: Address {
      payment_credential: Script(t_gs_script_hash),
      stake_credential: None,
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(t_gs_policy, constants.global_state_asset_name, 1),
    ),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

/// A plain output carrying no asset of `t_gs_policy` at all.
fn t_mint_plain_output() -> Output {
  Output {
    address: Address {
      payment_credential: VerificationKey(t_mint_receiver_vkey),
      stake_credential: None,
    },
    value: from_lovelace(2_000_000),
    datum: NoDatum,
    reference_script: None,
  }
}

fn t_mint_tx(
  inputs: List<Input>,
  outputs: List<Output>,
  mint: Value,
) -> Transaction {
  Transaction {
    ..t_tx(sanitise_datum(#"", 1), sanitise_datum(#"", 1), []),
    inputs,
    outputs,
    mint,
  }
}

test global_state_mint_succeeds_with_nonce_and_sanitised_datum() {
  let datum = sanitise_datum(#"", 1)
  let mint = merge(
    from_asset(t_gs_policy, constants.global_state_asset_name, 1),
    sanitise_mint(),
  )
  run_mint(
    t_gs_policy,
    t_mint_tx([t_nonce_input()], [t_mint_output(datum)], mint),
  )
}

test global_state_mint_fails_without_nonce_input() fail {
  // The one-time UTxO `find_input` must locate is absent from `self.inputs`
  // — `expect Some(_input_present) = find_input(..)` traps.
  let datum = sanitise_datum(#"", 1)
  let mint = merge(
    from_asset(t_gs_policy, constants.global_state_asset_name, 1),
    sanitise_mint(),
  )
  run_mint(t_gs_policy, t_mint_tx([], [t_mint_output(datum)], mint))
}

test global_state_mint_rejects_second_asset_name_under_policy() {
  // A second asset name minted under the same policy, carried by a SEPARATE
  // output — the primary NFT output is untouched, so `list.expect_find`
  // still locates it without trapping; `quantity_of_policy_id(self.mint,
  // policy_id) == 1` is the only assertion this violates.
  let datum = sanitise_datum(#"", 1)
  let mint = merge(
    merge(
      from_asset(t_gs_policy, constants.global_state_asset_name, 1),
      from_asset(t_gs_policy, "Other", 1),
    ),
    sanitise_mint(),
  )
  !run_mint(
    t_gs_policy,
    t_mint_tx(
      [t_nonce_input()],
      [t_mint_output(datum), t_mint_plain_output()],
      mint,
    ),
  )
}

test global_state_mint_rejects_nft_quantity_of_two() {
  // The NFT-carrying output still holds exactly 1 unit (so `list.expect_find`
  // does not trap), but `self.mint` carries 2 units of the same asset name —
  // `quantity_of(self.mint, policy_id, asset_name) == 1` is the check this
  // violates.
  let datum = sanitise_datum(#"", 1)
  let mint = merge(
    from_asset(t_gs_policy, constants.global_state_asset_name, 2),
    sanitise_mint(),
  )
  !run_mint(
    t_gs_policy,
    t_mint_tx([t_nonce_input()], [t_mint_output(datum)], mint),
  )
}

test global_state_mint_fails_when_no_output_carries_the_nft() fail {
  // No output in the transaction carries the NFT at all — `list.expect_find`
  // recurses past the end of `self.outputs` and traps.
  let mint = merge(
    from_asset(t_gs_policy, constants.global_state_asset_name, 1),
    sanitise_mint(),
  )
  run_mint(
    t_gs_policy,
    t_mint_tx([t_nonce_input()], [t_mint_plain_output()], mint),
  )
}

// ── PauseTransfers — the power-user gate and its list-address pin ───────────
//
// The address pin this branch carries matters more here than in the swappable
// consumers: `global_state_spend_validator` cannot be rotated on a live
// deployment, so the assertion is the primary defence rather than a
// belt-and-braces one. Keep all three tests together — the positive control is
// what makes the two negatives meaningful.

const t_pause_pu_cred: ByteArray =
  #"0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c"

/// The datum used by the pause tests — `t_datum` leaves the list policy ids
/// empty, which no real deployment does.
fn t_pause_datum(transfers_paused: Bool) -> GlobalStateDatum {
  GlobalStateDatum {
    ..t_datum(transfers_paused, False),
    power_user_linked_list_policy_id: t_pu_ll_policy,
    denylist_linked_list_policy_id: t_dl_ll_policy,
  }
}

/// A power-user node with `can_pause`, at `payment` — varied so the address
/// pin can be exercised in both directions.
fn t_pu_node_at(payment: Credential) -> Input {
  let pu = PowerUser {
    credential_hash: t_pause_pu_cred,
    is_admin: False,
    can_mint: False,
    can_burn: False,
    can_pause: True,
    can_force_transfer: False,
  }
  let element: Element<Data, PowerUser> = Element {
    data: Node { data: pu },
    link: None,
  }
  Input {
    output_reference: t_out_ref(5),
    output: Output {
      address: Address { payment_credential: payment, stake_credential: None },
      value: merge(
        from_lovelace(2_000_000),
        from_asset(
          t_pu_ll_policy,
          bytearray.concat(
            constants.linked_list_node_key_prefix,
            t_pause_pu_cred,
          ),
          1,
        ),
      ),
      datum: InlineDatum(element),
      reference_script: None,
    },
  }
}

fn t_pause_tx(node: Input) -> Transaction {
  Transaction {
    ..t_tx(t_pause_datum(False), t_pause_datum(True), [t_pause_pu_cred]),
    reference_inputs: [node],
  }
}

fn t_pause_redeemer() -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: PauseTransfers {
      transfers_paused: True,
      power_user_node_ref_input_index: 0,
    },
  }
}

/// The positive control. Without it the two negatives below would also pass
/// if the branch were broken outright.
test pause_succeeds_for_a_can_pause_power_user_in_the_list() {
  run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    t_pause_tx(t_pu_node_at(Script(t_pu_script_hash))),
  )
}

/// The same node, same NFT, same datum — parked at a SCRIPT address
/// that is not the power-users list. `expect ... == power_user_list_script_hash`
/// traps, hence `fail`.
test pause_fails_when_the_power_user_node_is_at_the_wrong_script() fail {
  run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    t_pause_tx(t_pu_node_at(Script(t_gs_script_hash))),
  )
}

/// The reachable shape: the node NFT carried out of the list into a private
/// wallet, where element authentication would otherwise still accept whatever
/// role flags its holder writes. The `expect Script(..)` pattern match traps on
/// a `VerificationKey` credential.
test pause_fails_when_the_power_user_node_is_in_a_wallet() fail {
  run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    t_pause_tx(
      t_pu_node_at(
        VerificationKey(
          #"0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e",
        ),
      ),
    ),
  )
}

// ── PauseTransfers — no_security_token_spent ─────────────────────────────

test pause_succeeds_when_security_token_absent_from_tx() {
  // Positive control paired with the two negatives below — same fixture as
  // `pause_succeeds_for_a_can_pause_power_user_in_the_list`.
  run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    t_pause_tx(t_pu_node_at(Script(t_pu_script_hash))),
  )
}

test pause_rejects_when_an_input_carries_the_security_token() {
  !run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    with_security_token_input(
      t_pause_tx(t_pu_node_at(Script(t_pu_script_hash))),
    ),
  )
}

test pause_rejects_when_the_security_token_is_minted_into_an_output() {
  !run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    with_security_token_minted_into_an_output(
      t_pause_tx(t_pu_node_at(Script(t_pu_script_hash))),
    ),
  )
}

// ── PauseTransfers — value_preserved (assets.match) ─────────────────────────
// `value_preserved` is one `assets.match` walk: every non-ADA asset of the
// continuing output must equal the input's, and ADA may only grow. The two
// tests below pin both halves locally (ADA removal is covered in
// `validators/regression.ak`).

const t_foreign_policy: ByteArray =
  #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

/// Rebuild the continuing GlobalState output (index 0, what every redeemer
/// names) with a transformed value; everything else is untouched.
fn with_gs_output_value(tx: Transaction, f: fn(Value) -> Value) -> Transaction {
  expect [gs_out, ..rest] = tx.outputs
  Transaction {
    ..tx,
    outputs: [Output { ..gs_out, value: f(gs_out.value) }, ..rest],
  }
}

/// ADA top-up on the control UTxO is allowed (the `>=` arm of `assets.match`).
test pause_succeeds_when_the_continuing_output_is_topped_up_with_ada() {
  run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    with_gs_output_value(
      t_pause_tx(t_pu_node_at(Script(t_pu_script_hash))),
      fn(v) { merge(v, from_lovelace(1_000_000)) },
    ),
  )
}

/// A foreign asset smuggled into the continuing output changes the non-ADA
/// asset set, which `assets.match` requires to be identical — rejected as a
/// clean `False` (`value_preserved` is a `Bool` conjunct), hence `!run_spend`.
test pause_rejects_a_foreign_asset_added_to_the_continuing_output() {
  !run_spend(
    t_pause_datum(False),
    t_pause_redeemer(),
    with_gs_output_value(
      t_pause_tx(t_pu_node_at(Script(t_pu_script_hash))),
      fn(v) { merge(v, from_asset(t_foreign_policy, "X", 1)) },
    ),
  )
}

/// One list must not double as the other. `sanitise_mint()` mints both
/// roots under distinct policies, so with the datum ids made equal the mint
/// check still passes and the new inequality assertion is what rejects it.
/// Both fields are immutable after genesis, so this is the only chance.
test sanitise_rejects_identical_list_policies() {
  let d = sanitise_datum(#"", 1)
  !sanitise_initial_datum(
    GlobalStateDatum { ..d, denylist_linked_list_policy_id: t_pu_ll_policy },
    sanitise_mint(),
  )
}

/// A malformed policy id can never name a real minting policy, so the
/// corresponding list would be permanently un-initialisable.
///
/// The mint is built to carry a root under the malformed id as well, so the
/// pre-existing "both roots minted here" check PASSES and the new length check
/// is the only thing that can reject this datum.
test sanitise_rejects_short_list_policy_id() {
  let d = sanitise_datum(#"", 1)
  let short_policy = #"aabb"
  !sanitise_initial_datum(
    GlobalStateDatum { ..d, denylist_linked_list_policy_id: short_policy },
    merge(
      from_asset(t_pu_ll_policy, constants.linked_list_root_key, 1),
      from_asset(short_policy, constants.linked_list_root_key, 1),
    ),
  )
}

// ============================================================================
// Tests — the seven remaining spend branches: ModifySecurityInfo,
// AddTrustedEntity, RemoveTrustedEntity, UpdateTrustedEntity,
// SetRequiresSenderKyc, SetRequiresReceiverKyc, UpdateMemberRootHash
// ============================================================================
//
// None of these seven branches contains an `expect` inside its `and { .. }`
// block — every condition (signature, length, has_key, ..) is a plain Bool
// combined with `and`, so a violated precondition or a missing signature
// makes `run_spend` return False. It never traps. So unlike the
// `deactivated_input_rejects_*` / `pause_fails_when_*` tests above, none of
// the negatives below are `fail`-annotated.
//
// `deactivated_input_rejects_modify_security_info` (above) remains the only
// terminal-guard test touching one of these seven branches — it is not
// duplicated here.

/// 32-byte trusted-entity vkeys, chosen so their byte-wise ascending order is
/// obvious: 05 < 10 < 20 < 30 < 40.
const t_vkey_05: ByteArray =
  #"0505050505050505050505050505050505050505050505050505050505050505"

const t_vkey_10: ByteArray =
  #"1010101010101010101010101010101010101010101010101010101010101010"

const t_vkey_20: ByteArray =
  #"2020202020202020202020202020202020202020202020202020202020202020"

const t_vkey_30: ByteArray =
  #"3030303030303030303030303030303030303030303030303030303030303030"

const t_vkey_40: ByteArray =
  #"4040404040404040404040404040404040404040404040404040404040404040"

/// Deliberately not 32 bytes.
const t_vkey_bad_length: ByteArray = #"aabb"

/// Trusted-entity fixture: two entries already sorted ascending, so tests can
/// exercise insertion, removal, renaming and duplicate/absence checks against
/// a non-trivial starting list.
fn t_tel_datum() -> GlobalStateDatum {
  GlobalStateDatum {
    ..t_datum(False, False),
    trusted_entity_vkeys: [
      Pair(t_vkey_10, builtin.i_data(1)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
}

// ── ModifySecurityInfo — admin-only; no shape or value precondition ────────

fn modify_security_info_redeemer(
  new_security_info: Data,
) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: ModifySecurityInfo { new_security_info },
  }
}

test modify_security_info_succeeds_when_admin_signs() {
  let input_datum = t_datum(False, False)
  let new_info: Data = builtin.constr_data(0, [builtin.i_data(7)])
  let output_datum = GlobalStateDatum { ..input_datum, security_info: new_info }
  run_spend(
    input_datum,
    modify_security_info_redeemer(new_info),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test modify_security_info_fails_without_admin_signature() {
  let input_datum = t_datum(False, False)
  let new_info: Data = builtin.constr_data(0, [builtin.i_data(7)])
  let output_datum = GlobalStateDatum { ..input_datum, security_info: new_info }
  !run_spend(
    input_datum,
    modify_security_info_redeemer(new_info),
    t_tx(input_datum, output_datum, []),
  )
}

test modify_security_info_cannot_smuggle_another_field_change() {
  let input_datum = t_datum(False, False)
  let new_info: Data = builtin.constr_data(0, [builtin.i_data(7)])
  let output_datum = GlobalStateDatum {
    ..input_datum,
    security_info: new_info,
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    modify_security_info_redeemer(new_info),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test modify_security_info_accepts_an_arbitrary_data_shape() {
  // `security_info` is opaque, unconstrained `Data` — an admin-signed update
  // to a plain integer (not even a Constr) is accepted exactly like a
  // Constr-shaped one; there is no on-chain shape check to violate.
  let input_datum = t_datum(False, False)
  let new_info: Data = builtin.i_data(42)
  let output_datum = GlobalStateDatum { ..input_datum, security_info: new_info }
  run_spend(
    input_datum,
    modify_security_info_redeemer(new_info),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── ModifySecurityInfo — datum growth cap ───────────────────────────────────

test modify_security_info_succeeds_at_the_size_cap() {
  let input_datum = t_datum(False, False)
  let new_info = t_data_of_raw_length(t_security_info_len_at_cap)
  let output_datum = GlobalStateDatum { ..input_datum, security_info: new_info }
  run_spend(
    input_datum,
    modify_security_info_redeemer(new_info),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test modify_security_info_rejects_one_byte_over_the_size_cap() {
  let input_datum = t_datum(False, False)
  let new_info = t_data_of_raw_length(t_security_info_len_over_cap)
  let output_datum = GlobalStateDatum { ..input_datum, security_info: new_info }
  !run_spend(
    input_datum,
    modify_security_info_redeemer(new_info),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── AddTrustedEntity — 32-byte vkey, no duplicate, sorted insertion ────────

fn add_trusted_entity_redeemer(
  vkey: ByteArray,
  metadata: TrustedEntityMetadata,
) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: AddTrustedEntity { vkey, metadata },
  }
}

test add_trusted_entity_succeeds_when_admin_signs() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_10, builtin.i_data(1)),
      Pair(t_vkey_20, builtin.i_data(2)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_20, builtin.i_data(2)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test add_trusted_entity_fails_without_admin_signature() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_10, builtin.i_data(1)),
      Pair(t_vkey_20, builtin.i_data(2)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  !run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_20, builtin.i_data(2)),
    t_tx(input_datum, output_datum, []),
  )
}

test add_trusted_entity_fails_when_vkey_wrong_length() {
  // `t_vkey_bad_length` is 2 bytes, not 32 — `bytearray.length(vkey) == 32`
  // is the only assertion this violates: the output below is the exact
  // insertion the branch itself would compute, so equals_data would
  // otherwise pass.
  let input_datum = t_tel_datum()
  let updated_entities = pairs.insert_by_ascending_key(
    input_datum.trusted_entity_vkeys,
    t_vkey_bad_length,
    builtin.i_data(9),
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  !run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_bad_length, builtin.i_data(9)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test add_trusted_entity_fails_when_vkey_already_present() {
  // t_vkey_10 is already in the fixture's list — `!has_key` is the only
  // assertion this violates. The output is what a naive (unguarded) insert
  // would produce: a second Pair keyed on the same vkey, which is exactly
  // the corruption this precondition exists to prevent.
  let input_datum = t_tel_datum()
  let updated_entities = pairs.insert_by_ascending_key(
    input_datum.trusted_entity_vkeys,
    t_vkey_10,
    builtin.i_data(99),
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  !run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_10, builtin.i_data(99)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test add_trusted_entity_cannot_smuggle_another_field_change() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_10, builtin.i_data(1)),
      Pair(t_vkey_20, builtin.i_data(2)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_20, builtin.i_data(2)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test add_trusted_entity_inserts_smaller_vkey_in_sorted_order() {
  // t_vkey_05 sorts BEFORE every existing entry. The expected output below
  // is written out explicitly in ascending order — not computed by calling
  // the same production helper the branch uses — so a broken sort insertion
  // in the validator itself would actually be caught here.
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_05, builtin.i_data(0)),
      Pair(t_vkey_10, builtin.i_data(1)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_05, builtin.i_data(0)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── AddTrustedEntity — datum growth caps ────────────────────────────────────

fn t_full_tel_datum(count: Int) -> GlobalStateDatum {
  GlobalStateDatum {
    ..t_datum(False, False),
    trusted_entity_vkeys: t_many_entities(count),
  }
}

test add_trusted_entity_succeeds_when_resulting_length_is_at_the_cap() {
  let input_datum = t_full_tel_datum(constants.max_trusted_entities - 1)
  let new_vkey = bytearray.from_int_big_endian(
    constants.max_trusted_entities,
    32,
  )
  let updated_entities = pairs.insert_by_ascending_key(
    input_datum.trusted_entity_vkeys,
    new_vkey,
    builtin.i_data(0),
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  run_spend(
    input_datum,
    add_trusted_entity_redeemer(new_vkey, builtin.i_data(0)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test add_trusted_entity_rejects_when_resulting_length_exceeds_the_cap() {
  let input_datum = t_full_tel_datum(constants.max_trusted_entities)
  let new_vkey = bytearray.from_int_big_endian(
    constants.max_trusted_entities + 1,
    32,
  )
  let updated_entities = pairs.insert_by_ascending_key(
    input_datum.trusted_entity_vkeys,
    new_vkey,
    builtin.i_data(0),
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  !run_spend(
    input_datum,
    add_trusted_entity_redeemer(new_vkey, builtin.i_data(0)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test add_trusted_entity_succeeds_when_metadata_is_at_the_size_cap() {
  let input_datum = t_tel_datum()
  let metadata = t_data_of_raw_length(t_metadata_len_at_cap)
  let updated_entities = pairs.insert_by_ascending_key(
    input_datum.trusted_entity_vkeys,
    t_vkey_20,
    metadata,
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_20, metadata),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test add_trusted_entity_rejects_metadata_one_byte_over_the_size_cap() {
  let input_datum = t_tel_datum()
  let metadata = t_data_of_raw_length(t_metadata_len_over_cap)
  let updated_entities = pairs.insert_by_ascending_key(
    input_datum.trusted_entity_vkeys,
    t_vkey_20,
    metadata,
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  !run_spend(
    input_datum,
    add_trusted_entity_redeemer(t_vkey_20, metadata),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── RemoveTrustedEntity — vkey must be present ──────────────────────────────

fn remove_trusted_entity_redeemer(vkey: ByteArray) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: RemoveTrustedEntity { vkey },
  }
}

test remove_trusted_entity_succeeds_when_admin_signs() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [Pair(t_vkey_30, builtin.i_data(3))],
  }
  run_spend(
    input_datum,
    remove_trusted_entity_redeemer(t_vkey_10),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test remove_trusted_entity_fails_without_admin_signature() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [Pair(t_vkey_30, builtin.i_data(3))],
  }
  !run_spend(
    input_datum,
    remove_trusted_entity_redeemer(t_vkey_10),
    t_tx(input_datum, output_datum, []),
  )
}

test remove_trusted_entity_fails_when_vkey_absent() {
  // t_vkey_20 is not present in the fixture's list at all — `has_key` is the
  // only assertion this violates; the output reproduces the input list
  // unchanged, which is what the branch's own `list.filter` would compute
  // for an absent key (a no-op), so nothing else here is what rejects it.
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: input_datum.trusted_entity_vkeys,
  }
  !run_spend(
    input_datum,
    remove_trusted_entity_redeemer(t_vkey_20),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test remove_trusted_entity_cannot_smuggle_another_field_change() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [Pair(t_vkey_30, builtin.i_data(3))],
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    remove_trusted_entity_redeemer(t_vkey_10),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── RemoveTrustedEntity — no_security_token_spent ────────────────────────

test remove_trusted_entity_succeeds_when_security_token_absent_from_tx() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [Pair(t_vkey_30, builtin.i_data(3))],
  }
  run_spend(
    input_datum,
    remove_trusted_entity_redeemer(t_vkey_10),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test remove_trusted_entity_rejects_when_an_input_carries_the_security_token() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [Pair(t_vkey_30, builtin.i_data(3))],
  }
  !run_spend(
    input_datum,
    remove_trusted_entity_redeemer(t_vkey_10),
    with_security_token_input(t_tx(input_datum, output_datum, [t_admin])),
  )
}

test remove_trusted_entity_rejects_when_the_security_token_is_minted_into_an_output() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [Pair(t_vkey_30, builtin.i_data(3))],
  }
  !run_spend(
    input_datum,
    remove_trusted_entity_redeemer(t_vkey_10),
    with_security_token_minted_into_an_output(
      t_tx(input_datum, output_datum, [t_admin]),
    ),
  )
}

// ── UpdateTrustedEntity — old present, new free (unless renaming to self), new 32 bytes ──

fn update_trusted_entity_redeemer(
  old_vkey: ByteArray,
  new_vkey: ByteArray,
  new_metadata: TrustedEntityMetadata,
) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: UpdateTrustedEntity { old_vkey, new_vkey, new_metadata },
  }
}

test update_trusted_entity_succeeds_when_admin_signs() {
  // Rename t_vkey_10 -> t_vkey_20, with new metadata.
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_20, builtin.i_data(20)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  run_spend(
    input_datum,
    update_trusted_entity_redeemer(t_vkey_10, t_vkey_20, builtin.i_data(20)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_trusted_entity_fails_without_admin_signature() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_20, builtin.i_data(20)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  !run_spend(
    input_datum,
    update_trusted_entity_redeemer(t_vkey_10, t_vkey_20, builtin.i_data(20)),
    t_tx(input_datum, output_datum, []),
  )
}

test update_trusted_entity_fails_when_old_vkey_absent() {
  // t_vkey_40 is not present — `old_exists` is the only assertion this
  // violates. new_clash_ok, the length check and the signature all hold, and
  // the output is exactly what `without_old` + `insert_by_ascending_key`
  // compute (filtering an absent key is a no-op), so equals_data would
  // otherwise also pass.
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_10, builtin.i_data(1)),
      Pair(t_vkey_20, builtin.i_data(20)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  !run_spend(
    input_datum,
    update_trusted_entity_redeemer(t_vkey_40, t_vkey_20, builtin.i_data(20)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_trusted_entity_fails_when_new_vkey_collides_with_another_entry() {
  // Renaming t_vkey_10 -> t_vkey_30 collides with the OTHER existing entry —
  // `new_clash_ok` is the only assertion this violates. The output is what
  // `without_old` (removes t_vkey_10) followed by the branch's own
  // `insert_by_ascending_key(.., t_vkey_30, ..)` actually computes: a
  // duplicate-keyed list, which is exactly the corruption this precondition
  // exists to prevent.
  let input_datum = t_tel_datum()
  let without_old = list.filter(
    input_datum.trusted_entity_vkeys,
    fn(p) { p.1st != t_vkey_10 },
  )
  let updated_entities = pairs.insert_by_ascending_key(
    without_old,
    t_vkey_30,
    builtin.i_data(30),
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  !run_spend(
    input_datum,
    update_trusted_entity_redeemer(t_vkey_10, t_vkey_30, builtin.i_data(30)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_trusted_entity_fails_when_new_vkey_wrong_length() {
  // t_vkey_bad_length is 2 bytes — `bytearray.length(new_vkey) == 32` is the
  // only assertion this violates. old_exists and new_clash_ok both hold
  // (bad_length is absent from the list), and the output is exactly what
  // the branch's own without_old + insert_by_ascending_key compute.
  let input_datum = t_tel_datum()
  let without_old = list.filter(
    input_datum.trusted_entity_vkeys,
    fn(p) { p.1st != t_vkey_10 },
  )
  let updated_entities = pairs.insert_by_ascending_key(
    without_old,
    t_vkey_bad_length,
    builtin.i_data(9),
    bytearray.compare,
  )
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: updated_entities,
  }
  !run_spend(
    input_datum,
    update_trusted_entity_redeemer(
      t_vkey_10,
      t_vkey_bad_length,
      builtin.i_data(9),
    ),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_trusted_entity_cannot_smuggle_another_field_change() {
  let input_datum = t_tel_datum()
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_20, builtin.i_data(20)),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    update_trusted_entity_redeemer(t_vkey_10, t_vkey_20, builtin.i_data(20)),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── UpdateTrustedEntity — datum growth cap ──────────────────────────────────

test update_trusted_entity_succeeds_when_new_metadata_is_at_the_size_cap() {
  let input_datum = t_tel_datum()
  let new_metadata = t_data_of_raw_length(t_metadata_len_at_cap)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_20, new_metadata),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  run_spend(
    input_datum,
    update_trusted_entity_redeemer(t_vkey_10, t_vkey_20, new_metadata),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_trusted_entity_rejects_new_metadata_one_byte_over_the_size_cap() {
  let input_datum = t_tel_datum()
  let new_metadata = t_data_of_raw_length(t_metadata_len_over_cap)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    trusted_entity_vkeys: [
      Pair(t_vkey_20, new_metadata),
      Pair(t_vkey_30, builtin.i_data(3)),
    ],
  }
  !run_spend(
    input_datum,
    update_trusted_entity_redeemer(t_vkey_10, t_vkey_20, new_metadata),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── SetRequiresSenderKyc — admin-only; guards against writing the sibling flag ──

fn set_requires_sender_kyc_redeemer(enabled: Bool) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: SetRequiresSenderKyc { enabled },
  }
}

test set_requires_sender_kyc_succeeds_when_admin_signs() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_sender_kyc: True,
  }
  run_spend(
    input_datum,
    set_requires_sender_kyc_redeemer(True),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test set_requires_sender_kyc_fails_without_admin_signature() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_sender_kyc: True,
  }
  !run_spend(
    input_datum,
    set_requires_sender_kyc_redeemer(True),
    t_tx(input_datum, output_datum, []),
  )
}

test set_requires_sender_kyc_rejects_flipping_the_other_flag() {
  // Index-transposition guard: the redeemer asks to set the SENDER flag, but
  // the output instead flips requires_receiver_kyc and leaves
  // requires_sender_kyc at its input value — the whole-datum equality must
  // catch a write landing on the wrong field index.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_receiver_kyc: True,
  }
  !run_spend(
    input_datum,
    set_requires_sender_kyc_redeemer(True),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test set_requires_sender_kyc_cannot_smuggle_another_field_change() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_sender_kyc: True,
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    set_requires_sender_kyc_redeemer(True),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── SetRequiresSenderKyc — no_security_token_spent ───────────────────────

test set_requires_sender_kyc_succeeds_when_security_token_absent_from_tx() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_sender_kyc: True,
  }
  run_spend(
    input_datum,
    set_requires_sender_kyc_redeemer(True),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test set_requires_sender_kyc_rejects_when_an_input_carries_the_security_token() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_sender_kyc: True,
  }
  !run_spend(
    input_datum,
    set_requires_sender_kyc_redeemer(True),
    with_security_token_input(t_tx(input_datum, output_datum, [t_admin])),
  )
}

test set_requires_sender_kyc_rejects_when_the_security_token_is_minted_into_an_output() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_sender_kyc: True,
  }
  !run_spend(
    input_datum,
    set_requires_sender_kyc_redeemer(True),
    with_security_token_minted_into_an_output(
      t_tx(input_datum, output_datum, [t_admin]),
    ),
  )
}

// ── SetRequiresReceiverKyc — admin-only; guards against writing the sibling flag ──

fn set_requires_receiver_kyc_redeemer(enabled: Bool) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: SetRequiresReceiverKyc { enabled },
  }
}

test set_requires_receiver_kyc_succeeds_when_admin_signs() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_receiver_kyc: True,
  }
  run_spend(
    input_datum,
    set_requires_receiver_kyc_redeemer(True),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test set_requires_receiver_kyc_fails_without_admin_signature() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_receiver_kyc: True,
  }
  !run_spend(
    input_datum,
    set_requires_receiver_kyc_redeemer(True),
    t_tx(input_datum, output_datum, []),
  )
}

test set_requires_receiver_kyc_rejects_flipping_the_other_flag() {
  // Same transposition guard, other direction: the redeemer asks to set the
  // RECEIVER flag, but the output instead flips requires_sender_kyc.
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_sender_kyc: True,
  }
  !run_spend(
    input_datum,
    set_requires_receiver_kyc_redeemer(True),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test set_requires_receiver_kyc_cannot_smuggle_another_field_change() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    requires_receiver_kyc: True,
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    set_requires_receiver_kyc_redeemer(True),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── UpdateMemberRootHash — new root must be empty or exactly 32 bytes ──────

fn update_member_root_hash_redeemer(
  new_member_root_hash: ByteArray,
) -> GlobalStateSpendRedeemer {
  GlobalStateSpendRedeemer {
    global_state_output_index: 0,
    action: UpdateMemberRootHash { new_member_root_hash },
  }
}

test update_member_root_hash_succeeds_with_32_byte_root_when_admin_signs() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    member_root_hash: t_root32,
  }
  run_spend(
    input_datum,
    update_member_root_hash_redeemer(t_root32),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_member_root_hash_fails_without_admin_signature() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    member_root_hash: t_root32,
  }
  !run_spend(
    input_datum,
    update_member_root_hash_redeemer(t_root32),
    t_tx(input_datum, output_datum, []),
  )
}

test update_member_root_hash_fails_when_length_invalid() {
  // 2 bytes — neither empty nor 32 — is the only assertion this violates;
  // mirrors sanitise_rejects_bad_root_hash_length but exercised through the
  // spend branch rather than genesis sanitisation.
  let input_datum = t_datum(False, False)
  let bad_root = #"aabb"
  let output_datum = GlobalStateDatum {
    ..input_datum,
    member_root_hash: bad_root,
  }
  !run_spend(
    input_datum,
    update_member_root_hash_redeemer(bad_root),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_member_root_hash_cannot_smuggle_another_field_change() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    member_root_hash: t_root32,
    mintable_amount: input_datum.mintable_amount + 1_000_000,
  }
  !run_spend(
    input_datum,
    update_member_root_hash_redeemer(t_root32),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_member_root_hash_accepts_clearing_back_to_empty() {
  // The other valid length, 0 bytes (no membership tree yet), is accepted
  // just like 32 — the positive control that gives the wrong-length negative
  // above its meaning: both endpoints of the "empty or 32" precondition are
  // exercised, not just the one that happens to be non-empty.
  let input_datum = GlobalStateDatum {
    ..t_datum(False, False),
    member_root_hash: t_root32,
  }
  let output_datum = GlobalStateDatum { ..input_datum, member_root_hash: #"" }
  run_spend(
    input_datum,
    update_member_root_hash_redeemer(#""),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

// ── UpdateMemberRootHash — no_security_token_spent ───────────────────────

test update_member_root_hash_succeeds_when_security_token_absent_from_tx() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    member_root_hash: t_root32,
  }
  run_spend(
    input_datum,
    update_member_root_hash_redeemer(t_root32),
    t_tx(input_datum, output_datum, [t_admin]),
  )
}

test update_member_root_hash_rejects_when_an_input_carries_the_security_token() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    member_root_hash: t_root32,
  }
  !run_spend(
    input_datum,
    update_member_root_hash_redeemer(t_root32),
    with_security_token_input(t_tx(input_datum, output_datum, [t_admin])),
  )
}

test update_member_root_hash_rejects_when_the_security_token_is_minted_into_an_output() {
  let input_datum = t_datum(False, False)
  let output_datum = GlobalStateDatum {
    ..input_datum,
    member_root_hash: t_root32,
  }
  !run_spend(
    input_datum,
    update_member_root_hash_redeemer(t_root32),
    with_security_token_minted_into_an_output(
      t_tx(input_datum, output_datum, [t_admin]),
    ),
  )
}

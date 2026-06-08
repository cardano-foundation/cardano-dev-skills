use aiken/builtin
use aiken/collection/list
use aiken/collection/pairs
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{get_element_info, run_element_with}
use cardano/assets.{PolicyId, Value, quantity_of}
use cardano/transaction.{
  InlineDatum, Mint, Output, OutputReference, Transaction, find_input,
}
use constants
use types/global_state.{
  AddTrustedEntity, GlobalStateDatum, GlobalStateSpendRedeemer, MintSecurity,
  ModifySecurityInfo, PauseTransfers, RemoveTrustedEntity, RotateAdmin,
  SetRequiresReceiverKyc, TrustedEntityMetadata, UpdateMemberRootHash,
  UpdateTrustedEntity,
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
  and {
    !datum.transfers_paused,
    datum.mintable_amount >= 0,
    bytearray.length(datum.admin_credential_hash) == 28,
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

    let global_state_output = utils.safe_list_at(
      self.outputs,
      redeemer.global_state_output_index,
    )
    expect InlineDatum(global_state_output_datum) = global_state_output.datum
    expect parsed_global_state_output_datum: GlobalStateDatum = global_state_output_datum

    // All branches share these address/NFT preservation invariants.
    let address_preserved = global_state_output.address == own_input.output.address
    // ensuring the nft is preserved is what enforces that the same global state UTxO is carried forward after the spend.
    let nft_preserved = quantity_of(
      global_state_output.value,
      global_state_policy_id,
      constants.global_state_asset_name,
    ) == 1
    // ensuring the ADA amount in the Utxo is preserverd
    let value_preserved = own_input.output.value == global_state_output.value

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
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: remaining_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: input_datum.trusted_entity_vkeys,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
        and {
          //Remaining amount must NOT be negative
          remaining_amount >= 0,
          address_preserved,
          nft_preserved,
          value_preserved,
          parsed_global_state_output_datum == expected_datum,
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

        let expected_datum = GlobalStateDatum {
          transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: input_datum.trusted_entity_vkeys,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          //Must have permission to pause/unpause transfers
          power_user_data.can_pause,
          //Must be signed by the power user
          must_be_signed_by_credential(self, power_user_credential_hash),
          parsed_global_state_output_datum == expected_datum,
        }
      }
      ModifySecurityInfo { new_security_info } -> {
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: new_security_info,
          trusted_entity_vkeys: input_datum.trusted_entity_vkeys,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          //Must be signed by the current admin (from input datum)
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          parsed_global_state_output_datum == expected_datum,
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
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: updated_entities,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          bytearray.length(vkey) == 32,
          !has_key,
          parsed_global_state_output_datum == expected_datum,
        }
      }
      RemoveTrustedEntity { vkey } -> {
        let has_key = pairs.has_key(input_datum.trusted_entity_vkeys, vkey)
        let updated_entities = list.filter(
          input_datum.trusted_entity_vkeys,
          fn(p) { p.1st != vkey },
        )
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: updated_entities,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          has_key,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          parsed_global_state_output_datum == expected_datum,
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
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: updated_entities,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          old_exists,
          new_clash_ok,
          bytearray.length(new_vkey) == 32,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          parsed_global_state_output_datum == expected_datum,
        }
      }
      SetRequiresReceiverKyc { enabled } -> {
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: input_datum.trusted_entity_vkeys,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: enabled,
        }
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          parsed_global_state_output_datum == expected_datum,
        }
      }
      UpdateMemberRootHash { new_member_root_hash } -> {
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: input_datum.admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: input_datum.trusted_entity_vkeys,
          member_root_hash: new_member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
        and {
          no_concurrent_security_mint,
          address_preserved,
          nft_preserved,
          value_preserved,
          must_be_signed_by_credential(self, input_datum.admin_credential_hash),
          parsed_global_state_output_datum == expected_datum,
        }
      }
      RotateAdmin { new_admin_credential_hash } -> {
        let expected_datum = GlobalStateDatum {
          transfers_paused: input_datum.transfers_paused,
          mintable_amount: input_datum.mintable_amount,
          admin_credential_hash: new_admin_credential_hash,
          power_user_linked_list_policy_id: input_datum.power_user_linked_list_policy_id,
          denylist_linked_list_policy_id: input_datum.denylist_linked_list_policy_id,
          security_info: input_datum.security_info,
          trusted_entity_vkeys: input_datum.trusted_entity_vkeys,
          member_root_hash: input_datum.member_root_hash,
          requires_receiver_kyc: input_datum.requires_receiver_kyc,
        }
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
          parsed_global_state_output_datum == expected_datum,
        }
      }
    }
  }

  else(_) {
    fail
  }
}

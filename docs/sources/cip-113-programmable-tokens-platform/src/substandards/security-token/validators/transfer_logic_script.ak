use aiken/collection/list
use cardano/address.{Credential, Inline, Script, VerificationKey}
use cardano/assets.{quantity_of}
use cardano/certificate.{Certificate, RegisterCredential}
use cardano/transaction.{InlineDatum, Transaction}
use constants
use denylist/absence.{verify_denylist_absence}
use env
use kyc/verify.{verify_kyc_proof}
use types/global_state.{GlobalStateDatum}
use types/transfer_logic_script.{TransferLogicScriptWithdrawRedeemer}
use utils

/// Transfer logic for a BAFIN security token (Track 4, TEL+denylist model).
///
/// Per-input check (for each unique sender stake credential):
///   1. The redeemer's matching KYC proof validates against GS.trusted_entity_vkeys
///      (signature + payload fields + TTL + tier + network + security binding).
///   2. The sender is NOT in the denylist (covering-node absence proof).
///
/// Per-output check (for each unique destination stake credential):
///   3. The destination is NOT in the denylist. No KYC required — receiving
///      is gated only by denylist absence.
///
/// Plus the pause gate (GS must not be paused).
validator transfer_logic_validator(
  security_asset_name: ByteArray,
  global_state_policy_id: ByteArray,
  registry_policy_id: ByteArray,
) {
  withdraw(
    redeemer: TransferLogicScriptWithdrawRedeemer,
    credential: Credential,
    self: Transaction,
  ) {
    let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
      self.reference_inputs,
      registry_policy_id,
      credential,
      constants.transfer_logic_script_registry_node_index,
    )

    // DIVERGES FROM UPSTREAM (mint / burn rubber-stamp):
    //
    // CIP-113's prog-logic-global requires the substandard's transfer-logic
    // withdraw to be invoked for any prog-token spend. For pure mints and
    // burns (where the prog-token policy appears in self.mint), authorisation
    // is already enforced by minting_logic_script.withdraw (which checks
    // can_mint / can_burn) and by global_state_spend.MintSecurity (which
    // enforces the supply cap). transfer_logic_script has no role in those
    // flows — its redeemer is built for transfers-with-KYC and has no burn
    // shape. We short-circuit here when a mint/burn is happening so the
    // CIP-113 plumbing keeps working without requiring a fake KYC proof.
    //
    // Detection: self.mint contains a non-zero quantity of the security
    // token. Pure transfers don't touch self.mint, so they fall through to
    // the strict path below.
    let is_mint_or_burn = quantity_of(
      self.mint,
      issuance_policy_id,
      security_asset_name,
    ) != 0
    if is_mint_or_burn {
      True
    } else {
      // 1. Resolve GS reference input and fast-check pause flag.
      let gs_input = utils.safe_list_at(
        self.reference_inputs,
        redeemer.global_state_ref_input_index,
      )
      let transfers_paused = global_state.is_paused(
        gs_input,
        global_state_policy_id,
      )

      // 2. Full-parse GS datum so we can read the TEL and denylist policy id.
      expect InlineDatum(gs_datum_raw) = gs_input.output.datum
      expect gs_datum: GlobalStateDatum = gs_datum_raw

      // 3. Aggregate unique sender stake-cred hashes from inputs carrying the
      //    security token.
      let inputs_user_stake_cred_hash = list.unique(
        list.foldr(
          self.inputs,
          [],
          fn(input, result) {
            if quantity_of(
              input.output.value,
              issuance_policy_id,
              security_asset_name,
            ) > 0 {
              expect Some(Inline(stake_cred)) = input.output.address.stake_credential
              let credential_hash = when stake_cred is {
                VerificationKey(hash) -> hash
                Script(hash) -> hash
              }
              list.push(result, credential_hash)
            } else {
              result
            }
          },
        ),
      )

      // 4. Aggregate unique destination stake-cred hashes from outputs carrying
      //    the security token.
      let outputs_user_stake_cred_hash = list.unique(
        list.foldr(
          self.outputs,
          [],
          fn(output, result) {
            if quantity_of(
              output.value,
              issuance_policy_id,
              security_asset_name,
            ) > 0 {
              expect Some(Inline(stake_cred)) = output.address.stake_credential
              let credential_hash = when stake_cred is {
                VerificationKey(hash) -> hash
                Script(hash) -> hash
              }
              list.push(result, credential_hash)
            } else {
              result
            }
          },
        ),
      )

      // 5. Per-sender: valid KYC proof + denylist absence.
      let all_senders_ok = list.indexed_foldr(
        inputs_user_stake_cred_hash,
        True,
        fn(index, sender_pkh, acc) {
          expect acc
          let action = utils.safe_list_at(
            redeemer.actions_for_each_input,
            index,
          )
          let kyc_ok = verify_kyc_proof(
            action.source_proof,
            sender_pkh,
            gs_datum,
            issuance_policy_id,
            env.network_id,
            self,
          )
          let denylist_ok = verify_denylist_absence(
            sender_pkh,
            action.source_denylist_covering_ref_input_index,
            self.reference_inputs,
            gs_datum.denylist_linked_list_policy_id,
          )
          and {
            kyc_ok,
            denylist_ok,
          }
        },
      )

      // 6. Per-destination: valid KYC proof + denylist absence. Swiss CO
      //    Art. 973e / eWpG §14 / ERC-3643 norm all demand that the recipient
      //    be KYC'd at transfer time (a named creditor / registered holder).
      let all_destinations_ok = list.indexed_foldr(
        outputs_user_stake_cred_hash,
        True,
        fn(index, dest_pkh, acc) {
          expect acc
          let action = utils.safe_list_at(redeemer.destination_actions, index)
          let kyc_ok = if gs_datum.requires_receiver_kyc {
            verify_kyc_proof(
              action.destination_proof,
              dest_pkh,
              gs_datum,
              issuance_policy_id,
              env.network_id,
              self,
            )
          } else {
            True
          }
          let denylist_ok = verify_denylist_absence(
            dest_pkh,
            action.destination_denylist_covering_ref_input_index,
            self.reference_inputs,
            gs_datum.denylist_linked_list_policy_id,
          )
          and {
            kyc_ok,
            denylist_ok,
          }
        },
      )

      and {
        //General transfers of this token must NOT be paused
        transfers_paused == False,
        all_senders_ok,
        all_destinations_ok,
      }
    }
  }

  // Whitelist RegisterCredential only — see minting_logic_script for rationale.
  // A rubber-stamp publish would let anyone de-register this script's stake
  // credential via UnregisterCredential, bricking every transfer until
  // re-registered (and paying the attacker the 2 ADA deposit refund).
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

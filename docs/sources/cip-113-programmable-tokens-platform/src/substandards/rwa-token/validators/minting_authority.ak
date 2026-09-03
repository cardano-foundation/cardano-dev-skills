use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Interval, IntervalBound, NegativeInfinity, PositiveInfinity}
use aiken/primitive/bytearray
use aiken_design_patterns/linked_list.{Element, Node, Root}
use cardano/address.{Address, Credential, Inline, Script, VerificationKey}
use cardano/assets.{Value, from_asset, from_lovelace, merge, quantity_of, zero}
use cardano/certificate.{Certificate, RegisterCredential, UnregisterCredential}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use constants
use denylist/absence.{verify_denylist_absence}
use kyc/verify.{verify_kyc_proof}
use types/global_state.{
  GlobalStateDatum, GlobalStateReferenced, GlobalStateSpent,
  gs_datum_from_location,
}
use types/kyc_proof.{Attestation, AttestationProof}
use types/minting_authority.{
  MintBurn, MintingAuthorityWithdrawRedeemer, MintingLogicDestinationAction,
  RegisterMint, RegisterStructural, UpgradeRegistryNode,
}
use types/power_users.{PowerUser}
use utils.{must_be_signed_by_credential}

/// The swappable minting authority — see the redeemer type's doc comment for
/// the trust model. This validator's OWN logic (KYC, denylist, power-user
/// roles) is exactly what "upgrading the minting path" is meant to change:
/// GlobalState.minting_script_credential_hash can be admin-rotated to a
/// DIFFERENT deployment of this same shape (a different compliance
/// integration, a bugfix, a new rule set) without ever touching
/// minting_logic_script.ak or the CIP-113 registry.
///
/// ============================================================================
/// INVARIANTS ANY REPLACEMENT AUTHORITY MUST PRESERVE
/// ============================================================================
/// minting_logic_script.ak — the permanent proxy — checks NOTHING except that
/// whichever script GlobalState names is running. That is what makes this
/// validator fully replaceable, and it means everything below is enforced
/// here or nowhere at all. A replacement that drops one of these does not
/// merely lose a feature; in the first two cases it causes damage no later
/// upgrade can undo, because the harm lands in the CIP-113 registry and in
/// circulating supply rather than in this script.
///
///   1. NO REGISTRY NODE MAY BE SPENT during a mint or burn.
///      `registry_spend`'s in-place UPDATE path mints no registry NFT and
///      demands the proxy's withdraw-0 as its "proof of instance" — which
///      this validator's approval supplies. Without the guard, anyone who
///      can get a routine mint authorised can ride along on an update that
///      re-points `transfer_logic_script` /
///      `third_party_transfer_logic_script` at permissive scripts,
///      permanently destroying transfer-side compliance. IRREVERSIBLE.
///   2. GLOBALSTATE MUST BE SPENT for any supply change, so its
///      `MintSecurity` branch runs and decrements `mintable_amount`. Merely
///      referencing it leaves the supply cap — a core CMTAT/BaFin invariant
///      — entirely unenforced. IRREVERSIBLE (tokens already exist).
///   3. ONLY `security_asset_name` may be minted under the issuance policy.
///      `issuance_mint` constrains no asset names, and the destination
///      checks only ever inspect the security asset, so a second name would
///      be minted with no KYC or denylist scrutiny at all.
///   4. THE PROTOCOL MUST NOT BE `deactivated`. Deactivation is the terminal
///      decommissioning switch and is meant to be absolute.
///   5. REGISTRATION STRUCTURE: the node must name this deployment's proxy,
///      forbid unfracking, and pin this deployment's GlobalState — AND the
///      node's own registry NFT must be minted in the same transaction.
///
///      That last clause is what makes registration a once-only event, and
///      it is load-bearing, not cosmetic. Requiring merely that SOME registry
///      NFT is minted is not enough: an admin-signed transaction can bundle a
///      throwaway insert for an unrelated token to satisfy it while this
///      token's already-registered node is spent and re-emitted through
///      `registry_spend`'s UPDATE path with `transfer_logic_script`
///      re-pointed at a permissive script. Every other structural check still
///      passes in that shape, because the base layer freezes
///      `minting_logic_script` across an update. Scoping the mint to THIS
///      node closes it — on an insert the NFT is created now, on an update it
///      is carried forward from the spent node — and, because CIP-113 keys
///      nodes by a policy id derived from the proxy hash and the linked list
///      forbids duplicate keys, no second node naming this proxy can ever be
///      inserted. Weaken this and registration becomes a stealthy, repeatable
///      vehicle for hijacking transfer compliance. IRREVERSIBLE.
/// ============================================================================
validator minting_authority_validator(
  security_asset_name: ByteArray,
  global_state_policy_id: ByteArray,
  registry_policy_id: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
  // The permanent proxy's hash (validators/minting_logic_script.ak) — used
  // to independently re-verify the registry node this transaction concerns
  // (see the redeemer type's doc comment). Not circular: the proxy never
  // takes this validator's hash as one of its own compile-time parameters,
  // so this validator is free to be compiled after the proxy, at any time,
  // including long after initial deployment — that is the whole point of
  // making this validator swappable.
  minting_logic_script_credential_hash: ByteArray,
  /// The issuance policy id this deployment mints, pinned at compile
  /// time.
  ///
  /// Every derivation below authenticates its registry node by "this node
  /// names our proxy at field 2". That IS cryptographic under CIP-113 — a
  /// node's key is derived from the minting-logic hash and the registry
  /// forbids duplicate keys — but neither guarantee is vendored, pinned or
  /// re-derived in this repository. If the deployed base
  /// layer ever fails to hold it, a node naming our proxy but keyed to a
  /// foreign policy makes `only_permitted_assets_minted` vacuous, reads
  /// `minted_amount` as 0, demotes the role check from `can_mint` to
  /// `can_burn` and skips destination vetting entirely — while the
  /// transaction mints the REAL token to a sanctioned address. This pin makes
  /// the control local instead of inherited.
  ///
  /// Not circular: `gs_policy → proxy hash → issuance_policy_id → this
  /// validator`, and this validator is compiled last (it is the swappable one).
  expected_issuance_policy_id: ByteArray,
  /// The DENYLIST SPEND VALIDATOR's script hash, threaded into
  /// `verify_denylist_absence`. See its doc comment.
  denylist_script_hash: ByteArray,
  /// The POWER-USERS SPEND VALIDATOR's script hash — not the list
  /// policy id (they are separate validators with separate hashes).
  ///
  /// Element authentication ignores the address, so a power-user NFT carried
  /// out of the list into a private wallet keeps authenticating whatever datum
  /// its holder writes. The node's KEY stays pinned to the NFT asset name — so
  /// the signature gate still binds — but the ROLE FLAGS come from the datum,
  /// which means a revoked operator retains whichever powers their old key hash
  /// signs for. Requiring the node to still live at the list's script address
  /// is what makes revocation stick.
  power_user_list_script_hash: ByteArray,
  /// The CIP-68 REFERENCE NFT's asset name, under this same issuance policy.
  ///
  /// CIP-68 puts the reference token and the user token under one policy and
  /// distinguishes them by asset-name label, so supporting it means the
  /// issuance policy must be allowed to carry a second name. That relaxation is
  /// deliberately narrow — see `only_permitted_assets_minted` for why a general
  /// one would be a compliance bypass.
  ///
  /// Set it equal to `security_asset_name` to disable CIP-68 support entirely:
  /// the security-asset arm of the allowlist matches first, so the reference
  /// arm becomes unreachable.
  reference_asset_name: ByteArray,
) {
  withdraw(
    redeemer: MintingAuthorityWithdrawRedeemer,
    _credential: Credential,
    self: Transaction,
  ) {
    // The variants differ in where this token's registry node is found — a
    // reference input in steady state, an output of this very transaction
    // during a CIP-113 insert — and in whether supply changes. In every case
    // the node is re-resolved and re-verified HERE against the proxy's known
    // hash; nothing is trusted from the proxy, which checked nothing.
    when redeemer is {
      MintBurn {
        global_state_input_index,
        power_user_node_ref_input_index,
        minted_amount,
        destination_actions,
      } -> {
        // INVARIANT 1 — see the header. A steady-state mint or burn only
        // ever REFERENCES the registry node; spending one means a
        // `registry_spend` update is riding along on this authorisation.
        expect
          !list.any(
            self.inputs,
            fn(input) {
              utils.quantity_of_policy_id(
                input.output.value,
                registry_policy_id,
              ) > 0
            },
          )
        // Decode GlobalState ONCE. The NFT check authenticates the UTxO
        // BEFORE any field of its datum is read; `!deactivated` traps
        // immediately (INVARIANT 4). The power-users list policy cross-check
        // moves here (from `verify_mint_or_burn`) so both callers — this one
        // and `RegisterMint` below — do it once, against the same decoded
        // field list, instead of the callee re-deriving it per call.
        let gs_input = utils.safe_list_at(self.inputs, global_state_input_index)
        expect
          quantity_of(
            gs_input.output.value,
            global_state_policy_id,
            constants.global_state_asset_name,
          ) == 1
        expect InlineDatum(gs_raw) = gs_input.output.datum
        let fields = builtin.unconstr_fields(gs_raw)
        expect !global_state.get_deactivated(fields)
        expect
          power_users_linked_list_policy_id == global_state.get_power_user_linked_list_policy_id(
            fields,
          )
        and {
          // Steady state mints supply and nothing else. The CIP-68 reference
          // NFT is a registration-time artefact; allowing it here would let it
          // be re-minted after the token is live.
          only_permitted_assets_minted(
            self,
            expected_issuance_policy_id,
            security_asset_name,
            reference_asset_name,
            False,
          ),
          verify_mint_or_burn(
            expected_issuance_policy_id,
            minted_amount,
            gs_raw,
            power_user_node_ref_input_index,
            destination_actions,
            security_asset_name,
            power_users_linked_list_policy_id,
            denylist_script_hash,
            power_user_list_script_hash,
            self,
          ),
        }
      }
      RegisterMint {
        registry_node_output_index,
        global_state_input_index,
        power_user_node_ref_input_index,
        minted_amount,
        destination_actions,
      } -> {
        // The registration's structural invariants are NOT a base-layer
        // duplicate: CIP-113 binds only key <-> minting logic and leaves
        // fields 3-6 free, and it never tells this authority whether an
        // insert of THIS token's node is actually happening. This call is
        // what ties `RegisterMint` to that (once-only) insert — the reason it
        // alone may mint the CIP-68 reference NFT — and what pins the free
        // fields at genesis.
        let issuance_policy_id = verify_registration_structure(
          registry_node_output_index,
          registry_policy_id,
          global_state_policy_id,
          minting_logic_script_credential_hash,
          expected_issuance_policy_id,
          self,
        )
        // Decode GlobalState ONCE — same shape as the MintBurn call site
        // above: the NFT check authenticates the UTxO before any field of
        // its datum is read, and the deactivation trap and power-users
        // cross-check both run here rather than inside `verify_mint_or_burn`.
        let gs_input = utils.safe_list_at(self.inputs, global_state_input_index)
        expect
          quantity_of(
            gs_input.output.value,
            global_state_policy_id,
            constants.global_state_asset_name,
          ) == 1
        expect InlineDatum(gs_raw) = gs_input.output.datum
        let fields = builtin.unconstr_fields(gs_raw)
        expect !global_state.get_deactivated(fields)
        expect
          power_users_linked_list_policy_id == global_state.get_power_user_linked_list_policy_id(
            fields,
          )
        let admin_credential_hash = global_state.get_admin_credential_hash(
          fields,
        )
        and {
          // Registration is the one moment the CIP-68 reference NFT may be
          // created, which is what makes it once-only: registration itself is
          // structurally once-only.
          only_permitted_assets_minted(
            self,
            issuance_policy_id,
            security_asset_name,
            reference_asset_name,
            True,
          ),
          // …and if one was minted, it must land somewhere defined.
          //
          // The `reference_asset_name != security_asset_name` half is what keeps the
          // CIP-68-OFF configuration working. Setting the two equal is the documented
          // way to disable CIP-68, and it does disable minting (the security arm of
          // `only_permitted_assets_minted` matches first, so the reference arm is
          // unreachable) — but it ALSO makes the quantity test below read the SECURITY
          // token's mint, which is > 0 for every first mint. Without this guard the
          // pinned-output check would then fire on the security token itself and demand
          // exactly one of it, so a non-CIP-68 token could only ever be registered with
          // a first mint of 1. Gate on CIP-68 actually being enabled, not on a quantity
          // that aliasing makes ambiguous.
          if and {
            reference_asset_name != security_asset_name,
            quantity_of(self.mint, issuance_policy_id, reference_asset_name) > 0,
          } {
            reference_nft_output_is_pinned(
              self,
              issuance_policy_id,
              reference_asset_name,
              security_asset_name,
              admin_credential_hash,
            )?
          } else {
            True
          },
          // The admin authorises the registration itself — CIP-113 binds the
          // node's key to the proxy but leaves its transfer-logic fields
          // free, so this signature is what stops a stranger registering the
          // token with permissive rules.
          must_be_signed_by_credential(self, admin_credential_hash)?,
          // ...and the mint half passes exactly the checks every later mint
          // gets, so a genesis mint is auditable on the same terms.
          verify_mint_or_burn(
            issuance_policy_id,
            minted_amount,
            gs_raw,
            power_user_node_ref_input_index,
            destination_actions,
            security_asset_name,
            power_users_linked_list_policy_id,
            denylist_script_hash,
            power_user_list_script_hash,
            self,
          ),
        }
      }
      UpgradeRegistryNode {
        registry_node_input_index,
        registry_node_output_index,
        global_state_location,
      } -> {
        // Purpose-binding: the node being spent must be THIS token's — i.e.
        // it must currently name this deployment's proxy. That is also what
        // makes the derived policy id ours.
        let spent_node = utils.safe_list_at(
          self.inputs,
          registry_node_input_index,
        ).output
        let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
          spent_node,
          registry_policy_id,
          minting_logic_script_credential_hash,
          constants.minting_logic_script_registry_node_index,
        )
        // The continuing-node check below already compares against this
        // id, so pinning the spent node pins both.
        expect issuance_policy_id == expected_issuance_policy_id

        // The continuing node — AUTHENTICATED, not merely indexed. Deriving
        // its policy id the same way as the spent node's asserts three things
        // at once: it carries a genuine registry NFT, it names this
        // deployment's proxy, and (by comparing the two ids below) it is the
        // SAME node rather than some other token's.
        //
        // Without this, `registry_node_output_index` could be aimed at a
        // decoy plain output holding a copy of the original clean datum,
        // while the real continuing node — the only registry-NFT output, per
        // registry_spend's `expect [cont]` — re-pointed `global_state_cs` at
        // an attacker-authored GlobalState or switched unfracking on. The two
        // field checks below would then be inspecting the decoy.
        let continuing_node = utils.safe_list_at(
          self.outputs,
          registry_node_output_index,
        )
        let continuing_policy_id = utils.derive_issuance_policy_id_from_registry_node(
          continuing_node,
          registry_policy_id,
          minting_logic_script_credential_hash,
          constants.minting_logic_script_registry_node_index,
        )
        expect continuing_policy_id == issuance_policy_id

        let out_fields: List<Data> = builtin.unconstr_fields(
          utils.expect_inline_datum(continuing_node),
        )

        // `next` backstop REMOVED: CIP-113's `registry_spend` already
        // threads `next` unchanged through an in-place field update — this
        // deployment relies on that verified base-layer guarantee rather
        // than re-checking it.
        // Registry fields 3 and 4 must stay SCRIPT credentials — same
        // requirement and rationale as `verify_registration_structure`'s
        // field-3/4 checks: a `VerificationKey` here would leave
        // `transfer_logic_script` / `third_party_transfer_logic_script`
        // unable to ever execute as transfer logic, silently disabling the
        // compliance gates every later transfer relies on. CIP-113 allows
        // both fields to change on update, so nothing else stands in the
        // way of an upgrade re-pointing them at a non-script credential.
        expect Some(out_transfer_logic_data) = list.at(
          out_fields,
          constants.transfer_logic_script_registry_node_index,
        )
        expect out_transfer_logic: Credential = out_transfer_logic_data
        expect Script(_) = out_transfer_logic

        expect Some(out_third_party_logic_data) = list.at(
          out_fields,
          constants.third_party_transfer_logic_script_registry_node_index,
        )
        expect out_third_party_logic: Credential = out_third_party_logic_data
        expect Script(_) = out_third_party_logic

        // Re-assert the two fields the base layer leaves mutable but this
        // deployment treats as permanent.
        //
        // `global_state_cs`: pinning is unambiguously right — re-pointing it
        // would aim every later compliance read at a GlobalState the caller
        // authored.
        //
        // `unfracking_logic_script`: pinning it HERE, on the upgrade path, is
        // the consequential choice — it means the hook can never be enabled
        // for this token at all, not even later by a governed upgrade. That
        // permanently forecloses the co-mingled-freeze escape hatch described
        // in `verify_registration_structure`. Relaxing just this one line
        // (while leaving registration default-deny) would make the decision
        // reversible without weakening the genesis posture. Flagged in the
        // audit report as the single highest-value change to reconsider.
        expect Some(out_unfracking_data) = list.at(
          out_fields,
          constants.unfracking_logic_script_registry_node_index,
        )
        expect out_unfracking: Credential = out_unfracking_data
        expect out_unfracking == VerificationKey(#"")

        expect Some(out_gs_cs_data) = list.at(
          out_fields,
          constants.global_state_cs_registry_node_index,
        )
        expect out_gs_cs: ByteArray = out_gs_cs_data
        expect out_gs_cs == global_state_policy_id

        let gs_datum = gs_datum_from_location(
          self.inputs,
          self.reference_inputs,
          global_state_location,
          global_state_policy_id,
        )
        and {
          // INVARIANT 4.
          !gs_datum.deactivated,
          // The one-way lock closes this path permanently.
          (!gs_datum.upgrades_locked)?,
          must_be_signed_by_credential(self, gs_datum.admin_credential_hash)?,
        }
      }
      RegisterStructural { registry_node_output_index, global_state_location } -> {
        let issuance_policy_id = verify_registration_structure(
          registry_node_output_index,
          registry_policy_id,
          global_state_policy_id,
          minting_logic_script_credential_hash,
          expected_issuance_policy_id,
          self,
        )
        let gs_datum = gs_datum_from_location(
          self.inputs,
          self.reference_inputs,
          global_state_location,
          global_state_policy_id,
        )
        and {
          // Nothing may be minted under the issuance policy at all. Without
          // this, `RegisterStructural` would be a way to mint the first
          // supply while skipping every power-user and receiver gate that
          // `RegisterMint` applies — GlobalState is only referenced here, so
          // the cap would go unenforced too.
          //
          // Checked as a SHAPE, not a sum — see `only_permitted_assets_minted`.
          // Summing would accept +N of one asset name netted against -N of
          // another under the same policy.
          dict.is_empty(assets.tokens(self.mint, issuance_policy_id))?,
          // INVARIANT 4.
          !gs_datum.deactivated,
          must_be_signed_by_credential(self, gs_datum.admin_credential_hash)?,
        }
      }
    }
  }

  // Same whitelist rationale as minting_logic_script.ak's publish handler:
  // rejecting UnregisterCredential prevents a rubber-stamp publish from
  // letting anyone de-register this script's stake credential, which would
  // brick every mint/burn the proxy tries to delegate here until
  // re-registered.
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

/// INVARIANT 3 — see the header. Only the security asset may appear under the
/// issuance policy. Checked as a SHAPE, not a sum: `quantity_of_policy_id(...)
/// == 0` would also accept +N of the security asset netted against -N of
/// another asset name under the same policy. `issuance_mint` constrains no
/// asset names — it delegates entirely to this substandard — so a second name
/// is possible, and it would be invisible to the destination checks below,
/// which only ever inspect outputs carrying `security_asset_name`.
fn only_permitted_assets_minted(
  self: Transaction,
  issuance_policy_id: ByteArray,
  security_asset_name: ByteArray,
  reference_asset_name: ByteArray,
  // Whether the CIP-68 reference NFT may be minted in THIS branch. True only
  // for `RegisterMint`; see the call sites.
  reference_mint_allowed: Bool,
) -> Bool {
  list.all(
    dict.to_pairs(assets.tokens(self.mint, issuance_policy_id)),
    fn(minted) {
      let Pair(asset_name, quantity) = minted
      if asset_name == security_asset_name {
        // Supply. Amount is governed by the cap, not here.
        True
      } else {
        and {
          // The reference NFT may only appear where a branch says so.
          reference_mint_allowed?,
          (asset_name == reference_asset_name)?,
          // An NFT, and exactly one of it. Without this the "metadata" name
          // would be a second, uncapped supply under the same policy id.
          (quantity == 1)?,
        }
      }
    },
  )
}

/// THE CIP-68 REFERENCE NFT CUSTODY DECISION.
///
/// The reference NFT is metadata, not value — it is exempt from the supply
/// cap and from the denylist and KYC gates. It is minted exactly once, here,
/// at registration (only `RegisterMint` may mint it, and registration is
/// structurally a once-only event), and this function requires it to be
/// ALONE in its own UTxO — quantity 1, no other asset of this policy
/// co-located with it — at genesis. Its owner — the inline stake credential
/// of that output — must be the GlobalState ADMIN credential, so the admin is
/// the CIP-68 metadata authority by construction: updating the metadata is
/// the admin spending this UTxO (base-layer owner consent) and re-outputting
/// the NFT with the new datum. After `RotateAdmin` the outgoing admin hands
/// the NFT to the new admin with an ordinary owner transfer (README).
///
/// Every compliance scan in this substandard (denylist, KYC, seizure) is
/// scoped to `security_asset_name` and never inspects the reference NFT, so
/// its LATER movement is governed by the base layer's owner-consent check
/// alone — nothing here re-vets a metadata update. Keeping it alone and at an
/// issuer-controlled credential is therefore an OPERATIONAL rule (documented
/// in the README), not a hot-path check: a per-transfer check guarding a
/// once-in-a-lifetime asset is not worth its cost.
///
/// The base layer's `no_escape` already confines every token of this policy —
/// the reference NFT included — to the programmable base, so the
/// programmable-base payment-credential pin stays OUT of this function; only
/// the quantity, the co-location and the owner (inline stake credential ==
/// admin) are checked here. The datum itself is not inspected.
fn reference_nft_output_is_pinned(
  self: Transaction,
  issuance_policy_id: ByteArray,
  reference_asset_name: ByteArray,
  security_asset_name: ByteArray,
  admin_credential_hash: ByteArray,
) -> Bool {
  let carriers = list.filter(
    self.outputs,
    fn(output) {
      quantity_of(output.value, issuance_policy_id, reference_asset_name) > 0
    },
  )
  when carriers is {
    [output] -> {
      expect Some(Inline(owner)) = output.address.stake_credential
      and {
        quantity_of(output.value, issuance_policy_id, reference_asset_name) == 1,
        // The admin is the CIP-68 metadata authority: the NFT's owner (its
        // inline stake credential, key or script) must be the GlobalState
        // admin credential at registration.
        utils.credential_hash(owner) == admin_credential_hash,
        // Genesis-only: the reference NFT starts life alone in its own
        // UTxO, never co-located with the first supply.
        quantity_of(output.value, issuance_policy_id, security_asset_name) == 0,
      }
    }
    _ -> False
  }
}

/// INVARIANT 5 — see the header. The CIP-113 registration's structural
/// invariants, moved here from the proxy so that they too are upgradeable.
/// Returns this token's issuance policy id, derived from the node itself.
///
/// What CIP-113 guarantees and what it does not: `registry_mint` binds `key`
/// to `minting_logic_script` cryptographically
/// (`is_programmable_token_id_valid`), so the policy id cannot lie about which
/// minting logic governs it. It binds NOTHING about `transfer_logic_script`,
/// `third_party_transfer_logic_script`, `unfracking_logic_script` or
/// `global_state_cs` — those are free fields, and this substandard's consent
/// is the only thing standing between an attacker and a registration naming
/// permissive logic scripts, which would bypass every compliance gate from
/// genesis.
fn verify_registration_structure(
  registry_node_output_index: Int,
  registry_policy_id: ByteArray,
  global_state_policy_id: ByteArray,
  minting_logic_script_credential_hash: ByteArray,
  expected_issuance_policy_id: ByteArray,
  self: Transaction,
) -> ByteArray {
  let node_output = utils.safe_list_at(self.outputs, registry_node_output_index)
  let node_fields: List<Data> = builtin.unconstr_fields(
    utils.expect_inline_datum(node_output),
  )

  // Identity + policy id in one step: asserts the registry NFT and that the
  // node names THIS deployment's proxy. An insert emits TWO registry-node
  // outputs — the new node and the re-emitted covering node — so the index
  // alone does not identify ours.
  let issuance_policy_id = utils.derive_issuance_policy_id_from_registry_node(
    node_output,
    registry_policy_id,
    minting_logic_script_credential_hash,
    constants.minting_logic_script_registry_node_index,
  )
  // See the validator parameter's doc comment.
  expect issuance_policy_id == expected_issuance_policy_id

  // INSERT only — and specifically, an insert OF THIS NODE.
  expect [Pair(node_asset_name, _)] = dict.to_pairs(
    assets.tokens(node_output.value, registry_policy_id),
  )
  expect quantity_of(self.mint, registry_policy_id, node_asset_name) == 1

  // Registry fields 3 and 4 must be SCRIPT credentials. CIP-113 leaves both
  // fields free-form, but this deployment's transfer-side compliance can
  // only run if `registry_spend`'s withdraw-0 mechanism has an actual script
  // to invoke — a `VerificationKey` here would leave
  // `transfer_logic_script` / `third_party_transfer_logic_script` unable to
  // ever execute as transfer logic, silently disabling the compliance gates
  // every later transfer relies on.
  expect Some(transfer_logic_data) = list.at(
    node_fields,
    constants.transfer_logic_script_registry_node_index,
  )
  expect transfer_logic: Credential = transfer_logic_data
  expect Script(_) = transfer_logic

  expect Some(third_party_logic_data) = list.at(
    node_fields,
    constants.third_party_transfer_logic_script_registry_node_index,
  )
  expect third_party_logic: Credential = third_party_logic_data
  expect Script(_) = third_party_logic

  // Unfracking is left FORBIDDEN (`empty_vkey` is CIP-113's
  // least-permission value; no ledger transaction can carry a withdrawal
  // keyed by an empty hash, so an unset hook is default-deny).
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

  issuance_policy_id
}

/// The mint/burn authority — ported from minting_logic_script.ak's original,
/// pre-delegation logic. `issuance_policy_id` arrives already independently
/// derived and verified by the caller (see `withdraw` above); this function
/// is otherwise a pure decision over (amounts, GlobalState, power user,
/// destinations).
///
/// GlobalState arrives ALREADY AUTHENTICATED as `gs_raw` — the raw datum
/// `Data` of a UTxO the caller has already NFT-checked. This function must
/// not re-resolve or re-authenticate it: the deactivation trap and the
/// power-users list policy cross-check both already ran at the call site,
/// against the same decoded field list. The only thing left genuinely
/// conditional on the caller's shape is the full TYPED decode, which only a
/// mint (`minted_amount > 0`) needs, for destination vetting — a burn pays
/// no decode at all.
fn verify_mint_or_burn(
  issuance_policy_id: ByteArray,
  expected_minted_amount: Int,
  gs_raw: Data,
  power_user_node_ref_input_index: Int,
  destination_actions: List<MintingLogicDestinationAction>,
  security_asset_name: ByteArray,
  power_users_linked_list_policy_id: ByteArray,
  denylist_script_hash: ByteArray,
  power_user_list_script_hash: ByteArray,
  self: Transaction,
) -> Bool {
  // Ledger truth, derived here rather than accepted from a caller so the
  // "actual vs claimed" comparison below cannot be defeated by passing a
  // matched-but-wrong pair.
  let minted_amount = quantity_of(
    self.mint,
    issuance_policy_id,
    security_asset_name,
  )

  let power_user_ref_input = utils.safe_list_at(
    self.reference_inputs,
    power_user_node_ref_input_index,
  )

  let (power_user_node_key, power_user_data) = utils.authenticated_power_user(
    power_user_ref_input.output,
    power_users_linked_list_policy_id,
    power_user_list_script_hash,
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
    expect gs_datum: GlobalStateDatum = gs_raw
    verify_mint_destinations(
      self.outputs,
      destination_actions,
      [],
      issuance_policy_id,
      security_asset_name,
      gs_datum,
      power_user_node_key,
      denylist_script_hash,
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
    // A zero-amount mint — e.g. a `RegisterMint` that mints only the CIP-68
    // reference NFT, with no initial supply — removes nothing from
    // circulation, so it is a MINT, not a burn: gating it on `can_burn`
    // would let a burn-only operator perform what is structurally a mint
    // action merely because its supply delta happens to be zero.
    //If minted_amount >= 0, power user must be minter
    //If minted_amount < 0, power user must be burner
    if minted_amount >= 0 {
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
/// attestation — is documented at the call site in `verify_mint_or_burn`.
fn verify_mint_destinations(
  outputs: List<Output>,
  actions: List<MintingLogicDestinationAction>,
  seen: List<Credential>,
  issuance_policy_id: ByteArray,
  security_asset_name: ByteArray,
  gs_datum: GlobalStateDatum,
  power_user_node_key: ByteArray,
  denylist_script_hash: ByteArray,
  self: Transaction,
) -> Bool {
  when outputs is {
    [] -> True
    [output, ..rest_outputs] ->
      if quantity_of(output.value, issuance_policy_id, security_asset_name) > 0 {
        // The base layer's `no_escape` already forbids any token of this
        // policy at a non-programmable-base output, so only the inline
        // STAKE credential — the owner identity — needs reading here. An
        // enterprise address (no stake credential at all) still traps.
        // Carry the full `Credential` — a key and a script sharing a hash
        // are different holders, and `seen` must dedupe on both halves or the
        // second of the pair would inherit the first's vetting.
        expect Some(Inline(dest_credential)) = output.address.stake_credential
        let dest_pkh = utils.credential_hash(dest_credential)
        if list.has(seen, dest_credential) {
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
            denylist_script_hash,
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
                //
                // Compared on the BARE HASH deliberately: a power-user
                // node's key is a bare 28-byte hash with no constructor
                // recorded, so there is nothing to compare the other half
                // against. The exemption is only from RECEIVER KYC — the
                // denylist check below still applies to this destination — so
                // the conservative reading (either credential form of the
                // operator's own hash is exempt) is acceptable. Recording the
                // constructor in the power-user node datum would tighten it.
                dest_pkh == power_user_node_key,
                // …or a valid KYC proof is presented for the receiver.
                verify_kyc_proof(
                  action.destination_proof,
                  dest_credential,
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
              denylist_script_hash,
            ),
            verify_mint_destinations(
              rest_outputs,
              rest_actions,
              [dest_credential, ..seen],
              issuance_policy_id,
              security_asset_name,
              gs_datum,
              power_user_node_key,
              denylist_script_hash,
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
          denylist_script_hash,
          self,
        )
      }
  }
}

// ============================================================================
// Tests
// ============================================================================
//
// Fixtures follow the aiken-design-patterns linked-list conventions verified
// against the vendored library: an element UTxO carries exactly ADA + one
// list NFT, an inline `Element` datum, and no reference script.

const test_security_asset_name: ByteArray = "SEC"

// CIP-68 reference NFT name, under the SAME issuance policy. Real deployments
// use the (100) label prefix; the validator treats it as an opaque name.
const test_reference_asset_name: ByteArray = "REF"

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

// The permanent proxy's hash (validators/minting_logic_script.ak) — this
// deployment's minting_logic_script_credential_hash compile-time parameter.
// The registry node names THIS, never this authority's own credential.
const test_proxy_hash: ByteArray =
  #"f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1"

// This authority's own credential — irrelevant to its checks (it never
// compares anything against its own hash), but supplied to `withdraw` the
// same way the ledger would.
const test_authority_hash: ByteArray =
  #"f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4"

const test_transfer_logic_hash: ByteArray =
  #"f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2"

const test_third_party_logic_hash: ByteArray =
  #"f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3"

const test_pu_credential_hash: ByteArray =
  #"01010101010101010101010101010101010101010101010101010101"

const test_dest_stake_hash: ByteArray =
  #"02020202020202020202020202020202020202020202020202020202"

// The list SPEND validators' hashes — deliberately distinct from the
// list POLICY ids above, because `denylist_validator`/`power_users_validator`
// (spend) and their `mint` counterparts are separate validators with separate
// hashes. The fixtures below place list nodes at THESE addresses; a node
// anywhere else must now be rejected.
const test_denylist_script_hash: ByteArray =
  #"d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0"

const test_pu_script_hash: ByteArray =
  #"d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1"

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
  unfracking_logic_script: Credential,
  global_state_cs: ByteArray,
}

fn test_out_ref(ix: Int) -> OutputReference {
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
    output_index: ix,
  }
}

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
    // Irrelevant here — this field only matters to the PROXY's own
    // self-authorisation guard, which this validator never checks.
    minting_script_credential_hash: test_authority_hash,
    upgrades_locked: False,
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

const test_admin_hash: ByteArray =
  #"0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a"

// GlobalState carrying a real admin credential, as a REFERENCE input — the
// shape a structural registration uses (nothing is minted, so there is no
// cap to enforce and no reason to spend it).
fn make_gs_ref_input_with(deactivated: Bool) -> Input {
  let base = make_gs_input(False)
  expect InlineDatum(raw) = base.output.datum
  expect gs_datum: GlobalStateDatum = raw
  Input {
    output_reference: test_out_ref(5),
    output: Output {
      ..base.output,
      datum: InlineDatum(
        GlobalStateDatum {
          ..gs_datum,
          admin_credential_hash: test_admin_hash,
          deactivated,
        },
      ),
    },
  }
}

fn make_gs_ref_input() -> Input {
  make_gs_ref_input_with(False)
}

// The same GlobalState, SPENT — the shape a registration carrying a mint
// uses, so that `MintSecurity` runs and enforces the cap.
fn make_gs_input_with_admin() -> Input {
  Input { ..make_gs_ref_input(), output_reference: test_out_ref(0) }
}

fn make_gs_ref_input_deactivated() -> Input {
  make_gs_ref_input_with(True)
}

fn make_gs_ref_input_locked() -> Input {
  let base = make_gs_ref_input()
  expect InlineDatum(raw) = base.output.datum
  expect gs_datum: GlobalStateDatum = raw
  Input {
    ..base,
    output: Output {
      ..base.output,
      datum: InlineDatum(GlobalStateDatum { ..gs_datum, upgrades_locked: True }),
    },
  }
}

// The mint-path GlobalState input (SPENT — `make_gs_input`'s shape), but
// with its `power_user_linked_list_policy_id` field overridden. Models a
// mis-deployment where the datum's genesis-set copy of the list policy id
// disagrees with this validator's compile-time parameter.
fn make_gs_input_with_pu_policy(pu_policy_id: ByteArray) -> Input {
  let base = make_gs_input(False)
  expect InlineDatum(raw) = base.output.datum
  expect gs_datum: GlobalStateDatum = raw
  Input {
    ..base,
    output: Output {
      ..base.output,
      datum: InlineDatum(
        GlobalStateDatum {
          ..gs_datum,
          power_user_linked_list_policy_id: pu_policy_id,
        },
      ),
    },
  }
}

// A registry node output that ENABLES unfracking — must be rejected.
fn make_registry_node_output_with_unfracking() -> Output {
  let node = TestRegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_proxy_hash),
    transfer_logic_script: Script(test_transfer_logic_hash),
    third_party_transfer_logic_script: Script(test_third_party_logic_hash),
    unfracking_logic_script: Script(test_pu_credential_hash),
    global_state_cs: test_gs_policy_id,
  }
  Output { ..make_registry_ref_input().output, datum: InlineDatum(node) }
}

// A registry node whose TRANSFER-LOGIC field (3) names a VerificationKey
// instead of a script. CIP-113 leaves the field free-form; this deployment
// requires it to be script-gated so the transfer path can actually run.
fn make_registry_node_output_with_vkey_transfer_logic() -> Output {
  let node = TestRegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_proxy_hash),
    transfer_logic_script: VerificationKey(test_transfer_logic_hash),
    third_party_transfer_logic_script: Script(test_third_party_logic_hash),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: test_gs_policy_id,
  }
  Output { ..make_registry_ref_input().output, datum: InlineDatum(node) }
}

// Same, but the THIRD-PARTY transfer-logic field (4) is the one that names a
// VerificationKey instead of a script.
fn make_registry_node_output_with_vkey_third_party_logic() -> Output {
  let node = TestRegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_proxy_hash),
    transfer_logic_script: Script(test_transfer_logic_hash),
    third_party_transfer_logic_script: VerificationKey(
      test_third_party_logic_hash,
    ),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: test_gs_policy_id,
  }
  Output { ..make_registry_ref_input().output, datum: InlineDatum(node) }
}

/// A registry node that NAMES THIS DEPLOYMENT'S PROXY at field 2 — so it
/// satisfies `derive_issuance_policy_id_from_registry_node`'s identity
/// assertion — but whose `key` is a foreign policy id.
///
/// CIP-113 is supposed to make this unconstructible: a node's key is derived
/// from the minting-logic hash and the registry forbids duplicate keys. That
/// That guarantee lives in the BASE LAYER, which this repository neither
/// vendors nor pins — which is exactly why `expected_issuance_policy_id`
/// exists. These fixtures model the world where that guarantee fails.
fn make_registry_node_output_with_foreign_key() -> Output {
  let node = TestRegistryNode {
    key: #"9999999999999999999999999999999999999999999999999999999999",
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_proxy_hash),
    transfer_logic_script: Script(test_transfer_logic_hash),
    third_party_transfer_logic_script: Script(test_third_party_logic_hash),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: test_gs_policy_id,
  }
  Output { ..make_registry_ref_input().output, datum: InlineDatum(node) }
}

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
        payment_credential: Script(test_pu_script_hash),
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
// `has_any_nft_strict` locates it; field 2 must equal the PROXY's known
// hash — never this authority's own credential.
fn make_registry_ref_input() -> Input {
  let node = TestRegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_proxy_hash),
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

// A registry node belonging to a DIFFERENT programmable token — same
// registry policy, well-formed single NFT, but its `minting_logic_script`
// names neither this deployment's proxy nor anything related. Models the
// reference input a transaction picks up when it moves a second
// programmable token alongside this one.
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
        payment_credential: Script(test_denylist_script_hash),
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
// node cannot witness its absence.
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
        payment_credential: Script(test_denylist_script_hash),
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

fn make_dest_output(amount: Int) -> Output {
  make_dest_output_for(amount, test_dest_stake_hash)
}

fn make_dest_output_for(amount: Int, stake_hash: ByteArray) -> Output {
  Output {
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

/// `run_withdraw` with CIP-68 switched OFF the documented way: `reference_asset_name`
/// set equal to `security_asset_name`. The reference arm of the mint allowlist then
/// becomes unreachable, because the security arm matches first.
fn run_withdraw_cip68_disabled(
  redeemer: MintingAuthorityWithdrawRedeemer,
  tx: Transaction,
) {
  minting_authority_validator.withdraw(
    test_security_asset_name,
    test_gs_policy_id,
    test_registry_policy_id,
    test_pu_policy_id,
    test_proxy_hash,
    test_issuance_policy_id,
    test_denylist_script_hash,
    test_pu_script_hash,
    test_security_asset_name,
    redeemer,
    Script(test_authority_hash),
    tx,
  )
}

fn run_withdraw(redeemer: MintingAuthorityWithdrawRedeemer, tx: Transaction) {
  minting_authority_validator.withdraw(
    test_security_asset_name,
    test_gs_policy_id,
    test_registry_policy_id,
    test_pu_policy_id,
    test_proxy_hash,
    test_issuance_policy_id,
    test_denylist_script_hash,
    test_pu_script_hash,
    test_reference_asset_name,
    redeemer,
    Script(test_authority_hash),
    tx,
  )
}

// ── destination verification ─────────────────────────────────────────────────

test mint_succeeds_with_clean_destination_no_receiver_kyc() {
  let amount = 1_000
  let redeemer = MintBurn {
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
  let amount = 1_000
  let redeemer = MintBurn {
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

test mint_fails_when_receiver_kyc_required_but_proof_invalid() {
  let amount = 1_000
  let redeemer = MintBurn {
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
  let amount = 1_000
  let redeemer = MintBurn {
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
  let amount = 1_000
  let redeemer = MintBurn {
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

test mint_to_enterprise_address_is_rejected() fail {
  let amount = 1_000
  let redeemer = MintBurn {
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

// ── power-user authorisation ─────────────────────────────────────────────────

test mint_authority_withdraw_fails_when_not_signed_by_power_user() {
  let amount = 1_000
  let redeemer = MintBurn {
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

test mint_authority_withdraw_fails_when_minting_without_mint_permission() {
  let amount = 1_000
  let redeemer = MintBurn {
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

// ── power-user list policy id cross-check ────────────────────────────────────

test mint_succeeds_when_global_state_power_user_policy_id_matches() {
  // POSITIVE CONTROL. Same shape as `mint_succeeds_with_clean_destination_no_receiver_kyc`,
  // spelled out explicitly here so it differs from the negative test below in
  // exactly the GlobalState input's `power_user_linked_list_policy_id`.
  let amount = 1_000
  let redeemer = MintBurn {
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  run_withdraw(
    redeemer,
    Transaction {
      ..make_withdraw_tx(
        amount,
        True,
        False,
        False,
        make_denylist_root_ref_input(),
        [make_dest_output(amount)],
        [test_pu_credential_hash],
      ),
      inputs: [make_gs_input_with_pu_policy(test_pu_policy_id)],
    },
  )
}

test mint_fails_when_global_state_power_user_policy_id_mismatches() fail {
  // The GlobalState datum's own `power_user_linked_list_policy_id` must
  // agree with this deployment's compile-time parameter (`test_pu_policy_id`,
  // as supplied by `run_withdraw`). Traps at the cross-check `expect` in
  // `verify_mint_or_burn`, before the power-user node is even looked up.
  let amount = 1_000
  let redeemer = MintBurn {
    global_state_input_index: 0,
    power_user_node_ref_input_index: 0,
    minted_amount: amount,
    destination_actions: [clean_dest_action()],
  }
  run_withdraw(
    redeemer,
    Transaction {
      ..make_withdraw_tx(
        amount,
        True,
        False,
        False,
        make_denylist_root_ref_input(),
        [make_dest_output(amount)],
        [test_pu_credential_hash],
      ),
      inputs: [
        make_gs_input_with_pu_policy(
          #"9999999999999999999999999999999999999999999999999999999999",
        ),
      ],
    },
  )
}

// ── registry read removed from MintBurn ──────────────────────────────────────
//
// The three tests formerly here (resolving among decoy registry nodes,
// rejecting a wrong index, rejecting a node that names neither the proxy nor
// itself) pinned MintBurn's independent re-derivation of the issuance policy
// from a redeemer-cited registry node. That re-derivation is gone: the
// policy is pinned at compile time, and the base layer already authenticates
// whichever node invoked this withdraw-0. This positive test replaces them —
// proving the removal is real by omitting the registry node entirely.

test mint_succeeds_without_any_registry_reference_input() {
  // No registry node anywhere in this transaction — reference inputs are
  // power-user node (0) and denylist root (1); the registry node every
  // other fixture above keeps, unused, at index 1 is simply absent here.
  let amount = 1_000
  let redeemer = MintBurn {
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
  run_withdraw(
    redeemer,
    Transaction {
      ..make_withdraw_tx(
        amount,
        True,
        False,
        False,
        make_denylist_root_ref_input(),
        [make_dest_output(amount)],
        [test_pu_credential_hash],
      ),
      reference_inputs: [
        make_pu_node_ref_input(True, False),
        make_denylist_root_ref_input(),
      ],
    },
  )
}

// ── RegisterMint: the first mint, node reached via self.outputs ─────────────
//
// The proxy owns the registration's structural invariants and admin gate;
// this variant authorises only the mint riding along with it, on exactly the
// same terms as steady-state MintBurn. The node is an OUTPUT here because at
// insert time it does not exist as a UTxO yet.

fn make_register_mint_tx(
  amount: Int,
  can_mint: Bool,
  node_output: Output,
  signatories: List<ByteArray>,
) -> Transaction {
  let base = make_withdraw_tx(
    amount,
    can_mint,
    False,
    False,
    make_denylist_root_ref_input(),
    [make_dest_output(amount)],
    signatories,
  )
  Transaction {
    ..base,
    inputs: [make_gs_input_with_admin()],
    // reference_inputs: 0 = power-user node, 1 = denylist root. The registry
    // node is deliberately absent — it only exists as an output.
    reference_inputs: [
      make_pu_node_ref_input(can_mint, False),
      make_denylist_root_ref_input(),
    ],
    outputs: list.push(base.outputs, node_output),
    // A RegistryInsert mints exactly one registry node NFT; that is what
    // distinguishes a registration from an in-place node update.
    mint: merge(base.mint, from_asset(test_registry_policy_id, "Node", 1)),
    // The admin authorises the registration; `signatories` varies only the
    // power-user half so each negative test isolates one condition.
    extra_signatories: list.push(signatories, test_admin_hash),
  }
}

fn register_mint_redeemer(amount: Int) -> MintingAuthorityWithdrawRedeemer {
  RegisterMint {
    registry_node_output_index: 0,
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

test register_mint_succeeds_resolving_the_node_from_outputs() {
  run_withdraw(
    register_mint_redeemer(1_000),
    make_register_mint_tx(
      1_000,
      True,
      make_registry_ref_input().output,
      [test_pu_credential_hash],
    ),
  )
}

test register_mint_fails_without_power_user_signature() {
  !run_withdraw(
    register_mint_redeemer(1_000),
    make_register_mint_tx(1_000, True, make_registry_ref_input().output, []),
  )
}

test register_mint_fails_when_power_user_cannot_mint() {
  !run_withdraw(
    register_mint_redeemer(1_000),
    make_register_mint_tx(
      1_000,
      False,
      make_registry_ref_input().output,
      [test_pu_credential_hash],
    ),
  )
}

test register_mint_fails_when_amount_disagrees() {
  // The redeemer's claimed amount is cross-checked against ledger truth.
  !run_withdraw(
    register_mint_redeemer(999),
    make_register_mint_tx(
      1_000,
      True,
      make_registry_ref_input().output,
      [test_pu_credential_hash],
    ),
  )
}

test register_mint_fails_when_node_output_names_another_minting_logic() fail {
  // The decoy node is a genuine registry node for a DIFFERENT token, so it
  // must not be usable to derive this token's issuance policy — otherwise a
  // redeemer could point at an unrelated policy and make every check below
  // vacuous while a real mint proceeded unchecked.
  run_withdraw(
    register_mint_redeemer(1_000),
    make_register_mint_tx(
      1_000,
      True,
      make_decoy_registry_ref_input().output,
      [test_pu_credential_hash],
    ),
  )
}

// ── zero-amount mint is a mint, not a burn ───────────────────────────────────

// A registration whose first mint carries NO initial supply — only the
// CIP-68 reference NFT. Mirrors `make_register_mint_tx`, but threads
// `can_burn` through independently (that fixture hardcodes it to `False`)
// so a can-burn-only operator can be modelled, and layers the reference NFT
// mint/output on top.
fn make_register_mint_reference_only_tx(
  can_mint: Bool,
  can_burn: Bool,
) -> Transaction {
  let amount = 0
  let base = make_withdraw_tx(
    amount,
    can_mint,
    can_burn,
    False,
    make_denylist_root_ref_input(),
    [],
    [test_pu_credential_hash],
  )
  Transaction {
    ..base,
    inputs: [make_gs_input_with_admin()],
    reference_inputs: [
      make_pu_node_ref_input(can_mint, can_burn),
      make_denylist_root_ref_input(),
    ],
    outputs: [make_registry_ref_input().output, make_reference_nft_output()],
    mint: merge(
      merge(base.mint, from_asset(test_registry_policy_id, "Node", 1)),
      from_asset(test_issuance_policy_id, test_reference_asset_name, 1),
    ),
    extra_signatories: [test_pu_credential_hash, test_admin_hash],
  }
}

test register_mint_reference_only_succeeds_with_mint_only_operator() {
  // A `RegisterMint` that carries no initial supply — only the CIP-68
  // reference NFT — mints ZERO of the security asset. That is still a MINT
  // (see the role-gate doc comment in `verify_mint_or_burn`), so a
  // `can_mint`-only operator must be able to authorise it.
  run_withdraw(
    register_mint_redeemer(0),
    make_register_mint_reference_only_tx(True, False),
  )
}

test register_mint_reference_only_fails_with_burn_only_operator() {
  // Same transaction, differing in exactly the power user's role flags: a
  // `can_burn`-only operator must not be able to authorise a zero-amount
  // mint just because the supply delta happens to read as non-positive
  // under the old `> 0` gate.
  !run_withdraw(
    register_mint_redeemer(0),
    make_register_mint_reference_only_tx(False, True),
  )
}

// ── RegisterStructural: registration with no mint ───────────────────────────

fn make_register_structural_tx(
  extra_issuance_mint: Value,
  signatories: List<ByteArray>,
) -> Transaction {
  Transaction {
    ..make_withdraw_tx(
      0,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [],
      signatories,
    ),
    reference_inputs: [make_gs_ref_input()],
    outputs: [make_registry_ref_input().output],
    mint: merge(
      from_asset(test_registry_policy_id, "Node", 1),
      extra_issuance_mint,
    ),
  }
}

fn register_structural_redeemer() -> MintingAuthorityWithdrawRedeemer {
  RegisterStructural {
    registry_node_output_index: 0,
    global_state_location: GlobalStateReferenced {
      global_state_ref_input_index: 0,
    },
  }
}

// ── CIP-68: a second asset name under the issuance policy ───────────────────
//
// The compliance layer identifies "the token" by ASSET NAME, while the CIP-113
// base layer gates and confines by POLICY. The mint allowlist is what keeps
// those two views the same set. Relaxing it for CIP-68 is therefore only safe
// while the extra name is known, quantity-capped, and creatable exactly once —
// these tests pin all three.

/// A reference-NFT output: at the programmable base, with an owner.
/// Owned by the GlobalState admin (`test_admin_hash`), as
/// `reference_nft_output_is_pinned` requires.
fn make_reference_nft_output() -> Output {
  Output {
    address: Address {
      payment_credential: Script(test_plb_hash),
      stake_credential: Some(Inline(VerificationKey(test_admin_hash))),
    },
    value: merge(
      from_lovelace(2_000_000),
      from_asset(test_issuance_policy_id, test_reference_asset_name, 1),
    ),
    datum: InlineDatum(builtin.constr_data(0, [])),
    reference_script: None,
  }
}

/// A registration that also mints the CIP-68 reference NFT alongside the first
/// supply. POSITIVE control — without it the negatives below would pass even if
/// the whole branch were broken.
fn register_mint_with_reference_tx(extra_qty: Int, out: Output) -> Transaction {
  let amount = 1_000
  let base = make_register_mint_tx(
    amount,
    True,
    make_registry_ref_input().output,
    [test_pu_credential_hash],
  )
  Transaction {
    ..base,
    mint: merge(
      base.mint,
      from_asset(test_issuance_policy_id, test_reference_asset_name, extra_qty),
    ),
    // APPEND: the registry node must stay at output index 0, which is what
    // `register_mint_redeemer` names. `list.push` would prepend.
    outputs: list.concat(base.outputs, [out]),
  }
}

// REGRESSION. Disabling CIP-68 by aliasing `reference_asset_name` to
// `security_asset_name` must not break an ordinary registration.
//
// The aliasing makes `quantity_of(self.mint, .., reference_asset_name)` read the
// SECURITY token's mint, which is > 0 for every first mint. An earlier revision
// gated the reference-NFT output check on that quantity alone, so the check fired
// on the security token itself and demanded exactly one of it — meaning a
// non-CIP-68 token could only ever be registered with a first mint of 1. A mint of
// 1_000 is the case that exposes it.
test register_mint_with_cip68_disabled_allows_a_multi_unit_first_mint() {
  run_withdraw_cip68_disabled(
    register_mint_redeemer(1_000),
    make_register_mint_tx(
      1_000,
      True,
      make_registry_ref_input().output,
      [test_pu_credential_hash],
    ),
  )
}

test register_mint_may_also_mint_the_cip68_reference_nft() {
  run_withdraw(
    register_mint_redeemer(1_000),
    register_mint_with_reference_tx(1, make_reference_nft_output()),
  )
}

/// NEGATIVE TWIN. POSITIVE CONTROL:
/// `register_mint_may_also_mint_the_cip68_reference_nft`, whose reference-NFT
/// output differs from this one in exactly the stake credential
/// (`Some(Inline(...))` there, `None` here). With no stake credential,
/// `reference_nft_output_is_pinned`'s
/// `expect Some(Inline(_owner)) = output.address.stake_credential` traps —
/// hence `fail`.
test register_mint_rejects_a_reference_nft_without_stake_credential() fail {
  run_withdraw(
    register_mint_redeemer(1_000),
    register_mint_with_reference_tx(
      1,
      Output {
        ..make_reference_nft_output(),
        address: Address {
          payment_credential: Script(test_plb_hash),
          stake_credential: None,
        },
      },
    ),
  )
}

/// The reference NFT is an NFT. Two of them would be a second, uncapped supply
/// under the security token's own policy id.
test register_mint_rejects_a_reference_quantity_above_one() {
  !run_withdraw(
    register_mint_redeemer(1_000),
    register_mint_with_reference_tx(
      2,
      Output {
        ..make_reference_nft_output(),
        value: merge(
          from_lovelace(2_000_000),
          from_asset(test_issuance_policy_id, test_reference_asset_name, 2),
        ),
      },
    ),
  )
}

/// NEGATIVE TWIN of `register_mint_may_also_mint_the_cip68_reference_nft`.
/// THE CIP-68 CUSTODY DECISION: the reference NFT must start life ALONE in
/// its own UTxO. Here it shares ONE output with the first supply instead —
/// `co_located_dest` carries both `test_reference_asset_name` and 1_000 of
/// `test_security_asset_name` — which `reference_nft_output_is_pinned`'s new
/// genesis-only conjunct (`quantity_of(.., security_asset_name) == 0`)
/// exists to catch.
///
/// Rejection is a clean `False`, not a trap: `reference_nft_output_is_pinned`
/// returns a `Bool` through `?` (trace-on-false, not `expect`) into the
/// `RegisterMint` branch's `and { }`, so a failing conjunct there just makes
/// the whole branch — and `withdraw` — return `False`. Hence `!run_withdraw`,
/// not `fail`.
test register_mint_rejects_a_reference_nft_co_located_with_supply() {
  let amount = 1_000
  let base = make_register_mint_tx(
    amount,
    True,
    make_registry_ref_input().output,
    [test_pu_credential_hash],
  )
  let co_located_dest = Output {
    ..make_dest_output(amount),
    value: merge(
      make_dest_output(amount).value,
      from_asset(test_issuance_policy_id, test_reference_asset_name, 1),
    ),
  }
  !run_withdraw(
    register_mint_redeemer(amount),
    Transaction {
      ..base,
      // Same node at index 0 (what `register_mint_redeemer` names); the
      // supply output at index 1 now also carries the reference NFT, in
      // place of the reference NFT's own output.
      outputs: [make_registry_ref_input().output, co_located_dest],
      mint: merge(
        base.mint,
        from_asset(test_issuance_policy_id, test_reference_asset_name, 1),
      ),
    },
  )
}

/// NEGATIVE TWIN of `register_mint_may_also_mint_the_cip68_reference_nft`:
/// the reference-NFT output differs from the positive control in exactly its
/// inline stake credential — a non-admin key (`test_dest_stake_hash`) instead
/// of the GlobalState admin. `reference_nft_output_is_pinned`'s owner conjunct
/// is a plain `Bool` through `?`, so the rejection is a clean `False` — hence
/// `!run_withdraw`, not `fail`.
test register_mint_rejects_a_reference_nft_not_owned_by_the_admin() {
  !run_withdraw(
    register_mint_redeemer(1_000),
    register_mint_with_reference_tx(
      1,
      Output {
        ..make_reference_nft_output(),
        address: Address {
          payment_credential: Script(test_plb_hash),
          stake_credential: Some(Inline(VerificationKey(test_dest_stake_hash))),
        },
      },
    ),
  )
}

/// THE CORE PROTECTION, UNCHANGED. Any name that is neither the security asset
/// nor the declared reference NFT is still refused. Without this the second
/// name would be uncapped, unvetted at mint, and — because the transfer path
/// filters by asset name — movable with no denylist or KYC check at all.
test register_mint_rejects_an_unknown_third_asset_name() {
  let amount = 1_000
  let base = make_register_mint_tx(
    amount,
    True,
    make_registry_ref_input().output,
    [test_pu_credential_hash],
  )
  !run_withdraw(
    register_mint_redeemer(amount),
    Transaction {
      ..base,
      mint: merge(
        base.mint,
        from_asset(test_issuance_policy_id, "SHADOW", 1_000_000),
      ),
    },
  )
}

/// Steady state mints supply and nothing else. Allowing the reference NFT here
/// would let it be re-minted after the token is live, defeating the once-only
/// property that registration gives it.
test steady_state_mint_rejects_the_reference_nft() {
  let amount = 1_000
  let base = make_withdraw_tx(
    amount,
    True,
    False,
    False,
    make_denylist_root_ref_input(),
    [make_dest_output(amount)],
    [test_pu_credential_hash],
  )
  !run_withdraw(
    MintBurn {
      global_state_input_index: 0,
      power_user_node_ref_input_index: 0,
      minted_amount: amount,
      destination_actions: [clean_dest_action()],
    },
    Transaction {
      ..base,
      mint: merge(
        base.mint,
        from_asset(test_issuance_policy_id, test_reference_asset_name, 1),
      ),
      outputs: list.concat(base.outputs, [make_reference_nft_output()]),
    },
  )
}

/// Issuance-policy pin, `RegisterMint`. `validators/regression.ak` covers the
/// `MintBurn` branch; this covers the pin inside `verify_registration_structure`.
/// The node names this deployment's proxy, so the pre-existing identity
/// assertion PASSES — only `expected_issuance_policy_id` rejects it. `expect`,
/// so `fail`.
test register_mint_fails_when_node_is_keyed_to_a_foreign_policy() fail {
  let amount = 1_000
  run_withdraw(
    register_mint_redeemer(amount),
    make_register_mint_tx(
      amount,
      True,
      make_registry_node_output_with_foreign_key(),
      [test_pu_credential_hash],
    ),
  )
}

test register_structural_succeeds_when_admin_signs() {
  run_withdraw(
    register_structural_redeemer(),
    make_register_structural_tx(zero, [test_admin_hash]),
  )
}

/// Issuance-policy pin, `RegisterStructural` — the same shared
/// `verify_registration_structure` pin, reached through the other caller.
test register_structural_fails_when_node_is_keyed_to_a_foreign_policy() fail {
  run_withdraw(
    register_structural_redeemer(),
    Transaction {
      ..make_register_structural_tx(zero, [test_admin_hash]),
      outputs: [make_registry_node_output_with_foreign_key()],
    },
  )
}

test register_structural_fails_without_admin_signature() {
  !run_withdraw(
    register_structural_redeemer(),
    make_register_structural_tx(zero, []),
  )
}

test register_structural_fails_when_it_actually_mints() {
  // Otherwise this variant would be a way to mint the first supply while
  // skipping every power-user and receiver gate RegisterMint applies — and
  // with GlobalState only referenced, the cap would go unenforced too.
  !run_withdraw(
    register_structural_redeemer(),
    make_register_structural_tx(
      from_asset(test_issuance_policy_id, test_security_asset_name, 1_000),
      [test_admin_hash],
    ),
  )
}

test register_structural_fails_when_deactivated() fail {
  let base = make_register_structural_tx(zero, [test_admin_hash])
  run_withdraw(
    register_structural_redeemer(),
    Transaction { ..base, reference_inputs: [make_gs_ref_input_deactivated()] },
  )
}

test register_structural_fails_when_unfracking_is_enabled() fail {
  // INVARIANT 5: unfracking would let a holder split this policy out of a
  // shared UTxO without its transfer logic ever running.
  let base = make_register_structural_tx(zero, [test_admin_hash])
  run_withdraw(
    register_structural_redeemer(),
    Transaction {
      ..base,
      outputs: [make_registry_node_output_with_unfracking()],
    },
  )
}

test register_structural_fails_when_transfer_logic_is_not_a_script() fail {
  // Field 3 must be script-gated so the transfer side actually runs — a
  // `VerificationKey` here would make `transfer_logic_script` unable to
  // ever execute as transfer logic. POSITIVE CONTROL:
  // `register_structural_succeeds_when_admin_signs`, whose node (via
  // `make_register_structural_tx` -> `make_registry_ref_input`) differs
  // from this one in exactly this field.
  let base = make_register_structural_tx(zero, [test_admin_hash])
  run_withdraw(
    register_structural_redeemer(),
    Transaction {
      ..base,
      outputs: [make_registry_node_output_with_vkey_transfer_logic()],
    },
  )
}

test register_structural_fails_when_third_party_logic_is_not_a_script() fail {
  // Same requirement, field 4. POSITIVE CONTROL: same as above.
  let base = make_register_structural_tx(zero, [test_admin_hash])
  run_withdraw(
    register_structural_redeemer(),
    Transaction {
      ..base,
      outputs: [make_registry_node_output_with_vkey_third_party_logic()],
    },
  )
}

test register_structural_fails_when_no_registry_nft_is_minted() fail {
  // No registry NFT minted means this is an in-place node UPDATE, not an
  // insert — that path re-points transfer logic and must never be reachable
  // through a registration redeemer.
  let base = make_register_structural_tx(zero, [test_admin_hash])
  run_withdraw(
    register_structural_redeemer(),
    Transaction { ..base, mint: zero },
  )
}

test register_structural_cannot_smuggle_a_registry_node_update() fail {
  // ATTACK: `registry_spend`'s in-place UPDATE path mints no registry NFT and
  // demands the proxy's withdraw-0, which this validator's approval supplies.
  // The Register variants try to exclude updates by requiring that SOME
  // registry NFT is minted — but "some" is satisfiable by bundling an
  // unrelated insert for a DIFFERENT token, while OUR node is simultaneously
  // spent and re-emitted with `transfer_logic_script` re-pointed at a
  // permissive script. The re-emitted node still names our proxy (the base
  // layer freezes that field on update), still forbids unfracking and still
  // pins our GlobalState, so every structural check passes.
  //
  // Nothing is minted under the issuance policy, so the no-mint assertion
  // passes too. Only the admin signature is needed — and re-pointing
  // transfer logic is exactly the operation the codebase says must stay
  // rejected "pending a deliberate authorisation design".
  let our_node_spent = Input {
    output_reference: test_out_ref(7),
    output: make_registry_ref_input().output,
  }
  let base = make_register_structural_tx(zero, [test_admin_hash])
  run_withdraw(
    register_structural_redeemer(),
    Transaction {
      ..base,
      // our node is SPENT (the update), alongside whatever the bundled
      // unrelated insert spends
      inputs: [our_node_spent],
      // the bundled unrelated insert mints a registry NFT, satisfying the
      // "this is an insert" heuristic
      mint: from_asset(test_registry_policy_id, "OtherTokenNode", 1),
    },
  )
}

// ── UpgradeRegistryNode: the CIP-113 transfer-logic upgrade path ────────────
//
// Shape mirrors registry_spend's update branch: the node is SPENT and exactly
// one registry-node output continues it, nothing is minted, GlobalState is
// referenced.

fn make_upgraded_node_output(
  transfer_logic: Credential,
  unfracking: Credential,
  global_state_cs: ByteArray,
) -> Output {
  let node = TestRegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    // frozen by the base layer across an update
    minting_logic_script: Script(test_proxy_hash),
    transfer_logic_script: transfer_logic,
    third_party_transfer_logic_script: Script(test_third_party_logic_hash),
    unfracking_logic_script: unfracking,
    global_state_cs,
  }
  Output { ..make_registry_ref_input().output, datum: InlineDatum(node) }
}

// Same shape as `make_upgraded_node_output`, but with the THIRD-PARTY
// transfer-logic field (4) — which that fixture hardcodes to a script —
// swapped for a VerificationKey instead.
fn make_upgraded_node_output_with_vkey_third_party_logic() -> Output {
  let node = TestRegistryNode {
    key: test_issuance_policy_id,
    next: #"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    minting_logic_script: Script(test_proxy_hash),
    transfer_logic_script: Script(test_new_transfer_logic_hash),
    third_party_transfer_logic_script: VerificationKey(
      test_third_party_logic_hash,
    ),
    unfracking_logic_script: VerificationKey(#""),
    global_state_cs: test_gs_policy_id,
  }
  Output { ..make_registry_ref_input().output, datum: InlineDatum(node) }
}

fn make_upgrade_tx(
  node_output: Output,
  gs_ref: Input,
  signatories: List<ByteArray>,
) -> Transaction {
  Transaction {
    ..make_withdraw_tx(
      0,
      True,
      False,
      False,
      make_denylist_root_ref_input(),
      [],
      signatories,
    ),
    inputs: [
      Input {
        output_reference: test_out_ref(7),
        output: make_registry_ref_input().output,
      },
    ],
    reference_inputs: [gs_ref],
    outputs: [node_output],
    mint: zero,
  }
}

fn upgrade_redeemer() -> MintingAuthorityWithdrawRedeemer {
  UpgradeRegistryNode {
    registry_node_input_index: 0,
    registry_node_output_index: 0,
    global_state_location: GlobalStateReferenced {
      global_state_ref_input_index: 0,
    },
  }
}

// A different transfer-logic script — the point of the upgrade.
const test_new_transfer_logic_hash: ByteArray =
  #"0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e"

/// Issuance-policy pin, `UpgradeRegistryNode`. The SPENT node is what the pin
/// guards here — the continuing node is then compared against it, so pinning
/// the spent node pins both. Node names this proxy, so only the new assertion
/// rejects it. `expect`, so `fail`.
test upgrade_fails_when_spent_node_is_keyed_to_a_foreign_policy() fail {
  let foreign = make_registry_node_output_with_foreign_key()
  run_withdraw(
    upgrade_redeemer(),
    Transaction {
      ..make_upgrade_tx(foreign, make_gs_ref_input(), [test_admin_hash]),
      inputs: [Input { output_reference: test_out_ref(7), output: foreign }],
    },
  )
}

// ── GlobalState may be spent instead of referenced ──────────────────────────
//
// `UpgradeRegistryNode` and `RegisterStructural` both read GlobalState for the
// admin credential (and, for the upgrade, the lock) and nothing else, so both
// were widened from a fixed reference index to a `GlobalStateLocation`. These
// tests exercise the SPENT branch, which the widening made reachable and which
// the platform does not build today — an unverified branch of shared,
// security-relevant code is exactly what a future caller trips over. Contrast
// `MintBurn`/`RegisterMint`, which keep a bare index because they MUST spend.
//
// GlobalState is absent from `reference_inputs` in both fixtures, as it would
// be in a real transaction that spends it (Conway rejects the overlap). The
// spent input reuses `make_gs_ref_input`'s output so it carries the admin.

fn make_upgrade_tx_gs_spent(node_output: Output) -> Transaction {
  Transaction {
    ..make_upgrade_tx(node_output, make_gs_ref_input(), [test_admin_hash]),
    inputs: [
      Input {
        output_reference: test_out_ref(7),
        output: make_registry_ref_input().output,
      },
      make_gs_ref_input(),
    ],
    reference_inputs: [],
  }
}

fn upgraded_node() -> Output {
  make_upgraded_node_output(
    Script(test_new_transfer_logic_hash),
    VerificationKey(#""),
    test_gs_policy_id,
  )
}

test upgrade_succeeds_when_global_state_is_spent() {
  run_withdraw(
    UpgradeRegistryNode {
      registry_node_input_index: 0,
      registry_node_output_index: 0,
      global_state_location: GlobalStateSpent { global_state_input_index: 1 },
    },
    make_upgrade_tx_gs_spent(upgraded_node()),
  )
}

test upgrade_gs_spent_still_requires_the_admin_signature() {
  // The location changes WHERE the datum is read, never WHETHER its gates
  // apply. Same transaction, admin signature removed.
  !run_withdraw(
    UpgradeRegistryNode {
      registry_node_input_index: 0,
      registry_node_output_index: 0,
      global_state_location: GlobalStateSpent { global_state_input_index: 1 },
    },
    Transaction {
      ..make_upgrade_tx_gs_spent(upgraded_node()),
      extra_signatories: [],
    },
  )
}

test upgrade_gs_spent_fails_when_index_is_not_global_state() fail {
  // Input 0 is the registry node. `GlobalStateSpent` may point anywhere; the
  // GlobalState NFT is still what decides whether the datum is believed.
  run_withdraw(
    UpgradeRegistryNode {
      registry_node_input_index: 0,
      registry_node_output_index: 0,
      global_state_location: GlobalStateSpent { global_state_input_index: 0 },
    },
    make_upgrade_tx_gs_spent(upgraded_node()),
  )
}

test register_structural_succeeds_when_global_state_is_spent() {
  run_withdraw(
    RegisterStructural {
      registry_node_output_index: 0,
      global_state_location: GlobalStateSpent { global_state_input_index: 0 },
    },
    Transaction {
      ..make_register_structural_tx(zero, [test_admin_hash]),
      inputs: [make_gs_ref_input()],
      reference_inputs: [],
    },
  )
}

test register_structural_gs_spent_still_requires_the_admin_signature() {
  !run_withdraw(
    RegisterStructural {
      registry_node_output_index: 0,
      global_state_location: GlobalStateSpent { global_state_input_index: 0 },
    },
    Transaction {
      ..make_register_structural_tx(zero, []),
      inputs: [make_gs_ref_input()],
      reference_inputs: [],
    },
  )
}

test upgrade_repoints_transfer_logic_when_admin_signs() {
  // THE upgrade path for the other scripts: transfer_logic_script is mutable
  // per CIP-113's is_field_updated_registry_node, and registry_spend gates it
  // on our proxy's withdraw-0, which delegates here.
  run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output(
        Script(test_new_transfer_logic_hash),
        VerificationKey(#""),
        test_gs_policy_id,
      ),
      make_gs_ref_input(),
      [test_admin_hash],
    ),
  )
}

test upgrade_fails_without_admin_signature() {
  !run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output(
        Script(test_new_transfer_logic_hash),
        VerificationKey(#""),
        test_gs_policy_id,
      ),
      make_gs_ref_input(),
      [],
    ),
  )
}

test upgrade_fails_when_upgrades_are_locked() {
  // The one-way lock closes this path permanently.
  !run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output(
        Script(test_new_transfer_logic_hash),
        VerificationKey(#""),
        test_gs_policy_id,
      ),
      make_gs_ref_input_locked(),
      [test_admin_hash],
    ),
  )
}

test upgrade_fails_when_deactivated() fail {
  run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output(
        Script(test_new_transfer_logic_hash),
        VerificationKey(#""),
        test_gs_policy_id,
      ),
      make_gs_ref_input_deactivated(),
      [test_admin_hash],
    ),
  )
}

test upgrade_cannot_repoint_global_state() fail {
  // CIP-113 lets `global_state_cs` change on update; this deployment does
  // not. Re-pointing it at a GlobalState the caller controls would make every
  // later compliance read meaningless.
  run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output(
        Script(test_new_transfer_logic_hash),
        VerificationKey(#""),
        test_pu_policy_id,
      ),
      make_gs_ref_input(),
      [test_admin_hash],
    ),
  )
}

test upgrade_cannot_enable_unfracking() fail {
  // Likewise mutable in CIP-113, likewise refused: unfracking lets a holder
  // split this policy out of a shared UTxO without its transfer logic running.
  run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output(
        Script(test_new_transfer_logic_hash),
        Script(test_pu_credential_hash),
        test_gs_policy_id,
      ),
      make_gs_ref_input(),
      [test_admin_hash],
    ),
  )
}

test upgrade_cannot_repoint_transfer_logic_to_a_non_script() fail {
  // Field 3 must stay script-gated. POSITIVE CONTROL:
  // `upgrade_repoints_transfer_logic_when_admin_signs`, whose continuing
  // node differs from this one in exactly this field (`Script` there,
  // `VerificationKey` here, same underlying hash).
  run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output(
        VerificationKey(test_new_transfer_logic_hash),
        VerificationKey(#""),
        test_gs_policy_id,
      ),
      make_gs_ref_input(),
      [test_admin_hash],
    ),
  )
}

test upgrade_cannot_repoint_third_party_logic_to_a_non_script() fail {
  // Same requirement, field 4. POSITIVE CONTROL: same as above.
  run_withdraw(
    upgrade_redeemer(),
    make_upgrade_tx(
      make_upgraded_node_output_with_vkey_third_party_logic(),
      make_gs_ref_input(),
      [test_admin_hash],
    ),
  )
}

// `next`-backstop test removed: that property is now delegated to the base
// layer (CIP-113's `registry_spend` already threads `next` unchanged through
// an in-place field update).

// `upgrade_cannot_change_supply` test removed: its subject — the belt-and-
// braces `dict.is_empty(assets.tokens(self.mint, issuance_policy_id))?`
// conjunct — no longer exists. The base layer's `registry_spend` already
// forbids minting or burning the spent node's own token in the same
// transaction, relied upon instead.

test upgrade_fails_when_spent_node_is_another_tokens() fail {
  // Purpose-binding: only THIS token's node (the one naming our proxy) may
  // be upgraded through this validator.
  let base = make_upgrade_tx(
    make_upgraded_node_output(
      Script(test_new_transfer_logic_hash),
      VerificationKey(#""),
      test_gs_policy_id,
    ),
    make_gs_ref_input(),
    [test_admin_hash],
  )
  run_withdraw(
    upgrade_redeemer(),
    Transaction {
      ..base,
      inputs: [
        Input {
          output_reference: test_out_ref(7),
          output: make_decoy_registry_ref_input().output,
        },
      ],
    },
  )
}

test upgrade_cannot_aim_the_field_checks_at_a_decoy_output() fail {
  // ATTACK: `registry_node_output_index` selects the output whose
  // `unfracking_logic_script` / `global_state_cs` get pinned, but nothing
  // asserted that output is actually the registry node. An attacker emits a
  // decoy plain output carrying a COPY of the original (clean) node datum
  // and points the index at it, while the REAL continuing node — the only
  // one carrying the registry NFT, per registry_spend's `expect [cont]` —
  // re-points `global_state_cs` at a GlobalState they control. CIP-113
  // permits that field to change on update, so only our check stands in the
  // way, and it is looking at the decoy.
  //
  // Consequence: every later compliance read (pause, deactivation, denylist
  // policy, TEL, KYC config) resolves against an attacker-authored datum.
  let decoy_clean_datum = Output {
    ..make_upgraded_node_output(
      Script(test_new_transfer_logic_hash),
      VerificationKey(#""),
      test_gs_policy_id,
    ),
    // no registry NFT — just ADA and an inline datum
    value: from_lovelace(2_000_000),
  }
  let real_node_hijacked = make_upgraded_node_output(
    Script(test_new_transfer_logic_hash),
    VerificationKey(#""),
    test_pu_policy_id,
  )
  let base = make_upgrade_tx(
    decoy_clean_datum,
    make_gs_ref_input(),
    [test_admin_hash],
  )
  run_withdraw(
    UpgradeRegistryNode {
      registry_node_input_index: 0,
      registry_node_output_index: 0,
      global_state_location: GlobalStateReferenced {
        global_state_ref_input_index: 0,
      },
    },
    Transaction { ..base, outputs: [decoy_clean_datum, real_node_hijacked] },
  )
}

// ── publish handler ──────────────────────────────────────────────────────────

test publish_accepts_credential_registration() {
  minting_authority_validator.publish(
    test_security_asset_name,
    test_gs_policy_id,
    test_registry_policy_id,
    test_pu_policy_id,
    test_proxy_hash,
    test_issuance_policy_id,
    test_denylist_script_hash,
    test_pu_script_hash,
    test_reference_asset_name,
    builtin.constr_data(0, []),
    RegisterCredential {
      credential: Script(test_authority_hash),
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
  !minting_authority_validator.publish(
    test_security_asset_name,
    test_gs_policy_id,
    test_registry_policy_id,
    test_pu_policy_id,
    test_proxy_hash,
    test_issuance_policy_id,
    test_denylist_script_hash,
    test_pu_script_hash,
    test_reference_asset_name,
    builtin.constr_data(0, []),
    UnregisterCredential {
      credential: Script(test_authority_hash),
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

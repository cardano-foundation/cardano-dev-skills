

# CIP-113 Programmable Tokens — Audit-Era API Changes

A reference for off-chain integrators (transaction builders, indexers,
custodial software, wallet teams) covering every breaking change to the public
on-chain surface between the pre-audit baseline and current `main`.

> **Reading order.** This document is the *field-level* surface (types,
> parameters, CBOR shapes). For the *conceptual* upgrade — what these changes
> mean for an existing substandard and what you must do about them — read the
> companion [`cip113-substandard-upgrade-guide.md`](./cip113-substandard-upgrade-guide.md).

If your code reads or writes any of:

- Validator script parameters
- Redeemer types
- Datum types
- Validator script bytecode (because any parameter change shifts the policy id
  / script hash, and hence every address derived from it)

…then this document tells you what changed and how to update.

---

## Baseline and scope

| | Commit | Date | Description |
|---|---|---|---|
| **Pre-audit baseline** | `8143853` | 2026-04-28 | "chore: removed unwanted build script" — last commit before audit findings started landing |
| **Current `main`** | `3a6d8d6` | 2026-07-16 | "fix(registry_spend): R-01 — a registry-node spend cannot issue its own token (#88)" |

The audit-remediation PRs landing between them (newest first):

```
3a6d8d6 fix(registry_spend): R-01 — node spend cannot issue its own token (#88)
17ef775 feat: control & admin scope — protected prefixes (Findings 01,15,16,18) (#82)
cbedcfe feat(unfracking): Finding 17 — same-owner PLB UTxO restructuring (#78)
39a6b1e Merge #81 — registry design limitation (Finding 05 / contention)
8e42d65 fix(issuance_mint): Finding 04 — precise per-redeemer scope delegation (#80)
d728af6 fix(third_party): Finding 12 — prevent UTxO contamination (#79)
ffbe16e feat: in-place update of registry-node fields (node upgradability)
a5ed95c fix(transfer): Finding 02 — pure mints not subject to transfer logic (#77)
11d74f0 refactor(registry): drop redundant length/ordering checks (Finding 19) (#70)
ebd9ffa chore: added ref script validation (#69)
1687209 chore: flattened and updated find in issuance (#68)
2f6cd90 feat(registry): Separation of Concerns — Register / Register-and-Mint (#52)
0a04cc2 Fix audit findings 3, 8 and 9 (#51)
```

> **What changed since the 2026-05-26 revision of this doc.** Sections §1–§6
> (unchanged in substance) cover everything through `ebd9ffa`. Sections
> §7–§12 are new: registry-node field updates (§7), the `unfracking_cred`
> protocol-params field (§8), the `UnfrackingAct` / reshaped `ThirdPartyAct`
> PLG redeemer (§9), third-party protected prefixes & anti-injection (§10),
> the pure-mint transfer contract (§11), and the re-audit layer (§12).

Validators with **no public-surface changes** since baseline (no off-chain
impact):

- `programmable_logic_base.ak`
- `protocol_params_mint.ak`
- `issuance_cbor_hex_mint.ak`
- `always_fail.ak`

The rest of this document walks through the components that did change.

---

## TL;DR — action items for integrators

| Area | Action |
|---|---|
| `registry_mint` parameters | **Add** a 3rd parameter `registry_spend_cred: Credential` when applying parameters. Your registry-mint policy id will change. |
| `registry_mint.RegistryInsert` redeemer | **Reshape**: `{key, hashed_param}` → `{key, minting_logic_script}`. Drop `hashed_param`; supply the substandard's `minting_logic_script` credential. |
| `issuance_mint` parameters | **Add** a 4th parameter `plg_stake_cred: Credential` when applying parameters. Your programmable-token policy ids will change. |
| `issuance_mint.mint` redeemer | **Simplify**: was `SmartTokenMintingAction { minting_logic_cred, minting_registry_proof }`, now just `MintingRegistryProof` directly. The `minting_logic_cred` field is gone — it's baked into the validator's parameters. |
| `RegistryNode` datum | **Add** a new field `minting_logic_script: Credential` at position #3 (after `key` and `next`). Datum CBOR shape changed. |
| `RegistryInsert` withdrawal requirement | The substandard's withdraw-0 (`minting_logic_script` credential) **must** appear in `tx.withdrawals`, even when the registration carries no first mint. |
| `issuance_mint` delegation signal | `issuance_mint` now consults `tx.withdrawals` (looking for `plg_stake_cred`), not `tx.inputs` (looking for PLB spends), to decide whether to delegate output-custody to PLGlobal. |
| `ThirdPartyAct` continuing outputs | Must now preserve `reference_script` of the paired input (in addition to address and datum). Tx builders that strip ref scripts on seize-style outputs will be rejected. |
| `RegistryNode` datum (again) | **Add** a 7th field `protected_prefixes: List<ByteArray>` at the end. Datum CBOR shape changed again since the 2026-05-26 revision. See [§7](#7-registry-node-field-updates--in-place-node-upgradability). |
| Registry-node **updates** | New capability: a node's `transfer_logic_script` / `third_party_transfer_logic_script` / `global_state_cs` / `protected_prefixes` can be changed by **re-spending the node UTxO** via `registry_spend` (authorised by its `minting_logic_script` withdraw-0). Indexers must treat these as **live, not frozen**. See [§7](#7-registry-node-field-updates--in-place-node-upgradability). |
| Protocol-params datum | **Add** a 3rd field `unfracking_cred: Credential`. Deploy tooling that writes the params datum must include it. See [§8](#8-protocol-params-datum--new-unfracking_cred-field). |
| PLG redeemer | **Add** `UnfrackingAct` (no payload); `ThirdPartyAct` now carries `{registry_node_idx, outputs_start_idx}`. See [§9](#9-programmable_logic_global-redeemer--unfrackingact--reshaped-thirdpartyact). |
| `TransferAct` proofs | Supply **exactly one proof per PLB *input* policy**; do **not** supply a proof for a policy that only appears in `tx.mint` (pure mint) — it is rejected as surplus. See [§11](#11-transfer-pure-mints-no-longer-require-a-proof-finding-02). |

A dedicated walkthrough of the two registration flows (with and without a
first mint) is in [§6](#6-registration-flows--with-and-without-a-first-mint).

---

## 1. `lib/types.ak` — redeemer / shared type changes

### 1.1 `SmartTokenMintingAction` — REMOVED

```aiken
// Before
pub type SmartTokenMintingAction {
  minting_logic_cred: Credential,
  minting_registry_proof: MintingRegistryProof,
}

// After
(removed)
```

The wrapper is gone. Its `minting_logic_cred` field was redundant in the
redeemer because the validator already carries it as a compile-time parameter
— passing it again per-transaction was both pointless and a place for callers
to lie. `MintingRegistryProof` is now used directly as the `issuance_mint.mint`
redeemer.

### 1.2 `MintingRegistryProof` — unchanged shape, new role

```aiken
pub type MintingRegistryProof {
  RefInput { index: Int }
  OutputIndex { index: Int }
}
```

Shape preserved; **now the top-level redeemer** for `issuance_mint.mint(...)`.

### 1.3 `RegistryRedeemer.RegistryInsert` — RESHAPED

```aiken
// Before
pub type RegistryRedeemer {
  RegistryInit
  RegistryInsert { key: ByteArray, hashed_param: ByteArray }
}

// After
pub type RegistryRedeemer {
  RegistryInit
  RegistryInsert { key: ByteArray, minting_logic_script: Credential }
}
```

Changes:

- **Dropped** `hashed_param: ByteArray`. The validator now derives the inner
  28-byte hash from `minting_logic_script` itself. Callers can no longer
  mis-supply it.
- **Added** `minting_logic_script: Credential` — the substandard's withdraw-0
  minting-logic credential that the new policy id is parameterised by. The
  validator cryptographically binds this to `key` via
  `is_programmable_token_id_valid` (audit Finding 3).

### 1.4 `IssuanceCborHex` — unchanged

Shape preserved.

---

## 2. `lib/registry_node.ak` — datum gained a field

`RegistryNode` (the inline datum of every registry linked-list UTxO) gained a
field at position **#3**, between `next` and `transfer_logic_script`.

```aiken
// Before
pub type RegistryNode {
  key: ByteArray,
  next: ByteArray,
  transfer_logic_script: Credential,
  third_party_transfer_logic_script: Credential,
  global_state_cs: ByteArray,
}

// After (current main — 7 fields)
pub type RegistryNode {
  key: ByteArray,
  next: ByteArray,
  minting_logic_script: Credential,             // NEW (position #3, this window)
  transfer_logic_script: Credential,
  third_party_transfer_logic_script: Credential,
  global_state_cs: ByteArray,
  protected_prefixes: List<ByteArray>,          // NEW (position #7, Finding 18 — see §7/§10)
}
```

Off-chain impact:

- Anyone constructing a `RegistryNode` datum CBOR must include `minting_logic_script`
  at index 2 (between `next` and `transfer_logic_script`) **and**
  `protected_prefixes` as the final field.
- Anyone parsing legacy pre-audit registry UTxOs will need to handle both
  shapes during migration (no automatic ledger migration — new nodes are
  inserted with the new shape).
- `registry_mint` enforces that `minting_logic_script` equals the value
  supplied in the `RegistryInsert` redeemer, and that both are cryptographically
  bound to `key`. The field cannot lie.
- `protected_prefixes` is a list of 4-byte CIP-67 asset-name label prefixes,
  **strictly ascending** and **append-only** across updates. It marks companion
  assets (e.g. CIP-68 label 100, CIP-102 label 500) that `ThirdPartyAct` may
  neither seize nor burn. See [§7](#7-registry-node-field-updates--in-place-node-upgradability)
  (mutability) and [§10](#10-third-party-action--protected-prefixes--anti-injection)
  (enforcement).

---

## 3. `validators/registry_mint.ak` — new parameter, reshaped redeemer

### 3.1 Script parameters

```aiken
// Before
validator registry_mint(
  utxo_ref: OutputReference,
  issuance_cbor_hex_cs: PolicyId,
) { ... }

// After
validator registry_mint(
  utxo_ref: OutputReference,
  issuance_cbor_hex_cs: PolicyId,
  registry_spend_cred: Credential,    // NEW (3rd parameter)
) { ... }
```

**Impact on off-chain code:**

- When applying parameters to the `registry_mint` blueprint, supply all three.
  Your registry policy id (and every registry NFT address) changes.
- `registry_spend_cred` should be the credential of the `registry_spend`
  validator that holds the linked-list UTxOs. It is consumed by
  `validate_directory_init` (audit Finding 3) to confirm the origin node lands
  at the right address at `RegistryInit`. By inductive reasoning every
  subsequently inserted node also lands at the same address (Insert binds new
  outputs' addresses to the covering input's address; the covering input is at
  `registry_spend_cred` by induction from Init).

### 3.2 `mint` handler signature

Unchanged in shape:

```aiken
mint(redeemer: RegistryRedeemer, policy_id: PolicyId, self: Transaction)
```

Only the `RegistryRedeemer.RegistryInsert` *variant* changed (see §1.3).

### 3.3 New required withdrawal at `RegistryInsert` time

The substandard's `minting_logic_script` credential (from the redeemer) **must**
appear as a withdraw-0 in `tx.withdrawals`.

This is the *proof of instance* check. It replaces the old indirect proof
(which came for free from `issuance_mint` running, because the old flow always
co-minted the first batch). It is required **whether or not the registration
carries a first mint** — and particularly important when it doesn't, because
then `issuance_mint` is not invoked at all.

---

## 4. `validators/issuance_mint.ak` — new parameter, simplified redeemer, delegation-signal change

### 4.1 Script parameters

```aiken
// Before
validator issuance_mint(
  programmable_logic_base: Credential,
  registry_node_cs: PolicyId,
  minting_logic_cred: Credential,
) { ... }

// After
validator issuance_mint(
  programmable_logic_base: Credential,
  registry_node_cs: PolicyId,
  minting_logic_cred: Credential,
  plg_stake_cred: Credential,   // NEW (4th parameter)
) { ... }
```

**Impact on off-chain code:**

- When applying parameters to the `issuance_mint` blueprint, supply all four.
  Every programmable-token policy id derived from this template changes.
- `plg_stake_cred` should be the stake credential of `programmable_logic_global`.
  It is the new delegation signal — see §4.3.

### 4.2 `mint` handler redeemer simplified

```aiken
// Before
mint(
  redeemer: SmartTokenMintingAction,  // { minting_logic_cred, minting_registry_proof }
  own_policy: PolicyId,
  self: Transaction,
)

// After
mint(
  redeemer: MintingRegistryProof,     // RefInput | OutputIndex
  own_policy: PolicyId,
  self: Transaction,
)
```

Pass `MintingRegistryProof` directly:

- `RefInput { index: Int }` — for subsequent mints/burns of an already-registered
  policy. `index` points at the registry-node reference input.
- `OutputIndex { index: Int }` — for the first mint paired with registration in
  the same transaction. `index` points at the registry-node *output* being
  created.

The old `minting_logic_cred` field is gone — the validator already knows its
parameter at compile time. Passing it in the redeemer was redundant.

### 4.3 Delegation signal: input-based → withdrawal-based (Finding 9)

`issuance_mint` decides whether to delegate its output-custody check to
PLGlobal. The way it makes that decision changed:

- **Before**: "does any input have payment credential ==
  `programmable_logic_base`?" — i.e., a PLB input was the delegation signal.
- **After**: "is PLGlobal's stake credential (`plg_stake_cred`) being invoked
  as a withdraw-0?" — direct delegation signal via withdrawals.

For typical tx builders this is transparent (PLGlobal is invoked via withdraw-0
in any tx that needs the transfer path). The difference matters at the corners:

- A pure-mint tx that incidentally spends an unrelated PLB UTxO **no longer**
  triggers delegation (which is correct — PLGlobal isn't validating anything
  about that mint).
- A tx that explicitly invokes PLGlobal **does** trigger delegation (which is
  also correct — PLGlobal is the validator vouching for the transfer).

This signal change applies only on the `RefInput` arm. The `OutputIndex` arm
(first-mint case) always validates output custody itself via
`validate_mint_outputs` — there is no delegation choice on first mints.

### 4.4 Removed redundant `single_mint_with_credential` check (Finding 10)

The pre-audit validator carried an explicit check that the redeemer's
credential matched the policy's mint redeemer (`single_mint_with_credential`).
That invariant is already implied by the per-policy redeemer scoping in
Plutus; the check was removed. **No off-chain impact.**

---

## 5. `validators/programmable_logic/third_party.ak` — additional invariant

`ThirdPartyAct` now enforces `output.reference_script == input.reference_script`
on the continuing PLB output, in addition to the existing address and datum
equality checks (audit Finding 13).

**Off-chain impact:** transaction builders that strip or replace reference
scripts on the continuing output of a seize-style action will now be rejected.

- If your input has no reference script, your continuing output must have no
  reference script.
- If your input has one, the continuing output must carry the same one.

No validator-signature change; this is an internal invariant added to
`check_seized_tokens`.

---

## 6. Registration flows — with and without a first mint

A `RegistryInsert` may or may not carry a first mint of the new policy in the
same transaction. Both shapes share the same registry-update invariants; they
differ in **whether `tx.mint` carries entries under the new policy id** and
**which validators run as a consequence**. There is no redeemer tag selecting
between them — `registry_mint` does not constrain the first-mint shape under
the new key at all; when a first mint is present it is validated by
`issuance_mint`. A substandard that wants a strict register-then-mint
lifecycle must enforce it in its own minting logic — see §6.4.

### 6.1 Invariants common to both flows

In both flows, a `RegistryInsert` transaction must:

1. **Spend exactly one covering registry node** — the linked-list node whose
   `key < new_key < next`. `registry_mint` filters inputs by the registry NFT
   policy and asserts exactly one such input exists.
2. **Mint exactly one new registry NFT** under the registry policy, with asset
   name = `new_key`.
3. **Produce exactly two registry-node outputs** at the `registry_spend`
   address:
   - the *updated covering node* (its `next` repointed to `new_key`);
   - the *newly inserted node* with the linked-list invariants
     `covering.key < new_key < covering.next`.
4. **Include the substandard's `minting_logic_script` as a withdraw-0** in
   `tx.withdrawals`. *(This is the proof-of-instance check — required in both
   flows, see §3.3.)*
5. **Carry an `IssuanceCborHex` reference input** under `issuance_cbor_hex_cs`.
   The validator uses its `prefix_cbor_hex` and `postfix_cbor_hex` to verify
   `is_programmable_token_id_valid(new_key, prefix, postfix, minting_logic_script)`
   — the cryptographic binding between `new_key` and the credential being
   registered.
6. **Use a 28-byte `key`** (the validator asserts `bytearray.length(key) == 28`).

`registry_spend` runs (because the covering node is being consumed) and is
satisfied automatically: it requires exactly one positive-amount entry under
the registry NFT policy in `tx.mint`, which both flows produce.

### 6.2 Register without a first mint

| | |
|---|---|
| **Caller intent** | Reserve a policy id in the registry **without** minting any tokens of it yet. |
| **`tx.mint` for `new_key`** | No entries. `registry_mint` does not check this either way. |
| **`issuance_mint` invocation** | Not invoked. No tokens of `new_key` are minted, so the issuance policy never runs. |
| **PLGlobal involvement** | None — PLGlobal is not part of this flow. |
| **Use case** | Two-stage flow where a partner wants to publish the registry entry (claim the policy id slot, publish the substandard's credentials) and mint the first tokens in a *later* transaction using the `RefInput` redeemer of `issuance_mint`. Useful when registration and first-mint are performed by different signers, or when the registration must occur before the substandard is ready to mint. |

**Minimum withdrawals:**

```text
- minting_logic_script (the substandard's withdraw-0 — proof of instance)
```

### 6.3 Register and mint in the same transaction

| | |
|---|---|
| **Caller intent** | Reserve the policy id **and** mint its first tokens atomically. This is the all-in-one flow that matches pre-audit behaviour. |
| **`tx.mint` for `new_key`** | Contains the first-mint entries. `registry_mint` does not inspect them; minting under `new_key` triggers `issuance_mint`, which validates the mint as usual. |
| **`issuance_mint` invocation** | Required (by the ledger — the policy is being minted). Runs with redeemer `MintingRegistryProof.OutputIndex { index }` where `index` points at the new registry-node *output* being created. |
| **PLGlobal involvement** | **Not required by `issuance_mint`** for the first mint — the `OutputIndex` arm always validates output custody itself via `validate_mint_outputs` (mandates all minted tokens land at PLB). You may still invoke PLGlobal in the same transaction for unrelated reasons (e.g., transferring another already-registered token); doing so is harmless. |
| **Use case** | Standard "create a programmable token and issue the initial supply" — single atomic on-chain action. |

**Minimum withdrawals:**

```text
- minting_logic_script (the substandard's withdraw-0 — proof of instance)
```

(PLGlobal not required; see the table row above.)

### 6.4 Enforcing a strict register-then-mint lifecycle (substandard's job)

The flow split above is purely a property of the transaction you build — the
base layer does not forbid (or require) a first mint at registration time. If
a substandard's policy demands that registration and issuance never happen in
the same transaction, the enforcement point is the substandard's own
minting-logic withdraw-0, which is guaranteed to run in both flows (proof of
instance, §3.3) and at every mint. Give it an explicit running mode — e.g. a
redeemer with `Register | Mint` arms — and in the `Register` arm assert that
`tx.mint` carries no entries under the token's policy id. See the substandard
development guide (`09-DEVELOPING-SUBSTANDARDS.md`) for the full pattern.

### 6.5 Off-chain decision tree

```text
Need to:
├─ Reserve a policy slot only (no first mint, yet)
│     → tx.mint has NO entries under new_key
│     → required withdrawals: [substandard's minting_logic_script]
│     → invoke registry_mint + the substandard's minting-logic withdraw-0
│     → issuance_mint is NOT invoked
│
└─ Reserve a policy slot AND mint the first batch in the same tx
      → tx.mint has entries under new_key
      → required withdrawals: [substandard's minting_logic_script]
      → invoke registry_mint + issuance_mint + substandard's withdraw-0
      → use MintingRegistryProof.OutputIndex { index } for issuance_mint
      → `index` points at the new registry-node output being created
      → first-mint tokens must land at PLB (validate_mint_outputs always runs
        on the OutputIndex arm; no PLGlobal delegation on first mints)

For SUBSEQUENT mints/burns of an already-registered policy
(i.e., NOT in the same tx as registration):
   → don't use registry_mint
   → use issuance_mint.mint with MintingRegistryProof.RefInput { index }
   → `index` points at the existing registry-node REFERENCE input
   → if PLGlobal is invoked in the same tx (e.g., you're also transferring),
     issuance_mint will delegate output-custody to it; otherwise issuance_mint
     validates custody itself
```

---

## 7. Registry-node field updates — in-place node upgradability

**New capability (`ffbe16e`, hardened by re-audit R-01 in #88).** A registered
node's *governance fields* can be changed after it exists, by **re-spending the
node UTxO** through `validators/registry_spend.ak` (no registry NFT minted in
that tx → the "update" branch). The rules are in
`lib/linked_list.ak:is_field_updated_registry_node`:

| Field | Updatable via node-spend? |
|---|---|
| `key` | **No** — immutable policy identity |
| `next` | **No** — only re-linked by insert |
| `minting_logic_script` | **No** — bound to `key` |
| `transfer_logic_script` | **Yes** (must be a 28-byte credential) |
| `third_party_transfer_logic_script` | **Yes** (28-byte credential) |
| `global_state_cs` | **Yes** (28 bytes or empty) |
| `protected_prefixes` | **Yes, APPEND-ONLY** (4-byte, strictly-ascending; new ⊇ old) |

**Authority.** The update is valid only if the node's `minting_logic_script` is
a `Script` credential **and** its withdraw-0 is invoked in the update tx. A
`VerificationKey` minting logic can never update a node.

**Re-audit R-01 guard (#88).** A node-spend may **not** mint or burn the node's
own token (`key`) in the same transaction — spending a node is a lifecycle
action, never an issuance. Enforced in `registry_spend.ak` above the
mint/update branch, so it covers both the update and the insert covering-node
spend.

**Off-chain impact:**

- **Indexers / wallets / custodial software: treat `transfer_logic_script`,
  `third_party_transfer_logic_script`, `global_state_cs`, and
  `protected_prefixes` as LIVE.** Resolve them fresh from the current node at
  transaction-build time; do not cache them as immutable. A token's governance
  can change under existing holders. *(This is a behavioural change with no
  signature change — the classic silent breakage.)*
- To **update** a node, build a tx that spends the node UTxO, produces exactly
  one continuing node output preserving the immutable fields, includes the
  node's `minting_logic_script` withdraw-0, and mints/burns nothing under `key`.

---

## 8. Protocol-params datum — new `unfracking_cred` field

**New (Finding 17, #78).** `programmable_logic/params.ak:ProgrammableLogicGlobalParams`
gained a third field:

```aiken
// Before                          // After (current main)
{ registry_node_cs: PolicyId,      { registry_node_cs: PolicyId,
  prog_logic_cred: Credential }      prog_logic_cred: Credential,
                                     unfracking_cred: Credential }  // NEW (#3)
```

`unfracking_cred` is the credential of the standalone `unfracking` withdraw-0
validator. It is read only by the `UnfrackingAct` branch of PLGlobal (§9).

**Off-chain impact:** the protocol-bootstrap tooling that mints the params NFT
and writes its datum must include this third field. Anyone parsing the params
datum must expect three fields. `registry_node_cs` and `prog_logic_cred` are
unchanged in position.

---

## 9. `programmable_logic_global` redeemer — `UnfrackingAct` + reshaped `ThirdPartyAct`

`lib/types.ak:ProgrammableLogicGlobalRedeemer`:

```aiken
// Before
pub type ProgrammableLogicGlobalRedeemer {
  TransferAct { proofs: List<RegistryProof> }
  ThirdPartyAct { ... }
}

// After (current main)
pub type ProgrammableLogicGlobalRedeemer {
  TransferAct { proofs: List<RegistryProof> }
  ThirdPartyAct {
    registry_node_idx: Int,   // registry node (subject policy) in reference inputs
    outputs_start_idx: Int,   // where processed outputs begin
  }
  UnfrackingAct               // NEW (Finding 17) — no payload
}
```

**`UnfrackingAct`** lets a holder redistribute programmable tokens they already
hold across their own PLB UTxOs, value-preserving and same-owner, **without**
invoking any substandard transfer logic. PLG only checks that the `unfracking`
withdraw-0 validator (from `unfracking_cred`, §8) is invoked; the invariants
live in that standalone validator.

**Off-chain impact:**

- Tx builders on the admin path must encode `ThirdPartyAct` with the two named
  fields.
- Builders wanting to split multi-policy UTxOs into single-policy UTxOs use
  `UnfrackingAct` (no payload) plus the `unfracking` withdraw-0. This action is
  invisible to your transfer logic — indexers tracking movement via transfer
  logic must account for it separately.
- Anyone decoding the PLG redeemer must handle the new third variant.

> On `feat/upgradability-in-place`, every variant additionally carries a leading
> `params_idx: Int` — see §16.

---

## 10. Third-party action — protected prefixes + anti-injection

Beyond the `reference_script` preservation of §5, `ThirdPartyAct` gained two
invariants in `validators/programmable_logic/third_party.ak`:

- **Anti-injection (Finding 12, #79).** The paired PLB input must already hold
  the subject policy (`expect !dict.is_empty(input_tokens_at)`). The admin
  cannot conjure the policy onto a UTxO that never held it, nor drag an
  unrelated UTxO into the action.
- **Protected prefixes (Finding 18, #82).** Any token of the subject policy
  whose CIP-67 label prefix is in the node's `protected_prefixes` must be
  **byte-equal** between the paired input and output — it can be neither
  extracted nor burned ("preserve, not fail"). The unprotected remainder stays
  fully seizable.

**Off-chain impact:** seize-style tx builders must (a) only target inputs that
already hold the subject policy, and (b) leave protected-prefixed tokens
untouched on the continuing output. Registration is where you *declare* the
protected prefixes (append-only thereafter). No PLG redeemer signature change.

> **Note (re-audit R-03, pending).** A former per-pair "the subject amount must
> change" anti-DoS guard is being removed on a separate branch (§12). It does
> not affect the CBOR surface; it only means a no-op respend is no longer
> rejected by the validator.

---

## 11. Transfer: pure mints no longer require a proof (Finding 02)

**Landed (#77).** This was the "coming next" item in the 2026-05-26 revision.
In `validators/programmable_logic/transfer.ak:verify_proofs`, a policy that is
purely minted (present in `tx.mint`, absent from every PLB input) is **no
longer** subject to transfer-logic enforcement and must **not** carry a
`TransferAct` proof.

The strict one-proof-per-input-policy contract is preserved and now exact:

- Supply exactly one `TransferAct` proof per PLB **input** policy.
- Do **not** supply a proof for a pure-mint policy — a surplus proof is rejected.
- A missing proof for an input policy is rejected.

**Off-chain impact:** transfer tx builders that previously added a proof for
every policy touched (including freshly-minted ones) must drop the proofs for
pure-mint policies.

---

## 12. Re-audit layer (R-01 … R-05)

The second audit ("re-audit") reviewed the first-audit fixes. Status on `main`:

| Re-audit | Summary | Surface impact | Status |
|---|---|---|---|
| **R-01** | A registry-node spend cannot issue its own token; registry-lifecycle authority documented | `registry_spend` guard (§7) | **Landed (#88)** |
| **R-02** | Registry lifecycle authority & mutability documentation | none (docs) | Landed |
| **R-03** | Remove the pair-local no-op guard on `ThirdPartyAct` (bypassable; aggregate check too costly) | none — a no-op respend becomes accepted; no CBOR change (§10 note) | **Pending** (branch `fix/r03-remove-pair-local-noop-guard`) |
| **R-04** | Issuance custody escape — net-positive mints must land at PLB even when pre-existing supply exists | `issuance_mint` output-custody tightening; no signature change | **Pending** (two candidate branches) |
| **R-05** | Unfracking module documentation (ADA-out allowed; non-ADA-non-programmable-out forbidden) | none (docs) | Landed |
| **R-06** | Redundant registration-mode tag removed from `RegistryInsert` before release | `RegistryInsert` = `{key, minting_logic_script}` (§1.3); `registry_mint` hash changes | **Landed (#92)** |

When R-03 and R-04 land in `main`, this section and §10/§4 will be updated.

---

## 13. Audit findings referenced

| Finding | Title | Affected component |
|---|---|---|
| 2 | Transfer-logic enforcement contradiction for pure mints | `transfer.ak:verify_proofs` (§11) |
| 3 | Registry init does not bind origin node to registry_spend | `registry_mint` parameters (new `registry_spend_cred`) |
| 4 | Imprecise delegation scope | `issuance_mint` precise per-node delegation (`plgl_scope_covers`) |
| 5 | Linked-list registry contention limitation | documented (#81) |
| 7 | Separation of Concerns | `RegistryInsert` reshape + register-without-mint capability |
| 8 | Inefficient membership check | `registry_mint` internal |
| 9 | Indirect delegation signal | `issuance_mint` parameters (new `plg_stake_cred`) + withdrawal-based delegation |
| 10 | Redundant single-mint redeemer check | removed from `issuance_mint` |
| 12 | UTxO contamination in ThirdPartyAct | `third_party.ak` anti-injection (§10) |
| 13 | Reference script preservation in ThirdPartyAct | `third_party.ak` reference-script equality (§5) |
| 17 | Unfracking action | `UnfrackingAct` + `unfracking_cred` (§8, §9) |
| 18 | Admin/control scope — protected prefixes | `RegistryNode.protected_prefixes` (§7, §10) |
| 19 | Redundant length/ordering checks in RegistryInsert | `registry_mint` internal (#70) |
| R-01 | Node spend cannot issue its own token | `registry_spend` guard (§7, §12) |
| R-06 | Redundant `RegistryInsert` registration-mode tag | removed before release — final redeemer is `{key, minting_logic_script}` (§1.3) |

The findings themselves live under `audit/` (first audit) and the re-audit
tracking in the repo. This document captures the *resulting public-API surface*
— refer to the audit text for threat models and remediation rationale.

---

## 14. Migration checklist

When upgrading off-chain integration:

- [ ] Re-fetch the deployed blueprints from your backend — every policy id and
      address derived from `registry_mint` and `issuance_mint` has shifted
      because both validators gained a parameter.
- [ ] Update transaction builders that call `RegistryInsert`: replace
      `hashed_param` with `minting_logic_script`.
- [ ] Update `RegistryNode` datum constructors to insert `minting_logic_script`
      at field position #3.
- [ ] Update parsers reading existing registry UTxOs to handle both pre- and
      post-audit datum shapes during the migration window.
- [ ] Update transaction builders that call `issuance_mint.mint`: pass
      `MintingRegistryProof` directly, not the old `SmartTokenMintingAction`
      wrapper.
- [ ] Where you previously included a PLB input purely as a delegation signal
      to `issuance_mint`, include the PLGlobal withdraw-0 explicitly instead.
      Stop adding extraneous PLB inputs for signalling.
- [ ] In registration flows without a first mint, include the substandard's
      `minting_logic_script` withdraw-0 even though no programmable tokens are
      being minted — the registry validator now requires it explicitly.
- [ ] If your tx builder uses the `ThirdPartyAct` path, ensure the continuing
      PLB outputs preserve the input's reference script verbatim, only target
      inputs already holding the subject policy, and leave protected-prefixed
      tokens byte-equal on the continuing output (§10).
- [ ] Add the 7th `RegistryNode` field `protected_prefixes` (and the 3rd
      `minting_logic_script` if migrating from pre-`ebd9ffa`) to every datum
      constructor/parser (§2, §7).
- [ ] Add the 3rd protocol-params field `unfracking_cred` to your params-datum
      tooling (§8).
- [ ] Decode the PLG redeemer's new `UnfrackingAct` variant and the reshaped
      `ThirdPartyAct { registry_node_idx, outputs_start_idx }` (§9) — **on the
      upgradability branch these no longer exist**: use `TransferRedeemer`,
      `ThirdPartyRedeemer`, `UnfrackingRedeemer` and the three-arm
      `BaseSpendRedeemer` instead (§17).
- [ ] **Stop caching node governance credentials** — resolve
      `transfer_logic_script` / `third_party_transfer_logic_script` /
      `global_state_cs` / `protected_prefixes` fresh at build time; they are
      updatable (§7).
- [ ] In transfer builders, drop `TransferAct` proofs for pure-mint policies;
      keep exactly one per PLB input policy (§11).

---

## 15. Coming next (not yet in `main`)

Two re-audit fixes are prepared on separate branches (§12):

- **R-03** — removes the pair-local no-op guard on `ThirdPartyAct`. No CBOR
  surface change; the only observable effect is that a no-op forced respend
  (subject amount unchanged) is no longer rejected by the validator. Branch:
  `fix/r03-remove-pair-local-noop-guard`.
- **R-04** — tightens issuance custody so a net-positive mint must land at PLB
  even when pre-existing supply of the policy could otherwise mask an escape.
  No validator-signature change; `issuance_mint` output-custody only. Two
  candidate branches (input-aware and no-escape variants).

This document will be updated when each lands in `main`.

---

## 16. Protocol-params reference-input index in redeemers (upgradability branch)

> On `feat/upgradability-in-place`. **Breaking redeemer-surface change.**

Every validator that reads the protocol-params UTxO now locates it by a
**redeemer-supplied index** into `reference_inputs`, authenticated by the
one-shot params NFT, instead of scanning the reference-input set.

**Motivation.** A programmable-token transaction references several scripts,
each as a reference input, so scanning for the params UTxO is O(position) — and,
before this change, aborted outright on a token-less reference-script UTxO
ordered ahead of it (the reference-input order is fixed by the ledger, not the
builder). A direct index (`list.expect_at`) drops `params_idx` list cells and
checks the NFT once — O(`params_idx`) cell drops, versus a policy check at
every reference input walked; since `programmable_logic_base` runs once **per
spent input**, the saving multiplies across a multi-input transaction. The one-shot params NFT still authenticates the target, so a wrong
index simply fails — no security is delegated to the index.

### Redeemer changes

- **`programmable_logic_base.spend`** — the redeemer was ignored (`Data`); it is
  now an `Int`, the params-NFT reference-input index.
- **`ProgrammableLogicGlobalRedeemer`** — every variant gains a leading
  `params_idx: Int`:
  ```aiken
  TransferAct { params_idx: Int, proofs: List<RegistryProof> }
  ThirdPartyAct { params_idx: Int, registry_node_idx: Int, outputs_start_idx: Int }
  UnfrackingAct { params_idx: Int }
  ```
- **`UnfrackingRedeemer`** (standalone `unfracking` validator) — gains a leading
  `params_idx: Int`.

### Off-chain impact

- Builders must compute the params UTxO's position in the **canonical**
  `reference_inputs` ordering (the ledger sorts `reference_inputs` by
  `OutputReference` = `(transaction_id, output_index)`) and pass it as
  `params_idx` in each PLG/unfracking redeemer, and as the `Int` redeemer of
  **every** `programmable_logic_base` spend in the transaction.
- A wrong index fails the params-NFT authentication `expect`, so the whole
  transaction fails — there is no silent misbehaviour.
- `issuance_mint`'s delegation check is unaffected: it still locates the
  coordination UTxO by NFT membership with fail-safe semantics (no coordination
  UTxO ⇒ local custody), so it takes no params index.

---

## 17. Validator split — `transfer`, `third_party`, `unfracking` as standalone validators; PLB dispatches (upgradability branch, PR #110)

> On `feat/upgradability-in-place`. **Breaking redeemer-surface + validator-set change.** Supersedes the `ThirdPartyAct` / `UnfrackingAct` parts of §9 and the PLG redeemer shape in §16.

The former `programmable_logic_global` (PLG) coordinator — one withdraw-0
script that dispatched transfer / third-party / unfracking on its redeemer —
is gone. `programmable_logic_base` (PLB) now dispatches **directly** to one of
three standalone withdraw-0 validators, each carrying only its own invariants:

| Validator | Redeemer | Params-datum credential | Transaction kind |
|---|---|---|---|
| **`transfer`** (renamed from `programmable_logic_global`) | `TransferRedeemer { params_idx, proofs }` | `transfer_cred` (field 2) | ordinary transfers |
| **`third_party`** (new) | `ThirdPartyRedeemer { params_idx, registry_node_idx, outputs_start_idx }` | `third_party_cred` (field 3) | seize / clawback / freeze enforcement |
| **`unfracking`** (existing; no longer gated through PLG) | `UnfrackingRedeemer { params_idx, registry_node_idx, outputs_start_idx }` | `unfracking_cred` (field 4) | holder-driven same-owner restructuring |

**Motivation.** The transfer validator is a reference script paid for by every
transfer, forever; the seize logic is heavy but rare, and the unfracking arm
was a pure trampoline (one withdrawal scan) that still forced every unfracking
transaction to load the whole transfer script. Each transaction kind now loads
PLB plus exactly one delegate. Measured reference-script footprint per tx:
`transfer` 3659 → 3045 B (**−614 B**), `seize` 3659 → 2674 B (**−985 B**),
`unfracking` 5491 → 2700 B (**−2791 B**); the transfer script itself 3163 →
2177 B (**−31%**), PLB 496 → 868 B (three-arm dispatch).

### Validator set

- **`validators/transfer.ak`** — blueprint title `transfer.transfer.withdraw`
  (was `programmable_logic_global.programmable_logic_global.withdraw`).
  Parameter unchanged (`params_policy`). Same transfer invariants
  (`validate_transfer`); no redeemer switch.
- **`validators/third_party.ak`** — new; blueprint title
  `third_party.third_party.withdraw`; parameter `params_policy`; carries the
  third-party invariants (`validate_3rd_party`). Per-policy it still requires
  the issuer's `third_party_transfer_logic_script` (registry-node field 4)
  withdrawal.
- **`validators/unfracking.ak`** — unchanged bytes; now invoked via PLB's
  `SpendViaUnfracking` instead of through PLG.

### Redeemer changes

- **`programmable_logic_base.spend`** — from `Int` (§16's params index) to a
  **sum type** that picks the delegate and witnesses its withdrawal position:
  ```aiken
  BaseSpendRedeemer {
    SpendViaTransfer { params_idx: Int, wdrl_idx: Int }     // constructor 0 -> transfer
    SpendViaThirdParty { params_idx: Int, wdrl_idx: Int }   // constructor 1 -> third_party
    SpendViaUnfracking { params_idx: Int, wdrl_idx: Int }   // constructor 2 -> unfracking
  }
  ```
  PLB reads the arm's credential from the params datum (field 2 / 3 / 4) and
  requires it at `withdrawals[wdrl_idx]` — a direct `list.expect_at`
  (O(`wdrl_idx`) cell drops, no credential comparison en route; cost record in
  `validators/programmable_logic/wdrl_idx_cost.test.ak`) instead of a scan that
  compares at every entry. Self-validating: a wrong index or arm resolves to a
  credential that fails the equality — assuming the three delegate credentials
  are pairwise distinct, which is **not** enforced on-chain (a deployment /
  upgrade-authority responsibility; see `02-ARCHITECTURE.md`). `wdrl_idx` is a
  position in the withdrawal map as the ledger orders it (script credentials
  before key credentials, bytewise within each kind), over the complete
  withdrawal set — see `09-DEVELOPING-SUBSTANDARDS.md` › Withdrawal indices.
- **`ProgrammableLogicGlobalRedeemer` is gone.** Its replacement is the
  single-constructor record
  ```aiken
  TransferRedeemer { params_idx: Int, proofs: List<RegistryProof> }
  ```
  (constructor 0, same field order as the old `TransferAct`, so an existing
  `TransferAct` encoder produces valid bytes). `ThirdPartyAct` and
  `UnfrackingAct` no longer exist as PLG arms: their payloads live in
  `ThirdPartyRedeemer` / `UnfrackingRedeemer` at the respective validators.

### Protocol-params datum — reordered + renamed, `third_party_cred` added

`ProgrammableLogicGlobalParams` is now a **6-field record, reordered by
read-frequency** and with two fields renamed (`prog_logic_global_cred` →
`transfer_cred`, `upgrade_logic_cred` → `upgrade_cred`) — dropping "logic" so
the framework-validator creds don't collide with the registry node's
`*_logic_script` per-policy hooks:

```aiken
type ProgrammableLogicGlobalParams {
  registry_node_cs: PolicyId,   // 0
  prog_logic_cred: Credential,  // 1 — base payment credential
  transfer_cred: Credential,    // 2 — the transfer validator (SpendViaTransfer)
  third_party_cred: Credential, // 3 — the third_party validator (SpendViaThirdParty)
  unfracking_cred: Credential,  // 4 — the unfracking validator (SpendViaUnfracking)
  upgrade_cred: Credential,     // 5 — upgrade authority (coordination_spend only)
}
```

The three credentials PLB reads on its per-input dispatch sit at indices 2-4
(ordered by how often each arm runs); the coldest `upgrade_cred` is last.
`third_party_cred` is new. All four delegate credentials are swappable in
place; `coordination_spend` guards each mutable one with the same
`is_28_byte_credential` one-way-brick check. (The type keeps its historical
name `ProgrammableLogicGlobalParams` — it is the protocol-params datum, not
tied to any one validator.)

> **Breaking for any params-datum builder or parser**: the field ORDER and the
> two field NAMES changed, so the on-chain CBOR field order changed. Deploy
> tooling that writes the datum, and any code that reads it positionally, must
> update.

### issuance_mint delegation

- `issuance_mint`'s mint-custody delegation (Finding 04) recognises coverage
  from **either** the `transfer` validator's `TransferRedeemer` (a
  `TokenExists` proof naming the same registry node the mint's
  `RefInput { index }` did) **or** the `third_party` validator's
  `ThirdPartyRedeemer` (same `registry_node_idx`). `unfracking` never mints and
  is not a delegate. No change to the `issuance_mint` parameter list.

### Off-chain impact

- Each `programmable_logic_base` spend carries a `SpendViaTransfer` /
  `SpendViaThirdParty` / `SpendViaUnfracking` redeemer: pick the arm matching
  the transaction and set `wdrl_idx` to the delegate credential's position in
  the ledger-ordered withdrawal map (script credentials first, then key
  credentials, bytewise within each kind; over the complete withdrawal set).
- A transfer invokes `transfer`'s withdraw-0 with a `TransferRedeemer`
  (blueprint title `transfer.transfer.withdraw`); a seize invokes `third_party`
  with a `ThirdPartyRedeemer`; an unfracking invokes `unfracking` with an
  `UnfrackingRedeemer` — **never more than one framework delegate per
  transaction**, and no transaction kind needs the transfer script unless it
  is a transfer.
- Deployment must publish all three delegate reference scripts and write
  `transfer_cred`, `third_party_cred`, `unfracking_cred` into the
  protocol-params datum.
- The SDK (`cip113-sdk-ts`) and the Java backend need corresponding updates —
  tracked separately, out of scope for the on-chain change.

---

*This document tracks `main` at the time of writing. For the most current
surface, always cross-check the validator declarations in `validators/` and
type definitions in `lib/types.ak` / `lib/registry_node.ak`.*

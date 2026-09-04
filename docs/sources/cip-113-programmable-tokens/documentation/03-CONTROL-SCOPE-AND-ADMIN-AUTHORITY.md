# Control Scope & Admin Authority

This document defines two boundaries that the rest of the architecture assumes
but does not spell out:

1. **The scope of programmable control** — what a registered CIP-113 policy does
   and does not govern (and why metadata/royalty management is out of scope).
2. **The scope of administrative authority** — exactly what the third-party
   path (the administrative / compliance action: forced transfer, seizure,
   freeze enforcement, burn), run through the standalone `third_party`
   validator, can and cannot do to a holder's UTxO.

Implementation lives in `validators/programmable_logic/third_party.ak`,
`lib/registry_node.ak`, and `lib/linked_list.ak`; this document is the normative
reading of their intent.

---

## 1. Scope of programmable control

### What CIP-113 controls

A registered policy's **user token** is subject to programmable control: every
ownership change / transfer is gated by the policy's `transfer_logic_script`,
enforced at the `programmable_logic_base` (PLB) address via the withdraw-zero
pattern. This is the framework's entire remit — *custody and movement of the
user token*.

### What CIP-113 does NOT control

Metadata (CIP-68 reference NFTs) and royalties (CIP-102 royalty tokens) are
**out of scope**. CIP-113 applies control at the **policy level** — every token
under a policy shares one rule set — whereas CIP-68/102 operate at the **token
level**, assigning different rules to different roles (user token vs reference
NFT vs royalty token) under the same policy. Baking companion-asset semantics
into the framework would overpower it and collide with those adjacent standards.

Companion assets are therefore handled by **substandards layered on top**: a
substandard's issuance/transfer logic can be CIP-68/102-aware and mint, move, or
lock reference/royalty tokens however those standards require. The framework
neither knows nor enforces companion-asset roles.

### The no-PLB-escape invariant is deliberate

The framework **never lets a registered policy's tokens leave the PLB** —
companion assets included. There is no carve-out; once a token is outside the
PLB the custody guarantee is void and re-entry/escape ambiguity follows. This is
a deliberate design choice.

Companion assets are accommodated **inside the PLB, under the same policy**, by a
CIP-68/102-aware substandard:

- The reference NFT (CIP-67 label 100) or royalty token (label 500) lives at the
  PLB like any token of the policy.
- **Transferring them is allowed** through the (owner-authorized) transfer path
  — the substandard's CIP-68/102-aware transfer and minting logic is responsible
  for ensuring it happens the *proper* way: moving the token, updating a
  reference NFT's datum (the transfer path does not pin output datums, so a
  CIP-68-aware substandard can permit datum updates), or handling royalty
  payouts. This is the substandard author's responsibility, not the framework's.
- **The third-party path is forbidden from interfering** with them: list labels
  100/500 in the node's protected prefixes (§2.2) and the administrator can
  neither seize nor burn the companion assets. Only the owner — through the
  substandard's transfer logic — can move them.
- CIP-68/102 consumers locate companion assets by *policy id + CIP-67 label asset
  name* and read their datum regardless of on-chain location, so
  interoperability holds without any escape.

In short: keep everything in the mini-ledger, make the substandard
CIP-68/102-aware, and protect the companion labels. The administrator cannot
seize, burn, or move them; a correctly-implemented substandard can.

---

## 2. Admin authority — the third-party scope

The administrative path (seizure / forced transfer) is the standalone
`third_party` withdraw-0 validator, carrying a `ThirdPartyRedeemer` and invoking
a policy's `third_party_transfer_logic_script`. A programmable-token spend reaches
it with a `SpendViaThirdParty` base redeemer, so `programmable_logic_base`
requires the `third_party` validator's withdraw-0 (not the transfer validator's). The subject of the
action is **policy A** — the registry node pointed to by `registry_node_idx`.
Everything else in the transaction is "non-subject".

### 2.1 Structural guarantees the base layer enforces

These hold unconditionally for every third-party action, independent of any
substandard:

| Guarantee | Enforced by |
|---|---|
| A's `third_party_transfer_logic_script` is invoked (withdraw-0) | `third_party.ak` |
| Each spent PLB UTxO is paired 1:1 with a continuing output preserving **address, datum, and reference script** byte-for-byte | `third_party.ak` |
| **Non-subject** token quantities are conserved per pair, byte-for-byte — no other policy can be injected, redirected, split, or destroyed | `third_party.ak` |
| The paired input **must already hold** policy A — the admin cannot conjure A onto a UTxO that never held it (anti-injection), nor drag an unrelated UTxO into the action (anti-DoS) | `third_party.ak` |
| The subject delta across all pairs reconciles against A's `mint`/burn; nothing escapes the PLB | `third_party.ak` |
| The action resolves exactly **one** registry node (`registry_node_idx`), hence exactly one policy per transaction (see §3.1) | `third_party` |

A single third-party action may act on **multiple UTxOs of the same policy A** in
one transaction; each spent PLB input gets its own paired output.

**On the subject policy, the admin may change amounts in any direction.**
A third-party action is a forced *transfer*, not only a removal: on each paired
output the subject policy's non-protected tokens may be **decreased, removed
entirely, increased, or left unchanged**. The framework does not require the
amount to change — an admin can re-spend a holder's UTxO without altering its
subject balance, a capability bounded by transaction fees rather than the
validator; custody is unaffected either way. The per-pair check pins the
protected subset (§2.2) and the non-subject tokens; the *direction* of the
subject change is otherwise unconstrained per pair. The aggregate rule (the
`mint`/burn-reconciled superset check above) keeps the *total* non-protected
subject amount within the PLB across all outputs — so amounts are
**redistributed** (or minted/burned), never created from nothing or made to
escape. An increase on one UTxO must therefore be backed by a decrease on
another seized input or by a mint of A.

### 2.2 Protected prefixes — extraction the admin cannot perform

The `RegistryNode` carries `protected_prefixes`: an **issuer-declared,
append-only** list of 4-byte CIP-67 asset-name label prefixes, kept in
**strictly ascending order** (which deduplicates it and lets the framework
validate the list and the append-only invariant in a single pass).

A third-party action may **not extract or burn** any token of policy A whose asset
name begins with a protected prefix. On each paired UTxO the protected-labelled
tokens must be **byte-equal** between input and continuing output; only the
non-protected remainder may be seized or otherwise changed. This is
**"preserve, not fail"**:
co-locating a protected token in a UTxO does **not** block the admin from
seizing everything else in it, and the protected token simply stays put.

The list is **append-only** — a registry-node update may only *add* prefixes,
never remove one. Protection, once declared, cannot be revoked to enable a later
seizure.

Typical use: protect CIP-68 reference NFTs (label 100, prefix `000643b0`) and
CIP-102 royalty tokens (label 500, prefix `001f4d70`), so administrative seizure
of the user token never sweeps the metadata/royalty infrastructure. This is the
mechanism by which the §1 scope boundary is enforced on the admin path.

### 2.3 Freeze vs. extract

The two administrative powers are **asymmetric**:

- **Freeze** (declining to authorise a spend) is **unconditional** — a
  substandard's `transfer_logic` can always refuse a transfer.
- **Extract** (seizing/removing tokens via the `third_party` path) is the **gated,
  conditional** power.

A consequence worth stating plainly: **hiding assets behind a non-cooperating
script is self-freezing, not evasion.** Tokens parked under a script that
refuses to authorise spends become unspendable *to the holder too*. So gating
extraction (but not freeze) is safe — there is no construction that both evades
seizure and keeps the tokens usable.

### 2.4 Holder scope is substandard policy, not framework

**Which holders are seizable is a substandard decision, not a framework rule.**
The only on-chain signal of who holds a token is the UTxO's **stake credential**:

- **VerificationKey** stake credential → a directly-held user wallet. Extraction
  is appropriate: the holder accepted the substandard's authority by using
  CIP-113 tokens at all.
- **Script** stake credential → **ambiguous**. It could be a smart-contract
  wallet, or a DEX / lending pool / escrow. These are indistinguishable as
  `Credential`s. Any hard-coded framework rule ("script-staked is seizable", or
  "is not") is wrong for someone.

The framework therefore provides **primitives**; the substandard composes the
policy. The guiding principle (and the real-world and DeFi-empirical norm —
secured-creditor priority cannot be unilaterally overridden, and `forcedTransfer`
against pooled contracts is socially uncallable):

> The third-party path can **freeze** (block spending) anywhere, but should not
> unilaterally **extract** assets from a UTxO whose validator has not opted in.

Example: a lending protocol holding policy-A collateral at the PLB is in scope
for seizure *as the base layer is written*. Whether seizing it is correct —
given the borrower's debt and other lenders' claims — is exactly the kind of
judgement the framework cannot make for every case, and must be left to the
substandard.

### 2.5 DeFi-aware substandard reference pattern

A substandard that wants to respect script-owned positions can gate extraction
of **script-staked** inputs with one of two patterns:

- **Allowlist** — a script-staked input is seizable only if its stake script is
  on an issuer-maintained list of known protocols.
- **Consent** — a script-staked input is seizable only if that script's
  withdraw-0 is invoked in the same transaction (the protocol consents to the
  seizure).

Both gate **extraction only**; freeze remains unconditional (§2.3). Note this is
substandard-level guidance — the base framework does not enforce it, precisely
because no single rule is correct for every script (§2.4).

---

## 3. Limitations & lifecycle

### 3.1 One policy per third-party transaction

The `third_party` withdraw-0 validator runs once per transaction, and its
`ThirdPartyRedeemer` resolves exactly one registry node (`registry_node_idx`) —
therefore exactly one policy. A single third-party action can act on many UTxOs
of the *same* policy, but **cannot atomically seize across two policies**.

A compliance operation spanning multiple policies requires multiple sequential
transactions (accepting an exposure window between them). Atomic multi-policy
seizure was prototyped and **deliberately not adopted**: making the path
multi-policy imposed a significant execution-cost and script-size tax on the
common single-policy case, which was judged not worth it. This is an accepted,
permanent limitation.

### 3.2 Registry-node update authority

A node's three mutable fields — `transfer_logic_script`,
`third_party_transfer_logic_script`, `global_state_cs` — and growth of
`protected_prefixes` can be changed through the registry lifecycle (update) path,
authorised by the registration credential (`minting_logic_script`). `key`,
`next`, and `minting_logic_script` are frozen.

Two properties integrators must understand:

- The change is **retroactive** — updated transfer / third-party logic governs
  **all existing holders'** tokens on their next spend.
- It can **flip credential type** (Script ↔ VerificationKey) — i.e. move a token
  between script-enforced and signature-gated logic.

Therefore the **registry node is the live source of truth**: wallets, indexers,
and integrators must read the current node, never cache its logic credentials.

**Lifecycle is not issuance — but shares a credential.** The authorising
credential (`minting_logic_script`) is also the token's *issuance* authority, so
by default the party that can mint can also register and update the node. A
substandard that wants these to be distinct powers must separate them inside its
issuance logic (see
[`09-DEVELOPING-SUBSTANDARDS.md`](./09-DEVELOPING-SUBSTANDARDS.md#registry-lifecycle--upgradeability)).
Independently, the base layer forbids a node-spend — an update, or the
covering-node spend of an insert — from minting or burning **that node's own
token** in the same transaction (enforced by `registry_spend`, the sole spender
of every node). So a registry lifecycle operation and an issuance of the same
policy are always **separate transactions**, never conflated in one.

### 3.3 De-registration

There is **no de-registration**. The lifecycle path supports *update* only; a
node cannot be removed or flagged de-registered. Deleting a node would let a
policy's tokens escape the framework's custody guarantee (§1), so removal is
deliberately not provided.

### 3.4 Seizure is per-UTxO; fragmentation is not prevented

A third-party action operates on the PLB inputs a transaction includes. A holder's
balance of the subject policy may be spread across many UTxOs (fragmentation),
and the framework does not force consolidation. Consequences an administrator
must understand:

- A single third-party action can act on many UTxOs of the *same* policy, but only
  those the transaction actually spends. To fully seize a holder, the
  administrator must include **all** of that holder's subject-policy UTxOs.
- A holder can therefore fragment a balance across many small UTxOs to raise the
  cost of — or push past the transaction-size / execution-budget limits for — a
  single atomic seizure. Full seizure may then need **multiple transactions**,
  with the usual exposure window between them.
- This is inherent to the eUTxO model, not a framework defect: there is no
  account-style "seize the whole balance in one call". Holder-driven
  consolidation (the Unfracking action) and substandard-level UTxO-shape
  guidance reduce fragmentation in practice, but the administrator cannot assume
  a holder's balance lives in a single UTxO.

---

*See also: [`02-ARCHITECTURE.md`](./02-ARCHITECTURE.md) for the validator
architecture and the third-party (administrative) flow; [`09-DEVELOPING-SUBSTANDARDS.md`](./09-DEVELOPING-SUBSTANDARDS.md)
for writing transfer and third-party logic.*

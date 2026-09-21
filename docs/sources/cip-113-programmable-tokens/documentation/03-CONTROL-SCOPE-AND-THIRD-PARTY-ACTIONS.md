# Control Scope & Third-Party Actions

This document defines two boundaries that the rest of the architecture assumes
but does not spell out:

1. **The scope of programmable control** — what a registered CIP-113 policy does
   and does not govern (and why metadata/royalty management is out of scope).
2. **The scope of third-party action** — exactly what the third-party
   path (a compliance action: forced transfer, seizure,
   freeze enforcement, burn), run through the standalone `third_party`
   validator, can and cannot do to a holder's UTxO.

The withdraw-0 validator is `third_party` (`validators/third_party.ak:39`); it
calls the invariant module `validators/programmable_logic/third_party.ak`,
which holds the rules this document is the normative reading of. The
registry-node shape and lifecycle mechanics referenced throughout are
`lib/registry_node.ak` and `lib/linked_list.ak`.

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
- **The third-party path reaches them like any other subject-policy token.** A
  `RegistryNode` has no asset-name-scoped field — its seven fields are `key`,
  `next`, and five credential/currency fields, none of them a label list
  (`lib/registry_node.ak:51-81`) — and the third-party per-pair rules operate on
  policy A as a whole, with no carve-out by asset name
  (`validators/programmable_logic/third_party.ak:99-120`, implemented at
  `:121-280`). A companion asset minted under the same policy id as the user
  token is therefore exactly as reachable by a third-party action on policy A as the
  user token is — a third-party action may decrease, remove, increase, or leave it
  unchanged on each paired output, the same as any other subject-policy token
  (§2.1).
- **Protecting a companion asset from a third-party action is a substandard
  decision, not a framework guarantee** — the same "framework provides
  primitives, the substandard composes the policy" pattern as holder scope
  (§2.3). Two substandard-level options: (a) the policy's
  `third_party_logic_script` — the script whose withdraw-zero the base layer
  requires present (`validators/programmable_logic/third_party.ak:29`) — runs
  with full visibility into the transaction and can itself refuse to authorise
  a seizure that disturbs the protected asset names; the base layer only checks
  that this script's withdraw-zero is invoked, never what it itself checks. Or
  (b) mint the companion asset under a **different** policy id, so it becomes
  "non-subject" to any action on policy A and is conserved byte-for-byte by the
  per-pair rule (§2.1) — at the cost of the CIP-68/102 same-policy-id
  convention.
- CIP-68/102 consumers locate companion assets by *policy id + CIP-67 label asset
  name* and read their datum regardless of on-chain location, so
  interoperability holds without any escape.

In short: keep everything in the mini-ledger, and decide deliberately how — or
whether — to keep a companion asset out of a third-party action's reach on policy A.
The framework does not decide this for you; it gives you the same policy id
(reachable, substandard-enforced protection if you want it) or a distinct
policy id (framework-enforced conservation, by construction) to choose from.

---

## 2. Scope of third-party action

The third-party path (seizure / forced transfer) is the standalone
`third_party` withdraw-0 validator, carrying a `ThirdPartyRedeemer` and invoking
a policy's `third_party_logic_script`. A spend reaches it the way every spend
does: `programmable_logic_base` requires the dispatcher's withdraw-zero
(`programmable_logic_global_cred`, protocol-params field 0 —
`validators/programmable_logic_base.ak:72-74`), and the dispatcher requires
`third_party`'s withdraw-zero under a `ThirdPartyAct` redeemer
(`validators/programmable_logic_global.ak:65`, `:69`). The subject of the
action is **policy A** — the registry node pointed to by `registry_node_idx`
(`lib/types.ak:50-55`). Everything else in the transaction is "non-subject".

### 2.1 Structural guarantees the base layer enforces

These hold unconditionally for every third-party action, independent of any
substandard:

| Guarantee | Enforced by |
|---|---|
| A's `third_party_logic_script` is invoked (withdraw-0) | `validators/programmable_logic/third_party.ak:29` |
| Each spent PLB UTxO is paired 1:1 with a continuing output preserving **address, datum, and reference script** byte-for-byte | `validators/programmable_logic/third_party.ak:196-198` |
| Lovelace is **ratcheted, not frozen** — the paired output must carry at least the input's lovelace, never less | `validators/programmable_logic/third_party.ak:211-217` |
| **Non-subject** token quantities are conserved per pair, byte-for-byte — no other policy can be injected, redirected, split, or destroyed | `validators/programmable_logic/third_party.ak:221-229`, `:254-257` |
| The paired input **must already hold** policy A — a third-party action cannot conjure A onto a UTxO that never held it (anti-injection), nor drag an unrelated UTxO into the action (anti-DoS) | `validators/programmable_logic/third_party.ak:253` |
| The subject delta across all pairs reconciles against A's `mint`/burn; nothing escapes the PLB | `validators/programmable_logic/third_party.ak:181-184` |
| The action resolves exactly **one** registry node (`registry_node_idx`), hence exactly one policy per transaction (see §3.1) | `lib/types.ak:50-55` |

A single third-party action may act on **multiple UTxOs of the same policy A** in
one transaction; each spent PLB input gets its own paired output.

**On the subject policy, a third-party action may change amounts in any direction.**
A third-party action is a forced *transfer*, not only a removal: on each paired
output the subject policy's tokens may be **decreased, removed entirely,
increased, or left unchanged**
(`validators/programmable_logic/third_party.ak:99-120`, implemented at
`:121-280`). The framework does not require the amount to change — a third-party
action can re-spend a holder's UTxO without altering its subject balance, a
capability bounded by transaction fees rather than the validator; custody is
unaffected either way. The per-pair check pins the non-subject tokens (and, on
lovelace, only a floor — see the table above); the *direction* of the subject
change is otherwise unconstrained per pair. The aggregate rule (the
`mint`/burn-reconciled superset check above) keeps the *total* subject amount
within the PLB across all outputs — so amounts are **redistributed** (or
minted/burned), never created from nothing or made to escape. An increase on
one UTxO must therefore be backed by a decrease on another seized input or by a
mint of A.

### 2.2 Freeze vs. extract

The two powers are **asymmetric**:

- **Freeze** (declining to authorise a spend) is **unconditional** — a
  substandard's `transfer_logic` can always refuse a transfer.
- **Extract** (seizing/removing tokens via the `third_party` path) is the **gated,
  conditional** power described in §2.1.

A consequence worth stating plainly: **hiding assets behind a non-cooperating
script is self-freezing, not evasion.** Tokens parked under a script that
refuses to authorise spends become unspendable *to the holder too*. So gating
extraction (but not freeze) is safe — there is no construction that both evades
seizure and keeps the tokens usable.

### 2.3 Holder scope is substandard policy, not framework

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
for seizure *as the base layer is written* (§2.1). Whether seizing it is
correct — given the borrower's debt and other lenders' claims — is exactly the
kind of judgement the framework cannot make for every case, and must be left to
the substandard.

### 2.4 DeFi-aware substandard reference pattern

A substandard that wants to respect script-owned positions can gate extraction
of **script-staked** inputs with one of two patterns:

- **Allowlist** — a script-staked input is seizable only if its stake script is
  on an issuer-maintained list of known protocols.
- **Consent** — a script-staked input is seizable only if that script's
  withdraw-0 is invoked in the same transaction (the protocol consents to the
  seizure).

Both gate **extraction only**; freeze remains unconditional (§2.2). Note this is
substandard-level guidance — the base framework does not enforce it, precisely
because no single rule is correct for every script (§2.3).

---

## 3. Limitations & lifecycle

### 3.1 One policy per third-party transaction

The `third_party` withdraw-0 validator runs once per transaction, and its
`ThirdPartyRedeemer` names exactly one registry node (`registry_node_idx`,
`lib/types.ak:50-55`) — therefore exactly one policy. A single third-party
action can act on many UTxOs of the *same* policy, but **cannot atomically
seize across two policies**.

A compliance operation spanning multiple policies requires multiple sequential
transactions, accepting an exposure window between them. This is a permanent
limitation, by design: a multi-policy path would carry its cost — walking a
second policy's tokens through the same per-pair and aggregate checks
(§2.1) — on every single-policy seizure, the common case, to serve the rare
cross-policy one.

### 3.2 Registry-node update authority

A node's four mutable fields — `transfer_logic_script`,
`third_party_logic_script`, `unfracking_logic_script`, and `global_state_cs` —
can be changed through the registry lifecycle (update) path, authorised by the
registration credential (`minting_logic_script`). `key`, `next`, and
`minting_logic_script` are frozen (`lib/linked_list.ak:184-209`).

The update path itself is gated on `minting_logic_script`'s credential type: it
must be a `Script` credential whose withdraw-zero is present in the
transaction — a node registered with a `VerificationKey` `minting_logic_script`
can never be updated in place (`validators/registry.ak:226-235`).

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
token** in the same transaction: the `registry` validator's `spend` handler
rejects it (`validators/registry.ak:187-188`, inside the handler at
`:174-238`), and it is the sole spender of every node. So a registry lifecycle
operation and an issuance of the same policy are always **separate
transactions**, never conflated in one.

### 3.3 De-registration

There is **no de-registration**. The lifecycle path supports *update* only; a
node cannot be removed or flagged de-registered. Deleting a node would let a
policy's tokens escape the framework's custody guarantee (§1), so removal is
deliberately not provided.

### 3.4 Seizure is per-UTxO; fragmentation is not prevented

A third-party action operates on the PLB inputs a transaction includes. A holder's
balance of the subject policy may be spread across many UTxOs (fragmentation),
and the framework does not force consolidation. Consequences for a third-party
action to account for:

- A single third-party action can act on many UTxOs of the *same* policy, but only
  those the transaction actually spends. To fully seize a holder, the
  transaction must include **all** of that holder's subject-policy UTxOs.
- A holder can therefore fragment a balance across many small UTxOs to raise the
  cost of — or push past the transaction-size / execution-budget limits for — a
  single atomic seizure. Full seizure may then need **multiple transactions**,
  with the usual exposure window between them.
- This is inherent to the eUTxO model, not a framework defect: there is no
  account-style "seize the whole balance in one call". Holder-driven
  consolidation (the Unfracking action) and substandard-level UTxO-shape
  guidance reduce fragmentation in practice, but a third-party action cannot assume
  a holder's balance lives in a single UTxO.

---

*See also: [`02-ARCHITECTURE.md`](./02-ARCHITECTURE.md) for the validator
architecture and the third-party flow; [`09-DEVELOPING-SUBSTANDARDS.md`](./09-DEVELOPING-SUBSTANDARDS.md)
for writing transfer and third-party logic.*

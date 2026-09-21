# Developing a New Substandard

This guide is for developers who want to create new substandards for CIP-113 programmable tokens. A substandard defines the rules that govern how a specific programmable token can be issued, transferred, restructured, and acted on through its third-party logic.

**Target audience**: Cardano developers familiar with Aiken and the UTXO model who want to implement custom token compliance logic (e.g., BaFin, CMTA, or other regulatory frameworks).

---

## Table of Contents

1. [What is a Substandard?](#what-is-a-substandard)
2. [The Core Infrastructure](#the-core-infrastructure)
3. [What You Must Implement](#what-you-must-implement)
4. [The Withdraw-Zero Pattern](#the-withdraw-zero-pattern)
5. [Global State](#global-state)
6. [Token Lifecycle from the Substandard's Perspective](#token-lifecycle-from-the-substandards-perspective)
7. [Registry Lifecycle & Upgradeability](#registry-lifecycle--upgradeability)
8. [Walkthrough: Dummy Substandard](#walkthrough-dummy-substandard)
9. [Walkthrough: Freeze-and-Seize Substandard](#walkthrough-freeze-and-seize-substandard)
10. [Off-Chain Integration (Evolution SDK)](#off-chain-integration-evolution-sdk)
11. [Testing Your Substandard](#testing-your-substandard)

---

## What is a Substandard?

CIP-113 follows a layered design. The **core standard** provides shared infrastructure — a token registry, a custody model, a dispatcher and three delegate validators — that is deployed once and used by all programmable tokens. **Substandards** are pluggable policy modules that define the actual rules a specific token must obey.

Think of the core standard as the operating system and a substandard as an application that runs on it. Different tokens can use different substandards depending on their compliance requirements:

- A stablecoin might use a **freeze-and-seize** substandard for sanctions compliance
- A tokenized security might use a **whitelist** substandard for investor accreditation
- A regulated fund token might use a **BaFin** or **CMTA** substandard for jurisdiction-specific rules

Two reference substandards exist:

| Substandard | Purpose | Complexity |
|-------------|---------|------------|
| **Dummy** | Minimal reference implementation | Very low — checks a redeemer value |
| **Freeze-and-Seize** | Denylist-aware transfers, token seizure | Medium — on-chain denylist linked list |

Both live outside this repository. This guide describes the **interface** the core standard presents to them; it does not describe their source files.

The goal is for the community to build many more substandards for various regulatory frameworks and use cases.

---

## The Core Infrastructure

As a substandard developer, you do **not** implement or modify the core CIP-113 infrastructure. The following components are deployed once by the protocol operator and shared by all programmable tokens.

Throughout this document we use one abbreviation — **Programmable Logic Base
(PLB)**, the spending validator that custodies all programmable token UTxOs.
PLB requires exactly one thing: the withdraw-zero of the **dispatcher**,
`programmable_logic_global`, whose credential it reads from the protocol-params
datum (`validators/programmable_logic_base.ak:72-74`). The dispatcher, in turn,
requires the withdraw-zero of one of three **delegate** validators —
`transfer`, `third_party`, `unfracking` — selected by its own redeemer
(`validators/programmable_logic_global.ak:63-69`). The delegate then requires
the credential your registry node names for that kind of action.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                            CORE INFRASTRUCTURE                             │
│                       (Already deployed — don't touch)                     │
│                                                                            │
│   ┌───────────────────────┐                                                │
│   │ programmable_logic    │  spend, once per programmable-token input      │
│   │ _base  (PLB)          │  requires the dispatcher's withdraw-0          │
│   │ Custodies all tokens  │                                                │
│   └───────────┬───────────┘                                                │
│               ▼                                                            │
│   ┌───────────────────────┐  withdraw, once per transaction                │
│   │ programmable_logic    │  requires the delegate its redeemer names      │
│   │ _global  (dispatcher) │  TransferAct | ThirdPartyAct | UnfrackingAct   │
│   └───┬───────────┬───────┴───────┐                                        │
│       ▼           ▼               ▼                                        │
│   ┌────────┐ ┌─────────────┐ ┌────────────┐   withdraw, once per tx        │
│   │transfer│ │ third_party │ │ unfracking │   each requires YOUR           │
│   │        │ │ seize /     │ │ same-owner │   credential from the          │
│   │        │ │ clawback    │ │ restructure│   policy's registry node       │
│   └────────┘ └─────────────┘ └────────────┘                                │
│                                                                            │
│   ┌──────────────────────┐   ┌──────────────────────────────────────────┐  │
│   │ registry             │   │ Issuance infrastructure                  │  │
│   │ (mint + spend)       │   │ issuance_mint (per token, permanent),    │  │
│   │ Sorted linked list   │   │ issuance_logic (protocol-wide, live),    │  │
│   │ of registered tokens │   │ issuance_cbor_hex_mint, protocol_params, │  │
│   │                      │   │ always_fail                              │  │
│   └──────────────────────┘   └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
                                   │
                         ┌─────────┴──────────┐
                         │  YOUR SUBSTANDARD  │
                         │                    │
                         │  - Issuance logic  │
                         │  - Transfer logic  │
                         │  - 3rd party logic │
                         │  - Unfracking hook │
                         │  - State mgmt (opt)│
                         └────────────────────┘
```

### What each core component does

| Component | What it does | Why you don't touch it |
|-----------|-------------|----------------------|
| **`programmable_logic_base` (PLB)** | Spending validator that custodies all programmable token UTxOs. Reads one credential out of the protocol-params datum — `programmable_logic_global_cred`, field 0 — and requires that credential's withdraw-zero at the index its redeemer witnesses (`validators/programmable_logic_base.ak:66-74`). It has no action arm. | Every token holder's UTxO lives at a PLB address; its hash is baked into every one of those addresses, so it can never be replaced. |
| **`programmable_logic_global`** | The dispatcher. Its redeemer names an action, and it requires the matching delegate's withdraw-zero against a hash baked in at compile time (`validators/programmable_logic_global.ak:48-69`). It reads no datum and touches no value. | It is the link that turns "some dispatcher ran" into "the right delegate ran". Replacing the dispatch layer is a protocol-params datum rewrite, not a token migration. |
| **`transfer` / `third_party` / `unfracking`** | The three delegates, each a withdraw-zero validator running once per transaction. Each resolves the subject policy's registry node from a reference input and requires the credential that node names for its kind of action (`validators/programmable_logic/transfer.ak:256-264`, `validators/programmable_logic/third_party.ak:24-29`, `validators/programmable_logic/unfracking.ak:107-120`). | They call *your* validators — you don't call them. |
| **`registry`** | One validator, two handlers on one hash (`validators/registry.ak:49`): `mint` builds and extends the sorted linked list of registered policies, `spend` guards every node UTxO. Each node stores which substandard credentials govern that token. | Your token gets registered here, but you don't modify the registry validator. |
| **Issuance infrastructure** | `issuance_mint` — the permanent per-token policy whose applied hash **is** the token's policy id (`validators/issuance_mint.ak:34-41`); `issuance_logic` — the protocol's replaceable issuance rules, named live by the protocol-params datum (`validators/issuance_logic.ak:44-62`); `issuance_cbor_hex_mint`; `protocol_params` (mint + spend on one hash, `validators/protocol_params.ak:228`); `always_fail`. | Handles the mechanics of minting and custody. Your issuance logic validator is invoked *by* `issuance_mint`. |

**Key insight**: Your substandard validators are invoked by the core infrastructure, not the other way around. The delegate validator looks up your token in the registry, finds your validator credentials, and requires that they are present in the transaction's withdrawals.

---

## What You Must Implement

A substandard registers **four credentials** in its token's registry node
(`lib/registry_node.ak:51-81`). Three are required for the token to function;
the fourth is an opt-in.

| Registry field | Invoked by | Required? |
|---|---|---|
| `minting_logic_script` | `issuance_mint` on every mint and burn (`validators/issuance_mint.ak:46`); `registry`'s mint handler at registration (`validators/registry.ak:109-110`); `registry`'s spend handler on a node update (`validators/registry.ak:227-234`) | Yes |
| `transfer_logic_script` | `transfer` (`validators/programmable_logic/transfer.ak:264`) | Yes |
| `third_party_logic_script` | `third_party` (`validators/programmable_logic/third_party.ak:29`) | Yes |
| `unfracking_logic_script` | `unfracking` (`validators/programmable_logic/unfracking.ak:120`) | Optional; unset means unfracking is forbidden |

All four are `Credential`s. Three of them are normally `Script` credentials —
withdraw-zero stake validators you write — but the type permits a
`VerificationKey`, with consequences spelled out below.

### 1. Issuance Logic (withdraw)

Invoked when tokens are **minted or burned**. `issuance_mint` — the permanent policy whose hash is your token's policy id — requires your credential's withdraw-zero by direct membership in the withdrawal map:

```aiken
// validators/issuance_mint.ak:46
expect unsafe_pairs.has_key_or_fail(self.withdrawals, minting_logic_cred)
```

Your issuance logic validator decides **who can mint and burn** tokens. This could be:
- A specific admin key must sign
- A multisig of N-of-M keys
- A DAO governance script
- Any custom logic

> **An issuance transaction carries a second withdraw-zero that is not yours.**
> `issuance_mint` also requires the **protocol's** `issuance_logic` credential,
> read live from protocol-params field 1, and requires that its redeemer
> *covers the policy being minted* (`validators/issuance_mint.ak:52-63`,
> `:79-98`). That redeemer is a `Pairs<PolicyId, MintingRegistryProof>`
> (`lib/types.ak:184-185`) and the mint fails unless your policy id is one of
> its keys. Both withdrawals are the builder's responsibility; see
> [Minting or burning tokens](#minting-or-burning-tokens).

> **This same credential is also your registry-lifecycle authority.** It is
> checked not only on mint/burn, but also when the token is registered and when
> its registry node is updated. If those should be different powers — or if
> your policy forbids minting during registration — your issuance logic must
> tell the contexts apart; see
> [Your issuance logic must know why it is running](#your-issuance-logic-must-know-why-it-is-running).

### 2. Transfer Logic (withdraw)

Invoked when an **owner transfers** their tokens. The `transfer` validator resolves the policy's registry node from a reference input, checks the node's `key` equals the policy, and requires `transfer_logic_script`'s withdraw-zero (`validators/programmable_logic/transfer.ak:256-264`).

Your transfer logic validator decides **what conditions must be met for a transfer**. This could be:
- Check sender/recipient against a denylist (freeze-and-seize)
- Verify both parties are on a whitelist (KYC/accreditation)
- Enforce time-locks or vesting schedules
- Any custom validation

> **Companion assets (CIP-68 / CIP-102) are your responsibility, not the
> framework's.** Reference NFTs and royalty tokens stay in the PLB under the
> same policy, and the base layer draws no distinction between them and any
> other token of your policy: a companion asset is ordinary subject value on
> the third-party path (`validators/programmable_logic/third_party.ak:99-120`).
> Transferring them is allowed — your CIP-68/102-aware transfer and minting
> logic must ensure it happens the proper way (moving them, updating a
> reference NFT's datum, handling royalties) — and protecting them from your
> own third-party action is your third-party logic's job. See
> [`03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md`](./03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md) §1.

### 3. Third-Party Transfer Logic (withdraw)

Invoked when a **third party** (not the token owner) moves tokens. The `third_party` validator resolves the subject policy's registry node from the reference input its redeemer names and requires `third_party_logic_script`'s withdraw-zero (`validators/third_party.ak:92-104`, `validators/programmable_logic/third_party.ak:24-29`). This is used for actions like:
- Seizing tokens from a sanctioned address
- Forced transfers by court order
- Emergency recovery operations

**Scope and responsibility.** The base layer guarantees the structural envelope
— paired-output address/datum/reference-script preservation, byte-for-byte
conservation of every non-subject **policy**, anti-injection, and an aggregate
conservation rail on the subject policy
(`validators/programmable_logic/third_party.ak:99-120`, the rules in one place;
implemented at `:121-280`).

> **Lovelace is the exception to the byte-identity, and your logic must expect
> it.** Ada is peeled off both sides of each pair before the asset lists are
> compared, and it is **ratcheted, not conserved**: the paired continuing
> output must carry *at least* the input's lovelace
> (`validators/programmable_logic/third_party.ak:211-217`). `>=` rather than
> `==` because exact equality forbade the top-up that absorbs a rise in the
> min-ADA protocol parameter, which would make a third-party action on an
> existing UTxO unsatisfiable forever; and `>=` rather than free because
> lovelace is not a programmable asset, so accepting less would let a
> third-party action drain the holder's ada while seizing. If your third-party logic
> asserts exact ada equality per pair, it re-creates the dead end the base
> layer exists to avoid.

What it does **not** decide is
*which tokens* and *whose UTxOs* are in scope: every token of the subject policy
is ordinary subject value to the base layer, and a `VerificationKey`-staked UTxO
is a user wallet (extraction is appropriate) while a script-staked UTxO is
ambiguous (smart wallet vs DeFi pool). **Your** third-party logic owns both
calls. Two reference patterns gate extraction of script-staked inputs — an
issuer **allowlist** of known protocols, or **consent** (the script's own
withdraw-0 must fire in the same tx). Only *extraction* is gated; *freeze* is
unconditional. See
[`03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md`](./03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md) §2 for the full specification.

### 4. Unfracking Hook (withdraw, optional)

Invoked when a holder performs a **same-owner restructuring**: moving one
policy's tokens out of a UTxO that holds several, without changing owner. The
motivating case is a UTxO holding several policies where a freeze scoped to one
policy immobilises them all.

The `unfracking` validator reads `unfracking_logic_script` from the acted-on
policy's registry node and requires its withdraw-zero
(`validators/programmable_logic/unfracking.ak:107-120`). What you put in that
field decides the policy's posture:

- **`empty_vkey`** — `VerificationKey(#"")`, the value a node is born with
  unless the registrar sets otherwise (`lib/registry_node.ak:26`; the registrar's choice is bounded at
  `lib/linked_list.ak:138-143`).
  **Unfracking is forbidden for this policy.** No ledger transaction can carry a
  withdrawal keyed by an empty hash — a reward account is a header byte plus a
  28-byte hash, and anything shorter fails phase-1 deserialisation — so the
  single `has_key_or_fail` check is also the default-deny
  (`validators/programmable_logic/unfracking.ak:111-120`). This is least
  permission by default: no script, no party.
- **A `Script` credential** — delegates to your hook validator, which runs as an
  ordinary withdraw-zero and can enforce whatever restructuring constraints
  your token needs (a stateful, datum-carrying token typically wants its own
  rules here).
- **A `VerificationKey` credential** — gives signature-gated unfracking: a
  withdrawal against a vkey reward account requires that key's signature, so
  only that party can restructure.

The field is **mutable** through the registry-node update path, exactly like
the other logic fields — an issuer may set it, change it, or unset it back to
`empty_vkey` (`lib/linked_list.ak:203-207`).

What the base layer enforces around your hook, so you do not have to: `tx.mint`
is zero; every PLB input carries the same full address and that single owner
authorises once (signature for a vkey stake credential, withdraw-zero for a
script one); each PLB input is paired positionally with a continuing output
whose address, datum and reference script are byte-identical and whose
non-acted **policies** are byte-identical; and the acted policy is stripped
*entirely* from each continuing output — partial strips are rejected
(`validators/programmable_logic/unfracking.ak:37-77`, implemented from `:96`).

**Lovelace is again the exception, and here it is not constrained at all.** Ada
is dropped from both sides before the lockstep walk and is never read
(`validators/programmable_logic/unfracking.ak:288-298`) — not even ratcheted, as
the third-party path does. The single owner authorised the whole action, so
nothing is being taken from anyone; constraining ada would only re-create the
min-UTxO dead end. What *is* pinned is the acted policy: its total over the
non-paired outputs at the owner address must equal its total over the PLB
inputs, which is what forces every acted token to land back at the owner
(`validators/programmable_logic/unfracking.ak:60-68`). If your hook needs ada to
behave a particular way, your hook is where that rule goes.

### Summary

```
┌────────────────────────────────────────────────────────────────────────┐
│                    YOUR SUBSTANDARD (4 credentials)                    │
│                                                                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌───────────────┐  │
│  │Issuance Logic│ │Transfer Logic│ │ 3rd Party    │ │Unfracking Hook│  │
│  │ (withdraw)   │ │ (withdraw)   │ │ Logic        │ │ (withdraw)    │  │
│  │              │ │              │ │ (withdraw)   │ │               │  │
│  │ Who can      │ │ Rules for    │ │ Third-party  │ │ Same-owner    │  │
│  │ mint/burn?   │ │ owner        │ │ operations   │ │ restructuring │  │
│  │ + lifecycle  │ │ transfers    │ │              │ │ (or unset =   │  │
│  │   authority  │ │              │ │              │ │  forbidden)   │  │
│  └──────────────┘ └──────────────┘ └──────────────┘ └───────────────┘  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ State Management (optional)                                      │  │
│  │ Denylists, whitelists, config NFTs, etc.                         │  │
│  │ Additional mint + spend validators as needed                     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

All four are recorded in the **RegistryNode** when a token is registered. The
record has **seven fields** and the order is the CBOR layout your off-chain
code encodes and decodes (`lib/registry_node.ak:51-81`):

```aiken
pub type RegistryNode {
  key: ByteArray,                        // 0 — policy id of the registered token
  next: ByteArray,                       // 1 — next key in sorted order
  minting_logic_script: Credential,      // 2 — YOUR issuance / lifecycle authority
  transfer_logic_script: Credential,     // 3 — YOUR transfer logic
  third_party_logic_script: Credential,  // 4 — YOUR third-party logic
  unfracking_logic_script: Credential,   // 5 — YOUR unfracking hook (empty_vkey = forbidden)
  global_state_cs: ByteArray,            // 6 — YOUR global state NFT policy (optional)
}
```

The `minting_logic_script` (your issuance logic credential) is both **stored in the registry node** and **baked into the `issuance_mint` policy** as a compile-time parameter. The `registry` validator's mint handler cryptographically binds the two at registration: the issuance template parameterised with this credential must hash to `key` (`expect_programmable_token_id_valid`, `validators/registry.ak:91-97`), so the two can never disagree. It is frozen for the life of the node and doubles as the registry-lifecycle authority — see [Registry Lifecycle & Upgradeability](#registry-lifecycle--upgradeability).

> **Note**: For simple substandards, you can reuse the same validator for multiple purposes. The dummy substandard registers one script for both transfer and third-party logic. The freeze-and-seize substandard registers its issuer-admin script for both issuance and third-party logic — seizure is authorized by the same admin credential that controls minting. Design your validators based on which operations share the same authorization model.

### The `max_inline_datum_bytes` deployment invariant

Every PLB output must carry no datum hash, no reference script, and — where it
carries a programmable policy — an inline datum serialising to at most
`max_inline_datum_bytes` (`lib/prog_assets.ak:291-302`).

That bound is **not** a protocol-params datum field. It is a compile-time
parameter of four scripts, and **all four must be deployed with the same value**:

| script | parameter declared at |
|---|---|
| `transfer` | `validators/transfer.ak:38` |
| `third_party` | `validators/third_party.ak:42` |
| `unfracking` | `validators/unfracking.ak:58` |
| `issuance_logic` | `validators/issuance_logic.ak:61` |

**Why this is safety-critical, and why nothing on-chain can enforce it.** Each of
the four bounds only the outputs *it* creates, and no script can read another
script's parameters. So a UTxO born under a **laxer** bound than the one
`transfer` or `third_party` must later carry it under is **frozen and
unseizable** — permanently, with no repair path. The rule is stated at
`lib/prog_assets.ak:285-290` — all four must be deployed with the same value
(or, minimally, every creator's bound must be less than or equal to every
carrier's), "correct by composition, at deployment" — and again at
`validators/issuance_logic.ak:54-60`, which draws out the consequence for the
issuance path in as many words: a datum born under a laxer bound than the one
`transfer` or `third_party` must later carry it under is a frozen, unseizable
UTxO, and nothing on-chain can compare the four values.

**What this means for you.** Your substandard does not take this parameter, so
you cannot set it wrongly yourself — but your issuance logic decides what datum
a minted PLB output carries, and that datum must fit the bound every one of the
four deployed scripts was compiled with. Read the deployed value from the
deployment's blueprint; it is not in the protocol-params datum, so there is
nowhere else to read it. If you need a rule finer than a byte count, put it in
your own minting logic: the core bound is the floor under your rules, not a
replacement for them (`lib/prog_assets.ak:280-283`).

---

## The Withdraw-Zero Pattern

All substandard validators use the **withdraw-zero pattern**. This is a Cardano technique where a stake validator is invoked by including a 0-ADA withdrawal in the transaction:

```
Transaction withdrawals (a transfer) — listed by role, NOT in ledger order:
  - (programmable_logic_global, 0 ADA)  ← Core dispatcher, required by every PLB spend
  - (transfer,                  0 ADA)  ← Core transfer delegate
  - (your_transfer_logic,       0 ADA)  ← Your validator
```

The order above is the order these three are *explained* in, and it is not the
order the ledger presents them to a validator. Never read a position off a list
like this one: derive every `wdrl_idx` from the sorted set, as in
[Withdrawal indices](#withdrawal-indices-wdrl_idx).

A transfer therefore needs **three** script withdrawals, not two. A transaction
carrying only `transfer` and your transfer logic fails at `programmable_logic_base`
before the transfer validator ever runs.

### Why stake validators instead of spending validators?

- **Spending validators** run once **per input** — if a transaction consumes 10 UTxOs, the spending validator executes 10 times
- **Stake validators** (via withdrawal) run **once per transaction** — regardless of how many inputs

This is critical for performance. Your transfer logic might need to check a denylist or verify signatures. Running that once per transaction instead of once per input saves a substantial execution budget.

### What your withdraw handler receives

```aiken
withdraw(redeemer: YourRedeemerType, account: Credential, self: Transaction) {
  // redeemer  — your custom data (proofs, signatures, whatever you need)
  // account   — the credential this withdrawal is for (your validator's own credential)
  // self      — the full transaction context (inputs, outputs, withdrawals, etc.)
}
```

Your validator has full access to the transaction via `self`. It can inspect inputs, outputs, reference inputs, other withdrawals, signatories, mints — anything needed to enforce your rules.

### Your credential must also carry a `publish` handler

A credential cannot appear in a transaction's withdrawals until its stake
address is **registered**, and after Conway registering a *script* credential
requires that script's consent. Every withdraw-zero validator in the core
protocol therefore carries a `publish` handler accepting `RegisterCredential`
and refusing every other certificate (`validators/programmable_logic_global.ak:72-77`,
`validators/transfer.ak:70-75`, `validators/third_party.ak:76-81`,
`validators/unfracking.ak:92-97`, `validators/issuance_logic.ak:89-94`).
**The same obligation falls on each of your four credentials.** A substandard
script with no `publish` handler, or one that rejects `RegisterCredential`, can
never be registered and therefore can never be invoked — and the failure is a
phase-1 ledger rejection with no validator trace to read.

### How it fits together

1. A user builds a transfer transaction
2. The transaction includes withdraw-zero entries for the dispatcher, the `transfer` delegate, and your transfer logic validator
3. The PLB spending validator runs once per spent input, reads `programmable_logic_global_cred` from the protocol-params datum, and requires that credential at the withdrawal index its redeemer witnesses (`validators/programmable_logic_base.ak:66-74`)
4. The dispatcher runs once, and under a `TransferAct` redeemer requires the `transfer` validator's withdraw-zero (`validators/programmable_logic_global.ak:63-69`)
5. The `transfer` validator runs once: it resolves one registry proof per distinct spent policy and, for each registered policy, requires that policy's `transfer_logic_script` withdraw-zero (`validators/programmable_logic/transfer.ak:256-264`)
6. Your transfer logic withdrawal validator runs and either succeeds or fails
7. If all validators pass, the transaction is valid

### Finding your own policy id

A common need in substandard logic is to know **which programmable token
policy you govern** — for example, to isolate your token's entries from other
policies co-located in the same transaction, or to assert that `tx.mint`
carries nothing under your policy.

The first thing to understand is that **your substandard's own script hash is
not the token's policy id.** Your transfer / third-party / issuance validators
run as *withdraw-0 stake validators*; the token's policy id is the hash of the
`issuance_mint` script, which is parameterized (among other things) by your
**issuance** credential (`minting_logic_script`, `validators/issuance_mint.ak:36`).
So the policy id is derived from your issuance logic, not from the validator
that is currently running.

There are two ways to obtain it.

**1. Resolve it at runtime from the registry node.** Your withdraw handler
receives `account` — your validator's own credential (see [What your withdraw
handler receives](#what-your-withdraw-handler-receives)). Every registered
token's `RegistryNode` is present as a reference input on any transaction that
moves it (the base layer needs it), and the node's NFT asset name **is** the
policy id (`key`). So: scan the registry-node reference inputs for the node
whose relevant logic field equals `account`, and read its `key`.

```aiken
// Locate registry nodes by their NFT (registry_node_cs, a compile-time parameter
// of the delegates — see 02-ARCHITECTURE.md), then match the node whose logic
// field is your own credential. That node's `key` is the policy id you govern.
//   - transfer logic          → match node.transfer_logic_script == account
//   - third-party logic       → match node.third_party_logic_script == account
//   - unfracking hook         → match node.unfracking_logic_script == account
//   - issuance logic          → match node.minting_logic_script == account
```

One substandard credential can govern **several** tokens (many nodes can point
at the same logic script), so treat this as "find *all* nodes referencing me"
when your rules span more than one of your policies, not just the first.

**2. Bake it in as a compile-time parameter.** Alternatively, parameterize your
validator with the policy id directly. This is the cheapest option (no scan) and
is what the example substandards do for related values (e.g. the PLB credential,
`global_state_cs`). It works because the policy id depends on your **issuance**
(`minting_logic_script`) credential — not on your transfer credential — so you
can compute it before compiling your transfer and third-party validators.

The one caveat is **dependency order**: fix your issuance-logic credential
first, derive the policy id from the `issuance_mint` template, then bake that id
into your other validators. Do **not** try to parameterize the issuance logic
with its own policy id — that is circular (the id is a hash *of* the issuance
script). The `registry` validator's mint handler cryptographically binds the
issuance credential to the policy id at registration
(`validators/registry.ak:91-97`), so a runtime resolution and a
correctly-derived compile-time parameter always agree.

This is the general form of the narrower derivation shown for the registration
path in [Your issuance logic must know why it is
running](#your-issuance-logic-must-know-why-it-is-running), where the node is
being *created* in the same transaction rather than referenced.

---

## Global State

Most real-world substandards need on-chain state — denylists, whitelists, configuration parameters, permissioned keys, etc. The CIP-113 registry supports this via the `global_state_cs` field in `RegistryNode` (field 6, `lib/registry_node.ak:79-80`).

### How it works

`global_state_cs` is a **currency symbol** (policy ID) that your substandard uses to manage its on-chain state. The pattern is:

1. **Create a minting policy** for your state NFTs/tokens (e.g., denylist node tokens, whitelist node tokens, config NFTs)
2. **Create a spending validator** that guards the UTxOs holding your state
3. **Store the minting policy ID** as `global_state_cs` when registering the token
4. **Read state via reference inputs** — your transfer logic validator reads state UTxOs without consuming them

The field is either empty or a 28-byte policy id; the registry enforces exactly that on both write paths (`lib/linked_list.ak:200-202`).

### Example: Denylist (Freeze-and-Seize)

The freeze-and-seize substandard uses `global_state_cs` to point to a denylist:

```
global_state_cs = denylist minting policy ID

On-chain state:
  [DenylistNode UTxO] → [DenylistNode UTxO] → [DenylistNode UTxO] → ...
  Each marked with an NFT from the denylist minting policy
  Each guarded by the denylist spending validator
```

During a transfer, the transfer logic validator:
1. Reads denylist nodes as **reference inputs** (not consumed)
2. Checks that sender/recipient credentials are NOT in the denylist
3. Uses covering-node proofs for non-membership verification — a direct index into `reference_inputs`, constant in the length of the list

### Common state patterns

| Pattern | State Structure | Use Case |
|---------|----------------|----------|
| **Linked list** | Sorted linked list of credentials/keys | Denylists, whitelists |
| **Config NFT** | Single UTxO with configuration datum | Permissioned keys, thresholds, parameters |
| **Counter** | UTxO with incrementing value | Rate limiting, supply caps |

### State management validators

If your substandard has on-chain state, you'll typically need additional validators beyond the four withdraw-zero credentials:

- **State minting policy** — controls creation/deletion of state entries
- **State spending validator** — guards state UTxOs, usually just checks that the minting policy is active

These are standard Aiken validators, not withdraw-zero validators. They follow typical Cardano patterns.

---

## Token Lifecycle from the Substandard's Perspective

### 1. Registration

When a new programmable token is registered, a `RegistryNode` entry is created in the on-chain registry containing:

- Your **issuance logic** credential (`minting_logic_script` — also baked into the `issuance_mint` policy as a parameter at token creation time)
- Your **transfer logic** credential
- Your **third-party transfer logic** credential
- Your **unfracking hook** credential (or `empty_vkey` to forbid unfracking)
- Your **global state** currency symbol (if applicable)

The registry mechanics are handled by the core infrastructure (`registry`'s mint handler, `validators/registry.ak:50`), but **your issuance logic withdraw-0 runs at registration** — the mint handler requires it in `tx.withdrawals` as proof that your substandard instance authorises the registration (the *proof of instance* check, `validators/registry.ak:99-110`). So your validators must be compiled, deployed, their stake addresses registered, and able to validate a registration transaction before the token can be registered.

A registration **may or may not mint the first tokens in the same transaction** — the framework supports both and does not constrain the choice (`validators/registry.ak:106-108`):

- **Register and mint**: `tx.mint` carries the first batch under the new policy; `issuance_mint` runs and validates it as usual.
- **Register only**: no entries under the new policy in `tx.mint`; `issuance_mint` never runs. Useful for RWA issuance, or for initialising global state before any token exists.

**If your substandard requires a strict register-then-mint lifecycle** (no minting during registration), you must enforce it yourself — see [Your issuance logic must know why it is running](#your-issuance-logic-must-know-why-it-is-running).

### 2. Minting

```
issuance_mint fires
  → requires YOUR minting_logic_cred withdraw-0            (issuance_mint.ak:46)
  → requires the PROTOCOL's issuance_logic_cred withdraw-0,
    whose redeemer must name this policy                   (issuance_mint.ak:52-63)
```

Your **issuance logic withdraw** validator is invoked. It should verify that the minting is authorized (e.g., an authorised signature, governance approval).

Tokens are minted to the PLB address with the recipient's stake credential. `issuance_logic` enforces this — no token of the policy may sit at a non-PLB output, and every PLB output carrying the policy must have an inline stake credential and a bounded inline datum (`validators/issuance_logic.ak:183-215`). Your substandard doesn't need to check it.

### 3. Transfer (Owner-Initiated)

```
PLB requires the dispatcher → dispatcher (TransferAct) requires transfer
  → transfer resolves your registry node → transfer requires your transfer logic
  → your transfer logic runs
```

Your **transfer logic withdraw** validator is invoked. It receives the full transaction context and must verify that the transfer meets your rules (e.g., not denylisted, on whitelist, within limits).

The `transfer` validator handles:
- Ownership verification — every PLB input's stake credential must sign, or (for a script credential) present its own withdraw-zero (`validators/programmable_logic/owner.ak:28-40`)
- Value containment — programmable tokens must reappear at PLB outputs (`validators/programmable_logic/transfer.ak:43-47`, `:213-217`)
- Registry proof resolution, one proof per distinct spent policy

Your validator only needs to enforce your **custom rules**.

### 4. Third-Party Transfer (Compliance)

```
PLB requires the dispatcher → dispatcher (ThirdPartyAct) requires third_party
  → third_party resolves the subject registry node → requires your 3rd-party logic
  → your 3rd-party logic runs
```

The transaction selects the third-party path through the **dispatcher's** redeemer — `ThirdPartyAct` (`lib/types.ak:100-109`) — not through the base spend redeemer, which carries no action arm at all. `programmable_logic_base` requires the dispatcher on this path exactly as it does on a transfer; it is the dispatcher that then requires `third_party`'s withdraw-0 (carrying a `ThirdPartyRedeemer`). Your **third-party transfer logic withdraw** validator is then invoked. This path does NOT require the token owner's signature — it's for third-party actions like seizure or forced transfers.

### 5. Unfracking (Holder-Initiated Restructuring)

```
PLB requires the dispatcher → dispatcher (UnfrackingAct) requires unfracking
  → unfracking resolves the acted-on registry node → requires your hook
  → your unfracking hook runs
```

Only reachable when the node's `unfracking_logic_script` is set. The owner still authorises — signature for a vkey stake credential, withdraw-zero for a script one.

### 6. Burning

```
issuance_mint fires (negative quantity) — the same two withdraw-0s as a mint
```

Your **issuance logic withdraw** validator is invoked with a negative mint quantity. The same validator handles both minting and burning — you can differentiate by inspecting `self.mint` in the transaction. A burn also *spends* a PLB UTxO, so the transaction carries the full spend chain of whichever action releases the tokens as well.

### Lifecycle diagram

```
Registration ──→ Minting ──→ Transfer ──→ ... ──→ Burning
                   │            │
                   │            ├──→ Third-Party Transfer
                   │            │          │
                   │            │    Your 3rd party logic runs
                   │            │
                   │            └──→ Unfracking
                   │                       │
                   │                 Your unfracking hook runs
                   │
              Your issuance   Your transfer      Your issuance
              logic runs      logic runs          logic runs
```

---

## Registry Lifecycle & Upgradeability

A registered token's `RegistryNode` is **live configuration, not a frozen
record**. Through the registry update path, **four** fields can be changed in
place after registration (`lib/linked_list.ak:184-208`):

- `transfer_logic_script`
- `third_party_logic_script`
- `unfracking_logic_script` — including unsetting it back to `empty_vkey`, which forbids unfracking again (`lib/linked_list.ak:203-207`)
- `global_state_cs`

`key`, `next`, and `minting_logic_script` are **frozen** (`lib/linked_list.ak:189-197`). Updates are
**retroactive**: the new transfer / third-party / unfracking logic governs *all existing
holders'* tokens on their next spend, so integrators must read the current node
and never cache its credentials (see
[`03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md`](./03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md) §3.2).

So you **can** re-point a token's transfer, third-party or unfracking logic, or its
global-state pointer, in place — no migration needed — as long as the change
stays within the mutable-field envelope above. The new values are still
shape-checked: each credential must be 28 bytes, the state policy must be empty
or 28 bytes, and the unfracking hook must be `empty_vkey` or 28 bytes
(`lib/linked_list.ak:198-207`).

### Lifecycle authority is your issuance credential

Registry lifecycle actions are authorized by the **registration credential —
which is your issuance-logic credential (`minting_logic_script`)**. The same
withdraw-0 credential is checked in three different contexts:

| Context | Enforced by | At |
|---|---|---|
| Mint / burn the token | `issuance_mint` | `validators/issuance_mint.ak:46` |
| Register the token (insert node) | the `registry` validator's **mint** handler | `validators/registry.ak:109-110` |
| Update the node in place | the `registry` validator's **spend** handler | `validators/registry.ak:227-234` |

So **your issuance-logic validator runs in all three** — and by default, whoever
can mint can also register and reconfigure the registry entry (transfer logic,
third-party logic, unfracking hook, global state).

> **The in-place update path requires a *script* `minting_logic_script`.**
> The `registry` spend handler authorises a node update by checking that
> `minting_logic_script`'s withdraw-0 is present — which is only possible for a
> `Script` credential. The `VerificationKey` arm returns `False` outright
> (`validators/registry.ak:227-234`), so it denies the update rather than
> aborting. If your `minting_logic_script` is a plain `VerificationKey`, you
> can mint and register but you **cannot update the node in place**; the node's
> configuration is effectively frozen. Choose a script credential if you want
> upgradeable transfer / third-party / unfracking logic.

**If issuance and registry-lifecycle should be *different* authorities, your
issuance logic must distinguish them itself** — e.g. by inspecting whether the
transaction spends or mints a registry node versus mints the programmable
token, and applying different rules (different signers, thresholds,
timelocks). The framework hands your validator the full transaction context; how
finely to separate these powers is a substandard decision, not a framework
default.

### Your issuance logic must know why it is running

The three contexts above mean your issuance withdraw-0 cannot assume "I am
running, therefore tokens are being minted". In particular, at registration
time the base layer does **not** constrain whether the transaction also mints
the first tokens: the `registry` mint handler requires your withdraw-0 as proof
of instance, and if a mint is present `issuance_mint` runs too — with your
*already-present* withdrawal as its authorisation
(`validators/registry.ak:99-110`). A validator that rubber-stamps registrations
therefore silently authorises co-mints as well.

**If your substandard's policy is "register first, mint later", enforce it
explicitly.** The recommended pattern is a redeemer on your issuance
withdraw-0 that names the running mode:

```aiken
pub type IssuanceAction {
  Register
  UpdateNode
  Mint
  Burn
}
```

Each arm validates only its own context:

- `Register` — validate the registration (e.g. an authorised signature) **and assert
  `tx.mint` carries no entries under your policy id**. Resolve the policy id
  from the registry-node output being created in this transaction (its NFT's
  asset name is the policy id, and its datum's `minting_logic_script` is your
  own credential), or recompute it from the issuance template.
- `UpdateNode` — validate the in-place node update (a registry node is being
  spent, not created; apply whatever stricter authority you want here).
- `Mint` / `Burn` — validate issuance as usual (sign of the `tx.mint` entries
  distinguishes the two if you prefer a single arm).

Cross-check the claimed mode against the transaction shape (registry node
minted / spent / untouched, programmable-token entries in `tx.mint`) so a
caller cannot pick a permissive arm for the wrong context. If instead your
substandard is happy with atomic register-and-mint (the common case), a single
arm that validates both concerns together is fine — just make that a
deliberate choice, not an accident.

### Base-layer guarantee: lifecycle and issuance are separate transactions

You can rely on one hard separation the base layer enforces: **a transaction
that spends a registry node may not mint or burn that node's own programmable
token (`key`)**. The check is hoisted above the handler's branch
(`validators/registry.ak:182-188`), so it covers both lifecycle spends — an
in-place update and the covering-node spend of an insert — and the `registry`
spend handler is the sole spender of every node. Consequences:

- A single transaction is **never** simultaneously a lifecycle operation *and* an
  issuance of the same policy. They are always distinct transactions — which
  keeps them independently authorizable and independently auditable.
- Registering a *new* token with a first mint in the same transaction still
  mints the **new** key. The guard is scoped to the node being *spent* (the
  covering predecessor, or the node being updated), never the node being
  *created*.

### When you still need a migration

The update path cannot change the frozen fields (`key`, `next`, `minting_logic_script`)
or perform a wholesale substandard swap. For those, migrate:

1. **Pause the old token** — if your substandard supports pausing (e.g., via a global state flag), pause transfers first
2. **Deploy + register the new substandard** — compile new validator scripts and create a new `RegistryNode`
3. **Migrate balances** — use either:
   - **A third-party action** (the dispatcher's `ThirdPartyAct` plus a `ThirdPartyRedeemer`) on the old token to move balances from holders to a migration address, then mint equivalent new tokens
   - **Burn old + mint new** in coordinated transactions
4. **Decommission the old token** — the old registry entry remains but the token is effectively deprecated (there is no de-registration; see [`03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md`](./03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md) §3.3)

**Recommendation**: design your substandard for upgradeability from the start.
Put behavior that may need tuning (thresholds, permissioned keys) behind a global-state
config NFT so you can adjust it without even a node update, and decide up front
whether issuance and registry-lifecycle should be the same authority or distinct
ones.

---

## Walkthrough: Dummy Substandard

The dummy substandard is the simplest possible implementation: the smallest
thing that satisfies the interface. Its sources live outside this repository;
what follows describes the interface it fills, not its file layout.

### Shape

Two `withdraw` validators, each ignoring the transaction entirely and checking
a magic number in its redeemer:

```aiken
validator issue {
  withdraw(redeemer: Int, _account: Credential, _self: Transaction) {
    redeemer == 100
  }
  else(_) {
    False
  }
}

validator transfer {
  withdraw(redeemer: Int, _account: Credential, _self: Transaction) {
    redeemer == 200
  }
  else(_) {
    False
  }
}
```

### How it maps onto the four registry credentials

| Registry field | Dummy's choice |
|---|---|
| `minting_logic_script` | the `issue` script's credential |
| `transfer_logic_script` | the `transfer` script's credential |
| `third_party_logic_script` | the **same** `transfer` script — one credential serving two roles |
| `unfracking_logic_script` | `empty_vkey` — unfracking forbidden |
| `global_state_cs` | empty — no state |

### Key takeaways

1. **Minimal structure**: two `withdraw` validators — that is the absolute minimum for a token that mints and transfers
2. **Reusing a credential is legitimate**: nothing requires the four registry fields to be four distinct scripts
3. **No transaction inspection**: the validators don't even look at the transaction — they just check a magic number
4. **Separate compile targets**: `issue` and `transfer` compile to separate scripts with separate script hashes, and each must be registered as a stake address before it can be invoked

This is obviously not secure for production use, but it demonstrates the interface contract clearly.

---

## Walkthrough: Freeze-and-Seize Substandard

The freeze-and-seize substandard is a real-world implementation for regulated
stablecoins. It maintains an on-chain denylist and validates every transfer
against it. As with the dummy substandard, its sources live outside this
repository; what follows is the interface it fills.

### How it maps onto the four registry credentials

| Registry field | Freeze-and-seize's choice |
|---|---|
| `minting_logic_script` | an issuer-admin script, parameterized by a permitted credential |
| `transfer_logic_script` | a denylist-checking transfer script |
| `third_party_logic_script` | the **same** issuer-admin script — whoever can mint can seize |
| `unfracking_logic_script` | the substandard's choice; `empty_vkey` forbids restructuring, a script credential lets the issuer gate it |
| `global_state_cs` | the denylist minting policy id |

### Issuance / third-party logic: an issuer-admin script

Parameterized by a `Credential`. The action is authorized only if that
credential has authorized the transaction — via `extra_signatories` for a
`VerificationKey`, or via a withdrawal entry for a `Script`:

```aiken
validator issuer_admin_contract(permitted_cred: Credential) {
  withdraw(_redeemer: Data, _account: Credential, self: Transaction) {
    when permitted_cred is {
      VerificationKey(pkh) -> list.has(self.extra_signatories, pkh)
      Script(script_hash) ->
        list.any(self.withdrawals, fn(Pair(cred, _)) { cred == Script(script_hash) })
    }
  }
}
```

Registering this one script for both `minting_logic_script` and
`third_party_logic_script` is a deliberate design choice: the entity that can
mint tokens is also the entity that can seize them.

### Transfer logic: denylist non-membership

Parameterized by the PLB credential (to identify programmable inputs) and the
denylist minting policy id (to authenticate denylist nodes):

```aiken
validator transfer(
  programmable_logic_base_cred: Credential,
  denylist_node_cs: PolicyId,
) {
  withdraw(proofs: List<NonmembershipProof>, account: Credential, self: Transaction) {
    let witnesses =
      extract_required_witnesses(self.inputs, programmable_logic_base_cred)
    and {
      is_rewarding_script(self.redeemers, account),
      validate_witnesses(denylist_node_cs, proofs, self.reference_inputs, witnesses),
    }
  }
}
```

What it does:

1. Extracts all stake credentials from programmable token inputs (the "witnesses")
2. For each witness, requires a non-membership proof — a reference to a denylist covering node proving the credential is NOT denylisted
3. Validates each proof: `node.key < credential_hash < node.next`
4. If any credential IS on the denylist, the transaction fails

### State management: the denylist

The denylist is a sorted linked list stored on-chain, managed by two additional
validators of the substandard's own:

- a **minting policy** with three operations — create the origin node (one-shot, consuming a specific UTxO), insert a credential, remove a credential — the last two gated on a manager signature, all three enforcing the linked-list invariants: sorted order, covering-node correctness, single mint per operation;
- a **spending validator** that permits spending a denylist node UTxO only while the minting policy is active in the same transaction, delegating all logic to the policy:

```aiken
validator denylist_spend(denylist_cs: PolicyId) {
  spend(_datum, _redeemer, _own_ref, self: Transaction) {
    to_dict(self.mint) |> has_key(denylist_cs)
  }
}
```

### How it all connects

```
Transfer transaction:
  Withdrawals (all zero ADA; listed by role, NOT in ledger order):
    - programmable_logic_global    ← required by every PLB spend
    - transfer                     ← required by the dispatcher's TransferAct
    - your transfer logic          ← the denylist check

  Reference inputs:
    - Protocol params UTxO         ← required by PLB, not by `transfer`
    - Registry node UTxO           ← its transfer_logic_script is your credential
    - Denylist node UTxO(s)        ← covering nodes for non-membership proofs

Denylist management transaction:
  Mints:
    - denylist policy: an insert operation naming the credential to ban
  Inputs:
    - Covering node UTxO (consumed and updated)
  Outputs:
    - Updated covering node UTxO
    - New denylist node UTxO
  Signatories:
    - Manager key
```

### Key takeaways

1. **Parameterized validators**: transfer logic takes the PLB credential and the denylist policy ID as parameters — different deployments can have different denylists
2. **Reference inputs for state**: the denylist is read via reference inputs, not consumed. Multiple transfers can read the same denylist concurrently
3. **Separated concerns**: denylist management (mint/spend) is independent from transfer validation. You can add or remove denylist entries without affecting transfers in progress
4. **Covering-node proofs**: non-membership is proven by a direct index into the reference inputs, constant in the length of the denylist

---

## Off-Chain Integration (Evolution SDK)

This section shows how to build transactions for your substandard using the
[Evolution SDK](https://github.com/IntersectMBO/evolution-sdk)
(`@evolution-sdk/evolution`).

**What is verified here, and what is not.** Two different things are checked by
two different means, and neither covers the other:

- **The redeemer shapes and index semantics** come from test fixtures in this
  repository, named in the citation line above each block. Those fixtures are
  executable and run under `aiken check`, so a redeemer shape that drifts from
  the protocol is caught by a failing test rather than by a reader.
- **The TypeScript itself** type-checks against `@evolution-sdk/evolution`
  `0.5.9` under TypeScript `5.9.3`, extracted block by block with the
  `declare const` preamble each block carries. That catches a wrong field name,
  a `number` where a `bigint` is required, or a `string` where an `Address` is
  required.

Neither check submits a transaction. **No block below has been run against a
node or a devnet**, so a mistake that is well-typed and protocol-shaped — a
credential that is registered but not the one the registry node names, an output
whose min-UTxO is short — will still reach you at submission time. Treat these
as verified skeletons, not as tested code.

Three things the SDK does **not** do for you, which shape everything below:

- **It resolves input indices, not reference-input or withdrawal indices.** The
  deferred-redeemer machinery (`Self` and `Batch` modes) hands a callback the
  final position of a *transaction input* after coin selection. CIP-113's
  `params_idx`, `registry_node_idx`, `node_idx` and `wdrl_idx` address
  `reference_inputs` and `withdrawals`, which coin selection never touches, so
  you compute those yourself from the sets you assembled — and recompute them if
  you add another reference input or another withdrawal.
- **It does not sort your index domains for you.** `reference_inputs` reach the
  validator in the ledger's canonical `(transaction_id, output_index)` order;
  `withdrawals` reach it with every `Script` credential ahead of every
  `VerificationKey` credential. Both orders are given below.
- **It does not know the protocol.** Which withdrawals a transaction needs, and
  which reference inputs, come from
  [`08-INTEGRATION-GUIDES.md`](./08-INTEGRATION-GUIDES.md#required-withdrawals).

### Minting or burning tokens

**Fixture sources:**

- Transcribed from validators/issuance_mint.test.ak:119 — valid_tx

`valid_tx` is the smallest transaction `issuance_mint` accepts: the
protocol-params UTxO among the reference inputs, a mint under the policy, and
**both** withdraw-zeros, with the protocol's issuance-logic redeemer naming the
policy being minted. `issuance_logic` needs one more reference input that
`issuance_mint` does not — the policy's registry node, resolved from its own
`RefInput { index }` proof (`validators/issuance_logic.ak:152-165`).

```typescript
import {
  Address, Assets, Credential, Data, InlineDatum, type Client, type UTxO,
} from "@evolution-sdk/evolution";

// A SIGNING client specifically: only a signing builder's `build()` returns a
// value with `.sign()`. A read-only (CIP-30) client builds but cannot sign here.
declare const client: Client.SigningClient;
declare const protocolParamsUtxo: UTxO.UTxO;
declare const registryNodeUtxo: UTxO.UTxO;
declare const walletUtxos: UTxO.UTxO[];
// Addresses are `Address` OBJECTS, not bech32 strings — see "Building
// programmable logic addresses" below.
declare const recipientProgrammableAddress: Address.Address;
declare const changeAddress: Address.Address;

declare const yourMintingLogicHash: string;   // 28-byte hex
declare const issuanceLogicHash: string;      // 28-byte hex, protocol-params field 1
declare const yourMintingLogicScript: any;
declare const issuanceLogicScript: any;
declare const issuanceMintScript: any;        // issuance_mint, parameters applied
declare const yourIssuanceRedeemer: Data.Data;
declare const tokenPolicyId: string;          // = the applied issuance_mint hash
declare const assetNameHex: string;
declare const quantity: bigint;               // > 0 to mint, < 0 to burn

const scriptCred = (hash: string) =>
  Credential.makeScriptHash(Uint8Array.from(Buffer.from(hash, "hex")));

// Reference inputs, in the ledger's canonical (transaction_id, output_index)
// order — see "Reference-input indices" below.
const refInputs = sortReferenceInputs([protocolParamsUtxo, registryNodeUtxo]);
const paramsIdx = BigInt(refInputIndexOf(refInputs, protocolParamsUtxo));
const registryNodeIdx = BigInt(refInputIndexOf(refInputs, registryNodeUtxo));

// IssuanceMintRedeemer { params_idx } — lib/types.ak:172-174.
// A single-constructor record with ONE field: constructor 0, one integer.
const issuanceMintRedeemer = Data.constr(0n, [Data.int(paramsIdx)]);

// IssuanceLogicRedeemer = Pairs<PolicyId, MintingRegistryProof> —
// lib/types.ak:184-185. A Plutus MAP. `issuance_mint` reads only the KEYS and
// fails unless this policy id is one of them (validators/issuance_mint.ak:88-91).
// MintingRegistryProof: RefInput { index } is constructor 0, OutputIndex { index }
// is constructor 1 (lib/types.ak:162-165). Use OutputIndex, naming an OUTPUT
// position, when the registry node is being CREATED in this same transaction —
// a first mint alongside registration (`validators/issuance_logic.ak:141-151`).
const issuanceLogicRedeemer = Data.map([
  [Data.bytearray(tokenPolicyId), Data.constr(0n, [Data.int(registryNodeIdx)])],
]);

// A negative quantity here IS the burn (lib/types.ak has no burn arm; the sign
// of the mint entry is the whole distinction).
let mintAssets = Assets.fromLovelace(0n);
mintAssets = Assets.addByHex(mintAssets, tokenPolicyId, assetNameHex, quantity);

let tx = client
  .newTx()
  // 1. YOUR issuance logic withdraw-0 (validators/issuance_mint.ak:46)
  .withdraw({
    stakeCredential: scriptCred(yourMintingLogicHash),
    amount: 0n,
    redeemer: yourIssuanceRedeemer,   // e.g. Data.int(100n) for the dummy substandard
  })
  .attachScript({ script: yourMintingLogicScript })

  // 2. The PROTOCOL's issuance logic withdraw-0, covering this policy
  //    (validators/issuance_mint.ak:52-63). Omitting this is the common
  //    mistake: the mint fails with an uncovered-policy failure, not a
  //    missing-script one.
  .withdraw({
    stakeCredential: scriptCred(issuanceLogicHash),
    amount: 0n,
    redeemer: issuanceLogicRedeemer,
  })
  .attachScript({ script: issuanceLogicScript })

  // 3. The issuance_mint policy — its applied hash IS tokenPolicyId.
  .mintAssets({ assets: mintAssets, redeemer: issuanceMintRedeemer })
  .attachScript({ script: issuanceMintScript })

  // 4. The reference inputs, at the indices the two redeemers named.
  .readFrom({ referenceInputs: refInputs });

// 5. A MINT creates a PLB output for the recipient: no datum hash, no reference
//    script, inline datum within max_inline_datum_bytes
//    (lib/prog_assets.ak:291-302). A BURN creates no such output — an output
//    cannot carry a negative quantity, and the tokens being burned come from a
//    PLB INPUT, not from a new output.
if (quantity > 0n) {
  let outAssets = Assets.fromLovelace(1_500_000n);
  outAssets = Assets.addByHex(outAssets, tokenPolicyId, assetNameHex, quantity);
  tx = tx.payToAddress({
    address: recipientProgrammableAddress,
    assets: outAssets,
    datum: new InlineDatum.InlineDatum({ data: Data.constr(0n, []) }),
  });
}

const built = await tx.build({ changeAddress, availableUtxos: walletUtxos });
const signed = await built.sign();
await signed.submit();
```

**A burn is not this transaction with the sign flipped.** The negative mint entry
is right, but a burn additionally **spends** the PLB UTxO holding the tokens, and
it builds **no** PLB output for the burned policy. So a burn carries the two
issuance withdraw-zeros above *plus* the full spend chain of whichever action
releases the tokens — dispatcher, delegate, and the policy's logic credential for
that action. Build it as the transfer below, with the mint and the two issuance
withdrawals added. `validators/issuance_logic.ak:183-215` constrains PLB outputs
that carry the policy; it never requires one to exist.

### Transferring tokens

**Fixture sources:**

- Transcribed from validators/programmable_logic/fixture.ak:416 — some_transfer
- Transcribed from validators/programmable_logic/fixture.ak:103 — withdrawals_transfer
- Transcribed from validators/programmable_logic_base.test.ak:132 — valid_programmable_logic_base_tx

`some_transfer` supplies the inputs, outputs, reference inputs and the
`transfer` redeemer; `withdrawals_transfer` the three-credential withdrawal set;
`valid_programmable_logic_base_tx` the per-input base redeemer and the indices
it is called with (`validators/programmable_logic_base.test.ak:142-144`).

```typescript
import { Credential, Data, InlineDatum, KeyHash } from "@evolution-sdk/evolution";

// --- Reference inputs -------------------------------------------------------
// reference_inputs reach the validator in the ledger's canonical order:
// sorted by (transaction_id, output_index). Sort the set you assembled and read
// the indices off the sorted list.
// Both helpers return a `number`; `Data.int` takes a `bigint`.
const refInputs = sortReferenceInputs([protocolParamsUtxo, registryNodeUtxo]);
const paramsIdx = BigInt(refInputIndexOf(refInputs, protocolParamsUtxo));
const registryIdx = BigInt(refInputIndexOf(refInputs, registryNodeUtxo));

// --- Withdrawals ------------------------------------------------------------
// The COMPLETE withdrawal set of the finished transaction. The order you write
// it in here is irrelevant — withdrawalIndexOf sorts into ledger order before
// it reads a position. What matters is that nothing is missing.
const withdrawals = [
  { hash: programmableLogicGlobalHash, isScript: true },
  { hash: coreTransferHash,            isScript: true },
  { hash: yourTransferLogicHash,       isScript: true },
  // ...plus every other withdrawal this transaction will carry. A key-hash
  // reward withdrawal the wallet adds sorts after every script and cannot move
  // a script's index; another SCRIPT withdrawal can.
];
const wdrlIdx = BigInt(
  withdrawalIndexOf(withdrawals, { hash: programmableLogicGlobalHash, isScript: true }),
);

// --- Redeemers --------------------------------------------------------------
// BaseSpendRedeemer { params_idx, wdrl_idx } — lib/types.ak:79-84.
// A SINGLE-CONSTRUCTOR record with two integer fields. There is no action arm:
// a transfer, a seizure and an unfracking all use this same shape. `wdrl_idx`
// locates the DISPATCHER's entry — programmable_logic_global_cred, protocol-params
// field 0 — not the delegate's (validators/programmable_logic_base.ak:72-74).
const baseSpendRedeemer = Data.constr(0n, [Data.int(paramsIdx), Data.int(wdrlIdx)]);

// ProgrammableLogicGlobalRedeemer — lib/types.ak:100-109. Three field-less arms,
// in declaration order: TransferAct = 0, ThirdPartyAct = 1, UnfrackingAct = 2.
const dispatcherRedeemer = Data.constr(0n, []);   // TransferAct

// RegistryProof — lib/types.ak:11-16. TokenExists { node_idx } is constructor 0;
// TokenDoesNotExist { node_idx } is constructor 1.
const registryProof = Data.constr(0n, [Data.int(registryIdx)]);

// TransferRedeemer { proofs } — lib/types.ak:27-30. ONE field. `transfer` reads
// no protocol-params datum, so this redeemer carries no params_idx. One proof
// per DISTINCT policy in the spent inputs, in ascending policy order.
const transferRedeemer = Data.constr(0n, [Data.list([registryProof])]);

const yourTransferLogicRedeemer = Data.int(200n);   // your substandard's rule

// --- Build ------------------------------------------------------------------
const scriptCred = (hash: string) =>
  Credential.makeScriptHash(Uint8Array.from(Buffer.from(hash, "hex")));

let tx = client.newTx();

// 1. Spend the token UTxOs from the PLB address. The base redeemer is the same
//    value for every PLB input in this transaction.
tx = tx.collectFrom({ inputs: selectedPlbUtxos, redeemer: baseSpendRedeemer });
tx = tx.attachScript({ script: programmableLogicBaseScript });

// 2. The dispatcher's withdraw-0 — what PLB requires of EVERY programmable spend.
tx = tx
  .withdraw({
    stakeCredential: scriptCred(programmableLogicGlobalHash),
    amount: 0n,
    redeemer: dispatcherRedeemer,
  })
  .attachScript({ script: programmableLogicGlobalScript });

// 3. The `transfer` delegate's withdraw-0 — what the dispatcher's TransferAct requires.
tx = tx
  .withdraw({
    stakeCredential: scriptCred(coreTransferHash),
    amount: 0n,
    redeemer: transferRedeemer,
  })
  .attachScript({ script: coreTransferScript });

// 4. Your transfer logic's withdraw-0 — what `transfer` requires, read from the
//    policy's registry node.
tx = tx
  .withdraw({
    stakeCredential: scriptCred(yourTransferLogicHash),
    amount: 0n,
    redeemer: yourTransferLogicRedeemer,
  })
  .attachScript({ script: yourTransferLogicScript });

// 5. Outputs, at PLB addresses with the new owner's stake credential.
tx = tx.payToAddress({
  address: recipientProgrammableAddress,
  assets: recipientAssets,
  datum: new InlineDatum.InlineDatum({ data: Data.constr(0n, []) }),
});
if (returningAmount > 0n) {
  tx = tx.payToAddress({
    address: senderProgrammableAddress,
    assets: returningAssets,
    datum: new InlineDatum.InlineDatum({ data: Data.constr(0n, []) }),
  });
}

// 6. Reference inputs, and the owner's signature when the owner is a key.
tx = tx.readFrom({ referenceInputs: refInputs });
tx = tx.addSigner({ keyHash: KeyHash.fromHex(senderStakeCredentialHash) });

const built = await tx.build({ changeAddress, availableUtxos: walletUtxos });
const signed = await built.sign();
await signed.submit();
```

Transcription notes:

- **`some_transfer` builds one reference input the chain does not require** — a
  list-head registry node keyed `""`, so its fixture registry is gap-free. That
  puts the spent policy's own node at reference-input position 2 and makes the
  fixture's proof `TokenExists { node_idx: 2 }`. A real registry has gaps and a
  transfer references only the nodes its proofs resolve, so the code above
  derives the index from the two reference inputs it actually adds.
- **The fixture's owner credential is also the policy's `transfer_logic_script`**
  (`validators/programmable_logic/fixture.ak:113`, `:278`), so its three
  withdrawals cover both the substandard's rule and the owner's consent. When
  the owner is a *different* `Script`, the set grows to four.

Where the owner is a **`Script`** rather than a key, drop `addSigner` and add
that script's own withdraw-zero as a fourth entry — then recompute `wdrlIdx`,
because a script credential sorts among the scripts and may land before the
dispatcher (`validators/programmable_logic/owner.ak:28-40`).

For the seizure and unfracking shapes, change the dispatcher's arm and the
delegate: `ThirdPartyAct` (`Data.constr(1n, [])`) plus the `third_party`
validator's withdraw-0 carrying a `ThirdPartyRedeemer`
`{ registry_node_idx, outputs_start_idx }` (`lib/types.ak:50-54`), or
`UnfrackingAct` (`Data.constr(2n, [])`) plus `unfracking` carrying an
`UnfrackingRedeemer` of the same shape (`lib/types.ak:36-40`). The base spend
redeemer does not change.

### Key off-chain patterns

#### Building programmable logic addresses

Recipients receive tokens at the PLB address with their own stake credential:
the payment credential is always the PLB script hash, and only the stake
credential varies.

```typescript
import {
  Address, AddressEras, BaseAddress, KeyHash, ScriptHash,
} from "@evolution-sdk/evolution";

const programmableBase = new BaseAddress.BaseAddress({
  networkId,                                                   // 0 = testnet, 1 = mainnet
  paymentCredential: new ScriptHash.ScriptHash({
    hash: Uint8Array.from(Buffer.from(programmableLogicBaseHash, "hex")),
  }),
  stakeCredential: new KeyHash.KeyHash({                       // or ScriptHash, for a script owner
    hash: Uint8Array.from(Buffer.from(recipientStakeHash, "hex")),
  }),
});

// Bech32 for display, storage and logs.
const programmableBech32 = AddressEras.toBech32(programmableBase);

// The builder wants an `Address`, NOT a string: `payToAddress.address` is typed
// `Address`, and so is `build`'s `changeAddress`. `AddressEras.toBech32` returns
// a `string`, so parse it back before handing it to the builder.
const programmableAddress = Address.fromBech32(programmableBech32);
```

#### Reference-input indices

Reference inputs are **sorted canonically** by the ledger, by transaction hash
then output index. Every index hint that addresses `reference_inputs` —
`params_idx`, `registry_node_idx`, and each proof's `node_idx` — is a position
in that sorted list, never in the order you added them.

> **An Evolution `UTxO` has `transactionId` and `index` — not `txHash` and
> `outputIndex`.** `transactionId` is a `TransactionHash` object, not a hex
> string, and `index` is a **`bigint`**. Those are the fields the type carries
> (`UTxO` "combines TransactionOutput with the transaction reference
> (transactionId + index)"), and the whole `readFrom` → index-hint chain depends
> on reading them. A comparator that reaches for `txHash`/`outputIndex` — the
> names most other Cardano SDKs use — does not fail loudly: it compares
> `undefined` against `undefined`, the sort becomes a no-op, and `findIndex`
> matches the first element, so **every index hint in the transaction silently
> becomes 0**. That is the exact failure `wdrl_idx` and `params_idx` are
> self-validating against, arriving through the off-chain side instead.

```typescript
import { TransactionHash, UTxO } from "@evolution-sdk/evolution";

// The ledger sorts reference inputs by (transaction_id, output_index).
// Lowercase hex compares like the underlying bytes.
function compareRefInputs(a: UTxO.UTxO, b: UTxO.UTxO): number {
  const ha = TransactionHash.toHex(a.transactionId);
  const hb = TransactionHash.toHex(b.transactionId);
  if (ha !== hb) return ha < hb ? -1 : 1;
  return Number(a.index) - Number(b.index);   // index is a bigint
}

function sortReferenceInputs(utxos: readonly UTxO.UTxO[]): UTxO.UTxO[] {
  return [...utxos].sort(compareRefInputs);
}

// Position in the SORTED list — the value an index hint must carry.
// `UTxO.toOutRefString` renders a UTxO as `txHash#index`, which is exactly the
// identity we need.
function refInputIndexOf(sorted: readonly UTxO.UTxO[], target: UTxO.UTxO): number {
  const key = UTxO.toOutRefString(target);
  const i = sorted.findIndex((u) => UTxO.toOutRefString(u) === key);
  if (i === -1) throw new Error(`reference input ${key} is not in the sorted set`);
  return i;
}
```

The `-1` guard is not decoration: `findIndex` returning `-1` would otherwise be
written straight into a redeemer as an index, and `list.expect_at` would fail
the transaction with no indication of which hint was wrong.

Pass the **sorted** array to `readFrom`, and read every index off that same
array. `readFrom` does not reorder what you give it, and the ledger will sort it
anyway — but if the array you index and the array you submit disagree, every
hint in the transaction is wrong.

Both helpers return a **`number`**, and `Data.int` takes a **`bigint`** — so
wrap at the point of derivation, `BigInt(refInputIndexOf(...))`, as both
skeletons above do.

#### Withdrawal indices (`wdrl_idx`)

**Fixture sources:**

- Transcribed from validators/programmable_logic/fixture.ak:162 — compare_credentials_ledger
- Transcribed from validators/programmable_logic/fixture.ak:181 — withdrawal_index_of

`BaseSpendRedeemer.wdrl_idx` is a position in the transaction's withdrawal map
**as the ledger orders it** — which is *not* insertion order and *not* the sort
order of bech32 reward-address strings. The ledger keys withdrawals by
`RewardAccount = (network, credential)`; within one transaction the network is
constant, so the order is cardano-ledger's derived `Ord` on `Credential`, whose
constructors are declared `ScriptHashObj` **before** `KeyHashObj`: every script
credential sorts ahead of every key credential, and hashes compare bytewise
within each kind. (This is *not* Aiken's `Credential` declaration order, which
lists `VerificationKey` first.) The rule, and the two helpers that implement it
on-chain, are at `validators/programmable_logic/fixture.ak:151-190`.

The index must be computed over the **complete** withdrawal set: any extra
withdrawal occupies a slot too.

```typescript
type WithdrawalKey = { hash: string; isScript: boolean }; // hash: 28-byte hex

// Ledger order: scripts first, then keys; bytewise hash order within each.
// Lowercase hex compares like the underlying bytes.
function compareWithdrawalKeys(a: WithdrawalKey, b: WithdrawalKey): number {
  if (a.isScript !== b.isScript) return a.isScript ? -1 : 1;
  const ha = a.hash.toLowerCase(), hb = b.hash.toLowerCase();
  return ha < hb ? -1 : ha > hb ? 1 : 0;
}

function withdrawalIndexOf(all: readonly WithdrawalKey[], target: WithdrawalKey): number {
  const sorted = [...all].sort(compareWithdrawalKeys);
  const i = sorted.findIndex(
    (w) => w.isScript === target.isScript && w.hash.toLowerCase() === target.hash.toLowerCase(),
  );
  // Same guard, same reason as `refInputIndexOf`: this array is assembled by
  // hand, so a credential omitted from it yields -1, and -1 written into
  // `wdrl_idx` fails `list.expect_at` naming nothing.
  if (i === -1) throw new Error(`withdrawal ${target.hash} is not in the set`);
  return i;
}
```

**A worked example, because the intuition is wrong.** Take this repository's
own transfer fixture, `validators/programmable_logic/fixture.ak:103-114`. It
writes its three credentials in role order — dispatcher, delegate, substandard —
and that is *not* the order the ledger hands them over. Running the rule above
over the fixture's actual hashes:

| credential | hash (last 4 bytes) | literal position in the fixture | ledger position |
|---|---|---:|---:|
| `programmable_logic_global` | `…00000101` | 0 | **0** |
| `transfer` (the delegate) | `…0001091c` | 1 | **2** |
| `transfer_logic_script` (the substandard) | `…00000b0b` | 2 | **1** |

The delegate and the substandard script swap. `wdrl_idx` here happens to be `0`
either way, only because the dispatcher's hash is the byte-minimum of this
particular set — a property of these three arbitrary test hashes, not of the
protocol. With your own deployment's hashes the dispatcher can sit anywhere.
**Derive the index; never read it off a listing, a fixture, or this page.**

A wrong `wdrl_idx` cannot authorise anything — `programmable_logic_base`
resolves the entry at that index and requires it to equal
`programmable_logic_global_cred`, the **dispatcher** credential read from
protocol-params field 0 (`validators/programmable_logic_base.ak:72-74`, field
declared at `validators/programmable_logic/params.ak:55-61`, accessor at
`:146-152`) — but it does fail the transaction, so derive it from the *final*
withdrawal set, after the builder has added everything. A key-hash withdrawal
appended late is harmless; a second script withdrawal is not.

#### Substandard-specific reference inputs

If your substandard uses global state (e.g., denylist nodes), those UTxOs must
also be included as reference inputs. Add them to the set **before** computing
any index: they take positions in the same canonical ordering as the params
UTxO and the registry node.

#### Parameterizing substandard scripts

If your validators take parameters — as the freeze-and-seize transfer logic
takes the PLB credential and the denylist policy id — apply them with
`UPLC.applyParamsToScript`, which returns a fully applied, double-CBOR-encoded
script:

```typescript
import { Data, UPLC } from "@evolution-sdk/evolution";

const appliedCode = UPLC.applyParamsToScript(compiledCodeFromBlueprint, [
  // Credential is an Aiken sum type: VerificationKey(hash) = constructor 0,
  // Script(hash) = constructor 1 (cardano/address).
  Data.constr(1n, [Data.bytearray(programmableLogicBaseHash)]),
  Data.bytearray(denylistPolicyId),
]);
// applyParamsToScript output is already valid CBOR — do NOT wrap it again.
```

Parameters are applied in declaration order, matching the lambda bindings in the
compiled script. A parameter's `Data` encoding must match the Aiken type
exactly: a `Credential` is a constructor, a `PolicyId` is a bare byte string, an
`Int` is an integer.

---

## Testing Your Substandard

### Unit testing withdraw validators

Test your validators in isolation using Aiken's built-in test framework. Create mock transactions that exercise your validation logic:

```aiken
// Example: testing a transfer logic validator
test transfer_allows_valid_transfer() {
  let mock_tx = Transaction {
    inputs: [...],
    reference_inputs: [...],
    outputs: [...],
    withdrawals: [Pair(my_transfer_credential, 0)],
    extra_signatories: [admin_pkh],
    ..transaction.placeholder
  }

  // Call your withdraw handler directly
  my_transfer.transfer.withdraw(my_redeemer, my_credential, mock_tx)
}

test transfer_rejects_denylisted_sender() fail {
  let mock_tx = Transaction {
    // ... transaction with a denylisted sender credential
    ..transaction.placeholder
  }
  my_transfer.transfer.withdraw(my_redeemer, my_credential, mock_tx)
}
```

### Testing state management

Test your minting and spending validators for linked list operations:

```aiken
test denylist_insert_maintains_sorted_order() {
  // Build a transaction that inserts a new node
  // Verify the covering node is updated correctly
  // Verify the new node has correct key and next pointers
}
```

### Integration testing

For full integration tests that exercise the core infrastructure + your substandard together, see the test files in this repository:

- `validators/transfer.test.ak`, `validators/third_party.test.ak`, `validators/programmable_logic/unfracking.test.ak` — the transfer / third-party / unfracking flows with mock substandard validators
- `validators/programmable_logic_base.test.ak`, `validators/programmable_logic_global.test.ak` — the two links above the delegates
- `validators/issuance_mint.test.ak`, `validators/issuance_logic.test.ak` — the two halves of issuance
- `validators/registry.test.ak` — registration, register-only, and the in-place node update
- `validators/programmable_logic/fixture.ak` — the shared fixtures every skeleton in this document is transcribed from
- `validators/programmable_logic/benchmarks.ak` — execution-cost benchmarks for the transfer flows

### Running tests

```bash
# In your substandard directory
aiken check

# Run tests whose NAME matches a substring (-m matches test names, not modules)
aiken check -m transfer_allows

# Watch mode
aiken check --watch
```

---

**Previous**: [Integration Guides](./08-INTEGRATION-GUIDES.md) | **Back to**: [README](../README.md)

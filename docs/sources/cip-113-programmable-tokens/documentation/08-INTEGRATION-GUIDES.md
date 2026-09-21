# Integration Guides

This document provides integration guidance for three audiences: **wallet developers**, **indexers and explorers**, and **dApp developers**. Each section explains what programmable tokens mean for your domain, what changes relative to standard native tokens, and what to watch out for.

Sections 2 and 3 are shared ground: the rules every transaction builder obeys regardless of audience, and the four transaction skeletons the rest of the document refers back to. Every rule stated here names the validator and the line that enforces it, and every skeleton names the test fixture it was transcribed from.

Familiarity with the [Architecture](./02-ARCHITECTURE.md) document is assumed — in particular the ownership model, the dispatch chain, and the withdraw-zero pattern.

---

## Table of Contents

1. [Understanding Programmable Addresses](#understanding-programmable-addresses)
2. [Deriving Protocol and Registry Identifiers](#deriving-protocol-and-registry-identifiers)
3. [Transaction Rules Every Builder Obeys](#transaction-rules-every-builder-obeys)
4. [Transaction Skeletons](#transaction-skeletons)
5. [For Wallet Developers](#for-wallet-developers)
6. [For Indexers and Explorers](#for-indexers-and-explorers)
7. [For dApp Developers](#for-dapp-developers)

---

## Understanding Programmable Addresses

### Address structure

All programmable tokens are held at addresses with a **shared payment credential** (the `programmable_logic_base` script hash) and a **unique stake credential** that determines ownership:

```
Programmable Address = programmable_logic_base (shared) + owner_credential (unique)
                       ──────────────────────────────────  ──────────────────────────
                       Payment credential                  Stake credential slot
                       Same for ALL holders                Determines who owns the UTxO
```

### Credential flexibility

The stake credential slot is **polymorphic** — it can hold three kinds of credential:

| Credential type | Source | Authorization method | Use case |
|---|---|---|---|
| User's **stake** key hash | Stake verification key | Signature from the stake key | Preferred for standard wallets — aligns with Cardano's address model |
| User's **payment** key hash | Payment verification key | Signature from the payment key | Required for enterprise wallets (e.g. CEXes) that lack stake credentials |
| **Script** hash | Smart contract | Script invocation via withdraw-zero | Required when a dApp or smart contract holds programmable tokens |

The on-chain validators do not distinguish between payment and stake key hashes. They check only whether the credential is a `VerificationKey` (which requires a signature) or a `Script` (which requires a withdraw-zero invocation):

```aiken
expect Some(Inline(stake_cred)) = address.stake_credential
expect
  when stake_cred is {
    VerificationKey(pkh) -> has_signatory(pkh)
    Script(_hash) -> has_withdrawal(stake_cred)
  }
```

Quoted from `validators/programmable_logic/owner.ak:33-38` (`authorised_stake_cred`, declared at `:28`). It is called from `transfer` (`validators/programmable_logic/transfer.ak:98`) and from `unfracking` (`validators/programmable_logic/unfracking.ak:169`). The `third_party` path does not call it — a third-party action is authorised by the issuer, not by the holder.

**Which credential goes in the stake slot is an off-chain and protocol-level choice, not an on-chain constraint.** Different tokens or deployments may adopt different conventions. Using the stake key aligns with Cardano's existing address model; using the payment key is equally valid on-chain and becomes mandatory for enterprise addresses.

The `expect Some(Inline(stake_cred))` on the first line is load-bearing: a PLB output with no stake credential, or with a pointer credential, has no owner any validator can authorise. See [PLB output shape](#plb-output-shape-and-the-datum-bound).

### Implications

- **A single user may hold programmable tokens at different addresses**, depending on which credential the issuing protocol chose.
- **Wallets must know the convention** used by a given token to construct the correct query address.
- **Indexers must be prepared** for the stake credential slot to contain a payment key hash, a stake key hash, or a script hash.

---

## Deriving Protocol and Registry Identifiers

### The registry and params addresses

Both the registry and the protocol-params UTxO resolve to a single applied
script, not a script layered over an address computed some other way.

`protocol_params(utxo_ref)` IS the address computation: mint and spend share
one script hash, so the params NFT policy id — the result of applying the
one `utxo_ref` parameter — is the params address's payment credential
(`validators/protocol_params.ak:8-16`;
`nft_output.address == address.from_script(own_policy)`,
`validators/protocol_params.ak:267`). There is no second parameter and no
address passed in from another deployment step; see
[Who may initialise](./02-ARCHITECTURE.md#who-may-initialise).

`registry(utxo_ref, issuance_cbor_hex_cs)` is the same shape: the registry
node NFT policy id and the registry address's payment credential are the same
value by construction (`validators/registry.ak:9-16`). `registry` takes no
protocol-params parameter at all (`validators/registry.ak:40`) — deriving the
registry's address needs only `issuance_cbor_hex_mint`'s applied policy id
(see [Deployment ordering](#deployment-ordering) below), never a reference to
`protocol_params`.

An SDK deriving either address applies parameters to one script and reads the
resulting policy id back as both the minting policy and the payment
credential. There is no second lookup and no coordination address to plumb
through from a different deployment step.

### Deployment ordering

The constraint that matters here is which script's compiled hash is a
compile-time PARAMETER of another script. It is not an on-chain sequencing
rule: none of these validators reads another validator's on-chain state to
run, so "deployed" below means "applied and hashed", not "has processed a
transaction".

1. `always_fail(nonce)`, `protocol_params(utxo_ref)` and
   `upgrade_multisig(utxo_ref)` need no other script's hash
   (`validators/always_fail.ak:5`; `validators/protocol_params.ak:222`;
   `validators/upgrade_multisig.ak:66`). `protocol_params` takes no address
   parameter, so its own genesis needs nothing but a chosen `utxo_ref`: the
   params mint no longer depends on a params spend address, because there is
   no separate spend-address parameter to depend on.
2. `issuance_cbor_hex_mint(utxo_ref, always_fail_hash)` needs `always_fail`'s
   hash (`validators/issuance_cbor_hex_mint.ak:13-16`).
3. `registry(utxo_ref, issuance_cbor_hex_cs)` needs
   `issuance_cbor_hex_mint`'s applied policy id (`validators/registry.ak:40`)
   and nothing else. The registry no longer depends on the protocol-params
   chain: it carries no `params_policy` parameter, so `registry`'s own
   `RegistryInit` genesis needs `protocol_params` to be neither deployed nor
   genesised (`lib/linked_list.ak:64-87` reads no reference input at all).
4. `programmable_logic_base(params_policy)` needs `protocol_params`'s applied
   policy id (`validators/programmable_logic_base.ak:42`) and only that.
5. `transfer`, `third_party` and `unfracking` — each
   `(programmable_logic_base_cred, registry_node_cs,
   max_inline_datum_bytes)` — need `programmable_logic_base`'s credential
   (step 4) and the registry's policy id (step 3), applied with the same
   `max_inline_datum_bytes` across all three (`validators/transfer.ak:32-35`,
   `validators/third_party.ak:41-44`, `validators/unfracking.ak:56-59`; see
   [The `max_inline_datum_bytes` deployment
   invariant](./02-ARCHITECTURE.md#the-max_inline_datum_bytes-deployment-invariant)).
   `issuance_logic` needs the same two plus `protocol_params`'s policy id
   directly (`validators/issuance_logic.ak:38-47`).
6. `programmable_logic_global(transfer_hash, third_party_hash,
   unfracking_hash)` needs all three delegate hashes from step 5
   (`validators/programmable_logic_global.ak:48-51`).
7. Only once steps 1–6 are computed can the `protocol_params` genesis DATUM
   be written: fields 0–3 name step 6's dispatcher, step 5's
   `issuance_logic`, and the `transfer`/`third_party` hashes from step 5
   directly (`validators/programmable_logic/params.ak:51-75`). The genesis
   TRANSACTION has no on-chain prerequisite among these scripts — it
   consumes only its own `utxo_ref` — but the datum it writes cannot be
   assembled before those hashes exist.

Two consequences follow. The registry can be genesised before, after, or
independently of `protocol_params`'s genesis, since neither reads the
other's on-chain state. And an `issuance_cbor_hex_mint` genesis must precede
any `RegistryInsert` that references it as a reference input
(`validators/registry.ak:69-74`), but a bare `RegistryInit` needs no
reference input at all (`lib/linked_list.ak:64-87`).

---

## Transaction Rules Every Builder Obeys

### The validation chain

Every spend of a programmable-token UTxO runs the same three links, plus the policy's own substandard script:

```
programmable_logic_base   spend,   once per programmable-token input
        │ requires the withdraw-zero of the credential in protocol-params field 0
        ▼
programmable_logic_global withdraw, once per transaction
        │ requires the withdraw-zero of the delegate its redeemer names
        ▼
transfer | third_party | unfracking   withdraw, once per transaction
        │ requires the withdraw-zero named by the policy's registry node
        ▼
the policy's substandard logic script  withdraw
```

- `programmable_logic_base` reads one field out of the protocol-params datum — `programmable_logic_global_cred`, field 0 — and requires that credential's withdraw-zero at the index its redeemer witnesses (`validators/programmable_logic_base.ak:66-74`). It has no action arm: **every** programmable spend requires the dispatcher, whether it is a transfer, a seizure, or an unfracking.
- `programmable_logic_global` takes the three delegate hashes as compile-time parameters and turns its redeemer's action into a requirement that the matching delegate ran: `TransferAct` → `transfer`, `ThirdPartyAct` → `third_party`, `UnfrackingAct` → `unfracking` (`validators/programmable_logic_global.ak:63-70`).
- The delegate does the work, once per transaction: `transfer` (`validators/programmable_logic/transfer.ak:15-56`), `third_party` (`validators/programmable_logic/third_party.ak:16-58`), `unfracking` (`validators/programmable_logic/unfracking.ak:96-153`). Each resolves the subject policy's registry node from a reference input and requires the credential that node names for its kind of action.

The dispatcher's redeemer names the one delegate that **must** have run, and requires that delegate's withdraw-zero to be in the set (`validators/programmable_logic_global.ak:63-69`). That is a lower bound, not an exclusion: nothing in the dispatcher, in `programmable_logic_base` or in any delegate forbids a transaction from also carrying a second delegate's withdraw-zero, and every withdrawal in the map runs its script, so any delegate present enforces its own rules in full. Classify a transaction by the dispatcher's redeemer, not by delegate presence alone. A redeemer naming the wrong action resolves to a delegate that is not in the withdrawal set, so it can only invalidate its own transaction.

### Required withdrawals

Every withdrawal below is for **zero ADA**. Omitting any one of them fails the transaction.

| Action | Required withdraw-zero credentials | Enforced by |
|---|---|---|
| **Transfer** | `programmable_logic_global_cred`; `transfer`; the policy's `transfer_logic_script`; plus the owner's credential when the owner is a `Script` | `validators/programmable_logic_base.ak:72-74`; `validators/programmable_logic_global.ak:64`, `:69`; `validators/programmable_logic/transfer.ak:264`; `validators/programmable_logic/owner.ak:37` |
| **Seize / third party** | `programmable_logic_global_cred`; `third_party`; the policy's `third_party_logic_script` | `validators/programmable_logic_base.ak:72-74`; `validators/programmable_logic_global.ak:65`, `:69`; `validators/programmable_logic/third_party.ak:29` |
| **Unfracking** | `programmable_logic_global_cred`; `unfracking`; the policy's `unfracking_logic_script`; plus the owner's credential when the owner is a `Script` | `validators/programmable_logic_base.ak:72-74`; `validators/programmable_logic_global.ak:66`, `:69`; `validators/programmable_logic/unfracking.ak:120`; `validators/programmable_logic/owner.ak:37` |
| **Issuance (mint or burn)** | the substandard's `minting_logic_cred`; the protocol's `issuance_logic_cred` | `validators/issuance_mint.ak:46`; `validators/issuance_mint.ak:52-63` |

Three consequences worth stating plainly:

- **The dispatcher's withdraw-zero is on every programmable spend.** It is the one requirement `programmable_logic_base` makes, and it is not implied by the delegate's own withdrawal: PLB never looks at the delegate.
- **A transfer needs three script withdrawals, not two.** A transaction carrying only `transfer` and `transfer_logic_script` fails at `programmable_logic_base` before the transfer validator runs.
- **A burn is both.** Burning a programmable token spends a PLB UTxO, so the transaction carries the issuance withdrawals *and* the full spend chain for the action that releases the tokens.

Where the owner is a `Script`, one withdrawal of that credential authorises **every** PLB input in the transaction that carries it: the check is per input (`validators/programmable_logic/transfer.ak:92-104`) but is satisfied by membership in the transaction-wide withdrawal set (`validators/programmable_logic/transfer.ak:58-70`). A script that authorises a withdraw-zero must therefore enumerate the PLB inputs it means to authorise; it cannot assume it is being asked about one.

### The base spend redeemer

`BaseSpendRedeemer` is a **single-constructor record with two fields** (`lib/types.ak:79-84`):

| Field | Declared at | Meaning |
|---|---|---|
| `params_idx` | `lib/types.ak:81` | Position of the protocol-params UTxO in the ledger-ordered `reference_inputs` |
| `wdrl_idx` | `lib/types.ak:83` | Position of `programmable_logic_global_cred`'s entry in the ledger-ordered withdrawal map |

There is no action arm. The same redeemer shape is used for a transfer, a seizure and an unfracking; what distinguishes them is the `programmable_logic_global` redeemer, and that one carries no payload at all (`lib/types.ak:100-109`).

`wdrl_idx` locates the **dispatcher**, not the delegate. `programmable_logic_base.ak:72` takes the withdrawal at that index with a direct `list.expect_at` and `:74` compares it to protocol-params field 0. A wrong index resolves to some other credential and the equality fails, so a dishonest witness can only invalidate its own transaction.

### Reference inputs and index hints

`reference_inputs` reach a validator in the ledger's canonical order: sorted by `OutputReference`, which is `(transaction_id, output_index)`. **Every index below is a position in that sorted list, not in the order the builder added the references.**

What each action needs:

| Action | Reference inputs | Why |
|---|---|---|
| Transfer | the protocol-params UTxO; one registry node per distinct policy carried by the spent PLB inputs | PLB reads the params datum (`validators/programmable_logic_base.ak:66`); `transfer` resolves one proof per policy (`validators/programmable_logic/transfer.ak:50-55`) |
| Seize / third party | the protocol-params UTxO; the subject policy's registry node | PLB; `validators/third_party.ak:97-104` |
| Unfracking | the protocol-params UTxO; the acted-on policy's registry node | PLB; `validators/unfracking.ak:77-81` |
| Issuance | the protocol-params UTxO; **and** the policy's registry node, whenever that policy's proof is `RefInput` | `validators/issuance_mint.ak:52-56`; `validators/issuance_logic.ak:152-155` resolves the node out of `reference_inputs` and binds it to the policy; `validators/issuance_logic.ak:267-281` is how `issuance_logic` locates the params UTxO without a hint |

The params UTxO is required by `programmable_logic_base`, once per programmable input. **The three delegates read it zero times.** The values they would have read from it — `programmable_logic_base_cred`, `registry_node_cs` and `max_inline_datum_bytes` — are compile-time parameters of `transfer` (`validators/transfer.ak:36-38`), `third_party` (`validators/third_party.ak:40-42`) and `unfracking` (`validators/unfracking.ak:56-58`). Neither the registry NFT policy nor the PLB credential is a protocol-params datum field; see the parameter table in [`02-ARCHITECTURE.md`](./02-ARCHITECTURE.md#validator-reference).

The index hints, and who consumes each:

| Hint | Carried in | Consumed at | Addresses |
|---|---|---|---|
| `params_idx` | `BaseSpendRedeemer` (`lib/types.ak:81`) | `validators/programmable_logic_base.ak:66` | `reference_inputs` |
| `params_idx` | `IssuanceMintRedeemer` (`lib/types.ak:173`) | `validators/issuance_mint.ak:52-56` | `reference_inputs` |
| `registry_node_idx` | `ThirdPartyRedeemer` (`lib/types.ak:52`) | `validators/third_party.ak:97` | `reference_inputs` |
| `registry_node_idx` | `UnfrackingRedeemer` (`lib/types.ak:38`) | `validators/unfracking.ak:77-81` | `reference_inputs` |
| `node_idx` | each `RegistryProof` inside `TransferRedeemer` (`lib/types.ak:13`, `:15`) | `lib/registry_node.ak:83-108` | `reference_inputs` |
| `outputs_start_idx` | `ThirdPartyRedeemer` (`lib/types.ak:54`), `UnfrackingRedeemer` (`lib/types.ak:40`) | `validators/programmable_logic/third_party.ak:31-38`; `validators/programmable_logic/unfracking.ak:134-141` | `outputs` |
| `wdrl_idx` | `BaseSpendRedeemer` (`lib/types.ak:83`) | `validators/programmable_logic_base.ak:72` | `withdrawals` |

`issuance_logic` takes no index hint: it finds the params UTxO itself by scanning `reference_inputs` for the params NFT (`validators/issuance_logic.ak:267-281`).

Each hint is validated by what it resolves to, never trusted:

- the UTxO at `params_idx` must carry the protocol-params NFT policy and an inline datum (`validators/programmable_logic/params.ak:139-142`). Presence of the policy is the whole test — the asset name and quantity are not checked on this path, because the policy is a one-shot NFT;
- the UTxO at `registry_node_idx`, and at each proof's `node_idx`, must have the registry NFT policy as its first non-ADA policy and an inline datum (`validators/third_party.ak:102-104`; `lib/registry_node.ak:99-100`);
- a `TokenExists` proof's node must have `key == policy` (`validators/programmable_logic/transfer.ak:261`); a `TokenDoesNotExist` proof's node must cover the policy, `key < policy < next` (`:273-274`).

### The withdrawal index

`withdrawals` reach a validator as the ledger's `Map RewardAccount Coin`, keyed by (network, credential). Within one transaction the network is constant, so the order is cardano-ledger's derived `Ord` on `Credential`, whose constructors are declared `ScriptHashObj` **before** `KeyHashObj`:

> **Every `Script` credential sorts ahead of every `VerificationKey` credential, and hashes compare bytewise within each group.**

This is *not* Aiken's `Credential` declaration order, which lists `VerificationKey` first, and it is *not* insertion order or bech32 string order. The rule, and the two helpers that implement it, are in `validators/programmable_logic/fixture.ak:151-190` (`compare_credentials_ledger` at `:162`, `ledger_sorted_withdrawals` at `:173`, `withdrawal_index_of` at `:181`).

Compute `wdrl_idx` over the **complete** withdrawal set of the finished transaction:

1. collect every withdrawal the transaction will carry — including ones the wallet adds for reasons unrelated to programmable tokens;
2. sort: all `Script` credentials first (bytewise by hash), then all `VerificationKey` credentials (bytewise by hash);
3. `wdrl_idx` is the position of `programmable_logic_global_cred` in that list.

Two consequences for a builder:

- **Adding a key-hash withdrawal never moves a script credential's index.** A wallet that appends a reward withdrawal for the user's own stake key after computing `wdrl_idx` has not invalidated it: the new entry sorts after every script credential.
- **Adding a script withdrawal can.** A dApp script credential, or a second policy's logic script, sorts among the scripts and may land before `programmable_logic_global_cred`. Recompute `wdrl_idx` after the withdrawal set is final, never before.

### PLB output shape and the datum bound

Every output at the `programmable_logic_base` payment credential must:

- carry an **inline stake credential** — `expect Some(Inline(..))`, `lib/prog_assets.ak:218`. Without it the output has no owner any validator can authorise;
- carry **no datum hash**. `NoDatum` or an inline datum only;
- carry **no reference script**;
- where it carries an inline datum, serialise that datum to **at most `max_inline_datum_bytes`**.

The predicate is `lib/prog_assets.ak:291-302` (`is_seizable_output_shape_bounded`), applied at every site that creates a PLB output: the transfer gate (`lib/prog_assets.ak:219`, reached from `validators/programmable_logic/transfer.ak:43`), third-party and unfracking destinations, and issuance (`validators/issuance_logic.ak:203`). The reasons are in [`02-ARCHITECTURE.md`](./02-ARCHITECTURE.md#plb-output-shape); the builder-facing consequence is that an output violating any of the four is rejected at creation time, not later.

`max_inline_datum_bytes` is a compile-time parameter of four scripts — `transfer` (`validators/transfer.ak:38`), `third_party` (`validators/third_party.ak:42`), `unfracking` (`validators/unfracking.ak:58`) and `issuance_logic` (`validators/issuance_logic.ak:61`) — and **all four are deployed with the same value**. Read it from the deployment's blueprint, not from the protocol-params datum: it is not a field there.

One exception a seizure builder needs: the **paired continuing output** of a third-party action is not re-checked against the bound. It is instead required to be byte-identical to the input it is paired with — address, datum and reference script (`validators/programmable_logic/third_party.ak:196-198`) — so its datum is whatever the input already carried and was bounded when that input was created. Fresh destination outputs get the full check (`validators/programmable_logic/third_party.ak:156-161`).

**Lovelace is not covered by any of these byte-identity rules.** Both pairing validators strip ADA off the two sides before comparing them, and then treat it differently:

- a third-party pair **ratchets** it — the paired continuing output must carry **at least** the input's lovelace, `expect (output_lovelace >= input_lovelace)?` (`validators/programmable_logic/third_party.ak:217`). Byte-identity applies to the ADA-stripped halves, i.e. to the non-ADA policies (`:254-257`). Equality is deliberately *not* required: it would leave a UTxO whose lovelace sits below a later min-UTxO rise permanently unseizable. A builder may therefore top the paired output up to the current min-UTxO, and must never give it less than the input had;
- an unfracking pair leaves it **unconstrained** — the lovelace is not even read (`validators/programmable_logic/unfracking.ak:288-298`). A builder redistributes the input's ADA across the owner's outputs as min-UTxO requires, and needs no extra funding input to do it.

### Stake-credential registration and the `publish` handlers

A credential cannot appear in a transaction's withdrawals until its stake address is **registered**. This is a ledger rule, not a validator rule: an unregistered credential fails in phase 1, with no validator trace to read.

In the Conway era, registering a *script* credential requires that script's consent, so each withdraw-zero validator in the protocol carries a `publish` handler. All six accept `RegisterCredential` and refuse every other certificate:

| Validator | `publish` at |
|---|---|
| `programmable_logic_global` | `validators/programmable_logic_global.ak:72-77` |
| `transfer` | `validators/transfer.ak:70-75` |
| `third_party` | `validators/third_party.ak:76-81` |
| `unfracking` | `validators/unfracking.ak:92-97` |
| `issuance_logic` | `validators/issuance_logic.ak:89-94` |
| `upgrade_multisig` | `validators/upgrade_multisig.ak:181-186` |

Deregistration is refused on purpose. The same obligation falls on every credential a substandard registers — `minting_logic_script`, `transfer_logic_script`, `third_party_logic_script`, `unfracking_logic_script` — and on any dApp script that owns programmable tokens. A substandard script with no `publish` handler, or one that rejects `RegisterCredential`, can never be registered and therefore can never be invoked.

### Issuance needs two withdraw-zeros

A mint or a burn of a programmable token carries **both**:

1. the substandard's `minting_logic_cred` — a compile-time parameter of `issuance_mint`, checked by membership in the withdrawal set (`validators/issuance_mint.ak:46`);
2. the protocol's `issuance_logic_cred`, read live from protocol-params field 1 (`validators/issuance_mint.ak:52-63`).

The second one is the common omission, and it fails in a way that does not name it. `issuance_mint` does not merely require that `issuance_logic` ran: it requires that `issuance_logic`'s **redeemer covers this policy**. That redeemer is a `Pairs<PolicyId, MintingRegistryProof>` (`lib/types.ak:184-185`), and the mint fails unless the policy being minted is one of its keys (`validators/issuance_mint.ak:79-98`). A builder who invokes `issuance_logic` for policy A and mints policy B gets an uncovered-policy failure, not a missing-script failure.

Because `issuance_logic_cred` is a datum field rather than a parameter, replacing the issuance-logic script retires the old one for every token at once.

---

## Transaction Skeletons

Each skeleton below is transcribed from a test fixture in this repository, named in the citation line above it. The fixtures are executable and run under `aiken check`, so a skeleton that drifts from the protocol will be caught by a failing test rather than by a reader.

Two reading rules apply throughout:

- The withdrawal lists are **sets, not orders**. They are transcribed in the order the fixture constant writes them, which is not the order the ledger will present them in, so they carry no bracket numbers and no entry's position in them means anything. The one number a builder must derive is `wdrl_idx`, and it is derived by sorting the finished transaction's complete withdrawal set with the rule in [The withdrawal index](#the-withdrawal-index) — never read off a list on this page.

  The skeletons all show `wdrl_idx: 0` because in these fixtures the dispatcher's hash is the byte-minimum of the credential set, so it does sort first (`validators/programmable_logic/fixture.ak:105-107`). That is a property of those particular hashes. Worked on the transfer set: sorting `#0000..000101` (`programmable_logic_global`), `#0000..01091c` (`transfer`) and `#0000..000b0b` (the transfer-logic script) bytewise puts the *substandard's* script at index 1 and the `transfer` delegate at index 2 — the reverse of the order the fixture lists them in. Your own credentials will sort differently again.
- Reference-input positions are positions in the ledger's canonical ordering. A skeleton's `[0]`, `[1]` are shown in that ordering.

### Transfer

**Fixture sources:**

- Transcribed from validators/programmable_logic/fixture.ak:416 — some_transfer
- Transcribed from validators/programmable_logic/fixture.ak:103 — withdrawals_transfer
- Transcribed from validators/programmable_logic_base.test.ak:132 — valid_programmable_logic_base_tx

`some_transfer` supplies the inputs, outputs, reference inputs and the `transfer` redeemer; `withdrawals_transfer` the withdrawal set; `valid_programmable_logic_base_tx` the per-input base redeemer and the indices it is called with (`validators/programmable_logic_base.test.ak:142-144`).

```
Inputs:
  - sender's programmable-token UTxO
      address: addr(programmable_logic_base, sender_credential)
      value:   ADA + tokens of policy P

Reference Inputs (ledger order, sorted by (transaction_id, output_index)):
  [0] protocol-params UTxO       -- carries the params NFT, inline datum
  [1] registry node for policy P -- carries the registry NFT, key == P

Outputs:
  - addr(programmable_logic_base, recipient_credential)
      value:   ADA + tokens of policy P
      datum:   NoDatum, or an inline datum within max_inline_datum_bytes
      (no datum hash, no reference script, inline stake credential)

Withdrawals (the required set, all zero ADA; NOT in ledger order -- sort
your own set to compute wdrl_idx):
  - programmable_logic_global   -- required by every PLB spend
  - transfer                    -- required by the dispatcher's TransferAct
  - transfer_logic_script       -- policy P's rule, from its registry node

Redeemer (programmable_logic_base, one per spent PLB input):
  BaseSpendRedeemer {
    params_idx: 0,   -- position of the params UTxO in reference_inputs
    wdrl_idx:   0,   -- position of programmable_logic_global_cred in withdrawals
  }

Redeemer (programmable_logic_global, once):
  TransferAct

Redeemer (transfer, once):
  TransferRedeemer {
    proofs: [TokenExists { node_idx: 1 }],   -- one proof per distinct spent policy,
                                             -- in ascending policy order
  }

Redeemer (transfer_logic_script, once):
  as required by the substandard

Required Signatories:
  - the sender's key, when sender_credential is a VerificationKey

Collateral:
  - a standard collateral UTxO
```

Transcription notes:

- **`some_transfer` builds one further reference input** — a list-head registry node keyed `""` — so that its fixture registry is gap-free, which puts policy P's own node at position 2 and makes the fixture's proof `TokenExists { node_idx: 2 }`. That head node is not required on chain: a real registry has gaps, and a transfer references only the nodes its proofs resolve. The skeleton above omits it, which is why its `node_idx` is 1.
- **The fixture's owner credential is also policy P's `transfer_logic_script`**, so its three withdrawals cover both the substandard's rule and the owner's consent. When the owner is a *different* `Script`, add its credential as a fourth withdrawal (see [the dApp skeleton](#transaction-building)). When the owner is a `VerificationKey`, the owner signs instead and the set stays at three.
- **One proof per distinct policy in the spent inputs**, including non-programmable ones: a policy with no registry node needs a `TokenDoesNotExist` proof naming a covering node. Proofs are consumed in ascending policy order (`validators/programmable_logic/transfer.ak:180-240`).

### Seize (third party)

**Fixture sources:**

- Transcribed from validators/third_party.test.ak:231 — valid_seize_tx
- Transcribed from validators/programmable_logic/fixture.ak:118 — withdrawals_third_party

`valid_seize_tx` supplies the inputs, outputs, reference inputs and the `third_party` redeemer (the redeemer at `validators/third_party.test.ak:265`); `withdrawals_third_party` the whole-transaction withdrawal set.

```
Inputs:
  - the holder's programmable-token UTxO
      address: addr(programmable_logic_base, holder_credential)
      value:   ADA + tokens of subject policy P     -- must already hold P

Reference Inputs (ledger order):
  [0] protocol-params UTxO
  [1] registry node for subject policy P

Outputs:
  [0] the PAIRED continuing output -- address, datum and reference script
      byte-identical to input [0]; every non-subject NON-ADA policy
      byte-identical; the subject policy's tokens reduced by the seized
      amount; lovelace is EXEMPT from byte-identity and RATCHETED -- give
      this output AT LEAST the input's lovelace, and top it up freely if
      min-UTxO requires it
      (validators/programmable_logic/third_party.ak:217)
  [1] the destination output at the PLB payment credential, holding the
      seized tokens

Withdrawals (the required set, all zero ADA; NOT in ledger order -- sort
your own set to compute wdrl_idx):
  - programmable_logic_global    -- required by every PLB spend
  - third_party                  -- required by the dispatcher's ThirdPartyAct
  - third_party_logic_script     -- policy P's third-party rule, from its registry node

Redeemer (programmable_logic_base, one per spent PLB input):
  BaseSpendRedeemer { params_idx: 0, wdrl_idx: 0 }

Redeemer (programmable_logic_global, once):
  ThirdPartyAct

Redeemer (third_party, once):
  ThirdPartyRedeemer {
    registry_node_idx: 1,   -- reference-input position of P's node
    outputs_start_idx: 0,   -- where the paired region begins in outputs
  }

Redeemer (third_party_logic_script, once):
  as required by the substandard
```

Transcription notes:

- **`valid_seize_tx` carries one withdrawal**, `third_party_logic_script`. It is a unit fixture that calls the `third_party` delegate directly, so it does not build the PLB and dispatcher links. A whole transaction carries all three, which is what `withdrawals_third_party` holds; the delegate's own requirement is `validators/programmable_logic/third_party.ak:29`, the other two are `validators/programmable_logic_base.ak:72-74` and `validators/programmable_logic_global.ak:65`.
- **Both of the fixture's outputs sit at the same owner.** That is a fixture simplification: the paired output's address is pinned to its input's, but the destination output beyond the paired region is constrained only by the PLB payment credential and the output-shape rule. A real seizure sends it to the issuer's own programmable address.
- **`outputs_start_idx` is where the paired region begins.** Outputs before it are scanned for subject-policy tokens and folded into the conservation total; outputs from that index on are paired positionally with the PLB inputs. The per-pair rules and the aggregate conservation rail are stated in one place at `validators/programmable_logic/third_party.ak:99-120` and implemented at `:121-280`.
- **No owner signature and no owner withdrawal.** The holder does not consent to a seizure and is not asked to.

### Unfracking

**Fixture sources:**

- Transcribed from validators/programmable_logic/fixture.ak:526 — some_unfracking
- Transcribed from validators/programmable_logic/fixture.ak:137 — withdrawals_unfracking

`some_unfracking` supplies the inputs, outputs, reference inputs and the `unfracking` redeemer; `withdrawals_unfracking` the withdrawal set, which `some_unfracking` itself uses.

```
Inputs:
  - the holder's co-mingled programmable-token UTxO
      address: addr(programmable_logic_base, holder_credential)
      value:   ADA + tokens of acted-on policy P + tokens of other policies

Reference Inputs (ledger order):
  [0] protocol-params UTxO
  [1] registry node for acted-on policy P
      -- its unfracking_logic_script must be set; empty_vkey forbids unfracking

Outputs:
  [0] the PAIRED continuing output -- same owner, holding the non-acted
      remainder: its asset list is byte-identical to the input's except the
      acted-on policy, which is absent here. Lovelace is UNCONSTRAINED across
      an unfracking pair -- it is not read at all
      (validators/programmable_logic/unfracking.ak:288-298) -- so fund
      output [1]'s min-UTxO out of this input's own ADA rather than adding a
      separate funding input
  [1] a further output at the SAME owner, holding the moved tokens of P

Withdrawals (the required set, all zero ADA; NOT in ledger order -- sort
your own set to compute wdrl_idx):
  - programmable_logic_global    -- required by every PLB spend
  - unfracking                   -- required by the dispatcher's UnfrackingAct
  - transfer_logic_script        -- the owner's consent, when the owner is a Script
  - unfracking_logic_script      -- policy P's hook, from its registry node

Mint:
  - empty. Unfracking is value-preserving; any mint or burn fails
    (validators/programmable_logic/unfracking.ak:105)

Redeemer (programmable_logic_base, one per spent PLB input):
  BaseSpendRedeemer { params_idx: 0, wdrl_idx: 0 }

Redeemer (programmable_logic_global, once):
  UnfrackingAct

Redeemer (unfracking, once):
  UnfrackingRedeemer {
    registry_node_idx: 1,
    outputs_start_idx: 0,
  }

Redeemer (unfracking_logic_script, once):
  as required by the issuer's hook
```

Transcription notes:

- **`transfer_logic_script` is here as the owner's consent, not as a transfer rule.** In the fixture the holder's stake credential is the same script as policy P's `transfer_logic_script`, so one withdrawal serves. A holder with a `VerificationKey` credential signs instead and the set is three entries. The `transfer` validator is *not* part of an unfracking transaction.
- **`unfracking_logic_script` is default-deny.** It is registry-node field 5 (`lib/registry_node.ak:78`), and an issuer who never set it leaves it at `empty_vkey` — a zero-byte key hash (`lib/registry_node.ak:26`). No ledger transaction can carry a withdrawal keyed by an empty hash, so the unconditional requirement at `validators/programmable_logic/unfracking.ak:120` forbids unfracking outright for such a policy.
- **Every output stays at the same owner.** Unfracking restructures the holder's own UTxOs; it cannot move value to anyone else.

### Issuance (mint or burn)

**Fixture sources:**

- Transcribed from validators/issuance_mint.test.ak:119 — valid_tx

```
Reference Inputs (ledger order):
  [0] protocol-params UTxO
  [1] registry node for policy P -- REQUIRED whenever P's proof below is
      RefInput { index }, which is every mint and every burn of an
      already-registered policy. issuance_logic takes the reference input at
      that index and requires it to be P's registry node
      (validators/issuance_logic.ak:152-155). Omitted only on a first mint
      alongside registration, where the node is an OUTPUT of this transaction
      and the proof is OutputIndex { index }.

Mint:
  - (policy P, asset name, +n)   for a mint
  - (policy P, asset name, -n)   for a burn

Outputs (mint):
  - the minted supply at addr(programmable_logic_base, recipient_credential)
    (validators/issuance_logic.ak:183-215)

Inputs (burn):
  - the PLB UTxO(s) holding the tokens being burned. A burn therefore ALSO
    carries the full spend chain of whichever action releases them — see the
    transfer or seize skeleton above.

Withdrawals (all zero ADA):
  - minting_logic_cred    -- the substandard's minting logic, a compile-time
                             parameter of issuance_mint
  - issuance_logic_cred   -- the protocol's issuance logic, read live from
                             protocol-params field 1

Redeemer (issuance_mint, for the mint purpose):
  IssuanceMintRedeemer { params_idx: 0 }

Redeemer (issuance_logic, once):
  Pairs<PolicyId, MintingRegistryProof> -- MUST have policy P as a key
    [ Pair(P, RefInput { index: <reference-input position of P's registry node> }) ]
    -- or OutputIndex { index } when P's registry node is an OUTPUT of this
       transaction, i.e. the token's first mint alongside its registration
```

Transcription notes:

- **`valid_tx` is a unit fixture for `issuance_mint` alone, and its reference-input list is not a whole transaction's.** It carries only the params UTxO (`validators/issuance_mint.test.ak:122`) and its proofs are `RefInput(0)` — documented in the fixture itself as a placeholder (`validators/issuance_mint.test.ak:108-109`) because `issuance_logic` never runs in that test. In a real transaction `issuance_logic` does run, and the `RefInput` branch resolves the reference input at that index and requires it to be the policy's registry node (`validators/issuance_logic.ak:152-155`). The skeleton above therefore adds reference input `[1]`, which the fixture does not have.
- **`valid_tx` shows the withdrawal set in the order the fixture writes it.** Sort both credentials by the ledger rule before assigning any index; `issuance_mint` locates neither by index, but a PLB spend in the same transaction does need its own `wdrl_idx` computed over the complete set.
- **The `issuance_logic` redeemer's keys are the frozen interface.** `issuance_mint` decodes it only as far as `Pairs<PolicyId, Data>` and asks whether its own policy is a key (`validators/issuance_mint.ak:88-91`); the proof values are `issuance_logic`'s business and may change with the protocol.
- **A node's own programmable token is never minted or burned in a transaction that spends that node** (`validators/registry.ak:188`). Registering a new token still mints the new key, because the node being spent is the covering predecessor, not the new node. See [the registry pitfall](#common-pitfalls-2).

---

## For Wallet Developers

### Balance resolution

Programmable token balances cannot be queried the way regular native tokens are. With standard tokens you query by payment address; with programmable tokens every holder shares the same payment credential and what differs is the stake credential.

To display a user's programmable token balance:

1. Determine which credential the token protocol uses (payment key or stake key — stake key is the common convention).
2. Construct the full address: `addr(programmable_logic_base_hash, user_credential)`.
3. Query all UTxOs at that address.
4. Sum the programmable token quantities across those UTxOs.

If a user may hold tokens under both their payment and stake credentials, query both addresses:

```
Address A = addr(programmable_logic_base, user_stake_credential)
Address B = addr(programmable_logic_base, user_payment_credential)

Total balance = tokens at Address A + tokens at Address B
```

The `programmable_logic_base` hash is a deployment-level constant, the same for every programmable token in one CIP-113 deployment. Wallets take it from the deployment's blueprint.

### Building transfers

A programmable token transfer differs from a standard native token transfer in four ways. The complete shape is [the transfer skeleton](#transfer); this section is what changes relative to an ordinary transaction.

**Authorization.** The owner authorizes the spend with whichever key matches the credential in the *stake* slot — the stake key if the stake key is the owner credential, the payment key if it is the payment key. This differs from standard transactions, where the payment key always authorizes.

**Three script withdrawals, not two.** `programmable_logic_global`, `transfer`, and the policy's `transfer_logic_script`. The first is what `programmable_logic_base` requires of every spend (`validators/programmable_logic_base.ak:72-74`); a transaction without it fails before the transfer validator runs. `transfer_logic_script` is read from the policy's registry node at build time.

**Two reference inputs, at computed indices.** The protocol-params UTxO and the registry node for the policy being spent. The params UTxO is required by `programmable_logic_base`, not by `transfer`. Both positions are indices into the ledger's canonical `reference_inputs` ordering — see [Reference inputs and index hints](#reference-inputs-and-index-hints).

**One registry proof per distinct policy in the inputs.** A programmable policy gets a `TokenExists` proof naming its node; a non-programmable policy gets a `TokenDoesNotExist` proof naming a node that covers it, `key < policy < next` (`validators/programmable_logic/transfer.ak:269-277`). ADA needs no proof.

The output goes to the recipient's programmable address: the payment credential stays `programmable_logic_base`, only the stake credential changes. It must satisfy [the PLB output shape rule](#plb-output-shape-and-the-datum-bound).

### Token discovery

To determine whether a token is programmable:

1. Look up the policy id in the on-chain registry — a sorted linked list of `RegistryNode` UTxOs, each marked with an NFT of the registry policy.
2. If a node with `key == policy_id` exists, the token is programmable.
3. That node's `transfer_logic_script`, `third_party_logic_script` and `unfracking_logic_script` say which substandard governs it and what each path requires.

### Stake delegation

Programmable token addresses generally hold minimal ADA, so delegation rewards are negligible. Delegation is nonetheless possible, and depends on the credential in the stake slot:

- **Stake key as owner credential**: delegation works as normal.
- **Payment key as owner credential**: the payment key can sign a delegation certificate for the stake address derived from it; the ledger requires only a valid signature from the credential's owner.
- **Script as owner credential**: the script must handle the `publish` purpose for the certificate it wants. See [For dApp Developers](#for-dapp-developers).

### Common pitfalls

| Pitfall | Explanation |
|---|---|
| Querying by payment credential only | Returns ALL programmable token UTxOs (every holder), not just the user's. Query by the full address, including the stake credential. |
| Assuming the payment key signs the spend | The credential in the stake slot determines authorization. If the stake key is the owner, the stake key signs. |
| Omitting the dispatcher's withdraw-zero | The single most common failure. `programmable_logic_base` requires `programmable_logic_global_cred`'s withdraw-zero on **every** programmable spend (`validators/programmable_logic_base.ak:72-74`). A transaction with only `transfer` and `transfer_logic_script` is rejected. |
| Computing `wdrl_idx` against insertion order | It is a position in the ledger's ordering: every `Script` credential before every `VerificationKey` credential, bytewise within each. Recompute it once the withdrawal set is final. |
| Missing reference inputs | Both the protocol-params UTxO and the registry node must be present. Without the first, `programmable_logic_base` cannot read the dispatcher credential; without the second, `transfer` cannot resolve its proof. |
| Not registering the stake address | Every withdraw-zero credential — `programmable_logic_global`, `transfer`, the substandard's scripts, a dApp's script — must have a registered stake address. An unregistered one fails at the ledger level, in phase 1, with no validator trace. |
| Wrong credential convention | If the token protocol uses payment keys but the wallet builds the address with the stake key (or the reverse), the balance reads zero and transfers fail. |
| Caching a registry-node reference input | A registry node UTxO is consumed and re-created when a token is registered around it, or when its node is updated in place. A transfer referencing a stale (now-spent) node fails. Resolve the covering or exists node at build time, and on failure **re-resolve against the current registry and rebuild** rather than retrying the same reference. See the registration-contention limitation in [`02-ARCHITECTURE.md`](./02-ARCHITECTURE.md#registration-contention). |
| Caching a token's logic **credentials** | A registry node's `transfer_logic_script`, `third_party_logic_script`, `unfracking_logic_script` and `global_state_cs` are **live, mutable configuration** — the issuer can update them in place, and the change is **retroactive** (it governs every existing holder on their next spend). `key`, `next` and `minting_logic_script` are the only frozen fields (`lib/linked_list.ak:184-208`). Always resolve the **current** node at build time, and monitor node updates for the policies you support. |
| Building a PLB output with a datum hash or a reference script | Rejected at creation (`lib/prog_assets.ak:291-302`). Use `NoDatum` or an inline datum within `max_inline_datum_bytes`, and always an inline stake credential. |

### UTxO hygiene and anti-injection

A programmable token can be **frozen** by its substandard — the token's `transfer_logic_script` (or `third_party_logic_script`) can decline to authorize a spend. Because a single UTxO can hold assets of several policies at once, **a freeze applies to the whole UTxO, not to one asset**: if a UTxO holds a legitimate token *and* a frozen one, the legitimate token — and the UTxO's ADA — are locked with it until the frozen policy allows a spend. Nothing is stolen, but everything sharing that UTxO is held hostage.

This is the mechanism behind a **freeze-for-ransom scam**: an attacker gets a freezable token co-located in a UTxO with a victim's real assets, then declines transfers until paid. The attacker cannot place a victim's asset into a UTxO directly — the co-location happens on the **victim's own side**, when a wallet merges an unsolicited token into a UTxO with real assets during coin selection or change construction. Wallet hygiene is therefore the primary defence.

**Prevention — transaction construction:**

- **Keep programmable tokens in single-policy UTxOs.** Coin selection and change construction should not merge distinct programmable policies into one output. A user who never co-locates policies cannot be freeze-ransomed across them.
- **Keep ADA in a programmable-token UTxO at or near the minimum-UTxO value.** A freeze locks whatever ADA shares the UTxO; holding only the minimum caps the hostage amount. Keep spendable ADA in ordinary UTxOs.
- **Do not auto-consolidate unsolicited or unknown programmable-token UTxOs.** Exclude them from automatic input selection so a dust UTxO cannot be swept into a UTxO holding real assets. This is the single most effective control against the scam above.

**Detection — treat suspicious programmable tokens like suspicious NFTs and CNTs.** Wallets already flag, filter or hide spam and scam native tokens; extend that infrastructure to programmable tokens. Beyond the usual signals (unsolicited receipt, no metadata, known-scam lists), programmable tokens expose extra risk data worth surfacing:

- Whether a co-located token is a **registered programmable token** at all — and if so, from its registry node, **who can freeze or seize it** (`transfer_logic_script` / `third_party_logic_script` and the credentials behind them). A *registered* token with **unknown or untrusted logic** sitting beside a user's assets is the loud signal: only a registered token can freeze the shared UTxO, because its transfer logic runs on the spend and can decline. An **unregistered** co-located token is an ordinary native token — it moves via a covering-node proof and cannot lock the UTxO, though it may still be spam.
- **Newly-formed co-location.** Flag any output that places multiple distinct programmable policies together when **no input already held that combination** — the co-location is being created, not carried forward. Apply this both to the wallet's own change and, critically, to any externally-built transaction presented for signing. Suppress it for a **continuing output** (an input already held the same combination) and for recognized dApp interactions.

**Recovery — separating a co-mingled UTxO.** If assets do end up co-located, the holder splits the UTxO into single-policy UTxOs, after which a freeze on one policy leaves the others free. The `unfracking` validator (`validators/unfracking.ak:55`) performs exactly this split: a same-owner, value-preserving restructuring of the holder's own PLB UTxOs for one policy, gated by that policy's own `unfracking_logic_script` hook rather than by its transfer logic. The legitimate token is freed and the suspicious token is isolated in its own UTxO. Build it as [the unfracking skeleton](#unfracking).

The practical consequence for users: **freeze-for-ransom only works if the tokens cannot be separated** — a wallet that supports both the prevention above and this separation defangs the scam, and users should never pay.

**Legitimate exceptions.** Multi-asset programmable UTxOs are not inherently suspicious:

- **Same-policy companion assets** (e.g. a CIP-68 user token and its reference NFT under one policy) are one policy, not co-location — do not flag them.
- **dApp interactions** (e.g. a liquidity pool holding two programmable tokens) legitimately produce multi-policy UTxOs. Flag-and-explain rather than block, and suppress for continuing outputs and allow-listed contracts.

The through-line: **hygiene prevents co-location, minimal ADA caps the hostage, separation is the cure, and scam-token detection warns the user before they walk into the trap.**

---

## For Indexers and Explorers

Indexers and explorers share the concern of reading and interpreting on-chain state. The difference is presentation: explorers display to humans, indexers store for API consumers. The data access patterns are the same.

### Balance tracking

#### Resolving ownership

All programmable tokens live at addresses sharing the `programmable_logic_base` payment credential. To determine who owns what:

1. **Query all UTxOs** at the `programmable_logic_base` payment credential.
2. **Group by stake credential** — each unique stake credential is a distinct owner.
3. **Sum token quantities** per stake credential per policy id.

This gives an account-like view of programmable token holdings.

#### Script owners

The stake credential can be a **script hash**, not just a verification key hash. This happens when a smart contract (DEX, lending protocol, DAO treasury) holds programmable tokens. Indexers must:

- Identify `Script` credentials as a distinct owner type.
- Label them appropriately (e.g. "smart contract" rather than a wallet address).
- Not assume all owners are human wallet holders.

#### Credential type ambiguity

A `VerificationKey` credential hash in the stake slot could come from either a payment key or a stake key. **The on-chain data does not distinguish them** — both are a 28-byte blake2b-224 hash under the `VerificationKey` constructor. Indexers cannot tell the source from the programmable address alone.

In practice:

- If the hash matches a known stake key hash from the chain's registration records, it is likely a stake key.
- If it matches a known payment key hash from other transaction witnesses, it is likely a payment key.
- Cross-referencing with known address mappings can help, but is not always possible.

### Transaction history

#### By stake address (standard case)

When the owner credential is a stake key, querying history is straightforward: filter transactions that consume or produce UTxOs at `addr(programmable_logic_base, stake_credential)`. This aligns with existing indexer patterns for stake address queries.

#### By payment key in the stake slot (enterprise address / CEX pattern)

When an enterprise wallet uses its payment key as the owner credential, history queries become less intuitive:

- The entity's payment key hash sits in the **stake credential position** of the programmable address.
- To find their programmable token transactions, query by that payment key hash **as a stake credential**, not as a payment credential.
- This inverts the usual mental model where "payment key = payment side, stake key = staking side".

**Example:**

```
CEX has payment key hash: abc123...

Standard (non-programmable) address:
  addr(abc123..., <no stake>)                -- enterprise address, query by payment cred

Programmable token address:
  addr(programmable_logic_base, abc123...)   -- abc123 is now in the stake slot

To find the CEX's programmable tokens:
  Query UTxOs where payment_cred = programmable_logic_base AND stake_cred = abc123...
```

Indexers serving enterprise clients therefore need to:

- Accept queries by a credential hash that might appear in the stake slot.
- Not assume a payment key hash appears only as a payment credential.
- Offer a "query by owner credential" API that checks the stake slot of programmable addresses regardless of the credential's original role.

#### Identifying transfer, third-party and unfracking transactions

Every programmable-token transaction carries the `programmable_logic_global` withdraw-zero, so that credential is the marker of a programmable spend as such. What distinguishes the three actions is **the redeemer on the dispatcher's withdraw-zero**. Each redeemer arm requires the matching delegate's withdraw-zero as well (`validators/programmable_logic_global.ak:63-69`), so the delegate is a reliable corroboration — but only the redeemer is decisive, because that requirement is a lower bound and a transaction may carry a second delegate's withdraw-zero too:

| Transaction type | Dispatcher redeemer → delegate withdraw-zero | Characteristics |
|---|---|---|
| **Transfer** | `TransferAct` → `transfer` (`TransferRedeemer { proofs }`) | Owner-authorized. The stake credential owner signed or invoked. Input and output may have different stake credentials. |
| **Unfracking** | `UnfrackingAct` → `unfracking` (`UnfrackingRedeemer { registry_node_idx, outputs_start_idx }`) | Owner-authorized, same-owner, value-preserving restructuring of one policy across the holder's own PLB UTxOs. No transfer logic runs; the policy's unfracking hook does. Mint and burn are both empty. |
| **Third-party** | `ThirdPartyAct` → `third_party` (`ThirdPartyRedeemer { registry_node_idx, outputs_start_idx }`) | Authorised by the policy's third-party logic script (forced transfer, seizure, burn). No owner signature or owner withdrawal. The paired continuing output preserves the holder's address, datum and reference script; among non-ADA policies only the subject policy's tokens change, while its lovelace may rise (`validators/programmable_logic/third_party.ak:217`). An indexer must not read a lovelace increase on that output as a payment. |

The base-spend redeemer does **not** distinguish them: `BaseSpendRedeemer` is a single-constructor record carrying two indices (`lib/types.ak:79-84`), identical in all three cases.

Explorers should display these differently. A third-party action is not a voluntary transfer and should be flagged as a third-party (compliance) action.

### Registry state

The on-chain registry is a sorted linked list of `RegistryNode` UTxOs. Each node has seven fields (`lib/registry_node.ak:51-81`); the five an indexer will care about are:

- **`key`** — the registered programmable token policy id.
- **`transfer_logic_script`** — the substandard credential that governs ordinary transfers.
- **`third_party_logic_script`** — the compliance credential.
- **`unfracking_logic_script`** — the issuer's unfracking hook, or `empty_vkey` when the issuer forbids unfracking for the policy.
- **`global_state_cs`** — may point to additional on-chain state, such as a denylist.

Four of the seven are mutable in place — the three logic-script fields above and `global_state_cs` (`lib/linked_list.ak:184-208`). An indexer that snapshots a node once will serve stale governance data.

#### Compliance events (freeze-and-seize substandard)

For tokens using the freeze-and-seize substandard, indexers should additionally track:

- **Denylist changes**: insertions (`BlacklistInsert`) and removals (`BlacklistRemove`) on the blacklist linked list.
- **Frozen addresses**: current denylist membership indicates frozen or sanctioned credentials.
- **Third-party actions**: transactions carrying the `third_party` withdraw-zero and a `ThirdPartyRedeemer`, where the third-party logic script forcibly changes a holder's subject-token balance without the holder's consent.

### Common pitfalls

| Pitfall | Explanation |
|---|---|
| Attributing all tokens to the script address | Without stake-credential-level grouping, all programmable tokens appear to belong to one giant script address. Decompose by stake credential. |
| Missing script owners | If only `VerificationKey` credentials are indexed, script-held tokens (dApps, DAOs) are invisible. |
| Confusing payment keys in stake slots | A credential hash in the stake slot may be a payment key hash. Do not assume it corresponds to a registered stake address. |
| Classifying by the base-spend redeemer | `BaseSpendRedeemer` is identical for all three actions. Classify by the `programmable_logic_global` redeemer, which names the delegate that had to run. |
| Treating delegate presence as exclusive | The dispatcher requires one named delegate's withdraw-zero (`validators/programmable_logic_global.ak:63-69`); it does not forbid another delegate's from also being present. An indexer that assumes at most one delegate appears will mis-classify, or crash on, such a transaction. |
| Treating third-party actions as transfers | A transaction carrying the `third_party` withdraw-zero is a third-party action, not a user-initiated transfer. Display it differently and flag it for compliance. |
| Ignoring registry changes | New registrations change which policies are programmable, and node updates change who governs an existing one. An indexer that snapshots the registry once misses both. |

---

## For dApp Developers

If your dApp (DEX, lending protocol, DAO treasury, escrow) needs to **hold or manage programmable tokens**, the integration model differs from regular native tokens: your dApp's script must be the *owner* of the programmable token UTxOs, which means its script hash occupies the stake credential slot.

### Script as owner

```
Programmable Address = addr(programmable_logic_base, dapp_script_hash)
                                                     ─────────────────
                                                     Your dApp's script
                                                     is the "owner"
```

To authorize spending from this address, the owner check resolves the `Script` branch:

```aiken
Script(_hash) -> has_withdrawal(stake_cred)
```

`validators/programmable_logic/owner.ak:37`. This is the **delegate's** check — it runs inside `transfer` (`validators/programmable_logic/transfer.ak:98`) and inside `unfracking` (`validators/programmable_logic/unfracking.ak:169`). `programmable_logic_global` never inspects an input's stake credential; it only requires the delegate's withdraw-zero (`validators/programmable_logic_global.ak:63-70`).

So your dApp's script must be **invokable as a stake validator via withdraw-zero**:

1. **Implement the `withdraw` purpose.** Your script is invoked by a zero-ADA withdrawal, not as a spending validator.
2. **Implement `publish` and accept `RegisterCredential`.** In the Conway era, registering a script stake credential requires the script's consent. A script that refuses it can never be registered and therefore never invoked.
3. **Register the stake address on-chain**, once, before the dApp holds anything.

### Transaction building

**Fixture sources:**

- Transcribed from validators/programmable_logic/fixture.ak:416 — some_transfer
- Transcribed from validators/programmable_logic/fixture.ak:103 — withdrawals_transfer

This is [the transfer skeleton](#transfer) with **one** addition: the dApp's own script credential, as the owner's consent. In the fixture that role is played by `transfer_logic_script`, which is both the policy's transfer logic and the holder's stake credential (`validators/programmable_logic/fixture.ak:113`, `:278`); when the owner is a distinct script the two separate and the withdrawal set grows from three entries to four.

```
Withdrawals (the required set, all zero ADA; NOT in ledger order -- sort
your own set to compute wdrl_idx):
  - programmable_logic_global    -- required by every PLB spend
  - transfer                     -- required by the dispatcher's TransferAct
  - transfer_logic_script        -- the token's substandard rule
  - dapp_script                  -- your dApp's authorization, as the owner

Reference Inputs (ledger order):
  [0] protocol-params UTxO
  [1] registry node for the token's policy

Inputs:
  - programmable token UTxO(s) at addr(programmable_logic_base, dapp_script_hash)
  - (optionally) your dApp's own state UTxOs

Outputs:
  - new programmable token UTxO(s) with updated ownership
  - (optionally) updated dApp state UTxOs

Redeemers:
  - programmable_logic_base (per spent PLB input):
      BaseSpendRedeemer { params_idx, wdrl_idx }
        -- wdrl_idx is programmable_logic_global_cred's position in the
           ledger-ordered withdrawal set, recomputed AFTER adding dapp_script
  - programmable_logic_global (once): TransferAct
  - transfer (once): TransferRedeemer { proofs: [...] }
  - transfer_logic_script (withdraw): as required by the substandard
  - dapp_script (withdraw): your dApp's redeemer
```

Four simultaneous withdraw-zero invocations. Each runs independently and all must pass.

Note the ordering hazard: `dapp_script` is a `Script` credential, so it sorts among the script credentials and may land **before** `programmable_logic_global_cred`. Compute `wdrl_idx` after the withdrawal set is complete, not while building it. See [The withdrawal index](#the-withdrawal-index).

### What your script must handle

Your dApp's `withdraw` handler is the gate for all spending of programmable tokens held by your dApp. It must:

1. **Validate your business logic** — whatever the dApp's purpose is (swap, lend, vote), this is where you enforce it.
2. **Enumerate the PLB inputs it is authorizing.** One withdrawal of your credential satisfies the owner check for **every** PLB input in the transaction whose stake credential is your script: the check is per input (`validators/programmable_logic/transfer.ak:92-104`) but is satisfied by set membership (`validators/programmable_logic/transfer.ak:58-70`). Your handler cannot assume it is being asked about a single UTxO — if it approves at all, it approves all of them.
3. **Not re-validate the programmable chain.** Registry proofs, containment at PLB, and the substandard's rules are `transfer`'s and `transfer_logic_script`'s job. Your script's concern is whether *this* transaction is a legitimate dApp operation over *these* inputs.

### Stake address registration

Before your dApp can hold or spend programmable tokens, its script stake address must be registered on-chain. A one-time setup:

1. Build a transaction including a stake-address registration certificate for your script's credential.
2. The registration requires the ledger's deposit.
3. Your script's `publish` handler must accept `RegisterCredential` for that certificate to validate.

**If the stake address is not registered, any transaction attempting to withdraw from it — even zero ADA — is rejected by the ledger**, not by a validator. It fails in phase 1, so there is no validator trace to read.

### Delegation and withdrawal

Your script occupies the stake credential slot, so it is a staking credential from the ledger's perspective:

- **Delegation**: your script can delegate to a stake pool if its `publish` handler authorizes the delegation certificate. The ADA in programmable token UTxOs is minimal, so rewards are negligible.
- **Reward withdrawal**: if rewards accumulate, your script authorizes the withdrawal. Its `withdraw` handler is invoked both for zero-ADA programmable-token authorization and for real reward withdrawals; make sure it distinguishes the two, for instance by checking the withdrawal amount.

### Execution budget

A programmable-token transaction loads several validators at once:

- `programmable_logic_base` (spend) — **once per programmable input**
- `programmable_logic_global` (withdraw) — once per transaction
- the delegate, `transfer` / `third_party` / `unfracking` (withdraw) — once per transaction
- the policy's substandard logic script (withdraw) — once per transaction
- your dApp script (withdraw) — once per transaction

Budget accordingly. `programmable_logic_base` is the one that multiplies, which is why it does the smallest job in the protocol: one reference-input lookup, one field read, one withdrawal lookup, one equality (`validators/programmable_logic_base.ak:66-74`). The delegate is the expensive one — `transfer` walks the registry proofs and sums values across inputs and outputs — so cost grows with the number of distinct policy ids, not only with the number of inputs. Profile with realistic transaction sizes.

### Composability patterns

#### Receiving programmable tokens

When your dApp receives programmable tokens (a user deposits into a pool):

- The output must be at `addr(programmable_logic_base, dapp_script_hash)` and satisfy [the PLB output shape rule](#plb-output-shape-and-the-datum-bound).
- Your dApp's script hash is the owner; later spends require its authorization.
- The sender's transaction handles the transfer validation. Your dApp is not invoked on deposit, only on release.

#### Releasing programmable tokens

When your dApp releases programmable tokens (a user withdraws from a pool):

- Your dApp's script is invoked via withdraw-zero to authorize the spend.
- The output goes to `addr(programmable_logic_base, recipient_credential)`.
- The full chain runs: `programmable_logic_base` → `programmable_logic_global` → `transfer` → the policy's `transfer_logic_script`, with your script alongside as the owner's consent.

#### Holding mixed assets

A dApp UTxO at `addr(programmable_logic_base, dapp_script_hash)` can hold both programmable and non-programmable tokens. The `transfer` validator handles this: a non-programmable policy is proven absent from the registry by a `TokenDoesNotExist` covering-node proof and skipped (`validators/programmable_logic/transfer.ak:269-277`). Every distinct non-ADA policy in the spent inputs needs a proof of one kind or the other.

Mixing is still a liability rather than a convenience — see [UTxO hygiene and anti-injection](#utxo-hygiene-and-anti-injection). A frozen policy in a shared UTxO freezes everything beside it, including your dApp's own assets.

### Common pitfalls

| Pitfall | Explanation |
|---|---|
| Not implementing the `withdraw` purpose | Your script must be a stake validator, or a multi-purpose validator with a `withdraw` handler. A pure spending validator cannot authorize programmable token operations. |
| Not implementing `publish`, or refusing `RegisterCredential` | The stake credential can then never be registered, and an unregistered credential can never withdraw. |
| Forgetting stake address registration | Without it, every transaction fails at the ledger level — no validator error, a phase-1 rejection. |
| Assuming your withdrawal authorizes one input | It authorizes every PLB input in the transaction carrying your script as its stake credential. Enumerate them in your handler. |
| Conflating zero-ADA and real withdrawals | Your `withdraw` handler is invoked for both. Check the withdrawal amount. |
| Computing `wdrl_idx` before adding your own withdrawal | Your script credential sorts among the script credentials and can shift `programmable_logic_global_cred`'s position. Recompute over the final set. |
| Not budgeting execution units | Several validator invocations in one transaction can exceed default budgets, and `programmable_logic_base` runs once per input. Profile on preview or preprod. |
| Assuming direct UTxO spending | You do not spend programmable token UTxOs with your spending validator; you authorize via withdraw-zero. `programmable_logic_base` is the spending validator, and it requires the dispatcher's withdraw-zero on every path (`validators/programmable_logic_base.ak:72-74`) — transfers, third-party actions and unfracking alike. |
| Minting the token in a registry lifecycle transaction | A registry-node lifecycle transaction — registering a token, or updating a node in place — must **not** mint or burn that node's own programmable token. The `registry` validator's spend handler rejects it (`validators/registry.ak:187-188`, inside the handler at `:174-238`), and it is the sole spender of every node. Lifecycle and issuance are always **separate** transactions. Registering a *new* token still mints the new key; the rule applies to the node being *spent*, e.g. the covering predecessor. See [Registry Lifecycle & Upgradeability](./09-DEVELOPING-SUBSTANDARDS.md#registry-lifecycle--upgradeability) and [`03` §3.2](./03-CONTROL-SCOPE-AND-THIRD-PARTY-ACTIONS.md). |

---

**Next**: [Developing Substandards](./09-DEVELOPING-SUBSTANDARDS.md) | **Back to**: [README](../README.md)

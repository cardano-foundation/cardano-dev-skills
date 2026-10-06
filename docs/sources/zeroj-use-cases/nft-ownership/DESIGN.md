# Design: Private NFT Ownership on Cardano

A detailed walkthrough of how this demo works — from ZK circuits to on-chain verification.

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [System Architecture](#system-architecture)
- [ZK Circuit](#zk-circuit)
  - [What the Circuit Proves](#what-the-circuit-proves)
  - [Signals (Inputs and Outputs)](#signals-inputs-and-outputs)
  - [Circuit Logic Step by Step](#circuit-logic-step-by-step)
  - [Poseidon Hash](#poseidon-hash)
  - [Merkle Tree](#merkle-tree)
  - [Nullifier](#nullifier)
- [Proof Generation (Off-Chain)](#proof-generation-off-chain)
  - [Groth16 Prover](#groth16-prover)
  - [Trusted Setup](#trusted-setup)
- [On-Chain Verification](#on-chain-verification)
  - [Two-Validator Design](#two-validator-design)
  - [ZkProofMintingPolicy](#zkproofmintingpolicy)
  - [NullifierListValidator](#nullifierlistvalidator)
  - [How They Work Together](#how-they-work-together)
- [Sorted Linked List (On-Chain Nullifier Storage)](#sorted-linked-list-on-chain-nullifier-storage)
  - [Why a Linked List?](#why-a-linked-list)
  - [How Insertion Works](#how-insertion-works)
  - [UTXO Contention](#utxo-contention)
- [Transaction Flow](#transaction-flow)
  - [Init: Deploy Root Sentinel](#init-deploy-root-sentinel)
  - [Insert: Record Nullifier On-Chain](#insert-record-nullifier-on-chain)
- [Data Flow (End to End)](#data-flow-end-to-end)
- [What Each Party Sees](#what-each-party-sees)
- [Security Properties](#security-properties)
- [Cost Analysis](#cost-analysis)

---

## The Problem

On Cardano, proving you own an NFT requires revealing your wallet address:

```
Verifier: "Prove you own a ZeroJTicket NFT"
You:      "Here's my wallet addr1_abc... — check the UTXO set"
Verifier: ✓ Verified

But now everyone knows:
  - Your wallet address
  - Every other token you hold
  - Your full transaction history
  - Your ADA balance
```

This is a privacy problem for token-gated events, anonymous DAO voting, anti-sybil airdrops, and more.

## The Solution

With zero-knowledge proofs, you prove ownership without revealing anything:

```
Verifier: "Prove you own a ZeroJTicket NFT"
You:      "Here's a 192-byte proof"
Verifier: ✓ Verified

Nobody knows:
  - Which wallet holds the NFT
  - Which specific NFT was used
  - Any other information about the holder
```

The proof is verified on-chain via Cardano's Plutus V3 BLS12-381 builtins. A nullifier (one-time token) prevents using the same proof twice.

## System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  USER (Browser or curl)                                       │
│                                                               │
│  1. Register as NFT holder (secretKey + tokenName)            │
│  2. Request ZK proof                                          │
│  3. Submit proof for gated access                             │
└────────────────────┬─────────────────────────────────────────┘
                     │ REST API (http://localhost:8085)
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  SPRING BOOT BACKEND                                          │
│                                                               │
│  ProverService          — compiles circuit, generates proofs  │
│  SnapshotService        — builds Merkle tree of holders       │
│  OnChainNullifierService — manages on-chain linked list       │
│  MintService            — mints NFTs on Cardano               │
└────────────────────┬─────────────────────────────────────────┘
                     │ Cardano transactions
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  CARDANO (Yaci DevKit)                                        │
│                                                               │
│  ZkProofMintingPolicy    — Groth16 BLS12-381 pairing check   │
│  NullifierListValidator  — sorted linked list of nullifiers  │
│                                                               │
│  On-chain state:                                              │
│    ROOT → node(null_A) → node(null_B) → ∅                    │
│    Each node is a UTXO with an NFT + inline datum             │
└──────────────────────────────────────────────────────────────┘
```

## ZK Circuit

### What the Circuit Proves

The circuit proves a single statement:

> "I know a secret key and a token name such that their combined hash
> is a leaf in the published Merkle tree of NFT holders."

This is equivalent to proving: "I own an NFT from this collection" — without revealing which wallet, which NFT, or any other information.

### Signals (Inputs and Outputs)

Think of "signals" as the variables in the ZK proof. Some are secret (only the prover knows them), and some are public (everyone can see them).

```
SECRET (only the NFT holder knows these):
  secretKey    — identifies the wallet (never revealed)
  tokenName    — identifies which NFT
  sibling_0..9 — Merkle proof path (10 values for depth 10)
  pathBit_0..9 — direction at each tree level (left=0, right=1)

PUBLIC (visible to everyone):
  snapshotRoot — the Merkle root of all holders (published on-chain)
  contextId    — what this proof is for (e.g., "event-123", "airdrop-456")

OUTPUT (computed by the circuit):
  isOwner      — always 1 if the proof is valid
  nullifier    — a unique one-time token (prevents reuse)
```

### Circuit Logic Step by Step

```
Step 1: Derive an owner identifier from the secret key
        ownerHash = Poseidon(secretKey, 0)

        This is a one-way hash. Given ownerHash, nobody can find secretKey.
        The snapshot builder uses the same formula to compute ownerHash
        for each registered holder.

Step 2: Compute the leaf (what the holder's entry looks like in the tree)
        leaf = Poseidon(ownerHash, tokenName)

Step 3: Verify the leaf is in the Merkle tree
        Walk up the tree from the leaf to the root using the siblings
        and path bits. The computed root must match snapshotRoot.

        For each level i (bottom to top):
          if pathBit[i] == 0:  current = Poseidon(current, sibling[i])
          if pathBit[i] == 1:  current = Poseidon(sibling[i], current)

        Assert: computed root == snapshotRoot

Step 4: Compute the nullifier (anti-replay token)
        nullifier = Poseidon(tokenName, contextId)

        Same NFT + same context = same nullifier (prevents double use).
        Different context = different nullifier (allows reuse for other events).

Step 5: Assert isOwner = 1 (all checks passed)
```

This circuit compiles to **10,847 R1CS constraints** at depth 10 (supporting 1,024 holders).

### Poseidon Hash

Poseidon is a hash function designed specifically for ZK circuits. It works over prime fields (not bytes), making it efficient inside a circuit. Each Poseidon hash adds ~650 constraints.

We use the BLS12-381 scalar field (`r = 0x73eda753...`), matching Cardano's Plutus V3 BLS builtins.

### Merkle Tree

A Merkle tree lets you prove a value is in a set without revealing the entire set.

```
Depth 10 tree (1,024 leaves):

              Root
             /    \
           H01    H23
          /  \   /  \
         H0  H1 H2  H3
        / \  ...
       L0 L1 ...        ← 1,024 leaves

Each leaf: Poseidon(ownerHash, tokenName)
Each internal node: Poseidon(leftChild, rightChild)
```

To prove leaf L5 is in the tree, you provide:
- The 10 siblings along the path from L5 to the root
- The 10 path direction bits (left or right at each level)

The verifier recomputes the root from the leaf + siblings and checks it matches.

### Nullifier

The nullifier prevents using the same proof twice:

```
Alice uses ZeroJTicket#42 for event-123:
  nullifier = Poseidon(42, "event-123") = 0xABC

Alice tries again for the same event:
  nullifier = Poseidon(42, "event-123") = 0xABC  ← same! Rejected.

Alice uses ZeroJTicket#42 for airdrop-456:
  nullifier = Poseidon(42, "airdrop-456") = 0xDEF  ← different context, allowed.
```

The nullifier is stored on-chain. Before granting access, the system checks if the nullifier already exists.

## Proof Generation (Off-Chain)

### Groth16 Prover

Groth16 is a ZK proof system that produces very small proofs (192 bytes) with fast verification. The prover:

1. Takes the circuit (10,847 constraints) and the witness (all signal values)
2. Performs elliptic curve operations on BLS12-381 (scalar multiplications, multi-scalar multiplication, FFT)
3. Outputs three curve points: `(A, B, C)` — the proof

This is done entirely in **pure Java** — no native code, no external tools. It takes ~7-30 seconds depending on CPU.

### Trusted Setup

Groth16 requires a one-time "trusted setup" that generates proving and verification keys. In this demo, we use a **dev-only single-party setup** (generated at startup). For production, you'd use an MPC (multi-party computation) ceremony.

The setup produces:
- **Proving key** — used by the prover (large, kept on the server)
- **Verification key** — used by the on-chain verifier (small, baked into the Plutus script)

## On-Chain Verification

### Two-Validator Design

The on-chain verification uses two Plutus V3 scripts that work together in a single transaction:

```
┌─────────────────────────────────────┐
│  ZkProofMintingPolicy               │
│                                     │
│  Validates the Groth16 proof        │
│  (BLS12-381 pairing check)          │
│  Mints 1 "ZK token" as proof        │
│  that verification passed            │
└────────────────┬────────────────────┘
                 │ both run in the same transaction
┌────────────────┴────────────────────┐
│  NullifierListValidator             │
│                                     │
│  Validates sorted linked list       │
│  insertion (data structure check)   │
│  Checks that ZK token was minted    │
│  (couples to proof verification)    │
└─────────────────────────────────────┘
```

**Why two scripts?** Separation of concerns:
- The ZK policy handles **cryptographic correctness** (is the proof valid?)
- The list validator handles **data structure correctness** (is the linked list maintained?)
- They're coupled: the list validator checks that the ZK policy minted in the same tx

### ZkProofMintingPolicy

This is a `@MintingValidator` (Julc annotation). It runs when tokens are minted under its policy.

**What it does:**
1. Decompresses the proof points (piA, piB, piC) from compressed BLS12-381 format
2. Decompresses the 9 verification key points (baked in at deploy time via `@Param`)
3. Extracts the 4 public inputs from the redeemer: snapshotRoot, contextId, isOwner, nullifier
4. Computes `vk_x = IC[0] + pub[0]*IC[1] + pub[1]*IC[2] + pub[2]*IC[3] + pub[3]*IC[4]`
5. Performs the Groth16 pairing check:
   - `e(A, B) * e(-alpha, beta) == e(vk_x, gamma) * e(C, delta)`
   - Uses Plutus V3 BLS12-381 builtins: `bls12_381_millerLoop`, `bls12_381_mulMlResult`, `bls12_381_finalVerify`
6. Checks that exactly 1 token was minted with name = nullifier bytes
7. Checks isOwner = 1

**Cost:** ~4 miller loops + 4 scalar multiplications + 1 final verify. This fits within Cardano's execution budget.

### NullifierListValidator

This is a `@MultiValidator` (Julc annotation) with two purposes:

**MINT purpose** — validates the linked list operation:
- `InitList`: creates the root sentinel node (one-time setup)
- `InsertNode`: inserts a new nullifier in sorted order

**SPEND purpose** — allows spending list nodes only when the MINT policy also runs:
```java
return NullifierListLib.requireListTokensMintedOrBurned(txInfo.mint(), ownHash);
```
This is the "coupling pattern": the SPEND validator delegates all logic to the MINT validator.

### How They Work Together

In a single Cardano transaction:

```
Inputs:
  - Admin wallet (pays fees)
  - Predecessor node UTXO (the node we're inserting after)

Minting:
  - NullifierListValidator mints 1 list NFT (token name = "N" + nullifier_key)
    → validates sorted insertion
  - ZkProofMintingPolicy mints 1 ZK token (token name = nullifier_full)
    → validates Groth16 proof

Outputs:
  - Updated predecessor (datum.nextKey = new nullifier key)
  - New node (datum.nextKey = predecessor's old nextKey) + both tokens

Spend:
  - NullifierListValidator (SPEND) allows spending the predecessor
    because it sees its own policy in the mint field
```

## Sorted Linked List (On-Chain Nullifier Storage)

### Why a Linked List?

On Cardano's UTXO model, you can't store a growing list in a single UTXO (16KB datum limit). Instead, each nullifier is its own UTXO, linked in sorted order.

```
ROOT(0x00) → node(0x3A) → node(0x5C) → node(0x8F) → ∅

Each node is a UTXO at the script address:
  - Holds an NFT (unique identifier)
  - Has an inline datum: { userData, nextKey }
  - nextKey points to the next node (empty = end of list)
```

**How does sorted order prove non-existence?** If you want to insert `0x4B`, you find the predecessor where `0x3A < 0x4B < 0x5C`. If no such position exists, the nullifier already exists in the list.

### How Insertion Works

```
Before: ROOT → node(0x3A) → node(0x5C) → ∅

Insert 0x4B:
  1. Find predecessor: node(0x3A) where 0x3A < 0x4B < 0x5C
  2. Consume predecessor UTXO
  3. Create two new UTXOs:
     - Updated predecessor: { nextKey: 0x4B }
     - New node: { nextKey: 0x5C }

After: ROOT → node(0x3A) → node(0x4B) → node(0x5C) → ∅
```

The on-chain validator checks:
- Sorted order: `predecessor.key < new.key < predecessor.oldNext`
- Predecessor updated correctly
- New node points to predecessor's old next
- Exactly 1 new NFT minted
- ZK proof verified (via ZK minting policy)

### UTXO Contention

Different nullifier insertions touch **different** nodes in the list, so they can happen in parallel:

```
Insert 0x11 → touches ROOT          (first in list)
Insert 0x77 → touches node(0x5C)    (different node — no contention!)
```

Contention only occurs when two insertions target the same predecessor. As the list grows, this becomes increasingly unlikely (~0.1% for 1,000+ entries).

## Transaction Flow

### Init: Deploy Root Sentinel

A one-time transaction creates the root node (runs at app startup):

```
Mint: 1 token (listPolicy, "NROOT")
Output: UTXO at script address
  Value: 2 ADA + 1 NROOT token
  Datum: { userData: (), nextKey: "" }  ← empty nextKey = end of list

Validator: NullifierListValidator (MINT, InitList)
  ✓ Output at script address
  ✓ nextKey is empty
  ✓ Exactly 1 NROOT token minted
```

### Insert: Record Nullifier On-Chain

Each access request creates a transaction:

```
Inputs:
  [0] Predecessor UTXO (e.g., ROOT with NROOT token)
  [1] Admin wallet (fees + ADA for new node)

Mint:
  [listPolicy] 1 token named "N" + nullifier_key_31bytes   ← list NFT
  [zkPolicy]   1 token named nullifier_full_32bytes        ← ZK proof token

Outputs:
  [0] Updated predecessor at script address
      Value: 2 ADA + predecessor's NFT
      Datum: { userData: (), nextKey: nullifier_key }

  [1] New node at script address
      Value: 2 ADA + list NFT + ZK token
      Datum: { userData: (), nextKey: predecessor's old nextKey }

  [2] Change back to admin wallet

Validators that run:
  1. ZkProofMintingPolicy (MINT)
     ✓ Groth16 pairing check passes
     ✓ Token name = nullifier bytes
     ✓ Exactly 1 ZK token minted
     ✓ isOwner = 1

  2. NullifierListValidator (MINT, InsertNode)
     ✓ Sorted order maintained
     ✓ Predecessor updated correctly
     ✓ New node linked correctly
     ✓ Exactly 1 list NFT minted
     ✓ ZK policy also minted in this tx

  3. NullifierListValidator (SPEND)
     ✓ Own policy appears in mint field (coupling check)
```

## Data Flow (End to End)

```
User                    Backend                         Cardano
 │                        │                               │
 │  POST /register        │                               │
 │  (secretKey, token) ──>│                               │
 │                        │  ownerHash=Poseidon(sk,0)     │
 │                        │  leaf=Poseidon(ownerHash,tok)  │
 │                        │  store leaf in memory          │
 │                        │                               │
 │  POST /snapshot/build  │                               │
 │ ──────────────────────>│                               │
 │                        │  Build Merkle tree             │
 │                        │  Compute root                  │
 │                        │                               │
 │  POST /prove           │                               │
 │  (secretKey, token) ──>│                               │
 │                        │  Find leaf in tree             │
 │                        │  Get Merkle path (siblings)    │
 │                        │  Compute witness               │
 │                        │  Groth16 prove (~7-30s)        │
 │  <── proof + nullifier │                               │
 │                        │                               │
 │  POST /access          │                               │
 │  (nullifier) ─────────>│                               │
 │                        │  Check not already used        │
 │                        │  Compress proof to BLS bytes   │
 │                        │  Find predecessor in list      │
 │                        │  Build Cardano tx:             │
 │                        │    - Spend predecessor         │
 │                        │    - Mint ZK token (proof)     │
 │                        │    - Mint list NFT (node)      │
 │                        │    - Output updated pred       │
 │                        │    - Output new node           │
 │                        │  ──── submit tx ──────────────>│
 │                        │                               │  Validate:
 │                        │                               │  - Groth16 pairing ✓
 │                        │                               │  - Sorted insertion ✓
 │                        │                               │  - Coupling check ✓
 │                        │  <──── tx confirmed ──────────│
 │  <── access granted    │                               │
 │      + txHash          │                               │
```

## What Each Party Sees

| Data | NFT Holder | Verifier | Public Chain |
|------|-----------|----------|--------------|
| Wallet address | Yes | **No** | **No** |
| Which specific NFT | Yes | **No** | **No** |
| Other tokens in wallet | Yes | **No** | **No** |
| ADA balance | Yes | **No** | **No** |
| "Owns an NFT from this collection" | Yes | Yes | Yes |
| Nullifier (one-time token) | Yes | Yes | Yes |
| Proof (192 bytes) | Yes | Yes | Yes |

## Security Properties

| Property | How it's achieved |
|----------|-------------------|
| **Privacy** | ZK proof reveals nothing about wallet, NFT, or holdings |
| **Soundness** | Groth16 proof is computationally infeasible to forge |
| **One-time use** | Nullifier = Poseidon(tokenName, contextId) — deterministic, stored on-chain |
| **Reusability** | Different contextId produces different nullifier (same NFT, different event) |
| **Trustless verification** | Pairing check runs on-chain in Plutus V3 (no off-chain trust) |
| **Concurrent access** | Sorted linked list — different insertions touch different nodes |
| **Non-censorship** | Sorted order proves non-existence — can't silently reject valid nullifiers |

## Cost Analysis

| Operation | Cost | Frequency |
|-----------|------|-----------|
| Root sentinel deployment | ~2 ADA | Once per collection |
| ZK proof generation | Free (off-chain computation) | Per access request |
| Nullifier insertion tx | ~2 ADA locked per node | Per access request |
| Off-chain verification | Free | Per status check |

Each nullifier node locks ~2 ADA in a UTXO. For an event with 1,000 attendees, that's ~2,000 ADA locked (reclaimable after the event if remove operations are added).

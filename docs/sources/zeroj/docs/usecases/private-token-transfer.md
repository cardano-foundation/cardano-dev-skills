# Private Token Transfer on Cardano — Detailed Design

Send ADA from address A to address B with no on-chain link between them.

## Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [How ZK Private Transfers Work](#how-zk-private-transfers-work)
- [The Core Protocol](#the-core-protocol)
- [The ZK Circuits](#the-zk-circuits)
  - [Deposit Circuit](#deposit-circuit)
  - [Withdrawal Circuit](#withdrawal-circuit)
- [On-Chain Design: Cardano UTXO Patterns](#on-chain-design-cardano-utxo-patterns)
  - [Challenge: Where Do Commitments Live?](#challenge-where-do-commitments-live)
  - [Approach 1: Single UTXO Merkle Root](#approach-1-single-utxo-merkle-root)
  - [Approach 2: Sorted Linked List of Commitments](#approach-2-sorted-linked-list-of-commitments)
  - [Approach 3: Deposit UTXOs as Individual Notes (UTXO-Native)](#approach-3-deposit-utxos-as-individual-notes-utxo-native)
  - [Approach 4: Batch Deposit with Periodic Root Update](#approach-4-batch-deposit-with-periodic-root-update)
- [The Relayer Problem](#the-relayer-problem)
- [Fixed vs Variable Amounts](#fixed-vs-variable-amounts)
- [Nullifier Management on Cardano](#nullifier-management-on-cardano)
- [Multi-Asset Support (Native Tokens)](#multi-asset-support-native-tokens)
- [Smart Contract Code (Julc)](#smart-contract-code-julc)
- [Full Transaction Flow](#full-transaction-flow)
- [Cost Analysis](#cost-analysis)
- [Approach Comparison](#approach-comparison)
- [Security Considerations](#security-considerations)
- [Compliance: Privacy Pools](#compliance-privacy-pools)
- [Architecture Recommendation](#architecture-recommendation)
- [CircuitSpec Implementation](#circuitspec-implementation)

---

## Overview

Alice wants to send 100 ADA to Bob. Today, this is a public transaction — everyone can see Alice sent 100 ADA to Bob. With a ZK privacy pool, Alice deposits 100 ADA into a shared pool, and Bob withdraws 100 ADA from the pool. The deposit and withdrawal are **cryptographically unlinkable**.

```
Today (public):
  Alice ──100 ADA──▶ Bob         Everyone sees: Alice → Bob

With ZK privacy pool:
  Alice ──100 ADA──▶ Pool        Everyone sees: Alice → Pool
       (time passes, others deposit/withdraw)
  Pool ──100 ADA──▶ Bob          Everyone sees: Pool → Bob

  Nobody can link Alice's deposit to Bob's withdrawal.
```

## The Problem

Every Cardano transaction is public:

```
Tx: addr1_alice → addr1_bob, 100 ADA
```

This reveals:
- **Who** sent (Alice's address)
- **Who** received (Bob's address)
- **How much** (100 ADA)
- **When** (slot/block)

Even with multiple addresses, chain analysis can correlate:
- Same UTXOs feeding multiple transactions
- Change outputs linking back to the sender
- Timing analysis (deposit then immediate withdrawal)

## How ZK Private Transfers Work

The protocol has two phases:

### Phase 1: Deposit

Alice generates a random **secret** and **nullifier**, computes `commitment = Poseidon(secret, nullifier)`, and deposits ADA into the pool along with the commitment.

```
Alice knows: secret = 42, nullifier = 789
Alice computes: commitment = Poseidon(42, 789) = 0xABC...
Alice deposits: 100 ADA + commitment 0xABC to pool contract

On-chain: commitment 0xABC is added to the pool's Merkle tree
Alice's identity is linked to this deposit (publicly visible)
```

### Phase 2: Withdrawal

Later, Bob (actually Alice using a new address, or someone Alice shared the secret with) generates a ZK proof:

```
Bob proves (without revealing which commitment is his):
  1. "I know a secret and nullifier such that Poseidon(secret, nullifier) = some commitment"
  2. "That commitment is in the pool's Merkle tree" (membership proof)
  3. "nullifierHash = Poseidon(nullifier) is my anti-double-spend token"

Bob reveals: nullifierHash (prevents double-withdrawal), recipient address
Bob hides: which commitment is his, the secret, the nullifier
```

The pool contract:
1. Verifies the ZK proof (BLS12-381 pairing check)
2. Checks nullifierHash is not already used
3. Records nullifierHash (prevents double-withdrawal)
4. Sends 100 ADA to the recipient address

**Nobody can tell which deposit Bob is withdrawing.** The anonymity set is everyone who deposited into the pool.

## The Core Protocol

### What Each Party Sees

| Data | Depositor | Withdrawer | Pool Contract | Public |
|------|-----------|------------|---------------|--------|
| Secret | Yes | Yes (shared) | No | No |
| Nullifier | Yes | Yes (shared) | No | No |
| Commitment | Yes | Yes | Yes | Yes |
| NullifierHash | No (until withdrawal) | Yes | Yes | Yes |
| Which commitment is being withdrawn | Yes | Yes | **No** | **No** |
| Deposit amount | Yes | Yes | Yes | Yes |
| Deposit address | Yes | No | No | Yes |
| Withdrawal address | No | Yes | No | Yes |
| **Link between deposit and withdrawal** | Yes | Yes | **No** | **No** |

### The Math

```
Deposit:
  secret = random()
  nullifier = random()
  commitment = Poseidon(secret, nullifier)
  → Publish commitment, deposit ADA

Withdrawal:
  nullifierHash = Poseidon(nullifier)
  → ZK prove: "I know (secret, nullifier) such that
     Poseidon(secret, nullifier) is in the Merkle tree
     AND nullifierHash = Poseidon(nullifier)"
  → Publish nullifierHash, receive ADA
```

## The ZK Circuits

### Deposit Circuit

The deposit doesn't need a ZK proof — it's a simple commitment publication. But we can optionally prove the commitment is well-formed:

```java
public class DepositCircuit implements CircuitSpec {
    @Override
    public void define(SignalBuilder c) {
        Signal secret     = c.privateInput("secret");
        Signal nullifier  = c.privateInput("nullifier");
        Signal commitment = c.publicOutput("commitment");

        // commitment = Poseidon(secret, nullifier)
        c.assertEqual(SignalPoseidon.hash(c, secret, nullifier), commitment);
    }
}
```

**Constraints**: ~330 (one Poseidon hash). This proof is optional — the depositor can compute the commitment off-chain and just publish it.

### Withdrawal Circuit

This is the critical circuit. It proves membership in the deposit tree without revealing which deposit:

```java
public class WithdrawalCircuit implements CircuitSpec {
    private final int treeDepth;

    public WithdrawalCircuit(int treeDepth) { this.treeDepth = treeDepth; }

    @Override
    public void define(SignalBuilder c) {
        // Secret inputs — only the withdrawer knows
        Signal secret    = c.privateInput("secret");
        Signal nullifier = c.privateInput("nullifier");

        // Merkle proof (secret — hides which deposit)
        Signal[] siblings = new Signal[treeDepth];
        Signal[] pathBits = new Signal[treeDepth];
        for (int i = 0; i < treeDepth; i++) {
            siblings[i] = c.privateInput("sibling_" + i);
            pathBits[i] = c.privateInput("pathBit_" + i);
        }

        // Public inputs
        Signal merkleRoot    = c.publicInput("merkleRoot");
        Signal recipient     = c.publicInput("recipient");  // withdrawal address hash
        Signal relayerFee    = c.publicInput("relayerFee"); // optional fee for relayer

        // Public outputs
        Signal nullifierHash = c.publicOutput("nullifierHash");

        // === Constraints ===

        // 1. Compute the commitment from secret inputs
        Signal commitment = SignalPoseidon.hash(c, secret, nullifier);

        // 2. Prove commitment is in the Merkle tree
        SignalMerkle.verifyProof(c, commitment, c.signal("merkleRoot"),
                siblings, pathBits, SignalPoseidon::hash);

        // 3. Compute nullifier hash (for double-spend prevention)
        c.assertEqual(SignalPoseidon.hash(c, nullifier, c.constant(0)),
                      nullifierHash);

        // 4. Bind recipient and fee to the proof
        //    (prevents front-running: nobody can redirect the withdrawal)
        //    These are public inputs — included in the proof's public signals
        //    The smart contract checks they match the transaction
    }

    public static CircuitBuilder build(int treeDepth) {
        var builder = CircuitBuilder.create("withdrawal")
                .publicVar("merkleRoot")
                .publicVar("recipient")
                .publicVar("relayerFee")
                .publicVar("nullifierHash")
                .secretVar("secret")
                .secretVar("nullifier");

        for (int i = 0; i < treeDepth; i++) {
            builder = builder.secretVar("sibling_" + i).secretVar("pathBit_" + i);
        }
        return builder.defineSignals(new WithdrawalCircuit(treeDepth));
    }
}
```

**Estimated constraints** (tree depth 20 = 1M deposits):

| Component | Constraints |
|-----------|------------|
| Commitment hash (Poseidon) | ~330 |
| Merkle proof (20 levels × Poseidon) | ~6,600 |
| Nullifier hash (Poseidon) | ~330 |
| **Total** | **~7,260** |

## On-Chain Design: Cardano UTXO Patterns

The core question: **where do the deposit commitments live on-chain?**

### Challenge: Where Do Commitments Live?

On Ethereum, Tornado Cash stores all commitments in a contract's storage (a Merkle tree in a mapping). On Cardano, there's no global mutable storage. Each UTXO is independent.

This creates two sub-problems:
1. **Deposit**: How to add a commitment to the pool's "state"
2. **Withdrawal**: How to prove your commitment is in the pool, and record the nullifier

### Approach 1: Single UTXO Merkle Root

Store only the Merkle root of all commitments in one UTXO:

```
Pool UTXO:
  Datum: {
    commitmentRoot: 0x1234...,   // Merkle root of all deposits
    depositCount: 500,
    poolValue: 50,000 ADA
  }
```

**Deposit**: Consume pool UTXO, update root (insert commitment into tree), produce new UTXO.
**Withdrawal**: Consume pool UTXO, verify ZK proof against root, check nullifier, reduce pool value.

| Pros | Cons |
|------|------|
| Constant-size on-chain state (~100 bytes) | **Single point of contention** — only 1 deposit OR withdrawal per block |
| Cheapest on-chain footprint | Requires off-chain Merkle tree service |
| Simple contract logic | Withdrawal and deposit compete for same UTXO |

**Concurrency mitigation**: Batch multiple deposits/withdrawals in one transaction via an aggregator.

**Verdict**: Simple but has severe contention. Best combined with batching.

### Approach 2: Sorted Linked List of Commitments

Same pattern as the voting nullifier list — each commitment is its own UTXO in sorted order:

```
HEAD(0x00) → commit(0x3A) → commit(0x5C) → commit(0x8F) → TAIL(0xFF)
```

**Deposit**: Insert commitment into sorted list (touch only predecessor node).
**Withdrawal**: Prove membership of your commitment via ZK (against a root computed from the list), add nullifier to a separate nullifier linked list.

| Pros | Cons |
|------|------|
| **Natural concurrency** — different deposits touch different nodes | Two linked lists needed (commitments + nullifiers) |
| **Trustless** — no off-chain components for deposits | Computing Merkle root from linked list is expensive |
| Deposits are parallel | Withdrawal still needs Merkle proof (how to get siblings?) |

**The problem**: The withdrawer needs Merkle siblings to generate the ZK proof. With a linked list, there's no efficient way to compute siblings without scanning the whole list. This requires either:
- An off-chain indexer that builds the Merkle tree from the linked list
- Or a different data structure

**Verdict**: Good for deposits, awkward for withdrawals. Hybrid approach needed.

### Approach 3: Deposit UTXOs as Individual Notes (UTXO-Native)

**This is the most Cardano-native approach.** Instead of a Merkle tree, each deposit is a standalone UTXO:

```
Deposit UTXO 1: { commitment: 0xABC, value: 100 ADA }  at poolScript
Deposit UTXO 2: { commitment: 0xDEF, value: 100 ADA }  at poolScript
Deposit UTXO 3: { commitment: 0x123, value: 100 ADA }  at poolScript
...
```

**Withdrawal**: The ZK proof doesn't use a Merkle tree. Instead, it proves knowledge of the secret behind ONE of the commitments — but via a **different mechanism**:

```
Withdrawal proves:
  "I know (secret, nullifier) such that Poseidon(secret, nullifier) = C
   where C is the commitment in the UTXO I'm consuming"
```

The trick: the withdrawer **selects which UTXO to consume** (their deposit), but the ZK proof hides the connection because:
- The proof doesn't reveal the secret or nullifier
- The nullifierHash prevents double-spend
- **BUT**: the transaction itself reveals which UTXO is consumed!

**This breaks privacy!** If Alice deposits to UTXO #42 and Bob withdraws UTXO #42, the link is obvious.

**Fix**: Consume **multiple** deposit UTXOs in one transaction, and produce new deposit UTXOs:

```
Transaction:
  Inputs:  deposit(0xABC), deposit(0xDEF), deposit(0x123)  // consume 3
  Outputs: deposit(0xAAA), deposit(0xBBB)                    // re-create 2
           withdrawal(100 ADA → Bob)                          // withdraw 1

  ZK proof: "One of the 3 inputs is mine, I produced 2 new valid commitments
             for the other 2 depositors, and I'm withdrawing the third"
```

This is essentially a **CoinJoin with ZK** — but much more complex.

| Pros | Cons |
|------|------|
| Perfectly UTXO-native | **Very complex circuit** (multi-input/output proof) |
| No Merkle tree needed | Anonymity set = # inputs in the tx (small) |
| Parallel deposits | **Coordinator needed** to assemble multi-input tx |
| | Requires cooperation between depositors |

**Verdict**: Theoretically elegant but practically difficult. The anonymity set is too small (limited by transaction size).

### Approach 4: Batch Deposit with Periodic Root Update

A hybrid that combines the best of approaches 1 and 2:

```
Phase 1: Deposits accumulate as individual UTXOs (like Approach 3)
Phase 2: A "tree builder" periodically collects deposits and updates the Merkle root
Phase 3: Withdrawals use the Merkle root (like Approach 1)
```

```
┌─────────────────────────────────────────────────────────────────┐
│  DEPOSIT PHASE (parallel, no contention)                        │
│                                                                 │
│  deposit UTXO 1: { commitment: 0xABC, 100 ADA }                │
│  deposit UTXO 2: { commitment: 0xDEF, 100 ADA }                │
│  deposit UTXO 3: { commitment: 0x123, 100 ADA }                │
│  (each deposit is independent — fully parallel)                 │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  TREE UPDATE (periodic batch — operator or anyone)              │
│                                                                 │
│  Transaction:                                                   │
│    Inputs:  deposit(0xABC), deposit(0xDEF), deposit(0x123),    │
│             pool UTXO { root: ROOT_OLD, count: 10 }             │
│    Outputs: pool UTXO { root: ROOT_NEW, count: 13 }            │
│                                                                 │
│  ROOT_NEW = insert(0xABC, insert(0xDEF, insert(0x123, ROOT_OLD)))│
│  Pool ADA += 300 ADA (from 3 deposits)                          │
│                                                                 │
│  Verified by: ZK proof or on-chain computation                  │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  WITHDRAWAL PHASE (uses updated Merkle root)                    │
│                                                                 │
│  Withdrawer generates ZK proof against ROOT_NEW                 │
│  Transaction:                                                   │
│    Inputs:  pool UTXO { root: ROOT_NEW, count: 13, value: X }  │
│    Outputs: pool UTXO { root: ROOT_NEW, count: 13, value: X-100}│
│             withdrawal { 100 ADA → recipient }                  │
│             nullifier recorded (sorted linked list)             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

| Pros | Cons |
|------|------|
| **Deposits are fully parallel** (no contention) | Tree update is periodic (deposits not immediately withdrawable) |
| **Withdrawals use proven Merkle root** | Operator/anyone runs the tree builder |
| Pool UTXO is constant size | Two-phase: deposit → wait for tree update → withdraw |
| Large anonymity set | Tree builder needs to be incentivized |
| Nullifiers via sorted linked list (trustless) | Slightly more complex architecture |

**Key insight**: The tree builder is **trustless** — anyone can build the tree because:
1. Deposit commitments are public (on-chain UTXOs)
2. The Merkle insertion can be verified on-chain or via ZK proof
3. If the tree builder lies, the ZK withdrawal proof won't verify

**Verdict**: Best balance for Cardano. Parallel deposits, proven Merkle withdrawals, trustless tree building.

## The Relayer Problem

### The Bootstrapping Issue

When Bob withdraws to a **new address**, that address has no ADA to pay the transaction fee. If Bob uses his existing address to pay fees, the privacy is broken (linked to his identity).

### Solution: Relayer Network

A relayer submits the withdrawal transaction on Bob's behalf and takes a fee from the withdrawn amount:

```
Bob wants to withdraw 100 ADA to a fresh address.
Bob has no ADA at that address (can't pay tx fees).

Bob → Relayer: "Here's my ZK proof + recipient address"
Relayer → Cardano: submits tx, pays fee (~0.3 ADA)

Transaction:
  Pool → Bob's new address: 99.7 ADA  (100 - relayer fee)
  Pool → Relayer: 0.3 ADA             (fee)
```

**The relayer can't steal**: The ZK proof binds the recipient and fee to the proof. If the relayer changes the recipient or increases the fee, the proof is invalid.

**How it's enforced**: The `recipient` and `relayerFee` are **public inputs** to the ZK circuit. The on-chain contract checks these match the transaction outputs.

### Relayer Trust Model

| What relayer CAN do | What relayer CANNOT do |
|---------------------|----------------------|
| Delay submission | Change the recipient |
| Refuse to relay (censorship) | Change the fee (bound in proof) |
| See the recipient address | See which deposit is being withdrawn |
| Charge a fee | Steal the funds |

**Censorship mitigation**: Multiple competing relayers. Or Bob waits until he has ADA at the new address (via a friend, faucet, etc.) and submits directly.

## Fixed vs Variable Amounts

### Fixed Denomination (Simple, Stronger Privacy)

Like Tornado Cash — separate pools for 10, 100, 1000 ADA:

```
Pool-10:   deposit/withdraw exactly 10 ADA
Pool-100:  deposit/withdraw exactly 100 ADA
Pool-1000: deposit/withdraw exactly 1000 ADA
```

| Pros | Cons |
|------|------|
| Maximum anonymity (all deposits look identical) | Must split/combine amounts manually |
| Simple circuit (no amount proof needed) | Many pools to manage |
| Easy to reason about privacy set | Specific amounts may be fingerprinted |

### Variable Amount (Complex, Flexible)

Support any deposit amount with a **note-based** system (like Zcash):

```
Deposit: Alice deposits 137 ADA, gets a "note" for 137 ADA
Withdraw: Alice can split into: 100 ADA note + 37 ADA note
          Or merge: combine two notes into one
```

The circuit must prove:
- Sum of input note values = sum of output note values (balance)
- Each note has a valid commitment
- No value creation (overflow prevention)

| Pros | Cons |
|------|------|
| Flexible amounts | **Much more complex circuit** (~20K+ constraints) |
| Single pool for all amounts | Amount range proofs needed |
| Better UX | Smaller anonymity set per amount |

**Recommendation**: Start with fixed denomination. It's simpler, has stronger privacy, and is easier to audit. Add variable amounts later if needed.

## Nullifier Management on Cardano

Same approaches as voting (see [Private Voting](private-voting.md#nullifier-management-on-cardano)):

**Recommended: Sorted linked list** for nullifiers (trustless, concurrent, no off-chain dependency).

Each withdrawal adds one nullifier node to the sorted list:

```
Withdrawal tx:
  1. Consume predecessor nullifier node
  2. Insert new nullifier node (sorted position)
  3. ZK proof verifies withdrawal is valid
  4. Pool releases ADA to recipient
```

## Multi-Asset Support (Native Tokens)

Cardano's native multi-asset support means the privacy pool can handle any token:

```
Pool-ADA-100:    100 ADA deposits
Pool-HOSKY-1M:   1,000,000 HOSKY deposits
Pool-WMT-500:    500 WMT deposits
```

Each pool is a separate instance with its own:
- Commitment Merkle tree
- Nullifier linked list
- Minting policy (for nullifier tokens)
- Pool value denomination

The circuit is identical — only the on-chain scripts differ in the value they check.

## Smart Contract Code (Julc)

### Deposit Validator

```java
@SpendingValidator
public class PrivacyPoolDeposit {

    @Param static byte[] poolScriptHash;   // where deposits accumulate
    @Param static long denomination;        // fixed amount (e.g., 100_000_000 lovelace)

    record DepositDatum(byte[] commitment) {}

    @Entrypoint
    static boolean validate(PlutusData datum, PlutusData redeemer, PlutusData ctx) {
        // This validator governs deposit UTXOs before they're absorbed into the pool.
        // Tree builder consumes these + pool UTXO, updates Merkle root.

        // Check: this deposit is being consumed by the pool script
        // (prevents stealing deposits)
        PlutusData outputs = getOutputs(ctx);
        boolean sentToPool = hasOutputToScript(outputs, poolScriptHash);

        return sentToPool;
    }
}
```

### Pool Validator (Withdrawal)

```java
    @SpendingValidator
    public class PrivacyPool {

    @Param static byte[] vkAlpha, vkBeta, vkGamma, vkDelta;
    @Param static PlutusData vkIc;
    @Param static byte[] nullifierRegistryHash;
    @Param static long denomination;

    record PoolDatum(
        byte[] merkleRoot,
        long depositCount,
        long poolValueLovelace
    ) {}

    record WithdrawRedeemer(
        byte[] piA, byte[] piB, byte[] piC,    // ZK proof
        byte[] nullifierHash,                   // anti-double-spend
        byte[] recipientPkh,                    // withdrawal address
        long relayerFee                         // relayer compensation
    ) {}

    @Entrypoint
    static boolean validate(PoolDatum datum, WithdrawRedeemer redeemer, PlutusData ctx) {

        // 1. Verify Groth16 ZK proof
        //    Public inputs: [merkleRoot, recipientHash, relayerFee, nullifierHash]
        boolean proofValid = verifyGroth16(
            redeemer.piA(), redeemer.piB(), redeemer.piC(),
            datum.merkleRoot(),
            redeemer.recipientPkh(),
            redeemer.relayerFee(),
            redeemer.nullifierHash());

        // 2. Check output sends denomination to recipient
        boolean recipientPaid = hasOutputToAddress(
            ctx, redeemer.recipientPkh(), denomination - redeemer.relayerFee());

        // 3. Check pool UTXO continues with reduced value
        boolean poolContinues = hasContinuingOutput(ctx,
            datum.merkleRoot(), datum.depositCount(),
            datum.poolValueLovelace() - denomination);

        // 4. Check nullifier is recorded (via nullifier registry interaction)
        boolean nullifierRecorded = checkNullifierMinted(
            ctx, nullifierRegistryHash, redeemer.nullifierHash());

        return proofValid && recipientPaid && poolContinues && nullifierRecorded;
    }
}
```

## Full Transaction Flow

### Setup

```
1. Deploy PrivacyPoolDeposit validator
2. Deploy PrivacyPool validator (with Groth16 VK baked in)
3. Deploy NullifierRegistry (sorted linked list)
4. Create initial pool UTXO: { merkleRoot: EMPTY_ROOT, count: 0, value: 0 }
5. Create nullifier sentinels: HEAD(0x00) → TAIL(0xFF)
```

### Alice Deposits 100 ADA

```
Transaction:
  Inputs:  Alice's wallet (100 ADA + fees)
  Outputs: Deposit UTXO at depositValidator address
           { commitment: Poseidon(secret, nullifier), value: 100 ADA }

  No ZK proof needed. Alice computes commitment off-chain.
  Alice saves (secret, nullifier) securely — needed for withdrawal.
```

### Tree Builder Absorbs Deposits (Periodic)

```
Transaction:
  Inputs:  deposit(0xABC), deposit(0xDEF), deposit(0x123),
           pool UTXO { root: OLD_ROOT, count: 10, value: 1000 ADA }
  Outputs: pool UTXO { root: NEW_ROOT, count: 13, value: 1300 ADA }

  Proof: ZK proof that NEW_ROOT = insert(0xABC, insert(0xDEF, insert(0x123, OLD_ROOT)))
         OR on-chain computation (if tree is small enough)

  Anyone can run this — it's trustless (deposit commitments are public).
```

### Bob Withdraws 100 ADA (Later, from New Address)

```
Step 1: Bob gets current Merkle tree state (from indexer or by scanning chain)
Step 2: Bob finds his commitment's position and generates Merkle siblings
Step 3: Bob generates ZK proof:
        - secret, nullifier → commitment
        - commitment is in tree (Merkle proof)
        - nullifierHash = Poseidon(nullifier)
Step 4: Bob sends proof to relayer (or submits directly if he has ADA)

Transaction:
  Inputs:  pool UTXO { root: ROOT, count: 13, value: 1300 ADA }
           nullifier predecessor node (for sorted insertion)
  Outputs: pool UTXO { root: ROOT, count: 13, value: 1200 ADA }
           Bob's address: 99.7 ADA
           Relayer: 0.3 ADA
           New nullifier node in sorted list

  On-chain:
    ✓ ZK proof valid (BLS12-381 pairing)
    ✓ NullifierHash not in sorted list (new node inserted)
    ✓ 99.7 + 0.3 = 100 ADA = denomination
    ✓ Recipient matches proof's public input
```

### Alice Tries to Double-Withdraw

```
Alice's nullifier is deterministic: nullifierHash = Poseidon(nullifier)
This hash is already in the nullifier sorted list.
No valid insertion point exists → transaction fails.
```

## Cost Analysis

### Per-Operation Costs

| Operation | Tx Fee | ADA Locked | Who Pays |
|-----------|--------|-----------|----------|
| Deposit | ~0.3 ADA | 100 ADA (denomination) + ~1.5 ADA (UTXO min) | Depositor |
| Tree update (batch 10) | ~0.5 ADA | None (deposits absorbed) | Tree builder (incentivized) |
| Withdrawal | ~0.5 ADA | ~1.5 ADA (nullifier node) | Relayer (from withdrawal fee) |
| Nullifier cleanup (after pool closes) | ~0.3 ADA | Reclaims ~1.5 ADA per node | Pool operator |

### Pool Economics (100 ADA denomination, 1000 deposits)

| Item | Cost |
|------|------|
| Total deposited | 100,000 ADA |
| Deposit UTXO overhead | ~1,500 ADA (reclaimable after tree absorption) |
| Nullifier nodes | ~1,500 ADA (reclaimable after pool closes) |
| Tree builder incentive | ~50 ADA (0.5 ADA per batch of 10) |
| Relayer fees | ~300 ADA (0.3 ADA per withdrawal) |
| **Net privacy cost** | **~0.65 ADA per transfer** (~0.35% of denomination) |

## Approach Comparison

| | Single Merkle UTXO | Sorted Linked List | UTXO Notes | **Batch Deposit (Recommended)** |
|---|---|---|---|---|
| **Deposit contention** | High | Low | **None** | **None** |
| **Withdrawal contention** | High | Low (nullifiers) | N/A | Medium (pool UTXO) |
| **Off-chain requirement** | Tree service | None for deposits | None | Tree indexer (trustless) |
| **Anonymity set** | All deposits | All deposits | Tx inputs only | **All deposits** |
| **Circuit complexity** | ~7K constraints | ~7K + list proof | ~20K+ | **~7K constraints** |
| **Trust** | Tree service | **Trustless** | Coordinator | **Tree builder (trustless)** |
| **Scalability** | Unlimited | Unlimited | Limited by tx size | **Unlimited** |

## Security Considerations

### Anonymity Set Size

Privacy is proportional to the number of deposits in the pool. With 10 deposits, an observer has a 1-in-10 chance of guessing the link. With 10,000 deposits, it's 1-in-10,000.

**Recommendation**: Don't withdraw immediately after depositing. Wait for at least 100 more deposits to improve your anonymity set.

### Timing Analysis

If Alice deposits at block 100 and Bob withdraws at block 101, the timing correlation is suspicious. Mitigations:
- Wait for many blocks between deposit and withdrawal
- Use the pool during high-activity periods
- Randomize withdrawal timing

### Amount Fingerprinting

If Alice deposits exactly 137.5 ADA and Bob withdraws 137.5 ADA, the amount itself links them. This is why **fixed denominations** are critical for privacy.

### Graph Analysis

Multiple deposits and withdrawals from the same identity can be correlated via:
- Common change addresses
- UTXO graph analysis
- Timing patterns

**Best practice**: Use a completely fresh wallet for withdrawals, funded only by the privacy pool.

## Compliance: Privacy Pools

Privacy pools can include **compliance mechanisms** without breaking privacy:

### Association Sets

A withdrawer can prove: "My deposit is NOT from a sanctioned address" without revealing which deposit is theirs.

```
The circuit additionally proves:
  "My commitment is in the GOOD SET (Merkle root of non-sanctioned deposits)
   AND my commitment is in the FULL SET (all deposits)"
```

This allows:
- Regulated DeFi protocols to accept privacy pool withdrawals
- Users to prove compliance without revealing their identity
- Sanctioned addresses to be excluded without de-anonymizing anyone

This is the **Privacy Pools** proposal (Buterin, et al., 2023) — compatible with ZK proofs and applicable to Cardano.

## Architecture Recommendation

### For Cardano (Recommended: Batch Deposit Pattern)

```
┌──────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────┐
│ Depositor │───▶│ Deposit UTXO  │───▶│  Tree Builder    │───▶│ Pool UTXO    │
│           │    │ (parallel,   │    │  (periodic batch)│    │ (Merkle root)│
│           │    │  no contention)│   │  (trustless)     │    │              │
└──────────┘    └──────────────┘    └─────────────────┘    └──────┬───────┘
                                                                  │
┌──────────┐    ┌──────────────┐    ┌─────────────────┐          │
│ Withdrawer│◀──│  Relayer      │◀──│ Withdrawal Tx    │◀─────────┘
│ (new addr)│   │ (pays fees)  │    │ (ZK proof +     │
│           │    │              │    │  nullifier)      │
└──────────┘    └──────────────┘    └─────────────────┘
                                           │
                                    ┌──────▼──────────┐
                                    │ Nullifier List   │
                                    │ (sorted linked   │
                                    │  list — trustless)│
                                    └─────────────────┘
```

### Why This Design

1. **Deposits are parallel** — no contention, anyone can deposit anytime
2. **Tree builder is trustless** — just reads public deposit commitments and updates root
3. **Withdrawals use proven Merkle root** — standard ZK membership proof
4. **Nullifiers via sorted linked list** — trustless, concurrent, no off-chain dependency
5. **Relayer solves the fee bootstrapping problem** — recipient and fee bound in the ZK proof
6. **Fixed denomination** — strongest privacy, simplest circuit
7. **~0.65 ADA total cost per private transfer** — practical for real use

## CircuitSpec Implementation

The withdrawal circuit is the core cryptographic component:

```java
// Build the circuit (parameterized by tree depth)
var circuit = WithdrawalCircuit.build(20);  // depth 20 = 1M deposits

// Compile for BLS12-381 (Cardano on-chain verification)
var r1cs = circuit.compileR1CS(CurveId.BLS12_381);
// ~7,260 constraints

// Setup (local dev requires -Dzeroj.allowInsecureTrustedSetup=true;
// production: use MPC ceremony .zkey)
var srs = PowersOfTauBLS381.generate(13);
var setup = Groth16SetupBLS381.setup(constraints, numWires, numPublic, srs.tauScalar());

// Prove (pure Java, on withdrawer's device)
var proof = Groth16ProverBLS381.prove(setup.provingKey(), witness, constraints, numWires);

// Compress for on-chain (192 bytes)
var compressed = ProverToCardano.compressProof(proof);

// Submit via relayer or directly to Cardano
```

The proof is ~192 bytes regardless of pool size. Verification cost on Cardano is identical whether the pool has 10 or 1,000,000 deposits.

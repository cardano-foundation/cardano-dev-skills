# Private Voting on Cardano — Detailed Design

Trustless anonymous voting using zero-knowledge proofs on Cardano's UTXO model.

## Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [How ZK Voting Works](#how-zk-voting-works)
- [The Nullifier — Preventing Double Votes](#the-nullifier--preventing-double-votes)
- [The ZK Circuit](#the-zk-circuit)
- [On-Chain Design: Cardano UTXO Patterns](#on-chain-design-cardano-utxo-patterns)
  - [Approach 1: Single UTXO Registry](#approach-1-single-utxo-registry)
  - [Approach 2: Token Per Nullifier](#approach-2-token-per-nullifier)
  - [Approach 3: Merkle Root On-Chain](#approach-3-merkle-root-on-chain)
  - [Approach 4: Sorted Linked List (Recommended)](#approach-4-sorted-linked-list-recommended)
- [Smart Contract Code (Julc)](#smart-contract-code-julc)
- [Full Transaction Flow](#full-transaction-flow)
- [Concurrency Analysis](#concurrency-analysis)
- [Approach Comparison](#approach-comparison)
- [Cost Analysis](#cost-analysis)
- [CircuitSpec Implementation](#circuitspec-implementation)
- [End-to-End Architecture](#end-to-end-architecture)
- [Alternative Approaches](#alternative-approaches)
  - [Batch ZK Rollup (Best for Large Elections)](#batch-zk-rollup-best-for-large-elections)
  - [Hydra L2 Voting (Best for Speed)](#hydra-l2-voting-best-for-speed)
  - [MACI — Anti-Collusion (Strongest Privacy)](#maci--anti-collusion-strongest-privacy)
- [Which Approach Is Best?](#which-approach-is-best)
- [Recommendation](#recommendation)

---

## Overview

A DAO wants to hold a governance vote. Requirements:
- Each eligible member votes exactly **once**
- Nobody can see **how** anyone voted
- The final tally is **verifiable** by anyone
- No **trusted third party** — fully on-chain

Zero-knowledge proofs make all of this possible on Cardano.

## The Problem

On-chain voting today is public. Every vote is visible:

```
Tx 1: addr_alice → voting_contract (vote: YES)    ← everyone sees Alice voted YES
Tx 2: addr_bob   → voting_contract (vote: NO)     ← everyone sees Bob voted NO
```

This enables:
- **Vote buying** — "Pay me 100 ADA and I'll prove I voted YES"
- **Social pressure** — peers and employers see your vote
- **Whale intimidation** — large holders pressure smaller voters
- **Strategic voting** — wait to see how others voted, then decide

## How ZK Voting Works

With ZK proofs, the voter proves their vote is valid without revealing it:

```
Tx 1: addr_??? → voting_contract
      proof: "I'm an eligible voter AND my vote is 0 or 1"
      public: nullifier=0xABC, commitment=0x789

      Nobody knows: who voted, what they voted, which address they used
```

### What Each Party Sees

| Data | Voter | Smart Contract | Public |
|------|-------|---------------|--------|
| Vote (YES/NO) | Yes | No | No |
| Voter identity | Yes | No | No |
| Secret key | Yes | No | No |
| Nullifier | Yes | Yes | Yes |
| Commitment | Yes | Yes | Yes |
| "Vote is valid" | Yes | Yes | Yes |

## The Nullifier — Preventing Double Votes

The nullifier is the core anti-double-vote mechanism.

### How It's Computed

```
nullifier = Poseidon(secretKey, electionId)
```

- `secretKey` — only the voter knows this (never revealed)
- `electionId` — public (e.g., "proposal-42")
- `Poseidon` — deterministic hash (same inputs always give same output)

### Why It Prevents Double Voting

**Same person, same election → always produces the same nullifier:**

```
Alice's secret key = 12345
Election ID = "proposal-42"

Vote 1: nullifier = Poseidon(12345, "proposal-42") = 0xABC
Vote 2: nullifier = Poseidon(12345, "proposal-42") = 0xABC  ← identical!

Smart contract sees 0xABC twice → REJECTS second vote.
```

**Why Alice can't use a different key:**

The ZK circuit simultaneously proves:
1. `nullifier = Poseidon(secretKey, electionId)` — ties nullifier to identity
2. `publicKey = derive(secretKey)` — ties secret key to public key
3. `publicKey ∈ voterMerkleTree` — proves eligibility

If Alice uses a different secret key → step 3 fails (not in voter list).
If Alice uses the same secret key → step 1 produces the same nullifier → rejected.

**Why nobody can de-anonymize the nullifier:**

Poseidon is a one-way hash. Given `0xABC`, you can't reverse it to find `secretKey = 12345`. The secret key never appears on-chain.

**Different elections produce different nullifiers:**

```
Alice, proposal-42: Poseidon(12345, "proposal-42") = 0xABC
Alice, proposal-43: Poseidon(12345, "proposal-43") = 0x999  ← different!
```

So Alice's votes across elections can't be linked.

## The ZK Circuit

The circuit proves all of the following simultaneously, without revealing any secret inputs:

```java
public class PrivateVoteCircuit implements CircuitSpec {
    private final int treeDepth;

    public PrivateVoteCircuit(int treeDepth) { this.treeDepth = treeDepth; }

    @Override
    public void define(SignalBuilder c) {
        // Secret inputs — only the voter knows these
        Signal vote       = c.privateInput("vote");
        Signal secretKey  = c.privateInput("secretKey");

        // Merkle proof of membership (secret — hides which voter)
        Signal[] siblings = new Signal[treeDepth];
        Signal[] pathBits = new Signal[treeDepth];
        for (int i = 0; i < treeDepth; i++) {
            siblings[i] = c.privateInput("sibling_" + i);
            pathBits[i] = c.privateInput("pathBit_" + i);
        }

        // Public inputs — visible to everyone
        Signal electionId = c.publicInput("electionId");
        Signal voterRoot  = c.publicInput("voterRoot");

        // Public outputs — the only things that appear on-chain
        Signal nullifier  = c.publicOutput("nullifier");
        Signal commitment = c.publicOutput("commitment");

        // === Constraints ===

        // 1. Vote must be 0 or 1
        vote.assertBoolean();

        // 2. Nullifier = Poseidon(secretKey, electionId)
        //    Deterministic: same voter + same election = same nullifier
        c.assertEqual(SignalPoseidon.hash(c, secretKey, c.signal("electionId")),
                       nullifier);

        // 3. Commitment = Poseidon(vote, nullifier)
        //    Binds the vote to the nullifier (for tally verification)
        c.assertEqual(SignalPoseidon.hash(c, vote, nullifier), commitment);

        // 4. Voter is in the eligible voter Merkle tree
        //    Proves: derive(secretKey) is a leaf in the tree with root = voterRoot
        Signal publicKey = SignalPoseidon.hash(c, secretKey, c.constant(0));
        SignalMerkle.verifyProof(c, publicKey, c.signal("voterRoot"),
                siblings, pathBits, SignalPoseidon::hash);
    }

    public static CircuitBuilder build(int treeDepth) {
        var builder = CircuitBuilder.create("private-vote")
                .publicVar("electionId")
                .publicVar("voterRoot")
                .publicVar("nullifier")
                .publicVar("commitment")
                .secretVar("vote")
                .secretVar("secretKey");

        for (int i = 0; i < treeDepth; i++) {
            builder = builder.secretVar("sibling_" + i).secretVar("pathBit_" + i);
        }
        return builder.defineSignals(new PrivateVoteCircuit(treeDepth));
    }
}
```

**Estimated constraints** (tree depth 14 = 16,384 eligible voters):

| Component | Constraints |
|-----------|------------|
| Boolean check (vote ∈ {0,1}) | 1 |
| Nullifier hash (Poseidon) | ~330 |
| Commitment hash (Poseidon) | ~330 |
| Public key derivation (Poseidon) | ~330 |
| Merkle proof (14 levels × Poseidon) | ~4,620 |
| **Total** | **~5,611** |

## On-Chain Design: Cardano UTXO Patterns

The ZK circuit is the same regardless of the on-chain pattern. The difference is **how the smart contract stores and checks nullifiers**.

### Approach 1: Single UTXO Registry

Store all nullifiers in one UTXO's datum.

```
Registry UTXO:
  Datum: { nullifiers: [0xABC, 0xDEF, 0x123, ...], yesCount: 5, noCount: 3 }
```

Each vote consumes the UTXO and produces a new one with the updated list.

| Pros | Cons |
|------|------|
| Simple | Sequential — one vote at a time |
| No off-chain components | UTXO hits 16KB limit at ~60-80 nullifiers |
| Trustless | High contention |

**Verdict**: Only works for tiny elections (<60 voters).

### Approach 2: Token Per Nullifier

Mint one token per nullifier. Token name = nullifier hash.

```
Each vote mints: (electionPolicy, 0xABC) → 1 token
Stored at script address as individual UTXOs
```

| Pros | Cons |
|------|------|
| No single shared UTXO | Still needs a check for existing tokens |
| Parallel minting possible | Can't natively prevent duplicate token names |
| | Checking existing tokens requires reading many UTXOs |

**Verdict**: Requires additional state management to prevent duplicates.

### Approach 3: Merkle Root On-Chain

Store only the Merkle root of all nullifiers. Tree lives off-chain.

```
Registry UTXO:
  Datum: { nullifierRoot: 0x5678..., count: 5000 }   ← constant ~100 bytes
```

Each vote proves (in ZK) that the nullifier was correctly inserted into the tree.

| Pros | Cons |
|------|------|
| Constant on-chain size | **Requires off-chain Merkle tree service** |
| Scales to millions | Two ZK proofs per vote (vote + insertion) |
| Cheap on-chain | Off-chain component can censor (mitigatable) |

**Verdict**: Scalable and cheap, but requires off-chain infrastructure. The off-chain component can't forge or change votes — it can only censor (and voters can go around it by rebuilding the tree from chain data).

### Approach 4: Sorted Linked List (Recommended)

Each nullifier is its own UTXO, linked in sorted order. Insertion proves non-existence by finding the correct position.

```
HEAD(0x00) → node(0x3A) → node(0x5C) → node(0x8F) → TAIL(0xFF)
                 ↑
            Insert 0x4B here: 0x3A < 0x4B < 0x5C (proves 0x4B doesn't exist)
```

| Pros | Cons |
|------|------|
| **Fully trustless** — no off-chain components | ~1.5 ADA locked per vote |
| **Natural concurrency** — different votes touch different UTXOs | Need to scan UTXOs to find insertion point |
| Only 1 ZK proof per vote (no Merkle insertion proof) | ADA cost grows linearly |
| Non-membership proven by sorted order | |
| Scales to any size | |

**Verdict**: Best balance of trustlessness, concurrency, and simplicity. The ADA locked per vote is reclaimable after the election.

## Smart Contract Code (Julc)

Two scripts work together:

### Minting Policy — Validates ZK Proof

```java
import org.zeroj.onchain.julc.groth16.lib.Groth16BLS12381Lib;

@MintingValidator
public class VoteMintingPolicy {

    @Param static byte[] vkAlpha;
    @Param static byte[] vkBeta;
    @Param static byte[] vkGamma;
    @Param static byte[] vkDelta;
    @Param static PlutusData vkIc;

    record VoteProof(
        byte[] piA, byte[] piB, byte[] piC,
        byte[] nullifier
    ) {}

    @Entrypoint
    static boolean validate(VoteProof redeemer, PlutusData ctx) {
        // 1. Groth16 BLS12-381 pairing check
        boolean proofValid = Groth16BLS12381Lib.verify(publicInputs,
            redeemer.piA(), redeemer.piB(), redeemer.piC(),
            vkAlpha, vkBeta, vkGamma, vkDelta, vkIc);

        // 2. Minted token name must equal the nullifier
        byte[] ownPolicy = getOwnPolicyId(ctx);
        boolean nameCorrect = checkMintedTokenName(ctx, ownPolicy, redeemer.nullifier());

        // 3. Exactly 1 token minted
        boolean exactlyOne = checkMintedAmount(ctx, ownPolicy, redeemer.nullifier(), 1);

        return proofValid && nameCorrect && exactlyOne;
    }
}
```

### Spending Validator — Sorted Linked List Registry

```java
@SpendingValidator
public class NullifierRegistry {

    @Param static byte[] votingPolicyId;

    record NodeDatum(
        byte[] nullifier,   // this node's value
        byte[] next         // next nullifier in sorted order
    ) {}

    @Entrypoint
    static boolean validate(NodeDatum datum, PlutusData redeemer, PlutusData ctx) {
        byte[] myNullifier = datum.nullifier();
        byte[] myNext = datum.next();
        byte[] newNullifier = extractNewNullifier(redeemer);

        // 1. Sorted insertion: myNullifier < newNullifier < myNext
        boolean sorted = byteArrayLessThan(myNullifier, newNullifier)
                      && byteArrayLessThan(newNullifier, myNext);

        // 2. This node updated: { nullifier: same, next: newNullifier }
        NodeDatum updatedMe = getOutputDatum(ctx, 0);
        boolean meUpdated =
            byteArrayEquals(updatedMe.nullifier(), myNullifier) &&
            byteArrayEquals(updatedMe.next(), newNullifier);

        // 3. New node created: { nullifier: newNullifier, next: myOldNext }
        NodeDatum newNode = getOutputDatum(ctx, 1);
        boolean newCorrect =
            byteArrayEquals(newNode.nullifier(), newNullifier) &&
            byteArrayEquals(newNode.next(), myNext);

        // 4. Both outputs at this script address
        boolean sameScript = outputsAtOwnAddress(ctx);

        // 5. Nullifier token was minted (minting policy validated the ZK proof)
        boolean tokenMinted = checkMint(ctx, votingPolicyId, newNullifier);

        return sorted && meUpdated && newCorrect && sameScript && tokenMinted;
    }
}
```

## Full Transaction Flow

### Setup (once per election)

```
Transaction: Create sentinel nodes

  Outputs:
    UTXO 1: { nullifier: 0x00...00, next: 0xFF...FF }  (HEAD)
    UTXO 2: { nullifier: 0xFF...FF, next: (none) }      (TAIL)

  State:
    HEAD(0x00) ───▶ TAIL(0xFF)
```

### Alice Votes

```
Transaction:
  Inputs:
    - Alice's wallet (for fees + new UTXO ADA)
    - HEAD node { null: 0x00, next: 0xFF }

  Mint: 1 token (votingPolicy, name: 0x5C)
        Minting policy runs → validates ZK proof ✓

  Outputs:
    - Updated HEAD { null: 0x00, next: 0x5C }
    - New node     { null: 0x5C, next: 0xFF }

  Registry validator checks:
    ✓ 0x00 < 0x5C < 0xFF (sorted)
    ✓ HEAD updated correctly
    ✓ New node points to old next
    ✓ Token minted

  State:
    HEAD(0x00) ───▶ node(0x5C) ───▶ TAIL(0xFF)
```

### Bob Votes (can be parallel with Alice if different insertion points)

```
  State after both:
    HEAD(0x00) ───▶ node(0x3A) ───▶ node(0x5C) ───▶ TAIL(0xFF)
```

### Alice Tries Again — REJECTED

```
  Alice's nullifier is still 0x5C (deterministic).
  Scan list: 0x00 → 0x3A → 0x5C → 0xFF
  0x5C already exists as a node!
  No valid (prev, next) pair where prev < 0x5C < next.
  Transaction cannot be constructed → double vote impossible.
```

## Concurrency Analysis

Different voters naturally touch different nodes:

```
Voter A (null: 0x11) → insert after HEAD      → touches HEAD
Voter B (null: 0x77) → insert after 0x5C node → touches 0x5C node
                                                 (no contention!)
```

Contention probability decreases as the list grows:

| List Size | Probability of Collision (2 simultaneous voters) |
|-----------|--------------------------------------------------|
| 2 (empty, just sentinels) | 100% (both insert after HEAD) |
| 10 | ~10% |
| 100 | ~1% |
| 1,000 | ~0.1% |

For large elections, contention is negligible.

## Approach Comparison

| | Single UTXO | Tokens | Merkle Root | **Sorted Linked List** |
|---|---|---|---|---|
| **Trust** | Trustless | Trustless | Needs indexer | **Trustless** |
| **Concurrency** | None | Limited | Low | **Natural** |
| **Off-chain** | None | None | Merkle service | **None** |
| **ZK proofs per vote** | 1 | 1 | 2 | **1** |
| **Max voters** | ~60 | ~60 | Unlimited | **Unlimited** |
| **UTXO scalability** | Hits 16KB | Hits 16KB | Constant | 1 per vote |
| **ADA cost** | ~2 ADA total | Grows fast | ~2 ADA total | ~1.5 ADA/vote |
| **Complexity** | Simple | Medium | High | Medium |

## Cost Analysis

| Voters | UTXOs | ADA Locked | Reclaimable After Election? |
|--------|-------|-----------|---------------------------|
| 100 | 102 | ~153 ADA | Yes |
| 1,000 | 1,002 | ~1,503 ADA | Yes |
| 10,000 | 10,002 | ~15,003 ADA | Yes |

Each node locks ~1.5 ADA (Cardano minimum UTXO). After the election ends, a cleanup transaction can burn the nullifier tokens and reclaim all ADA back to the DAO treasury.

## CircuitSpec Implementation

The vote circuit is built with ZeroJ's `CircuitSpec` DSL and proven with the pure Java BLS12-381 prover:

```java
// 1. Build circuit (parameterized by tree depth)
var circuit = PrivateVoteCircuit.build(14);  // depth 14 = 16K voters

// 2. Compile
var r1cs = circuit.compileR1CS(CurveId.BLS12_381);
// ~5,600 constraints

// 3. Trusted setup (dev: Java with -Dzeroj.allowInsecureTrustedSetup=true,
//    prod: MPC ceremony)
var srs = PowersOfTauBLS381.generate(13);
var setup = Groth16SetupBLS381.setup(constraints, numWires, numPublic, srs.tauScalar());

// 4. Witness (voter fills in their secret data)
var witness = circuit.calculateWitness(Map.of(
    "vote", List.of(BigInteger.ONE),           // YES
    "secretKey", List.of(mySecretKey),
    "electionId", List.of(electionId),
    "voterRoot", List.of(voterMerkleRoot),
    "nullifier", List.of(myNullifier),
    "commitment", List.of(myCommitment),
    "sibling_0", List.of(siblings[0]),
    // ... remaining siblings and path bits
), CurveId.BLS12_381);

// 5. PROVE (pure Java, zero native deps)
var proof = Groth16ProverBLS381.prove(setup.provingKey(), witness, constraints, numWires);

// 6. Compress for on-chain
var compressed = ProverToCardano.compressProof(proof);
// compressed.piA() = 48 bytes, piB() = 96 bytes, piC() = 48 bytes
```

## End-to-End Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  ELECTION SETUP (DAO admin, one-time)                                │
│                                                                      │
│  1. Collect eligible voter public keys                               │
│  2. Build voter Merkle tree → voterRoot                              │
│  3. Compile PrivateVoteCircuit → R1CS                                │
│  4. Trusted setup (MPC ceremony for production)                      │
│  5. Deploy VoteMintingPolicy (VK baked in)                           │
│  6. Deploy NullifierRegistry                                         │
│  7. Create sentinel UTXOs (HEAD, TAIL)                               │
│  8. Publish: voterRoot, electionId, script addresses                 │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  VOTING PHASE (each voter, independently)                            │
│                                                                      │
│  1. Voter computes:                                                  │
│     - nullifier = Poseidon(secretKey, electionId)                    │
│     - commitment = Poseidon(vote, nullifier)                         │
│     - Merkle proof (siblings + path bits for their leaf)             │
│                                                                      │
│  2. Voter generates ZK proof (pure Java, on their device)            │
│     → ~192 bytes proof                                               │
│                                                                      │
│  3. Voter scans linked list UTXOs at registry address                │
│     → finds insertion point (prev.nullifier < myNullifier < prev.next)│
│                                                                      │
│  4. Voter builds + submits transaction:                              │
│     - Consume predecessor node                                       │
│     - Mint nullifier token (triggers ZK proof verification)          │
│     - Produce updated predecessor + new node                         │
│                                                                      │
│  5. Cardano validates:                                               │
│     - Minting policy: ZK proof valid (BLS12-381 pairing) ✓          │
│     - Registry: sorted insertion correct ✓                           │
│     - Nullifier is new (not already in list) ✓                       │
│                                                                      │
│  Transaction succeeds → vote recorded. Identity hidden.              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  TALLY PHASE (anyone can verify)                                     │
│                                                                      │
│  1. Read all nullifier nodes from chain                              │
│  2. Each commitment is public → tally YES/NO from commitments        │
│  3. Result is verifiable by anyone                                   │
│  4. Cleanup: burn tokens, reclaim ADA to treasury                    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Security Properties

| Property | How It's Enforced |
|----------|------------------|
| **One vote per person** | Nullifier is deterministic (same key + election = same hash) |
| **Can't fake identity** | Merkle proof ties secret key to voter list |
| **Vote is private** | Nullifier reveals nothing about YES/NO |
| **Votes unlinkable across elections** | Different electionId → different nullifier |
| **No trusted third party** | Sorted linked list is fully on-chain |
| **Censorship resistant** | Voters submit directly to Cardano |
| **Verifiable tally** | Commitments are public, anyone can count |
| **ADA reclaimable** | Cleanup after election returns all locked ADA |

## Alternative Approaches

The sorted linked list is the best **trustless on-chain** solution. But depending on your priorities — cost, speed, or anti-collusion — other architectures may be more appropriate.

Every voting design sits on a tradeoff spectrum:

```
Fully On-Chain                                         Fully Off-Chain
(trustless, expensive)                                 (cheap, needs trust)
     │                                                        │
     ├── Sorted Linked List                                   │
     │   (1.5 ADA/vote, no trust)                             │
     │                                                        │
     │         ├── Merkle Root On-Chain                        │
     │         │   (~2 ADA total, indexer needed)              │
     │         │                                               │
     │         │              ├── Batch ZK Rollup              │
     │         │              │   (1 tx total, operator trust) │
     │         │              │                                │
     │         │              │              ├── Hydra L2      │
     │         │              │              │   (free, committee trust)
```

### Batch ZK Rollup (Best for Large Elections)

Instead of recording each vote on-chain, an operator collects ALL votes off-chain and produces **one ZK proof** that the entire tally is correct.

```
10,000 voters submit proofs off-chain
              │
              ▼
     ┌─────────────────┐
     │  Tally Operator   │
     │                   │
     │  Collects votes,  │
     │  checks nullifiers│
     │  (all off-chain)  │
     │                   │
     │  Generates ONE    │
     │  ZK proof:        │
     │  "5,847 YES,      │
     │   4,153 NO,       │
     │   no duplicates,  │
     │   all voters      │
     │   eligible"       │
     └────────┬──────────┘
              │
              ▼
     ONE Cardano transaction:
       Proof: 192 bytes
       Datum: { yes: 5847, no: 4153, nullifierRoot: 0x... }
       Cost: ~0.3 ADA total (regardless of voter count)
```

**How it works**: The operator proves a recursive/aggregated statement:

- For each vote i: `vote_i ∈ {0, 1}`, voter is eligible (Merkle proof), nullifier is unique
- `yesCount = count(vote_i == 1)` and `noCount = count(vote_i == 0)`
- `nullifierRoot = MerkleRoot(all nullifiers)`

**What the operator CAN'T do**:
- Can't forge votes (doesn't know anyone's secret key)
- Can't change votes (ZK proof binds vote to commitment)
- Can't break privacy (votes are encrypted/hidden in the proof)

**What the operator CAN do**:
- Censor specific voters (refuse to include their vote)

**Mitigation**: Multiple competing operators, or fallback to direct L1 submission.

| | Sorted Linked List | Batch ZK Rollup |
|---|---|---|
| **On-chain cost** | ~1.5 ADA per vote | **~0.3 ADA total** |
| **Transactions** | 1 per vote | **1 total** |
| **Trust** | **Trustless** | Operator can censor (not forge) |
| **Liveness** | Real-time | Batched (wait for operator) |
| **Best for** | Trustless DAOs | **Large elections (1000+ voters)** |

### Hydra L2 Voting (Best for Speed)

Process all votes inside a Hydra head (Cardano L2). Only the final result hits L1.

```
┌──────────────────────────────────────────────┐
│  Hydra Head (L2)                              │
│                                               │
│  Participants: Election Committee (3-of-5)    │
│                                               │
│  Inside Hydra:                                │
│    - Instant finality (<1 second)             │
│    - Zero fees                                │
│    - Full Plutus V3 support                   │
│    - Sorted linked list works perfectly       │
│      (no contention — sequential processing)  │
│                                               │
│  Each vote: submit ZK proof → validate → done │
│  Time: <1 second. Cost: 0 ADA.               │
│                                               │
└──────────────────────┬───────────────────────┘
                       │ Close Hydra head
                       ▼
              L1 Settlement:
                ONE transaction with final state
                { yes: 5847, no: 4153 }
                Cost: ~0.5 ADA
```

**The key advantage**: Inside the Hydra head, the sorted linked list works perfectly with zero contention (sequential processing) and zero cost. All the UTXO contention problems disappear because Hydra processes transactions sequentially within the head.

| | Sorted Linked List (L1) | Hydra L2 |
|---|---|---|
| **Cost per vote** | ~1.5 ADA | **0 ADA** |
| **Latency** | ~20 seconds | **<1 second** |
| **Contention** | Low | **None** |
| **Trust** | **Trustless** | Committee (m-of-n) must be online |
| **Best for** | Any DAO | **Speed-critical, committee-governed DAOs** |

### MACI — Anti-Collusion (Strongest Privacy)

MACI (Minimum Anti-Collusion Infrastructure) solves a problem the other approaches don't: **vote buying**.

**The problem with standard ZK voting**: Even with ZK proofs, a voter can **prove to a briber how they voted** by sharing their proof inputs before submitting:

```
Briber: "Vote YES and show me proof. I'll pay you 100 ADA."
Voter: Votes YES, shows the briber the inputs.
Briber: Verifies and pays.
```

**How MACI fixes this**: MACI adds an encrypted key-change mechanism. After voting, a voter can **secretly change their vote** — and there's no way to prove they didn't.

```
Round 1: Alice votes YES (encrypted with coordinator's key)
Round 2: Alice secretly changes to NO (new encrypted message)
         Alice CANNOT prove to briber that she didn't change it.

Briber: "Prove you voted YES"
Alice: Shows round 1 proof (YES)
Briber: Can't tell Alice secretly changed to NO.
Alice: Actually voted NO. Briber got scammed.
```

The coordinator (who has the decryption key) processes all votes and produces a ZK proof of the **final tally** without revealing individual votes or key changes.

**The tradeoff**: The coordinator can **see individual votes** (but can't change them). Public privacy is maintained — only the coordinator sees decrypted votes.

| | Sorted Linked List | MACI |
|---|---|---|
| **Vote buying resistance** | No — voter can prove their vote to briber | **Yes — voter can secretly change** |
| **Trust** | **Trustless** | Coordinator sees votes (can't change them) |
| **Privacy from public** | **Full** | **Full** |
| **Privacy from coordinator** | N/A | No (coordinator decrypts) |
| **Complexity** | Medium | High |
| **Best for** | Standard DAO governance | **High-stakes votes where buying is a threat** |

## Which Approach Is Best?

| Priority | Best Approach | Why |
|----------|--------------|-----|
| **Zero trust, any size** | Sorted Linked List | No off-chain components, fully on-chain |
| **Minimum cost** | Batch ZK Rollup | One transaction regardless of voter count |
| **Maximum speed** | Hydra L2 | Sub-second finality, zero fees |
| **Anti vote-buying** | MACI | Only design that prevents proving how you voted |
| **Simplicity** | Sorted Linked List | Easiest to implement and audit |
| **Small DAO (<100)** | Single UTXO | Simplest, fits in one datum |

### All Approaches Compared

| | Single UTXO | Merkle Root | **Sorted List** | Batch Rollup | Hydra L2 | MACI |
|---|---|---|---|---|---|---|
| **Trust** | Trustless | Indexer | **Trustless** | Operator | Committee | Coordinator |
| **Max voters** | ~60 | Unlimited | **Unlimited** | Unlimited | Unlimited | Unlimited |
| **Cost/vote** | 0 ADA | 0 ADA | **1.5 ADA** | ~0 ADA | 0 ADA | ~0 ADA |
| **Concurrency** | None | Low | **Natural** | N/A | None needed | N/A |
| **Anti-bribery** | No | No | No | No | No | **Yes** |
| **Off-chain** | None | Tree service | **None** | Operator | Committee | Coordinator |
| **Complexity** | Low | High | **Medium** | High | Medium | Very high |

## Recommendation

For **most Cardano DAOs today**:

1. **Start with sorted linked list.** It's trustless, simple to audit, and works out of the box with the ZeroJ pure Java prover. The 1.5 ADA per vote cost is acceptable for DAOs with treasury, and the ADA is reclaimable after the election.

2. **Graduate to batch ZK rollup** when voter count exceeds 5,000+, or when ADA cost becomes a concern. This requires building an aggregation circuit and running an operator, but reduces on-chain cost to near zero.

3. **Consider MACI** only if vote buying is a concrete threat (large treasury votes, political elections). It's significantly more complex to implement.

4. **Consider Hydra** when it matures further and your DAO already runs committee-based infrastructure.

**The key insight**: The ZK circuit is the same for all approaches. Only the on-chain pattern changes. You can start with the linked list and migrate to batch rollup later **without rewriting the circuit**.

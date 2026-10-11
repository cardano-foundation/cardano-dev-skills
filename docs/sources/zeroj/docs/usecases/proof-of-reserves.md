# Proof of Reserves on Cardano — Detailed Design

Prove solvency without revealing individual account balances.

## Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [Use Cases](#use-cases)
- [How ZK Proof of Reserves Works](#how-zk-proof-of-reserves-works)
- [The Merkle Sum Tree](#the-merkle-sum-tree)
- [ZK-Provable Claims](#zk-provable-claims)
- [Four Approaches](#four-approaches)
  - [Approach 1: Simple Sum Proof (Single Prover)](#approach-1-simple-sum-proof-single-prover)
  - [Approach 2: Merkle Sum Tree (User-Verifiable)](#approach-2-merkle-sum-tree-user-verifiable)
  - [Approach 3: On-Chain UTXO Summation (Cardano-Native)](#approach-3-on-chain-utxo-summation-cardano-native)
  - [Approach 4: Recursive Proof Aggregation (Maximum Privacy)](#approach-4-recursive-proof-aggregation-maximum-privacy)
- [Individual Account Inclusion Proof](#individual-account-inclusion-proof)
- [Cardano-Specific Design](#cardano-specific-design)
  - [Stake Pool Pledge Verification](#stake-pool-pledge-verification)
  - [Stablecoin Reserve Proof](#stablecoin-reserve-proof)
  - [DeFi Protocol Solvency](#defi-protocol-solvency)
  - [Bridge Reserve Verification](#bridge-reserve-verification)
- [Smart Contract Code (Julc)](#smart-contract-code-julc)
- [ZK Circuits (CircuitSpec)](#zk-circuits-circuitspec)
- [Full Transaction Flow](#full-transaction-flow)
- [UTXO Contention Analysis](#utxo-contention-analysis)
- [Cost Analysis](#cost-analysis)
- [Approach Comparison](#approach-comparison)
- [Security Considerations](#security-considerations)
- [Architecture Recommendation](#architecture-recommendation)

---

## Overview

After exchange collapses (FTX, Mt. Gox), users want cryptographic proof that custodians actually hold the funds they claim. But publishing all account balances destroys user privacy. Zero-knowledge proofs enable **solvency verification without revealing any individual account**.

```
Without ZK:
  Exchange: "We have $10B in reserves. Here's a public audit report."
  User: "How do I know my $5,000 is included? And I don't want others seeing my balance."

With ZK:
  Exchange: "Here's a ZK proof: total reserves >= total liabilities."
  User: "Here's my personal inclusion proof: my $5,000 IS in the liability tree."
  Public: Verified ✓. Nobody sees any individual balance.
```

## The Problem

### Why Trust Breaks Down

```
What custodians claim:          What might be true:
─────────────────────           ─────────────────────
"Total reserves: $10B"           Actually: $3B (rest lent to hedge fund)
"All funds fully backed"         Actually: 70% backed, 30% IOUs
"Your balance is safe"           Actually: commingled with operating funds
```

### Current Solutions and Their Flaws

| Solution | How It Works | Flaw |
|----------|-------------|------|
| **Auditor report** | Big 4 firm examines books quarterly | Auditor sees snapshot; fraud happens between audits |
| **Public balance sheet** | Exchange publishes all addresses | Doesn't prove they control the keys; privacy violated |
| **Merkle proof (no ZK)** | Each user verifies inclusion | User can see neighboring balances; total may be falsified |
| **Proof of keys day** | Everyone withdraws simultaneously | Impractical; causes bank run; only tests one moment |

### What We Actually Need

1. **Total reserves >= total liabilities** (solvency)
2. **My account is included in the liabilities** (personal verification)
3. **No account has a negative balance** (no hidden debts)
4. **Nobody sees anyone else's balance** (privacy)
5. **Proof is fresh** (not from last month's snapshot)
6. **Automated and continuous** (not quarterly audits)

## Use Cases

### Crypto Exchanges and Custodians

```
Secret:  individual account balances [user1: 5000, user2: 12000, ...]
Secret:  reserve wallet addresses and individual holdings
Public:  total reserves >= total liabilities (boolean)
Public:  each user can verify their own inclusion (personal proof)
```

### Stablecoins (DJED, iUSD)

```
Secret:  reserve composition (which assets, how much of each)
Secret:  collateralization ratio details
Public:  reserve_value >= circulating_supply * peg_price
Public:  collateralization >= minimum_ratio (e.g., >= 150%)
```

### Cardano Stake Pools

```
Secret:  pledge source addresses, timing of pledge movement
Public:  operator controls >= declared_pledge ADA
Public:  pledge hasn't been borrowed/rehypothecated
```

### DeFi Lending Protocols

```
Secret:  individual loan positions, collateral details
Secret:  liquidation thresholds per position
Public:  total_collateral >= total_outstanding_loans
Public:  no position is undercollateralized
```

### Wrapped Token Bridges

```
Secret:  reserve wallet addresses on source chain
Public:  locked_on_source_chain >= minted_on_cardano
Public:  1:1 backing verified for each wrapped token
```

### DAO Treasury

```
Secret:  multi-sig holder identities, spending authorization rules
Public:  treasury_balance >= committed_spending
Public:  funds are accessible (not locked in broken contracts)
```

## How ZK Proof of Reserves Works

### The Core Idea

The custodian builds a **Merkle sum tree** of all account balances. The root contains the total sum. A ZK proof proves:

1. The tree is correctly constructed (each parent = sum of children)
2. No leaf has a negative balance
3. The total (root sum) meets the solvency threshold

```
                    Root
                 sum = 50,000
                /              \
          Node A                Node B
        sum = 20,000          sum = 30,000
        /        \            /          \
    User 1    User 2     User 3      User 4
    5,000     15,000     12,000      18,000

ZK proves:
  ✓ 5,000 + 15,000 = 20,000 (Node A correct)
  ✓ 12,000 + 18,000 = 30,000 (Node B correct)
  ✓ 20,000 + 30,000 = 50,000 (Root correct)
  ✓ All leaves >= 0 (no negative balances)
  ✓ 50,000 = total liabilities (matches claimed total)
  ✓ reserves (separate proof) >= 50,000

Nobody sees: any individual balance. Only the total is verified.
```

## The Merkle Sum Tree

Unlike a standard Merkle tree (which only hashes data), a **Merkle sum tree** carries cumulative sums up the tree:

```
Standard Merkle Tree:
  Node = hash(left_hash, right_hash)
  Proves: data inclusion
  Doesn't prove: anything about values

Merkle Sum Tree:
  Node = { hash: hash(left_hash, right_hash, left_sum, right_sum),
           sum: left_sum + right_sum }
  Proves: data inclusion AND correct summation
  Key property: parent sum MUST equal children sums (enforced by hash)
```

### Why the Sum Property Matters

If the custodian tries to cheat by excluding a user:

```
Honest tree:
  User1: 5,000 + User2: 15,000 = Node: 20,000

Cheating (exclude User2):
  User1: 5,000 + FAKE: 0 = Node: 5,000
  But: Root sum drops from 50,000 to 35,000
  → Reserves might still be >= 35,000, but User2 checks their inclusion proof
  → User2's proof FAILS (they're not in the tree)
  → Fraud detected
```

If the custodian inflates a balance:

```
Honest: User1 has 5,000
Cheat: Claim User1 has 50,000 (inflate total to look more solvent)
But: User1 checks their inclusion proof
→ User1 sees their leaf says 50,000 (wrong!)
→ User1 reports discrepancy
→ Fraud detected
```

**The combination of ZK proof (total is correct) + individual inclusion proof (my balance is correct) makes fraud detectable.**

## ZK-Provable Claims

### Claim 1: Solvency (Reserves >= Liabilities)

```
Circuit: SolvencyProof

Secret inputs:  account_balances[N], reserve_amounts[M], reserve_signatures[M]
Public inputs:  liabilities_root (Merkle sum tree root), reserve_attestation_root
Public output:  is_solvent (YES/NO)

Circuit logic:
  1. Verify Merkle sum tree is correctly constructed
  2. Extract total_liabilities from root
  3. Verify reserve attestations (auditor signatures)
  4. Extract total_reserves from attestations
  5. Assert: total_reserves >= total_liabilities
  6. Assert: all account balances >= 0

Constraints: ~500 per account (Poseidon hash + sum check + range check)
For 1000 accounts: ~500,000 constraints (requires batching — see Approach 4)
```

### Claim 2: Individual Inclusion

```
Circuit: InclusionProof

Secret inputs:  my_balance, my_account_id, merkle_siblings[], merkle_path[]
Public inputs:  liabilities_root, my_commitment (hash of account_id + balance)
Public output:  is_included (YES/NO), my_balance_matches (YES/NO)

Circuit logic:
  1. Compute: leaf_hash = Poseidon(account_id, balance)
  2. Verify: Merkle path from leaf to root
  3. Verify: sum at each level is correct (sum tree property)
  4. Assert: computed root == liabilities_root

Constraints: ~330 per tree level (Poseidon) × depth
For depth 20 (1M accounts): ~6,600 constraints
```

### Claim 3: Non-Negative Balances

```
Circuit: NonNegativeProof

Secret inputs:  account_balances[N]
Public inputs:  liabilities_root
Public output:  all_non_negative (YES/NO)

Circuit logic:
  For each account:
    1. Assert: balance >= 0 (range check, 64-bit)
    2. Assert: balance is in the Merkle sum tree (inclusion)

  Combined with the sum tree verification, this ensures no hidden debts.

Constraints: ~64 per account (range check) + tree verification
```

## Four Approaches

### Approach 1: Simple Sum Proof (Single Prover)

The custodian proves `sum(all_balances) <= total_reserves` in a single ZK proof.

```
Custodian:
  1. Collect all account balances
  2. Sum them: total_liabilities = Σ balance_i
  3. Prove: total_reserves >= total_liabilities

ZK proof proves:
  - The sum was computed correctly
  - All balances are non-negative
  - Reserves cover the total
```

| Pros | Cons |
|------|------|
| Simplest circuit | **Users can't verify their own inclusion** |
| One proof covers everything | Must trust custodian included all accounts |
| ~500K constraints for 1000 accounts | Very large circuit for many accounts |
| | No individual accountability |

**Verdict**: Proves solvency but not completeness. Users must trust the custodian didn't omit accounts.

### Approach 2: Merkle Sum Tree (User-Verifiable)

The custodian builds a Merkle sum tree and publishes the root. Each user can independently verify their inclusion.

```
                    Root (published on-chain)
                 hash: 0xABC, sum: 50,000
                /                          \
          hash: 0x123                hash: 0x456
          sum: 20,000                sum: 30,000
         /          \               /          \
    User1          User2       User3         User4
    5,000         15,000      12,000        18,000

On-chain: Root { hash: 0xABC, sum: 50,000 }
ZK proof: "Reserves >= 50,000"

Each user independently:
  1. Receives their Merkle path from custodian
  2. Verifies: their balance is in the tree
  3. Verifies: sums are correct along the path
  4. If wrong → publicly challenge
```

**What each user sees**:

```
User1 receives:
  My leaf: { account: User1, balance: 5,000 }
  Sibling: { hash: 0x..., sum: 15,000 }  ← User2's hash (but NOT User2's identity or balance)
  Parent:  { hash: 0x123, sum: 20,000 }
  Sibling: { hash: 0x456, sum: 30,000 }  ← Right subtree hash
  Root:    { hash: 0xABC, sum: 50,000 }

User1 verifies:
  ✓ 5,000 + 15,000 = 20,000 (my level correct)
  ✓ 20,000 + 30,000 = 50,000 (root correct)
  ✓ My balance is 5,000 (matches my expectation)

User1 learns:
  ✓ My balance is included
  ✓ Total liabilities = 50,000
  ~ Sibling sum = 15,000 (knows there's one sibling with 15,000 total)
  ✗ Cannot identify User2 or their exact balance (if tree is deep enough)
```

**Privacy concern**: At each level, the user sees the sibling's sum. With a binary tree of 1000 users, each user sees ~10 sibling sums (one per level). This leaks some aggregate information.

| Pros | Cons |
|------|------|
| **Users verify their own inclusion** | Sibling sums partially leak (aggregate info) |
| Standard pattern (used by Binance, OKX) | Custodian must distribute paths to all users |
| Detects: excluded accounts, inflated balances | Large proof for complete tree verification |
| Well-studied (Vitalik's PoR proposal) | |

**Verdict**: Best balance of verifiability and practicality. Industry standard.

### Approach 3: On-Chain UTXO Summation (Cardano-Native)

Instead of a Merkle tree, use Cardano's native UTXO set as the "proof":

```
Reserve proof:
  "Here are our reserve wallet addresses. Check the UTXOs yourself."

Liability proof:
  "Here's the Merkle sum tree root of all liabilities."

Solvency:
  "sum(reserve UTXOs) >= merkle_sum_tree_root.total"
```

For **Cardano-native use cases** (stake pools, DeFi protocols), the reserves are already on-chain UTXOs. The challenge is only the liability side.

**Stake pool example**:

```
Pledge verification:
  Reserve: Query UTXO set for pool operator's declared addresses
  Liability: Declared pledge amount
  Proof: sum(UTXOs at operator addresses) >= declared_pledge

  This doesn't even need ZK — it's publicly verifiable!
  ZK adds: "These addresses belong to the operator" without revealing which addresses
```

| Pros | Cons |
|------|------|
| **Reserves are on-chain** (for Cardano-native assets) | Only works for on-chain reserves |
| No trusted auditor for reserve side | Liability side still needs Merkle tree |
| Real-time verification (query UTXO set) | Doesn't work for off-chain reserves (fiat, BTC, etc.) |
| | Address-balance linkage may leak info |

**Verdict**: Best for Cardano-native reserves (stake pools, DeFi). Not suitable for exchanges with fiat reserves.

### Approach 4: Recursive Proof Aggregation (Maximum Privacy)

For large custodians (millions of accounts), a single ZK proof is too large. Use recursive aggregation:

```
Layer 1: Prove batches of 100 accounts each
  Batch 1: accounts[0..99]    → proof_1 (sum: 500,000)
  Batch 2: accounts[100..199] → proof_2 (sum: 430,000)
  ...
  Batch 100: accounts[9900..9999] → proof_100 (sum: 620,000)

Layer 2: Prove the batch proofs are valid
  Aggregate proof: "proof_1 through proof_100 are all valid
                    AND sum(all batch sums) = total_liabilities
                    AND total_liabilities <= total_reserves"
  → Single final proof (192 bytes)
```

| Pros | Cons |
|------|------|
| **Scales to millions of accounts** | Most complex circuit design |
| **Maximum privacy** (no sibling sum leakage) | Requires recursive SNARK support |
| Single constant-size proof | Higher proving time (minutes for millions) |
| Parallelizable (batch proofs independent) | Requires sophisticated prover infrastructure |

**Verdict**: Future — when recursive SNARK tooling matures. Ideal for large exchanges.

## Individual Account Inclusion Proof

Regardless of which approach is used for the aggregate proof, each user needs to verify their own account is included:

```
User's verification (off-chain, on their device):

  1. User receives from custodian:
     - Their leaf: { account_id_hash, balance }
     - Merkle path: siblings and sums at each level

  2. User computes:
     - leaf_hash = Poseidon(my_account_id, my_balance)
     - Walk up the tree: verify each level's hash and sum
     - Reach the root: compare with published on-chain root

  3. User verifies:
     ✓ My leaf is in the tree (hash matches path)
     ✓ My balance is correct (matches my expectation)
     ✓ Sums are consistent at each level (no inflation)
     ✓ Root matches the on-chain published root

  If ANY check fails → user publicly challenges (fraud detected)
```

**ZK enhancement**: The user's verification itself can be a ZK proof, so they can prove "my account is included and correct" without revealing their balance to anyone:

```java
public class AccountInclusionCircuit implements CircuitSpec {
    private final int treeDepth;

    public AccountInclusionCircuit(int treeDepth) { this.treeDepth = treeDepth; }

    @Override
    public void define(SignalBuilder c) {
        // Secret (user's private data)
        Signal accountId = c.privateInput("accountId");
        Signal balance   = c.privateInput("balance");

        Signal[] siblings    = new Signal[treeDepth];
        Signal[] siblingSums = new Signal[treeDepth];
        Signal[] pathBits    = new Signal[treeDepth];
        for (int i = 0; i < treeDepth; i++) {
            siblings[i]    = c.privateInput("sibling_" + i);
            siblingSums[i] = c.privateInput("siblingSum_" + i);
            pathBits[i]    = c.privateInput("pathBit_" + i);
        }

        // Public (published on-chain)
        Signal root      = c.publicInput("root");
        Signal totalSum  = c.publicInput("totalSum");

        // Public output
        Signal isIncluded = c.publicOutput("isIncluded");

        // 1. Compute leaf hash
        Signal leafHash = SignalPoseidon.hash(c, accountId, balance);

        // 2. Walk up the tree, verifying hash AND sum at each level
        Signal currentHash = leafHash;
        Signal currentSum  = balance;

        for (int i = 0; i < treeDepth; i++) {
            pathBits[i].assertBoolean();

            // Left or right placement
            Signal leftHash  = pathBits[i].select(siblings[i], currentHash);
            Signal rightHash = pathBits[i].select(currentHash, siblings[i]);
            Signal leftSum   = pathBits[i].select(siblingSums[i], currentSum);
            Signal rightSum  = pathBits[i].select(currentSum, siblingSums[i]);

            // Parent hash includes both hashes AND both sums
            currentHash = PoseidonN.hash(c, leftHash, rightHash, leftSum, rightSum);
            currentSum  = leftSum.add(rightSum);
        }

        // 3. Root must match published root
        c.assertEqual(currentHash, root);
        c.assertEqual(currentSum, totalSum);

        // 4. Balance must be non-negative
        balance.assertInRange(64);

        c.assertEqual(isIncluded, c.constant(1));
    }
}
```

**Constraints**: ~1,500 per tree level (4-input Poseidon + sum + select). Depth 20 = ~30,000 constraints.

## Cardano-Specific Design

### Stake Pool Pledge Verification

Delegators can't easily verify that a pool operator's pledge is real and not temporarily borrowed.

```
Problem:
  Pool declares: "Pledge = 1,000,000 ADA"
  Reality: Operator borrowed 900,000 ADA, will return after snapshot

ZK Solution:
  Operator proves: "I have controlled >= 1,000,000 ADA for the past 10 epochs"
  Circuit checks: UTXO ownership over time (not just a snapshot)

Secret inputs:  wallet addresses, UTXO history for 10 epochs
Public inputs:  declared_pledge, current_epoch
Public output:  pledge_is_real (YES/NO)
```

**UTXO design**: No contention — each pool's proof is independent. Published as metadata on the pool registration certificate update transaction.

### Stablecoin Reserve Proof

```
DJED/iUSD proves: reserve_value >= circulating_supply * peg_price

Secret inputs:  reserve_composition (ADA, BTC, bonds, etc.), oracle_prices
Public inputs:  circulating_supply (from minting policy), minimum_ratio (150%)
Public output:  is_overcollateralized (YES/NO), ratio_category ("150-200%", "200%+")

On Cardano:
  Reserve UTXO: { root: merkle_sum_root, total_reserve_value: X, epoch: 42 }
  Published: every epoch by the stablecoin protocol
  Verified: by anyone reading the UTXO + checking the ZK proof
```

### DeFi Protocol Solvency

```
Lending protocol proves: total_collateral >= total_loans

Secret inputs:  loan_positions[N] (borrower, collateral, loan_amount)
Public inputs:  protocol_address, current_epoch
Public output:  is_solvent (YES/NO), health_factor_category (">1.5", "1.0-1.5")

Advantage on Cardano: collateral UTXOs are on-chain.
  Reserve side: sum(collateral UTXOs at protocol address) — publicly verifiable
  Liability side: ZK proof of total outstanding loans
```

### Bridge Reserve Verification

```
Bridge proves: locked_on_ethereum >= minted_on_cardano

Secret inputs:  ethereum_wallet_addresses, ethereum_balances (from oracle)
Public inputs:  total_minted_on_cardano (from minting policy), bridge_policy_id
Public output:  fully_backed (YES/NO)

Challenge: Ethereum balances are off-chain relative to Cardano.
Solution: Trusted oracle signs Ethereum balance attestation.
          ZK proof verifies: oracle_signature valid AND eth_balance >= cardano_minted
```

## Smart Contract Code (Julc)

### Reserve Proof Verifier

```java
@SpendingValidator
public class ReserveProofVerifier {

    @Param static byte[] vkAlpha;
    @Param static byte[] vkBeta;
    @Param static byte[] vkGamma;
    @Param static byte[] vkDelta;
    @Param static PlutusData vkIc;

    record ReserveProof(
        byte[] piA, byte[] piB, byte[] piC,
        BigInteger isSolvent
    ) {}

    @Entrypoint
    static boolean validate(PlutusData datum, ReserveProof proof, PlutusData ctx) {
        // 1. Verify Groth16 proof (BLS12-381 pairing)
        boolean proofValid = verifyGroth16(
            proof.piA(), proof.piB(), proof.piC(),
            proof.isSolvent());

        // 2. Must be solvent
        boolean solvent = proof.isSolvent().equals(BigInteger.ONE);

        // 3. (Optional) Check proof is recent — datum contains epoch
        //    Prevents replaying old proofs

        return proofValid && solvent;
    }
}
```

### Periodic Solvency Attestation

```java
@SpendingValidator
public class SolvencyAttestation {

    @Param static byte[] custodianPubKeyHash;
    @Param static byte[] proofVerifierHash;

    record AttestationDatum(
        byte[] liabilitiesRoot,    // Merkle sum tree root
        BigInteger totalLiabilities,
        BigInteger epoch,
        byte[] proofHash           // hash of the ZK proof
    ) {}

    @Entrypoint
    static boolean validate(AttestationDatum datum, PlutusData redeemer, PlutusData ctx) {
        // Only the custodian can update the attestation
        boolean authorizedSigner = checkSignedBy(ctx, custodianPubKeyHash);

        // New attestation must have a later epoch
        AttestationDatum newDatum = extractOutputDatum(ctx);
        boolean epochAdvanced = newDatum.epoch().compareTo(datum.epoch()) > 0;

        // Proof hash must be present (verified separately or via reference)
        boolean hasProof = newDatum.proofHash().length > 0;

        return authorizedSigner && epochAdvanced && hasProof;
    }
}
```

## Full Transaction Flow

### Setup

```
1. Custodian builds Merkle sum tree of all account balances
2. Generates ZK proof: "tree is correct AND reserves >= root sum"
3. Deploys SolvencyAttestation validator on Cardano
4. Creates initial attestation UTXO:
   Datum: { root: 0x..., total: 50000, epoch: 1, proofHash: 0x... }
```

### Periodic Update (Every Epoch)

```
Transaction:
  Input:  Attestation UTXO { root: OLD_ROOT, epoch: N }
  Output: Attestation UTXO { root: NEW_ROOT, epoch: N+1, proofHash: 0x... }

  Custodian:
    1. Rebuild Merkle sum tree with current balances
    2. Generate new ZK proof
    3. Update attestation UTXO

  Validator checks:
    ✓ Signed by custodian
    ✓ Epoch advanced
    ✓ Proof hash present
```

### User Verification (Off-Chain, Anytime)

```
User:
  1. Read attestation UTXO from chain (get root + total)
  2. Request Merkle path from custodian (for their account)
  3. Verify path locally:
     ✓ My leaf hash matches
     ✓ My balance is correct
     ✓ Sums are consistent up to root
     ✓ Root matches on-chain attestation
  4. If any check fails → publicly challenge
```

## UTXO Contention Analysis

**Minimal contention** — this is one of the simpler UTXO patterns:

| Component | Contention | Why |
|-----------|-----------|-----|
| Attestation UTXO (update) | **Very low** | Only custodian updates, once per epoch |
| User inclusion verification | **None** | Off-chain computation |
| Reserve UTXO query | **None** | Read-only (or reference input) |
| Challenge submission | **None** | Independent per user |

The attestation UTXO is updated once per epoch (~5 days on Cardano) by one party (the custodian). No concurrent writes. This is the simplest UTXO pattern of all our use cases.

## Cost Analysis

| Operation | Cost | Frequency | Who Pays |
|-----------|------|-----------|----------|
| Initial setup (deploy validators) | ~2 ADA | Once | Custodian |
| Epoch attestation update | ~0.5 ADA | Every 5 days | Custodian |
| ZK proof generation | Free (off-chain computation) | Every 5 days | Custodian |
| User inclusion verification | Free (off-chain) | On demand | User |
| Challenge transaction (if fraud) | ~0.5 ADA | Rare | Challenger |

**Annual cost**: ~37 ADA per year for continuous solvency attestation. Trivial.

## Approach Comparison

| | Simple Sum | **Merkle Sum Tree** | UTXO Summation | Recursive Aggregation |
|---|---|---|---|---|
| **User verifiable** | No | **Yes** | Partially | Yes |
| **Privacy** | High (total only) | **Medium** (sibling sums leak) | Low (addresses visible) | **High** (nothing leaked) |
| **Scalability** | 1000s of accounts | **Millions** | On-chain only | **Millions** |
| **Complexity** | Low | **Medium** | Low | High |
| **Off-chain reserves** | Yes | **Yes** | No | Yes |
| **Cardano-native** | Partial | **Yes** | Most native | Partial |
| **Proof size** | 192 bytes | **192 bytes + paths per user** | N/A | 192 bytes |
| **Best for** | Simple attestation | **Most use cases** | Stake pools, DeFi | Large exchanges |

## Security Considerations

### Cheating Strategies and Defenses

| Attack | How | Defense |
|--------|-----|---------|
| **Exclude accounts** | Remove user from Merkle tree | User checks inclusion → detects omission |
| **Inflate balances** | Claim user has more than they do | User checks balance → detects mismatch |
| **Negative balances** | Hidden debts reduce true liability | ZK circuit enforces all balances >= 0 |
| **Stale proof** | Submit old proof when currently insolvent | Epoch check on-chain — proof must be recent |
| **Borrowed reserves** | Temporarily borrow for snapshot | Time-weighted proof (prove reserves over N epochs) |
| **Double-counted reserves** | Count same reserves for two products | Nullifier per reserve address (each address counted once) |

### Collusion Resistance

```
Custodian + Auditor collude:
  Risk: Auditor signs false reserve attestation
  Defense: Multiple independent auditors, each signs separately
           ZK proof aggregates all signatures — all must agree

Custodian + Oracle collude (for bridges):
  Risk: Oracle reports false off-chain balance
  Defense: Multiple oracles with threshold (3-of-5 must agree)
           Dispute mechanism: any oracle can challenge
```

### Timing Attacks

```
Attack: Borrow reserves before snapshot, return after
Defense: Require proof of reserves at RANDOM times (not just epoch boundaries)
         Or: prove reserves were held for the ENTIRE epoch (time-weighted average)
```

## Architecture Recommendation

### For Most Use Cases: Merkle Sum Tree

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  CUSTODIAN (off-chain)                                          │
│                                                                 │
│  1. Build Merkle sum tree of all accounts                       │
│  2. Generate ZK proof: "tree correct AND reserves >= total"     │
│  3. Publish root + proof hash on Cardano (attestation UTXO)     │
│  4. Distribute inclusion paths to users                         │
│                                                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  CARDANO (on-chain)                                             │
│                                                                 │
│  Attestation UTXO:                                              │
│    { root: 0xABC, total: 50000, epoch: 42, proofHash: 0x... }  │
│                                                                 │
│  Updated every epoch by custodian.                              │
│  Readable by anyone. ~0.5 ADA per update.                       │
│                                                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  USERS (off-chain verification)                                 │
│                                                                 │
│  1. Read attestation UTXO (public)                              │
│  2. Get Merkle path from custodian                              │
│  3. Verify inclusion + balance + sums locally                   │
│  4. If fraud → submit challenge on-chain                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### For Cardano-Native (Stake Pools, DeFi)

Use UTXO summation for reserves (already on-chain) + Merkle sum tree for liabilities. Simplest possible design — no off-chain reserve attestation needed.

### For Maximum Privacy (Large Exchanges)

Use recursive proof aggregation — proves solvency for millions of accounts in a single 192-byte proof with zero information leakage. Requires more sophisticated prover infrastructure.

### The ZK Circuit Is the Same

All approaches use the same core circuit components:
- Poseidon hash for Merkle sum tree nodes
- Range checks for non-negative balances
- Sum verification at each tree level
- Groth16 BLS12-381 for proof generation

The ZeroJ pure Java prover handles all of these today. The circuit complexity scales with the number of accounts, but can be managed through batching and recursive aggregation.

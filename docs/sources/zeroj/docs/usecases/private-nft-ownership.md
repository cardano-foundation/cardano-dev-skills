# Private NFT Ownership on Cardano — Detailed Design

Prove you own an NFT without revealing your wallet address.

## Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [Use Cases](#use-cases)
  - [Token-Gated Events and Access](#token-gated-events-and-access)
  - [Anonymous DAO Participation](#anonymous-dao-participation)
  - [Anti-Sybil Airdrops](#anti-sybil-airdrops)
  - [NFT-Gated Content](#nft-gated-content)
  - [Whale Privacy](#whale-privacy)
  - [Anonymous Creator Verification](#anonymous-creator-verification)
  - [Cross-Platform Identity](#cross-platform-identity)
  - [Gaming Item Ownership](#gaming-item-ownership)
  - [Physical-Digital Twin (Warranty)](#physical-digital-twin-warranty)
  - [NFT-Backed Lending](#nft-backed-lending)
- [How ZK NFT Ownership Works](#how-zk-nft-ownership-works)
- [The Cardano UTXO Challenge](#the-cardano-utxo-challenge)
- [Four Approaches](#four-approaches)
  - [Approach 1: Ownership Merkle Tree (Off-Chain Snapshot)](#approach-1-ownership-merkle-tree-off-chain-snapshot)
  - [Approach 2: UTXO Commitment Registry (On-Chain)](#approach-2-utxo-commitment-registry-on-chain)
  - [Approach 3: Minting Policy with Built-In Privacy (Cardano-Native)](#approach-3-minting-policy-with-built-in-privacy-cardano-native)
  - [Approach 4: Shielded NFT Transfer (Maximum Privacy)](#approach-4-shielded-nft-transfer-maximum-privacy)
- [Nullifier: One-Time Use Tokens](#nullifier-one-time-use-tokens)
- [ZK Circuits (CircuitSpec)](#zk-circuits-circuitspec)
- [Smart Contract Code (Julc)](#smart-contract-code-julc)
- [Full Transaction Flow](#full-transaction-flow)
- [UTXO Contention Analysis](#utxo-contention-analysis)
- [Cost Analysis](#cost-analysis)
- [Approach Comparison](#approach-comparison)
- [Security Considerations](#security-considerations)
- [Architecture Recommendation](#architecture-recommendation)

---

## Overview

Today, proving you own a Cardano NFT requires revealing your wallet address. This links your on-chain identity to your real-world identity for anyone watching. With ZK proofs, you prove ownership of an NFT without revealing which wallet holds it — enabling anonymous access, private governance, and secure lending.

```
Today:
  Verifier: "Prove you own a SpaceBudz NFT"
  You: "Here's my wallet addr1_abc... — check the UTXO set"
  Verifier: Verified ✓
  Everyone: Now knows addr1_abc owns a SpaceBudz, plus everything else in that wallet

With ZK:
  Verifier: "Prove you own a SpaceBudz NFT"
  You: "Here's a 192-byte proof"
  Verifier: Verified ✓
  Everyone: Knows someone owns one. No idea who or which wallet.
```

## The Problem

### Why NFT Ownership Is Public

On Cardano, native tokens live in UTXOs. To verify ownership, you check:

```
UTXO at addr1_abc:
  Value: 5 ADA + 1 SpaceBudz#1234

Proof of ownership = "I control addr1_abc"
```

This reveals:
- **Your wallet address** (linked to all your transactions)
- **All other tokens** in that wallet (visible via chain explorer)
- **Your transaction history** (every send/receive)
- **Your ADA balance** (visible to everyone)

### Real Consequences

| Scenario | Privacy Risk |
|----------|-------------|
| Enter a token-gated event | Event organizer knows your wallet, net worth, and tx history |
| Vote in a DAO | Everyone sees which whale voted which way |
| Claim an airdrop | Your wallet is linked to the claim address forever |
| Use NFT as collateral | Lender sees your entire portfolio |
| Prove you created art | Buyers can track all your sales and holdings |

## Use Cases

### Token-Gated Events and Access

**Scenario**: A conference gives access to holders of a specific NFT collection.

```
Secret:  wallet key, UTXO containing the NFT
Public:  collection policy ID
Output:  isHolder = YES, nullifier (one entry per ticket)

How it works:
  1. Conference publishes: "Policy ID 0x1234... holders get in"
  2. Holder generates ZK proof on their phone
  3. Door scanner verifies proof (~2ms)
  4. Nullifier recorded → can't re-enter with same proof

What's protected:
  ✗ Event organizer does NOT learn your wallet address
  ✗ Other attendees can't see your holdings
  ✗ Nobody can track which specific NFT was used
  ✓ One entry per NFT (nullifier prevents duplicates)
```

### Anonymous DAO Participation

**Scenario**: NFT holders vote on proposals without revealing their identity.

```
Secret:  wallet key, NFT UTXO proof, vote (YES/NO)
Public:  DAO collection policy ID, proposal ID
Output:  commitment (vote hash), nullifier (one vote per NFT)

Why this matters:
  - Whale votes can't be tracked ("Which wallet voted YES?")
  - No social pressure or vote buying
  - Combined with voting nullifier: one vote per NFT, anonymous
  - DAO can see: "40 YES, 25 NO" but NOT who voted what
```

### Anti-Sybil Airdrops

**Scenario**: Project airdrops tokens to holders of collection X, ensuring one claim per NFT.

```
Secret:  wallet key, NFT UTXO, claim address
Public:  eligible collection policy ID, airdrop merkle root
Output:  nullifier (one claim per NFT), recipient address bound in proof

Why ZK helps:
  - Claim from a FRESH address (no link to holding wallet)
  - Nullifier = Poseidon(nft_id, airdrop_id) → one claim per NFT
  - Can't claim with same NFT twice (nullifier already used)
  - Holding address completely hidden from the airdrop contract
```

### NFT-Gated Content

**Scenario**: Exclusive content (music, articles, tools) accessible only to collection holders.

```
Secret:  wallet key, NFT UTXO proof
Public:  collection policy ID, content access root
Output:  isHolder = YES, session token (time-limited)

Design:
  - No nullifier needed (reusable access, not one-time)
  - Session token expires after 24 hours → must re-prove
  - Content platform never learns which wallet or which specific NFT
  - Same NFT can access content unlimited times
```

### Whale Privacy

**Scenario**: Prove you hold >= 10 NFTs from a collection without revealing your wallet or exact count.

```
Secret:  wallet keys (possibly multiple), NFT UTXOs
Public:  collection policy ID, minimum threshold (10)
Output:  isWhale = YES (threshold met)

Circuit proves:
  "I control wallets that collectively hold >= 10 NFTs
   from policy 0x1234..."

Verifier learns:
  ✓ "This person holds at least 10"
  ✗ Exact count (could be 10, 100, or 1000)
  ✗ Which wallets
  ✗ Which specific NFTs
```

### Anonymous Creator Verification

**Scenario**: An artist proves they created a collection without revealing their personal wallet.

```
Secret:  minting policy signing key (proves creator role)
Public:  collection policy ID
Output:  isCreator = YES

How it works:
  The minting policy is defined by a specific key or script hash.
  The creator proves knowledge of the key that controls the policy.
  Doesn't require revealing the key or any address associated with it.

Use case:
  - Artist sells on marketplace without doxxing their wallet
  - Collectors verify authenticity without knowing the artist's address
  - Artist can have separate "public persona" and "private wallet"
```

### Cross-Platform Identity

**Scenario**: Prove you own the same NFT across different platforms without linking accounts.

```
Platform A: Prove ownership → get access (nullifier: Poseidon(nft_id, "platformA"))
Platform B: Prove ownership → get access (nullifier: Poseidon(nft_id, "platformB"))

Each platform sees a DIFFERENT nullifier (due to different platform IDs).
Neither platform can link the two proofs to the same wallet.
But the underlying NFT is the same — unified identity across platforms.
```

### Gaming Item Ownership

**Scenario**: Prove you own a rare in-game item for tournament entry without revealing your full inventory.

```
Secret:  wallet key, specific item NFT UTXO
Public:  game policy ID, required item trait (e.g., "legendary sword")
Output:  hasItem = YES, nullifier (one entry per item per tournament)

Why this matters:
  - Tournament opponents can't scout your full inventory
  - No advance knowledge of what items you'll bring
  - Item ownership verified without revealing wallet
  - Fair competition (no information asymmetry)
```

### Physical-Digital Twin (Warranty)

**Scenario**: Claim warranty on a physical product linked to an NFT, without revealing purchase history.

```
Secret:  wallet key, product NFT UTXO, purchase transaction proof
Public:  manufacturer policy ID, warranty period
Output:  isOwner = YES, warrantyValid = YES

How it works:
  1. Physical product has NFT (minted by manufacturer at sale)
  2. Customer proves: "I own this product NFT AND it's within warranty period"
  3. Warranty claim processed without revealing:
     - Purchase price
     - Purchase date (only "within warranty")
     - Other products owned
     - Wallet balance
```

### NFT-Backed Lending

**Scenario**: Use an NFT as collateral for a loan without revealing your full portfolio.

```
Secret:  wallet key, NFT UTXO, floor price attestation
Public:  collection policy ID, minimum collateral value
Output:  hasCollateral = YES, collateralCategory (">1000 ADA", ">5000 ADA")

Design:
  - Borrower proves: "I own an NFT from collection X worth >= Y ADA"
  - Lender sees: collateral exists and meets threshold
  - Lender does NOT see: which specific NFT, borrower's wallet, other holdings
  - If default: escrow mechanism reveals NFT for liquidation
```

## How ZK NFT Ownership Works

### The Core Circuit

All use cases share a common proof structure:

```
I know:
  1. A secret key SK
  2. A UTXO that contains a token with policy ID P

Such that:
  1. The public key derived from SK owns the UTXO
  2. The UTXO contains at least 1 token with policy P
  3. (Optional) The token has a specific asset name or trait
  4. (Optional) nullifier = Poseidon(token_id, context_id)
```

### What Each Party Sees

| Data | NFT Holder | Verifier | Public |
|------|-----------|----------|--------|
| Wallet address | Yes | **No** | **No** |
| Which NFT specifically | Yes | **No** | **No** |
| Other tokens in wallet | Yes | **No** | **No** |
| ADA balance | Yes | **No** | **No** |
| "Owns an NFT from collection X" | Yes | Yes | Yes |
| Nullifier (if used) | Yes | Yes | Yes |
| ZK proof (192 bytes) | Yes | Yes | Yes |

## The Cardano UTXO Challenge

On Cardano, NFT ownership = UTXO possession. To prove ownership in ZK, you need to prove "I know the spending key for a UTXO that contains token X." But UTXOs change constantly (every transaction creates new UTXOs and consumes old ones).

### The Snapshot Problem

```
At slot 100: Alice owns SpaceBudz#42 in UTXO tx1#0
At slot 200: Alice sends ADA → new UTXOs created, SpaceBudz#42 moves to tx2#1
At slot 300: Alice's ZK proof references tx1#0 → BUT that UTXO no longer exists!
```

**The proof must be against a snapshot of ownership, not a live UTXO.** This is the fundamental challenge.

## Four Approaches

### Approach 1: Ownership Merkle Tree (Off-Chain Snapshot)

An indexer takes periodic snapshots of who holds which NFTs, builds a Merkle tree, and publishes the root on-chain.

```
Snapshot (every epoch):
  Scan all UTXOs for policy ID 0x1234...
  Build Merkle tree:
    leaf = Poseidon(owner_address_hash, token_asset_name)

  Merkle root published on-chain:
    Snapshot UTXO: { policyId: 0x1234, root: 0xABC, epoch: 42 }

ZK proof:
  "I know a (secret_key, token_name) such that
   Poseidon(derive_address(secret_key), token_name) is in the tree"
```

```java
public class NFTOwnershipCircuit implements CircuitSpec {
    private final int treeDepth;

    public NFTOwnershipCircuit(int treeDepth) { this.treeDepth = treeDepth; }

    @Override
    public void define(SignalBuilder c) {
        // Secret
        Signal secretKey  = c.privateInput("secretKey");
        Signal tokenName  = c.privateInput("tokenName");

        Signal[] siblings = new Signal[treeDepth];
        Signal[] pathBits = new Signal[treeDepth];
        for (int i = 0; i < treeDepth; i++) {
            siblings[i] = c.privateInput("sibling_" + i);
            pathBits[i] = c.privateInput("pathBit_" + i);
        }

        // Public
        Signal snapshotRoot = c.publicInput("snapshotRoot");
        Signal policyId     = c.publicInput("policyId");
        Signal contextId    = c.publicInput("contextId");

        // Public output
        Signal isOwner      = c.publicOutput("isOwner");
        Signal nullifier    = c.publicOutput("nullifier");

        // 1. Derive owner identifier from secret key
        Signal ownerHash = SignalPoseidon.hash(c, secretKey, c.constant(0));

        // 2. Compute leaf: Poseidon(ownerHash, tokenName)
        Signal leaf = SignalPoseidon.hash(c, ownerHash, tokenName);

        // 3. Verify Merkle inclusion
        SignalMerkle.verifyProof(c, leaf, c.signal("snapshotRoot"),
                siblings, pathBits, SignalPoseidon::hash);

        // 4. Compute nullifier: Poseidon(tokenName, contextId)
        //    Same NFT + same context = same nullifier (anti-replay)
        c.assertEqual(nullifier, SignalPoseidon.hash(c, tokenName, c.signal("contextId")));

        c.assertEqual(isOwner, c.constant(1));
    }
}
```

| Pros | Cons |
|------|------|
| Simple, proven pattern | **Requires off-chain indexer** for snapshots |
| Large anonymity set (all holders) | Snapshot can be stale (ownership changed since snapshot) |
| Works for any collection size | Indexer can censor (omit holders) |
| ~7,000 constraints (depth 20) | User must wait for next snapshot after acquiring NFT |

**Staleness mitigation**: Shorter snapshot intervals (every hour instead of every epoch). Or: user submits a more recent UTXO proof alongside the Merkle proof.

### Approach 2: UTXO Commitment Registry (On-Chain)

Instead of an off-chain indexer, holders **register** their NFT ownership on-chain by depositing a commitment:

```
Registration:
  1. Holder computes: commitment = Poseidon(secretKey, tokenName, policyId)
  2. Holder submits tx: deposits commitment into registry contract
  3. Registry adds commitment to its Merkle tree (on-chain)

Proof:
  "I know (secretKey, tokenName) such that
   Poseidon(secretKey, tokenName, policyId) is in the registry"
```

```
Registry UTXO (sorted linked list or Merkle root):
  { root: 0xDEF, commitmentCount: 500 }

Registration tx:
  Input: holder's wallet (contains the NFT)
  Input: registry UTXO
  Output: registry UTXO (updated with new commitment)
  Validator checks: holder's tx inputs contain a token with the registered policyId
```

| Pros | Cons |
|------|------|
| **No off-chain indexer** — fully on-chain | Holder must register (extra tx) |
| Fresh — registration is immediate | Registration tx reveals holder address (one-time linkage) |
| Trustless | Registry UTXO contention (use sorted linked list) |
| | Must deregister when NFT is transferred |

**Privacy concern**: The registration transaction itself reveals the holder's address. But after registration, all future proofs are anonymous. To mitigate: register from a fresh address that received the NFT.

### Approach 3: Minting Policy with Built-In Privacy (Cardano-Native)

Design the NFT collection from scratch with privacy built in. Each NFT includes a **commitment** in its metadata at mint time:

```
Minting:
  1. Buyer provides: commitment = Poseidon(buyerSecret, nonce)
  2. Minting policy mints NFT with commitment in CIP-25 metadata
  3. Commitment is public (in metadata), but can't be reversed to find buyer

Proof:
  "I know (buyerSecret, nonce) such that
   Poseidon(buyerSecret, nonce) = commitment in NFT metadata"

No Merkle tree needed — the commitment IS the NFT's metadata field.
```

```
NFT Metadata (CIP-25):
{
  "name": "SpaceBudz #42",
  "image": "ipfs://Qm...",
  "ownerCommitment": "0x7f3a..."  ← Poseidon(buyerSecret, nonce)
}
```

| Pros | Cons |
|------|------|
| **Simplest circuit** (~660 constraints) | Only works for NEW collections (designed for privacy) |
| No Merkle tree, no registry | Doesn't work for existing collections |
| No off-chain indexer | Commitment in metadata is permanent (transfer requires update) |
| Instant verification | Collection must be designed with this pattern |
| No contention | |

**Transfer**: When the NFT changes hands, the new owner submits a transaction updating the commitment in a datum (using CIP-68 updatable metadata).

### Approach 4: Shielded NFT Transfer (Maximum Privacy)

The most advanced pattern — hide not just ownership but also transfers:

```
Deposit:
  Current owner deposits NFT into a shielded pool
  commitment = Poseidon(ownerSecret, nftId)
  Pool records commitment (like a privacy pool for NFTs)

Transfer (hidden):
  Owner proves: "I know the secret for some commitment in the pool"
  Owner creates: new commitment for the recipient
  Pool removes old commitment, adds new one
  Nobody sees: which NFT transferred, from whom, to whom

Withdrawal:
  New owner proves ownership
  Withdraws NFT from pool to their address
```

This is essentially a **privacy pool for NFTs** (non-fungible version of private token transfer).

| Pros | Cons |
|------|------|
| **Complete privacy** — transfers are hidden too | Most complex design |
| Anonymity set = entire pool | Requires pool infrastructure |
| Same NFT can transfer many times anonymously | NFT is "locked" in pool (not in user's wallet) |
| | Higher cost per transfer (~3-5 ADA) |

**Verdict**: Overkill for most use cases. Use when transfer privacy is critical (e.g., anonymous art market).

## Nullifier: One-Time Use Tokens

The nullifier prevents reuse of proofs. It's computed deterministically:

```
nullifier = Poseidon(tokenIdentifier, contextId)
```

- `tokenIdentifier` = asset name or unique NFT ID (secret, derived from holder's data)
- `contextId` = "event-123", "airdrop-456", "dao-vote-789" (public)

**Same NFT + same context = same nullifier** (prevents double use):

```
Alice uses SpaceBudz#42 for event-123:
  nullifier = Poseidon(42, "event-123") = 0xABC

Alice tries again:
  nullifier = Poseidon(42, "event-123") = 0xABC ← SAME! Rejected.

Alice uses SpaceBudz#42 for airdrop-456:
  nullifier = Poseidon(42, "airdrop-456") = 0xDEF ← Different context, allowed.
```

**On-chain storage**: Sorted linked list (same pattern as voting — trustless, concurrent, no off-chain dependency).

**When NOT to use nullifiers**: For reusable access (content gating, repeated logins). In these cases, the same proof can be submitted multiple times, or a session-based token is issued.

## ZK Circuits (CircuitSpec)

### Generic NFT Ownership Proof

```java
public class NFTOwnershipCircuit implements CircuitSpec {
    private final int treeDepth;

    public NFTOwnershipCircuit(int treeDepth) { this.treeDepth = treeDepth; }

    @Override
    public void define(SignalBuilder c) {
        Signal secretKey  = c.privateInput("secretKey");
        Signal tokenName  = c.privateInput("tokenName");
        Signal snapshotRoot = c.publicInput("snapshotRoot");
        Signal contextId    = c.publicInput("contextId");
        Signal isOwner      = c.publicOutput("isOwner");
        Signal nullifier    = c.publicOutput("nullifier");

        Signal[] siblings = new Signal[treeDepth];
        Signal[] pathBits = new Signal[treeDepth];
        for (int i = 0; i < treeDepth; i++) {
            siblings[i] = c.privateInput("sibling_" + i);
            pathBits[i] = c.privateInput("pathBit_" + i);
        }

        // Derive owner hash from secret key
        Signal ownerHash = SignalPoseidon.hash(c, secretKey, c.constant(0));

        // Compute and verify leaf
        Signal leaf = SignalPoseidon.hash(c, ownerHash, tokenName);
        SignalMerkle.verifyProof(c, leaf, c.signal("snapshotRoot"),
                siblings, pathBits, SignalPoseidon::hash);

        // Nullifier for one-time use
        c.assertEqual(nullifier, SignalPoseidon.hash(c, tokenName, c.signal("contextId")));
        c.assertEqual(isOwner, c.constant(1));
    }

    public static CircuitBuilder build(int treeDepth) {
        var builder = CircuitBuilder.create("nft-ownership")
                .publicVar("snapshotRoot")
                .publicVar("contextId")
                .publicVar("isOwner")
                .publicVar("nullifier")
                .secretVar("secretKey")
                .secretVar("tokenName");
        for (int i = 0; i < treeDepth; i++)
            builder = builder.secretVar("sibling_" + i).secretVar("pathBit_" + i);
        return builder.defineSignals(new NFTOwnershipCircuit(treeDepth));
    }
}
```

**Constraints**: ~7,000 (depth 20, Poseidon hashes + Merkle proof)

### Threshold Ownership Proof (Whale Privacy)

```java
public class WhaleProofCircuit implements CircuitSpec {
    private final int treeDepth;
    private final int maxNFTs;

    public WhaleProofCircuit(int treeDepth, int maxNFTs) {
        this.treeDepth = treeDepth;
        this.maxNFTs = maxNFTs;
    }

    @Override
    public void define(SignalBuilder c) {
        Signal secretKey    = c.privateInput("secretKey");
        Signal snapshotRoot = c.publicInput("snapshotRoot");
        Signal threshold    = c.publicInput("threshold");
        Signal isWhale      = c.publicOutput("isWhale");

        Signal ownerHash = SignalPoseidon.hash(c, secretKey, c.constant(0));

        // Prove inclusion for each NFT owned (up to maxNFTs)
        Signal count = c.constant(0);
        for (int n = 0; n < maxNFTs; n++) {
            Signal tokenName = c.privateInput("token_" + n);
            Signal included  = c.privateInput("included_" + n); // 0 or 1

            included.assertBoolean();

            // If included=1, verify Merkle proof for this token
            // (circuit always executes both paths for constant-time)
            Signal[] siblings = new Signal[treeDepth];
            Signal[] pathBits = new Signal[treeDepth];
            for (int i = 0; i < treeDepth; i++) {
                siblings[i] = c.privateInput("sibling_" + n + "_" + i);
                pathBits[i] = c.privateInput("pathBit_" + n + "_" + i);
            }

            Signal leaf = SignalPoseidon.hash(c, ownerHash, tokenName);
            Signal computedRoot = SignalMerkle.computeRoot(c, leaf,
                    siblings, pathBits, SignalPoseidon::hash);

            // If included, root must match snapshot
            // (if not included, this check is skipped via select)
            Signal rootMatch = computedRoot.isEqual(c.signal("snapshotRoot"));
            Signal validInclusion = included.and(rootMatch);

            count = count.add(validInclusion);
        }

        // Total included >= threshold
        c.assertEqual(isWhale, SignalComparators.greaterOrEqual(c, count, threshold, 8));
    }
}
```

**Constraints**: ~7,000 × maxNFTs (one Merkle proof per NFT). For proving >= 10 with max 20: ~140,000 constraints.

## Smart Contract Code (Julc)

### Token-Gated Access Validator

```java
@SpendingValidator
public class NFTGatedAccess {

    @Param static byte[] vkAlpha;
    @Param static byte[] vkBeta;
    @Param static byte[] vkGamma;
    @Param static byte[] vkDelta;
    @Param static PlutusData vkIc;
    @Param static byte[] nullifierRegistryHash;

    record AccessProof(
        byte[] piA, byte[] piB, byte[] piC,
        byte[] nullifier
    ) {}

    @Entrypoint
    static boolean validate(PlutusData datum, AccessProof proof, PlutusData ctx) {
        // 1. Verify ZK proof (BLS12-381 pairing)
        boolean proofValid = verifyGroth16(
            proof.piA(), proof.piB(), proof.piC());

        // 2. Check nullifier is new (minted as token in sorted linked list)
        boolean nullifierNew = checkNullifierMinted(
            ctx, nullifierRegistryHash, proof.nullifier());

        return proofValid && nullifierNew;
    }
}
```

### Snapshot Oracle (Publishes Merkle Root)

```java
@SpendingValidator
public class OwnershipSnapshot {

    @Param static byte[] oraclePubKeyHash;

    record SnapshotDatum(
        byte[] policyId,       // which NFT collection
        byte[] merkleRoot,     // ownership Merkle tree root
        BigInteger epoch,      // when snapshot was taken
        BigInteger holderCount // number of holders
    ) {}

    @Entrypoint
    static boolean validate(SnapshotDatum datum, PlutusData redeemer, PlutusData ctx) {
        // Only oracle can update snapshots
        boolean authorizedOracle = checkSignedBy(ctx, oraclePubKeyHash);

        // Epoch must advance
        SnapshotDatum newDatum = extractOutputDatum(ctx);
        boolean epochAdvanced = newDatum.epoch().compareTo(datum.epoch()) > 0;

        return authorizedOracle && epochAdvanced;
    }
}
```

## Full Transaction Flow

### Setup (Collection Creator)

```
1. Deploy OwnershipSnapshot validator
2. Deploy NFTGatedAccess validator (with Groth16 VK)
3. Deploy NullifierRegistry (sorted linked list)
4. Create initial snapshot UTXO: { policyId: 0x1234, root: EMPTY, epoch: 0 }
5. Create nullifier sentinels: HEAD → TAIL
```

### Snapshot Update (Oracle, Periodic)

```
1. Indexer scans chain for all UTXOs containing tokens with policyId
2. For each holder: leaf = Poseidon(address_hash, token_name)
3. Build Merkle tree → root
4. Update snapshot UTXO: { root: NEW_ROOT, epoch: N+1, holderCount: 500 }
```

### User Proves Ownership (e.g., Event Entry)

```
1. User reads snapshot UTXO (get current root)
2. User gets their Merkle path (from indexer or local computation)
3. User generates ZK proof on their device:
   - "I own an NFT from collection 0x1234"
   - Nullifier for this specific event
4. User presents proof at door / submits to smart contract

Transaction (if on-chain access):
  Input: user's wallet (for fees)
  Input: nullifier predecessor node (sorted linked list)
  Output: new nullifier node
  Redeemer: ZK proof

  Validator checks:
    ✓ ZK proof valid
    ✓ Nullifier is new (not already in list)
```

## UTXO Contention Analysis

| Component | Contention | Pattern |
|-----------|-----------|---------|
| Snapshot UTXO (update) | **Very low** — oracle updates once per epoch | Same as Proof of Reserves |
| Nullifier registration | **Low** — sorted linked list, different users touch different nodes | Same as Private Voting |
| Proof verification (off-chain) | **None** | Stateless |
| NFT ownership itself | **None** — NFT stays in user's wallet | No interaction with pool |

**Overall**: Low contention. The snapshot is updated infrequently (once per epoch). Nullifiers use the sorted linked list pattern (naturally concurrent). Proofs are verified off-chain or via independent on-chain transactions.

## Cost Analysis

| Operation | Cost | Frequency | Who Pays |
|-----------|------|-----------|----------|
| Deploy validators | ~2 ADA | Once | Collection creator |
| Snapshot update | ~0.5 ADA | Every epoch | Oracle / collection creator |
| Generate ZK proof | Free (off-chain) | Per access | User |
| Nullifier registration (on-chain) | ~1.5 ADA | Per one-time use | User (or event organizer) |
| Off-chain verification | Free | Per access | Verifier |

**For an event with 1000 attendees**: ~1,500 ADA in nullifier deposits (reclaimable after event).

## Approach Comparison

| | Merkle Snapshot | UTXO Registry | Minting Policy | Shielded Pool |
|---|---|---|---|---|
| **Works for existing collections** | **Yes** | **Yes** | No (new only) | **Yes** |
| **Off-chain dependency** | Indexer for snapshots | None | **None** | Pool service |
| **Freshness** | Epoch delay | **Immediate** | **Immediate** | **Immediate** |
| **Registration tx needed** | No | Yes (reveals address once) | No | Yes (deposit into pool) |
| **Transfer privacy** | Ownership only | Ownership only | Ownership only | **Ownership + transfers** |
| **Circuit complexity** | ~7,000 | ~7,000 | **~660** | ~15,000+ |
| **Best for** | **Most collections** | Trustless environments | New privacy-first collections | Anonymous art markets |

## Security Considerations

### Snapshot Manipulation

If the oracle/indexer lies about the snapshot (omits holders or adds fake ones):
- **Defense**: Multiple independent indexers. Users can verify their inclusion against the published root.
- **Defense**: Publish raw snapshot data alongside root → anyone can rebuild and verify.

### NFT Transfer After Snapshot

If Alice proves ownership via snapshot, then sells the NFT before using the proof:
- **Defense**: Short snapshot intervals (hourly instead of epoch).
- **Defense**: Nullifier binds to the specific NFT ID → if Alice transfers, she can't use it again (new owner has a different secret key).

### Proof Replay

Someone copies a valid proof and submits it:
- **Defense**: Nullifier prevents reuse for one-time access.
- **Defense**: For reusable access, bind the proof to a session or timestamp.

### Wallet Key Compromise

If someone steals the holder's secret key, they can generate proofs:
- **Same risk as any key-based system** — protect your keys.
- **Defense**: Time-limited proofs (expire after N blocks).

## Architecture Recommendation

### For Most Use Cases: Merkle Snapshot (Approach 1)

```
┌──────────────┐    ┌───────────────┐    ┌─────────────────┐
│  Indexer       │───▶│ Snapshot UTXO  │◀──│ Verifier         │
│  (scans chain) │    │ (Merkle root)  │    │ (checks proof)   │
└──────────────┘    └───────────────┘    └────────┬────────┘
                                                   │
┌──────────────┐                          ┌────────▼────────┐
│  NFT Holder   │─── ZK proof ──────────▶│ Access granted   │
│  (generates   │                         │ (event, DAO,     │
│   proof on    │                         │  content, etc.)  │
│   device)     │                         │                  │
└──────────────┘                          └─────────────────┘
```

Works for **any existing Cardano NFT collection** — no changes to the NFTs themselves. The indexer is a simple chain scanner (can be run by anyone). The snapshot is updated periodically. Users generate proofs on their device.

### For New Collections: Minting Policy with Privacy (Approach 3)

If designing a new collection from scratch, embed the commitment in the NFT metadata. Simplest circuit (~660 constraints), no indexer needed, instant verification.

### For Maximum Privacy: Shielded Pool (Approach 4)

Only needed if transfer privacy is critical (anonymous art sales, private collectibles market). Most complex but provides complete anonymity for both ownership and transfers.

### The Circuit Is the Same On-Chain

All approaches use the same `Groth16BLS12381Verifier` Plutus V3 script shape. Only the circuit, verification key, and snapshot mechanism differ. You can start with Approach 1 and upgrade to Approach 3 or 4 later without writing a custom on-chain verifier.

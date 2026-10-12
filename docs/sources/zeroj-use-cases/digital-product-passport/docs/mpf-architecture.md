# Merkle Patricia Forestry (MPF) Architecture for DPP

How this demo uses Cardano's Merkle Patricia Forestry with ZK proofs for scalable Digital Product Passports.

## Table of Contents

- [What is MPF?](#what-is-mpf)
- [MPF vs Classic Merkle Patricia Trie (Ethereum)](#mpf-vs-classic-merkle-patricia-trie-ethereum)
- [MPF Internals — How Hashing Works](#mpf-internals--how-hashing-works)
  - [Key Hashing](#key-hashing)
  - [Branch Commitment (16-way → Binary Merkle)](#branch-commitment-16-way--binary-merkle)
  - [Leaf Commitment](#leaf-commitment)
  - [Extension Commitment](#extension-commitment)
- [HashFunction vs CommitmentScheme — Why Two Interfaces?](#hashfunction-vs-commitmentscheme--why-two-interfaces)
- [Using Poseidon with MPF](#using-poseidon-with-mpf)
  - [Why Poseidon?](#why-poseidon)
  - [PoseidonCommitmentScheme](#poseidoncommitmentscheme)
  - [How Branch Hashing Maps to Poseidon](#how-branch-hashing-maps-to-poseidon)
- [Architecture: MPF + ZK Proofs for DPP](#architecture-mpf--zk-proofs-for-dpp)
  - [Single Unified Trie](#single-unified-trie)
  - [Proof Flow](#proof-flow)
  - [Scaling to Millions of Products](#scaling-to-millions-of-products)
- [On-Chain Anchoring](#on-chain-anchoring)
- [Persistence and Restarts](#persistence-and-restarts)
- [Cost Model](#cost-model)

---

## What is MPF?

Merkle Patricia Forestry (MPF) is a cryptographically authenticated radix tree designed for Cardano. It combines:

- **Patricia Trie**: Path compression — shared prefixes are stored once, not repeated
- **Merkle Tree**: Every node commits to its children via cryptographic hashing
- **16-way Branching**: Hex nibbles (0-F) at each level, efficient for byte-keyed data

MPF is implemented in [cardano-client-lib](https://github.com/bloxbean/cardano-client-lib) (`cardano-client-merkle-patricia-forestry` module) with pluggable storage backends (RocksDB, PostgreSQL, H2) and pluggable hash functions.

The Aiken on-chain verifier at [aiken-lang/merkle-patricia-forestry](https://github.com/aiken-lang/merkle-patricia-forestry) provides Plutus-based proof verification compatible with the Java implementation.

## MPF vs Classic Merkle Patricia Trie (Ethereum)

MPF is **not** Ethereum's Merkle Patricia Trie. While structurally similar (both are 16-way radix tries with Merkle authentication), the implementations differ significantly:

| Aspect | Ethereum MPT | Cardano MPF |
|--------|--------------|-------------|
| **Hash function** | Keccak-256 | Blake2b-256 (default) or **custom** (since CCL 0.8.0-pre4) |
| **Encoding** | RLP (Recursive Length Prefix) | CBOR |
| **Branch commitment** | Hash of RLP-encoded list of 17 items (16 children + value) | **Binary Merkle tree** over 16 children → hash with prefix |
| **Key handling** | Stored as-is (variable-length paths) | **Pre-hashed** → always 64 nibbles (uniform depth, DoS-resistant) |
| **On-chain verifier** | Solidity (EVM) | Aiken (Plutus V3) or Julc |
| **Node storage** | LevelDB | RocksDB / PostgreSQL / H2 (pluggable `NodeStore`) |
| **Proof format** | RLP-encoded | CBOR-encoded |
| **Commitment scheme** | Fixed (RLP + Keccak) | **Pluggable** (`CommitmentScheme` interface, since CCL 0.8.0-pre4) |

### Why the Branch Commitment Matters

Ethereum MPT hashes a branch by RLP-encoding all 17 items (16 children + value) into one blob, then hashing. This is opaque — you can't verify individual children without the full list.

MPF builds a **binary Merkle tree** over the 16 children:

```
16 children → 4-level binary tree → single root

Level 0: [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15]
Level 1: [H(c0,c1), H(c2,c3), H(c4,c5), H(c6,c7), H(c8,c9), H(c10,c11), H(c12,c13), H(c14,c15)]
Level 2: [H(H01,H23), H(H45,H67), H(H89,H1011), H(H1213,H1415)]
Level 3: [H(H0123,H4567), H(H89AB,HCDEF)]
Level 4: [H(left_half, right_half)]  ← branch Merkle root
```

Then: `branchHash = H(prefix || branchMerkleRoot)`

This structure is **ideal for ZK proofs** because each hash operation combines exactly 2 inputs — a perfect match for Poseidon's 2-input design.

## MPF Internals — How Hashing Works

### Key Hashing

When you call `trie.put(key, value)`, MPF first hashes the key:

```
raw key (e.g., "product_SN001") → hashFn.digest(key) → 32 bytes → 64 hex nibbles
```

This guarantees:
- **Uniform depth**: All paths are exactly 64 nibbles (no deep worst-case paths)
- **Balanced tree**: Hash output is uniformly distributed
- **DoS protection**: Attackers cannot craft adversarial key patterns

### Branch Commitment (16-way → Binary Merkle)

A branch node has up to 16 children (one per hex nibble 0-F). The commitment process:

```java
// MpfCommitmentScheme.commitBranch():
byte[][] childHashes = new byte[16][];  // 16 children (null = empty)
byte[] branchRoot = merkleRoot(childHashes);  // binary Merkle tree
return hashFn.digest(concat(prefixBytes, branchRoot));
```

The `merkleRoot()` function pairs children bottom-up:
```java
// 16 → 8 → 4 → 2 → 1
while (size > 1) {
    for (int i = 0; i < size/2; i++) {
        next[i] = hashFn.digest(concat(current[2*i], current[2*i+1]));
    }
    size /= 2;
}
```

**Total hashes per branch**: 15 (pairwise) + 1 (final with prefix) = **16 hash calls**.

### Leaf Commitment

```
leafHash = H(nibble_prefix || H(value))
```

Where `nibble_prefix` encodes the remaining key suffix (odd/even nibble handling per MPF spec).

### Extension Commitment

```
extensionHash = H(path_nibbles || child_hash)
```

Extension nodes compress shared prefixes — if multiple keys share a common nibble sequence, it's stored once in an extension node.

## HashFunction vs CommitmentScheme — Why Two Interfaces?

CCL's MPF takes two separate abstractions:

```java
MpfTrie(NodeStore store, HashFunction hashFn, byte[] root, CommitmentScheme commitmentScheme)
```

They serve different purposes:

| Interface | What it does | Where it's used |
|-----------|-------------|-----------------|
| `HashFunction` | Primitive: `byte[] digest(byte[])` | Hash raw keys (path computation), hash raw values (before commitment) |
| `CommitmentScheme` | Policy: how to commit branch/leaf/extension nodes | `commitBranch()`, `commitLeaf()`, `commitExtension()`, `nullHash()` |

```
put("product_SN001", dppData):

  1. hashFn.digest("product_SN001")           ← HashFunction: compute trie path
  2. hashFn.digest(dppData)                    ← HashFunction: hash the value
  3. commitmentScheme.commitLeaf(suffix, vh)   ← CommitmentScheme: commit leaf node
  4. commitmentScheme.commitBranch(...)         ← CommitmentScheme: commit parent branch
  ...up to root
```

The separation allows:
- Same hash for keys/values but different node commitment strategy
- Same commitment strategy but different primitive hash
- Or (our use case) **Poseidon for everything** — custom HashFunction AND custom CommitmentScheme

## Using Poseidon with MPF

### Why Poseidon?

Poseidon is a hash function designed for ZK circuits. It operates over prime field elements (not raw bytes), making it ~100x cheaper inside a ZK proof compared to Blake2b or SHA-256.

| Hash | In-circuit cost (R1CS constraints) | Native speed |
|------|-----------------------------------|--------------|
| Poseidon (2 inputs) | ~330 constraints | ~1ms |
| Blake2b-256 | ~25,000+ constraints | ~0.01ms |
| SHA-256 | ~25,000+ constraints | ~0.01ms |

If the MPF root is computed with Poseidon, we can verify MPF proofs **inside a ZK circuit** at practical cost. If the root uses Blake2b, in-circuit verification is prohibitively expensive.

### PoseidonCommitmentScheme

We implement `CommitmentScheme` using Poseidon field arithmetic instead of byte concatenation:

```java
public class PoseidonCommitmentScheme implements CommitmentScheme {

    // Instead of: hashFn.digest(concat(left, right))
    // We do:     Poseidon(toFieldElement(left), toFieldElement(right)).toBytes()

    @Override
    public byte[] commitBranch(NibblePath prefix, byte[][] childHashes, byte[] valueHash) {
        // Build binary Merkle tree over 16 children using Poseidon pairs
        byte[] branchRoot = poseidonMerkleRoot(childHashes);
        // Combine with prefix
        return poseidonHash(prefixAsFieldElement(prefix), toFieldElement(branchRoot));
    }

    @Override
    public byte[] commitLeaf(NibblePath suffix, byte[] valueHash) {
        return poseidonHash(suffixAsFieldElement(suffix), toFieldElement(valueHash));
    }

    @Override
    public byte[] commitExtension(NibblePath path, byte[] childHash) {
        return poseidonHash(pathAsFieldElement(path), toFieldElement(childHash));
    }
}
```

### How Branch Hashing Maps to Poseidon

The binary Merkle tree over 16 children decomposes perfectly into Poseidon pairs:

```
16 children (each 32 bytes = 1 BLS12-381 field element):

Level 0: [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15]
Level 1: [P(c0,c1), P(c2,c3), P(c4,c5), P(c6,c7), P(c8,c9), P(c10,c11), P(c12,c13), P(c14,c15)]
Level 2: [P(P01,P23), P(P45,P67), P(P89,P1011), P(P1213,P1415)]
Level 3: [P(P0123,P4567), P(P89AB,PCDEF)]
Level 4: [P(left_half, right_half)]  ← branchRoot

Where P(a,b) = Poseidon(toField(a), toField(b))
```

Each Poseidon call takes two 32-byte inputs (field elements) and produces one 32-byte output. 15 Poseidon hashes per branch — identical structure to the default MpfCommitmentScheme, just using Poseidon instead of Blake2b.

## Architecture: MPF + ZK Proofs for DPP

### Single Unified Trie

This demo uses a **single MPF trie with Poseidon** for all product DPP data:

```
MPF Trie (Poseidon, RocksDB)
├── "product:BAT-SN001" → { carbon: 7.3, recycled: 45, country: 276, inspections: 3/3, ... }
├── "product:BAT-SN002" → { carbon: 8.1, recycled: 38, country: 276, inspections: 3/3, ... }
├── "batch:TEX-B2024-001" → { carbon_per_unit: 3.8, recycled: 42, country: 276, units: 100, ... }
├── "batch:TEX-B2024-002" → { carbon_per_unit: 4.1, recycled: 35, country: 250, units: 200, ... }
├── ... millions more ...
```

- **Persistent**: RocksDB backend survives restarts
- **Scalable**: Patricia trie = O(key_length) lookups, O(log n) proof size
- **Mutable**: Products can be added, updated, removed — root hash changes with each mutation
- **ZK-compatible**: Poseidon root can be verified inside ZK circuits

### Proof Flow

```
1. Product data stored in MPF (Poseidon, RocksDB)
   └── Root hash represents entire product database state

2. When a compliance claim needs proving:
   a. Extract MPF proof for the product: trie.getProofWire("product:BAT-SN001")
   b. MPF proof = path from root to the product's leaf (branch siblings, extensions, leaf)
   c. Generate ZK proof:
      - Private inputs: product data (carbon, recycled%, country, etc.) + MPF proof path
      - Public inputs: MPF root (on-chain), threshold (e.g., carbon < 50kg)
      - Output: isCompliant (0 or 1)
   d. ZK circuit verifies:
      - MPF proof path reconstructs to the public root (data exists in the database)
      - Product's claim meets the threshold (carbon < 50, recycled >= 30, etc.)

3. On-chain: MPF root anchored in datum/metadata
   └── Verifier checks: ZK proof valid + root matches on-chain anchor
```

### Scaling to Millions of Products

MPF with RocksDB is designed for large-scale data:

| Products | Trie depth | Proof size | Proof generation | ZK circuit cost (per claim) |
|----------|-----------|-----------|-----------------|---------------------------|
| 1,000 | ~8 levels | ~512 bytes | <1ms | ~2,000 constraints |
| 100,000 | ~12 levels | ~768 bytes | <1ms | ~3,000 constraints |
| 1,000,000 | ~16 levels | ~1 KB | <2ms | ~4,000 constraints |
| 10,000,000 | ~20 levels | ~1.3 KB | <3ms | ~5,000 constraints |

Note: MPF depth depends on key distribution, not just count. Pre-hashed keys (64 nibbles) ensure uniform distribution. The ZK circuit cost grows linearly with proof depth (each branch level = ~15 Poseidon hashes for siblings + 1 for the branch itself).

## On-Chain Anchoring

The MPF root hash is anchored on-chain as a public reference:

```
On-chain UTXO:
  Address: DPP registry script
  Datum: {
    mpf_root: <32-byte Poseidon MPF root>,
    last_updated: <slot>,
    product_count: 1000000
  }
```

This root commits to the **entire product database**. Any change (add/remove/update a product) produces a new root. The on-chain root is updated periodically (e.g., every epoch or after N changes).

ZK proofs reference this root as a public input. The verifier checks that the proof was generated against the currently anchored root.

## Persistence and Restarts

```java
// First startup: create trie with Poseidon
var nodeStore = new RocksDbNodeStore("/data/dpp-trie");
var hashFn = PoseidonHashFunction.INSTANCE;
var commitment = new PoseidonCommitmentScheme();
var trie = new MpfTrie(nodeStore, hashFn, null, commitment);

// Add products
trie.put("product:BAT-SN001".getBytes(), dppData);
byte[] root = trie.getRootHash();  // Poseidon root

// --- App restarts ---

// Subsequent startup: reopen with same root
var trie = new MpfTrie(nodeStore, hashFn, savedRoot, commitment);

// All data is still there (RocksDB persisted)
byte[] data = trie.get("product:BAT-SN001".getBytes());  // ✓ works

// Add more products to the SAME trie
trie.put("product:BAT-SN002".getBytes(), newDppData);
byte[] newRoot = trie.getRootHash();  // Updated root
```

Key behaviors:
- **RocksDB** persists all trie nodes to disk
- **Root hash** must be saved (e.g., on-chain or in config) to reopen the trie
- **Same trie** can grow indefinitely — add millions of products over time
- **Batches and individual products** coexist in the same trie (different key prefixes)

## Cost Model

### On-Chain Costs

| Operation | Cost | Frequency |
|-----------|------|-----------|
| Anchor MPF root update | ~0.3 ADA | Per batch of changes (e.g., daily) |
| Mint product NFT | ~0.5 ADA | Per product or per batch |
| Submit ZK compliance proof | ~0.3 ADA | Per claim per product (or per batch) |
| Consumer verification | Free | Off-chain proof check |

### Per-Product vs Per-Batch

| Pattern | Products | ZK proofs | On-chain cost | Cost per unit |
|---------|----------|-----------|---------------|---------------|
| Per-product NFT + 3 proofs | 1 | 3 | ~1.5 ADA | ~1.5 ADA |
| Batch NFT (100 units) + 3 proofs | 100 | 3 | ~1.5 ADA | ~0.015 ADA |
| Batch NFT (1000 units) + 3 proofs | 1000 | 3 | ~1.5 ADA | ~0.0015 ADA |

### MPF Storage Costs

| Products | RocksDB size (est.) | Memory footprint |
|----------|-------------------|-----------------|
| 10,000 | ~50 MB | ~20 MB cache |
| 100,000 | ~500 MB | ~50 MB cache |
| 1,000,000 | ~5 GB | ~100 MB cache |
| 10,000,000 | ~50 GB | ~200 MB cache |

RocksDB handles the heavy lifting — only hot nodes are cached in memory.

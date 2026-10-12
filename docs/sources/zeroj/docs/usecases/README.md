# Zero-Knowledge Use Cases on Cardano

## Table of Contents

- [What is Zero-Knowledge?](#what-is-zero-knowledge)
- [How It Works on Cardano](#how-it-works-on-cardano)
- [Use Case 1: Identity Verification (KYC)](#use-case-1-identity-verification-kyc-without-revealing-data)
- [Use Case 2: Private Voting](#use-case-2-private-voting)
- [Use Case 3: Sealed-Bid Auction](#use-case-3-sealed-bid-auction)
- [Use Case 4: Private Token Transfer](#use-case-4-private-token-transfer)
- [Use Case 5: Credit Score Proof](#use-case-5-credit-score-proof-defi-lending)
- [Use Case 6: Supply Chain Provenance](#use-case-6-supply-chain-provenance)
- [Use Case 7: Proof of Reserves](#use-case-7-proof-of-reserves-exchange-solvency)
- [Use Case 8: Private NFT Ownership](#use-case-8-private-nft-ownership-proof)
- [Summary](#summary)
- [Getting Started](#getting-started)

---

## What is Zero-Knowledge?

Imagine you want to prove you're over 18 to enter a venue. Today, you show your ID — revealing your name, address, exact birthday, and more. With zero-knowledge proofs, you prove **only** that you're over 18. Nothing else is revealed.

A zero-knowledge proof lets you prove a statement is true **without revealing why it's true**.

**In blockchain terms**: you can prove a transaction is valid without revealing the transaction details. The proof is tiny (~192 bytes) and cheap to verify on-chain, regardless of how complex the underlying computation is.

## How It Works on Cardano

```
You (the Prover)                           Cardano (the Verifier)
────────────────                           ──────────────────────
1. Define what you want to prove
   (a "circuit" — the rules)

2. Provide your secret data
   (only you see this)

3. Generate a ZK proof
   (~192 bytes, takes seconds)

4. Submit proof to Cardano                 → 5. Smart contract checks the proof
                                              (BLS12-381 pairing check)

                                           → 6. Valid? Transaction succeeds.
                                              Invalid? Transaction rejected.

                                              Secret data NEVER appears on-chain.
```

**Key insight**: The proof is the same size (~192 bytes) whether you're proving "I know two numbers that multiply to 33" or "I have a valid passport from an approved country." Verification cost on Cardano is identical for both.

---

## Use Case 1: Identity Verification (KYC without revealing data)

### The Problem

DeFi protocols need to verify users meet regulatory requirements (age, residency, etc.). Today, this means sharing sensitive personal data. A data breach exposes everything.

### The ZK Solution

Prove you meet the requirements without revealing your personal data.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Birth date | Only you |
| **Secret** (hidden) | Passport number | Only you |
| **Secret** (hidden) | Country code | Only you |
| **Secret** (hidden) | Government signature on passport | Only you |
| **Public** (visible) | Minimum age (e.g., 18) | Everyone |
| **Public** (visible) | Approved countries list (as Merkle root) | Everyone |
| **Public** (output) | Is eligible? (YES or NO) | Everyone |

### What Happens

1. Government issues a digitally signed credential (off-chain)
2. User generates a ZK proof: "My credential is valid AND my age >= 18 AND my country is approved"
3. DeFi protocol sees only: **"eligible: YES"**
4. User's personal data never touches the blockchain

### Real-World Impact

- No data breaches — personal data stays on user's device
- Regulatory compliance without privacy sacrifice
- User can prove eligibility to multiple protocols without re-sharing data

**Deep dive**: [ZK Identity & Credentials — Detailed Design](identity-and-credentials.md) — three credential approaches (Poseidon-signed, EdDSA, BBS+), credential lifecycle, revocation patterns, W3C VC compatibility, Atala PRISM integration, Julc smart contracts. Covers KYC, age verification, accredited investor, DAO membership, and more.

---

## Use Case 2: Private Voting

### The Problem

DAO governance votes are public on-chain. This enables:
- Vote buying (prove you voted a certain way to get paid)
- Social pressure (peers see your vote)
- Whale intimidation (large holders influence smaller voters)

### The ZK Solution

Vote privately while still preventing double-voting.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Your vote (YES or NO) | Only you |
| **Secret** (hidden) | Your secret key | Only you |
| **Secret** (hidden) | Merkle proof of membership | Only you |
| **Public** (visible) | Election ID | Everyone |
| **Public** (visible) | Eligible voters (Merkle root) | Everyone |
| **Public** (output) | Vote commitment (hash) | Everyone |
| **Public** (output) | Nullifier (anti-double-vote token) | Everyone |

### What Happens

1. DAO publishes a Merkle tree of eligible voter public keys
2. Voter generates proof: "I'm in the voter list AND my vote is valid (0 or 1)"
3. Smart contract records the **nullifier** (a unique token derived from voter's secret key + election ID)
4. If the same nullifier appears twice → second vote rejected (double-vote prevention)
5. Nobody can link a nullifier to a specific voter

### Real-World Impact

- Truly private governance — no vote buying possible
- Sybil-resistant — each eligible member votes exactly once
- Verifiable — anyone can check the election is fair without seeing individual votes

**Deep dive**: [Private Voting — Detailed Design](private-voting.md) — nullifier mechanics, Cardano UTXO patterns, sorted linked list on-chain registry, Julc smart contract code, concurrency analysis.

---

## Use Case 3: Sealed-Bid Auction

### The Problem

In standard on-chain auctions, bids are visible to everyone. This allows:
- Front-running (bid just above the current highest)
- Bid sniping (wait until the last moment)
- Collusion (coordinate bids based on visible information)

### The ZK Solution

Submit a hidden bid. After the deadline, prove your bid exceeds the reserve price without revealing the amount.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Bid amount (e.g., 1000 ADA) | Only you |
| **Secret** (hidden) | Random salt (for commitment) | Only you |
| **Public** (visible) | Reserve price (e.g., 500 ADA) | Everyone |
| **Public** (output) | Bid commitment (hash of bid + salt) | Everyone |
| **Public** (output) | Is above reserve? (YES or NO) | Everyone |

### What Happens

1. Bidder commits: publishes `hash(bidAmount, salt)` on-chain (hides the bid)
2. After deadline, bidder proves: "My bid is >= reserve price"
3. Winner reveals their bid to claim — losers' bids are **never revealed**
4. No front-running possible — bids are hidden until the reveal phase

### Real-World Impact

- Fair auctions for NFTs, real estate, spectrum licenses
- No information leakage during bidding phase
- Losers maintain privacy — failed bids are never exposed

**Already built**: This is the `SealedBidCircuit` example in ZeroJ with on-chain `ZkAuctionVerifier`.

---

## Use Case 4: Private Token Transfer

### The Problem

Every ADA transfer on Cardano is publicly visible. Sender, receiver, and amount are all on-chain. This is fine for transparency but bad for privacy.

### The ZK Solution

Transfer tokens without linking sender and receiver addresses.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Your secret (proves ownership of deposit) | Only you |
| **Secret** (hidden) | Nullifier (anti-double-spend) | Only you |
| **Secret** (hidden) | Merkle path (proves your deposit exists) | Only you |
| **Public** (visible) | Merkle root (all deposits) | Everyone |
| **Public** (visible) | Recipient address | Everyone |
| **Public** (output) | Nullifier hash (prevents double-spend) | Everyone |

### What Happens

1. **Deposit**: Alice sends 100 ADA to the pool contract, publishing `commitment = hash(secret, nullifier)`
2. **Wait**: More people deposit. The pool grows. The Merkle tree of commitments is updated.
3. **Withdraw**: Bob (actually Alice using a different address) proves: "I know a secret for one of the commitments in the tree"
4. The smart contract checks the proof and the nullifier hash (prevents withdrawing twice)
5. Bob receives 100 ADA. **Nobody can tell that Alice and Bob are the same person.**

### Real-World Impact

- Financial privacy on public blockchains
- Protects business transactions from competitor surveillance
- Salary payments without revealing amounts to the public

**Deep dive**: [Private Token Transfer — Detailed Design](private-token-transfer.md) — deposit/withdrawal protocol, Cardano UTXO pool patterns, relayer network, fixed vs variable amounts, sorted linked list nullifiers, Julc smart contracts, compliance (Privacy Pools).

---

## Use Case 5: Credit Score Proof (DeFi Lending)

### The Problem

To get a DeFi loan, you need to prove creditworthiness. But sharing your full financial history with every protocol is a privacy nightmare.

### The ZK Solution

Prove your credit score meets the minimum without revealing the score or any financial details.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Your credit score (e.g., 750) | Only you |
| **Secret** (hidden) | Lender's signature on your score | Only you |
| **Secret** (hidden) | Your financial data hash | Only you |
| **Public** (visible) | Minimum required score (e.g., 700) | Everyone |
| **Public** (visible) | Lender's public key | Everyone |
| **Public** (output) | Is qualified? (YES or NO) | Everyone |

### What Happens

1. A trusted credit agency signs your score off-chain (EdDSA signature)
2. You generate a proof: "A trusted agency certified my score AND my score >= 700"
3. The lending protocol verifies the proof on-chain
4. You get the loan. The protocol never sees your actual score (750), just "qualified: YES"

### Real-World Impact

- Privacy-preserving credit checks
- Portable reputation across DeFi protocols
- No data silos — users control their financial data

---

## Use Case 6: Supply Chain Provenance

### The Problem

Consumers want to know products are authentic and ethically sourced. But supply chain details are trade secrets — companies don't want to reveal their suppliers, routes, or costs.

### The ZK Solution

Prove a product passed all required quality checkpoints without revealing the supply chain details.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Inspector signatures (5 checkpoints) | Only the producer |
| **Secret** (hidden) | Timestamps and locations | Only the producer |
| **Secret** (hidden) | Quality measurements | Only the producer |
| **Public** (visible) | Product ID | Everyone |
| **Public** (visible) | Required checkpoints (Merkle root) | Everyone |
| **Public** (output) | Is compliant? (YES or NO) | Everyone |
| **Public** (output) | Product hash (integrity seal) | Everyone |

### What Happens

1. At each checkpoint, an inspector digitally signs the product data
2. Producer generates a proof: "All 5 required inspections passed, in correct order"
3. Retailer/consumer verifies on-chain: "compliant: YES"
4. Supply chain details (suppliers, routes, costs) remain confidential

### Real-World Impact

- Verified authenticity without revealing trade secrets
- Anti-counterfeiting for pharmaceuticals, luxury goods, food
- Consumer trust with producer privacy

**Deep dive**: [Digital Product Passport — Detailed Design](digital-product-passport.md) — EU DPP regulation, ZK-provable claims (carbon, recycled content, inspections, conflict minerals), native tokens as product IDs, UTXO lifecycle state machine, multi-party supply chain proofs, Julc smart contracts, zero contention architecture.

---

## Use Case 7: Proof of Reserves (Exchange Solvency)

### The Problem

After exchange collapses (FTX, etc.), users want proof that exchanges actually hold the funds they claim. But publishing all account balances destroys user privacy.

### The ZK Solution

Prove total reserves exceed total liabilities without revealing individual account balances.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Individual account balances | Only the exchange |
| **Secret** (hidden) | Merkle proofs for each account | Only the exchange |
| **Public** (visible) | Liabilities Merkle root | Everyone |
| **Public** (output) | Total reserves amount | Everyone |
| **Public** (output) | Is solvent? (YES or NO) | Everyone |

### What Happens

1. Exchange builds a Merkle tree of all account liabilities
2. Exchange generates a proof: "The sum of all accounts equals X AND I hold >= X in reserves"
3. Users can verify their account is included (Merkle proof) without seeing others' balances
4. Published periodically on Cardano — immutable proof of solvency

### Real-World Impact

- Prevents FTX-style hidden insolvency
- User privacy maintained (individual balances hidden)
- Automated, verifiable, tamper-proof auditing

**Deep dive**: [Proof of Reserves — Detailed Design](proof-of-reserves.md) — Merkle sum trees, 4 approaches compared (simple sum, Merkle sum tree, UTXO summation, recursive aggregation), individual account inclusion proofs, Cardano-specific designs (stake pools, stablecoins, DeFi, bridges), Julc smart contracts, cheating defenses.

---

## Use Case 8: Private NFT Ownership Proof

### The Problem

Token-gated access (events, content, communities) requires proving you own a specific NFT. But this links your wallet address to your real-world identity.

### The ZK Solution

Prove you own the NFT without revealing which wallet holds it.

### What the Circuit Sees

| Type | Data | Who Sees It |
|------|------|-------------|
| **Secret** (hidden) | Wallet secret key | Only you |
| **Secret** (hidden) | NFT policy ID and asset name | Only you |
| **Secret** (hidden) | UTXO proof (proves your wallet holds it) | Only you |
| **Public** (visible) | NFT fingerprint | Everyone |
| **Public** (visible) | Access grant root (approved NFTs) | Everyone |
| **Public** (output) | Is owner? (YES or NO) | Everyone |
| **Public** (output) | Nullifier (one-time access token) | Everyone |

### What Happens

1. Event organizer publishes a list of accepted NFT fingerprints
2. Holder generates proof: "I own one of the accepted NFTs"
3. Access is granted. The holder's wallet address is **never revealed**.
4. Nullifier prevents using the same proof twice (one entry per ticket)

### Real-World Impact

- Anonymous access to token-gated events
- No wallet-to-identity linkage
- Prevent ticket scalping (nullifier = one-time use)

**Deep dive**: [Private NFT Ownership — Detailed Design](private-nft-ownership.md) — 10 use cases (token-gated access, anonymous DAO, anti-sybil airdrops, whale privacy, creator verification, gaming, warranty, lending), 4 approaches (Merkle snapshot, UTXO registry, privacy-native minting, shielded pool), nullifier patterns, CircuitSpec circuits, Julc smart contracts.

---

## Summary

| Use Case | What You Prove | What Stays Hidden | Est. Constraints |
|----------|---------------|-------------------|-----------------|
| **Identity (KYC)** | "I'm eligible" | Age, passport, country | ~4,000 |
| **Private Voting** | "I voted validly" | Which way you voted | ~8,000 |
| **Sealed-Bid Auction** | "Bid >= reserve" | The actual bid amount | ~500 |
| **Private Transfer** | "I deposited earlier" | Which deposit is yours | ~7,000 |
| **Credit Score** | "Score >= 700" | The actual score | ~4,000 |
| **Supply Chain** | "All checks passed" | Suppliers, routes, costs | ~20,000 |
| **Proof of Reserves** | "Reserves >= liabilities" | Individual balances | ~10,000+ |
| **NFT Ownership** | "I own this NFT" | Your wallet address | ~5,000 |

**All produce the same ~192-byte proof. All verify with the same on-chain cost on Cardano.**

---

## Getting Started

Ready to build? Here's where to start:

1. **[Circuit DSL User Guide](../circuit-dsl-user-guide.md)** — Define circuits in Java using `CircuitSpec`
2. **[Pure Java Prover Guide](../pure-java-prover-guide.md)** — Prove and verify with zero external tools
3. **[Getting Started](../getting-started.md)** — Complete walkthrough from circuit to on-chain verification

### Already Implemented Examples

| Example | Use Case | Module |
|---------|----------|--------|
| `SealedBidCircuit` | Sealed-bid auction | `zeroj-integration-tests` |
| `AnonymousVotingCircuit` | Private voting | `zeroj-integration-tests` |
| `BalanceThresholdCircuit` | Balance/credit proof | `zeroj-integration-tests` |
| `HashChainCircuit` | Time-lock / PoW chain | `zeroj-integration-tests` |
| `MerkleMembershipCircuit` | Private set membership | `zeroj-integration-tests` |
| `MultiInputCommitmentCircuit` | Data commitment | `zeroj-integration-tests` |

All run on **BLS12-381** with the **pure Java prover** — zero external dependencies, verified on-chain via Cardano Plutus V3.

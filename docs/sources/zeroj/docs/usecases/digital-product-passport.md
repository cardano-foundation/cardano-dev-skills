# Digital Product Passport (DPP) on Cardano — Detailed Design

Prove product compliance without revealing trade secrets. EU-mandated, blockchain-anchored, ZK-verified.

## Table of Contents

- [Overview](#overview)
- [EU DPP Regulation](#eu-dpp-regulation)
- [The Privacy Tension](#the-privacy-tension)
- [How ZK Solves the DPP Challenge](#how-zk-solves-the-dpp-challenge)
- [DPP Data Model](#dpp-data-model)
- [ZK-Provable Claims](#zk-provable-claims)
  - [Recycled Content](#recycled-content)
  - [Carbon Footprint](#carbon-footprint)
  - [Quality Inspections](#quality-inspections)
  - [Conflict Minerals](#conflict-minerals)
  - [Manufacturing Origin](#manufacturing-origin)
  - [Battery Degradation](#battery-degradation)
- [Multi-Party Supply Chain](#multi-party-supply-chain)
- [Cardano-Native DPP Architecture](#cardano-native-dpp-architecture)
  - [Native Tokens as Product IDs](#native-tokens-as-product-ids)
  - [Product Lifecycle as UTXO State Machine](#product-lifecycle-as-utxo-state-machine)
  - [On-Chain vs Off-Chain Data Split](#on-chain-vs-off-chain-data-split)
- [UTXO Design](#utxo-design)
- [Smart Contract Code (Julc)](#smart-contract-code-julc)
- [ZK Circuits (CircuitSpec)](#zk-circuits-circuitspec)
- [Full Transaction Flow](#full-transaction-flow)
- [Cost Analysis](#cost-analysis)
- [Security and Trust Model](#security-and-trust-model)
- [Standards Compatibility](#standards-compatibility)
- [Architecture Recommendation](#architecture-recommendation)
- [Comparison with Cardano Foundation DPP Blueprint](#comparison-with-cardano-foundation-dpp-blueprint)
  - [Two Approaches to the Same Problem](#two-approaches-to-the-same-problem)
  - [Where ZK Enhances the CF Blueprint](#where-zk-enhances-the-cf-blueprint)
  - [Where the CF Blueprint Has Advantages](#where-the-cf-blueprint-has-advantages)
  - [When to Use Which Approach](#when-to-use-which-approach)
  - [Complementary, Not Competing](#complementary-not-competing)
  - [Implementation Roadmap](#implementation-roadmap)

---

## Overview

The EU Digital Product Passport (DPP) requires manufacturers to provide detailed information about their products — materials, carbon footprint, recyclability, supply chain origin, and compliance certifications. This data must be accessible to regulators, consumers, and recyclers.

**The problem**: Supply chain data is commercially sensitive. Revealing exact supplier names, costs, manufacturing processes, and defect rates to competitors destroys competitive advantage.

**The ZK solution**: Prove compliance claims without revealing the underlying data.

```
Without ZK:
  Manufacturer → "Our carbon footprint is 42.7 kg CO2"
                  Competitor now knows your efficiency. Regulators see everything.

With ZK:
  Manufacturer → "Proof: carbon footprint < 50 kg CO2" (192-byte proof)
                  Regulator: verified ✓. Competitor: learns nothing.
                  Consumer: "This product is green ✓"
```

## EU DPP Regulation

### What's Required

The **Ecodesign for Sustainable Products Regulation (ESPR)** mandates Digital Product Passports for:

| Phase | Products | Date | Key Requirements |
|-------|----------|------|-----------------|
| 1 | Textiles | 2026 | Materials composition, recycled content |
| 1 | Electronics | 2027 | Repairability, spare parts, energy label |
| 1 | Batteries | 2027 | Capacity, degradation, recycled content |
| 2 | Furniture | 2028 | Durability, recyclability |
| Full | All regulated | 2030 | Complete DPP for all covered products |

**Penalties**: Up to 10% of annual turnover (similar to GDPR).

### What a DPP Must Contain

```
1. Product identification (name, model, serial, manufacturer)
2. Materials composition (% by weight)
3. Carbon footprint (lifecycle)
4. Recycled content percentage
5. Repairability/recyclability rating
6. Hazardous substances
7. Supply chain origin (region-level)
8. Quality certifications (REACH, RoHS, ISO)
9. Spare parts availability
10. Repair instructions
```

## The Privacy Tension

| Regulators Want | Companies Need to Protect |
|----------------|--------------------------|
| Full supply chain transparency | Supplier identities (trade secrets) |
| Exact carbon footprint | Manufacturing efficiency (competitive data) |
| Inspection details | Defect rates (warranty liability) |
| Material sourcing proof | Sourcing costs (pricing power) |
| Labor standards verification | Factory locations (security) |

**ZK proofs bridge this gap** — prove the claim is true without revealing why.

## How ZK Solves the DPP Challenge

For each DPP requirement, the manufacturer can provide either:
- **Public data**: Product name, manufacturer, certification status (visible to all)
- **ZK proof**: "Recycled content >= 30%" — verified, but exact value hidden

```
DPP Claim                       What's Public           What's Hidden (in ZK proof)
─────────────────────────────────────────────────────────────────────────────────────
"Carbon footprint < 50kg"        Category: "low"         Exact: 42.7 kg
"Recycled content >= 30%"        Range: "30-50%"         Exact: 37.2%
"5 inspections passed"           Count: 5                Inspector names, defect details
"No conflict minerals"           Status: verified         Smelter identities, audit details
"Made in EU"                     Region: EU              Specific country, factory
"Battery health > 80% at 500cy" Rating: good             Exact degradation curve
```

## DPP Data Model

### Public vs Confidential Split

```
PUBLIC (on Cardano, visible to all):
├─ Product ID (Cardano native token)
├─ Manufacturer name and country
├─ Certification statuses (REACH, RoHS, ISO)
├─ Carbon footprint category ("low", "medium", "high")
├─ Recycled content category (">30%", "10-30%")
├─ Repairability rating (0-10)
├─ Spare parts availability (yes/no)
├─ ZK proof hashes (links to compliance proofs)
└─ DPP document hash (IPFS link)

CONFIDENTIAL (only in ZK proofs — never on-chain):
├─ Exact carbon footprint (kg CO2e)
├─ Exact recycled content percentage
├─ Supplier identities and locations
├─ Manufacturing costs and margins
├─ Quality inspection details
├─ Defect rates and remediation
├─ Supply chain routes
└─ Proprietary process parameters
```

## ZK-Provable Claims

### Recycled Content

**Claim**: "This product contains >= 30% recycled materials"

```
Secret inputs:  recycled_weight (250g), total_weight (500g), lab_signature
Public inputs:  product_id, threshold (30%), certifier_pubkey
Public output:  is_compliant (YES/NO)

Circuit logic:
  1. Verify lab signature on weight measurements
  2. Compute: percentage = recycled_weight * 100 / total_weight
  3. Assert: percentage >= threshold
  4. Output: is_compliant = 1

Constraints: ~1,500 (signature verify + range check + division)
```

| What verifier learns | What stays hidden |
|---------------------|-------------------|
| "Recycled content >= 30%" | Exact percentage (could be 30% or 99%) |
| Lab has certified it | Lab identity, test methodology |
| Product is compliant | Material suppliers, sourcing details |

### Carbon Footprint

**Claim**: "Lifecycle carbon footprint < 50 kg CO2-equivalent"

```
Secret inputs:  carbon_manufacturing, carbon_transport, carbon_materials,
                carbon_packaging, auditor_signature
Public inputs:  product_id, threshold_kg (50), auditor_pubkey
Public output:  is_below_threshold (YES/NO)

Circuit logic:
  1. total = manufacturing + transport + materials + packaging
  2. Verify auditor signature on the carbon data
  3. Assert: total < threshold
  4. Output: is_below_threshold = 1

Constraints: ~1,500
```

### Quality Inspections

**Claim**: "All 5 required quality checkpoints passed in correct order"

```
Secret inputs:  inspector_signatures[5], timestamps[5], details[5]
Public inputs:  product_id, required_checkpoints (5), approved_inspectors_root
Public output:  all_passed (YES/NO)

Circuit logic:
  For each checkpoint:
    1. Verify inspector signature
    2. Assert inspector is in approved set (Merkle proof)
    3. Assert timestamp[i] > timestamp[i-1] (correct order)
  Output: all_passed = 1

Constraints: ~8,000 (5 signatures + 5 Merkle proofs + ordering)
```

### Conflict Minerals

**Claim**: "No materials from conflict regions"

```
Secret inputs:  supplier_countries[N], supplier_certificates[N]
Public inputs:  product_id, conflict_countries_root, certifier_pubkeys
Public output:  conflict_free (YES/NO)

Circuit logic:
  For each supplier:
    1. Assert country NOT in conflict_countries tree (non-membership proof)
    2. Verify supplier certificate signature
  Output: conflict_free = 1

Constraints: ~3,000 per supplier
```

### Manufacturing Origin

**Claim**: "Manufactured in EU"

```
Secret inputs:  factory_country, factory_id, auditor_signature
Public inputs:  product_id, eu_countries_root, auditor_pubkey
Public output:  made_in_eu (YES/NO)

Circuit logic:
  1. Assert country is in EU countries Merkle tree
  2. Verify auditor signature on factory data
  Output: made_in_eu = 1

Constraints: ~2,000
```

### Battery Degradation

**Claim**: "Battery retains >= 80% capacity at 500 cycles"

```
Secret inputs:  initial_capacity, capacity_at_500_cycles, test_lab_signature
Public inputs:  product_id, min_retention (80%), cycle_count (500), lab_pubkey
Public output:  degradation_acceptable (YES/NO)

Circuit logic:
  1. Verify lab signature on test data
  2. retention = capacity_at_500 * 100 / initial_capacity
  3. Assert: retention >= min_retention
  Output: degradation_acceptable = 1

Constraints: ~1,500
```

## Multi-Party Supply Chain

A product passes through multiple companies. Each contributes data, but shouldn't see others' secrets:

```
Raw Material       Component          Assembly           Distribution
Supplier           Manufacturer       Factory            Company
   │                   │                 │                  │
   │ "Conflict-free    │ "Carbon <10kg   │ "All 5 checks   │ "Stored at
   │  minerals"        │  for this part" │  passed"         │  correct temp"
   │                   │                 │                  │
   ▼                   ▼                 ▼                  ▼
 ZK Proof 1         ZK Proof 2        ZK Proof 3         ZK Proof 4
   │                   │                 │                  │
   └──────────────────┴────────────────┴─────────────────┘
                              │
                    Aggregate DPP Proof
                    "All supply chain claims verified"
                              │
                        On Cardano
                    (product native token + proofs)
```

### Chain of Proofs

Each party generates their own ZK proof for their supply chain segment. The proofs are **independently verifiable** — the assembler doesn't need to know the raw material supplier's secrets, and vice versa.

```
Aggregation options:

Option A: Independent proofs (simple)
  Each proof is a separate on-chain reference.
  Verifier checks all proofs independently.
  Cost: N × ~0.3 ADA (one tx per proof)

Option B: Recursive proof (advanced)
  Each party's proof includes the previous party's proof hash.
  Final proof attests to the entire chain.
  Cost: 1 × ~0.3 ADA (one tx for entire chain)
  Requires: recursive SNARK or proof aggregation circuit

Option C: Merkle tree of proofs (balanced)
  All proofs hashed into a Merkle tree.
  Root stored on-chain. Individual proofs verifiable via Merkle path.
  Cost: 1 × ~0.3 ADA + storage for root
```

**Recommended**: Option A for simplicity. Each party submits their proof independently. The product's DPP metadata references all proof hashes.

## Cardano-Native DPP Architecture

### Native Tokens as Product IDs

Every physical product gets a Cardano native token:

```
Policy ID:  manufacturer's minting policy (acts as brand authentication)
Asset Name: "ProductModel_SerialNumber_BatchID"
Quantity:   1 (always — unique product)

Metadata (CIP-25/CIP-68):
{
  "name": "Widget X - SN:ABC123",
  "dpp_hash": "0x8f4a...",           // hash of full DPP document
  "dpp_url": "ipfs://QmXxxx",        // link to full DPP
  "compliance_proofs": [              // ZK proof references
    "0xproof_recycled...",
    "0xproof_carbon...",
    "0xproof_inspections..."
  ],
  "carbon_category": "low",          // public category
  "recycled_content": ">30%",        // public range
  "repairability": 8                  // public score
}
```

**Why native tokens**: No smart contract needed for product identity. Policy ID = manufacturer authentication. Unforgeable. Transferable (product changes ownership).

### Product Lifecycle as UTXO State Machine

```
MANUFACTURED ──▶ IN_TRANSIT ──▶ AT_RETAIL ──▶ SOLD ──▶ REPAIRED ──▶ RECYCLED
     │               │              │           │          │            │
  Create           Transfer       Transfer    Transfer   Update       Burn
  token +          to next        to          to         metadata     token
  initial          party          retailer    consumer   (repair      (end
  DPP proofs       + segment                  + warranty  proof)      of life)
                   proof
```

Each state transition is a Cardano transaction. The product's native token moves between addresses, and new proofs/metadata are attached at each step.

### On-Chain vs Off-Chain Data Split

```
On-Chain (Cardano):                          Off-Chain (IPFS / Company Server):
├─ Product native token                      ├─ Full DPP document (PDF, JSON)
├─ DPP hash (commitment to full document)    ├─ High-resolution images
├─ ZK proof references (compliance claims)   ├─ Repair manuals
├─ Public metadata (categories, ratings)     ├─ Full supply chain audit trail
├─ State machine transitions                 ├─ Lab test reports
└─ Issuer/auditor signatures                 └─ Inspector documentation
```

**Binding**: The on-chain DPP hash commits to the off-chain document. If the document changes, the hash changes. Tamper-evident.

## UTXO Design

### No Contention (Unlike Voting/Transfers)

DPP verification is **stateless** — like credential verification:

```
Product A verified → uses Product A's token UTXO only
Product B verified → uses Product B's token UTXO only
                     (fully parallel, no shared state)
```

Each product is its own UTXO. Verification reads the product's metadata and checks the ZK proofs. No shared registry to contend for.

### Auditor Registry (Reference Input)

```
Auditor Registry UTXO (read-only via CIP-31):
  Datum: {
    approved_auditors: [
      { name: "ISO-Lab-1", pubkey: 0x1234..., cert_type: "carbon" },
      { name: "SGS",       pubkey: 0x5678..., cert_type: "quality" },
      { name: "Bureau Veritas", pubkey: 0x9ABC..., cert_type: "minerals" }
    ]
  }
```

Reference input — never consumed, never contended. Multiple products can reference the same auditor list simultaneously.

## Smart Contract Code (Julc)

### DPP Compliance Verifier

```java
@SpendingValidator
public class DppComplianceGate {

    // Groth16 VK for compliance proof
    @Param static byte[] vkAlpha;
    @Param static byte[] vkBeta;
    @Param static byte[] vkGamma;
    @Param static byte[] vkDelta;
    @Param static PlutusData vkIc;

    record ComplianceProof(
        byte[] piA, byte[] piB, byte[] piC,
        BigInteger isCompliant
    ) {}

    @Entrypoint
    static boolean validate(PlutusData datum, ComplianceProof proof, PlutusData ctx) {
        // 1. Verify ZK proof (BLS12-381 pairing check)
        boolean proofValid = verifyGroth16(
            proof.piA(), proof.piB(), proof.piC(),
            proof.isCompliant());

        // 2. Must be compliant
        boolean compliant = proof.isCompliant().equals(BigInteger.ONE);

        // 3. (Optional) Check product token is in the transaction
        //    Ensures the proof is for THIS product, not copied from another

        return proofValid && compliant;
    }
}
```

### Product Lifecycle Validator (State Machine)

```java
@SpendingValidator
public class ProductLifecycle {

    @Param static byte[] manufacturerPolicyId;

    record ProductDatum(
        int state,            // 0=manufactured, 1=transit, 2=retail, 3=sold, 4=repaired, 5=recycled
        byte[] dppHash,       // hash of current DPP document
        byte[][] proofRefs    // ZK proof hashes for compliance claims
    ) {}

    @Entrypoint
    static boolean validate(ProductDatum datum, PlutusData redeemer, PlutusData ctx) {
        int currentState = datum.state();
        int nextState = extractNextState(redeemer);

        // Valid state transitions
        boolean validTransition = switch (currentState) {
            case 0 -> nextState == 1;                    // manufactured → transit
            case 1 -> nextState == 1 || nextState == 2;  // transit → transit or retail
            case 2 -> nextState == 3;                    // retail → sold
            case 3 -> nextState == 4 || nextState == 5;  // sold → repaired or recycled
            case 4 -> nextState == 3 || nextState == 5;  // repaired → sold again or recycled
            default -> false;
        };

        // Product token must be present (authenticity)
        boolean hasToken = checkTokenPresent(ctx, manufacturerPolicyId);

        // DPP hash must be updated (new proofs may be added)
        boolean dppUpdated = extractOutputDppHash(ctx).length > 0;

        return validTransition && hasToken && dppUpdated;
    }
}
```

## ZK Circuits (CircuitSpec)

### Generic Compliance Proof Circuit

A reusable circuit for any threshold-based compliance claim:

```java
public class ComplianceThresholdCircuit implements CircuitSpec {
    private final int numMeasurements;

    public ComplianceThresholdCircuit(int numMeasurements) {
        this.numMeasurements = numMeasurements;
    }

    @Override
    public void define(SignalBuilder c) {
        // Secret: actual measurements (commercially sensitive)
        Signal[] measurements = new Signal[numMeasurements];
        for (int i = 0; i < numMeasurements; i++) {
            measurements[i] = c.privateInput("measurement_" + i);
        }
        Signal auditorSignature = c.privateInput("auditorSig");

        // Public: threshold and auditor identity
        Signal threshold   = c.publicInput("threshold");
        Signal auditorKey  = c.publicInput("auditorKey");
        Signal productId   = c.publicInput("productId");

        // Public output
        Signal isCompliant = c.publicOutput("isCompliant");

        // 1. Compute aggregate (sum, average, etc.)
        Signal total = measurements[0];
        for (int i = 1; i < numMeasurements; i++) {
            total = total.add(measurements[i]);
        }

        // 2. Verify auditor signed the measurements
        Signal dataHash = measurements[0];
        for (int i = 1; i < numMeasurements; i++) {
            dataHash = SignalPoseidon.hash(c, dataHash, measurements[i]);
        }
        // (auditor signature verification — Poseidon-signed for now)

        // 3. Check threshold
        Signal passes = SignalComparators.greaterOrEqual(c, total, threshold, 64);
        c.assertEqual(isCompliant, passes);
    }

    public static CircuitBuilder build(int numMeasurements) {
        var builder = CircuitBuilder.create("compliance-threshold")
                .publicVar("threshold")
                .publicVar("auditorKey")
                .publicVar("productId")
                .publicVar("isCompliant")
                .secretVar("auditorSig");

        for (int i = 0; i < numMeasurements; i++) {
            builder = builder.secretVar("measurement_" + i);
        }
        return builder.defineSignals(new ComplianceThresholdCircuit(numMeasurements));
    }
}
```

### Multi-Checkpoint Inspection Circuit

```java
public class InspectionChainCircuit implements CircuitSpec {
    private final int numCheckpoints;

    public InspectionChainCircuit(int numCheckpoints) {
        this.numCheckpoints = numCheckpoints;
    }

    @Override
    public void define(SignalBuilder c) {
        Signal productId   = c.publicInput("productId");
        Signal inspectorRoot = c.publicInput("inspectorRoot");
        Signal allPassed   = c.publicOutput("allPassed");

        Signal prevTimestamp = c.constant(0);

        for (int i = 0; i < numCheckpoints; i++) {
            Signal passed    = c.privateInput("passed_" + i);
            Signal timestamp = c.privateInput("timestamp_" + i);
            Signal inspector = c.privateInput("inspector_" + i);

            // Each inspection must pass
            c.assertEqual(passed, c.constant(1));

            // Timestamps must be in order
            Signal orderOk = SignalComparators.greaterThan(c, timestamp, prevTimestamp, 64);
            c.assertEqual(orderOk, c.constant(1));
            prevTimestamp = timestamp;

            // Inspector must be approved (Merkle proof would go here)
        }

        c.assertEqual(allPassed, c.constant(1));
    }
}
```

## Full Transaction Flow

### 1. Product Manufacturing

```
Manufacturer:
  1. Produce product
  2. Collect measurements (carbon, materials, inspections)
  3. Get auditor to sign measurements
  4. Generate ZK proofs for each compliance claim
  5. Create DPP document (JSON + proofs)
  6. Mint product native token with DPP metadata

Transaction:
  Mint: 1 native token (policyId: manufacturer, name: "Product_SN123")
  Metadata: { dpp_hash: 0x..., proofs: [...], carbon: "low", recycled: ">30%" }
  Output: Product UTXO at manufacturer address
```

### 2. Supply Chain Transfer

```
Each supply chain party:
  1. Receive product (consume UTXO)
  2. Add their segment proof (e.g., "stored at correct temperature")
  3. Transfer to next party (create new UTXO)

Transaction:
  Input: Product UTXO (from previous party)
  Output: Product UTXO (at next party's address)
  Metadata updated: + new proof hash for this segment
```

### 3. Consumer Verification

```
Consumer scans QR code on product:
  1. QR → Cardano transaction hash
  2. Look up product native token
  3. Read metadata: DPP hash, proof references, public claims
  4. Verify each ZK proof (off-chain, ~2ms per proof)
  5. Display: "Verified ✓ — Low carbon, >30% recycled, 5/5 inspections passed"
```

### 4. Regulator Audit

```
Regulator:
  1. Query all products from manufacturer (by policy ID)
  2. Verify ZK proofs on-chain or off-chain
  3. If suspicious: request full data from manufacturer (off-chain)
  4. Manufacturer provides secret inputs → regulator verifies they match the proof
  5. If fraud: proof hash on-chain is immutable evidence
```

## Cost Analysis

| Operation | Cost | Who Pays |
|-----------|------|----------|
| Mint product token + initial DPP | ~0.5 ADA | Manufacturer |
| Each compliance ZK proof submission | ~0.3 ADA | Claiming party |
| Supply chain transfer (per segment) | ~0.3 ADA | Transferring party |
| Consumer verification | Free (off-chain) | — |
| Regulator audit | Free (on-chain data is public) | — |

**Per-product total**: ~2-3 ADA for a 5-segment supply chain with 3 compliance proofs. At scale (millions of products), this is pennies per product.

## Security and Trust Model

| Party | Trusts | Doesn't Need to Trust |
|-------|--------|----------------------|
| **Consumer** | ZK math, Cardano consensus | Manufacturer's claims (proof replaces trust) |
| **Regulator** | Auditor signatures, ZK proofs | Self-reported data |
| **Manufacturer** | Auditor (who signs measurements) | Competitors seeing their data |
| **Competitor** | Nothing — can't extract secrets from proofs | — |

### What If the Auditor Lies?

The auditor signs the measurement data. If they sign false data:
- The ZK proof will verify (it proves the signed data meets the threshold)
- But the **underlying data is false**
- **Mitigation**: Multiple independent auditors, auditor reputation/insurance, regulatory spot-checks
- This is the same trust model as today's ISO auditing — ZK doesn't make it worse, just adds privacy

## Standards Compatibility

| Standard | How DPP Uses It |
|----------|----------------|
| **EU ESPR** | Regulatory framework — defines what DPP must contain |
| **GS1 EPCIS** | Supply chain event tracking (compatible with UTXO lifecycle) |
| **ISO 22095** | Chain of custody framework (maps to multi-party proof chain) |
| **CIP-25/CIP-68** | Cardano metadata standards for product tokens |
| **W3C VC** | Auditor certifications as verifiable credentials |
| **IPFS** | Off-chain DPP document storage |

## Architecture Recommendation

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  PRODUCT IDENTITY                                                    │
│  Cardano native token (policy ID = manufacturer, name = serial)     │
│                                                                      │
│  DPP METADATA (CIP-25)                                               │
│  Public: categories, ratings, proof hashes                           │
│  Link: IPFS hash of full DPP document                                │
│                                                                      │
│  COMPLIANCE PROOFS (Groth16 BLS12-381)                               │
│  Each claim → separate ZK proof → hash stored in metadata            │
│  Proof size: 192 bytes each, constant regardless of data complexity  │
│                                                                      │
│  LIFECYCLE (UTXO state machine)                                      │
│  manufactured → transit → retail → sold → repaired → recycled        │
│  Each transition: transfer token + update metadata + new proofs      │
│                                                                      │
│  VERIFICATION                                                        │
│  Consumer: scan QR → verify proofs off-chain (free, instant)         │
│  Regulator: query by policy ID → verify on-chain proofs              │
│  Auditor: sign measurements → ZK proof generated by manufacturer     │
│                                                                      │
│  NO CONTENTION                                                       │
│  Each product = independent UTXO. Fully parallel verification.       │
│  Auditor registry = reference input (CIP-31). Never consumed.        │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Why Cardano Is Ideal for DPP

1. **Native tokens** = product IDs without smart contracts
2. **UTXO model** = natural product lifecycle (each product is independent)
3. **CIP-25/CIP-68** = standardized DPP metadata
4. **Plutus V3 + BLS12-381** = on-chain ZK proof verification
5. **Reference inputs (CIP-31)** = read auditor registry without contention
6. **Low fees** = ~2 ADA per product lifecycle (practical at scale)
7. **No contention** = every product verification is independent

---

## Comparison with Cardano Foundation DPP Blueprint

The [Cardano Foundation DPP Standards](https://github.com/cardano-foundation/cardano-dpp-standards) project defines a blueprint for implementing Digital Product Passports on Cardano. This section compares both approaches and shows how ZK proofs enhance the CF blueprint.

### Two Approaches to the Same Problem

Both approaches target EU ESPR compliance and share foundational design choices (native tokens, CIP-25/CIP-68 metadata, IPFS for off-chain storage). They differ in **how compliance claims are verified**:

```
CF Blueprint Approach: DATA ANCHORING
  "Here's a hash of our DPP data. We can selectively reveal specific data branches."

  Manufacturer → hash(full_dpp) → on-chain anchor
                 Merkle tree of claims → selective disclosure to verifier
                 Verifier receives: exact value + Merkle proof of inclusion

ZK Approach: PROOF OF COMPLIANCE
  "Here's a mathematical proof that our data meets all requirements."

  Manufacturer → ZK proof(secret_data, threshold) → on-chain anchor
                 Verifier receives: 192-byte proof + "compliant: YES"
                 Verifier NEVER sees: exact values, supplier names, or raw data
```

### Shared Foundation

Both frameworks agree on these Cardano-native patterns:

| Pattern | CF Blueprint | ZK Approach |
|---------|-------------|-------------|
| Product identity | Native token (policy ID = manufacturer) | Same |
| Metadata standard | CIP-25 / CIP-68 | Same |
| Off-chain storage | IPFS for full DPP document | Same |
| EU ESPR alignment | Explicit regulatory mapping | Same |
| Personas | Manufacturer, consumer, regulator, recycler | Same |
| QR/NFC linking | GS1 Digital Link | Compatible |

### Where ZK Enhances the CF Blueprint

#### 1. Exact Value Privacy

The fundamental difference: Merkle selective disclosure reveals the exact value to the verifier. ZK proofs don't.

```
Scenario: "Prove recycled content >= 30%"

CF Blueprint (Merkle Disclosure):
  Manufacturer discloses: recycled_content = 42.7%
  Merkle proof confirms: 42.7% is in the DPP data
  ✓ Regulator verifies: 42.7% >= 30% → compliant
  ✗ Problem: Competitor now knows exact efficiency (42.7%)

ZK Approach:
  Manufacturer generates: ZK proof that recycled_content >= 30
  Proof is 192 bytes. Contains NO data about the actual percentage.
  ✓ Regulator verifies: proof valid → compliant
  ✓ Competitor learns: nothing (could be 30.1% or 99.9%)
```

This matters for **every numeric compliance claim**:

| Claim | CF Reveals | ZK Reveals |
|-------|-----------|-----------|
| "Recycled >= 30%" | Exact: 42.7% | Only: "≥ 30%" |
| "Carbon < 50kg" | Exact: 42.7 kg | Only: "< 50kg" |
| "Degradation < 20% at 500 cycles" | Exact: 18.3% | Only: "< 20%" |
| "5 inspections passed" | Inspector names, dates, details | Only: "all 5 passed" |

#### 2. Supplier Anonymity

Merkle tree structure leaks information about the data schema. A Merkle proof path reveals which branches exist.

```
CF Blueprint:
  Merkle tree: hash(supplier_A) | hash(supplier_B) | hash(supplier_C)
  To prove "supplier_A is conflict-free":
    → Must reveal supplier_A's data + Merkle path
    → Path reveals tree has 3 suppliers (structural leak)

ZK Approach:
  Circuit: "ALL suppliers in my list are NOT in the conflict country set"
  Proof reveals: nothing about how many suppliers, who they are, or where they are
  Verifier sees: "conflict_free = true" (that's it)
```

#### 3. Composite Claims

Multiple claims can be proven in a single ZK proof:

```
CF Blueprint:
  Claim 1: recycled >= 30%    → Merkle proof 1 (reveals exact %)
  Claim 2: carbon < 50kg      → Merkle proof 2 (reveals exact kg)
  Claim 3: 5 inspections      → Merkle proof 3 (reveals inspector data)
  Total: 3 separate disclosures, each leaking exact values

ZK Approach:
  Single circuit: "recycled >= 30% AND carbon < 50kg AND 5 inspections passed"
  Single proof: 192 bytes
  Reveals: "all_compliant = true" — nothing else
```

#### 4. Auditor Isolation

In the CF model, the auditor sees raw data and provides a Merkle attestation. If the auditor is compromised or colluding with a competitor, the data is exposed.

```
CF Blueprint:
  Auditor receives: full DPP data (carbon=42.7, suppliers=[A,B,C], ...)
  Auditor produces: signed Merkle root
  Risk: Auditor leaks data to competitor or regulator overshares

ZK Approach:
  Auditor receives: full data (same)
  Auditor signs: hash of the data
  Manufacturer generates: ZK proof from signed data
  Key difference: The PROOF doesn't contain the data.
                  Even if the proof is leaked, no data is exposed.
                  The auditor's signature proves data authenticity
                  without the proof revealing what was signed.
```

### Where the CF Blueprint Has Advantages

| Advantage | CF Blueprint | ZK Approach |
|-----------|-------------|-------------|
| **Simplicity** | No circuit development, no prover infrastructure | Requires ZK circuit design + trusted setup |
| **Cost per product** | ~1-2 ADA | ~2-3 ADA (50% more) |
| **Verification speed** | Hash check: ~1ms | ZK verify: ~2ms off-chain, ~5ms on-chain |
| **Standards maturity** | GS1 Digital Link explicitly mapped | Should add GS1 EPCIS mapping |
| **Developer onboarding** | Hash + IPFS (familiar to most devs) | ZK circuits (specialized knowledge) |
| **Regulatory clarity** | Clear ESPR-to-metadata field mapping | Needs explicit regulatory mapping doc |

### CF Blueprint Solution Patterns

The CF blueprint defines four solution patterns:

| CF Pattern | How It Works | ZK Enhancement |
|------------|-------------|----------------|
| **Static Anchor** | Hash DPP data → store hash in metadata | Add ZK proof hash alongside data hash — proves compliance without revealing data |
| **Anchored Proof** | Merkle tree of claims → root in metadata | Replace Merkle disclosure with ZK proof — verifier gets "compliant: YES" instead of exact values |
| **Event Log** | Append-only chain of supply chain events | Each event can carry a ZK proof — "temperature was in range" without revealing exact temp |
| **High Throughput** | Batch roots for high-volume manufacturing | Batch ZK proofs — prove 1000 products compliant in one aggregate proof |

### When to Use Which Approach

| Scenario | Better Approach | Why |
|----------|----------------|-----|
| **Commodity products** (simple compliance, no competitive secrets) | CF Blueprint | Simpler, cheaper, transparency expected |
| **Electronics/pharma** (competitive manufacturing data) | **ZK Approach** | Exact carbon, efficiency, defect rates are trade secrets |
| **Luxury goods** (supplier relationships are valuable) | **ZK Approach** | Supplier anonymity critical for brand positioning |
| **Automotive** (complex multi-tier supply chain) | **ZK Approach** | Each tier proves compliance without revealing to others |
| **Consumer-facing transparency** (organic food, fair trade) | CF Blueprint | Consumers want full disclosure, not proofs |
| **Cross-border compliance** (EU + US + China regulations) | **ZK Approach** | One proof satisfies multiple regulators with different thresholds |
| **High-volume manufacturing** (millions of units) | Either | CF is cheaper per unit; ZK adds privacy but at cost |

### Complementary, Not Competing

The best DPP implementation **combines both approaches**:

```
Product DPP = Public Data (CF Blueprint) + Confidential Claims (ZK Proofs)

PUBLIC LAYER (CF Blueprint patterns):
├─ Product ID (native token)
├─ Manufacturer name and country
├─ Certification statuses (REACH, RoHS)
├─ Repairability score (0-10)
├─ Spare parts availability
├─ DPP document hash (IPFS)
└─ GS1 Digital Link (QR code)

CONFIDENTIAL LAYER (ZK Proofs):
├─ "Carbon footprint < 50kg" (exact hidden)
├─ "Recycled content >= 30%" (exact hidden)
├─ "All 5 inspections passed" (details hidden)
├─ "No conflict minerals" (suppliers hidden)
└─ "Made in EU" (specific factory hidden)
```

The public layer uses the CF blueprint's metadata anchoring (simple, cheap, transparent). The confidential layer uses ZK proofs for claims where exact values or supplier details are commercially sensitive.

**Both layers reference the same product native token and use the same CIP-25/CIP-68 metadata standard.** They're additive — a product can have some claims as public data and others as ZK proofs, depending on sensitivity.

### Implementation Roadmap

```
Phase 1 (Today):
  Use CF blueprint patterns for public DPP data
  → Native token + CIP-25 metadata + IPFS document
  → Simple, compliant, works now

Phase 2 (Add ZK for sensitive claims):
  Add ZK proofs for competitive data
  → "Carbon < 50kg" proof alongside public carbon category
  → "Recycled >= 30%" proof alongside public range
  → Uses ZeroJ pure Java prover (no external tools)

Phase 3 (Full integration):
  Multi-party supply chain with ZK proofs per segment
  → Each supplier proves their claims independently
  → Product DPP aggregates all proofs
  → On-chain verification via Plutus V3 (optional)
```

### References

- [Cardano Foundation DPP Standards](https://github.com/cardano-foundation/cardano-dpp-standards) — Blueprint, personas, and solution patterns
- [EU ESPR Regulation](https://environment.ec.europa.eu/topics/circular-economy/ecodesign-sustainable-products-regulation_en) — Digital Product Passport mandate
- [GS1 Digital Link](https://www.gs1.org/standards/gs1-digital-link) — QR/NFC resolver standard
- [CIP-25](https://cips.cardano.org/cip/CIP-0025) — Cardano NFT metadata standard
- [CIP-68](https://cips.cardano.org/cip/CIP-0068) — Datum standard NFT metadata

# Aiken ZKP Standards Library Specification

## Rationale

The Aiken ZKP Standards Library is designed with a pragmatic approach to feature implementation. We distinguish between our committed features (those we are confident we can deliver) and aspirational features (those we will pursue if resources and technical constraints allow).

The library's design explicitly acknowledges current technological constraints while preparing for future advancements:

* **Proven Technologies:** Utilizing well-understood ZKP constructions with existing implementation precedents
* **Scalable Architecture:** Designing for future optimizations and protocol upgrades
* **Resource Awareness:** Careful consideration of on-chain costs and computational requirements
* **Progressive Enhancement:** Supporting basic functionality first with clear upgrade paths for advanced features

Through this rationale, we commit to delivering a ZKP library that serves immediate practical needs while establishing a foundation for future zero-knowledge applications on Cardano.

We chose 3 protocols that we felt best aligned with these principles:

### Groth16
Groth is one of the most mature, proven protocols in the ZK space. It was introduced in 2016 and was one of the first protocols to make SNARKs efficient, providing constant-space proofs and constant-time verifications. It’s also one of the few examples of trusted setup protocols still in use today. We chose Groth as a proven, resource-aware example of a trusted-setup zk protocol.

### Plonk
Plonk revolutionized the ZK space when it was introduced in 2019. Since then, numerous Plonk-inspired protocols have appeared, such as Plonky2, Hyperplonk, HALO, and more. The key innovation of Plonk was its support for custom gates, allowing for much more complexity. This improvement also came with significant improvements to efficiency. We chose Plonk as an iconic, resource aware, scalable and progressively enhanceable, universal-setup protocol.

### Bulletproofs
Bulletproofs shine through their versatility. They’re small in size, easily aggregated, and compatible with just about any secure elliptic curve. Despite being around since 2017, they also use a fully transparent setup, similar to modern STARKS. Bulletproofs are proven, scalable, resource aware, and ideal for progressive enhancement.

## Functionalities

The library's scope has been carefully defined through a systematic evaluation process:

### Committed Features

#### Groth16
- Provide a generic Groth16 proof verifier system in Aiken which supports user-defined circuits leveraging circom and SnarkJS
- Provide an example circuit and R1CS constraint set for the Groth16 verifier to show the entire process of creating and verifying a Groth16 proof
- Provide a test suite that demonstrates the ability of the proof system to successfully verify the generated proof, while denying validation of invalid proofs

#### Plonk
- Provide a generic Plonk proof verifier system in Aiken which supports user-defined circuits leveraging circom and SnarkJS
- Provide an example circuit and R1CS constraint set for the Plonk verifier to show the entire process of creating and verifying a Plonk proof
- Provide a test suite that demonstrates the ability of the proof system to successfully verify the generated proof, while denying validation of invalid proofs

#### Bulletproofs
- Provide a generic Bulletproof verifier system in Aiken which supports user-defined circuits leveraging circom and SnarkJS
- Provide an example circuit and R1CS constraint set for the Bulletproof verifier to show the entire process of creating and verifying a Bulletproof
- Provide a test suite that demonstrates the ability of the proof system to successfully verify the generated proof, while denying validation of invalid proofs

### Non-Committed / Aspirational Features

#### Marlin
- We would like to explore "Marlin: Preprocessing zkSNARKs with Universal and Updatable SRS", but this work is aspirational and depends on additional research, development resources, and proven implementations in the broader ZKP ecosystem

#### Plonky2
- We would like to explore Plonky2, but this work is aspirational and depends on future technological advancements in recursive proof composition and improvements in proof generation efficiency

## Implementation

### On-Chain

Our on-chain implementation will be supported largely by the new builtin functions provided by PlutusV3 that relate to the BLS12-381 curve. Some of the type signatures for both type definitions and functions of the library can be found within the `.ak` files throughout the rest of the repository. These implementations will focus on efficient verification while maintaining security guarantees.

### Off-Chain

Given that this library is specific to Aiken, the off-chain implementation is highly dependent upon the design choices and requirements of the user. We will be providing examples using circom, but support for general purpose proof creation is outside the scope of this work. Users will need to implement their own proof generation infrastructure using tools like circom and SnarkJS while following our provided examples as guidance.

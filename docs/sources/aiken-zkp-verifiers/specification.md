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

### Delivered Features

All three verifiers below are implemented, covered by unit and property-based tests (64/64 tests passing, both positive and negative cases), and build cleanly under `aiken check`/`aiken build`. Each is **verification-only**: none of the three includes a proof-generation toolchain, and Groth16/Plonk additionally require a trusted-setup ceremony (circuit-specific and universal, respectively) that this library does not run or provide. Full architecture, design rationale, and security arguments for each are written up in `zkp/docs/`.

#### Groth16
- A generic Groth16 proof verifier in Aiken (`zkp/lib/groth`) that accepts any circuit-specific verification key and proof — including ones produced by an external circom + SnarkJS toolchain — without this library needing any knowledge of the circuit itself
- A test suite verifying real, externally-generated Groth16 proofs, and correctly rejecting a tampered one, plus property-based tests that any changed public input or replaced proof point is rejected
- See `zkp/docs/groth16-implementation-report.md`

#### Plonk
- A generic Plonk proof verifier in Aiken (`zkp/lib/plonk`), including a batched KZG opening and a Keccak-256 Fiat–Shamir transcript compatible with SnarkJS's Plonk verifier convention
- A test suite verifying a real, externally-generated Plonk proof, and correctly rejecting both a tampered proof and a mismatched public-input list, plus property-based tests that any changed public input or evaluation scalar is rejected
- See `zkp/docs/plonk-implementation-report.md`

#### Bulletproofs
- A generic Bulletproofs range-proof verifier *and* reference prover in Aiken (`zkp/lib/bullet`) — the only one of the three with no trusted setup, so this library implements and tests both sides directly, with no external fixtures required
- A test suite covering valid proofs, boundary values (0 and `2^n - 1`), and multiple tampering/rejection cases, plus property-based tests that every in-range value can be proven and that tampered proofs and other commitments are rejected
- See `zkp/docs/bulletproofs-implementation-report.md`

### Non-Committed / Aspirational Features

#### Marlin
- We would like to explore "Marlin: Preprocessing zkSNARKs with Universal and Updatable SRS", but this work is aspirational and depends on additional research, development resources, and proven implementations in the broader ZKP ecosystem

#### Plonky2
- We would like to explore Plonky2, but this work is aspirational and depends on future technological advancements in recursive proof composition and improvements in proof generation efficiency

## Implementation

Our implementation will be supported largely by the new builtin functions provided by PlutusV3 that relate to the BLS12-381 curve. Some of the type signatures for both type definitions and functions of the library can be found within the `.ak` files throughout the rest of the repository. These implementations will focus on efficient verification while maintaining security guarantees. See `zkp/docs/` for a full implementation report per protocol, covering architecture, design decisions, and security arguments.

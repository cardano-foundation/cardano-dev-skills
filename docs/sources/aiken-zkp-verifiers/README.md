# Aiken ZKP Standards Library

A standards-compliant Zero-Knowledge Proof (ZKP) library for Cardano smart contracts, implemented in Aiken. This library enables efficient on-chain verification while maintaining robust security guarantees.

## Project Overview

The Aiken ZKP Standards Library takes a pragmatic approach to implementing zero-knowledge proof systems on Cardano. We distinguish between committed features (current targets) and aspirational features (planned for future development).

This implementation is designed for Plutus v3, leveraging its built-in BLS12-381 curve functions to ensure efficient and secure verification of ZKPs. It emphasizes clarity and maintainability, making it suitable for educational/demonstrative purposes without sacrificing security.

## Status

All three verifiers are functional, covered by unit and property-based tests, and build cleanly (`aiken check` / `aiken build`, 64/64 tests passing). Known input-validation issues are tracked as [open issues](https://github.com/ADAOcommunity/zk/issues) and pinned by `known_issue_*` tests. Each is **verification-only**: proof generation, circuit compilation, and (for Groth16/PLONK) trusted setup are assumed to happen off-chain, using external tooling this library does not provide. Full architecture, security arguments, and known limitations for each are written up in [`zkp/docs/`](./zkp/docs).

### Groth16

Status: Complete (verifier)

The Groth16 implementation ([`zkp/lib/groth`](./zkp/lib/groth)) is largely based on Modulo-P's [ak-381](https://github.com/Modulo-P/ak-381), with some ideas taken from [tarassh's implementation](https://github.com/tarassh/zkSNARK-under-the-hood/blob/main/groth16.py), and operates on native BLS12-381 pairing builtins throughout. It's tested against externally-generated proof/verification-key fixtures, both accepting valid proofs and rejecting a tampered one. [Implementation report](./zkp/docs/groth16-implementation-report.md).

- [x] Generic Groth16 proof verifier system
- [x] Onchain verification tests

Wishlist:

- [ ] Integration examples with circom and SnarkJS
- [ ] Integration into a merkelized validator

### Plonk

Status: Optimizing

The Plonk implementation ([`zkp/lib/plonk`](./zkp/lib/plonk)) is loosely based on perturbing's [plutus-plonk-example](https://github.com/perturbing/plutus-plonk-example), with several optimizations and restructuring done around point compression to improve performance and clarity, a batched KZG opening, and a Keccak-256 Fiat–Shamir transcript matching the SnarkJS convention. It's tested against an externally-generated proof/verification-key fixture, including rejection of tampered proofs and mismatched public inputs. [Implementation report](./zkp/docs/plonk-implementation-report.md).

At current measurements, a full verification call is the most expensive of the three verifiers in this library (§7 of the implementation report) and leaves the least headroom against Cardano's per-transaction execution budget — hence "Optimizing" rather than "Complete."

- [x] Generic Plonk proof verifier system
- [x] Onchain verification tests

Wishlist:

- [ ] Optimize further to fit within Plutus resource limits
- [ ] Integration examples with circom and SnarkJS
- [ ] Integration into a merkelized validator

### Bulletproofs

Status: Complete (verifier and reference prover)

The Bulletproofs implementation ([`zkp/lib/bullet`](./zkp/lib/bullet)) is the only one of the three with no trusted setup, so this library implements and tests both a verifier *and* a reference prover directly, with no external fixtures required. [Implementation report](./zkp/docs/bulletproofs-implementation-report.md).

- [x] Generic Bulletproofs range-proof verifier and reference prover
- [x] Onchain verification tests, including boundary values and tamper rejection

Wishlist:

- [ ] Recursive inner-product-argument (IPA) compression, for `O(log n)` rather than `O(n)` proof size
- [ ] Integration into a merkelized validator

### Helper Functions

- Affine point operations - conversion to/from native types (`zkp/lib/common/blst_affine.ak`)
- Field arithmetic utilities (`zkp/lib/common/common.ak`) — largely superseded by native BLS12-381 builtins inside the three verifiers above; see the implementation reports for where and why. The verifiers use only its BLS12-381 constants and three small helpers (tested in `zkp/lib/tests/common_tests.ak`); the rest is legacy code with known defects ([#20](https://github.com/ADAOcommunity/zk/issues/20))

## Aspirational ZKP Systems

- **Marlin**: Preprocessing zkSNARKs with Universal and Updatable SRS
- **Plonky2**: Advanced recursive proof composition

## Implementation

- Leverages PlutusV3's BLS12-381 curve builtin functions
- Focuses on efficient verification
- Maintains strong security guarantees
- See the per-protocol implementation reports in [`zkp/docs/`](./zkp/docs) for details

## Getting Started

### Prerequisites

- Aiken development environment
- Familiarity with ZKP systems
- Understanding of Cardano smart contracts

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for:

- Development guidelines
- Submission process
- Testing requirements

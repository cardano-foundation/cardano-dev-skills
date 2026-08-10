# Aiken ZKP Standards Library

A standards-compliant Zero-Knowledge Proof (ZKP) library for Cardano smart contracts, implemented in Aiken. This library enables efficient on-chain verification while maintaining robust security guarantees.

## Project Overview

The Aiken ZKP Standards Library takes a pragmatic approach to implementing zero-knowledge proof systems on Cardano. We distinguish between committed features (current targets) and aspirational features (planned for future development).

This implementation is designed for Plutus v3, leveraging its built-in BLS12-381 curve functions to ensure efficient and secure verification of ZKPs. It emphasizes clarity and maintainability, making it suitable for educational/demonstrative purposes without sacrificing security.

## Targeted Features

### Groth16

Status: Complete

The Groth16 implementation is largely based on Modulo-P's [ak-381](https://github.com/Modulo-P/ak-381), with some ideas taken from [zarassh's implementation](https://github.com/tarassh/zkSNARK-under-the-hood/blob/main/groth16.py) and an emphasis on explicitness and clarity. This should make this implementation ideal for learning, or for further modification.

Currently, the Groth16 module includes:

- [x] Generic Groth16 proof verifier system
- [x] Onchain verification tests

Wishlist:

- [ ] Integration examples with circom and SnarkJS
- [ ] Integration into a merkelized validator

### Plonk

Status: Optimizing

The Plonk implementation is loosely based on perturbing's [plutus-plonk](https://github.com/perturbing/plutus-plonk-example), with several optimizations and restructuring done around point compression to improve performance and clarity.

The Plonk module currently includes:

- [x] Generic Plonk proof verifier system
- [x] Onchain verification tests

Wishlist:

- [ ] Optimize further to fit within Plutus resource limits
- [ ] Integration examples with circom and SnarkJS
- [ ] Integration into a merkelized validator

### Bulletproofs

Status: Early Development

The Bulletproofs implementation is in the early stages, with a focus on building out the necessary field arithmetic and point operations required for Bulletproofs.

### Helper Functions

- Affine point operations - conversion to/from native types
- Field arithmetic utilities

## Aspirational ZKP Systems

- **Marlin**: Preprocessing zkSNARKs with Universal and Updatable SRS
- **Plonky2**: Advanced recursive proof composition

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for:

- Development guidelines
- Submission process
- Testing requirements

### Prerequisites

- Aiken development environment
- Familiarity with ZKP systems
- Understanding of Cardano smart contracts

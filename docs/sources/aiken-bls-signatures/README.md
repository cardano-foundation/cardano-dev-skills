# High level BLS12-381 functions for Aiken

[![Licence](https://img.shields.io/github/license/aiken-lang/stdlib?style=for-the-badge)](https://github.com/ilap/bls/blob/main/LICENSE)
[![Continuous Integration](https://img.shields.io/github/actions/workflow/status/aiken-lang/stdlib/continuous-integration.yml?style=for-the-badge)](https://github.com/ilap/bls/actions/workflows/ci.yml)
[![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-Online-brightgreen?style=for-the-badge)](https://ilap.github.io/bls/)

## Introduction

Welcome to the BLS12-381 library for the Aiken smart-contract language! This library provides a comprehensive implementation of BLS12-381 signatures, enabling advanced cryptographic operations on the Cardano blockchain.

The library implements the three core BLS signature schemes as defined in the [IETF BLS Signature draft](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature):

- **Basic** (`g1/basic`): Standard BLS signatures
- **Message Augmentation** (`g1/aug`): Signatures with message augmentation for domain separation
- **Proof of Possession** (`g1/pop`): Signatures with PoP for rogue key attack resistance

### Implementation Status

Currently, this library implements the **Minimal-pubkey-size** variant as defined in the IETF draft:

- **Public keys**: Points in **G1** (48 bytes)
- **Signatures**: Points in **G2** (96 bytes)

This approach is **RECOMMENDED** for implementations using signature aggregation, since the size of `(PK_1, ..., PK_n, signature)` is dominated by the public keys even for small n. By keeping public keys in G1 (the smaller group), we minimize the overall size of aggregated verification data.

**_API Note_**: The core cryptographic primitives are implemented in the `g1/core` module, while the public interfaces are exposed through the scheme-specific modules.

## Implemented Functions

### Core Module (`g1/core`)

Low-level cryptographic primitives used by all schemes:

| Function                | Description                      |
| ----------------------- | -------------------------------- |
| `key_gen`               | Generate secret key from random  |
| `sk_to_pk`              | Convert secret key to public key |
| `key_validate`          | Validate a public key            |
| `core_sign`             | Core signing primitive           |
| `vore_verify`           | Core verification primitive      |
| `aggregate`             | Aggregate multiple signatures    |
| `core_aggregate_verify` | Core aggregate verification      |

### Basic Scheme (`g1/basic`)

Standard BLS signatures as specified in the IETF draft:

| Function           | Description                                        |
| ------------------ | -------------------------------------------------- |
| `sk_to_pk`         | Convert secret key to public key                   |
| `sign`             | Sign a message with private key                    |
| `verify`           | Verify a signature with public key                 |
| `aggregate`        | Combine multiple signatures                        |
| `aggregate_verify` | Verify aggregated signatures for distinct messages |

### Message Augmentation Scheme (`g1/aug`)

Signatures with message augmentation for domain separation:

| Function           | Description                                 |
| ------------------ | ------------------------------------------- |
| `sk_to_pk`         | Convert secret key to public key            |
| `sign`             | Sign a message with private key (augmented) |
| `verify`           | Verify a signature with public key          |
| `aggregate`        | Combine multiple signatures                 |
| `aggregate_verify` | Verify aggregated signatures                |

### Proof of Possession Scheme (`g1/pop`)

Signatures with PoP for rogue key attack resistance:

| Function           | Description                                             |
| ------------------ | ------------------------------------------------------- |
| `sk_to_pk`         | Convert secret key to public key                        |
| `sign`             | Sign a message with private key                         |
| `verify`           | Verify a signature with public key                      |
| `pop_prove`        | Generate Proof-of-Possession signature for a public key |
| `pop_verify`       | Verify a Proof-of-Possession signature                  |
| `aggregate`        | Combine multiple signatures                             |
| `aggregate_verify` | Verify aggregated signatures                            |

## Getting Started

To get started with this library, make sure you have the Aiken environment set up and add this library to your `aiken.toml`:

```toml
[dependencies]
ilap/bls = { version = "x.y.z" }
```

## Usage

Detailed usage examples and API documentation can be found in the [lib/bls/tests](https://github.com/ilap/bls/tree/main/lib/bls/tests) and docs directory (generated with `aiken docs`). Here is a quick example to get you started:

```aiken
use ilap/bls/g1/basic.{ sk_to_pk, sign, verify}

test test_bls () {
  let sk = #"ed69a93f0cf8c9836be3b67c7eeff416612d45ba39a5c099d48fa668bf558c9c"

  let pk = sk_to_pk(sk)
  let message = "Hello, Aiken!"

  let signature = sign(sk, message)

  verify(pk, message, signature)
}
```

## BLS12-381 Technical Brief

- **Embedding degree**: 12 i.e. the complexity of the pairing operation.
- **Field Size (𝑝)**: A large prime number defining the finite field i.e. 𝔽𝑝. The prime in the finite field is 381-bit.
- **Prime Order (r)**: The number of points on the curve e.g. `𝑦^2=𝑥^3+4` for `𝑥∈{0,𝔽𝑝−1}`. The number of points on the elliptic curve (excluding the point at infinity) is a prime number.
- **Security level**: BLS12-381 provides an approximate 128-bit security level, given that its complexity is around `≈√𝑟` i.e. `𝑟≈2^256`.
- **Private key**: A scalar in `𝔽𝑝` which means `∈{0,𝑝−1}`. The size is 381 bits ~48 bytes.
- **Identity Element**: The multiplicative identity (1).
- **Bilinear pairing** : A function `𝑒:𝐺1×𝐺2→𝐺𝑇` with the following properties:
  - **Non-degeneracy**: `𝑒(𝑔1,𝑔2)≠1` for some `𝑔1∈𝐺1` and `𝑔2∈𝐺2`.
  - **Bilinearity**: `𝑒(𝑎𝑔1,𝑏𝑔2)=𝑒(𝑔1,𝑔2)𝑎𝑏` for all `𝑎,𝑏∈𝔽𝑝` and `𝑔1∈𝐺1` and `𝑔2∈𝐺2`.
  - **Computability**: There exists an efficient algorithm to compute `𝑒(𝑔1,𝑔2)` for all `𝑔1∈𝐺1` and `𝑔2∈𝐺2`.

- **Group Definitions**:
  - **G1**: This group consists of points on the elliptic curve over the base field `𝐹𝑝` (`𝑦^2=𝑥^3+4`).
  - **G2**:: This group consists of points on the twisted curve over an extension field `𝐹𝑝^2` (`𝑦^2=𝑥^3+4(1+i)`).
  - **GT**: This is the multiplicative group of a larger field `𝐹𝑝12`, used as the result of the pairing operation.

## Resources

- [BLS Signatures Specification](https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature)

## Contributing

We welcome contributions to enhance the functionality and usabilioty of this library. Please refer to the [CONTRIBUTING.md](./CONTRIBUTING.md) file for guidelines on how to contribute.

## License

This project is licensed under the `Apache 2.0 License` - see the [LICENSE](./LICENSE) file for details.

---
title: Status & maturity
description: What ZeroJ's Beta, Experimental, Disabled and Assurance-only labels mean, the full support matrix, and what "not for production" means in practice.
sidebar:
  order: 4
---

ZeroJ is **experimental research software**. Some parts are feature-complete and
heavily tested; others are opt-in experiments. None of it has been externally audited. This page
tells you exactly where each component stands, so you can decide what is reasonable to build on
and what to treat as a prototype.

As the repository README states, ZeroJ is generated using AI, with human-assisted design, testing,
and verification. That's one more reason to treat every component as unaudited until an external
review says otherwise.

## What the labels mean

| Label | Meaning in ZeroJ |
|-------|------------------|
| **Beta** | Feature-complete and correctness-tested. The repository has more than 3,500 tests, and the full Groth16 flow is verified end-to-end on-chain against Yaci DevKit. **Not externally audited, and not for value-bearing or mainnet use.** |
| **Beta, testnet only** | Beta, and additionally limited to test networks. Nothing of value should depend on it. |
| **Beta with caveat** | Beta, with a specific known limitation you must design around. The caveat is named in the matrix. |
| **Beta, opt-in** | Beta, but you have to add it explicitly; it's never pulled in by default. |
| **Experimental** | Opt-in, may change, and may have known limitations. Use for evaluation and research, not as a foundation. |
| **Disabled by default** | Legacy code kept for explicit experiments. It refuses to run unless you set a flag. |
| **Assurance only** | Independent implementations used to cross-check ZeroJ in CI. Never published and never a runtime option. |

"Beta" is a statement about completeness and testing. It is **not** a security claim.

## Support matrix

The matrix below restates the project's support matrix. Groth16 on BLS12-381 is the focus of the
current release and the default in every recommendation.

### Circuits and core

| Area | Modules | Status |
|------|---------|--------|
| Core proof model, codecs, verifier SPI and orchestrator | `zeroj-api`, `zeroj-codec`, `zeroj-backend-spi` | **Beta** |
| Circuit definition: DSL, symbolic annotations, gadgets | `zeroj-circuit-dsl`, `zeroj-circuit-annotation-api`, `zeroj-circuit-annotation-processor`, `zeroj-circuit-lib` | **Beta**, with per-gadget status (see [Gadgets](/guides/circuits/gadgets/)) |
| BLS12-381 pure-Java primitives | `zeroj-bls12381` | **Beta**, verification-grade |

### Groth16 (the default)

| Area | Modules | Status |
|------|---------|--------|
| Groth16 BLS12-381: pure-Java prove and verify | `zeroj-crypto`, `zeroj-verifier-groth16` | **Beta**. Production keys require an external snarkjs MPC ceremony; the in-repo setup is dev-only and flag-gated. |
| Groth16 BLS12-381: on-chain (JuLC / Plutus V3) | `zeroj-onchain-julc` | **Beta, testnet only**, not value-bearing. Real validators must bind the proof to `ScriptContext` (see [Verify proofs on Cardano](/guides/verifying/on-chain/#bind-the-proof-to-the-spend)). |
| blst native acceleration | `zeroj-blst`, `zeroj-crypto-blst` | **Beta, opt-in**. FFM binding, `libblst` built from source (pinned v0.3.15). |

### PlonK

| Area | Modules | Status |
|------|---------|--------|
| PlonK BLS12-381: pure-Java prove and verify, `.ptau`/`.zkey` import | `zeroj-crypto`, `zeroj-verifier-plonk` | **Experimental** |
| PlonK BLS12-381: on-chain (JuLC / Plutus V3) | `zeroj-onchain-julc` | **Experimental**. Labeled testnet trials only. |

:::caution[PlonK is experimental everywhere]
Treat ZeroJ's PlonK support, off-chain and on-chain, as experimental. It isn't a recommended
alternative to Groth16, and these docs make no correctness or readiness claims for it.
:::

### Credentials

| Area | Modules | Status |
|------|---------|--------|
| BBS (IRTF CFRG draft-10): verification | `zeroj-bbs` | **Beta**. The spec is an IRTF draft, not yet an RFC. |
| BBS: issuance and proof generation | `zeroj-bbs` | **Beta with caveat**. The default pure-Java provider is not constant-time; prefer the blst provider for issuer keys. |

### Authenticated state

| Area | Modules | Status |
|------|---------|--------|
| Poseidon authenticated state (MPF, JMT) | `zeroj-mpf-poseidon`, `zeroj-jmt-poseidon` | **Experimental**. High-volume paths are benchmarked (5M-entry local end-to-end runs passed), but production ceremonies, external review, and Yaci/public-network gates remain open. |

### Legacy and assurance

| Area | Modules | Status |
|------|---------|--------|
| BN254 (Groth16 and PlonK, off-chain) | legacy classes | **Disabled by default.** Requires `-Dzeroj.allowLegacyBn254=true`. BN254 is not a Cardano curve. |
| BLS12-381 and BBS WASM differential providers | `assurance/zeroj-bls12381-wasm`, `assurance/zeroj-bbs-wasm` | **Assurance only**. Independent zkcrypto and zkryptium oracles, outside the default build and never published. |

## What "not for production" means in practice

"Don't use this in production" is easy to say and easy to ignore. Here is what it means
concretely for ZeroJ today:

- **No external audit.** No third party has reviewed the provers, verifiers, circuits, gadgets,
  or on-chain validators. Bugs that tests didn't anticipate may exist, including soundness bugs
  that would let someone forge a proof.
- **Development setup is not a ceremony.** The in-process trusted setup
  (`PowersOfTauBLS381.generate`, `Groth16Keys.setupInMemory`, `Groth16SetupBLS381.setup`) knows its
  own toxic waste and can forge proofs. It only runs with `-Dzeroj.allowInsecureTrustedSetup=true`.
  Anything beyond local testing needs keys from a multi-party ceremony. See
  [Trusted setup, explained](/learn/trusted-setup/).
- **On-chain means testnet.** The on-chain Groth16 verifier is tested on Yaci DevKit and is
  labeled testnet-only. Don't lock real ADA or tokens behind it.
- **A valid proof isn't authorization.** The reusable on-chain verifiers only check the math. Your
  validator must still prevent replay, bind the proof to the transaction, track nullifiers, and
  enforce who may do what. See [Application security](/guides/verifying/application-security/).
- **No constant-time guarantee for Java code.** The BBS pure-Java provider uses fixed-schedule
  arithmetic for secret scalars, but that is not a full JVM constant-time guarantee. For BBS issuer
  keys, select the native blst provider. ZeroJ doesn't claim constant-time behavior for its Java
  code.
- **PlonK is experimental,** off-chain and on-chain.
- **APIs and coordinates can still change.** ZeroJ is pre-1.0. The move to `org.zeroj` in
  `0.1.0-pre12` is one example (see [Migration](/reference/migration/)).

What you *can* reasonably do today: learn ZK, prototype applications, run the demos, evaluate
designs, benchmark, and run testnet experiments that protect nothing of value.

## How ZeroJ gathers evidence

The project tries to avoid the classic trap of a library only ever agreeing with itself. Where
possible, expected values come from somewhere other than the code under test.

| Kind of evidence | Examples in ZeroJ |
|------------------|-------------------|
| Unit and regression tests | More than 3,500 tests across modules, including invalid-witness, proof-tampering, wrong-public-input, and public-input-order tests |
| Official test vectors | IETF RFC 9380 hash-to-curve vectors for BLS12-381; the official CFRG BBS draft-10 fixtures (SHA-256 and SHAKE-256 ciphersuites) |
| Differential tests against independent implementations | zkcrypto BLS12-381 and zkryptium BBS compiled to WASM and run as oracles in a dedicated assurance CI job; Poseidon checked against published circomlibjs vectors (BN254) and an independent SageMath implementation of the Poseidon paper spec (BLS12-381) |
| Cross-provider equivalence | The same BBS vectors run against the pure-Java, blst, and WASM providers; the blst prover backend is tested for bit-identical Groth16 output against the pure-Java prover |
| Interop with other toolchains | A CI job where the pinned snarkjs 0.7.6 CLI verifies ZeroJ-produced proofs and keys, ZeroJ verifies live snarkjs proofs, and tampered proofs must be rejected; PlonK transcript checks against fixtures generated by gnark v0.14.0 |
| End-to-end on-chain runs | Groth16 proofs generated in pure Java and verified by a Plutus V3 validator in lock-and-unlock transactions on Yaci DevKit |

:::caution[Passing tests is not security]
Tests, vectors, differential checks, and a successful on-chain run all raise confidence that ZeroJ
computes what it intends to compute. None of them proves the absence of soundness bugs,
side channels, or protocol-level mistakes in your application. Only careful design and external
review can move a component toward production. This page will change when that happens, not
before.
:::

## Further reading

Production gates and remediation status are tracked in
[ADR-0026](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0026-production-readiness-review-and-remediation-plan.md).
The module split between the stable BOM, opt-in modules, and assurance providers is described in
[ADR-0044](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0044-focused-module-surface-and-optional-provider-isolation.md).

## Next steps

- [Installation](/start/installation/)
- [Quickstart: your first proof](/start/quickstart/)
- [Application security](/guides/verifying/application-security/)
- [Modules reference](/reference/modules/)

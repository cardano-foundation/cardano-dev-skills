---
title: Modules
description: Every published ZeroJ artifact with its coordinates, purpose, BOM membership, maturity and main entry-point classes, plus the unpublished support projects.
sidebar:
  order: 1
---

ZeroJ is split into small modules so you only pull in what you use. All published artifacts share
the Maven group **`org.zeroj`**, and every Java package starts with `org.zeroj`. (Releases up to
`0.1.0-pre11` used `com.bloxbean.cardano`; see [Migration notes](/reference/migration/).)

There are three kinds of published module:

- **Core** modules are version-aligned by the BOM `org.zeroj:zeroj-bom-core`. Import the BOM once
  and omit versions.
- **Opt-in** modules are published but deliberately left out of the BOM. Declare them with an
  explicit version. "Opt-in" means they're not in the default dependency graph and have their
  own maturity; it doesn't mean untested.
- **Support, assurance and benchmark** projects are never published.

Maturity labels come from the support matrix on [Status & maturity](/start/status/). "Beta" means
feature-complete and correctness-tested but **not externally audited** and not for value-bearing or
mainnet use.

## Using the BOM

```groovy title="build.gradle"
dependencies {
    implementation platform('org.zeroj:zeroj-bom-core:%ZEROJ_VERSION%')

    implementation 'org.zeroj:zeroj-circuit-dsl'            // core: version from the BOM
    implementation 'org.zeroj:zeroj-crypto'
    implementation 'org.zeroj:zeroj-verifier-groth16'

    implementation 'org.zeroj:zeroj-bbs:%ZEROJ_VERSION%'    // opt-in: explicit version
}
```

```xml title="pom.xml"
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.zeroj</groupId>
      <artifactId>zeroj-bom-core</artifactId>
      <version>%ZEROJ_VERSION%</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

## Core modules (in `zeroj-bom-core`)

| Artifact | Purpose | Maturity | Start with |
|---|---|---|---|
| `zeroj-api` | Proof model and shared policy types. No dependencies. | Beta | `ZkProofEnvelope`, `PublicInputs`, `VerificationKeyRef`, `VerificationMaterial`, `VerificationResult`, `CircuitId`, `CurveId`, `ProofSystemId`, `TrustedSetupPolicy`, `LegacyCurvePolicy` |
| `zeroj-codec` | snarkjs JSON parsing, CBOR envelopes, canonical hashing | Beta | `SnarkjsJsonCodec`, `CborEnvelopeCodec`, `CanonicalHash`, `EnvelopeValidator` |
| `zeroj-backend-spi` | Verifier SPI, key registry, routing | Beta | `ZkVerifier`, `BackendDescriptor`, `VerificationKeyRegistry`, `InMemoryVerificationKeyRegistry`, `VerifierRegistry`, `VerifierOrchestrator` |
| `zeroj-verifier-groth16` | Groth16 BLS12-381 verification | Beta | `Groth16BLS12381PureJavaVerifier` (pure Java), `Groth16BLS12381Verifier` (blst-backed) |
| `zeroj-bls12381` | Pure-Java BLS12-381 fields, curves and pairing | Beta (verification-grade) | `BLS12381Pairing`, `G1Point`, `G2Point`, `Bls12381Provider` |
| `zeroj-blst` | Native BLS12-381 via [blst](https://github.com/supranational/blst): FFM MSM binding with a source-built, bundled `libblst`, plus pairing | Beta, opt-in native code | `BlstBls12381Provider`, `BlstPairing`, `ffm.BlstFfm` |
| `zeroj-crypto` | The pure-Java prover: Groth16 setup, proving, key stores, ceremony import, snarkjs export | Beta (Groth16); PlonK classes are experimental | `Groth16Keys`, `Groth16Pipeline`, `Groth16ProverBLS381`, `Groth16SetupBLS381`, `PowersOfTauBLS381`, `ZkeyImporterBLS381`, `ZkeyPkStoreImporter`, `SnarkjsGroth16Json` |
| `zeroj-crypto-blst` | Opt-in blst MSM backend for the Groth16 prover; bit-identical proofs | Beta, opt-in | `BlstProverBackend` |
| `zeroj-circuit-dsl` | Java circuit DSL; compiles to R1CS | Beta | `CircuitBuilder`, `CircuitSpec`, `SignalBuilder`, `Signal` |
| `zeroj-circuit-lib` | Gadget library: Poseidon, Merkle, comparators, binary, mux, Blake2b/SHA-512/HMAC, Ed25519/BIP32/CIP-1852… | Beta, per-gadget status | `PoseidonParamsBLS12_381T3`, see [Gadgets](/guides/circuits/gadgets/) |
| `zeroj-circuit-annotation-api` | `@ZKCircuit` symbolic annotations and `Zk*` types | Beta | `@ZKCircuit`, `@Prove`, `@Public`, `@Secret`, `ZkField`, `ZkBool`, `ZkContext`, `ZkInputMap` |
| `zeroj-circuit-annotation-processor` | Annotation processor that generates a `<Name>Circuit` companion class | Beta | Add as `annotationProcessor` |
| `zeroj-onchain-julc` | Plutus V3 validators and codecs, compiled with JuLC | Groth16: **Beta, testnet only**. PlonK validators: **Experimental**. BBS on-chain libraries: working for one fixed disclosure profile, not separately rated in the support matrix | `groth16.validator.Groth16BLS12381Verifier`, `Groth16BLS12381TxOutRefBindingVerifier` (reference example only), `Groth16BLS12381Lib`, `ProverToCardano`, `SnarkjsToCardano`, `ScriptBudgetEstimator` |
| `zeroj-tools` | Ceremony tooling and the `zeroj-ceremony` CLI (snarkjs-compatible phase-2 contributions) | Not separately rated; the ceremony design record is still *Proposed* | `ZkeyContributor`, `SnarkjsHashToG2`, `CeremonyCli` |
| `zeroj-bom-core` | The BOM for all of the above | — | `platform('org.zeroj:zeroj-bom-core:…')` |

:::note[Two `Groth16BLS12381Verifier` classes]
`org.zeroj.verifier.groth16.bls12381.Groth16BLS12381Verifier` (off-chain, blst-backed) and
`org.zeroj.onchain.julc.groth16.validator.Groth16BLS12381Verifier` (on-chain validator) share a
simple name. Import by package.
:::

## Opt-in modules (explicit version)

| Artifact | Purpose | Maturity | Start with |
|---|---|---|---|
| `zeroj-verifier-plonk` | PlonK BLS12-381 verification (structured snarkjs/ZeroJ JSON) | **Experimental** | `PlonkBLS12381Verifier` |
| `zeroj-bbs` | CFRG BBS draft-10 signatures and selective disclosure | Verification: Beta. Issuance: Beta with caveat (use the blst provider for issuer keys) | `BbsService`, `BbsPresentationCodec`, `BbsToCardano`, `BbsZkVerifier` |
| `zeroj-mpf-poseidon` | Poseidon-rooted MPF adapter over Cardano Client Lib plus operation-specific circuits | **Experimental** | `PoseidonMpfTrie`, `PoseidonMpfCircuitTemplates`, `PoseidonMpfBranchWitness` |
| `zeroj-jmt-poseidon` | Poseidon-rooted JMT profile over Cardano Client Lib plus operation-specific circuits | **Experimental** | `PoseidonJmtTree`, `PoseidonJmtCircuitTemplates`, `PoseidonJmtInclusionWitness` |

:::caution[PlonK is experimental]
Everything PlonK in ZeroJ (the prover classes in `zeroj-crypto`, `zeroj-verifier-plonk`, and the
on-chain PlonK validators) is experimental and opt-in. Groth16 on BLS12-381 is the focus of the
current release.
:::

Legacy BN254 classes still exist in some modules for old off-chain experiments. They are disabled
unless you set `-Dzeroj.allowLegacyBn254=true`, are not registered with `ServiceLoader`, and BN254
is not a Cardano curve.

## What depends on what

You rarely need to list every module. Typical sets:

| You want to… | Declare |
|---|---|
| Write and prove circuits | `zeroj-circuit-dsl` (+ `zeroj-circuit-lib`), `zeroj-crypto`; for annotations also `zeroj-circuit-annotation-api` and `annotationProcessor 'org.zeroj:zeroj-circuit-annotation-processor'` |
| Verify proofs in a service | `zeroj-verifier-groth16`, `zeroj-codec` |
| Verify on Cardano | `zeroj-onchain-julc` (+ JuLC's `julc-cardano-client-lib` to load scripts) |
| Faster proving on big machines | add `zeroj-crypto-blst` and benchmark first |
| Credentials | `zeroj-bbs` (explicit version), optionally `zeroj-blst` |

## Never published

These live in the repository for testing, assurance and benchmarking. You can't depend on them.

| Project | What it is | How to build |
|---|---|---|
| `zeroj-test-vectors` | Shared fixtures: pre-generated proofs and VKs | Default build |
| `zeroj-integration-tests` | Cross-module regressions: Groth16 end-to-end, tampering, invalid witness, snarkjs interop, JuLC VM and Yaci DevKit | `./gradlew :zeroj-integration-tests:test`, `:e2eTest` |
| `assurance/zeroj-bls12381-wasm` | zkcrypto BLS12-381 compiled to WASM, an independent differential oracle (needs Rust) | `-PincludeAssurance` |
| `assurance/zeroj-bbs-wasm` | zkryptium BBS compiled to WASM, an independent differential oracle (needs Rust) | `-PincludeAssurance` |
| `assurance/gnark-fixtures` | Pinned gnark fixture generator for the committed PlonK vectors (needs Go) | `make` (not a Gradle project) |
| `benchmarks/zeroj-mpf-poseidon-load` | RocksDB load, proof and Cardano-artifact benchmark tool for MPF | `-PincludeBenchmarks` |
| `benchmarks/zeroj-jmt-poseidon-load` | Durable, versioned JMT load and benchmark tool | `-PincludeBenchmarks` |

See [Configuration](/reference/configuration/#gradle-flags-for-contributors) for the build flags.

## Next steps

- [Installation](/start/installation/)
- [API cheat sheet](/reference/api-cheatsheet/)
- [Status & maturity](/start/status/)

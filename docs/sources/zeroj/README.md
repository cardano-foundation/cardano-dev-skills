<p align="center">
  <img src="static/zeroj-readme-hero.png" alt="ZeroJ — Zero-Knowledge Proofs for the JVM" width="100%">
</p>

# ZeroJ

[![snapshot](https://img.shields.io/maven-metadata/v?metadataUrl=https%3A%2F%2Frepo.bloxbean.org%2Fmaven%2Fsnapshots%2Forg%2Fzeroj%2Fzeroj-crypto%2Fmaven-metadata.xml&strategy=latestProperty&label=snapshot)](#development-snapshots)

> [!WARNING]
> **Status: Experimental — Research & Learning Project**
>
> This project is generated using AI, with human-assisted design, testing, and verification.
> It is an experimental project created mainly for research and exploration purposes.
>
> **Please do not use this in production.** Expect rough edges, incomplete features, and potential bugs.

Java-first zero-knowledge proof toolkit for Cardano.

ZeroJ lets Java developers **define ZK circuits**, **generate proofs**, **verify** them off-chain, and **execute on-chain verification** on Cardano. The Java DSL and pure-Java proving path require no native libraries or external CLIs.

> [!TIP]
> **New to ZeroJ? Start with the runnable examples.**
> [**zeroj-usecases**](https://github.com/bloxbean/zeroj-usecases) has complete, end-to-end
> applications built on ZeroJ — account-ownership recovery, private voting, selective disclosure, and
> more — that you can build and run to see the whole flow (circuit → prove → verify off-chain and
> on-chain). **Try those first** to get a feel for what ZeroJ does before diving into the library
> APIs below.

## Support Matrix

**Beta** means feature-complete and correctness-tested (3,500+ tests; the full
Groth16 flow is verified end-to-end on-chain against Yaci DevKit), but **not
externally audited and not for value-bearing/mainnet use**. **Experimental**
components are opt-in and may change or have known limitations. Statuses and
remaining production gates are tracked in
[ADR-0026](docs/adr/0026-production-readiness-review-and-remediation-plan.md).

| Area | Components | Status |
|------|-----------|--------|
| Core proof model, codecs, verifier SPI/orchestrator | `zeroj-api`, `zeroj-codec`, `zeroj-backend-spi` | **Beta** |
| Circuit definition (DSL, symbolic annotations, gadgets) | `zeroj-circuit-dsl`, `zeroj-circuit-annotation-*`, `zeroj-circuit-lib` ([per-gadget table](zeroj-circuit-lib/README.md)) | **Beta** |
| Groth16 BLS12-381 — pure Java prove + verify | `zeroj-crypto`, `zeroj-verifier-groth16` | **Beta** (production trusted setup requires an external snarkjs MPC ceremony; in-repo setup is dev-only and flag-gated) |
| Groth16 BLS12-381 — on-chain (Julc / Plutus V3) | `zeroj-onchain-julc` | **Beta — testnet only**, not value-bearing; bind `ScriptContext` in real validators (see `Groth16BLS12381TxOutRefBindingVerifier`) |
| PlonK BLS12-381 — pure Java prove + verify, `.ptau`/`.zkey` import | `zeroj-crypto`, `zeroj-verifier-plonk` | **Beta** |
| PlonK BLS12-381 — on-chain (Julc / Plutus V3) | `zeroj-onchain-julc` | **Experimental** — full KZG check implemented; labeled testnet trials only |
| BBS (CFRG draft-10) — verification | `zeroj-bbs` | **Beta** (spec is an IRTF draft, not yet an RFC) |
| BBS — issuance / proof generation | `zeroj-bbs` | **Beta with caveat** — default pure-Java provider is not constant-time; prefer the blst provider for issuer keys |
| BLS12-381 pure Java primitives | `zeroj-bls12381` | **Beta** — verification-grade; prover performance (allocation-lean, mmap'd key) in [ADR-0029](docs/adr/0029-blst-accelerated-groth16-prover.md) |
| blst native acceleration | `zeroj-blst` | **Beta, opt-in** — FFM binding; `libblst` built from source, pinned v0.3.15; a faster Groth16 prover backend ([ADR-0029](docs/adr/0029-blst-accelerated-groth16-prover.md)) |
| BLS/BBS WASM differential providers | `assurance/zeroj-bls12381-wasm`, `assurance/zeroj-bbs-wasm` | **Assurance only** — independent zkcrypto/zkryptium oracles, outside the default build and never published ([ADR-0044](docs/adr/0044-focused-module-surface-and-optional-provider-isolation.md)) |
| Poseidon authenticated state | `zeroj-mpf-poseidon`, `zeroj-jmt-poseidon` | **Experimental — high-volume paths benchmarked** (both 5M local end-to-end runs passed with operation-specific circuits; production ceremonies, external review, and Yaci/public-network gates remain open) |
| BN254 (Groth16 + PlonK, off-chain) | legacy classes | **Disabled by default** — `-Dzeroj.allowLegacyBn254=true`; not a Cardano curve |

## What You Can Do Today

### Define ZK Circuits
- **CircuitSpec Java DSL** (recommended) — define circuits as reusable Java classes with `CircuitSpec`
- **Inline lambda DSL** — quick prototyping with `CircuitBuilder.define(api -> ...)`
- **circom interop** — use externally compiled circom/snarkjs artifacts (`.r1cs`, `.zkey`, `.wtns`)
- **Standard library** — Poseidon, MiMC, Merkle, Comparators, Binary, Mux, AliasCheck; in-circuit **Blake2b / SHA-512 / HMAC-SHA512** and **Ed25519 / BIP32 / CIP-1852** key-derivation gadgets (prove Cardano key ownership without revealing the seed); symbolic `Zk*` adapters, plus operation-specific Poseidon MPF/JMT circuits in their authenticated-state modules; see the [`zeroj-circuit-lib`](zeroj-circuit-lib/README.md) gadget table and [large-state guide](docs/merkle/practical-large-state-guide.md)
- **Multi-backend compilation** — one Java circuit can compile to R1CS for Groth16 or to PlonK

### Generate Proofs
- **Pure Java prover** (recommended) — Groth16 + PlonK for BLS12-381. Zero native dependencies. GraalVM compatible. Allocation-lean flat arithmetic, an `mmap`-able proving key, and a streaming trusted setup keep large circuits (millions of constraints) within commodity memory, no JNI (ADR-0029/0033/0034/0035).
- **blst-accelerated prover backend** — optional, opt-in FFM-bound native MSM (`blst_p1s/p2s_mult_pippenger`); a faster Groth16 proving backend, bit-identical proofs. `libblst` is built from source (no third-party wrapper) ([ADR-0029](docs/adr/0029-blst-accelerated-groth16-prover.md)).
- **snarkjs CLI** — external CLI for circom-based circuits
- **snarkjs key import** — import `.zkey` files, prove with the pure Java prover

### Verify ZK Proofs (Pure Java, Zero Native Deps)
- **Groth16 BLS12-381** — pure Java verification; optional blst-backed native verifier is also available
- **PlonK BLS12-381** — pure Java verification
- **BN254 is disabled by default** — legacy off-chain proving and verification classes remain for explicit experiments only (`-Dzeroj.allowLegacyBn254=true`); BN254 is not a Cardano on-chain curve.
- Parse snarkjs proof artifacts (`proof.json`, `verification_key.json`, `public.json`)
- Pluggable backend SPI — add new proof systems without changing application code

### Verify On-Chain (Cardano Plutus V3)
- **Groth16 BLS12-381** — reusable Plutus V3 spending validator via Julc
- **PlonK BLS12-381** — experimental Julc validators; supported profiles perform the KZG pairing check and are suitable for labeled non-value-bearing testnet trials, but value-bearing use remains gated pending external review
- VK baked at deploy time, proof passed as redeemer, public inputs as datum
- **Proven end-to-end for Groth16**: Java DSL circuit → pure Java prove → Yaci DevKit on-chain verify

Reusable on-chain verifiers only verify the cryptographic proof statement. A
real application validator must also bind replay protection, nullifiers,
authorization, and any `ScriptContext` policy required by the business flow.

### Anchor on Cardano L1
- 4 anchor patterns: proof hash, state root + proof hash, full verification ref, nullifier commitment
- CCL integration — fluent helpers for attaching proof metadata to transactions

## Quick Start — Zero Dependencies

Define a circuit, prove it, and verify — all in pure Java.

ZeroJ supports multiple ways to write the same circuit. For new application
circuits, start with symbolic annotations. Use `CircuitSpec` when you want a
manual reusable circuit class, and use the inline DSL for small tests or
experiments.

### Recommended: Symbolic Annotations

```java
// Define the circuit with @ZKCircuit and symbolic Zk* values.
@ZKCircuit(name = "secret-multiplier", version = 1)
public class SecretMultiplier {
    @Prove
    ZkBool prove(
            ZkContext zk,
            @Public ZkField a,
            @Public ZkField product,
            @Secret ZkField b) {
        return a.mul(b).isEqual(product);
    }
}

// The annotation processor generates SecretMultiplierCircuit.
var circuit = SecretMultiplierCircuit.build();
```

### Equivalent CircuitSpec

```java
public class SecretMultiplierSpecCircuit implements CircuitSpec {
    @Override
    public void define(SignalBuilder c) {
        Signal a = c.publicInput("a");
        Signal b = c.privateInput("b");       // secret — never revealed
        Signal product = c.publicOutput("product");
        c.assertEqual(a.mul(b), product);
    }

    public static CircuitBuilder build() {
        return CircuitBuilder.create("secret-multiplier")
                .publicVar("a").publicVar("product").secretVar("b")
                .defineSignals(new SecretMultiplierSpecCircuit());
    }
}

var circuit = SecretMultiplierSpecCircuit.build();
```

Choose one definition style. Both produce a `CircuitBuilder`, and the proof flow
is the same after that point:

```java
// 1. Compile and compute witness
var r1cs = circuit.compileR1CS(CurveId.BLS12_381);
var witness = circuit.calculateWitness(Map.of(
    "a", List.of(BigInteger.valueOf(3)),
    "b", List.of(BigInteger.valueOf(11)),      // secret!
    "product", List.of(BigInteger.valueOf(33))
), CurveId.BLS12_381);

// 2. Setup + Prove (pure Java — zero native dependencies)
// Dev/test only; requires -Dzeroj.allowInsecureTrustedSetup=true.
var srs = PowersOfTauBLS381.generate(4);
var constraints = r1cs.constraints();
var setup = Groth16SetupBLS381.setup(
        constraints, r1cs.numWires(), r1cs.numPublicInputs(), srs.tauScalar());
var proof = Groth16ProverBLS381.prove(
        setup.provingKey(), witness, constraints, r1cs.numWires());

// 3. Verify off-chain (pure Java)
boolean valid = BLS12381Pairing.pairingCheck(...);  // Groth16 pairing equation

// 4. Verify on-chain (Cardano Plutus V3)
var script = JulcScriptLoader.load(Groth16BLS12381Verifier.class, vkParams...);
// Lock ADA → unlock with ZK proof → Cardano verifies BLS12-381 pairing
```

For setup beyond local tests, use an MPC ceremony `.zkey` instead of
`PowersOfTauBLS381.generate()`. See the
[Pure Java Prover Guide](docs/pure-java-prover-guide.md).

For large circuits, prefer the `Groth16Keys` / `Groth16Pipeline` facade — it streams
the trusted setup to a disk-backed, `mmap`-loaded proving key rather than holding it
in heap, so proving stays within commodity memory. See the
[Groth16 Dev Guide](docs/groth16-dev-guide.md).

See [Alternate Prover Backends](docs/alternate-prover-backends.md) for the
blst-accelerated backend and snarkjs interoperability.

## Prerequisites

### Required

| Dependency | Version | Notes |
|------------|---------|-------|
| **Java** | 25+ | GraalVM recommended for native-image support |
| **Gradle** | 9.2+ | Included via wrapper (`./gradlew`) |

Install Java 25 with [SDKMAN!](https://sdkman.io/):

```bash
sdk install java 25.0.2-graal
sdk use java 25.0.2-graal
```

### Optional (for specific backends)

| Dependency | Version | Required By | Notes |
|------------|---------|-------------|-------|
| **circom** | 2.x | Circuit compilation (if using circom) | `cargo install circom` |
| **snarkjs** | 0.7+ | Proof generation (if using snarkjs) | `npm install -g snarkjs` |

The **pure Java prover and verifier require no optional dependencies**.

## Building

```bash
# Build the full repository, including opt-in WASM/native modules
./gradlew build

# Build the core privacy path only
./gradlew :zeroj-bom-core:build :zeroj-backend-spi:build :zeroj-verifier-groth16:build :zeroj-verifier-plonk:build :zeroj-crypto:build :zeroj-onchain-julc:build

# Run all tests
./gradlew test

# Run end-to-end on-chain tests (requires Yaci DevKit)
./gradlew :zeroj-integration-tests:e2eTest
```

## Architecture

```
         CircuitSpec (Java DSL)           circom (.circom)
                  │                            │
         compileR1CS(BLS12_381)         snarkjs setup → .zkey
                  │                            │
                  │                   ZkeyImporterBLS381
                  │                            │
                  └──────────┬─────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
     Pure Java Prover               blst-accelerated backend
     (Groth16ProverBLS381)          (BlstProverBackend)
     Zero native deps               Optional native backend
              │                             │
              └──────────┬──────────────────┘
                         │
                Pure Java Verify
             (BLS12381Pairing / Verifier SPI)
                         │
                On-Chain Verify (Julc)
             (Plutus V3, BLS12-381 pairings)
                         │
                 Yaci DevKit / Cardano
```

### Module Organization

#### Core Modules (`zeroj-bom-core`)

| Module | Description |
|--------|-------------|
| [`zeroj-api`](zeroj-api/) | Core proof model, envelopes, verification result types |
| [`zeroj-codec`](zeroj-codec/) | Proof serialization — snarkjs JSON, CBOR, canonical hashing |
| [`zeroj-backend-spi`](zeroj-backend-spi/) | Service Provider Interface for verification backends, plus verifier orchestration and backend routing |
| [`zeroj-verifier-groth16`](zeroj-verifier-groth16/) | Groth16 verification — BLS12-381 pure Java/native blst; BN254 legacy verifier disabled by default |
| [`zeroj-bls12381`](zeroj-bls12381/) | Pure Java BLS12-381 field, curve, and pairing primitives |
| [`zeroj-blst`](zeroj-blst/) | Native BLS12-381 via blst — FFM MSM binding (`libblst` built from source) + pairing; standalone, reusable by other JVM projects |
| [`zeroj-crypto`](zeroj-crypto/) | **Pure Java prover** — Montgomery field arithmetic, EC operations, Groth16 + PlonK for BLS12-381; big-circuit ready: mmap'd sparse/dense key stores + a streaming trusted setup keep proving of large circuits (millions of constraints — e.g. the ~19M-constraint account-ownership circuit) within commodity memory (ADR-0029/0033/0034/0035). Start at `Groth16Keys` + `Groth16Pipeline` ([dev guide](docs/groth16-dev-guide.md)); no native deps; BN254 high-level proving APIs require legacy opt-in |
| [`zeroj-crypto-blst`](zeroj-crypto-blst/) | **Opt-in blst prover backend** — thin bridge wiring `zeroj-blst`'s native MSM into the `zeroj-crypto` prover SPI (keeps `zeroj-crypto` pure-Java by default; pure Java matches blst at large sizes since ADR-0033/0034) |
| [`zeroj-tools`](zeroj-tools/) | Reusable operator tools and the `zeroj-ceremony` CLI — snarkjs-compatible Groth16 phase-2 contributor (`ZkeyContributor`), hash-to-G2 challenge derivation; embeddable in coordinator services and wallets |
| [`zeroj-circuit-dsl`](zeroj-circuit-dsl/) | Java Circuit DSL — define circuits with CircuitSpec, compile to R1CS/PlonK |
| [`zeroj-circuit-lib`](zeroj-circuit-lib/) | Circuit standard library — Poseidon, MiMC, Merkle, Comparators, Binary, Mux, AliasCheck; in-circuit Blake2b / SHA-512 / HMAC-SHA512 and Ed25519 / BIP32 / CIP-1852 key derivation; symbolic adapters; [per-gadget status](zeroj-circuit-lib/README.md#gadget-status) |
| [`zeroj-onchain-julc`](zeroj-onchain-julc/) | Reusable Plutus V3 on-chain verifiers and libraries via Julc; Groth16 is the primary supported path, PlonK BLS12-381 validators/libraries are experimental opt-in |

#### Explicit Opt-In Product Modules

Published, but deliberately **outside** `zeroj-bom-core` — declare them with an explicit version.
Opt-in means the module is not pulled into the default dependency graph and its maturity is
documented independently; it does not mean untested.

| Module | Description |
|--------|-------------|
| [`zeroj-verifier-plonk`](zeroj-verifier-plonk/) | PlonK verification — BLS12-381 pure Java; BN254 legacy verifier disabled by default |
| [`zeroj-bbs`](zeroj-bbs/) | BBS/BBS+ selective disclosure credential backend |
| [`zeroj-mpf-poseidon`](zeroj-mpf-poseidon/) | Poseidon-rooted CCL MPF adapter, strict witness normalization, and operation-specific inclusion/non-inclusion/update/insert circuits ([5M benchmark](docs/benchmarks/poseidon-mpf-5m-2026-08-02.md)) |
| [`zeroj-jmt-poseidon`](zeroj-jmt-poseidon/) | Poseidon-rooted CCL JMT host profile plus operation-specific inclusion/non-inclusion/update/insert/tombstone circuits ([5M benchmark](docs/benchmarks/poseidon-jmt-5m-2026-08-03.md)) |

#### Support Projects (never published)

| Project | Description |
|--------|-------------|
| [`zeroj-test-vectors`](zeroj-test-vectors/) | Shared test fixtures — pre-generated proofs and VKs |
| [`zeroj-integration-tests`](zeroj-integration-tests/) | Cross-module security and end-to-end regressions (Groth16/PlonK E2E, tampering, invalid witness, snarkjs interop, Julc/Yaci on-chain) |
| [`zeroj-bom-core`](zeroj-bom-core/) | The single stable BOM for the default product surface |

#### Opt-In Assurance and Benchmark Projects

Outside the default build and never published. See
[ADR-0044](docs/adr/0044-focused-module-surface-and-optional-provider-isolation.md).

| Project | Description | Enable with |
|--------|-------------|-------------|
| [`assurance/zeroj-bls12381-wasm`](assurance/zeroj-bls12381-wasm/) | zkcrypto BLS12-381 WASM provider — independent differential oracle (needs Rust/Cargo) | `-PincludeAssurance` |
| [`assurance/zeroj-bbs-wasm`](assurance/zeroj-bbs-wasm/) | zkryptium BBS WASM provider — independent differential oracle (needs Rust/Cargo) | `-PincludeAssurance` |
| [`assurance/gnark-fixtures`](assurance/gnark-fixtures/) | Pinned gnark v0.14.0 PlonK fixture generator; keeps the committed independent PlonK vectors reproducible. Not a Gradle project, not a runtime provider | `make` (needs Go) |
| snarkjs interop suites (`zeroj-integration-tests`, `it.snarkjs.*`) | Bidirectional Groth16/PlonK proof + verification-key interop against the pinned snarkjs 0.7.6 CLI, with tamper negatives; skip locally without snarkjs, fail in the `snarkjs-interop` assurance job ([ADR-0047](docs/adr/0047-snarkjs-bidirectional-interop-export-and-ci.md)) | `-PrequireSnarkjs` (needs Node + `snarkjs@0.7.6`) |
| [`benchmarks/zeroj-mpf-poseidon-load`](benchmarks/zeroj-mpf-poseidon-load/) | Resumable RocksDB load, proof, circuit, Groth16 and Cardano artifact benchmark tool (needs RocksDB JNI) | `-PincludeBenchmarks` |
| [`benchmarks/zeroj-jmt-poseidon-load`](benchmarks/zeroj-jmt-poseidon-load/) | Durable/versioned JMT load, depth, operations, Groth16 and Cardano artifact benchmark tool (needs RocksDB JNI) | `-PincludeBenchmarks` |

## Dependency (Gradle)

ZeroJ releases are on Maven Central under the group `org.zeroj`. From the next release on, releases are also in the
BloxBean Maven repository (`https://repo.bloxbean.org/maven/releases`), with the same files as on Maven Central.

```gradle
dependencies {
    implementation platform('org.zeroj:zeroj-bom-core:0.1.0')

    // Circuit definition + standard library
    implementation 'org.zeroj:zeroj-circuit-dsl'
    implementation 'org.zeroj:zeroj-circuit-lib'

    // Pure Java prover (Groth16 + PlonK, BLS12-381)
    implementation 'org.zeroj:zeroj-crypto'

    // Verification (pure Java, zero native deps)
    implementation 'org.zeroj:zeroj-backend-spi'
    implementation 'org.zeroj:zeroj-verifier-groth16'

    // Opt-in product artifacts are outside the stable BOM — give them a version
    implementation 'org.zeroj:zeroj-verifier-plonk:0.1.0'

    // On-chain verification (Cardano Plutus V3)
    implementation 'org.zeroj:zeroj-onchain-julc'

}
```

### Development snapshots

Development snapshots are in the BloxBean Maven repository, one version per commit:
`<next-version>-<short-commit>-SNAPSHOT`, for example `0.1.0-pre13-1a2b3c4-SNAPSHOT`. They are published on
demand, not for every commit. The snapshot badge above shows the newest one, and
[`maven-metadata.xml`](https://repo.bloxbean.org/maven/snapshots/org/zeroj/zeroj-crypto/maven-metadata.xml) lists
them all. Use the exact version, and prefer a release for anything you share with others.

```gradle
repositories {
    mavenCentral()
    maven {
        url = uri('https://repo.bloxbean.org/maven/snapshots')
        mavenContent { snapshotsOnly() }
    }
}
```

Snapshot builds of the `zeroj-ceremony` CLI (the fat jar and the native zips a release attaches) are kept for 30
days under `https://repo.bloxbean.org/dist/snapshots/zeroj/`;
once the first one is published, [`latest.json`](https://repo.bloxbean.org/dist/snapshots/zeroj/latest.json) lists
the newest build's files with their SHA-256.

## Documentation

**Full index: [`docs/README.md`](docs/README.md).** Highlights:

### Guides
- **[Getting Started](docs/getting-started.md)** — end-to-end: circuit to on-chain verification
- **[ZK Trusted Setup Beginner Guide](docs/zk-trusted-setup-beginner-guide.md)** — tau, SRS, Powers of Tau, Groth16 phases, and PlonK setup
- **[Pure Java Prover Guide](docs/pure-java-prover-guide.md)** — zero-dependency proving pipeline
- **[Groth16 Dev Guide](docs/groth16-dev-guide.md)** — the `Groth16Keys` / `Groth16Pipeline` facade for large circuits
- **[Circuit DSL User Guide](docs/circuit-dsl-user-guide.md)** — CircuitSpec, Signal API, standard library
- **[Circuit Annotation User Guide](docs/circuit-annotation-user-guide.md)** — the `@ZKCircuit` symbolic DSL
- **[Circuit Library Gadget Status](zeroj-circuit-lib/README.md#gadget-status)** — the gadget catalog: curve, symbolic, and Cardano-readiness status for each reusable gadget (incl. the Blake2b / Ed25519 / CIP-1852 key-derivation family)
- **[Alternate Prover Backends](docs/alternate-prover-backends.md)** — blst acceleration and snarkjs interoperability
- **[Architecture Overview](docs/architecture-overview.md)** — module design and layer separation
- **[PlonK Support](docs/plonk-support.md)** — PlonK proving, off-chain verification, and the experimental Julc validators

### Use Cases
- **[▶ zeroj-usecases (runnable example apps)](https://github.com/bloxbean/zeroj-usecases)** — complete, end-to-end applications built on ZeroJ (account-ownership recovery, private voting, selective disclosure, …). **The best place to start — build and run these first to see ZeroJ in action.**
- **[ZK Use Cases on Cardano](docs/usecases/README.md)** — 8 real-world applications with secret/public input breakdowns
- **[Private Voting — Detailed Design](docs/usecases/private-voting.md)** — nullifiers, UTXO patterns, Julc contracts, architecture

### Architecture Decision Records
A full, self-maintaining list lives in [`docs/adr/`](docs/adr/). Highlights:
- [ADR-0001: Verifier-First Architecture](docs/adr/0001-verifier-first-architecture.md)
- [ADR-0003: Hybrid Crypto Backend](docs/adr/0003-pure-java-mvp.md)
- [ADR-0007: Module Structure](docs/adr/0007-module-structure-and-boundaries.md)
- [ADR-0010: Java Circuit DSL](docs/adr/0010-java-circuit-dsl.md)
- [ADR-0012: Pure Java Provers](docs/adr/0012-pure-java-provers-groth16-plonk.md)
- [ADR-0027: Real-World Crypto Gadgets (SHA-512/HMAC/Blake2b/Ed25519/BIP32)](docs/adr/0027-real-world-crypto-gadgets-sha512-hmac-blake2b-ed25519.md)
- [ADR-0028: DSL Optimization & Hint Soundness](docs/adr/0028-dsl-optimization-and-hint-soundness.md)
- [ADR-0029: Groth16 Prover Performance (memory + blst/FFM)](docs/adr/0029-blst-accelerated-groth16-prover.md)
- [ADR-0033: Prover Memory Reduction](docs/adr/0033-prover-memory-reduction.md)
- [ADR-0034: Frontend Memory Reduction](docs/adr/0034-frontend-memory-reduction.md)
- [ADR-0035: Setup Memory & Time Reduction](docs/adr/0035-setup-memory-time-reduction.md)
- [ADR-0036: Groth16 API Facade & Pipeline](docs/adr/0036-groth16-api-facade-and-pipeline.md)
- [ADR-0045: Groth16 Infinity-IC Profile & Public-Wire Binding](docs/adr/0045-groth16-infinity-ic-profile-and-public-wire-binding.md)
- [ADR-0046: Groth16 Unblinded Proving Is a Test Fixture, Not a Public API](docs/adr/0046-groth16-unblinded-proving-test-boundary.md)
- [ADR-0047: snarkjs-Compatible JSON Export & Bidirectional Interop CI](docs/adr/0047-snarkjs-bidirectional-interop-export-and-ci.md)

## Examples

| Example | What It Demonstrates |
|---------|---------------------|
| `SealedBidPureJavaE2ETest` | BLS12-381 Poseidon commitment + range proof → pure Java prove → pairing verify |
| `AnonymousVotingPureJavaE2ETest` | BLS12-381 Poseidon commitment + boolean → prove → verify |
| `BalanceThresholdPureJavaE2ETest` | Range comparison → prove → verify |
| `PureJavaProverYaciE2ETest` | **Full stack: prove → Yaci DevKit on-chain verify** |
| `CircomToOnChainE2ETest` | circom `.zkey` → Java prove → Julc VM on-chain verify |
| `ParameterizedCircuitE2ETest` | Parameterized circuits (depth, arity, hash function) |
| `Groth16BLS381ZkeyEndToEndTest` | snarkjs `.zkey` import → Java prove → pairing verify |

```bash
# Cross-module regressions (off-chain, no external tooling)
./gradlew :zeroj-integration-tests:test

# End-to-end tests (need snarkjs on PATH and/or a running Yaci DevKit;
# they skip gracefully when the prerequisite is missing)
./gradlew :zeroj-integration-tests:e2eTest
```

## License

MIT License — see [LICENSE](LICENSE) for details.

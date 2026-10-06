---
title: Configuration
description: Every ZeroJ system property, environment variable, native-library requirement, external tool and contributor Gradle flag, and which ones are dev-only.
sidebar:
  order: 3
---

ZeroJ has very little configuration, on purpose. At runtime the library reads **three** `zeroj.*`
system properties and **two** `ZEROJ_*` environment variables. Everything else is ordinary Java: the dependencies you
declare and the objects you construct. This page lists all of it, plus the native-library and
build details you may run into.

## Runtime switches

| System property | Environment variable | Default | Dev-only? | Effect |
|---|---|---|---|---|
| `zeroj.allowInsecureTrustedSetup` | `ZEROJ_ALLOW_INSECURE_TRUSTED_SETUP` | off | **Yes** | Allows single-party trusted setup |
| `zeroj.allowLegacyBn254` | `ZEROJ_ALLOW_LEGACY_BN254` | off | **Yes** | Allows the legacy BN254 proving and verification classes |
| `zeroj.jubjub.debugSecretSubgroupChecks` | — | off | **Yes** (diagnostic) | Adds a subgroup assertion inside the off-circuit Jubjub secret-scalar helpers |

A switch is on when the system property is `true` (via `Boolean.getBoolean`), or when the
environment variable equals `true` (case-insensitive). Either one is enough.

### `zeroj.allowInsecureTrustedSetup`

Groth16 needs a trusted setup whose secret ("toxic waste") must be destroyed. ZeroJ's in-process
setup generates that secret itself, so whoever runs it could forge proofs. The following refuse to
run unless the switch is on:

- `PowersOfTauBLS381.generate(...)`
- `Groth16SetupBLS381.setup(...)` and `Groth16SetupBLS381.setupToStore(...)`
- `Groth16Keys.setupInMemory(...)` and `Groth16Keys.setupToStore(...)`, which call the above
- the SRS cache, and the legacy BN254 setup classes `PowersOfTau` and `Groth16Setup` (which also
  need the BN254 switch below)

Without it you get:

```text
java.lang.IllegalStateException: Single-party trusted setup is disabled by default because the generator knows toxic waste and can forge proofs. Production deployments must use imported MPC ceremony artifacts and pinned artifact hashes. For local development or tests only, start the JVM with -Dzeroj.allowInsecureTrustedSetup=true.
```

Turn it on for tests and local experiments only:

```bash
java -Dzeroj.allowInsecureTrustedSetup=true -jar my-dev-app.jar
# or
ZEROJ_ALLOW_INSECURE_TRUSTED_SETUP=true ./gradlew run
```

```groovy title="build.gradle"
tasks.withType(Test).configureEach {
    systemProperty 'zeroj.allowInsecureTrustedSetup', 'true'   // tests only
}
```

Production keys come from a multi-party ceremony and are imported (`ZkeyPkStoreImporter`,
`ZkeyImporterBLS381`); importing and proving with them needs no switch. The constants are
`TrustedSetupPolicy.ALLOW_INSECURE_TRUSTED_SETUP_PROPERTY` and
`TrustedSetupPolicy.ALLOW_INSECURE_TRUSTED_SETUP_ENV`, and
`TrustedSetupPolicy.insecureTrustedSetupEnabled()` tells you whether it is on.

### `zeroj.allowLegacyBn254`

BN254 is not a Cardano curve. Plutus has no BN254 builtins. ZeroJ keeps a few BN254 classes for
old off-chain experiments, disabled by default and not registered with `ServiceLoader`. Without the
switch they fail with:

```text
java.lang.IllegalStateException: BN254 is disabled by default because ZeroJ targets Cardano production flows and Cardano only supports BLS12-381 on-chain. For legacy off-chain experiments, start the JVM with -Dzeroj.allowLegacyBn254=true.
```

The constants are `LegacyCurvePolicy.ALLOW_LEGACY_BN254_PROPERTY` / `ALLOW_LEGACY_BN254_ENV`, and
`LegacyCurvePolicy.legacyBn254Enabled()` reports the state. Use BLS12-381 instead.

### `zeroj.jubjub.debugSecretSubgroupChecks`

A diagnostic for the off-circuit Jubjub helpers in `zeroj-circuit-lib` (`EdDSAJubjub`,
`PedersenCommitment`, `PedersenVectorCommitment`). When set, their blinded secret-scalar multiplication first asserts that the
point is in the prime-order subgroup and throws `IllegalStateException` otherwise. Leave it unset
unless you are debugging those helpers.

:::danger[Fail closed in production]
Make production services refuse to start if a development switch is on:
`if (TrustedSetupPolicy.insecureTrustedSetupEnabled() || LegacyCurvePolicy.legacyBn254Enabled()) throw …`.
Remember that the environment variables work too: check the deployment environment, not just the
command line.
:::

## Native blst library

The default path is pure Java. Native code enters only if you add `zeroj-blst` or a module that
uses it:

| Where blst is used | Binding | Pulled in by |
|---|---|---|
| Groth16 prover MSM (`BlstProverBackend`) | Java 25 FFM, with a `libblst` built from source (pinned v0.3.15) and bundled in the `zeroj-blst` jar | `zeroj-crypto-blst` |
| Pairing for `Groth16BLS12381Verifier` (off-chain) and `BlstBls12381Provider` (BBS) | JNI via `foundation.icon:blst-java` | `zeroj-verifier-groth16`, `zeroj-blst` |

How the FFM library is found:

- There is **no path setting**. `BlstFfm` picks `/native/<os>/<arch>/libblst.<ext>` from the jar
  (`os` is `linux`, `mac` or `windows`; `arch` is `amd64` or `aarch64`, with `x86_64` on macOS),
  copies it to a temp file named `libblst-zeroj-*`, and loads it. The JVM needs a writable temp
  directory.
- Release builds rebuild the bundled binaries from source for each supported platform. macOS is
  **arm64-only**: Intel Macs can't use the blst prover backend but work normally on the pure-Java
  default.
- If your platform has no bundled binary, the first blst MSM call fails with an error containing
  `Bundled libblst not found for this platform`. Stay on the pure-Java path.
- FFM downcalls need native access enabled:

```bash
java --enable-native-access=ALL-UNNAMED -cp … my.App
```

GraalVM native-image metadata for `zeroj-blst` ships under
`META-INF/native-image/org.zeroj/zeroj-blst/`.

## External tools: circom and snarkjs

The published ZeroJ libraries **never launch external processes**. Nothing at runtime looks for
`circom` or `snarkjs`. You run those tools yourself, from your `PATH`, and hand ZeroJ their output
files (`.r1cs`, `.zkey`, `.wtns`, `*.json`):

```bash
# circom 2.x: build it from source as described at https://docs.circom.io/getting-started/installation/
npm install -g snarkjs          # ZeroJ's interop tests pin snarkjs 0.7.6

circom circuit.circom --r1cs --wasm --sym -p bls12381   # BLS12-381, not the default BN254
```

ZeroJ's own test suite finds snarkjs through the `SNARKJS_BIN` environment variable, then a few
common npm install locations, then `PATH`. See [Bring circom & snarkjs circuits](/tutorials/snarkjs-interop/).

## Gradle flags for contributors

These only matter when you build the ZeroJ repository itself. Use the Gradle wrapper.

| Command or flag | What it does |
|---|---|
| `./gradlew build` | Default pure-Java build: no Go, Rust, Node.js, WASM toolchain or RocksDB needed |
| `-PincludeAssurance` | Adds the WASM differential oracles (`zeroj-bls12381-wasm`, `zeroj-bbs-wasm`; need Rust + the `wasm32-unknown-unknown` target). Also makes `:zeroj-bbs:test` run the official BBS vectors through the WASM provider. |
| `-PincludeBenchmarks` | Adds the MPF/JMT RocksDB load and benchmark tools |
| `-PrequireSnarkjs` | Makes the snarkjs interop suites in `zeroj-integration-tests` **fail** instead of skip when snarkjs 0.7.6 is missing (sets `zeroj.assurance.requireSnarkjs=true`) |
| `./gradlew :zeroj-integration-tests:e2eTest` | Runs `@Tag("e2e")` tests: Yaci DevKit on-chain flows and snarkjs proving. They skip gracefully when Yaci DevKit (`localhost:8080`) or snarkjs is absent. |
| `./gradlew verifyDefaultModuleSurface` | Checks the stable module graph has no edge into assurance, benchmark or removed modules |

```bash
./gradlew -PincludeAssurance :zeroj-bls12381-wasm:test :zeroj-bbs-wasm:test :zeroj-bbs:test
./gradlew -PincludeBenchmarks :zeroj-mpf-poseidon-load:build :zeroj-jmt-poseidon-load:build
./gradlew -PrequireSnarkjs :zeroj-integration-tests:test
```

Inside the repository, every test JVM already runs with `--enable-native-access=ALL-UNNAMED` and
`zeroj.allowInsecureTrustedSetup=true` (and `zeroj-crypto`'s tests also set `zeroj.allowLegacyBn254`).
That is test scaffolding. Don't copy it into application run configurations.

Opt-in benchmark tasks such as `:zeroj-crypto:benchmark`, `:zeroj-crypto-blst:blstBench` and
`:zeroj-circuit-lib:heavyGadgetTest` set their own internal `zeroj.bench` / `zeroj.heavy`
properties. They are heavy and never part of `test`.

## Next steps

- [Installation](/start/installation/)
- [Secure your ZK application](/guides/verifying/application-security/#development-flags-never-reach-production)
- [FAQ & troubleshooting](/reference/faq/)

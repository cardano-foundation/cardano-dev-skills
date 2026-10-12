# ADR-0001: Account-Ownership Proof CLI — a Standalone Distributable for Proof Generation & Verification

## Status
Proposed (2026-07-08) — awaiting review; implementation starts after approval.

## Context

The **account-ownership proof** usecase lets the holder of an HD wallet prove — in zero knowledge —
that they know the **root key** behind a given address: the circuit re-derives the full CIP-1852
path (`m/1852'/1815'/account'/role/index`) in-circuit from the secret root key and asserts it
reaches the address's public payment key hash. The proof reveals nothing about the seed and can be
verified **off-chain** (pure Java pairing check) or **on-chain** (a Plutus V3 validator,
cost-independent of circuit size). This is a general primitive: address-ownership attestation,
account recovery authorization, credential binding, and similar flows where a signature from the
leaf key is unavailable or insufficient.

The full flow — the circuit, services, and on-chain validator — works end to end, but the missing
piece was an artifact an end user can download and run (rather than developer `main`-class harnesses
and gradle test tasks).

**Goal:** a self-contained CLI app — `account-ownership-recovery-cli` — distributed as a zip on the
zeroj-usecases GitHub release page. A user extracts it and drives everything from the command line:
one-time trusted setup (normally done by a coordinator team), proof generation, and off-chain or
on-chain verification.

### Measured realities that shape the design (from the ZeroJ ADR-0029/0031 work)

| fact | value |
|---|---|
| circuit | 19,075,097 constraints / 43.7M wires / evaluation domain 2²⁵ |
| one-time trusted setup (local single-party) | ~47 min, needs ~90 GB heap |
| proving key on disk (`Groth16PkStore`) | ~23 GB |
| proof generation (warm keys) | ~2 min mmap key load + ~2.3 min prove (blst multi-core) ≈ **4.5 min** |
| prove peak memory | ~66–70 GB heap → needs a **~64 GB+ RAM machine** |
| on-chain verification | one transaction, fee ≈ 0.95 ADA (measured on a local devnet) |
| prepared 2²⁵ `.ptau` (universal phase-1 powers) | ~32 GB — **cannot be bundled** with the app |
| snarkjs at 2²⁵: per contribution / one-time `prepare phase2` | ~2.5–3 h / ~60–105 h (cacheable forever) |

Two consequences follow directly:

1. **A coordinator/user split is unavoidable.** Setup is expensive and produces a 23 GB key; it is
   done **once** by the team operating the flow, and the exported key bundle is published for
   users to download. Users start at proof generation and finish in ~3–5 minutes.
2. **No tau can ship inside the zip.** The "quick testing" path is therefore the *local
   single-party* setup (which needs only a generated tau scalar — no download at all), while
   real-trust setups consume an external prepared `.ptau`.

## Decision

> Dependency update (2026-08-03): the repository-wide CCL baseline is now
> `0.8.0-pre5-dev1`. The `0.8.0-pre4` value below records the original ADR decision and is
> superseded by the shared version configuration.

### 1. Standalone application, self-contained by construction

A new independent gradle project at `zeroj-usecases/account-ownership-recovery-cli/`:

- Own `settings.gradle`, own gradle 9.2.0 wrapper — the established pattern in this repository
  (every usecase and example is already an independent build; the root includes nothing).
- **All dependency versions inlined** in the app's own `gradle.properties`
  (`zeroj 0.1.0-pre5` — resolved from mavenLocal for now, Maven Central later —
  `julc 0.1.0-pre14`, `ccl 0.8.0-pre4`). No reliance on the repo-root version script: the project
  builds identically if copied out of the repository.
- Plain `java` application with **picocli** (no Spring Boot). JVM flags baked into the start
  script: `--enable-native-access=ALL-UNNAMED` (blst FFM), large default heap, and the
  insecure-setup system property applied **only** for the local `setup`.
- **Self-contained sources**: the six classes of the library usecase (circuit `OwnershipProof`,
  on-chain `OwnershipProofValidator`, services `OwnershipCircuitService`, `OnChainOwnershipService`,
  `ProofCompressor`, `LocalJulcEvaluator`) are **copied** into the app's package — no gradle
  dependency on any other project in this repository. Both annotation processors run at build time
  (zeroj circuit processor → generated `*Circuit`; julc processor → compiled Plutus validator).

### 2. Command surface

The CLI is **snarkjs-free**: the multi-party phase-2 ceremony runs entirely *outside* the tool.
`export-r1cs` feeds it; `import` brings the finalized key back. Every command is pure Java.

```
account-ownership-recovery-cli
├── export-r1cs  --out <file>                                    (coordinator: r1cs for external ceremony)
├── import       --zkey <finalized.zkey> [--keys <dir>]          (coordinator: ceremony key → bundle)
├── setup        --i-understand-insecure [--keys <dir>]          (LOCAL dev/testing bundle only)
├── prove        [--keys <dir>] [--out <dir>] [--account N] [--index N] [--backend blst|java]  (user, ~3–5 min)
├── verify       [--offchain] [--proof <dir>] | --onchain [--bf-url <url>] [--bf-key <key>]     (user)
└── info         [--keys <dir>]                                  (bundle status / fingerprint)
```

Both `setup` (local) and `import` (ceremony) produce the same `keys/` bundle: the proving-key store
(~23 GB, mmap-loadable), `vk.json`, the circuit fingerprint, and `SHA256SUMS` for integrity.

| bundle source | what happens | trust level | cost |
|---|---|---|---|
| `setup` (local) | single-party setup from a generated tau scalar; no snarkjs, no downloads | **dev/testing only** — the machine that ran it could forge proofs; requires `--i-understand-insecure`. Run once + cache the bundle for demos. | ~47 min on a ~90 GB-heap machine |
| `export-r1cs` → external ceremony → `import` | `export-r1cs` writes the iden3 `.r1cs`; the operator runs the phase-2 ceremony externally (`snarkjs groth16 setup` + `zkey contribute` per contributor + `zkey beacon` + `zkey verify`) against a **prepared BLS12-381** ptau (≥ 2²⁵); `import` streams the finalized `.zkey` into the store (pure Java, checks it is for this circuit) | as strong as the ptau + phase-2 ceremony used | minutes for the CLI steps; the ceremony's time is external |

> **Design evolution:** earlier drafts had the CLI orchestrate snarkjs internally (`--tau ptau`,
> `--ptau`/`--ptau-url`, a `filecoin` auto-download/convert mode). That coupled the tool to snarkjs,
> to ptau formats, and to an unproven Filecoin conversion. It was simplified to push the ceremony
> fully external: **`export-r1cs` + `import`** are the only seams, and the CLI itself needs no
> snarkjs. Obtaining/preparing a BLS12-381 phase-1 (Filecoin, Zcash) into a `.ptau` is an out-of-band
> operator step; the ceremony consumes it, and the CLI only imports the finalized key.

**`prove`** — prompts for the mnemonic with hidden input (**never** accepted as a CLI argument,
environment variable, or file); derives the root key in-process; computes the witness; loads the
mmap'd proving key; proves with the blst multi-core backend; writes `proofs/proof.json` +
`public-inputs.json` (+ the address/pkh it binds to). Seed material never touches disk or network.

**`verify`** — off-chain (default): pairing check against the bundle's VK — seconds, no network.
On-chain: locks a gate UTxO with datum = the address pkh at the bundled Plutus validator and
unlocks it with the proof via a Blockfrost-compatible API; `--bf-url` defaults to a local Yaci
DevKit (`http://localhost:8080/api/v1/`), `--bf-key` optional (required by hosted providers).

### 3. Directory layout (predefined, documented)

```
account-ownership-recovery-cli/          ← extracted zip
├── bin/account-ownership-recovery-cli   ← start script (heap + native-access flags)
├── lib/account-ownership-recovery-cli-all.jar
├── README.md  USAGE.md
├── keys/                                ← the published key bundle goes here (manual download)
│   ├── pointsA.bin … pointsB2.bin       ← proving-key store (mmap-loaded)
│   ├── aux.bin  manifest.properties     ← VK + dimensions
│   ├── circuit.fingerprint              ← constraint count + R1CS hash
│   └── manifest.sha256                  ← integrity manifest (checked by prove/verify/info)
└── proofs/                              ← prove output
```

The coordinator publishes the `keys/` bundle (e.g. release asset or storage bucket); users drop it
into the extracted app directory. `info` and every command validate the manifest before use.

### 4. Distribution

Two zips, both uploaded to the zeroj-usecases GitHub release:

- **Fat-jar** (`./gradlew distZip`) — `account-ownership-recovery-cli-<version>.zip`: the fat jar,
  RAM-auto-sizing start scripts (unix + windows), README + USAGE. Runs on any JDK 25. This is the
  vehicle for heavy proving (fast blst backend, standard heap handling).
- **Native binary** (`./gradlew nativeDistZip`, GraalVM) —
  `account-ownership-recovery-cli-<version>-<platform>.zip`: a single self-contained executable
  (built `--no-fallback --enable-native-access` + `-H:-UseCompressedReferences` so >32 GB heaps
  work). Best for `verify` + `info` — no JVM, instant startup (off-chain verify ~0.1 s). It also
  proves, but on the pure-Java backend: blst reaches `libblst` via FFM downcalls that aren't
  registered in the image, so proving is routed to pure-Java (slower than the fat jar). A follow-up
  can register the FFM/foreign metadata (tracing agent) to enable blst in the image. Docker image is
  a further follow-up.

## Security considerations

- **Seed handling:** mnemonic via hidden interactive prompt only; root key derived in-process;
  nothing secret is written or transmitted. The proof + public inputs are the only outputs.
- **Setup trust:** `local` keys are for development/testing — whoever ran the setup can forge
  proofs. Any production deployment must publish a bundle produced from the `ptau` path, ideally with
  a multi-party phase-2 ceremony (ZeroJ ADR-0031 tooling: snarkjs or the `zeroj-ceremony` native
  contributor; verification always via stock `snarkjs zkey verify`). The `.ptau` must be BLS12-381
  (header pre-check enforces this).
- **Bundle integrity:** users verify `manifest.sha256` (automated by the CLI) against the hashes
  the coordinator publishes; the circuit fingerprint pins the exact R1CS the keys bind to.
- **On-chain gate:** the demo validator verifies the proof against the datum-pinned pkh; it does
  not bind the spending transaction context — production validators must add that (replay
  protection), as already documented in the usecase.

## Limitations (stated plainly)

- **Proving hardware:** ~64 GB+ RAM required today (measured ~66–70 GB peak). Mitigations tracked
  upstream: hint-based circuit reduction (~19M → ~11–12M) once the gadget audit clears; witness
  streaming; optionally a remote-proving deployment of this same app on a server.
- **The phase-2 ceremony is on the operator:** obtaining a BLS12-381 phase-1 (Filecoin, Zcash),
  preparing it, and running `snarkjs groth16 setup`/`contribute`/`beacon`/`verify` all happen out of
  band. The CLI only produces the `.r1cs` (`export-r1cs`) and imports the finalized `.zkey`
  (`import`); it needs no snarkjs.
- The app pins one derivation path shape (`account'/0/index`, configurable indices); other roles
  or multi-address batching are follow-ups.

## Implementation milestones (post-review)

| # | milestone | exit criteria |
|---|---|---|
| M1 | scaffold (standalone gradle + picocli) + `setup` (local) + keys export/manifest | fresh checkout builds independently; setup produces a loadable bundle; `info` validates it |
| M2 | `prove` | proof generated from a real mnemonic against M1 keys in ≤ 5 min warm; secrets never persisted |
| M3 | `verify` off-chain + on-chain | off-chain pairing check green; on-chain verify green against Yaci DevKit with default endpoint |
| M4 | `export-r1cs` + `import` | export the iden3 r1cs; import a finalized ceremony `.zkey` (pure Java) into a bundle that proves + verifies, with a circuit-match check |
| M5 | snarkjs-free simplification | remove internal snarkjs/ptau orchestration; ceremony is external; CLI surface = export-r1cs / setup / import / prove / verify / info |
| M6 | `distZip` + `nativeDistZip` + README/USAGE + release upload wiring | zips install + run on a clean machine; docs cover both roles end to end |

Each milestone: implement → test → iterate before moving on. (M4/M5 originally scoped an
internal snarkjs `--tau ptau`/`filecoin`/`--ptau-url` orchestration; it was delivered and then
simplified out in favor of the external-ceremony `export-r1cs`/`import` seam above.)

## References

- ZeroJ ADR-0029 (prover performance: mmap'd key store, multi-core blst prover — the numbers above)
- ZeroJ ADR-0031 (MPC trusted-setup ceremony: r1cs export, streaming zkey import, native contributor, phase-1 source analysis)
- ZeroJ `docs/account-ownership-why-zk.md` (why root-key knowledge, proven in zero knowledge, is the only sound ownership attestation)

## Amendment 2026-09-05 — preserve exact key-store fingerprints

Risk: R2, integration metadata at the circuit/key boundary. This implements the existing
ZeroJ exact-relation binding contract introduced by
[ZeroJ commit 5c561d6](https://github.com/bloxbean/zeroj/commit/5c561d6a9f59fbd7d2b390477b5e144f805cd302)
(PR #26), without changing proof equations, serialization, witnesses, or secret operations.

The shared CLI/UI bundle writer must preserve `Loaded.circuitFingerprint()` from a validated
`Groth16PkStore.load`, rather than replace it with a dimensions-only label. Before writing,
metadata wire/public counts must match the loaded store; for bound stores, all three dimensions
must also match the exact fingerprint. Missing/corrupt stores fail before metadata is replaced.
The key manifest and underlying setup/ceremony remain trusted inputs: copying the fingerprint
is not independent certification of a ceremony. No key is newly bound by this operation.

A store with no exact binding retains its legacy dimensions-only metadata. This does not upgrade
its assurance or bypass the pipeline's existing restrictions. Existing bundles whose CLI metadata
lost a bound fingerprint need metadata regenerated from their validated store (and integrity sums
regenerated); they are not silently rebound while proving. CLI and UI proving continue to pass the
stored metadata fingerprint unchanged, and mismatching exact fingerprints remain rejected.

Verification: small real sparse and dense key stores must round-trip their exact fingerprint,
prove through the cached pipeline without recompilation, and pairing-verify. Negative tests cover
dimension mismatches, corrupt/missing stores, and a different relation with identical dimensions.
The gated full account-ownership setup/prove/verify test must confirm exact fingerprint propagation
through bundle and proof metadata. Existing external-review and production-ceremony gates remain.

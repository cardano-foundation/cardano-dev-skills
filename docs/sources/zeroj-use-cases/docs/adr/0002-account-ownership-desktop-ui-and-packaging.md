# ADR-0002: Account-Ownership Desktop UI + Self-Contained Cross-OS Packaging

## Status
Proposed (2026-07-13) — awaiting review; implementation starts after approval. Follows
[ADR-0001](0001-account-ownership-proof-cli.md) (the CLI).

## Context

The account-ownership CLI (ADR-0001) works end-to-end — local/imported key bundle → prove →
off-chain/on-chain verify — and ships as a fat-jar zip, a Docker image, and per-OS native zips.
It targets developers and coordinators comfortable with a terminal.

We now want a **desktop app for non-technical users**: download and install one file, then click
through the flow. Two things drive this ADR:

1. **A GUI** that wraps the existing prove/verify flow and, crucially, lets the user **either
   download a pre-generated key bundle from a URL** (the trustworthy, coordinator-published,
   ceremony-produced keys) **or run a local single-party setup** (dev/testing). The download must
   show progress — the bundle is large.
2. **Self-contained packaging with a bundled JRE 25 for Windows, macOS, and Linux**, so the user
   downloads nothing else (no "install Java first"). The bundled runtime must be an **open-source
   OpenJDK build**, not Oracle JDK, for redistribution-licensing reasons.

### Measured realities that shape the design (carried from ADR-0001 / ZeroJ ADR-0033/0034/0035)

| fact | value | UI/packaging implication |
|---|---|---|
| circuit | ~19.07M constraints, fingerprint `c19075365-w43743286-p28` | keys are circuit-specific; a downloaded bundle must match the app's fingerprint |
| key bundle on disk | **~9.6 GB** (sparse default) | download must be resumable + show progress; needs ~11 GB free disk |
| prove heap | ~7–8 GB (8 GB first run, 7 GB cached) | app must size heap to the machine and warn on low RAM |
| setup heap / time | ~8 GB / ~5–6 min | same; setup is the "generate locally" path |
| prover backend | **pure Java by default** (blst is opt-in, lazy) — since the ProofCompressor fix, setup/prove/verify need **no native lib** | packaging carries no blst; works on every OS incl. Windows |
| verify off-chain | pure Java, ~0.2 s | trivial in-app |
| verify on-chain | 1 lock + 1 unlock tx (Yaci DevKit / Blockfrost) | needs a node/Blockfrost endpoint + a funded payer wallet |

The pure-Java default is what makes a clean cross-OS bundle possible: the app is a **JVM app**, and
prove/setup are JIT-favoured (native-image proving measured *slower*), so we bundle a HotSpot JRE
rather than compile a native image.

## Decision

### 1. Module layout — `account-ownership/` with two modules: `cli` and `ui`

Promote the account-ownership usecase to a top-level **`account-ownership/`** multi-project Gradle
build in zeroj-usecases:

```
account-ownership/
├── settings.gradle            # includes :cli and :ui
├── gradlew, gradle/           # one wrapper for the whole app
├── cli/                       # the current CLI: service layer + picocli (core merged in — no separate module)
└── ui/                        # new JavaFX desktop app; depends on :cli for the service classes
```

- **No separate `core` module** — the reusable service layer (`OwnershipCircuitService`,
  `Groth16Pipeline` usage, `OffchainVerifier`, `ProofIO`, `VkIO`, `WalletDerivation`, `Bundle`,
  `ProofCompressor`) stays in `:cli`; the picocli command classes sit alongside it. `:ui` depends
  on `:cli` and calls those service classes directly. Two modules, as simple as it gets.
- **Version** comes from the repo-root `version.properties` (`version=…`), read by the existing
  walk-up logic — both modules and all release artifacts share it. `-PreleaseVersion` overrides for
  tagged builds.
- **Migration**: the existing `account-ownership-recovery-cli/` build moves under
  `account-ownership/cli/`. Release-asset and Docker-image names are kept as
  `account-ownership-recovery-cli` (continuity of existing release URLs); the new UI ships as
  `account-ownership-recovery-ui`.

### 2. UI toolkit — JavaFX 25

Chosen for its async story: a `javafx.concurrent.Task`/`Service` exposes `progressProperty()` that
binds directly to a `ProgressBar`, which is exactly what the 9.6 GB download and the multi-minute
setup/prove need for live progress without hand-rolled threading. CSS styling gives a modern look.

Screens: **(1)** key-source chooser — *Download official keys* vs *Generate locally (dev/testing)*;
**(2)** progress screen (download or setup) with cancel; **(3)** prove — mnemonic + `role`/`index`,
progress, result; **(4)** verify — off-chain, and on-chain (DevKit/Blockfrost with payer wallet).

### 3. Packaging — `jlink` + `jpackage`, bundled **open-source** JRE 25, per OS

- **`jlink`** builds a trimmed runtime containing only the modules the app uses;
  **`jpackage`** wraps it + the app into a native installer: `.msi`/`.exe` (Windows, WiX),
  `.dmg`/`.pkg` (macOS), `.deb`/`.rpm` (Linux). The user double-clicks to install; **no Java
  download**.
- **Runtime provenance = open source.** The jlink/jpackage pipeline runs on an **OpenJDK
  distribution under GPLv2 + Classpath Exception**, so the bundled runtime is freely
  redistributable. **Oracle JDK is explicitly not used.** Preferred base: **BellSoft Liberica JDK
  25 "Full"** — an OpenJDK build that already bundles OpenJFX (GPLv2+CE), so jlink can include the
  `javafx.*` modules without a separate OpenJFX kit. Acceptable equivalents: Eclipse Temurin 25 +
  the OpenJFX jmods, Azul Zulu, Microsoft Build of OpenJDK, Amazon Corretto (all OpenJDK GPLv2+CE).
- **No cross-compilation**: jpackage builds for the OS it runs on, so a Windows/macOS/Linux CI
  runner each — the same matrix pattern as the native-image release job.
- **Heap sizing**: launch with `--java-options "-XX:MaxRAMPercentage=80"` so heap scales to the
  machine instead of a fixed `-Xmx8g`; the app checks total RAM at startup and **warns before
  setup/prove if under ~10 GB** (they will otherwise OOM).

### 4. Key-source options

- **Download official keys** — fetch the coordinator-published, ceremony-produced bundle via
  `java.net.http.HttpClient`: **resumable** (HTTP `Range`, so a dropped 9.6 GB transfer resumes),
  live byte progress, pre-flight disk-space check, then **verify `SHA256SUMS` and the circuit
  fingerprint** (the bundle must match the app's circuit) before use. This is the trustworthy path.
- **Generate locally** — the single-party `setup` (`--i-understand-insecure` equivalent), clearly
  labelled dev/testing only. Maps to ADR-0001's trust model.

### 5. Security

The mnemonic is entered in a `PasswordField` (`char[]`), used only to derive the root key, and
**cleared immediately after** — never logged, persisted, or sent, matching the CLI's discipline.
Only `proof.json` + `public-inputs.json` are written.

## Alternatives considered

- **Swing instead of JavaFX** — zero extra dependencies and `SwingWorker` covers progress; viable,
  but JavaFX's property-bound progress and modern styling win for this download-heavy UX. Kept as a
  fallback if the OpenJFX bundling proves troublesome.
- **Compose Multiplatform / Electron / web UI** — rejected: they don't reuse the existing Java
  crypto/service layer and add a large foreign runtime for a small tool.
- **GraalVM native-image app (no bundled JRE)** — rejected: prove/setup are JIT-favoured (native
  proving is slower), and blst/FFM + JavaFX under native-image is fragile. The bundled-JRE JVM app
  is both faster for the workload and simpler.
- **Hydraulic Conveyor instead of jpackage** — genuinely attractive (builds all-OS packages *and*
  an auto-updater from a single machine, free for OSS). Recorded as a strong option if the per-OS
  jpackage CI matrix or the lack of built-in updates becomes painful; jpackage is the default for
  zero third-party tooling and full control.

## Consequences

- **Per-OS CI matrix** for jpackage (Windows/macOS/Linux runners), extending the existing release
  workflow.
- **Signing/notarization** is needed for a warning-free install (macOS Gatekeeper via `--mac-sign`
  + notarization; Windows SmartScreen via a code-signing cert). Deferrable with right-click-open
  instructions initially; required for a polished GA.
- **The 9.6 GB download is the main UX cost.** Strongly recommend finally building the ADR-0035
  **M6b-lite point-compressed distribution (~5.5 GB)** — the single biggest win for the download
  path, already scoped (G1 x-only compression, trivial Fp sqrt). Tracked as a dependency, not a
  blocker.
- **Installer size** ≈ trimmed JRE (~40–70 MB) + app/deps; the multi-GB keys are **never** in the
  installer — they're downloaded or generated on first run.
- Both distributions coexist: `:cli` (power users, CI, coordinators) and `:ui` (everyone else),
  from one version and one build.

## Rollout (post-approval)

1. Restructure into `account-ownership/{cli,ui}` (move CLI; wire root-version resolution; keep CLI
   artifact/image names).
2. `:ui` skeleton — JavaFX app + the key-source chooser.
3. Resumable download + progress + SHA256/fingerprint verification (the highest-detail piece).
4. Prove/verify screens on the service layer.
5. `jlink` + `jpackage` Gradle wiring; per-OS CI matrix producing installers.
6. (Later) signing/notarization; M6b-lite compressed bundle to shrink the download.

## Implementation notes (as built, 2026-07-13)

- **`Flows` facade** (`:cli`): all flows are exposed with `Path`/primitive/`Consumer<String>`
  signatures, so `:ui` imports **no** ZeroJ crypto types (`:cli` declares those deps as
  `implementation`, not transitively visible). Everything runs the **pure-Java** backend.
- **JavaFX in the fat jar, not the runtime.** The platform-classifier OpenJFX jars carry their own
  native libs, so bundling them in the app's fat jar means the jlink'd runtime needs no `javafx.*`
  modules and **any OpenJDK 25 works as the base** (Temurin in CI, GraalVM CE validated locally) —
  the earlier "Liberica Full" note is relaxed to "any OpenJDK build". A `Launcher` class (not
  extending `Application`) is the entry point so classpath-mode FX launches cleanly.
- **jpackage validated** on macOS: `jpackageAppImage` → a 159 MB self-contained `.app`;
  `jpackageInstaller` → a 78 MB `.dmg`, both with a bundled `jlink` runtime
  (`java.se,jdk.crypto.ec,jdk.crypto.cryptoki,jdk.unsupported`). macOS forbids a zero major version,
  so a `0.x` release version is coerced to `1.0.0` for the bundle (overridable with
  `-PappVersion`); the real version stays in `version.properties`.
- **Testing** (all headless / CI-friendly): `ResumableDownloaderTest` (resume + SHA over a local
  HTTP server), `FlowsExtractTest` (extract + zip-slip), `FlowsE2ETest` (generate→prove→verify,
  gated `-Daor.e2e=true`), and `AppUiTest` (**TestFX + Monocle drives the real JavaFX 25 app with no
  display** — navigation + validation).
- **Still open**: on-chain verify (stubbed "coming soon"); signing/notarization for a warning-free
  install; M6b-lite compressed bundle to shrink the download.

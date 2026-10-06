---
title: Performance & large circuits
description: How ZeroJ's pure-Java Groth16 prover handles millions of constraints, how to size memory, when the optional blst backend helps, and JVM and GraalVM notes.
sidebar:
  order: 3
---

Small circuits need no tuning. This page is for the other end:
circuits with millions of constraints, where memory is the constraint that bites first. All of
it is about **Groth16 on BLS12-381**, the focus of the current release. Verification cost doesn't
grow with the circuit (a few pairings plus one scalar multiplication per public input), so
everything here concerns proving and setup.

## Where the cost goes

| Phase | What happens | What it needs |
|-------|--------------|---------------|
| Compile | Build the circuit graph, emit R1CS rows | Heap proportional to the circuit graph |
| Witness | Evaluate every gate | Heap for the graph plus one value per wire |
| Setup (dev) or import (ceremony) | Produce the proving key: several points per wire | Disk for the key; heap if you keep the key in memory |
| Prove: H | FFTs over the constraint domain | Heap for a few domain-sized arrays |
| Prove: MSMs | Multi-scalar multiplications over the key | Reads the whole key once; CPU-bound |

## How the pure-Java prover stays lean

The default prover in `zeroj-crypto` has no native dependencies. Several design choices keep large
circuits within ordinary machines:

- **Allocation-lean arithmetic.** Field elements and curve points are packed `long[]` limbs in
  Montgomery form rather than objects, so the hot loops allocate very little.
- **Memory-mapped key stores.** A store-backed proving key is memory-mapped (through the Java
  FFM API), so its points live in the OS page cache instead of the Java heap. The *sparse* store
  format stores points at infinity as one bit each.
- **Streaming setup.** `setupToStore` writes every key point straight to the mapped files, so the
  key is never fully resident.
- **Packed constraints and witnesses.** `R1CSFlat` stores the matrices in CSR form, and
  `FlatScalars` stores the witness as packed limbs instead of millions of `BigInteger`s.
- **Ordered peaks.** `Groth16Pipeline` generates the witness *before* it maps the cached
  constraints, and drops the constraints before the MSMs, so the big memory peaks never overlap.
- **Parallel MSMs.** `ProverBackend.PURE_JAVA` splits large MSMs across cores; the result is
  bit-identical to the single-threaded `ProverBackend.PURE_JAVA_SERIAL`.

## The scale reference: a 19M-constraint circuit

ZeroJ's largest real circuit proves Cardano account ownership in-circuit: CIP-1852 key derivation
from a root key to a payment key hash. It has 19,075,097 constraints, about 43.7 million wires,
and an FFT domain of 2²⁵. It drove the memory work, and ZeroJ's design records report these
measurements:

| Measurement | Result | Context |
|-------------|--------|---------|
| Dev setup, before the setup work | ~90 GB heap, ~47 min | 23 GB key bundle, in-heap setup |
| Setup → prove → verify, after | Setup 9.6 min, prove 161 s, verify 0.17 s | One Docker container capped at 16 GB total memory, `-Xmx8g`, sparse key store |
| Sparse vs dense key store | 9.3 GB vs 24.2 GB of point files | Same circuit |
| Prove heap floor | About 7 GB | Set by witness generation for this circuit, not by proving |

:::note[Read these as one data point]
These are single-machine measurements from ZeroJ's design records
([ADR-0033](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0033-prover-memory-reduction.md),
[ADR-0034](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0034-frontend-memory-reduction.md),
[ADR-0035](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0035-setup-memory-time-reduction.md)),
taken in July 2026 on one circuit. Your circuit shape, hardware, disk, and JVM will change them.
Measure your own circuit before you size machines for it.
:::

## Heap versus page cache

With a store-backed key, memory splits into two budgets:

- **Java heap (`-Xmx`)** holds the circuit graph during compile and witness generation, and the
  FFT buffers during proving. It doesn't hold the key.
- **Page cache** holds the memory-mapped key files. The OS manages it: with spare RAM the key
  stays cached and proving is fast; under pressure it pages key data in from disk, which is
  slower but still works. That's how the 19M circuit fits in a 16 GB cap with an 8 GB heap.

So don't give the heap all your RAM. Size `-Xmx` to your measured heap floor plus headroom, and
leave the rest for page cache. `Groth16Pipeline.estimateProvePhaseHeapBytes(numWires, domain)`
gives a lower bound for the prove phase only; witness generation for your circuit can need more.
Keep the heap below about 32 GB where you can, because larger heaps turn off compressed object
pointers and inflate every object.

## Recipe for millions of constraints

1. **Compile once to the packed form**: `compileR1CS(CurveId.BLS12_381)` and use `r1cs.flat()`.
2. **Put the key in a store**: `Groth16Keys.setupToStore(..., true)` for development keys, or
   `ZkeyPkStoreImporter.importToPkStore(zkey, dir, sha256)` for a ceremony key. Never `setupInMemory` at this size.
3. **Prove through `Groth16Pipeline`**, so the `r1cs.bin` constraint cache skips recompiling on
   later runs and the memory peaks stay ordered. See
   [Groth16Pipeline](/guides/proving/groth16/#groth16pipeline-for-very-large-circuits).
4. **Release the circuit graph before packing the witness**, then pack with
   `FlatScalars.packConsuming(...)`.
5. **Measure the witness peak.** `calculateWitnessFlat` / `calculateWitnessFlatChunked` avoid
   boxing, which helps typical circuits. In a bit-heavy circuit most wires hold 0 or 1 and share
   the same `BigInteger` objects, so the boxed witness plus `packConsuming` used less memory for
   the 19M circuit. Try both.
6. **Run it as its own JVM process** with explicit flags, rather than inside a build tool's
   default test JVM, which usually has a small heap.

## The optional blst backend

`zeroj-crypto-blst` plugs the native [blst](https://github.com/supranational/blst) library's
multi-scalar multiplication into the prover through the FFM API. It's purely a performance option:
proofs are bit-identical to pure Java, and cross-provider equivalence is tested.

```groovy
implementation 'org.zeroj:zeroj-crypto-blst'   // brings zeroj-crypto and zeroj-blst; version from the BOM
```

```java
import org.zeroj.cryptoblst.BlstProverBackend;

try (var keys = Groth16Keys.load(keysDir)) {
    var proof = keys.prove(BlstProverBackend.create(), witness, r1cs.constraints());
}
```

`BlstProverBackend.create()` is multi-core; `createSerial()` makes one native call per MSM. The
JVM needs native access:

```bash
java --enable-native-access=ALL-UNNAMED -Xmx8g -jar prover.jar
```

What to know before you adopt it:

- **Measure first.** blst measured about 5× faster than the pure-Java prover of the time on
  2¹²–2¹⁶ benchmark circuits. After the later memory and FFT work, the pure-Java prover matches
  it at the 19M scale, so the win depends on your circuit size.
- **It uses native memory outside `-Xmx`.** At the 19M scale, blst's native MSM buffers took
  several GB on top of the heap (about 8.4 GB during the G2 MSM alone), and the process was killed
  under a 16 GB cap. Use it on large-memory machines only.
- **Supply chain.** `libblst` is built from source at pinned tag v0.3.15 and bundled in
  `zeroj-blst` for Linux (x86-64 and AArch64), macOS on Apple silicon, and Windows. Intel Macs
  fall back to pure Java.

## JVM flags

| Flag | When |
|------|------|
| `-Xmx<size>` | Always, for large circuits. Size to your measured floor plus headroom. |
| `--enable-native-access=ALL-UNNAMED` | When you use `zeroj-crypto-blst` or `zeroj-blst` |
| `-Dzeroj.allowInsecureTrustedSetup=true` | Only for development setup; never in production launch scripts |

## GraalVM native image

The pure-Java prover has no JNI, so it can be compiled with `native-image`. For a long,
CPU-bound prove, though, native image is a *deployment* choice, not a speed lever: a warmed-up JIT
matches or beats it. Native image pays off for startup time and footprint, which matter most for
short-lived verifiers and CLIs.

`zeroj-blst` ships native-image configuration that enables native access and bundles the `libblst`
binaries as image resources. Depending on your GraalVM version, the build may also need the
experimental Foreign API support options noted in that configuration. ZeroJ's own `zeroj-ceremony`
CLI is built as a native binary with `--no-fallback --enable-native-access=ALL-UNNAMED`, and its
contribute and finalize commands (streaming, memory-mapped key processing) run in that binary.
Build and test your own image in CI rather than assuming.

## Benchmarks

Both benchmarks are opt-in Gradle tasks in the ZeroJ repository, heavy by design:

```bash
# Pure-Java Groth16 prover scale benchmark (circuit sizes as log2)
./gradlew :zeroj-crypto:benchmark -Dzeroj.bench.logs=12,14,16 -PbenchHeap=10g

# blst MSM and full-prove speedup versus pure Java
./gradlew :zeroj-crypto-blst:blstBench
```

Recorded end-to-end benchmark reports, including five-million-entry Poseidon MPF and JMT state
runs, are in
[docs/benchmarks](https://github.com/bloxbean/zeroj/tree/main/docs/benchmarks).

Further reading: [ADR-0029 (prover performance and blst)](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0029-blst-accelerated-groth16-prover.md),
[alternate prover backends](https://github.com/bloxbean/zeroj/blob/main/docs/alternate-prover-backends.md).

## Next steps

- [Prove with Groth16](/guides/proving/groth16/)
- [Run a trusted setup ceremony](/guides/proving/trusted-setup-ceremony/)
- [Account recovery](/use-cases/account-recovery/), the 19M-constraint circuit in context

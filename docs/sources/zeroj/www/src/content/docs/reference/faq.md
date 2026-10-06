---
title: FAQ & troubleshooting
description: Straight answers about ZeroJ's maturity, proof systems, tooling and performance, plus fixes for the errors you are most likely to hit.
sidebar:
  order: 4
---

## General

### Is ZeroJ production-ready?

No. ZeroJ is experimental research software. It has **not** been externally audited and is not for
production, value-bearing or mainnet use. Its most mature path, Groth16 on BLS12-381, is labelled
**Beta**: feature-complete and correctness-tested (3,500+ tests, with the full flow verified
end-to-end on-chain against Yaci DevKit), and on-chain verification is **testnet only**. Other areas
are experimental. See [Status & maturity](/start/status/).

### Which proof system should I use?

**Groth16 on BLS12-381.** It is the focus of the current release, the default in every guide and
tutorial, and the only proof system with a Beta on-chain verifier. Proofs are small (192 bytes
compressed) and cheap to verify on Cardano. Its one cost is a per-circuit trusted setup; see
[Trusted setup, explained](/learn/trusted-setup/).

PlonK exists in ZeroJ but is **experimental** everywhere, off-chain and on-chain. Don't choose it
for new work. If you only need to reveal some signed attributes (not prove predicates over hidden
ones), look at [BBS](/guides/credentials/bbs/), which needs no circuit and no setup.

### Why BLS12-381 and not BN254?

Cardano's Plutus V3 has built-in BLS12-381 operations (CIP-0381), so a validator can run the
pairing check. There are no BN254 builtins, so BN254 proofs can't be verified on Cardano. ZeroJ
keeps some BN254 classes for old off-chain experiments, disabled by default.

### Do I need Rust, Node.js or native libraries?

No. The default path (circuit DSL, witness generation, trusted setup for development, proving,
verification and on-chain codecs) is pure Java 25, and there is nothing to install beyond a JDK.

- **Native code that is on the classpath anyway:** `zeroj-verifier-groth16` depends on
  `zeroj-blst`, which brings the `blst-java` JNI jar for the module's native
  `Groth16BLS12381Verifier`. `Groth16BLS12381PureJavaVerifier` never loads it, but
  `VerifierRegistry.withServiceLoader()` lists the native verifier first, so construct the
  pure-Java verifier explicitly if you want to stay pure Java.
- **Optional native code:** `zeroj-blst` / `zeroj-crypto-blst` bundle a source-built `libblst`
  for a faster prover MSM. Opt in only after benchmarking; at large sizes the pure-Java prover
  matches it.
- **Optional tools:** circom (Rust) and snarkjs (Node.js) only if you bring circom circuits or run
  a snarkjs ceremony. ZeroJ never launches them itself.
- **Contributors only:** Rust, Go and RocksDB for the opt-in assurance and benchmark projects.

### Can I use my circom circuits?

Yes, for Groth16 on BLS12-381. Compile with `circom circuit.circom --r1cs --wasm --sym -p bls12381`
(circom's default prime is BN254), run the snarkjs setup or ceremony on the BLS12-381 curve, then
either verify snarkjs proofs in Java with `SnarkjsJsonCodec` or import the `.zkey` and prove in
Java with `ZkeyImporterBLS381` / `ZkeyPkStoreImporter`. See
[Bring circom & snarkjs circuits](/tutorials/snarkjs-interop/).

### How big and fast are proofs?

Numbers ZeroJ has measured and published (they depend on hardware and JVM):

| What | Measured |
|---|---|
| Groth16 proof, compressed for Cardano | 192 bytes |
| Groth16 VK, compressed, one public input | 432 bytes |
| Off-chain verification in the JVM | about 115 ms (113–119 ms across runs) |
| Proving circuits of about 10k–74k constraints | about 2.9–4.6 s median |
| On-chain verification, generic verifier, one public input (JuLC VM, full `ScriptContext`) | 2,627,770,348 CPU steps, 177,749 memory units |

The proving, off-chain verification and on-chain figures come from the Poseidon MPF/JMT
benchmarks. Each extra public input adds about 0.2 billion CPU steps on-chain, and your
validator's own checks add more; see
[Verify proofs on Cardano](/guides/verifying/on-chain/#budgets-and-script-size). Circuits with
millions of constraints can be proved within commodity memory using the store-backed keys; see
[Proving performance](/guides/proving/performance/).

### Does a valid proof mean the action is allowed?

No. A proof only shows that someone knows a witness for the circuit and public inputs. Replay
protection, nullifiers, authorization and business rules are yours to build. See
[Secure your ZK application](/guides/verifying/application-security/).

### Why is `accepted()` false when `proofValid()` is true?

Verifier backends only check cryptography. They return `VerificationResult.cryptoValid()`, where
`protocolValid()` is empty and `accepted()` is `false`. Your policy layer decides acceptance, for
example by returning `VerificationResult.ok()`. Check `proofValid()` for the crypto result.

## Errors and fixes

### "Single-party trusted setup is disabled by default…"

```text
java.lang.IllegalStateException: Single-party trusted setup is disabled by default because the generator knows toxic waste and can forge proofs. …
```

You called a development setup (`PowersOfTauBLS381.generate`, `Groth16Keys.setupInMemory`,
`Groth16SetupBLS381.setup`, …) without opting in. For tests and local experiments, start the JVM
with `-Dzeroj.allowInsecureTrustedSetup=true` (or set `ZEROJ_ALLOW_INSECURE_TRUSTED_SETUP=true`).
For anything real, don't flip the switch: run a multi-party ceremony and import its `.zkey`. See
[Trusted setup ceremony](/guides/proving/trusted-setup-ceremony/).

### "R1CS … references wire … outside [0, …)" or "witness length … must match numWires"

Every setup and prove entry point validates the relation's shape before doing any work:

```text
IllegalArgumentException: R1CS A row 3 references wire 9 outside [0, 8)
IllegalArgumentException: witness length (7) must match numWires (8)
IllegalArgumentException: witness[0] must be 1
```

The constraints, `numWires`/`numPublic`, or witness you passed don't describe the circuit the key
was made for. Usually you mixed artifacts from two compilations, or passed a hand-built witness.
Recompile, and pass `r1cs.constraints()`, `r1cs.numWires()` and the witness from
`calculateWitness` for the same circuit. Don't catch and retry.

### "R1CS public wire … is not referenced by any constraint"

```text
IllegalArgumentException: R1CS public wire 2 (public input 2 of 3) is not referenced by any constraint: IC[2] would be the point at infinity and the public input would be unbound by the verification equation (ADR-0045). Constrain the input in the circuit or remove it from the public inputs.
```

A public input that no constraint uses would leave it unbound: the proof would verify for *any*
value. ZeroJ's setup refuses such a relation. Constrain the input, or drop it from the public
inputs. The related message `R1CS constant wire 0 (ONE) is not referenced by any constraint` means
the relation has no constant term. DSL circuits get one from `assertEqual`. A hand-written relation
needs a row that references wire 0, such as `1 * 1 = 1`.

### Witness calculation throws "Constraint violation"

```text
ArithmeticException: Constraint violation: …
```

Your inputs don't satisfy the circuit, which is the circuit doing its job (an under-age input to an
age check, say). Fix the inputs, or catch the exception and report "can't prove this". Related
messages: `Missing public input: <name>` and `Missing secret input: <name>` mean a key is missing
from the input map.

Inputs are reduced modulo the BLS12-381 scalar field before evaluation, so a negative or oversized
number becomes a different field element instead of an error. Range limits must be constraints in
the circuit.

### OutOfMemoryError on a large circuit

`Groth16Keys.setupInMemory` keeps the proving key on the heap, which is fine up to a few hundred
thousand constraints. Beyond that:

- set up with `Groth16Keys.setupToStore(r1cs.flat(), numWires, numPublic, tau, keysDir, true)` and
  reopen with `Groth16Keys.load(keysDir)`, which memory-maps the key;
- import ceremony keys with `ZkeyPkStoreImporter.importToPkStore(zkeyPath, keysDir, verifiedZkeySha256)`
  and load them with `Groth16Keys.load(keysDir, manifestSha256)`, pinned to the hashes;
- for multi-million-constraint circuits, use `Groth16Pipeline`, which orders compile, witness and
  MSM work to keep the peak low;
- give the JVM enough `-Xmx` and run the prover as its own process, not inside a request thread.

See [Proving performance](/guides/proving/performance/).

### "BN254 is disabled by default…"

```text
java.lang.IllegalStateException: BN254 is disabled by default because ZeroJ targets Cardano production flows and Cardano only supports BLS12-381 on-chain. …
```

You called a legacy BN254 class, such as the curve-less `ZkeyImporter`, `Groth16Prover` or
`PtauImporter`, often because the artifacts were BN254 (snarkjs's and circom's default curve). Use
the BLS12-381 classes (`ZkeyImporterBLS381`, `Groth16ProverBLS381`, `Groth16Keys`, …) with
BLS12-381 artifacts and `CurveId.BLS12_381`. Set `-Dzeroj.allowLegacyBn254=true` only for old
off-chain experiments.

### snarkjs and ZeroJ disagree about a proof

Check, in order:

1. **Curve.** Every artifact must be BLS12-381 (`"curve": "bls12381"` in the JSON). BN254 files
   won't cross over.
2. **Same key.** Verify against the exact `verification_key.json` from the same setup or ceremony as
   the proving key.
3. **Public-input order.** `public.json` must list wires `1..numPublic` in circuit order.
4. **Use the exporter.** `SnarkjsGroth16Json.verificationKeyJson/proofJson/publicJson` write exactly
   what snarkjs 0.7.6 writes, including the `vk_alphabeta_12` pairing value. Don't hand-build the
   JSON.
5. **Unused public signals.** snarkjs quietly binds unused public signals during its setup, while
   ZeroJ's native setup refuses them (see above). Keys imported from a snarkjs ceremony are
   unaffected.

ZeroJ's interop tests pin snarkjs 0.7.6. See [Bring circom & snarkjs circuits](/tutorials/snarkjs-interop/).

### On-chain: execution budget exceeded

- Measure first: run the validator in the JuLC VM, and use `ScriptBudgetEstimator` for rough
  numbers (it counts only the BLS12-381 builtins, so real validators cost more). The generic
  one-input Groth16 verifier measured about 2.63 billion CPU steps.
- Each public input costs an extra scalar multiplication on-chain. Keep the count low.
- Keep other heavy logic out of the same script execution, and compare with the network's
  *current* protocol parameters.
- Reference scripts (CIP-0033) cut transaction size and fees, not execution units.

If the transaction builder's cost evaluation fails with errors mentioning `supranational.blst` or an
`ExceptionInInitializerError`, the evaluator couldn't load the native blst library on that machine.
This is an evaluator environment problem, not a proof problem; ZeroJ's own Yaci DevKit tests skip
in that situation.

### My script hash changed after upgrading JuLC

Expected. The script bytes, and so the hash and address, come from the JuLC compiler. A compiler
upgrade can change them even when your Java source didn't change. Treat it as a new script:
re-measure budgets, publish the new hash, and plan how funds at the old address move. Renaming
Java packages alone does not change the hash. See [Verify proofs on Cardano](/guides/verifying/on-chain/#julc-version-coupling).

### The verifier registry picks the blst verifier

`VerifierRegistry.withServiceLoader()` discovers the blst-backed `Groth16BLS12381Verifier` before
the pure-Java one, and `find` returns the first match. Build the registry explicitly with
`VerifierRegistry.empty()` and `register(new Groth16BLS12381PureJavaVerifier())` when you want a
specific backend.

## Platform

### Does ZeroJ work with GraalVM native image?

The pure-Java path is designed to be GraalVM-compatible, and modules that need it ship
native-image metadata under `META-INF/native-image/org.zeroj/<module>/`. Build and test your own
image, and keep these in mind:

- register verifier backends explicitly rather than relying on `ServiceLoader` discovery;
- the blst FFM path needs `--enable-native-access=ALL-UNNAMED` and a bundled `libblst` for your
  platform;
- the `zeroj-ceremony` CLI is published as native binaries. Its `contribute` and `finalize`
  commands are native-friendly, while `export-r1cs` loads circuit classes reflectively and is
  usually run on a JVM.

### Can I use Maven or Kotlin?

Yes. ZeroJ is a set of ordinary Maven Central artifacts under `org.zeroj`. Import
`zeroj-bom-core` in `<dependencyManagement>` for Maven; any JVM language can call the APIs. See
[Installation](/start/installation/).

## Security

### Are my secrets safe in the JVM?

ZeroJ doesn't claim constant-time behaviour for witness generation or the pure-Java prover (they use
`BigInteger`). Prove on hardware you control. For BBS issuer keys, use the blst provider. Keep
witnesses and `.wtns` files short-lived and out of logs. See
[Secure your ZK application](/guides/verifying/application-security/#secrets-in-java).

### How do I report a security issue?

The repository has no `SECURITY.md` or published private disclosure address yet. Please don't post
exploit details in a public issue. Check the **Security** tab of
[bloxbean/zeroj](https://github.com/bloxbean/zeroj) for private vulnerability reporting. If it isn't
available, open a short issue asking the maintainers for a private contact, without technical
details.

## Next steps

- [Status & maturity](/start/status/)
- [Configuration](/reference/configuration/)
- [Secure your ZK application](/guides/verifying/application-security/)

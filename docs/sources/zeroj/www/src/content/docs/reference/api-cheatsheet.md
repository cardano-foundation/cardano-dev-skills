---
title: API cheat sheet
description: One page of the ZeroJ calls you use most, grouped by task, each with the class's package, from circuit definition to on-chain verification and BBS.
sidebar:
  order: 2
---

The calls you reach for most, grouped by task. Every class lives under `org.zeroj` unless the
package says otherwise. For explanations, follow the links in each section.

## Define a circuit

See [Annotations](/guides/circuits/annotations/) and [Circuit DSL](/guides/circuits/circuit-dsl/).

| Call | Class (package) |
|---|---|
| `@ZKCircuit(name = "secret-multiplier", version = 1)` on a class | `ZKCircuit` (`org.zeroj.circuit.annotation`) |
| `@Prove ZkBool prove(ZkContext zk, @Public ZkField a, @Public ZkField product, @Secret ZkField b)` | `Prove`, `Public`, `Secret`, `ZkBool`, `ZkField`, `ZkContext` (`org.zeroj.circuit.annotation`) |
| `a.mul(b).isEqual(product)` · `a.add(b)` | `ZkField` (`org.zeroj.circuit.annotation`) |
| `SecretMultiplierCircuit.build()` (generated companion) | returns `CircuitBuilder` (`org.zeroj.circuit`) |
| `CircuitBuilder.create("mul").publicVar("c").secretVar("a").secretVar("b").define(api -> api.assertEqual(api.mul(api.var("a"), api.var("b")), api.var("c")))` | `CircuitBuilder` (`org.zeroj.circuit`) |
| `CircuitBuilder.create(name).publicVar(...).secretVar(...).defineSignals(new MySpec())`, with `MySpec implements CircuitSpec { void define(SignalBuilder c) }` | `CircuitSpec`, `SignalBuilder`, `Signal` (`org.zeroj.circuit`) |
| `ZkPoseidon.hash(zk, PoseidonParamsBLS12_381T3.INSTANCE, x, y)` | `ZkPoseidon` (`org.zeroj.circuit.lib.zk`), `PoseidonParamsBLS12_381T3` (`org.zeroj.circuit.lib.poseidon`) |
| `SignalPoseidon.hash(c, PoseidonParamsBLS12_381T3.INSTANCE, x, y)` | `SignalPoseidon` (`org.zeroj.circuit.lib`) |
| `PoseidonHash.hash(PoseidonParamsBLS12_381T3.INSTANCE, a, b)` (off-circuit, same hash) | `PoseidonHash` (`org.zeroj.circuit.lib.poseidon`) |

For Cardano circuits, always pass the BLS12-381 Poseidon parameters explicitly. The overloads
without parameters and MiMC are oriented to legacy BN254 use.

## Compile and compute the witness

| Call | Class (package) |
|---|---|
| `var r1cs = circuit.compileR1CS(CurveId.BLS12_381)` | `CircuitBuilder` (`org.zeroj.circuit`), `CurveId` (`org.zeroj.api`) |
| `r1cs.constraints()` · `r1cs.flat()` · `r1cs.numWires()` · `r1cs.numPublicInputs()` · `r1cs.numConstraints()` | `R1CSConstraintSystem` (`org.zeroj.circuit.r1cs`) |
| `BigInteger[] w = circuit.calculateWitness(Map.of("a", List.of(BigInteger.valueOf(3)), …), CurveId.BLS12_381)` | `CircuitBuilder` (`org.zeroj.circuit`) |
| `SecretMultiplierCircuit.inputs().a(3).product(33).b(11)` then `.toWitnessMap()` or `.calculateWitness(circuit, CurveId.BLS12_381)` | generated `…Circuit.Inputs` |
| `new ZkInputMap().put("root", value).toWitnessMap()` | `ZkInputMap` (`org.zeroj.circuit.annotation`) |
| Public inputs: `Arrays.copyOfRange(w, 1, 1 + r1cs.numPublicInputs())` (`w[0]` is always 1) | — |

An unsatisfied constraint throws `ArithmeticException("Constraint violation: …")`; a missing input
throws `IllegalArgumentException("Missing public input: …")` or `("Missing secret input: …")`.

## Trusted setup

:::caution[Dev/test only]
The single-party calls below know the toxic waste and can forge proofs. They need
`-Dzeroj.allowInsecureTrustedSetup=true`. Production keys come from an MPC ceremony. See
[Trusted setup ceremony](/guides/proving/trusted-setup-ceremony/).
:::

| Call | Class (package) |
|---|---|
| `BigInteger tau = PowersOfTauBLS381.generate(power).tauScalar()` (dev) | `PowersOfTauBLS381` (`org.zeroj.crypto.setup`) |
| `try (var keys = Groth16Keys.setupInMemory(r1cs.constraints(), r1cs.numWires(), r1cs.numPublicInputs(), tau)) { … }` (dev, small circuits) | `Groth16Keys` (`org.zeroj.crypto.groth16`) |
| `Groth16Keys.setupToStore(r1cs.flat(), numWires, numPublic, tau, keysDir, true)` (dev, large circuits, mmap'd store) | `Groth16Keys` (`org.zeroj.crypto.groth16`) |
| `var imported = ZkeyPkStoreImporter.importToPkStore(zkeyPath, keysDir, verifiedZkeySha256)` (production: import a ceremony `.zkey` once, pinned to its hash; the two-argument form always throws) | `ZkeyPkStoreImporter` (`org.zeroj.crypto.groth16`) |
| `try (var keys = Groth16Keys.load(keysDir, imported.manifestSha256())) { … }` (imported store, pinned) · `Groth16Keys.load(keysDir)` (your own `setupToStore` store) | `Groth16Keys` (`org.zeroj.crypto.groth16`) |
| `var zkey = ZkeyImporterBLS381.importZkeyFull(zkeyBytes)` · `ZkeyImporterBLS381.importWtns(inputStream)` | `ZkeyImporterBLS381` (`org.zeroj.crypto.groth16`) |
| `TrustedSetupPolicy.insecureTrustedSetupEnabled()` | `TrustedSetupPolicy` (`org.zeroj.api`) |

## Prove (Groth16)

| Call | Class (package) |
|---|---|
| `Groth16ProofBLS381 proof = keys.prove(witness, r1cs.constraints())` | `Groth16Keys`, `Groth16ProofBLS381` (`org.zeroj.crypto.groth16`) |
| `keys.prove(BlstProverBackend.create(), witness, r1cs.constraints())` (opt-in native MSM) | `BlstProverBackend` (`org.zeroj.cryptoblst`, module `zeroj-crypto-blst`) |
| `Groth16ProverBLS381.prove(zkey.provingKey(), witness, zkey.constraints(), zkey.numWires())` | `Groth16ProverBLS381` (`org.zeroj.crypto.groth16`) |
| Very large circuits: `Groth16Pipeline.setup(...)` / `Groth16Pipeline.prove(...)` | `Groth16Pipeline` (`org.zeroj.crypto.groth16`), see [Performance](/guides/proving/performance/) |

Every proof is blinded with fresh randomness; there is no public deterministic prove API.

## Export snarkjs JSON

| Call | Class (package) |
|---|---|
| `SnarkjsGroth16Json.verificationKeyJson(keys)` | `SnarkjsGroth16Json` (`org.zeroj.crypto.snarkjs`) |
| `SnarkjsGroth16Json.proofJson(proof)` | `SnarkjsGroth16Json` (`org.zeroj.crypto.snarkjs`) |
| `SnarkjsGroth16Json.publicJson(publicInputs)` (a `BigInteger[]`) | `SnarkjsGroth16Json` (`org.zeroj.crypto.snarkjs`) |

Output is byte-identical to what snarkjs 0.7.6 writes, so `snarkjs groth16 verify` accepts it.

## Verify off-chain

See [Verify proofs in Java](/guides/verifying/off-chain/).

| Call | Class (package) |
|---|---|
| `SnarkjsJsonCodec.toEnvelopeFromJson(proofJson, vkJson, publicJson, new CircuitId("mul"))` | `SnarkjsJsonCodec` (`org.zeroj.codec`), `CircuitId` (`org.zeroj.api`) |
| `VerificationMaterial.of(vkJson.getBytes(UTF_8), ProofSystemId.GROTH16, CurveId.BLS12_381, circuitId)` | `VerificationMaterial`, `ProofSystemId` (`org.zeroj.api`) |
| `new Groth16BLS12381PureJavaVerifier().verify(envelope, material).proofValid()` | `Groth16BLS12381PureJavaVerifier` (`org.zeroj.verifier.groth16.bls12381`) |
| `VerifierRegistry.empty()` + `register(verifier)` · `VerifierRegistry.withServiceLoader()` | `VerifierRegistry` (`org.zeroj.verifier.core`) |
| `new InMemoryVerificationKeyRegistry()` + `register(material)` | `InMemoryVerificationKeyRegistry` (`org.zeroj.backend.spi`) |
| `new VerifierOrchestrator(backends, keys).verify(envelope)` | `VerifierOrchestrator` (`org.zeroj.verifier.core`) |
| `VerificationResult.ok()` · `policyRejected(ReasonCode.USED_NULLIFIER, msg)` | `VerificationResult` (`org.zeroj.api`) |
| `CborEnvelopeCodec.encode(envelope)` · `decode(bytes)` · `CanonicalHash.sha256(vkBytes)` | `CborEnvelopeCodec`, `CanonicalHash` (`org.zeroj.codec`) |

A backend's success result has `proofValid() == true` and `accepted() == false`; acceptance is your
policy's decision.

## Compress for Cardano

| Call | Class (package) |
|---|---|
| `ProverToCardano.compressVk(keys)` → `VkCompressed(alpha, beta, gamma, delta, ic)` | `ProverToCardano` (`org.zeroj.onchain.julc.groth16.codec`) |
| `ProverToCardano.compressProof(proof)` → `ProofCompressed(piA, piB, piC)` | `ProverToCardano` (`org.zeroj.onchain.julc.groth16.codec`) |
| `SnarkjsToCardano.parseVk(vkJson)` · `parseProof(proofJson)` · `parsePublicInputs(publicJson)` | `SnarkjsToCardano` (`org.zeroj.onchain.julc.groth16.codec`) |

## Load and use the on-chain verifier

See [Verify proofs on Cardano](/guides/verifying/on-chain/). A valid proof is not authorization:
bind the proof to the transaction in your own validator.

| Call | Class (package) |
|---|---|
| `JulcScriptLoader.load(Groth16BLS12381Verifier.class, new BytesPlutusData(vk.alpha()), …, icList)` | `JulcScriptLoader` (`org.julclang.clientlib`, artifact `julc-cardano-client-lib`); `Groth16BLS12381Verifier` (`org.zeroj.onchain.julc.groth16.validator`) |
| `AddressProvider.getEntAddress(script, Networks.testnet()).toBech32()` | Cardano Client Lib (`com.bloxbean.cardano.client.address`) |
| Datum: `ListPlutusData.of(BigIntPlutusData.of(pub0), …)` · Redeemer: `Constr 0 [piA, piB, piC]` | Cardano Client Lib (`com.bloxbean.cardano.client.plutus.spec`) |
| In your validator: `Groth16BLS12381Lib.verify(datum, piA, piB, piC, vkAlpha, vkBeta, vkGamma, vkDelta, vkIc)` | `Groth16BLS12381Lib` (`org.zeroj.onchain.julc.groth16.lib`) |
| Spend-binding reference example (reads the bound value from the datum, so it can't lock real funds as-is): `Groth16BLS12381TxOutRefBindingVerifier` | `org.zeroj.onchain.julc.groth16.validator` |
| `ScriptBudgetEstimator.estimateCpu(ProofSystemId.GROTH16, CurveId.BLS12_381, n)` · `OnChainFeasibility.lookup(...)` | `org.zeroj.onchain.julc.analysis` |

## BBS credentials

`zeroj-bbs` is opt-in: declare it with an explicit version. See [Selective disclosure with BBS](/guides/credentials/bbs/).

| Call | Class (package) |
|---|---|
| `BbsService bbs = BbsService.pureJava()` | `BbsService` (`org.zeroj.bbs`) |
| `BbsService.withBlsProvider(BbsCiphersuite.BLS12381_SHA256, BlstBls12381Provider.createDefault())` (issuers) | `BbsCiphersuite` (`org.zeroj.bbs`), `BlstBls12381Provider` (`org.zeroj.blst`) |
| `BbsKeyPair kp = bbs.keyPair(keyMaterial32Bytes, keyInfo)` | `BbsKeyPair` (`org.zeroj.bbs`) |
| `BbsSignature sig = bbs.sign(kp.secretKey(), kp.publicKey(), messages, header)` | `BbsSignature` (`org.zeroj.bbs`) |
| `bbs.verify(kp.publicKey(), sig, messages, header)` | `BbsService` (`org.zeroj.bbs`) |
| `BbsPresentation p = bbs.derivePresentation(pk, sig, messages, header, presentationHeader, new int[]{2, 3})` | `BbsPresentation` (`org.zeroj.bbs`) |
| `bbs.verifyPresentation(pk, p)`, then compare `p.presentationHeader()` / `p.header()` with what you expect | `BbsService` (`org.zeroj.bbs`) |
| `BbsPresentationCodec.encode(p)` · `decode(bytes)` | `BbsPresentationCodec` (`org.zeroj.bbs`) |
| `new BbsPublicKey(bytes, BbsCiphersuite.BLS12381_SHA256)` · `pk.bytes()` | `BbsPublicKey` (`org.zeroj.bbs`) |
| `BbsToCardano.verifierParams(pk, header, messageCount)` · `BbsToCardano.onChainProof(p)` | `BbsToCardano` (`org.zeroj.bbs.cardano`) |

## PlonK (experimental)

:::caution[Experimental]
PlonK proving and verification are experimental, opt-in paths. Groth16 is the focus of the current
release. See [PlonK](/guides/proving/plonk/) before using them.
:::

| Class | Package |
|---|---|
| `PlonKSetupBLS381`, `PlonKProverBLS381`, `PtauImporterBLS381` | `org.zeroj.crypto.plonk` |
| `PlonkBLS12381Verifier` (module `zeroj-verifier-plonk`) | `org.zeroj.verifier.plonk` |
| `PlonkBLS12381Verifier`, `PlonkBLS12381MultiInputVerifier`, `PlonkBLS12381MultiInputParamVerifier` (on-chain) | `org.zeroj.onchain.julc.plonk.validator` |

## Next steps

- [Modules](/reference/modules/)
- [Configuration](/reference/configuration/)
- [Quickstart](/start/quickstart/)

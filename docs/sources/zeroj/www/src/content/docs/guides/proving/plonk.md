---
title: Prove with PlonK
description: What ZeroJ's experimental PlonK support contains today, how to try it off-chain, and its known gaps. Groth16 is the supported path.
sidebar:
  order: 4
---

:::caution[Experimental, with no correctness claims]
ZeroJ's PlonK support is **experimental everywhere**: pure-Java proving, off-chain verification,
`.zkey` import, and the on-chain validators. ZeroJ makes no claim that it is correct, sound, or
ready for use. **Groth16 on BLS12-381 is the supported path for the current release**; use
[Prove with Groth16](/guides/proving/groth16/) for anything you build on. Use PlonK only to
evaluate or experiment, and never where value is at stake.
:::

PlonK uses a *universal* setup: one powers-of-tau reference string (SRS) serves every circuit up
to its size, instead of a ceremony per circuit. ZeroJ has a pure-Java implementation over
BLS12-381. This page describes what exists and how to try it, briefly and without recommending it.

## What exists

| Piece | API | Module |
|-------|-----|--------|
| Compile a circuit | `circuit.compilePlonK(CurveId.BLS12_381)` → `PlonKConstraintSystem` | `zeroj-circuit-dsl` |
| Development SRS | `PowersOfTauBLS381.generate(power)` (needs the insecure-setup flag) | `zeroj-crypto` |
| Import a `.ptau` SRS | `PtauImporterBLS381.importPtau(input, maxPoints, expectedSha256)` | `zeroj-crypto` |
| Setup | `PlonKSetupBLS381.setup(...)` → `PlonKProvingKeyBLS381` | `zeroj-crypto` |
| Prove | `PlonKProverBLS381.prove(...)`; `proveCardano(...)` and `proveCardanoMpi(...)` for the on-chain profiles | `zeroj-crypto` |
| Import a snarkjs PlonK `.zkey` | `PlonKZkeyImporterBLS381.importZkey(input, expectedSha256)` | `zeroj-crypto` |
| Export snarkjs JSON | `SnarkjsPlonkJson.proofJson`, `verificationKeyJson`, `publicJson` | `zeroj-crypto` |
| Verify off-chain | `PlonkBLS12381Verifier` | `zeroj-verifier-plonk` |
| Verify on-chain | `PlonkBLS12381Verifier`, `PlonkBLS12381MultiInputVerifier`, `PlonkBLS12381MultiInputParamVerifier` (JuLC validators) | `zeroj-onchain-julc` |

`zeroj-verifier-plonk` is deliberately **outside** `zeroj-bom-core`, so declare its version
explicitly:

```groovy
implementation 'org.zeroj:zeroj-verifier-plonk:%ZEROJ_VERSION%'
```

BN254 PlonK exists only as a legacy path and is disabled unless you start the JVM with
`-Dzeroj.allowLegacyBn254=true`. It isn't a Cardano curve.

## Known gaps

- **Blinding.** The PlonK prover uses 9 blinding scalars, while the PlonK paper and snarkjs use 11
  (the quotient-split blinding factors are missing). This is tracked as an open issue affecting
  the zero-knowledge margin.
- **snarkjs PlonK keys.** `PlonKZkeyImporterBLS381` reads the header, selectors, permutations and
  SRS, but not the wire-map sections, so ZeroJ can't prove a snarkjs-arithmetized circuit under an
  imported PlonK `.zkey`.
- **No large-circuit work.** The memory and speed work that makes Groth16 practical at millions of
  constraints hasn't been applied to PlonK.
- **Not audited,** and on-chain use is limited to bounded profiles (below).

## Try it off-chain

The flow has more steps than Groth16 because you assign the three PlonK wire columns yourself.
This mirrors the shape used in ZeroJ's own interop tests:

```java
var circuit = CircuitBuilder.create("multiplier")
        .publicVar("c").secretVar("a").secretVar("b")
        .define(api -> api.assertEqual(api.mul(api.var("a"), api.var("b")), api.var("c")));
BigInteger[] witness = circuit.calculateWitness(Map.of(
        "c", List.of(BigInteger.valueOf(33)),
        "a", List.of(BigInteger.valueOf(3)),
        "b", List.of(BigInteger.valueOf(11))), CurveId.BLS12_381);

PlonKConstraintSystem plonk = circuit.compilePlonK(CurveId.BLS12_381);

// DEV/TEST ONLY: single-party SRS, needs -Dzeroj.allowInsecureTrustedSetup=true
var srs = PowersOfTauBLS381.generate(8);

int numGates = plonk.numGates();
BigInteger[][] selectors = new BigInteger[numGates][];
for (int i = 0; i < numGates; i++) {
    var row = plonk.gateRows().get(i);
    selectors[i] = new BigInteger[]{row.qL(), row.qR(), row.qO(), row.qM(), row.qC()};
}
PlonKProvingKeyBLS381 pk = PlonKSetupBLS381.setup(numGates, plonk.numPublicInputs(), selectors,
        plonk.sigmaA(), plonk.sigmaB(), plonk.sigmaC(), plonk.numWires(), srs);

BigInteger[] ext = plonk.extendWitness(witness);
int n = pk.domainSize();
MontFr381[] wireA = new MontFr381[n], wireB = new MontFr381[n], wireC = new MontFr381[n];
for (int i = 0; i < n; i++) {
    if (i < numGates) {
        var row = plonk.gateRows().get(i);
        wireA[i] = MontFr381.fromBigInteger(ext[row.wireA()]);
        wireB[i] = MontFr381.fromBigInteger(ext[row.wireB()]);
        wireC[i] = MontFr381.fromBigInteger(ext[row.wireC()]);
    } else {
        wireA[i] = wireB[i] = wireC[i] = MontFr381.ZERO;
    }
}
BigInteger[] publicInputs = Arrays.copyOfRange(witness, 1, 1 + plonk.numPublicInputs());

PlonKProofBLS381 proof = PlonKProverBLS381.prove(pk, wireA, wireB, wireC, publicInputs);
```

Every prove call draws fresh blinding scalars from `SecureRandom`; an overload accepts your own
`SecureRandom` instance. For an SRS from a public ceremony instead of the development generator,
import a BLS12-381 `.ptau` with `PtauImporterBLS381.importPtau(...)`, pinning its SHA-256.

Verify through the snarkjs JSON form:

```java
String vkJson = SnarkjsPlonkJson.verificationKeyJson(pk);
String proofJson = SnarkjsPlonkJson.proofJson(proof);
String publicJson = SnarkjsPlonkJson.publicJson(publicInputs);

var id = new CircuitId("multiplier");
byte[] vkBytes = vkJson.getBytes(StandardCharsets.UTF_8);
var material = VerificationMaterial.of(vkBytes, ProofSystemId.PLONK, CurveId.BLS12_381, id,
        CanonicalHash.sha256(vkBytes));   // optional pin: the verifier checks the VK hash matches
var envelope = SnarkjsPlonkCodec.toEnvelopeFromJson(proofJson, vkJson, publicJson, id);

boolean ok = new PlonkBLS12381Verifier().verify(envelope, material).proofValid();
```

The verifier accepts structured snarkjs/ZeroJ PlonK JSON. It doesn't accept gnark's binary PlonK
proof format.

## Independent test vectors

ZeroJ checks its PlonK transcript against artifacts it didn't produce:

- BLS12-381 PlonK vectors generated by **gnark v0.14.0**, an independent implementation, in
  `zeroj-test-vectors` (`test-vectors/plonk-bls12381/`). `GnarkTranscriptCompatTest` checks
  ZeroJ's Fiat-Shamir transcript against them. The pinned generator lives in
  `assurance/gnark-fixtures` so the vectors stay reproducible.
- A structured snarkjs PlonK vector (`test-vectors/snarkjs-plonk-bls12381/`) pins the JSON
  exporters byte for byte, and the interop suite checks proofs and keys in both directions against
  a pinned snarkjs CLI.

Passing these vectors is evidence of compatibility on the tested cases. It is not a correctness
or soundness guarantee.

## On-chain status

The JuLC validators perform the KZG pairing check with Plutus V3's BLS12-381 built-ins, for two
bounded profiles:

| Validator | Profile | Prove with |
|-----------|---------|------------|
| `PlonkBLS12381Verifier` | Exactly one public input | `PlonKProverBLS381.proveCardano(...)` |
| `PlonkBLS12381MultiInputVerifier` | 1 to 8 public inputs, supplied in the datum | `PlonKProverBLS381.proveCardanoMpi(...)` |
| `PlonkBLS12381MultiInputParamVerifier` | 1 to 8 public inputs, pinned at script-application time | `PlonKProverBLS381.proveCardanoMpi(...)` |

The Cardano profiles hash compressed curve points into the transcript, so proofs from the plain
`prove(...)` won't verify on-chain. These validators are experimental and suitable at most for
labeled, non-value-bearing testnet trials. As with Groth16, a valid proof is not authorization:
a real validator must bind `ScriptContext`, prevent replay, and enforce its own rules. See
[Verify on-chain](/guides/verifying/on-chain/).

Further reading: [plonk-support.md](https://github.com/bloxbean/zeroj/blob/main/docs/plonk-support.md),
[ADR-0024 (PlonK release gates and multi-public-input profile)](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0024-plonk-release-gates-and-multi-public-input-profile.md).

## Next steps

- [Prove with Groth16](/guides/proving/groth16/), the supported path
- [Groth16, PlonK & BBS](/learn/proof-systems/)
- [Status & maturity](/start/status/)

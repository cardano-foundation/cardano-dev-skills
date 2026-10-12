---
title: Verify proofs in Java
description: Verify Groth16 proofs off-chain with ZeroJ's proof model, verifier backends and registries, and build a service that only trusts keys you pinned.
sidebar:
  order: 1
---

Verification is the cheap half of zero-knowledge: a prover may spend seconds or minutes building a
proof, but checking it takes milliseconds and needs no secrets. ZeroJ's off-chain verifiers are
plain Java objects. You hand them a proof, its public inputs, and a verification key (VK), and they
tell you whether the math holds.

This page covers the proof model, the verifier backends, the registries that route proofs to them,
what the verifiers check at the trust boundary, and how to wrap all of it in a service that
only accepts proofs for circuits and keys you have pinned.

:::note[Math, not permission]
A valid proof says *"someone knows a witness that satisfies this circuit for these public
inputs."* It does not say the caller is allowed to do anything. Replay protection, nullifiers and
business rules are yours to add. See [Secure your ZK application](/guides/verifying/application-security/).
:::

## Add the dependencies

The Groth16 verifiers live in `zeroj-verifier-groth16`, which puts `zeroj-backend-spi` (the SPI
and registries) and `zeroj-api` (the proof model) on your compile classpath. Add `zeroj-codec`
yourself for the snarkjs JSON parser, CBOR and hashing helpers.

```groovy title="build.gradle"
dependencies {
    implementation platform('org.zeroj:zeroj-bom-core:%ZEROJ_VERSION%')
    implementation 'org.zeroj:zeroj-verifier-groth16'
    implementation 'org.zeroj:zeroj-codec'   // SnarkjsJsonCodec, CborEnvelopeCodec, CanonicalHash
}
```

## The proof model

Everything in `org.zeroj.api` is immutable, fails fast on missing or blank values, and copies byte
arrays on the way in and out.

| Type | What it holds |
|---|---|
| `ZkProofEnvelope` | Proof bytes plus everything needed to check them: `proofSystem()`, `curve()`, `circuitId()`, `publicInputs()`, `vkRef()`, and optional `proofFormat()`, `metadata()`, `domainTag()`. Built with `ZkProofEnvelope.builder()`. |
| `PublicInputs` | An ordered `List<BigInteger>` of field elements (`new PublicInputs(values)`, `size()`, `get(i)`). Order must match the circuit's public inputs. |
| `VerificationKeyRef` | A sealed interface: `ByHash(byte[] sha256)` (exactly 32 bytes) or `ById(String id)`. |
| `VerificationMaterial` | The VK bytes plus `ProofSystemId`, `CurveId`, `CircuitId` and an optional pre-computed `vkHash`. Create with `VerificationMaterial.of(...)`. |
| `CircuitId` | A non-blank string naming the circuit, e.g. `new CircuitId("age-check")`. |
| `ProofSystemId` | `GROTH16`, `PLONK`, `FFLONK`, `HALO2`, `BBS`. Shipped verifiers cover `GROTH16`, `BBS` and (experimentally) `PLONK`; the others are identifiers only. |
| `CurveId` | `BLS12_381` (Cardano's pairing curve), `PALLAS`, and legacy `BN254`. |

For Groth16, the proof bytes and VK bytes are **snarkjs JSON** (`proof.json` and
`verification_key.json`). That is the format ZeroJ's exporter writes and snarkjs reads, so the
same three files work in both tools. See [Bring circom & snarkjs circuits](/tutorials/snarkjs-interop/).

## Verify a Groth16 proof

`SnarkjsJsonCodec.toEnvelopeFromJson` parses the three snarkjs files, checks that they agree with
each other (same protocol and curve, public-input count equal to the VK's `nPublic`), and returns an
envelope whose `vkRef` is `ByHash(SHA-256 of the exact VK JSON bytes)`.

```java title="VerifyOnce.java"
import org.zeroj.api.CircuitId;
import org.zeroj.api.CurveId;
import org.zeroj.api.ProofSystemId;
import org.zeroj.api.VerificationMaterial;
import org.zeroj.api.VerificationResult;
import org.zeroj.api.ZkProofEnvelope;
import org.zeroj.codec.SnarkjsJsonCodec;
import org.zeroj.verifier.groth16.bls12381.Groth16BLS12381PureJavaVerifier;

import java.nio.charset.StandardCharsets;

CircuitId circuitId = new CircuitId("multiplier");

// proofJson and publicJson come from the prover; vkJson comes from YOUR trusted storage.
ZkProofEnvelope envelope = SnarkjsJsonCodec.toEnvelopeFromJson(proofJson, vkJson, publicJson, circuitId);
VerificationMaterial material = VerificationMaterial.of(
        vkJson.getBytes(StandardCharsets.UTF_8), ProofSystemId.GROTH16, CurveId.BLS12_381, circuitId);

VerificationResult result = new Groth16BLS12381PureJavaVerifier().verify(envelope, material);
if (result.proofValid()) {
    // the pairing check passed — now apply your own policy
}
```

`toEnvelopeFromJson` throws `CodecException` (a `RuntimeException`) for malformed or inconsistent
JSON, so catch it when the input comes from outside your process.

:::caution[The VK is never the prover's to choose]
Load the verification key from storage you control. If you verify against a VK the prover sent
you, they can send a key for a different, trivial circuit.
:::

## Read the result

`VerificationResult` is a record that keeps *cryptographic* validity separate from *policy*
validity.

| Accessor | Meaning |
|---|---|
| `proofValid()` | The cryptographic check passed. **This is the field a verifier backend sets.** |
| `protocolValid()` | `Optional<Boolean>`: your policy checks passed (empty when none ran). |
| `accepted()` | `true` only when both the proof and the policy are valid. |
| `reasonCode()` | `Optional<ReasonCode>` explaining a rejection. |
| `message()` | `Optional<String>` human-readable detail. |

On success a backend returns `VerificationResult.cryptoValid()`, so `proofValid()` is `true` but
`accepted()` is **`false`**: no policy has been evaluated yet. Your service decides acceptance, for
example by returning `VerificationResult.ok()` after its own checks pass, or
`VerificationResult.policyRejected(ReasonCode.USED_NULLIFIER, "...")` when they fail.

The `ReasonCode` enum covers both sides:

| Code | Typically set by |
|---|---|
| `INVALID_PROOF` | A backend: the pairing check failed, or a point was malformed |
| `INVALID_PUBLIC_INPUTS` | A backend: wrong count, or a value outside `[0, r)` |
| `INTERNAL_ERROR` | A backend: an unexpected exception, e.g. unparseable proof bytes |
| `UNKNOWN_VERIFICATION_KEY` | The orchestrator: the envelope's `vkRef` isn't registered |
| `UNSUPPORTED_PROOF_SYSTEM` | The orchestrator (no backend registered) or a backend given the wrong proof system |
| `VK_MISMATCH`, `UNSUPPORTED_CURVE`, `MALFORMED_ENVELOPE` | Consistency checks in the PlonK and BBS backends, and in your own gate |
| `UNKNOWN_CIRCUIT`, `RETIRED_CIRCUIT`, `STALE_STATE_ROOT`, `DUPLICATE_NONCE`, `UNAUTHORIZED_SUBMITTER`, `USED_NULLIFIER` | Your policy layer |

## Choose a backend

| Backend class | Module | Descriptor name | Notes |
|---|---|---|---|
| `Groth16BLS12381PureJavaVerifier` | `zeroj-verifier-groth16` | `groth16-bls12381-java` | Pure Java, no native code. The portable default. |
| `Groth16BLS12381Verifier` | `zeroj-verifier-groth16` | `groth16-bls12381-blst` | Same checks, pairing via the native blst library (the `blst-java` JNI binding that `zeroj-blst` brings in). |
| `PlonkBLS12381Verifier` | `zeroj-verifier-plonk` (opt-in) | — | **Experimental.** See [PlonK](/guides/proving/plonk/). |
| `BbsZkVerifier` | `zeroj-bbs` (opt-in) | `bbs-bls12381-java` | Verifies BBS presentations wrapped in an envelope. See [BBS](/guides/credentials/bbs/). |

:::caution[Two classes named `Groth16BLS12381Verifier`]
`org.zeroj.verifier.groth16.bls12381.Groth16BLS12381Verifier` is the **off-chain** blst-backed
verifier on this page. `org.zeroj.onchain.julc.groth16.validator.Groth16BLS12381Verifier` is the
**on-chain** Plutus validator. Check your imports.
:::

:::caution[PlonK is experimental]
The PlonK verifier is an experimental, opt-in path. Groth16 on BLS12-381 is the supported focus of
the current release; don't treat PlonK verification as production evidence.
:::

The legacy BN254 verifiers are not registered with `ServiceLoader` and refuse to run unless you
start the JVM with `-Dzeroj.allowLegacyBn254=true`. BN254 is not a Cardano curve; ignore it
unless you are running old off-chain experiments.

## Route proofs with registries

When a service handles more than one circuit or proof system, let the orchestrator pick the key and
the backend.

- **`VerifierRegistry`** (`org.zeroj.verifier.core`) holds backends. `VerifierRegistry.empty()`
  plus `register(...)` gives you an explicit list; `VerifierRegistry.withServiceLoader()` discovers
  every `ZkVerifier` on the classpath.
- **`VerificationKeyRegistry`** (`org.zeroj.backend.spi`) resolves a `VerificationKeyRef` to
  `VerificationMaterial`. `InMemoryVerificationKeyRegistry` stores each registered key under its
  SHA-256 (computed from the VK bytes if you didn't supply one) **and** under its circuit ID.
- **`VerifierOrchestrator`** resolves the envelope's `vkRef`, finds a backend for its proof system
  and curve, and delegates.

```java
import org.zeroj.backend.spi.InMemoryVerificationKeyRegistry;
import org.zeroj.backend.spi.VerificationKeyRegistry;
import org.zeroj.verifier.core.VerifierOrchestrator;
import org.zeroj.verifier.core.VerifierRegistry;

VerificationKeyRegistry keys = new InMemoryVerificationKeyRegistry();
keys.register(VerificationMaterial.of(
        vkJson.getBytes(StandardCharsets.UTF_8), ProofSystemId.GROTH16, CurveId.BLS12_381, circuitId));

VerifierRegistry backends = VerifierRegistry.empty();
backends.register(new Groth16BLS12381PureJavaVerifier());

var orchestrator = new VerifierOrchestrator(backends, keys);
VerificationResult result = orchestrator.verify(envelope);   // UNKNOWN_VERIFICATION_KEY if not registered
```

`VerifierRegistry.find` returns the *first* backend that supports a proof-system/curve pair. With
`withServiceLoader()`, `zeroj-verifier-groth16` lists the blst-backed verifier before the pure-Java
one, so discovery picks blst. Register backends explicitly when you need to know which one runs,
and when you build a GraalVM native image.

The orchestrator resolves whatever `vkRef` the envelope carries. Every key in the registry is
therefore reachable by any caller, including through `ById` lookups by circuit ID. Treat the
registry as an allowlist and put only keys you intend to accept in it, or use the pinned-gate
pattern below.

## What the verifiers enforce

The Groth16 backends fail closed on malformed input before any pairing work:

- **Bounded, strict JSON.** The snarkjs codec caps documents at 8 MiB, rejects duplicate keys,
  and accepts only canonical decimal strings (no sign, no leading zeros).
- **Public inputs.** The count must equal the VK's `nPublic`, and every value must be a canonical
  scalar in `[0, r)`. A value like `x + r` is rejected with `INVALID_PUBLIC_INPUTS`, never
  silently reduced.
- **Points.** Every proof and VK point, including every `IC` entry, must have coordinates in
  `[0, p)`, lie on the curve, be in the prime-order subgroup, and **not be the point at infinity**.
  An infinity `IC` entry would leave a public input unbound, so ZeroJ's setup refuses to create
  one and every verifier rejects it.

What the Groth16 backends do **not** check: that `envelope.circuitId()` or `envelope.vkRef()`
matches the `VerificationMaterial` you passed. They verify the proof against whatever key you give
them. (The experimental PlonK verifier does compare them and returns `VK_MISMATCH`.) Do that
comparison yourself, as the next section shows.

## Build a verification service

A verification endpoint should trust nothing in the envelope except the proof and public inputs.
Pin each circuit's VK by hash in configuration, look it up by the circuit *your endpoint expects*,
and compare the envelope against it before verifying.

```java title="ProofGate.java"
import org.zeroj.api.CircuitId;
import org.zeroj.api.CurveId;
import org.zeroj.api.ProofSystemId;
import org.zeroj.api.VerificationKeyRef;
import org.zeroj.api.VerificationMaterial;
import org.zeroj.api.VerificationResult;
import org.zeroj.api.VerificationResult.ReasonCode;
import org.zeroj.api.ZkProofEnvelope;
import org.zeroj.codec.CanonicalHash;
import org.zeroj.verifier.groth16.bls12381.Groth16BLS12381PureJavaVerifier;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Map;

/** Verifies only proofs for circuits and verification keys this service has pinned. */
public final class ProofGate {

    private final Groth16BLS12381PureJavaVerifier verifier = new Groth16BLS12381PureJavaVerifier();
    private final Map<String, VerificationMaterial> pinned;   // "age-check@1" -> material

    public ProofGate(Map<String, VerificationMaterial> pinned) {
        this.pinned = Map.copyOf(pinned);
    }

    /** Load a VK you control and refuse it unless it matches the SHA-256 pinned in config. */
    public static VerificationMaterial pin(Path vkJson, CircuitId circuitId, String expectedSha256Hex)
            throws Exception {
        byte[] vkBytes = Files.readAllBytes(vkJson);
        byte[] actual = CanonicalHash.sha256(vkBytes);
        if (!Arrays.equals(actual, HexFormat.of().parseHex(expectedSha256Hex))) {
            throw new IllegalStateException("verification key does not match pinned hash: " + vkJson);
        }
        return VerificationMaterial.of(vkBytes, ProofSystemId.GROTH16, CurveId.BLS12_381, circuitId, actual);
    }

    /** {@code expected} comes from your endpoint or business flow, never from the envelope. */
    public VerificationResult verify(String expected, ZkProofEnvelope envelope) {
        VerificationMaterial material = pinned.get(expected);
        if (material == null) {
            return VerificationResult.error(ReasonCode.UNKNOWN_CIRCUIT, "circuit not allowlisted: " + expected);
        }
        if (envelope.proofSystem() != material.proofSystemId()
                || envelope.curve() != material.curveId()
                || !envelope.circuitId().equals(material.circuitId())) {
            return VerificationResult.error(ReasonCode.VK_MISMATCH, "envelope does not match " + expected);
        }
        if (!(envelope.vkRef() instanceof VerificationKeyRef.ByHash ref)
                || !Arrays.equals(ref.hash(), material.vkHash().orElseThrow())) {
            return VerificationResult.error(ReasonCode.VK_MISMATCH, "unexpected verification key");
        }
        return verifier.verify(envelope, material);   // cryptographic check only
    }
}
```

Then layer policy on top. Here the circuit exposes a nullifier as its second public input:

```java
VerificationResult crypto = gate.verify("age-check@1", envelope);
if (!crypto.proofValid()) {
    return crypto;
}
BigInteger nullifier = envelope.publicInputs().get(1);   // your circuit's nullifier position
if (!usedNullifiers.add(nullifier)) {                      // durable, atomic store in production
    return VerificationResult.policyRejected(ReasonCode.USED_NULLIFIER, "nullifier already used");
}
return VerificationResult.ok();
```

A few rules that keep this honest:

- **Version your allowlist keys.** `@ZKCircuit(name = "age-check", version = 2)` produces the same
  `CircuitId` (`"age-check"`) as version 1; the version travels separately in envelope metadata.
  Key your pinned map by name *and* version, and give each version its own VK hash.
- **The VK hash is byte-exact.** `toEnvelopeFromJson` hashes the raw VK JSON. Re-formatting the
  file (whitespace, key order) changes the hash, so pin the exact bytes you ship.
- **Retire keys deliberately.** When a circuit changes, remove the old entry (or answer
  `RETIRED_CIRCUIT`) instead of leaving every historical key live.

## Move envelopes between services

`zeroj-codec` gives you two helpers for transport and content addressing:

```java
import org.zeroj.codec.CanonicalHash;
import org.zeroj.codec.CborEnvelopeCodec;

byte[] cbor = CborEnvelopeCodec.encode(envelope);          // integer-keyed CBOR map
ZkProofEnvelope decoded = CborEnvelopeCodec.decode(cbor);  // bounded, typed CodecException on bad input
byte[] id = CanonicalHash.hash(envelope);                  // SHA-256 over the core fields
```

The CBOR encoding carries the core fields only: version, proof system, curve, circuit ID, proof
bytes, public inputs, and the VK reference. Optional fields such as `metadata()` (where annotated
circuits put their version) and `proofFormat()` are **not** carried, and `CanonicalHash` ignores
them too. If your policy depends on them, send them another way, or rely on the pinned VK hash,
which already distinguishes circuit versions.

## Write a custom backend

A backend implements `ZkVerifier` from `zeroj-backend-spi`: a `descriptor()` naming the proof
system and curve it handles, and a `verify(envelope, material)` that returns a crypto-only result.

```java
import org.zeroj.api.CurveId;
import org.zeroj.api.ProofSystemId;
import org.zeroj.api.VerificationMaterial;
import org.zeroj.api.VerificationResult;
import org.zeroj.api.ZkProofEnvelope;
import org.zeroj.backend.spi.BackendDescriptor;
import org.zeroj.backend.spi.ZkVerifier;

public final class MyVerifier implements ZkVerifier {
    @Override
    public BackendDescriptor descriptor() {
        return new BackendDescriptor(ProofSystemId.GROTH16, CurveId.BLS12_381, "my-verifier");
    }

    @Override
    public VerificationResult verify(ZkProofEnvelope envelope, VerificationMaterial material) {
        try {
            // 1. parse and validate every input: encodings, ranges, curve/subgroup, infinity
            // 2. run the verification equation
            return checkProof(envelope, material)
                    ? VerificationResult.cryptoValid()
                    : VerificationResult.proofInvalid("verification equation failed");
        } catch (IllegalArgumentException e) {
            return VerificationResult.proofInvalid("malformed proof or key: " + e.getMessage());
        }
    }

    private boolean checkProof(ZkProofEnvelope envelope, VerificationMaterial material) {
        throw new UnsupportedOperationException("your verification logic");   // fail closed until written
    }
}
```

To make it discoverable, list its fully qualified name in
`META-INF/services/org.zeroj.backend.spi.ZkVerifier`. Match the built-in backends' validation:
canonical encodings, range checks, curve and subgroup membership, and the infinity rules above. A
backend with weaker checks silently weakens every service that discovers it.

## Next steps

- [Verify proofs on Cardano](/guides/verifying/on-chain/)
- [Secure your ZK application](/guides/verifying/application-security/)
- [Bring circom & snarkjs circuits](/tutorials/snarkjs-interop/)
- [API cheat sheet](/reference/api-cheatsheet/)

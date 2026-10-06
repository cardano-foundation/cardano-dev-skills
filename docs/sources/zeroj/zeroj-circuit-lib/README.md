# zeroj-circuit-lib

Reusable ZK circuit components for the ZeroJ circuit DSL.

This module contains standard gadgets and helper APIs that sit on top of
`zeroj-circuit-dsl`. Use it when building application circuits that need hashes,
Merkle membership, range/comparison checks, binary decomposition, multiplexing,
or Jubjub-style primitives.

## What It Provides

| Area | Key Types |
|------|-----------|
| Hashes | `Poseidon`, `PoseidonN`, optimized `FastPoseidonBls12381T3`, `MiMC`, `MiMCSponge`, `Blake2b`, `Sha512`, `HmacSha512` |
| Cardano key derivation | `Cip1852Derivation`, `Bip32Ed25519`, `Ed25519Point`, `Fe25519` — in-circuit root key → payment key hash |
| Merkle proofs | `Merkle`, `SignalMerkle` |
| Comparisons | `Comparators`, `SignalComparators` |
| Binary gadgets | `Binary`, `SignalBinary`, `AliasCheck` |
| Selection | `Mux` |
| Signal helpers | `SignalPoseidon`, `SignalMiMC` |
| Annotation helpers | `ZkPoseidon`, `ZkPoseidonN`, `ZkMiMC`, `ZkMerkle`, `ZkJubjubPoint`, `ZkPedersen`, `ZkEdDSAJubjub`, `ZkBlake2b`, `ZkSha512`, `ZkHmacSha512`, `ZkCip1852` |
| Jubjub primitives | `JubjubCurve`, `PedersenCommitment`, `EdDSAJubjub`, in-circuit variants |
| Poseidon parameters | `PoseidonParams*`, `PoseidonHash`, Grain LFSR generation helpers |

## Gadget Status

This table is intentionally conservative. "Cardano-ready" means the gadget can
be used in a circuit compiled over `CurveId.BLS12_381`, proved with Groth16, and
verified with ZeroJ's reusable Plutus V3 BLS12-381 verifier. The gadget logic
itself runs off-chain inside the circuit/prover flow; Cardano only sees the
final proof, verification key data, and public inputs.

| Gadget | DSL APIs | Symbolic APIs | Field / curve status | Cardano status | Notes |
|--------|----------|---------------|----------------------|----------------|-------|
| Field arithmetic | `Signal`, `SignalBuilder`, `CircuitAPI` | `ZkField` | Generic over supported circuit fields | Ready on BLS12-381 Groth16 | Core DSL feature, not a separate gadget. |
| Boolean values | DSL equality and constraints | `ZkBool` | Generic | Ready on BLS12-381 Groth16 | `ZkBool` constrains values to 0/1 and prevents Java `boolean` control-flow mistakes. |
| Unsigned integers | `Comparators`, `SignalComparators`, `Binary`, `SignalBinary` | `ZkUInt` | Generic, `ZkUInt.MAX_BITS = 253`; comparisons require width `< 253` | Ready on BLS12-381 Groth16 | `ZkUInt` adds range constraints on construction. |
| Fixed arrays and matrices | Java arrays passed to gadgets | `ZkArray<T>`, including rectangular `ZkArray<ZkArray<T>>` | Generic | Ready on BLS12-381 Groth16 | Deeper nesting is intentionally out of scope until a real circuit needs it. |
| Bit and byte vectors | `Binary`, `SignalBinary` | `ZkBits`, `ZkBytes` | Generic | Ready for binding/equality on BLS12-381 Groth16 | Symbolic bitwise operations are still limited; use `SignalBinary` or add wrappers when needed. |
| Binary decomposition | `Binary`, `SignalBinary`, `AliasCheck` | Partly via `ZkUInt`, `ZkBits`, `ZkBool` | Generic | Ready on BLS12-381 Groth16 | `AliasCheck` remains a lower-level helper for canonical field representation checks. |
| Comparators and ranges | `Comparators`, `SignalComparators` | Mostly through `ZkUInt` | Generic | Ready on BLS12-381 Groth16 | Optional symbolic `min`/`max` helpers can be added later if needed. |
| Selection / mux | `Mux` | `ZkBool.select(...)` | Generic for scalar values | Ready on BLS12-381 Groth16 | Dynamic array access remains a lower-level `Mux.arrayAccess(...)` pattern. `ZkJubjubPoint.select(...)` inherits the Jubjub-row status below, not this one. |
| MiMC | `MiMC`, `SignalMiMC` | `ZkMiMC` | BN254 only | Not Cardano-ready | `MiMC` and `SignalMiMC` call `requireField(FieldConfig.BN254)`. Use Poseidon for Cardano circuits. |
| MiMC sponge | `MiMCSponge` | No direct `ZkMiMCSponge` | BN254 only, because it uses MiMC | Not Cardano-ready | Useful for BN254/off-chain legacy circuits only. |
| Poseidon T3 | `Poseidon`, `SignalPoseidon` | `ZkPoseidon` | BN254 default; BLS12-381 with explicit params | Ready when using `PoseidonParamsBLS12_381T3.INSTANCE` | No-params overloads are BN254 for backward compatibility. |
| Folded Poseidon N | `PoseidonN` | `ZkPoseidonN` | BN254 default in DSL overloads; symbolic API requires explicit params | Ready when using `PoseidonParamsBLS12_381T3.INSTANCE` | Folded two-input Poseidon, not a separate variable-width Poseidon permutation. |
| Merkle membership | `Merkle`, `SignalMerkle` | `ZkMerkle` | Hash-dependent | Ready with params-aware BLS12-381 Poseidon helpers | Use `ZkMerkle.*Poseidon(..., PoseidonParamsBLS12_381T3.INSTANCE, ...)` for Cardano. `HashType.MIMC` and default `HashType.POSEIDON` are BN254-oriented convenience paths. |
| Poseidon MPF/JMT authenticated state | Operation APIs live in `zeroj-mpf-poseidon` and `zeroj-jmt-poseidon` | Named `ZkMpf*` / `ZkJmt*` operation classes in those modules | BLS12-381 Poseidon profile only | Experimental; pure-Java Groth16 and Julc paths locally benchmarked at 5M entries | Kept outside the generic circuit library to preserve host/profile boundaries. Inclusion, two non-inclusion forms, update, and split insert primitives are implemented; see ADR-0042. Not compatible with native Aiken/Blake2b roots. |
| Jubjub point arithmetic | `InCircuitJubjub`, `JubjubPoint` | `ZkJubjubPoint` | BLS12-381 scalar field only | Ready for algebraic/public-data use on BLS12-381 Groth16, pending external review (ADR-0037/0038) | Generic off-circuit secret-scalar use remains offline/isolated because `BigInteger` arithmetic is variable-time. Bind every prover-supplied in-circuit point with `witnessAffine(...)` (curve equation, `Z = 1`, `T = u·v`; 5 constraints) or `assertWellFormed(...)` for projective input (13 constraints, idempotent). The raw `Point` constructor is unchecked and documented as gadget-internal. Neither binder establishes subgroup membership. `ZkJubjubPoint.fromTrustedAffine` is deprecated and delegates to `witnessAffine`. |
| Pedersen commitment (in-circuit) | `InCircuitPedersen` | `ZkPedersen` | BLS12-381 scalar field only | Ready on BLS12-381 Groth16, pending external review | Profile spec: [`pedersen-jubjub-v1`](../docs/specs/pedersen-jubjub-v1.md). The blinding is always 252 bits and may not be a public input or constant (ADR-0051 D2); only the value has a caller-chosen width. 3,020 constraints for two 252-bit vectors in the gadget alone; the complete `ZkPedersen` commitment with public `(u, v)` costs 2,410 (64-bit value) / 4,042 (252-bit value). `InCircuitPedersen` proves the represented residues but does not establish integer `< l`; `ZkPedersen` adds that canonicality check. |
| Pedersen homomorphic API | `InCircuitJubjub.negate`/`subtract`/`assertInPrimeOrderSubgroup` | `ZkPedersenCommitment`, `ZkPedersen.assertBalanced`, `ZkJubjubPoint.negate`/`subtract`/`assertInPrimeOrderSubgroup` | BLS12-381 scalar field only | Experimental, pending review and external review | The public subgroup assertion validates the point (curve, `T·Z = U·V`, `Z ≠ 0`) before `[l]·P = O`. Unopened external commitments enter only through `witnessInSubgroup` or `fromVerifierCheckedPublic`. Commitment sums hold mod `l`; `assertBalanced` refuses layouts that could wrap (ADR-0051 D3a). `PedersenCommitment.decode` adds the subgroup check to canonical decoding. |
| Pedersen vector commitment | `InCircuitPedersenVector`, `PedersenVectorBases`, `PedersenVectorSchema`, `PedersenVectorCommitment`, `PedersenSchemaRegistry` | `ZkPedersenVector`, `ZkPedersenVectorCommitment` | BLS12-381 scalar field only | Experimental, pending spec and external review | Spec: [`pedersen-jubjub-vector-v1`](../docs/specs/pedersen-jubjub-vector-v1.md). Up to 16 values; bases from Zcash `FindGroupHash("ZeroJ_PV", …)`. The point binds neither length nor schema, so proofs bind a public schema digest and verifiers check it against a registry; received commitments need an authenticated issuance record (fail closed). |
| Pedersen commitment (off-circuit generation) | `PedersenCommitment.commit`; internal fixed-limb review candidate | — | Jubjub over BLS12-381 | Legacy is **offline/isolated only**; fixed-limb path is an unapproved ADR-0039 M9 candidate | The candidate is package-private, uses mutable explicit-width openings and fixed-limb schedules, and has separate timing/external/platform gates. Hiding and binding of the commitment itself are unaffected. |
| EdDSA-Jubjub | `InCircuitEdDSAJubjub`, `EdDSAJubjub`, `JubjubSigner` | `ZkEdDSAJubjub` | BLS12-381 scalar field only | Verification ready pending external review; legacy signing offline-only; fixed-limb hedged profile remains an unapproved candidate | Two in-circuit entry points are named for their key-trust model. `JubjubSigners.validatedDedicatedHostJavaRequired` deliberately fails closed until ADR-0039 M4–M8 pass. Specs: [`jubjub-eddsa-v1`](../docs/specs/jubjub-eddsa-v1.md), [hedged candidate](../docs/specs/jubjub-eddsa-hedged-v1-candidate.md). |
| Poseidon parameters and off-circuit hashing | `PoseidonParams*`, `PoseidonHash`, `PoseidonGrainLFSR`, `PoseidonParameterFingerprint` | Used by `ZkPoseidon*`, `ZkMerkle`, and the separate MPF/JMT modules | BN254 T3, BLS12-381 T3, BLS12-381 T5 presets exist | Ready when matched to the circuit field and gadget shape | `PoseidonHash` is host-side hashing for expected roots/test vectors, not a circuit constraint by itself. `FastPoseidonBls12381T3` is the equivalence-tested optimized **host-side** path used for off-circuit roots and witnesses; circuit constraints still use the Poseidon gadget. |

**Real-world crypto (Cardano key derivation).** These gadgets reproduce standard wallet/key
primitives *inside* the circuit, so a proof can attest to Cardano key ownership without revealing the
seed. They compose into `Cip1852Derivation` (root key → address payment key hash).

| Gadget | DSL APIs | Symbolic APIs | Field / curve status | Cardano status | Notes |
|--------|----------|---------------|----------------------|----------------|-------|
| BLAKE2b | `Blake2b` | `ZkBlake2b` | Field-agnostic (bit-oriented) | Ready on BLS12-381 Groth16 | RFC 7693. `ZkBlake2b.hash224` is the Cardano address key-hash function (blake2b-224); 256 also available. |
| SHA-512 | `Sha512` | `ZkSha512` | Field-agnostic (bit-oriented) | Ready as a building block | FIPS 180-4. Used inside HMAC and BIP32 key derivation. |
| HMAC-SHA512 | `HmacSha512` | `ZkHmacSha512` | Field-agnostic | Ready as a building block | RFC 2104, built on `Sha512`. Used by BIP32-Ed25519 derivation. |
| Ed25519 base field | `Fe25519` | — | Emulated GF(2²⁵⁵−19) | Building block | Non-native field arithmetic (5×51-bit limbs) underpinning Ed25519. |
| Ed25519 point ops | `Ed25519Point`, `Ed25519Host` | — | Ed25519 curve | Building block | Fixed-base scalar multiplication in-circuit; `Ed25519Host` provides constants and a correctness oracle. |
| BIP32-Ed25519 derivation | `Bip32Ed25519` | — | Ed25519 | Ready as a building block | Child-key derivation (HMAC-SHA512 + scalar mult), Cardano/Icarus style. |
| CIP-1852 → payment key hash | `Cip1852Derivation` | `ZkCip1852` | Ed25519 + BLAKE2b | Ready on BLS12-381 Groth16 | Full `m/1852'/1815'/account'/role/index` derivation, root key → 28-byte pkh. A complete path is a large circuit (on the order of ~19M constraints). Basis of the account-ownership proof; see ADR-0027. |

For the broader Cardano/annotation matrix, see
[`docs/adr/circuit-annotation/cardano-gadget-support-matrix.md`](../docs/adr/circuit-annotation/cardano-gadget-support-matrix.md).

## Why It Is Useful

- Avoids reimplementing common ZK gadgets in every application circuit.
- Keeps hash and Merkle circuits consistent across examples and production code.
- Provides field-aware Poseidon parameters for BN254 and BLS12-381 use cases.
- Lets higher-level privacy patterns build on reviewed, reusable components.

## Usage Shape

ZeroJ supports three circuit authoring styles. Prefer them in this order unless
you have a specific reason to drop lower in the stack.

### 1. Symbolic Annotations

Use this for new application circuits. The annotation processor generates the
`CircuitBuilder`, schema, metadata, and input helpers, while the body stays
close to ordinary Java domain code.

```java
@ZKCircuit(name = "sealed-bid", version = 1)
public class SealedBid {
    @Prove
    ZkBool prove(
            ZkContext zk,
            @Public ZkField bidCommitment,
            @Public @UInt(bits = 64) ZkUInt reservePrice,
            @Secret @UInt(bits = 64) ZkUInt bidAmount,
            @Secret ZkField salt) {
        var commitmentMatches = ZkPoseidon.hash(
                        zk,
                        PoseidonParamsBLS12_381T3.INSTANCE,
                        bidAmount.asField(),
                        salt)
                .isEqual(bidCommitment);

        return commitmentMatches.and(bidAmount.gte(reservePrice));
    }
}

var circuit = SealedBidCircuit.build();
```

### 2. CircuitSpec

Use `CircuitSpec` when you want an explicit reusable circuit class without the
annotation processor, or when working close to the `SignalBuilder` API is useful.

```java
public class SealedBidCircuit implements CircuitSpec {
    @Override
    public void define(SignalBuilder c) {
        Signal bidAmount = c.privateInput("bidAmount");
        Signal salt = c.privateInput("salt");
        Signal bidCommitment = c.publicOutput("bidCommitment");
        Signal reservePrice = c.publicInput("reservePrice");

        c.assertEqual(
                SignalPoseidon.hash(c, PoseidonParamsBLS12_381T3.INSTANCE, bidAmount, salt),
                bidCommitment);
        c.assertEqual(
                SignalComparators.greaterOrEqual(c, bidAmount, reservePrice, 64),
                c.constant(1));
    }

    public static CircuitBuilder build() {
        return CircuitBuilder.create("sealed-bid")
                .publicVar("bidCommitment")
                .publicVar("reservePrice")
                .secretVar("bidAmount")
                .secretVar("salt")
                .defineSignals(new SealedBidCircuit());
    }
}
```

### 3. Inline Circuit DSL

Use inline `CircuitBuilder` definitions for small tests, examples, and quick
experiments.

```java
var circuit = CircuitBuilder.create("sealed-bid")
        .publicVar("bidCommitment")
        .publicVar("reservePrice")
        .secretVar("bidAmount")
        .secretVar("salt")
        .defineSignals(c -> {
            var bidAmount = c.privateInput("bidAmount");
            var salt = c.privateInput("salt");
            var bidCommitment = c.publicOutput("bidCommitment");
            var reservePrice = c.publicInput("reservePrice");

            c.assertEqual(
                    SignalPoseidon.hash(c, PoseidonParamsBLS12_381T3.INSTANCE, bidAmount, salt),
                    bidCommitment);
            c.assertEqual(
                    SignalComparators.greaterOrEqual(c, bidAmount, reservePrice, 64),
                    c.constant(1));
        });
```

All three styles use the same underlying circuit library gadgets. Symbolic
annotation-based circuits use adapters from
`org.zeroj.circuit.lib.zk`; `CircuitSpec` and inline DSL code
usually use the `Signal*` helpers directly. Cardano/BLS12-381 examples should
also use `PoseidonParamsBLS12_381T3` from
`org.zeroj.circuit.lib.poseidon`.

Common symbolic adapter calls:

```java
var hash = ZkPoseidon.hash(
        zk,
        PoseidonParamsBLS12_381T3.INSTANCE,
        left,
        right);
var commitment = ZkPoseidonN.hash(
        zk,
        PoseidonParamsBLS12_381T3.INSTANCE,
        owner,
        assetId,
        nonce);
var root = ZkMerkle.computeRootPoseidon(
        zk,
        PoseidonParamsBLS12_381T3.INSTANCE,
        leaf,
        siblings,
        pathBits);
var pedersen = ZkPedersen.commit(zk, value, blinding); // blinding: 252-bit secret ZkUInt
```

These adapters delegate to the existing `Signal*` and in-circuit gadgets and
validate that their inputs belong to the supplied `ZkContext`.

Curve and parameter guidance:

- **MiMC** — `ZkMiMC` is guarded as BN254-only. Use Poseidon when targeting BLS12-381.
- **Poseidon** — `ZkPoseidonN` requires explicit Poseidon params and is the
  symbolic path for folded multi-input commitments. The no-params Poseidon
  helpers are BN254-oriented for backward compatibility.
- **Merkle** — `ZkMerkle.HashType.MIMC` and the no-params `HashType.POSEIDON`
  paths are BN254/off-chain conveniences. For Cardano Merkle circuits, use
  `ZkMerkle.computeRootPoseidon`, `isMemberPoseidon`, or `verifyPoseidon` with
  explicit BLS12-381 Poseidon params.
- **Jubjub / Pedersen / EdDSA-Jubjub** — hardened by
  [ADR-0037](../docs/adr/0037-jubjub-soundness-and-hardening.md); the normative scheme is
  [`docs/specs/jubjub-eddsa-v1.md`](../docs/specs/jubjub-eddsa-v1.md).

  Every prover-supplied point must be bound with `InCircuitJubjub.witnessAffine(...)`, which
  asserts the curve equation and pins `Z = 1`, `T = u·v`; a genuinely projective input must
  pass `InCircuitJubjub.assertWellFormed(...)`. The low-level arithmetic API takes an unchecked
  raw `Point`, so this is an explicit caller precondition there—a witness value is not
  constrained by anything the caller checks off-circuit. The named EdDSA verifier entry
  points are stronger: they accept affine wires and enforce binding at their own boundary.

  Verification comes in two named entry points, because whether `pk` needs an in-circuit
  subgroup check depends on the protocol, not the gadget. `verifyStrict(...)` proves
  `[l]·pk == O` in-circuit — use it whenever `pk` is prover-supplied.
  `verifyWithRegisteredKey(...)` requires `pk` to be a public input or constant, enforced by
  the DSL against circuit-owned wire ids, and leaves registry binding to the final verifier.
  Both reject small-order keys via `[8]·pk != O`. There is no unqualified `verify`.

  `ZkJubjubPoint` carries the same guarantee via `witnessAffine(...)`; its `assertWellFormed()`
  emits the projective invariants once. Before
  [ADR-0038](../docs/adr/0038-jubjub-dsl-remediation-plan.md) P2 it emitted nothing at all and
  accepted an off-curve `(1, 1)`.

  Still open before validated secret-bearing production use: external cryptographic review
  and the ADR-0039 platform/deployment gates below.

- **Off-circuit Pedersen commitment generation is offline-only.**
  `PedersenCommitment.commit(value, blinding)` uses a fresh 64-bit multiple-of-`l` scalar
  blinding and a fixed 316-iteration add/double schedule for both legs. This removes the old
  bit-length/zero-early-return channel and randomises the raw trailing-zero/identity-duration
  signal, but Java branches, `BigInteger`, the reductions and the JVM remain variable-time.
  The commitment's binding and perfect hiding are unaffected, as are the in-circuit Pedersen
  gadgets — the restriction is on secret-bearing execution only. Verification uses the faster
  public-scalar path because the opening is disclosed to that verifier.

  ADR-0039 also contains an internal fixed-limb Pedersen candidate. It accepts explicit
  unsigned widths, stores both inputs modulo `l`, uses fixed 252-iteration schedules, and
  never converts a secret opening to `BigInteger`. Its classes remain package-private until
  independent timing, platform, external-review, and public-API gates pass.

- **Legacy signing is not constant-time.** `EdDSAJubjub.sign` performs secret-dependent scalar
  multiplication over variable-time `BigInteger` and feeds `sk` through Poseidon's
  variable-time field arithmetic. It is **not approved for value-bearing issuance on shared
  or network-reachable infrastructure**; approved uses are local/offline signing and test
  issuance. It verifies its generated signature before returning, which catches inconsistent
  candidate faults but cannot detect a coherent attacker-selected nonce used in both `R` and
  `S`. Signing fails closed before point multiplication if its deterministic nonce is zero;
  releasing such a signature would disclose the secret key.

  ADR-0039 adds a separate fixed-limb implementation and typed `JubjubMessage` boundary.
  `JubjubSigners.fixedLimbDeterministicV1Compatibility(...)` preserves legacy signature bytes
  for offline testing. The hedged profile is implemented only as an internal review candidate:
  it derives every nonce twice into disjoint scratch, checks equality/nonzero, and independently
  verifies the public candidate before release. `validatedDedicatedHostJavaRequired()` takes
  no untagged caller key and throws until external design/implementation review, an approved
  key-provisioning boundary, and an exact JVM/CPU/CSPRNG deployment profile pass M4–M8; it
  never falls back to a weaker signer.

  `JubjubMessage.toPublicFieldElement()` is the explicit public-data bridge for circuit
  inputs. Typed message overloads can make an untyped Java `null` literal ambiguous; existing
  statically typed `BigInteger` calls and bytecode remain compatible.

  For intentional legacy/offline typed signing, use
  `signCompatibilityOffline(Keypair, JubjubMessage)` or the explicitly profiled
  `JubjubSigners.compatibilityOffline(...)` wrapper. The generic typed
  `sign(Keypair, JubjubMessage)` name is deprecated because it is too easy to mistake for
  hardened signing. `Keypair` is now a validating final class rather than a record:
  its public `(sk, pk)` constructor rejects an out-of-range secret or mismatched public key
  and recomputes the relation, so the factory methods are cheaper when constructing a key.
  The `sk()` / `pk()` accessors, value equality, and the former two-component record hash are
  preserved. Code using record reflection, record-component metadata, record patterns, or
  assignment to `java.lang.Record` must migrate and recompile.

  Multiple-of-`l` scalar blinding assumes a prime-order subgroup base. Package boundaries keep
  the helper internal; development and test runs can additionally enable
  `-Dzeroj.jubjub.debugSecretSubgroupChecks=true` for an expensive fail-closed precondition
  check. This is misuse detection, not a constant-time guarantee.

- **Comparators** — `CircuitAPI.lessThan(a, b, n)` range-constrains **both** variable
  operands to `n` bits, and rejects a constant operand that does not fit at
  circuit-definition time. Before ADR-0037 it constrained neither and was forgeable in both
  directions.

  The `lessThan(BitDecomposition, BitDecomposition)` overload skips those range constraints on
  the strength of the typed evidence, so it validates that evidence first: every consumer of a
  `BitDecomposition` calls `CircuitAPI.requireOwned(...)` before reading a single bit, and a
  decomposition minted in another circuit is rejected at circuit-definition time. Wire ids
  restart per circuit, so without that check a foreign decomposition would pass as evidence
  about unrelated same-id wires ([ADR-0038](../docs/adr/0038-jubjub-dsl-remediation-plan.md)
  P1). `ZkUInt.decomposition()` exposes an owned decomposition for reuse.

- **Cardano key derivation** — `ZkBlake2b`, `ZkSha512`, `ZkHmacSha512`, and
  `ZkCip1852` are bit-oriented and field-agnostic (they don't depend on the
  circuit's scalar field), so they run on BLS12-381 Groth16. `ZkCip1852`
  composes them (with in-circuit Ed25519 / BIP32 key derivation) into a full
  root-key → payment-key-hash derivation — the primitive behind proving Cardano
  address ownership. See ADR-0027.

The Cardano-oriented support matrix is maintained in
[`docs/adr/circuit-annotation/cardano-gadget-support-matrix.md`](../docs/adr/circuit-annotation/cardano-gadget-support-matrix.md).

The status table above was checked against the current implementation in
`src/main/java`, especially `MiMC`, `Poseidon`, `PoseidonN`, `ZkMerkle`,
`ZkPedersen`, `ZkEdDSAJubjub`, the `hash/`, `field/`, and `ed25519/`
crypto gadgets (`Blake2b`, `Sha512`, `HmacSha512`, `Ed25519Point`,
`Bip32Ed25519`, `Cip1852Derivation`), and the adapter coverage in
`src/test/java/org/zeroj/circuit/lib/zk/ZkGadgetAdaptersTest.java`.
The MPF/JMT rows are checked in their owning structure modules; they are not circuit-lib
packages.

## Gradle

```gradle
dependencies {
    implementation 'org.zeroj:zeroj-circuit-lib'
}
```

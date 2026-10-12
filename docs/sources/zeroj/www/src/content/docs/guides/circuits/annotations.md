---
title: Write circuits with annotations
description: Author ZeroJ circuits as annotated Java classes, and use the generated companion to build, fill inputs, compute witnesses, and wire proofs.
sidebar:
  order: 1
---

Annotations are the recommended way to write ZeroJ circuits. You write an ordinary Java class,
mark its inputs `@Public` or `@Secret`, and put the rules in one `@Prove` method. At compile
time, the annotation processor generates a companion class (`MyCircuit` gives you
`MyCircuitCircuit`) that builds a normal ZeroJ circuit, describes its inputs, and fills witnesses
for you.

Nothing about proving changes. The companion's `build()` returns the same `CircuitBuilder` that
the lower-level DSL produces, so everything in [Prove with Groth16](/guides/proving/groth16/)
applies unchanged.

## Set up the processor

You need `zeroj-circuit-annotation-api` on the compile classpath,
`zeroj-circuit-annotation-processor` on the annotation processor path, and usually
`zeroj-circuit-lib` for gadgets such as Poseidon:

```groovy title="build.gradle"
dependencies {
    implementation platform('org.zeroj:zeroj-bom-core:%ZEROJ_VERSION%')
    annotationProcessor platform('org.zeroj:zeroj-bom-core:%ZEROJ_VERSION%')

    implementation 'org.zeroj:zeroj-circuit-annotation-api'
    annotationProcessor 'org.zeroj:zeroj-circuit-annotation-processor'
    implementation 'org.zeroj:zeroj-circuit-lib'
}
```

Maven and Kotlin DSL versions are on [Installation](/start/installation/). If your circuits live
in test sources, use `testAnnotationProcessor` too.

## Anatomy of an annotated circuit

This sealed-bid circuit proves "my hidden bid matches the public commitment, and it is at least
the reserve price" without revealing the bid:

```java title="SealedBid.java"
import org.zeroj.circuit.annotation.Prove;
import org.zeroj.circuit.annotation.Public;
import org.zeroj.circuit.annotation.Secret;
import org.zeroj.circuit.annotation.UInt;
import org.zeroj.circuit.annotation.ZKCircuit;
import org.zeroj.circuit.annotation.ZkBool;
import org.zeroj.circuit.annotation.ZkContext;
import org.zeroj.circuit.annotation.ZkField;
import org.zeroj.circuit.annotation.ZkUInt;
import org.zeroj.circuit.lib.poseidon.PoseidonParamsBLS12_381T3;
import org.zeroj.circuit.lib.zk.ZkPoseidon;

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
```

A few things to notice:

- The method body doesn't compute an answer. It *describes constraints*. `ZkField`, `ZkUInt` and
  `ZkBool` are symbolic values: wires in a circuit, not numbers.
- Returning a `ZkBool` makes the generated code assert that it is true. A witness that makes it
  false can't be proven.
- `ZkContext` is optional. Declare it when you call gadgets that need the circuit context.
- For Cardano, pass `PoseidonParamsBLS12_381T3.INSTANCE` to every Poseidon call. See
  [Gadget library](/guides/circuits/gadgets/).

## Annotations

| Annotation | Where | What it does |
|------------|-------|--------------|
| `@ZKCircuit(name, nameTemplate, version)` | class | Marks the circuit. `name` defaults to the class name, `version` defaults to 1 and must be positive, `nameTemplate` is for parameterized circuits. |
| `@Prove` | method | The single method that defines the constraints. Exactly one per class, not `private`. Returns `ZkBool` or `void`. |
| `@Public(name = "...")` / `@Secret(name = "...")` | field or parameter | Visibility. Exactly one is required on every input. `name` overrides the generated input name. |
| `@UInt(bits = N)` | `ZkUInt` input (or arrays of it) | Declares the width, 1 to 253. Required on every `ZkUInt` input. |
| `@FixedSize(value)` / `@FixedSize(param = "...")` | `ZkArray`, `ZkBits`, `ZkBytes` | Fixed length, as a literal or a `@CircuitParam` name. Add `inner` / `innerParam` for `ZkArray<ZkArray<T>>`. |
| `@CircuitParam("name")` | constructor parameter | A build-time value that changes the circuit's shape (depth, size, mode). |
| `@Order(n)` | field | Overrides declaration order in field style. Values must be unique per visibility. |
| `@FieldElement` | `ZkField` input | Optional marker that documents "raw field element". The processor only checks it sits on a `ZkField`. |

## Symbolic types

| Type | Input constraints added | Key operations |
|------|-------------------------|----------------|
| `ZkField` | none | `add`, `sub`, `mul`, `div`, `isEqual`, `assertEqual` |
| `ZkBool` | value is 0 or 1 | `and`, `or`, `xor`, `not`, `select(a, b)`, `isEqual`, `assertTrue`, `assertFalse`, `asField` |
| `ZkUInt` | value < 2^bits (range check) | `add`, `sub`, `mul`, `lt`, `lte`, `gt`, `gte`, `inRange`, `isEqual`, `assertEqual`, `asField`, `bits` |
| `ZkArray<T>` | per element, by element type | `get(i)`, `size()`, `values()` |
| `ZkBits` | each element boolean | `get(i)`, `size()`, `isEqual`, `assertEqual` |
| `ZkBytes` | each element 8 bits | `get(i)` (a `ZkUInt`), `size()`, `isEqual`, `assertEqual` |

Semantics worth knowing:

- **`ZkField` arithmetic wraps modulo the circuit's field prime** (the BLS12-381 scalar field for
  Cardano). Use `ZkUInt` for anything that behaves like an amount, a count, or an age.
- **`ZkUInt` keeps you honest about widths.** `add` and `mul` widen the result (`add` of two
  64-bit values is 65 bits, `mul` sums the widths), and fail at circuit-build time if the
  result would exceed 253 bits. `sub` range-constrains its result, so a negative difference makes
  the witness unsatisfiable instead of wrapping. Comparisons need widths below 253.
- **`ZkContext`** gives you constants: `zk.constant(18)` or `zk.constant(BigInteger)` return a
  `ZkField`.

## Field style and parameter style

You can declare inputs as fields or as `@Prove` parameters. Pick one per class; mixing them is a
compile error.

```java title="Field style"
@ZKCircuit(name = "range-proof")
public class RangeProof {
    @Secret @UInt(bits = 16) ZkUInt secret;
    @Public @UInt(bits = 16) ZkUInt lo;
    @Public @UInt(bits = 16) ZkUInt hi;

    @Prove
    ZkBool inRange() {
        return secret.gte(lo).and(secret.lte(hi));
    }
}
```

```java title="Parameter style"
@ZKCircuit(name = "age-verification")
public class AgeVerification {
    @Prove
    ZkBool prove(@Secret @UInt(bits = 8) ZkUInt age,
                 @Public @UInt(bits = 8) ZkUInt threshold) {
        return age.gte(threshold);
    }
}
```

Field style is concise. Parameter style keeps every dependency in the method signature and is
required for `static` `@Prove` methods. Symbolic input fields must be neither `private` nor
`final`, and a non-static circuit needs a visible no-argument constructor unless it has a
`@CircuitParam` constructor.

When there is no natural boolean result, declare `void` and assert explicitly:

```java
@Prove
void prove(ZkContext zk,
           @Secret @UInt(bits = 16) ZkUInt value,
           @Secret @UInt(bits = 252) ZkUInt blinding,   // blindings are always full width
           @Public ZkField expectedU,
           @Public ZkField expectedV) {
    ZkPedersen.commit(zk, value, blinding)
            .assertAffineEquals(zk, expectedU, expectedV);
}
```

## Input order and names

The order of public inputs is part of your verification key's contract, so know how it's decided:

1. All public inputs come before all secret inputs.
2. Within each group, inputs keep declaration order. In field style, `@Order` values come first
   (ascending), then unannotated fields in declaration order.
3. Array inputs are flattened with a singular base name: `siblings` becomes `sibling_0`,
   `sibling_1`, and so on. A matrix `measurements` becomes `measurement_0_0`, `measurement_0_1`,
   row-major.

The generated `schema().publicInputs().names()` is the source of truth. Assert it in a test (see
[Test your circuits](/guides/circuits/testing-circuits/)) so a refactor can't silently reorder
your public inputs.

## Parameterized circuits

Constructor parameters annotated `@CircuitParam` make the circuit a template. Supported types are
primitive or boxed integral, boolean and char types, `String`, `BigInteger`, and enums. Integer
parameters can size arrays through `@FixedSize(param = ...)`:

```java
@ZKCircuit(name = "merkle-bls12-381", nameTemplate = "merkle-bls-d{depth}")
public class MerkleMembership {
    public MerkleMembership(@CircuitParam("depth") int depth) {
    }

    @Prove
    ZkBool prove(ZkContext zk,
                 @Secret ZkField leaf,
                 @Public ZkField root,
                 @Secret @FixedSize(param = "depth") ZkArray<ZkField> siblings,
                 @Secret @FixedSize(param = "depth") ZkArray<ZkBool> pathBits) {
        return ZkMerkle.isMemberPoseidon(zk, PoseidonParamsBLS12_381T3.INSTANCE,
                leaf, root, siblings, pathBits);
    }
}
```

Every generated method then takes the parameters:

```java
var circuit = MerkleMembershipCircuit.build(20);
var inputs = MerkleMembershipCircuit.inputs(20);
var schema = MerkleMembershipCircuit.schema(20);
```

The generated circuit name is the rendered template plus a canonical parameter suffix, for
example `merkle-bls-d2--depth-1:2` for depth 2. The suffix prevents two parameter sets from ever
sharing a name.

:::caution[One parameter set, one key]
Each parameter set is a different circuit with a different constraint system. It needs its own
proving key, verification key, and, for real deployments, its own ceremony. Track the circuit
name, `@ZKCircuit(version)`, and parameters together in your key registry.
`metadata().envelopeMetadata()` carries all three.
:::

### Rectangular matrices

Two-dimensional inputs are supported when both dimensions are fixed:

```java
@Secret @UInt(bits = 16)
@FixedSize(param = "rows", innerParam = "cols")
ZkArray<ZkArray<ZkUInt>> measurements
```

The input builder takes a `List<List<BigInteger>>` and rejects ragged rows. Deeper nesting isn't
supported; flatten it to parallel arrays.

## The generated companion

For a class `X`, the processor generates `XCircuit` with these static members. For
parameterized circuits, the methods marked with ✱ take the `@CircuitParam` values as arguments.

| Member | Returns | Use it to |
|--------|---------|-----------|
| `CIRCUIT_NAME`, `CIRCUIT_VERSION`, `CIRCUIT_NAME_TEMPLATE` | constants | Identify the circuit (the template constant exists only with `nameTemplate`) |
| One `String` constant per input, such as `BID_AMOUNT` | constants | Refer to input names without string literals |
| `build(...)` ✱ | `CircuitBuilder` | Compile (`compileR1CS`) and compute witnesses |
| `schema(...)` ✱ | `ZkCircuitSchema` | Inspect names, order, widths, and dimensions |
| `inputs(...)` ✱ | `XCircuit.Inputs` | Fill input values fluently |
| `circuitId(...)` ✱ | `CircuitId` | Label envelopes and key registries |
| `metadata(...)` ✱ | `ZkCircuitMetadata` | Name, version, and parameters for envelopes |
| `calculateWitness(circuit, inputs, curve)` | `BigInteger[]` | Compute the full witness |
| `publicInputs(inputs)` | `List<BigInteger>` | Public values in schema order |
| `publicInputValues(inputs)` | `PublicInputs` | The same, as the envelope type |
| `proofEnvelopeBuilder(circuit, proofSystem, curve, proofBytes, inputs, vkRef)` | `ZkProofEnvelope.Builder` | Wrap proof bytes with the right circuit ID, public inputs, and metadata |

`Inputs` has one setter per input. Scalars accept `BigInteger` or `long`. Arrays accept
`(index, value)` or a whole `List<BigInteger>`, and matrices accept `(row, col, value)` or a
list of rows. It also offers `toWitnessMap()`, `publicValues()`, `toPublicInputs()`,
`calculateWitness(circuit, curve)`, and `schema()`.

Putting it together:

```java
var circuit = SealedBidCircuit.build();

BigInteger bid = BigInteger.valueOf(100);
BigInteger salt = new BigInteger("88001");
BigInteger commitment = PoseidonHash.hash(PoseidonParamsBLS12_381T3.INSTANCE, bid, salt);

var inputs = SealedBidCircuit.inputs()
        .bidCommitment(commitment)
        .reservePrice(75)
        .bidAmount(bid)
        .salt(salt);

var r1cs = circuit.compileR1CS(CurveId.BLS12_381);
BigInteger[] witness = inputs.calculateWitness(circuit, CurveId.BLS12_381); // witness[0] == 1
List<BigInteger> publicValues = inputs.publicValues();                       // [commitment, 75]
```

`PoseidonHash` (in `org.zeroj.circuit.lib.poseidon`) computes the same hash outside the circuit,
which is how you produce public values such as commitments. Use a large random salt in real code.
From here, `r1cs` and `witness` go straight into [Groth16 proving](/guides/proving/groth16/).
After you have a proof, `proofEnvelopeBuilder(...)` checks that the circuit you pass has the name
the inputs were generated for, then builds an envelope with the generated `CircuitId`, the public
inputs in schema order, and the circuit metadata.

## Authoring rules

These rules are what keep an annotated circuit sound:

- **No Java control flow on circuit values.** `ZkBool` is not a Java `boolean`, so `if`, `&&` and
  `||` over secrets don't compile. That's deliberate: a circuit can't branch. Use `and`, `or`,
  `not`, and `select(ifTrue, ifFalse)`, which evaluate both sides and pick one with a constraint.
- **Java loops over shape values are fine.** Loops over `@CircuitParam` sizes or constants just
  unroll into more constraints.
- **A `ZkBool` you compute and then drop constrains nothing.** In a `void` method, call
  `assertTrue()`, `assertEqual(...)`, or an asserting gadget, or return the `ZkBool`.
- **Range-check everything that is really a number.** Use `ZkUInt` with the tightest honest
  `@UInt` width, and never compare raw `ZkField` values as if they were integers.
- **Use explicit BLS12-381 Poseidon parameters.** The no-parameter overloads are BN254 oriented,
  and the circuit refuses to compile for BLS12-381 if the fields don't match.
- **Test with invalid witnesses.** An honest witness that passes proves very little. See
  [Test your circuits for soundness](/guides/circuits/testing-circuits/).

When the symbolic types can't express something, drop to `CircuitSpec` and the `Signal` API. See
[CircuitSpec & the Signal DSL](/guides/circuits/circuit-dsl/).

## Current limits

- Nested (inner) `@ZKCircuit` classes, `private` `@Prove` methods, and `private` or `final` input
  fields aren't supported.
- `static` `@Prove` methods must use parameter style.
- `@CircuitParam` belongs on constructor parameters, not on `@Prove` parameters, and a class can
  have only one `@CircuitParam` constructor.
- `ZkArray` elements must be `ZkField`, `ZkBool`, `ZkUInt`, or one nested `ZkArray` of those.
- `ZkBits` and `ZkBytes` store one constrained field element per bit or byte. Packed encodings
  aren't available yet, and symbolic bitwise operations on `ZkBits` are limited.
- `ZkMiMC` and `ZkMerkle.HashType.MIMC` are BN254-only, so they aren't usable for Cardano circuits.

## Next steps

- [Gadget library](/guides/circuits/gadgets/): Poseidon, Merkle, comparators, Jubjub, and more
- [Test your circuits for soundness](/guides/circuits/testing-circuits/)
- [Prove with Groth16](/guides/proving/groth16/)

---
title: CircuitSpec & the Signal DSL
description: Write circuits directly with CircuitSpec, Signal and the inline CircuitAPI DSL, compile them, compute witnesses, and use hints without breaking soundness.
sidebar:
  order: 2
---

Annotated circuits are built on a lower layer that you can use directly: `CircuitBuilder`, the
object-oriented `Signal` API, and the functional `CircuitAPI`. This page covers when to drop down
to that layer, how to use it, and how prover *hints* work without making your circuit forgeable.

Everything here lives in `zeroj-circuit-dsl` (package `org.zeroj.circuit`). Gadgets such as
Poseidon and comparators come from `zeroj-circuit-lib`.

## Which layer should you use?

| Style | Entry point | Use it when |
|-------|-------------|-------------|
| Annotations | `@ZKCircuit` + generated `*Circuit` | New application circuits. See [Write circuits with annotations](/guides/circuits/annotations/). |
| `CircuitSpec` + `Signal` | `CircuitBuilder.defineSignals(spec)` | You want a reusable circuit class without the annotation processor, need `Signal`-level gadgets that have no `Zk*` adapter, or are porting a circom-style circuit. |
| Inline `CircuitAPI` | `CircuitBuilder.define(api -> ...)` | Small tests, quick experiments, and building gadgets on raw `Variable`s. |

All three produce the same kind of `CircuitBuilder`, so compiling, witness calculation, and
proving are identical from there on.

## CircuitSpec with the Signal API

A `CircuitSpec` is a class with one method, `define(SignalBuilder c)`. You declare the input
*layout* on the `CircuitBuilder`, then fetch the same names inside `define`:

```java title="HashCommitmentCircuit.java"
import org.zeroj.circuit.CircuitBuilder;
import org.zeroj.circuit.CircuitSpec;
import org.zeroj.circuit.Signal;
import org.zeroj.circuit.SignalBuilder;
import org.zeroj.circuit.lib.SignalPoseidon;
import org.zeroj.circuit.lib.poseidon.PoseidonParamsBLS12_381T3;

public class HashCommitmentCircuit implements CircuitSpec {
    @Override
    public void define(SignalBuilder c) {
        Signal secret = c.privateInput("secret");
        Signal salt = c.privateInput("salt");
        Signal commitment = c.publicOutput("commitment");

        Signal hash = SignalPoseidon.hash(c, PoseidonParamsBLS12_381T3.INSTANCE, secret, salt);
        c.assertEqual(hash, commitment);
    }

    public static CircuitBuilder build() {
        return CircuitBuilder.create("hash-commitment")
                .publicVar("commitment")
                .secretVar("secret")
                .secretVar("salt")
                .defineSignals(new HashCommitmentCircuit());
    }
}
```

The rules that trip people up:

- **Names must match.** `c.publicInput("x")` / `c.publicOutput("x")` require an earlier
  `.publicVar("x")`, and `c.privateInput("y")` requires `.secretVar("y")`. An unknown name, or a
  name requested with the wrong visibility, throws `IllegalArgumentException` while the circuit is
  being defined.
- **`publicOutput` is just a public input.** The name documents intent. The prover still supplies
  the value, and only your constraints make it correct.
- **Declaration order is public-input order.** Wire 0 is the constant `1`, then every `publicVar` in
  declaration order, then every `secretVar`. Verifiers receive public inputs in exactly this order.
- **Define once.** `define` / `defineSignals` build the constraint graph and freeze that
  definition. A symbolic value that escapes the block and later tries to add constraints fails
  loudly instead of silently constraining nothing.

Constructor parameters replace circom template parameters: a `MerkleCircuit(int depth)` can loop
`depth` times in `define` and declare `sibling_0 ... sibling_{depth-1}` in its `build(depth)`.

## The inline lambda DSL

For tests and experiments, define the constraints in place with the functional `CircuitAPI`,
where values are `Variable`s and operations are methods on `api`:

```java
var circuit = CircuitBuilder.create("multiplier")
        .publicVar("c").secretVar("a").secretVar("b")
        .define(api -> api.assertEqual(api.mul(api.var("a"), api.var("b")), api.var("c")));
```

`defineSignals` also takes a lambda, so you can write Signal-style code inline, and even mix in
the symbolic annotation types:

```java
var circuit = CircuitBuilder.create("range")
        .publicVar("threshold")
        .secretVar("age")
        .defineSignals(c -> {
            var age = ZkUInt.secret(c, "age", 8);             // adds the 8-bit range check
            var threshold = ZkUInt.publicInput(c, "threshold", 8);
            age.gte(threshold).assertTrue();
        });
```

## Key Signal operations

| Operation | Meaning | R1CS cost |
|-----------|---------|-----------|
| `a.add(b)`, `a.sub(b)`, `a.neg()`, `a.add(5)` | Field addition and subtraction | Free (linear combination) |
| `a.mul(b)` | Field multiplication | 1 constraint |
| `a.mul(5)` | Multiply by a constant | Free (the compiler folds constant factors into a linear combination) |
| `a.inv()`, `a.div(b)` | Inverse, division | Adds `a·a⁻¹ = 1`, so zero has no inverse and makes the witness unsatisfiable |
| `a.toBinary(n)` | Decompose into `n` bits, LSB first | About `n` booleanity checks plus one recomposition |
| `a.and(b)`, `a.or(b)`, `a.xor(b)`, `a.not()` | Boolean logic | Inputs must already be boolean |
| `a.isZero()`, `a.isEqual(b)` | Returns 1 or 0 | A few constraints (uses advice, see below) |
| `a.lessThan(b, n)` | 1 if `a < b` as `n`-bit integers | O(n); range-checks both operands |
| `cond.select(x, y)` | `cond ? x : y`, with `cond` boolean | Small constant |
| `a.assertBoolean()`, `a.assertInRange(n)` | Constrain to {0,1} or to `[0, 2ⁿ)` | 1, about `n + 1` |
| `c.assertEqual(a, b)`, `c.assertNotEqual(a, b)` | Equality constraints | Small constant |
| `c.constant(v)`, `c.fromBinary(bits)`, `c.arrayAccess(arr, idx)` | Constants, recomposition, MUX lookup | Free, free, O(length) |

The golden rule of R1CS cost: additions are free, multiplications are not. Reuse intermediate
results instead of recomputing them, and prefer `select` over any "branching".

`isEqual`, `lessThan` and friends *return* a 0/1 signal; they don't assert anything. Feed the
result into `c.assertEqual(result, c.constant(1))` or another constraint, or it constrains nothing.

## Compile

```java
var circuit = HashCommitmentCircuit.build();

R1CSConstraintSystem r1cs = circuit.compileR1CS(CurveId.BLS12_381);   // Groth16
r1cs.numConstraints();
r1cs.numWires();
r1cs.numPublicInputs();
r1cs.constraints();   // List<R1CSConstraint>
r1cs.flat();          // packed CSR form (R1CSFlat) for large circuits

byte[] iden3 = R1CSSerializer.serialize(r1cs);   // .r1cs file for snarkjs tooling
```

| Method | Produces | Notes |
|--------|----------|-------|
| `compileR1CS(curve)` | `R1CSConstraintSystem` | The Groth16 input. Use `CurveId.BLS12_381` for Cardano. |
| `compileR1CSWithDiagnostics(curve)` | `R1CSCompiler.CompilationResult` | Same compilation plus diagnostics. Use it in build tooling to catch changes in the R1CS shape before you generate keys. |
| `compilePlonK(curve)` | `PlonKConstraintSystem` | Experimental. See [Prove with PlonK](/guides/proving/plonk/). |

Gadgets that depend on field constants (Poseidon, MiMC) record the field they need. If you
compile or compute a witness for a different curve, `CircuitBuilder` throws
`IllegalStateException` instead of producing a circuit with mismatched constants.

:::caution[The R1CS is the key's identity]
A Groth16 proving key belongs to one exact constraint system. Any change to the circuit,
including gadget parameters, array sizes, or public-input order, needs a new key (and, for real
deployments, a new ceremony).
:::

## Compute a witness

```java
BigInteger[] witness = circuit.calculateWitness(Map.of(
        "commitment", List.of(commitment),
        "secret", List.of(secret),
        "salt", List.of(salt)), CurveId.BLS12_381);
// witness[0] = 1, witness[1..numPublic] = public inputs, then secrets, then intermediate wires
```

The witness calculator evaluates every gate in order and checks every equality assertion.
Expect these failures:

| Exception | Cause |
|-----------|-------|
| `ArithmeticException` | A constraint is violated (`Constraint violation: ...`) |
| `IllegalArgumentException` | A declared input is missing from the map |
| `IllegalStateException` | The curve doesn't match the gadgets' field |

Input values are reduced modulo the field prime before use, so `-1` becomes `p - 1`. Range-check
anything that must be a small integer. For very large circuits, `calculateWitnessFlat` and
`calculateWitnessFlatChunked` return packed limbs instead of millions of `BigInteger`s; see
[Performance & large circuits](/guides/proving/performance/).

## Hints: prover advice, and how to keep it sound

Some values are expensive to *compute* with constraints but cheap to *check*. An inverse is the
classic example: computing `a⁻¹` in-circuit is costly, but checking `a · x = 1` costs one
multiplication. A **hint** (also called advice) is a value the witness calculator computes
outside the constraint system and hands to the circuit as a new wire.

Here's the catch: **a hinted wire is unconstrained.** A malicious prover doesn't run your witness
calculator. They pick every wire value themselves. The only thing that stops them putting any
number in a hinted wire is the constraints you add around it. Soundness lives entirely in those
constraints.

You already use hints through built-ins that pin their own advice:

| Operation | Advice | Constraint that pins it |
|-----------|--------|--------------------------|
| `inv(a)` | `x = a⁻¹` | `a · x = 1` |
| `isZero(a)` | `r` (the result) and `x` (an inverse) | `a · x = 1 − r` and `a · r = 0` |
| `toBinary(a, n)` | the bits | each bit is boolean, and the bits recompose to `a` |

For advanced gadgets, `CircuitAPI.hintN(kind, params, numOutputs, inputs)` requests
multi-output advice from a fixed, enumerated set of trusted-core kinds (`Gate.HintKind`:
`MUL_MOD_REDUCE` and `INV_MOD`, used for non-native Ed25519 field arithmetic). There is
deliberately no way to plug in arbitrary advice lambdas. `hintN` creates **no constraints**: the
caller must add all of them.

The rules ZeroJ applies to its own hinted gadgets are the ones to follow in yours:

1. **Pin every hinted value.** For each advice wire, write down which constraints force it to one
   correct value, or show that a different value can't change any output.
2. **Range-check limbs and quotients.** Advice split into limbs must have each limb
   range-checked, or a prover can overflow the field.
3. **Check integer identities over the integers.** For non-native arithmetic, verify
   `a·b − q·p − r = 0` limb-wise with range-bounded carries, not merely modulo the native field.
   Checking only modulo the native field lets a prover forge by adding a multiple of the field
   modulus.
4. **Test with mutated advice.** Take an honest witness, change each hint output (+1, −1, plus
   the modulus), and assert the circuit rejects it. An accepted mutation is a forgery. The next
   page shows how: [Test your circuits for soundness](/guides/circuits/testing-circuits/).

ZeroJ's own hint-based Ed25519 multiplication (`Fe25519.USE_HINT_MUL`) ships **off by default**
and gated on an external audit. The simpler hint-based inverse (`Fe25519.USE_HINT_INVERSE`) is on
by default because its check reuses the deterministic multiplication.

## Tips

- Minimize multiplications; additions are free.
- Decompose to bits once and reuse the result. `ZkUInt.decomposition()` and
  `CircuitAPI.decompose(...)` return an owned `BitDecomposition` that gadgets can reuse, instead of
  range-checking the same wire twice.
- Use Poseidon with `PoseidonParamsBLS12_381T3.INSTANCE` as your hash. Bit-oriented hashes such as
  SHA-512 cost around a hundred thousand constraints per block.
- Keep public inputs few and bound to something meaningful. Every public wire must appear in some
  constraint, or Groth16 setup refuses the relation (see
  [Prove with Groth16](/guides/proving/groth16/#relation-validation)).

Design notes: [ADR-0010 (the Java circuit DSL)](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0010-java-circuit-dsl.md),
[ADR-0028 (DSL optimization and hint soundness)](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0028-dsl-optimization-and-hint-soundness.md).

## Next steps

- [Gadget library](/guides/circuits/gadgets/)
- [Test your circuits for soundness](/guides/circuits/testing-circuits/)
- [Prove with Groth16](/guides/proving/groth16/)

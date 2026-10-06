# ZK MPF Private Registry

This minimal circuit example shows how to build and test a private membership circuit for a
Cardano Client Lib MPF registry using ZeroJ symbolic annotations. It is a
witness-level demo: it builds the registry, strictly verifies and normalizes a
CCL inclusion proof, and evaluates the operation-specific BLS12-381 circuit.

The public verifier sees only:

- `registryRoot`
- `keyPathNullifier`

The member key, value commitment, and MPF wire proof stay private inside the
symbolic circuit witness.

## Why Poseidon MPF?

CCL's normal MPF path is Blake2b-based and is compatible with the native Aiken
MPF verifier. This project uses the separate ZeroJ Poseidon MPF profile:

```text
CCL MpfTrie + ZeroJ Poseidon HashFunction
  -> CCL wire proof
  -> PoseidonMpfBranchWitness.inclusion(...)
  -> @ZKCircuit + ZkMpfInclusion
  -> BLS12-381 circuit witness
```

The two roots are not interchangeable.

## Project Structure

- `PrivateRegistryMembership.java`: annotated branch-inclusion circuit using
  `ZkMpfInclusion` and `ZkMpfBranchProof`.
- `PrivateRegistryDemo.java`: builds a CCL MPF registry, creates witness inputs,
  and calculates a BLS12-381 circuit witness.
- `PrivateRegistryMembershipCircuitTest.java`: verifies valid and invalid
  witnesses and checks that only root/nullifier are public.

## Run

Publish the current ZeroJ snapshot first:

```bash
cd /path/to/zeroj
./gradlew publishToMavenLocal
```

The default dependency version matches the local snapshot used when this
usecase was created. To test a freshly committed ZeroJ snapshot, pass the
commit-derived version explicitly:

```bash
./gradlew test -PzerojVersion=0.1.0-pre2-<commit>-SNAPSHOT
```

Then run the usecase:

```bash
cd examples/minimal-circuits/zk-mpf-private-registry
./gradlew test
./gradlew run
```

## End-to-End Tutorial

1. Build a Poseidon-rooted CCL MPF registry:

```java
PoseidonMpfTrie registry = PoseidonMpfTrie.inMemory();
registry.put(memberKey, memberValue);
registry.put(otherKey, otherValue);
```

2. Generate the CCL wire proof and strictly normalize it to the fixed S8 branch
   witness profile:

```java
byte[] proof = registry.getProofWire(memberKey).orElseThrow();
PoseidonMpfBranchWitness witness = PoseidonMpfBranchWitness.inclusion(
        registry.getRootHash(), memberKey, memberValue, proof, 8);
```

3. Build the public inputs:

```java
int[] keyPath = witness.keyPath().stream()
        .mapToInt(BigInteger::intValueExact)
        .toArray();

BigInteger registryRoot = PoseidonMpfHash.fieldFromDigestBytes(registry.getRootHash());
BigInteger keyPathNullifier = PoseidonMpfHash.keyPathNullifier(
        PoseidonParamsBLS12_381T3.INSTANCE,
        keyPath);
```

4. Add private witness values:

```java
var inputs = new ZkInputMap()
        .put("registryRoot", registryRoot)
        .put("keyPathNullifier", keyPathNullifier)
        .put("value_commitment", PoseidonMpfValueCommitment.field(memberValue));
witness.putInto(inputs);
```

5. Build and evaluate the generated annotated circuit:

```java
var circuit = PrivateRegistryMembershipCircuit.build(8);
circuit.calculateWitness(inputs.toWitnessMap(), CurveId.BLS12_381);
```

6. For Cardano on-chain use, generate a Groth16 BLS12-381 proof and verify it
   from a custom Julc validator through `Groth16BLS12381Lib.verify(...)`.
   The validator should also enforce application-specific state rules such as
   the accepted registry root and one-time nullifier use.

This project intentionally stops at witness evaluation. ZeroJ's current S8
operation-specific inclusion profile has 50,768 constraints and measured about
4.0 seconds for local Groth16 proof generation; S9 covered every inclusion path
in the retained five-million-entry reference MPF and measured about 4.2 seconds.
Those are benchmark—not production ceremony—keys. The ZeroJ Groth16 artifact and
Julc examples show the proof-submission pattern; deployment must additionally
bind the accepted root/nullifier policy and use audited ceremony output.

The circuit bound is a deployment profile, not a per-proof choice: a proving
and verification key is tied to the exact circuit. S8 is used here for a stable
example. Select a bound from a complete depth census of the application dataset;
reject proofs beyond that bound before proving.

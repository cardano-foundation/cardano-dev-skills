# Batch Threshold Matrix

This minimal circuit example shows a grouped compliance check written with
nested symbolic arrays.

The prover supplies a private rectangular matrix of measurements. The verifier
publishes one maximum value per column. The circuit proves every private cell is
less than or equal to its column maximum.

The input shape is:

```java
@Secret
@UInt(bits = 16)
@FixedSize(param = "rows", innerParam = "cols")
ZkArray<ZkArray<ZkUInt>> measurements
```

The generated schema and witness names flatten row-major:

```text
measurement_0_0, measurement_0_1, measurement_1_0, measurement_1_1
```

Run:

```bash
cd examples/minimal-circuits/batch-threshold-matrix
./gradlew test
./gradlew run
```

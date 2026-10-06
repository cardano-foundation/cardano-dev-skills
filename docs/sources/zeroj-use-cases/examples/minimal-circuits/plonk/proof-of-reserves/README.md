# Proof Of Reserves Plonk

This example demonstrates an end-to-end **BLS12-381 PlonK** proof-of-reserves
flow on Cardano.

It uses a symbolic `@ZKCircuit` for the reserve statement, generates a
ZeroJ Cardano-profile PlonK MPI proof, verifies it with the pure Java off-chain
verifier, and can submit a Yaci DevKit transaction that spends through
`ReservePlonkVerifier`, an app-local validator that reuses `PlonkBLS12381Lib`.

The exchange proves a compact reserve-unit statement:

- A private fixed batch of customer liabilities opens to a public deterministic
  liability batch commitment.
- The public asset value is greater than or equal to the public claimed liabilities.
- The private liability batch sums exactly to the claimed liability total.
- The non-negative private surplus witness opens the solvency margin.

The circuit uses `@CircuitParam` and `@FixedSize(param = "accounts")`, so the
same Java source can build different fixed-batch circuits. Amounts are 8-bit
reserve units to keep local PlonK proving and Yaci execution practical. The
public inputs are:

```text
liabilityBatchCommitment
assetValue
claimedLiabilities
```

On-chain, these values are supplied as datum and the proof is supplied as the
redeemer. The script verifies the bounded PlonK MPI profile with 3 public inputs
and enforces the demo reserve policy that public assets are not below public
claimed liabilities.

The commitment in this demo is deliberately compact so proving and on-chain
testing remain practical in Yaci DevKit. It is a deterministic test commitment,
not a production Merkle/Poseidon liability tree. A production reserve statement
should replace it with an audited liability commitment scheme and ceremony
artifacts before holding user value.

This is an experimental PlonK demo pending independent security audit of the
PlonK stack. It uses a locally generated test Powers of Tau SRS and must not be
used for value-bearing deployment.

The first run generates a development SRS and circuit proving key. To reuse the
proving key for local host runs, set `ZEROJ_PLONK_SETUP_CACHE_DIR`:

```bash
ZEROJ_PLONK_SETUP_CACHE_DIR=/tmp/zeroj-plonk-cache ./gradlew run --args='--yaci'
```

Docker Compose sets this automatically and stores the proving key in a named
volume. Production deployments should replace the development setup with
audited ceremony artifacts and pinned proving/verifying-key artifacts.

Run:

```bash
cd examples/minimal-circuits/plonk/proof-of-reserves
./gradlew test
./gradlew run
```

Run against a running Yaci DevKit:

```bash
./gradlew run --args='--yaci'
```

Run without installing Java locally, from the `zeroj-usecases` repo root:

```bash
docker compose --profile proof-of-reserves-plonk up --build --abort-on-container-exit
```

For the current local ZeroJ snapshot, the Docker build expects a sibling
`../zeroj` checkout and publishes it to Maven local inside the builder image.

Run the gated Yaci integration test:

```bash
ZEROJ_YACI_E2E=true ./gradlew test --tests '*PlonkReserveYaciE2ETest'
```

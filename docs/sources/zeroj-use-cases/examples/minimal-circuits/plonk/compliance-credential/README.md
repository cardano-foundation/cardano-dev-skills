# Compliance Credential Plonk

This example demonstrates an end-to-end **BLS12-381 PlonK** compliance-credential
flow on Cardano.

It uses a symbolic `@ZKCircuit` for a private compliance gate, generates a
ZeroJ Cardano-profile PlonK MPI proof, verifies it with the pure Java off-chain
verifier, and can submit a Yaci DevKit transaction that spends through
`CredentialPlonkVerifier`, an app-local validator that reuses `PlonkBLS12381Lib`.

The credential holder proves:

- A private deterministic test commitment opens to the private credential fields.
- The private age satisfies the public minimum-age policy using a bounded
  private age-surplus witness.
- The private jurisdiction code equals the public required jurisdiction.
- The private sanctions-screen flag is true.

The circuit keeps attributes as 8-bit demo policy values so local PlonK proving
and Yaci execution remain practical. The public inputs are:

```text
credentialCommitment
minimumAge
requiredJurisdiction
```

On-chain, these values are supplied as datum and the proof is supplied as the
redeemer. The script verifies the bounded PlonK MPI profile with 3 public inputs
and enforces the demo policy of minimum age 18 and required jurisdiction 1.

The commitment in this demo is deliberately compact so proving and on-chain
testing remain practical in Yaci DevKit. It is a deterministic test commitment,
not a production issuer credential. A production compliance credential must bind
the attributes to an issuer signature or another audited trust root before
holding user value.

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
cd examples/minimal-circuits/plonk/compliance-credential
./gradlew test
./gradlew run
```

Run against a running Yaci DevKit:

```bash
./gradlew run --args='--yaci'
```

Run without installing Java locally, from the `zeroj-usecases` repo root:

```bash
docker compose --profile compliance-credential-plonk up --build --abort-on-container-exit
```

For the current local ZeroJ snapshot, the Docker build expects a sibling
`../zeroj` checkout and publishes it to Maven local inside the builder image.

Run the gated Yaci integration test:

```bash
ZEROJ_YACI_E2E=true ./gradlew test --tests '*PlonkCredentialYaciE2ETest'
```

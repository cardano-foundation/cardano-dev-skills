# ZeroJ Use Case Demos

Runnable examples for building zero-knowledge applications on Cardano with
[ZeroJ](https://github.com/bloxbean/zeroj). The top-level projects are
end-to-end Spring Boot demos with UI, REST APIs, proof generation, and real
Yaci DevKit transactions. Smaller developer examples live under
`examples/minimal-circuits`.

Most end-to-end demos now use ZeroJ symbolic circuit annotations. The Digital
Product Passport demo is intentionally kept as the lower-level `CircuitSpec`
example. On-chain Groth16 and Plonk verification is delegated to ZeroJ's tested
on-chain verifier libraries:

- `Groth16BLS12381Lib`
- `PlonkBLS12381Lib`

## Start Here

For a first run, use a top-level Spring Boot demo. These exercise the complete
flow: circuit, proof, Cardano transaction, and on-chain verification.

```bash
# 1. Start Yaci DevKit outside this repo
$ devkit start
yaci-cli> create-node -o --start

# 2. Run a full end-to-end demo through Docker
./demo.sh proof-of-reserves --run
```

Then open the UI URL printed by `demo.sh`.

`demo.sh` starts only the selected demo app container. Yaci DevKit is expected
to be running externally on the host. The script waits for the
Blockfrost-compatible API, tops up the shared demo wallet through Yaci's admin
API, starts the app, opens the UI, and can run a happy-path curl flow with
`--run`.

```bash
./demo.sh proof-of-reserves --run
./demo.sh identity-kyc --run
./demo.sh nft-ownership --run
./demo.sh voting --run
./demo.sh airdrop --run
./demo.sh dpp --run
./demo.sh selective-disclosure --run
./demo.sh reusable-kyc --run
```

Stop a demo without stopping Yaci:

```bash
./demo.sh proof-of-reserves --stop
```

## Repository Layout

```text
zeroj-usecases/
  proof-of-reserves/              Spring Boot E2E
  identity-kyc/                   Spring Boot E2E
  nft-ownership/                  Spring Boot E2E
  private-voting/                 Spring Boot E2E
  personhood-airdrop/             Spring Boot E2E
  digital-product-passport/       Spring Boot E2E, CircuitSpec reference
  selective-disclosure/           Spring Boot E2E
  reusable-kyc/                   Spring Boot E2E, BBS selective disclosure

  examples/
    minimal-circuits/
      batch-threshold-matrix/     lightweight symbolic circuit example
      zk-mpf-private-registry/    witness-level Poseidon MPF circuit example
      plonk/
        proof-of-reserves/        Plonk proof + Yaci verifier transaction
        compliance-credential/    Plonk proof + Yaci verifier transaction
```

## Full E2E Demos

| Demo | What it proves | Default `demo.sh` port | Circuit style |
|---|---|---:|---|
| [proof-of-reserves](proof-of-reserves/README.md) | Reserves cover liabilities without exposing balances | 8089 | Symbolic annotations |
| [identity-kyc](identity-kyc/README.md) | Age and country eligibility without revealing personal data | 8087 | Symbolic annotations |
| [nft-ownership](nft-ownership/README.md) | NFT ownership without revealing wallet or token | 8085 | Symbolic annotations |
| [private-voting](private-voting/README.md) | Eligible voter, one private vote, no double-vote | 8086 | Symbolic annotations |
| [personhood-airdrop](personhood-airdrop/SYBIL_AIRDROP_TUTORIAL.md) | One claim per person per epoch | 8083 | Symbolic annotations |
| [digital-product-passport](digital-product-passport/README.md) | Product compliance without exposing supply-chain data | 8088 | `CircuitSpec` |
| [selective-disclosure](selective-disclosure/SELECTIVE_DISCLOSURE_TUTORIAL.md) | Multiple predicates from one signed credential | 8091 | Symbolic annotations |
| [reusable-kyc](reusable-kyc/README.md) | KYC once, reveal only the attributes each service needs — **BBS proof verified natively on-chain** | 8092 | BBS (no circuit) |

Some apps have native Spring ports that overlap, such as 8085. The Docker demo
maps them to distinct host ports so multiple profiles can exist without port
collisions. For direct local Java runs, run one app at a time or update
`server.port` in that module.

## Requirements

For the Docker demo path:

- Docker with Compose v2
- Yaci DevKit running on the host

Docker demos use the released ZeroJ version configured by `ZEROJ_VERSION`
(`0.1.0-pre12` by default). A sibling ZeroJ checkout is optional and only needed
when you explicitly opt into publishing a local ZeroJ build during Docker image
builds.

For direct Java runs:

- Java 25, preferably GraalVM
- Yaci DevKit for any on-chain flow
- Node.js is optional; frontends are already built into the Spring JARs

Gradle dependency defaults for ZeroJ, Julc, and cardano-client-lib live in
[`gradle/usecase-versions.gradle`](gradle/usecase-versions.gradle) and are used
by every independent use-case build. Override them with `-PzerojVersion=...`,
`-PjulcVersion=...`, or `-PcclVersion=...`.

The demo mnemonic and address are local-devnet only. Do not use them on public
or production networks.

## Running With Docker

Start Yaci DevKit first:

```bash
$ devkit start
yaci-cli> create-node -o --start
```

Run a demo:

```bash
./demo.sh proof-of-reserves --run
```

Run from a fresh trusted setup instead of committed presentation cache:

```bash
./demo.sh proof-of-reserves --clean-cache --run
```

`--clean-cache` removes only the selected usecase's Docker volume and disables
demo-cache seeding for that run.

By default the containers reach host Yaci through:

```text
BLOCKFROST_BASE_URL=http://host.docker.internal:8080/api/v1/
YACI_ADMIN_URL=http://host.docker.internal:10000
```

The script derives provider health from `BLOCKFROST_BASE_URL` as
`<base>/epochs/latest`. Override it only if your provider uses a different
health endpoint:

```bash
PROVIDER_HEALTH_URL=http://host.docker.internal:8080/api/v1/epochs/latest \
./demo.sh voting --run
```

To run against a public Blockfrost-compatible testnet endpoint, fund the
configured mnemonic on that network and disable local Yaci top-up:

```bash
DEMO_TOPUP_ENABLED=false \
BLOCKFROST_BASE_URL=https://cardano-preprod.blockfrost.io/api/v0 \
BLOCKFROST_PROJECT_ID=<project-id> \
CARDANO_NETWORK=preprod \
./demo.sh dpp --run
```

To build Docker demos against a local ZeroJ checkout instead of the released
artifact:

```bash
PUBLISH_LOCAL_ZEROJ=true \
ZEROJ_SOURCE_CONTEXT=../zeroj \
./demo.sh proof-of-reserves --run
```

## Running Directly With Java

Use this when you want to develop a module locally:

```bash
cd proof-of-reserves
./gradlew clean bootJar
java --enable-native-access=ALL-UNNAMED \
  -Dzeroj.allowInsecureTrustedSetup=true \
  -jar build/libs/proof-of-reserves-*.jar
```

The same pattern works for every top-level Spring Boot module. Some modules
take several minutes on first boot because they generate or validate
development trusted setup artifacts. The system property explicitly permits
the single-party development setup used by these demos; do not enable it for
production setup material.

## Minimal Circuit Examples

These examples are for developers who want to inspect a circuit in isolation.
They do not replace the E2E demos.

```bash
cd examples/minimal-circuits/batch-threshold-matrix
./gradlew test
./gradlew run

cd ../zk-mpf-private-registry
./gradlew test
./gradlew run
```

## Plonk Examples

The Plonk examples live under `examples/minimal-circuits/plonk`. They can run
locally with Java or through Docker Compose. They submit lock/unlock
transactions to Yaci when run with `--yaci`.

```bash
cd examples/minimal-circuits/plonk/proof-of-reserves
./gradlew test
./gradlew run --args='--yaci'

cd ../compliance-credential
./gradlew test
./gradlew run --args='--yaci'
```

Docker Compose from the repo root:

```bash
docker compose --profile proof-of-reserves-plonk up --build --abort-on-container-exit
docker compose --profile compliance-credential-plonk up --build --abort-on-container-exit
docker compose --profile plonk up --build --abort-on-container-exit
```

Plonk proving-key caches are stored in named Docker volumes:

```bash
docker volume rm zeroj-usecases_proof-of-reserves-plonk-cache
docker volume rm zeroj-usecases_compliance-credential-plonk-cache
```

## Building Everything

From the repository root:

```bash
# If Gradle is installed locally, use the root aggregate tasks:
gradle buildAllUsecasesNoTests
gradle testAllUsecases

# Or use the repo script, which runs each module's wrapper:
./build-all.sh build -x test
```

To test against a local ZeroJ build:

```bash
cd ../zeroj
./gradlew publishToMavenLocal

cd ../zeroj-usecases
gradle buildAllUsecasesNoTests -PzerojVersion=<local-zeroj-version>
```

`<local-zeroj-version>` is the version the ZeroJ build published (a `-SNAPSHOT` version is
published as `<version>-<commit>-SNAPSHOT`). Every build resolves `mavenLocal()` first, so a
local publish of a released version number shadows the Maven Central artifact until it is
removed from `~/.m2/repository/org/zeroj`.

For Docker builds, use `PUBLISH_LOCAL_ZEROJ=true` and point
`ZEROJ_SOURCE_CONTEXT` at the local checkout as shown in the Docker section.

## Demo Cache

`demo-cache/` contains development setup artifacts used to make Docker demos
start quickly during presentations. They are generated with insecure
single-party development setup and are not production ceremony artifacts.

Use `--clean-cache` when you want to demonstrate or test first-run setup
generation.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Yaci health check fails | Start Yaci DevKit with `yaci-cli devkit start`; verify `http://localhost:8080/api/v1/epochs/latest`. |
| Top-up fails | Verify Yaci admin API is reachable at `http://localhost:10000`. |
| Container cannot reach host Yaci | Docker uses `host.docker.internal`; Compose also maps it through `host-gateway` for Linux. |
| BLST native access warning or failure | Use Java 25 and run JVM apps with `--enable-native-access=ALL-UNNAMED`. |
| First boot is slow | Expected for large circuits. Use committed demo cache for presentation runs or `--clean-cache` for fresh setup generation. |
| ZeroJ dependency resolution fails | Verify `ZEROJ_VERSION` is a published artifact. For unreleased local builds, set `PUBLISH_LOCAL_ZEROJ=true` and `ZEROJ_SOURCE_CONTEXT=/path/to/zeroj`. |

## Learn More

- [ZeroJ](https://github.com/bloxbean/zeroj)
- [Yaci DevKit](https://github.com/bloxbean/yaci-devkit)
- [cardano-client-lib](https://github.com/bloxbean/cardano-client-lib)

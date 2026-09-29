
WARNING: This project is in early development and is not production-ready. Use at your own risk.

# Cardano Node test assets for Antithesis

This repository contains test assets and configurations for running [Antithesis](https://antithesis.com/) fault-injection tests against Cardano Node implementations.

## Structure of the repository

- `testnets/`: Testnet configurations (docker-compose + genesis parameters).
- `components/`: Reusable Docker containers for the test environment.

## Components

Docker containers that set up and drive the Antithesis test environment. Depending on their role, they range from simple wrappers around external executables to complex services for actively or passively testing Cardano Nodes.

- `adversary/`: A node-to-node downstream chain-sync client that connects to producers from a random intersection point, pulls a bounded number of blocks, then disconnects. Today's surface is downstream-only; the long-term plan is a long-running daemon with parallel-driver fan-out (see [adversary roadmap](components/adversary-roadmap.md)).
- `asteria-game/`: Workload container that hosts a long-lived UTxO indexer plus composer-fired bootstrap, player, and invariant binaries for the [asteria](https://github.com/txpipe/asteria) game.
- `configurator/`: Generates genesis files, node configuration, and signing keys for the testnet using the [testnet-generation-tool](https://github.com/cardano-foundation/testnet-generation-tool).
- `config/`: Antithesis platform configuration container.
- `sidecar/`: Network health checks and Antithesis assertions that validate testnet status.
- `tracer-sidecar/`: Processes structured node logs from cardano-tracer into Antithesis assertions (chain convergence, error detection).
- `tx-generator/`: Long-running daemon that submits well-formed ADA transfers via N2C; composer drivers fire `transact` and `refill` requests over its control socket.

## Testnets

Currently we provide and maintain one testnet configuration. Some old testnets are preserved in the [old-broken](https://github.com/cardano-foundation/cardano-node-antithesis/tree/main/old-broken) directory for historical reference.

- `cardano_node_master/`: A mixed-version testnet with 4 block producers (10.5.3, 10.6.2, 10.7.1, 11.0.1), 3 relay nodes (10.6.2, 10.7.1, 11.0.1), tracer observability, Asteria Plutus workload pressure, and tx-generator ADA-transfer pressure. See [cardano-node-master](testnets/cardano-node-master.md) for details.

## Image publishing

Component images are published to `ghcr.io/cardano-foundation/cardano-node-antithesis/` via the `publish-images` workflow. The docker-compose references images by commit hash (e.g., `configurator:aa43ea4`). Nix-built images stamp OCI `created` from source revision time, not packaging wall-clock; see [image provenance](images/provenance.md). The publish workflow:

1. Runs the daemon-free provenance proof (`just check-image-provenance`)
2. Scans `docker-compose.yaml` for image references matching the registry prefix
3. Resolves each tag (commit hash) to a git revision
4. Checks out that revision and builds from `components/<name>/`
5. Pushes the image tagged with both the short hash and full commit hash, skipping tags that already exist and digest-only pins

To add a new component: create `components/<name>/Dockerfile`, reference it in docker-compose as `ghcr.io/cardano-foundation/cardano-node-antithesis/<name>:<commit>`, and push. The publish workflow builds and pushes it automatically on PR or merge to main. The live Antithesis freshness warning needs a consuming run of the corrected tags; this repository does not claim that live resolution. The MOOG config image is a separate artifact.

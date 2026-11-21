# Configurator

Generates genesis files, node configuration, topology, and signing keys for the testnet at startup.

## How it works

1. Reads `testnet.yaml` for genesis parameters (pool count, network magic, epoch length, protocol version)
2. Runs the [testnet-generation-tool](https://github.com/cardano-foundation/testnet-generation-tool) to produce genesis files and pool keys
3. Generates a ring topology for producers (`p1` through `pN`, where `N` is `poolCount`)
4. Sets the system start time to the current time
5. Writes configs to per-pool volumes (`p1-configs` through `pN-configs`)

## Image

`ghcr.io/cardano-foundation/cardano-node-antithesis/configurator:<commit>`

Built from `components/configurator/Dockerfile`. Uses cardano-cli and cardano-node from the official IntersectMBO image (pinned to the highest node version in the testnet).

## Key files

- `configurator.sh`: Main entry point — orchestrates genesis generation, topology, and config post-processing
- `Dockerfile`: Multi-stage build copying cardano binaries + Nix deps from the official node image

## Outputs

Each pool volume receives:
- `configs/config.json` — node configuration
- `configs/topology.json` — peer connections
- `configs/*-genesis.json` — Byron, Shelley, Alonzo, Conway genesis files
- `keys/` — pool-specific signing keys (KES, VRF, opcert, payment, stake)

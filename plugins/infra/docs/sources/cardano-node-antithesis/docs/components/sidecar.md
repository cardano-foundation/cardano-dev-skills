# Sidecar

Network health checks and Antithesis test driver.

## Role

The sidecar connects to each producer node via node-to-client (N2C) protocol and validates network status. It signals to Antithesis when the testnet setup is complete and ready for fault injection.

## Image

`ghcr.io/cardano-foundation/cardano-node-antithesis/sidecar:<commit>`

## Configuration

Environment variables:
- `NETWORKMAGIC`: Testnet network magic (42)
- `PORT`: Node port (3001)
- `POOLS`: Number of block-producing pools
- `NCONNS`: Number of connections per pool
- `CHAINPOINT_FILEPATH`: Path to chain points log from tracer

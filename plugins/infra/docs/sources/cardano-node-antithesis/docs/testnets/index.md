# Testnets

## Available commands

```bash
just
```

```text
Available recipes:
    attack testnet='cardano-node-releases'            # attack the network with adversarial chain sync clients
    check-convergence testnet='cardano-node-releases' # check convergence of nodes in a testnet
    default                                         # just this help message
    down testnet='cardano-node-releases'              # stop a testnet
    exec container testnet='cardano-node-releases'    # exec into a container
    logs container testnet='cardano-node-releases'    # view logs of a container
    ps testnet='cardano-node-releases'                # list containers in a testnet
    restart testnet='cardano-node-releases'           # restart a testnet
    up testnet='cardano-node-releases'                # start a testnet
```

## Running locally

Run the testnet locally before submitting to Antithesis to verify containers start and the chain converges:

```bash
# Start
just up

# Verify all containers are running
just ps

# Watch chain progress
just logs tracer-sidecar

# Stop and clean up volumes
just down
```

The `justfile` wraps `docker compose` commands. All images must be available locally (built) or published to `ghcr.io`.

## Available testnets

- [cardano-node-releases](cardano-node-releases.md): Mixed-version testnet with producers, relays, tracer observability, Asteria Plutus workload pressure, and tx-generator ADA-transfer pressure
- [cardano-node-releases-fast](cardano-node-releases.md#fast-variant): The same cluster with 5000 s epochs, so a run crosses epoch boundaries

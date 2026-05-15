# Yaci DevKit Quickstart

Yaci DevKit provides a local Cardano devnet using Docker for fast smart contract development and testing.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available for Docker
- Ports 3001 and 10000 available

## Starting the DevKit

### Option 1: Interactive mode (recommended for exploration)

```bash
docker run -it --name yaci-devkit \
  -p 3001:3001 \
  -p 10000:10000 \
  bloxbean/yaci-devkit:latest
```

This drops you into the Yaci CLI where you can manage the devnet interactively.

### Option 2: Detached mode (for CI/scripts)

```bash
docker run -d --name yaci-devkit \
  -p 3001:3001 \
  -p 10000:10000 \
  bloxbean/yaci-devkit:latest
```

## Yaci CLI Commands

Once inside the interactive CLI:

```bash
# Create and start a devnet
devnet:create
devnet:start

# Check devnet status
devnet:info

# Fund an address with test ADA
devnet:topup <address> <amount_in_ada>

# Reset the devnet (clean state)
devnet:reset

# Stop the devnet
devnet:stop
```

## Configuration

### Custom devnet configuration

Create a `devnet-config.yaml` to customize:

```yaml
# Protocol parameters
slotLength: 0.2          # Seconds per slot (faster = quicker testing)
protocolMagic: 42        # Network magic number
era: Conway              # Babbage or Conway

# Genesis configuration
initialFunds:
  - address: addr_test1qz...
    amount: 10000000000   # 10,000 ADA in lovelace
```

Mount the config when starting:

```bash
docker run -it --name yaci-devkit \
  -p 3001:3001 \
  -p 10000:10000 \
  -v $(pwd)/devnet-config.yaml:/app/config/devnet-config.yaml \
  bloxbean/yaci-devkit:latest
```

### Era selection

- **Babbage**: Standard Plutus V1/V2 smart contracts
- **Conway**: Governance features (CIP-1694), Plutus V3

## Pre-funded Wallets

DevKit creates pre-funded wallets on devnet creation. Access wallet details:

```bash
# Inside Yaci CLI
devnet:default-addresses
```

Default wallets come with sufficient test ADA for development. Use `devnet:topup` to fund additional addresses.

## Yaci Store API

The built-in Yaci Store provides a REST API at `http://localhost:10000`:

```bash
# Query UTxOs at an address
curl http://localhost:10000/api/v1/addresses/<address>/utxos

# Get latest block
curl http://localhost:10000/api/v1/blocks/latest

# Get transaction details
curl http://localhost:10000/api/v1/txs/<tx_hash>

# Protocol parameters
curl http://localhost:10000/api/v1/epochs/latest/parameters
```

## Connecting SDKs

### Mesh SDK (JavaScript/TypeScript)

```typescript
import { YaciProvider } from "@meshsdk/core";

const provider = new YaciProvider("http://localhost:10000/api/v1");
```

### Evolution SDK (TypeScript)

If running Ogmios + Kupo alongside Yaci DevKit, point the client at them via `.withKupmios(...)`. Evolution SDK also ships its own first-party local devnet (`@evolution-sdk/devnet`) as a code-first alternative to Yaci DevKit — see `evolution-sdk-devnet.md` in this directory.

```typescript
import { Client, preprod } from "@evolution-sdk/evolution"

// Pick `preprod` (or `preview`) depending on which network Yaci is emulating.
const client = Client.make(preprod).withKupmios({
  ogmiosUrl: "http://localhost:1337",
  kupoUrl: "http://localhost:1442",
})
```

### PyCardano (Python)

```python
from pycardano import BlockFrostChainContext

# Yaci Store is compatible with Blockfrost API format
context = BlockFrostChainContext(
    base_url="http://localhost:10000/api/v1",
    project_id="yaci"  # Any string works locally
)
```

## Smart Contract Deployment

### Using Aiken + SDK

```bash
# 1. Build the Aiken project
aiken build

# 2. The plutus.json blueprint is generated
# 3. Use your SDK to read the blueprint and deploy

# Example with cardano-cli (inside the container)
docker exec -it yaci-devkit bash
cardano-cli transaction build ...
```

## Common Issues

### Port conflicts

```bash
# Check if ports are in use
lsof -i :3001
lsof -i :10000

# Use different ports
docker run -it --name yaci-devkit \
  -p 3002:3001 \
  -p 10001:10000 \
  bloxbean/yaci-devkit:latest
```

### Container already exists

```bash
# Remove existing container
docker rm -f yaci-devkit

# Or restart it
docker start -i yaci-devkit
```

### Devnet not producing blocks

```bash
# Inside Yaci CLI, restart the devnet
devnet:stop
devnet:start
```

### Transactions failing with "era mismatch"

Ensure your transaction is built for the same era as the devnet. Check with `devnet:info` and match your SDK/CLI configuration.

### Resetting state

```bash
# Clean reset (inside CLI)
devnet:reset

# Or remove container and recreate
docker rm -f yaci-devkit
# Then run the docker run command again
```

## CI/CD Usage

```yaml
# GitHub Actions service
services:
  yaci-devkit:
    image: bloxbean/yaci-devkit:latest
    ports:
      - 3001:3001
      - 10000:10000
    options: >-
      --health-cmd "curl -f http://localhost:10000/api/v1/blocks/latest || exit 1"
      --health-interval 10s
      --health-timeout 5s
      --health-retries 10
```

Wait for the devnet to be ready before running tests:

```bash
# Wait script
until curl -sf http://localhost:10000/api/v1/blocks/latest; do
  echo "Waiting for Yaci DevKit..."
  sleep 2
done
echo "DevKit ready"
```

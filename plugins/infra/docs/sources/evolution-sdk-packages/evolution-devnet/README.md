# @evolution-sdk/devnet

Docker-based local Cardano network for testing and development.

## Installation

```bash
pnpm add -D @evolution-sdk/devnet @evolution-sdk/evolution
```

**Prerequisites**: Docker must be installed and running.

## Usage

```typescript
import { Devnet } from "@evolution-sdk/devnet"

// Create and start devnet
const cluster = await Devnet.Cluster.make()
await Devnet.Cluster.start(cluster)

// Cleanup
await Devnet.Cluster.stop(cluster)
await Devnet.Cluster.remove(cluster)
```

### With Pre-funded Address

```typescript
const cluster = await Devnet.Cluster.make({
  shelleyGenesis: {
    initialFunds: {
      "addr_test1...": 1_000_000_000_000  // 1000 ADA
    }
  }
})
await Devnet.Cluster.start(cluster)
```

### With Kupo and Ogmios

```typescript
const cluster = await Devnet.Cluster.make({
  kupo: { enabled: true, port: 1442 },
  ogmios: { enabled: true, port: 1337 }
})
await Devnet.Cluster.start(cluster)
```

## Configuration

```typescript
interface DevNetConfig {
  clusterName?: string
  networkMagic?: number
  ports?: { node: number; submit: number }
  shelleyGenesis?: Partial<ShelleyGenesis>
  kupo?: KupoConfig
  ogmios?: OgmiosConfig
}
```

### Accelerated Block Production

```typescript
const cluster = await Devnet.Cluster.make({
  shelleyGenesis: {
    slotLength: 0.02,      // 20ms slots (50x faster)
    activeSlotsCoeff: 1.0  // 100% block density
  }
})
```

## API

### Cluster
- `Cluster.make(config?)` - Create cluster
- `Cluster.start(cluster)` - Start containers
- `Cluster.stop(cluster)` - Stop containers
- `Cluster.remove(cluster)` - Remove containers

### Container
- `Container.execCommand(container, command)` - Execute command in container
- `Container.getStatus(container)` - Get container status

### Genesis
- `Genesis.calculateUtxosFromConfig(config)` - Calculate genesis UTxOs
- `Genesis.queryUtxos(cluster)` - Query UTxOs from running node

## Testing

```typescript
import { Devnet } from "@evolution-sdk/devnet"

describe("tests", () => {
  let cluster

  beforeAll(async () => {
    cluster = await Devnet.Cluster.make()
    await Devnet.Cluster.start(cluster)
  })

  afterAll(async () => {
    await Devnet.Cluster.remove(cluster)
  })
})
```

---
name: setup-devnet
description: >-
  Guides setting up a local Cardano development environment. Triggers: "setup devnet", "local testnet", "Yaci DevKit", "development environment", "local Cardano node", "devnet", "preview testnet", "preprod testnet".
allowed-tools: Read Grep Glob
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Set Up a Cardano Development Environment

Help the developer set up a local Cardano development network for building, testing, and deploying smart contracts.

## When to use

- Developer wants to run a local Cardano network for development
- Setting up Yaci DevKit or similar local devnet tooling
- Configuring local chain indexers (Kupo, Ogmios) for development
- Establishing a smart contract development workflow (build, deploy, test)
- Connecting to Preview or Preprod public testnets
- Setting up CI/CD pipelines for Cardano projects

## When NOT to use

- Querying mainnet or production chain data (use `query-chain` skill)
- Choosing between SDKs or tools broadly (use `suggest-tooling` skill)
- Writing smart contract logic in Aiken or Plutus
- Wallet integration in a web frontend (use `connect-wallet` skill)

## Key principles

1. **Start local, then move to testnets.** Local devnets give instant feedback. Use Preview/Preprod for integration testing.
2. **Yaci DevKit is the fastest path.** Docker-based, pre-configured, includes funded wallets.
3. **Automate from day one.** Scripts for devnet startup, contract deployment, and testing save hours.
4. **Match your devnet to your target network.** Ensure protocol parameters and era match what you will deploy to.
5. **Keep test wallets organized.** Use named wallets with known keys for reproducible testing.

## Workflow

### Step 1: Choose the environment

Ask the developer (if not already clear):

- **Are you developing smart contracts or off-chain code (or both)?**
- **Do you need a fully isolated local network or a shared testnet?**
- **What OS are you on?** (Docker availability matters)
- **Do you need governance features (Conway era)?**

| Environment | Best for | Setup time |
|---|---|---|
| **Yaci DevKit** | Smart contract dev, fast iteration, isolated testing | 5 minutes |
| **Preview testnet** | Integration testing, shared state, longer-lived deployments | 10 minutes |
| **Preprod testnet** | Pre-production testing, mirrors mainnet parameters | 10 minutes |
| **Custom local cluster** | Advanced scenarios, custom protocol params | 30+ minutes |

### Step 2: Search Bundled Documentation

Search the bundled documentation for relevant content:
- `${CLAUDE_SKILL_DIR}/../../docs/sources/yaci-devkit/` - Yaci DevKit docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/yaci-store/` - Yaci Store docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-node-wiki/` - Cardano node wiki

### Step 3: Set up Yaci DevKit (recommended for local dev)

Reference the quickstart guide for detailed commands:

```
File: skills/infrastructure/setup-devnet/references/yaci-devkit-quickstart.md
```

#### Quick setup

1. **Prerequisites**: Docker and Docker Compose installed
2. **Start the devnet**:
   ```bash
   # Pull and run Yaci DevKit
   docker run -it --name yaci-devkit \
     -p 3001:3001 -p 10000:10000 \
     bloxbean/yaci-devkit:latest
   ```
3. **Pre-funded wallets**: DevKit provides wallets with test ADA on startup
4. **Access points**:
   - Yaci Store API: `http://localhost:10000`
   - Node socket for cardano-cli: available inside the container

#### Configure for your needs

- Set era (Babbage, Conway) for governance testing
- Adjust protocol parameters (min fee, collateral percentage)
- Configure slot length for faster/slower block production
- Enable/disable Plutus cost model overrides for testing

### Step 4: Set up local chain indexers

If your application needs to query UTxOs or chain state beyond what Yaci Store provides:

#### Ogmios (local)

```bash
# Ogmios connects to the local node
docker run --rm \
  --network host \
  cardanosolutions/ogmios:latest \
  --node-socket /path/to/node.socket \
  --node-config /path/to/config.json
```

#### Kupo (local)

```bash
# Kupo indexes UTxOs matching patterns
docker run --rm \
  --network host \
  cardanosolutions/kupo:latest \
  --ogmios-host localhost \
  --ogmios-port 1337 \
  --match "*" \
  --since origin
```

### Step 5: Smart contract workflow

#### Aiken build-deploy-test cycle

1. **Build**: `aiken build` compiles validators to UPLC
2. **Generate blueprint**: Produces `plutus.json` with compiled scripts and parameter schemas
3. **Deploy**: Use an off-chain SDK (Mesh, Evolution SDK, PyCardano) to create a transaction referencing the script
4. **Test on-chain**: Submit to local devnet, query results, iterate

```bash
# Typical Aiken workflow
aiken build
aiken check        # Run unit tests
# Then use SDK to deploy to local devnet
```

#### Test structure

- **Unit tests**: Aiken's built-in `test` keyword for validator logic
- **Integration tests**: Off-chain SDK scripts against local devnet
- **Property tests**: Aiken's `fuzz` support for property-based testing
- **End-to-end**: Full workflow tests against Preview testnet

### Step 6: Connect to public testnets

#### Preview testnet

- **Purpose**: Testing new features, faster epoch transitions
- **Faucet**: https://docs.cardano.org/cardano-testnets/tools/faucet/
- **Network magic**: 2
- **Configuration files**: Download from https://book.play.dev.cardano.org/environments.html

#### Preprod testnet

- **Purpose**: Pre-production testing, mirrors mainnet parameters
- **Faucet**: Same faucet site, select Preprod
- **Network magic**: 1
- **Configuration files**: Same source as Preview

#### Getting test ADA

```bash
# Request test ADA from the faucet (web interface or API)
# Provide your testnet address
# Receives 1000 test ADA (Preview) or 10000 (Preprod)
# Faucet has rate limits per address
```

### Step 7: CI integration

#### GitHub Actions example

```yaml
# .github/workflows/cardano-ci.yml
name: Cardano CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      yaci-devkit:
        image: bloxbean/yaci-devkit:latest
        ports:
          - 3001:3001
          - 10000:10000
    steps:
      - uses: actions/checkout@v4
      - name: Install Aiken
        uses: aiken-lang/setup-aiken@v1
      - name: Build contracts
        run: aiken build
      - name: Run unit tests
        run: aiken check
      - name: Run integration tests
        run: |
          # Wait for devnet to be ready
          # Run off-chain integration tests against localhost
```

#### Key CI considerations

- Use Docker services for the devnet
- Cache Aiken build artifacts
- Run unit tests first (fast), then integration tests (slower)
- Use deterministic wallet keys for reproducible tests
- Clean devnet state between test suites if needed

### Step 8: Troubleshooting common issues

- **Docker not starting**: Check Docker daemon is running, ports not in use
- **Node not syncing**: For local devnet, check logs inside container
- **Transactions failing**: Verify era matches (Babbage vs Conway), check collateral
- **Slow block production**: Adjust slot length in devnet config
- **Out of test ADA**: Re-create devnet (local) or use faucet (testnet)
- **cardano-cli version mismatch**: Match CLI version to node version in the devnet

## References

- `skills/infrastructure/setup-devnet/references/yaci-devkit-quickstart.md` -- Yaci DevKit quickstart guide
- Yaci DevKit: https://github.com/bloxbean/yaci-devkit
- Cardano testnets: https://docs.cardano.org/cardano-testnets/
- Aiken: https://aiken-lang.org
- Ogmios: https://ogmios.dev
- Kupo: https://cardanosolutions.github.io/kupo

# Getting Started

## Prerequisites

- **Node.js** 18+ (20+ recommended)
- **npm** or **pnpm**
- **Blockfrost account** (free tier at [blockfrost.io](https://blockfrost.io)) for a preprod API key
- **Test ADA** on preprod (from the [Cardano faucet](https://docs.cardano.org/cardano-testnets/tools/faucet/))
- A **24-word seed phrase** (BIP-39 mnemonic) for your test wallet

## Installation

```bash
npm install @easy1staking/cip113-sdk-ts @evolution-sdk/evolution effect
```

## Creating a Client

The SDK uses the [Evolution SDK](https://github.com/IntersectMBO/evolution-sdk) as its provider layer. Create a client with Blockfrost + seed wallet:

```typescript
import { evoClient, preprodChain } from "@easy1staking/cip113-sdk-ts";

const client = evoClient(preprodChain)
  .withBlockfrost({
    projectId: "preprodYOUR_KEY_HERE",
    baseUrl: "https://cardano-preprod.blockfrost.io/api/v0",
  })
  .withSeed({ mnemonic: "your 24 word seed phrase here" });
```

For browser wallets (CIP-30), use `.withCip30(walletApi)` instead of `.withSeed()`.

## Initializing the Protocol

Load the protocol blueprint and deployment parameters, then initialize:

```typescript
import { CIP113, type PlutusBlueprint, type DeploymentParams } from "@easy1staking/cip113-sdk-ts";
import { freezeAndSeizeSubstandard } from "@easy1staking/cip113-sdk-ts/freeze-and-seize";

// Load from file or API
const standardBlueprint: PlutusBlueprint = /* your standard blueprint */;
const deployment: DeploymentParams = /* your deployment params */;

// Create a substandard plugin
const fes = freezeAndSeizeSubstandard({
  blueprint: fesBlueprint,
  deployment: {
    adminPkh: "your_payment_key_hash",
    assetName: "hex_encoded_asset_name",       // raw hex (CIP-68 prefix included if applicable)
    blacklistNodePolicyId: "from_init_compliance",
    blacklistInitTxInput: { txHash: "...", outputIndex: 0 },
  },
});

// Initialize the protocol
const protocol = CIP113.init({
  client,
  standard: { blueprint: standardBlueprint, deployment },
  substandards: [fes],
});
```

## Your First Transfer

```typescript
const result = await protocol.transfer({
  senderAddress: "addr_test1...",
  recipientAddress: "addr_test1...",
  tokenPolicyId: "abcd1234...",
  assetName: "hex_asset_name",            // raw hex, CIP-68 prefix included if applicable
  quantity: 100n,
  substandardId: "freeze-and-seize",      // always specify for direct routing
});

// Sign and submit (seed wallet auto-signs, CIP-30 prompts user)
const txHash = await result._signBuilder.signAndSubmit();
await client.awaitTx(txHash);
```

> **Important:** Always pass `substandardId` when calling `transfer()`, `mint()`, or `burn()`. Without it the SDK tries all registered substandards and may produce confusing error messages.

## Running the Examples

The `examples/` directory contains 11 runnable scripts covering the full Freeze-and-Seize lifecycle, verified on Cardano preprod:

```bash
cd examples
cp .env.example .env    # fill in your Blockfrost key and seed phrase
npm install
npm run fes:setup       # validate config, show wallet balance
npm run fes:init-compliance
npm run fes:register
npm run fes:transfer
npm run fes:mint
npm run fes:burn
npm run fes:freeze
npm run fes:transfer-blocked
npm run fes:seize
npm run fes:unfreeze
npm run fes:transfer-unfrozen
```

Run them sequentially — each script saves state to `.state.json` for the next one.

> **Note:** After `unfreeze`, wait ~15 seconds before running the final transfer. Blockfrost needs time to reflect the updated UTxO set.

See the [README](../README.md#examples) for the full list of available scripts.

## Next Steps

- [Freeze-and-Seize Substandard](substandards/freeze-and-seize.md) — full compliance lifecycle
- [Dummy Substandard](substandards/dummy.md) — minimal substandard for testing
- [API Reference](api-reference.md) — all types, methods, and utilities

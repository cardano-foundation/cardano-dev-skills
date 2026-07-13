---
name: build-transaction
description: >-
  Build Cardano transaction, send ADA, mint NFT, mint token, interact with
  smart contract, delegate stake, register DRep, vote on-chain using Mesh SDK,
  Evolution SDK, PyCardano, or cardano-client-lib.
allowed-tools: Read Grep Glob
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Build Cardano Transaction

Guide the user through building Cardano transactions step by step using their
chosen off-chain SDK. Covers the full lifecycle: prerequisites, transaction
construction, signing, submission, and verification on a testnet.

## When to Use

- User wants to send ADA or native tokens to an address
- User wants to mint an NFT or fungible token
- User wants to interact with a deployed smart contract (lock, redeem, etc.)
- User wants to delegate stake to a pool or DRep
- User wants to register as a DRep or cast a governance vote
- User asks how to build, sign, or submit a Cardano transaction
- User asks which SDK to use for off-chain transaction building

## When NOT to Use

- User wants to write or review on-chain validator logic -- use `write-validator`
  or `review-contract`
- User is designing token metadata standards -- use `design-token`
- User has a failing transaction and needs help debugging -- use `debug-transaction`
- User wants to set up a local devnet or node infrastructure -- use `setup-devnet`

## Key Principles

1. **Choose the right SDK for the job.** Mesh SDK (TypeScript) and Evolution SDK
   (TypeScript) have the best documentation and highest-level APIs. PyCardano is best
   for Python shops. cardano-client-lib suits JVM projects needing fine control.
   Search `${CLAUDE_SKILL_DIR}/../../docs/sources/` for the latest SDK comparison details.

2. **Always prototype on Preview testnet.** Never build against mainnet first.
   Use the Cardano faucet to obtain test ADA. Set the network parameter
   explicitly in every code example.

3. **UTxO selection matters.** Cardano uses the EUTxO model. The SDK must
   select unspent outputs that cover the transaction value plus fees. Understand
   coin selection to avoid `ValueNotConservedUTxO` errors.

4. **Fees and change are computed, not guessed.** All SDKs have fee estimation.
   Let the SDK calculate fees and construct change outputs automatically.

5. **Transactions are deterministic.** The same inputs and parameters always
   produce the same transaction. This enables dry-run testing before submission.

6. **Collateral is required for Plutus interactions.** Any transaction that
   executes a Plutus script must include collateral UTxOs containing only ADA.

## Workflow

### Step 1: Gather Parameters

Ask the user to specify or confirm:

| Parameter | Options | Default |
|-----------|---------|---------|
| SDK | `mesh`, `evolution-sdk`, `pycardano`, `cardano-client-lib` | `mesh` |
| Transaction type | `send-ada`, `mint-nft`, `mint-token`, `interact-with-contract`, `delegate-stake`, `register-drep`, `vote` | required |
| Network | `preview`, `preprod`, `mainnet` | `preview` |
| Wallet | mnemonic, private key, browser wallet | mnemonic |

If the user does not specify an SDK, recommend **Mesh SDK** for TypeScript
projects or **cardano-client-lib** for Java/JVM projects.

### Step 2: Search Bundled Documentation

Search the bundled documentation for relevant content:
- `${CLAUDE_SKILL_DIR}/../../docs/sources/evolution-sdk/` - Evolution SDK docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/mesh-sdk/` - Mesh SDK docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/mesh-sdk-packages/` - Mesh SDK package docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/pycardano/` - PyCardano docs
- `${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-client-lib/` - Cardano Client Lib docs

### Step 3: Set Up Prerequisites

For each SDK, ensure the user has the required environment:

**Mesh SDK (TypeScript/JavaScript)**

```bash
npm install @meshsdk/core
```

- Requires Node.js 18+
- Needs a blockchain provider (Blockfrost, Koios, or Ogmios)
- Blockfrost API key from https://blockfrost.io

**Evolution SDK (TypeScript)**

```bash
npm install @evolution-sdk/evolution
```

- Requires Node.js 18+ and TypeScript 5.0+
- Effect-TS based, type-safe composable API
- Built-in Blockfrost, Koios, Kupmios, and Maestro providers
- Works in Node.js and browser environments

**PyCardano (Python)**

```bash
pip install pycardano
```

- Requires Python 3.8+
- Needs a chain context (Blockfrost, Ogmios, or CardanoCliContext)

**cardano-client-lib (Java)**

```xml
<dependency>
  <groupId>com.bloxbean.cardano</groupId>
  <artifactId>cardano-client-lib</artifactId>
  <version>0.7.2</version>
</dependency>
```

- Java/JVM library by BloxBean
- Good for fine-grained transaction control

### Step 4: Build the Transaction

Provide step-by-step code for the chosen SDK and transaction type.
Follow these patterns:

#### Send ADA Pattern

1. Initialize the provider and wallet
2. Create a transaction builder
3. Add the payment output (recipient address + lovelace amount)
4. Let the SDK handle coin selection, fee calculation, and change
5. Sign with the wallet
6. Submit to the network
7. Log the transaction hash

#### Mint NFT / Token Pattern

1. Initialize the provider and wallet
2. Define the minting policy (time-locked or Plutus script)
3. Prepare token metadata conforming to CIP-25 or CIP-68
4. Create a transaction builder
5. Add the minting action (policy, asset name, quantity)
6. Add metadata to the transaction
7. Sign with policy key + wallet key
8. Submit and log the transaction hash

#### Interact with Contract Pattern

1. Initialize the provider and wallet
2. Load the Plutus script (from file or CIP-57 blueprint)
3. For locking: build a tx that sends value to the script address with a datum
4. For redeeming: query UTxOs at the script address, select the target,
   build a tx that spends it with the correct redeemer, include collateral
5. Sign, submit, and verify

#### Delegate Stake Pattern

1. Initialize the provider and wallet
2. Create or retrieve the stake address
3. Register the stake address (if not already registered -- costs 2 ADA deposit)
4. Build a delegation certificate targeting the chosen pool ID
5. Sign and submit

#### Register DRep / Vote Pattern

1. Initialize the provider and wallet
2. For DRep registration: build a DRep registration certificate with metadata anchor
3. For voting: build a voting procedure targeting a governance action ID
4. Sign and submit

### Step 5: Explain the Transaction

After providing code, explain:

- What each part of the transaction does
- How coin selection works in this context
- What fees are expected
- What happens on-chain when this transaction is processed

### Step 6: Common Pitfalls

Warn about these frequent issues:

- **Insufficient ADA for min-UTxO:** Every UTxO must hold a minimum amount of
  ADA (roughly 1-2 ADA depending on datum/token bundle size). The SDK usually
  handles this, but manual outputs can fail.
- **Forgetting collateral:** Plutus transactions require a collateral input.
  Use a UTxO with only ADA (no tokens).
- **Wrong network:** Addresses are network-specific. A Preview address will
  not work on Preprod or Mainnet.
- **Stale UTxO set:** If another transaction consumed your inputs between
  query and submit, you get `BadInputsUTxO`. Re-query and rebuild.
- **Token name encoding:** Asset names are hex-encoded bytes. Ensure proper
  encoding (e.g., `Buffer.from("MyToken").toString("hex")`).
- **Transaction size limit:** Max 16 KB. Large token bundles or many inputs
  can exceed this. Split into multiple transactions if needed.

### Step 7: Test on a testnet before mainnet

A transaction that type-checks can still fail at submission (min-UTxO, fees, collateral,
script evaluation). Always run it on a testnet first — and for Plutus-script flows, a local
Yaci DevKit devnet (`setup-devnet`) gives the fastest build→submit→confirm loop.

1. Get test ADA from the Cardano faucet: https://docs.cardano.org/cardano-testnets/tools/faucet/
2. Run the transaction code against Preview or Preprod
3. Verify on a block explorer (Preview: https://preview.cardanoscan.io ·
   Preprod: https://preprod.cardanoscan.io)
4. Check the transaction hash matches expected outputs
5. For minting: verify the token appears in the wallet

## SDK Quick Reference

### Mesh SDK -- Transaction Builder

```typescript
import { MeshTxBuilder, BlockfrostProvider } from "@meshsdk/core";

const provider = new BlockfrostProvider("<BLOCKFROST_KEY>");
const txBuilder = new MeshTxBuilder({ fetcher: provider, submitter: provider });

// Build, sign, submit pattern
const unsignedTx = await txBuilder
  .txOut(recipientAddress, [{ unit: "lovelace", quantity: "5000000" }])
  .changeAddress(senderAddress)
  .selectUtxosFrom(utxos)
  .complete();

const signedTx = await wallet.signTx(unsignedTx);
const txHash = await wallet.submitTx(signedTx);
```

### Evolution SDK -- Composable Builder

```typescript
import { Address, Assets, preprod, Client } from "@evolution-sdk/evolution"

const client = Client.make(preprod)
  .withBlockfrost({
    baseUrl: "https://cardano-preprod.blockfrost.io/api/v0",
    projectId: process.env.BLOCKFROST_API_KEY!
  })
  .withSeed({ mnemonic: process.env.WALLET_MNEMONIC!, accountIndex: 0 })

const tx = await client
  .newTx()
  .payToAddress({
    address: Address.fromBech32("addr_test1..."),
    assets: Assets.fromLovelace(5_000_000n)
  })
  .build()

const signed = await tx.sign()
const txHash = await signed.submit()
```

### PyCardano -- TransactionBuilder

```python
from pycardano import TransactionBuilder, TransactionOutput, Address

builder = TransactionBuilder(context)
builder.add_input_address(sender_address)
builder.add_output(TransactionOutput(recipient, 5_000_000))
signed_tx = builder.build_and_sign([signing_key], change_address=sender_address)
context.submit_tx(signed_tx)
```

## References

- `references/sdk-comparison.md` -- detailed SDK comparison table
- Search `${CLAUDE_SKILL_DIR}/../../docs/sources/` for CIP-25, CIP-68 metadata standards
- Cardano Developer Portal: https://developers.cardano.org
- Mesh SDK docs: https://meshjs.dev
- Evolution SDK docs: https://evolution-sdk.dev
- PyCardano docs: https://pycardano.readthedocs.io

# Cardano Off-Chain SDK Comparison

Quick reference for choosing and using Cardano transaction-building SDKs.

## Overview

| SDK | Language | Level | Maintenance | Best For |
|-----|----------|-------|-------------|----------|
| Mesh SDK | TypeScript/JS | High | Active | Web dApps, rapid prototyping |
| Evolution SDK | TypeScript | High | Active | Type-safe composable txs |
| PyCardano | Python | Mid | Active | Python backends, scripting |
| cardano-client-lib | Java | Mid-Low | Active | JVM fine-grained control |
| cardano-js-sdk | TypeScript | Low-Mid | IOG-maintained | Full-stack TS, Lace wallet |
| Cardano Serialization Lib | Rust/WASM | Low | IOG-maintained | Custom tooling, performance |

## Mesh SDK

- **Language:** TypeScript / JavaScript
- **Repository:** github.com/MeshJS/mesh
- **Documentation:** meshjs.dev (comprehensive guides and examples)

**Strengths:**
- Highest-level API -- fewest lines of code to build transactions
- Built-in wallet connectors for browser wallets (CIP-30)
- React hooks and components for dApp frontends
- Strong community and documentation
- Supports Plutus V1, V2, and V3

**Weaknesses:**
- Abstractions can hide details needed for complex transactions
- Tied to the JavaScript ecosystem
- Some edge cases require dropping to lower-level APIs

**Installation:**
```bash
npm install @meshsdk/core
```

**Basic send-ADA pattern:**
```typescript
import { MeshTxBuilder, BlockfrostProvider } from "@meshsdk/core";

const provider = new BlockfrostProvider("YOUR_KEY");
const txBuilder = new MeshTxBuilder({ fetcher: provider, submitter: provider });

const unsignedTx = await txBuilder
  .txOut(recipient, [{ unit: "lovelace", quantity: "5000000" }])
  .changeAddress(sender)
  .selectUtxosFrom(utxos)
  .complete();
```

---

## Evolution SDK

- **Language:** TypeScript
- **Repository:** github.com/IntersectMBO/evolution-sdk
- **Documentation:** evolution-sdk.dev (detailed with examples)

**Strengths:**
- Effect-TS based, type-safe composable API
- Built-in Blockfrost, Koios, Kupmios, and Maestro providers
- Supports Plutus V1, V2, V3 and native scripts
- Works in Node.js and browser environments
- Declarative, chainable transaction builder

**Weaknesses:**
- Newer SDK, smaller community than Mesh
- Effect-TS paradigm has a learning curve
- Fewer tutorials and third-party guides

**Installation:**
```bash
npm install @evolution-sdk/evolution
```

**Basic send-ADA pattern:**
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

---

## PyCardano

- **Language:** Python
- **Repository:** github.com/Python-Cardano/pycardano
- **Documentation:** pycardano.readthedocs.io

**Strengths:**
- Pythonic API, easy to learn
- Good for scripting and automation
- Supports Plutus V1, V2, and V3
- Built-in Blockfrost and Ogmios chain context
- Solid datum/redeemer serialization

**Weaknesses:**
- Smaller ecosystem than TypeScript options
- Fewer high-level abstractions than Mesh
- No built-in browser wallet support (server-side only)

**Installation:**
```bash
pip install pycardano
```

**Basic send-ADA pattern:**
```python
from pycardano import (
    BlockFrostChainContext, TransactionBuilder,
    TransactionOutput, Address
)

context = BlockFrostChainContext("YOUR_KEY", base_url="https://cardano-preview.blockfrost.io/api")
builder = TransactionBuilder(context)
builder.add_input_address(sender_address)
builder.add_output(TransactionOutput(recipient_address, 5_000_000))

signed_tx = builder.build_and_sign(
    signing_keys=[payment_skey],
    change_address=sender_address
)
context.submit_tx(signed_tx)
```

---

## cardano-client-lib

- **Language:** Java / Kotlin (JVM)
- **Repository:** github.com/bloxbean/cardano-client-lib
- **Documentation:** github wiki + javadoc

**Strengths:**
- Fine-grained control over transaction building
- Direct access to serialization primitives
- Mature and battle-tested
- Comprehensive JVM Cardano library by BloxBean

**Weaknesses:**
- More verbose than higher-level SDKs
- Requires deeper Cardano knowledge
- Less documentation than higher-level options

**Installation (Maven):**
```xml
<dependency>
  <groupId>com.bloxbean.cardano</groupId>
  <artifactId>cardano-client-lib</artifactId>
  <version>0.7.2</version>
</dependency>
```

**Basic send-ADA pattern:**
```java
TxBuilder txBuilder = (context, txn) -> {};
TxOutputBuilder txOutBuilder = (context, outputs) -> {
    outputs.add(Output.builder()
        .address(receiver)
        .assetName(LOVELACE)
        .qty(BigInteger.valueOf(5_000_000))
        .build());
};

UtxoSupplier utxoSupplier = new DefaultUtxoSupplier(utxoService);
TxBuilderContext ctx = TxBuilderContext.init(utxoSupplier, protocolParamsSupplier);
Transaction tx = ctx.buildAndSign(txn -> {
    txOutBuilder.accept(ctx, txn.getBody().getOutputs());
}, signerFrom(senderAccount));
```

---

## cardano-js-sdk

- **Language:** TypeScript
- **Repository:** github.com/input-output-hk/cardano-js-sdk
- **Documentation:** Limited (inline JSDoc, some guides)

**Strengths:**
- Official IOG SDK, used in Lace wallet
- Comprehensive coverage of Cardano features
- Modular package architecture
- Good TypeScript types

**Weaknesses:**
- Complex API surface -- steep learning curve
- Documentation is sparse compared to Mesh
- Designed primarily for wallet use cases
- Frequent breaking changes between versions

**Installation:**
```bash
npm install @cardano-sdk/core @cardano-sdk/wallet
```

---

## Cardano Serialization Lib (CSL)

- **Language:** Rust (with WASM/JS and mobile bindings)
- **Repository:** github.com/input-output-hk/cardano-multiplatform-lib
- **Documentation:** Limited (Rust docs)

**Strengths:**
- Lowest-level SDK -- maximum control
- Best performance (Rust/WASM)
- Cross-platform (Rust, JS/WASM, mobile)
- Foundation for many other tools

**Weaknesses:**
- Very verbose -- simple transactions require many lines
- No built-in chain query or submission
- Steep learning curve
- Must manually handle fee calculation and coin selection

---

## Decision Guide

**Choose Mesh SDK when:**
- Building a web dApp with browser wallet integration
- Want the fastest path to a working transaction
- Team is TypeScript-focused
- Need React components for wallet UI

**Choose Evolution SDK when:**
- Want a type-safe, composable TypeScript transaction builder
- Prefer Effect-TS functional patterns
- Need built-in multi-provider support (Blockfrost, Koios, Kupmios, Maestro)
- Building Node.js or browser-based Cardano applications

**Choose PyCardano when:**
- Building Python backends or automation scripts
- Team is Python-focused
- Need quick scripting for testing or ops

**Choose cardano-client-lib when:**
- Need low-level JVM control over transaction bytes
- Building custom tooling or libraries
- Already using it and need backward compatibility

**Choose cardano-js-sdk when:**
- Building a wallet application
- Need official IOG-maintained SDK
- Working on Lace ecosystem integrations

**Choose Cardano Serialization Lib when:**
- Building performance-critical tooling
- Need cross-platform Rust/WASM support
- Building a new SDK or framework on top

---
title: sdk/builders/operations/Mint.ts
nav_order: 125
parent: Modules
---

## Mint overview

Mint operation - creates minting transactions for native tokens.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [programs](#programs)
  - [createMintAssetsProgram](#createmintassetsprogram)

---

# programs

## createMintAssetsProgram

Creates a ProgramStep for mintAssets operation.
Adds minting information to the transaction and tracks redeemers by PolicyId.

Implementation:

1. Validates that only native tokens are being minted (no lovelace)
2. Converts SDK Assets to Core.Mint structure
3. Merges with existing mint state
4. Tracks redeemer information for script-based minting policies (by PolicyId)

**RedeemerBuilder Support:**

- Static: Direct Data value stored immediately
- Self: Callback stored for per-policy resolution after coin selection
- Batch: Callback + input set stored for multi-policy resolution

**Signature**

```ts
export declare const createMintAssetsProgram: (
  params: MintTokensParams
) => Effect.Effect<void, TransactionBuilderError, TxContext>
```

Added in v2.0.0

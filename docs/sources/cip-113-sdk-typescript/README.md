# @easy1staking/cip113-sdk-ts

TypeScript SDK for [CIP-113 Programmable Tokens](https://cips.cardano.org/cip/CIP-0113) on Cardano.

Build, transfer, mint, burn, freeze, and seize programmable tokens with a clean, pluggable API.

## Install

```bash
npm install @easy1staking/cip113-sdk-ts @evolution-sdk/evolution effect
```

## Quick Start

```typescript
import { CIP113, evoClient, preprodChain } from "@easy1staking/cip113-sdk-ts";
import { freezeAndSeizeSubstandard } from "@easy1staking/cip113-sdk-ts/freeze-and-seize";

// 1. Create a client
const client = evoClient(preprodChain)
  .withBlockfrost({ projectId: "your_key", baseUrl: "https://cardano-preprod.blockfrost.io/api/v0" })
  .withSeed({ mnemonic: "your 24 word seed phrase" });

// 2. Initialize the protocol with a substandard
const protocol = CIP113.init({
  client,
  standard: { blueprint: standardBlueprint, deployment: deploymentParams },
  substandards: [fes],
});

// 3. Transfer programmable tokens
const result = await protocol.transfer({
  senderAddress: "addr_test1...",
  recipientAddress: "addr_test1...",
  tokenPolicyId: "abcd1234...",
  assetName: "0014df1044454d4f",          // raw hex, CIP-68 prefix included
  quantity: 1000n,
  substandardId: "freeze-and-seize",      // always specify for direct routing
});

// 4. Sign and submit
const txHash = await result._signBuilder.signAndSubmit();
await client.awaitTx(txHash);
```

## Substandards

| Substandard | Import | Capabilities |
|-------------|--------|-------------|
| **Freeze-and-Seize** | `@easy1staking/cip113-sdk-ts/freeze-and-seize` | Register, Transfer, Mint, Burn, Freeze, Unfreeze, Seize |
| **Dummy** | `@easy1staking/cip113-sdk-ts/dummy` | Transfer (testing only) |

## Exports

| Path | Description |
|------|-------------|
| `@easy1staking/cip113-sdk-ts` | Core SDK: `CIP113`, types, utilities |
| `@easy1staking/cip113-sdk-ts/freeze-and-seize` | Freeze-and-Seize substandard |
| `@easy1staking/cip113-sdk-ts/dummy` | Dummy substandard |

## Migrating to 0.9.0 (CIP-113 0.5.0-alpha.4)

**0.9.0 targets a different protocol version and breaks every published consumer.** It is a
minor bump because this package is pre-1.0; treat it as major. Version 0.8.0 was never published,
so the real upgrade path is 0.3.1, or any later published release up to 0.7.0, to 0.9.0 and crosses both the
alpha.2-to-alpha.3 and alpha.3-to-alpha.4 boundaries described here.

⛔ **The alpha.3 change that will not announce itself.** `programmable_logic_base`'s redeemer went
from a three-constructor enum to a single record:

```
0.5.0-alpha.2   SpendViaTransfer(params_idx, wdrl_idx)   = Constr(0, [Int, Int])
0.5.0-alpha.3   BaseSpendRedeemer{params_idx, wdrl_idx}  = Constr(0, [Int, Int])
```

Those are **byte-identical**. A stale builder emitting `SpendViaTransfer` produces a redeemer that
decodes cleanly and fails later on a credential check — because `wdrl_idx` now indexes the
**dispatcher's** withdrawal, not the delegate's. `SpendViaThirdParty` and `SpendViaUnfracking`
(constructors 1 and 2) fail loudly instead, so **the silence lands on the transfer path — the common
one**. This SDK refuses the stale call shape at the API surface, because nothing downstream can.

⛔ **The alpha.4 datum change is silent for the same reason.** The protocol-params datum grew
from four fields to six, and `issuance_logic_cred` was inserted at **index 1**, not appended:

| protocol version | protocol-params datum | size |
|---|---|---|
| 0.5.0-alpha.3 | `[plg, transfer, third_party, upgrade]` | 4 fields |
| 0.5.0-alpha.4 | `[plg, ISSUANCE_LOGIC, transfer, third_party, upgrade, pending]` | 6 fields |

Indices 1, 2 and 3 all hold a `Credential` before and after the change. An alpha.3 positional
reader therefore returns well-formed credentials with the wrong meanings: `transfer_cred` moved
to index 2, `third_party_cred` moved to index 3, and the old index 3 is no longer the upgrade
credential. Nothing throws or fails to decode. Change positional readers to the six-field alpha.4
layout and treat the field names, not their old positions, as the authority.

⛔ **Every mint and burn now needs `issuance_logic`'s withdraw-0.** `issuance_mint` does not
diagnose an omitted withdrawal: `covered_by` scans the transaction redeemers, returns `False` when
it finds no matching withdrawal, and the mint fails naming no withdrawal, no policy and no index.
Calling `register()`, `mint()`, or `burn()` on a 0.9.0 protocol emits the withdrawal and its
policy-keyed redeemer alongside the minting-logic withdrawal.

⚠ **CIP-68 metadata now meets the deployment's inline-datum bound on the issuance path.** At the
CIP-68 datum shape, the chain's `serialise_data` measurement is exactly 2 bytes fewer than the
SDK's `Data.toCBORBytes` measurement: Evolution emits indefinite-length CBOR for the outer
constructor and metadata map, while Plutus's canonical encoder uses definite-length headers. The
SDK is conservative: it never accepts a record the chain refuses. A caller's usable budget is
`maxInlineDatumBytes - 2`; do not loosen the SDK comparison to reclaim those two bytes.

| what changed | before | after |
|---|---|---|
| params NFT policy vs address | two derivations | **one hash serves both** (`protocolParams.policyId`) |
| registry node policy vs address | `directoryMint` / `directorySpend` | **one hash serves both** (`registry.scriptHash`) |
| protocol-params datum | 7 fields | **4** in alpha.3, then **6** in alpha.4 |
| PLB redeemer | `SpendVia*` enum | `BaseSpendRedeemer` record; the act moved to the dispatcher |
| `transferRedeemer` | `(params_idx, proofs)` | `(proofs)` |
| `thirdPartyRedeemer` / `unfrackingRedeemer` | `(params_idx, node_idx, outputs_start_idx)` | `(node_idx, outputs_start_idx)` |
| every programmable tx | delegate withdraw-0 | **plus the dispatcher's** — every `wdrl_idx` shifts |
| every mint and burn | minting-logic withdraw-0 | **plus `issuance_logic`** |
| new deployment input | — | `maxInlineDatumBytes`, a **choice**, baked into four script hashes |
| gone | `coordinationNonce`, `coordination`, `directoryMint`, `directorySpend` | — |

⚠ **`max_inline_datum_bytes` changed KIND, not just place.** It was a mutable datum field
(re-tunable by an in-place upgrade) and is now a compile-time parameter of four delegates —
`transfer`, `third_party`, `unfracking` and `issuance_logic` — so changing it is a redeployment.

⚠ **Neither an alpha.3 nor an alpha.2 deployment can be represented by this SDK.** A 4-field
alpha.3 params datum and a 7-field alpha.2 one are rejected outright rather than read
positionally. No published release of this SDK operates an alpha.3 instance; its 0.8.x source line
must be built from git. Point an alpha.2 instance at a published 0.7.x release.

## Examples

> ### ⚠ The examples do not currently run. Do not follow this section yet.
>
> Two things are wrong with it, both known and neither hidden:
>
> 1. **The scripts target a superseded protocol.** They are written against a CIP-113 **0.3.x**
>    deployment on preprod. This SDK now targets **0.5.0-alpha.3**, in which `DeploymentParams`
>    has a different shape again — see the migration note below.
>    The scripts cannot work against that deployment, and the deployment cannot be represented
>    by this SDK.
> 2. **`.env.example` does not exist.** The `cp` below has never worked.
>
> **Nothing here is covered by CI** — `examples/` is a separate package, outside the root
> typecheck and outside the test suite, so neither defect can fail a build.
>
> Choosing a replacement target is an open decision (a local devnet, or a freshly deployed
> preprod instance); it is tracked in `PLAN.md` under workstream **W-E, slice S-7**. Until it is
> made, the working end-to-end reference is the **devnet suite** — `npm run test:devnet` — which
> exercises bootstrap, register, mint, transfer, third-party transfer and an in-place upgrade
> against a live chain. See `docs/devnet.md`.

The `examples/` directory contains runnable scripts for the full token lifecycle:

```bash
cd examples
cp .env.example .env    # add your Blockfrost key + seed phrase
npm install
npm run fes:setup
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

Each script is standalone — run them sequentially to walk through the complete Freeze-and-Seize lifecycle.

## Documentation

- [Provenance: CIP-171 and blueprint pins](docs/provenance.md) — what ships, how to build a record, and why `compilerVersion` must come from the artefact

- [Getting Started](docs/getting-started.md) — prerequisites, setup, first token
- [API Reference](docs/api-reference.md) — all types, methods, utilities
- [Freeze-and-Seize](docs/substandards/freeze-and-seize.md) — compliance substandard
- [Dummy](docs/substandards/dummy.md) — minimal test substandard

## Peer Dependencies

- `@evolution-sdk/evolution` ^0.5.2
- `effect` ^3.0.0

## License

Apache-2.0

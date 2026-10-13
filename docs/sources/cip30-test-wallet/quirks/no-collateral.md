# noCollateral

**Status:** confirmed
**Observed:** CIP-30 marks getCollateral as deprecated and lets wallets leave it out, so the behaviour is defined by the deprecation itself and there is nothing wallet-specific to reproduce. Lucid Evolution and Evolution SDK never call it. Mesh 1.9.1 calls `api.getCollateral()` and falls back to `api.experimental.getCollateral()` when the first call throws, 2026-09-29.
**What the wallet does:** the enabled api has neither `getCollateral` nor `experimental.getCollateral`.
**What breaks:** a dApp that calls `api.getCollateral()` unguarded throws a TypeError instead of falling back to its own collateral selection from `getUtxos`.
**How to use:** `test.use({ walletOptions: { quirks: { noCollateral: true } } })`. Takes effect at the next `enable()`, like the CIP-95 namespace.

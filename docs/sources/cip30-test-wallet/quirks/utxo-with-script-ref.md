# UTxO with a reference script

**Status:** reported
**Observed:** claimpaign, 2026-03. Evolution SDK's provider `getUtxos()` crashes on UTxOs carrying a reference script (native script outputs from NFT mints). The workaround filters out UTxOs with `dataHash` or `scriptRef`.
**What the wallet does:** there is no switch, it is configuration. `walletOptions.utxos: [{ lovelace, scriptRef }]` gives the wallet an owned UTxO with a reference script, and `getUtxos` returns it in the Babbage output form.
**What breaks:** a dApp path that hands wallet UTxOs with a reference script unfiltered to an SDK provider.
**How to use:** `test.use({ walletOptions: { utxos: [{ lovelace: 10_000_000 }, { lovelace: 2_000_000, scriptRef: '82008200581c00000000000000000000000000000000000000000000000000000000' }] } })`, then drive the flow that reads the wallet's UTxOs.

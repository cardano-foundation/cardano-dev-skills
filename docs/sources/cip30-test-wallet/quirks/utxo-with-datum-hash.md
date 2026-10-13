# UTxO with a datum hash

**Status:** reported
**Observed:** claimpaign, 2026-03. Evolution SDK's provider `getUtxos()` crashes on UTxOs carrying a reference script (native script outputs from NFT mints). The workaround for that crash also filters out UTxOs with `dataHash`. A crash on a datum hash alone is not established.
**What the wallet does:** there is no switch, it is configuration. `walletOptions.utxos: [{ lovelace, datumHash }]` gives the wallet an owned UTxO with a datum hash, and `getUtxos` returns it as `[address, value, datum_hash]`. A datum hash together with a reference script is encoded in the Babbage map form.
**What breaks:** in a dApp with that workaround, a datum-hash UTxO goes through the same filtering path. Whether a provider fails on it is unconfirmed.
**How to use:** `test.use({ walletOptions: { utxos: [{ lovelace: 10_000_000 }, { lovelace: 2_000_000, datumHash: '00'.repeat(32) }] } })`, then drive the flow that reads the wallet's UTxOs.

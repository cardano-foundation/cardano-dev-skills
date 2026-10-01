# networkId: 1 while the dApp expects preprod

**Status:** confirmed
**Observed:** every wallet, by design. A user on mainnet opens a preprod dApp, or the other way round. Observed repeatedly in support for commitproof and claimpaign, 2026.
**What the wallet does:** `getNetworkId()` returns `1`, every address carries the mainnet header nibble. Nothing is wrong on the wallet side.
**What breaks:** dApps that build a transaction before checking the network get an SDK error like `Wallet network mismatch: wallet is on network 1 but chain id is 0`, which users cannot act on. The fix is a guard right after `enable()` that compares `getNetworkId()` with the expected network and shows a human sentence.
**How to use:** `test.use({ walletOptions: { networkId: 1 } })`. The wallet is internally consistent: id and address prefix both say mainnet, so a dApp that checks either one sees the mismatch.

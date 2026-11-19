# noCip95

**Status:** confirmed
**Observed:** wallets without Conway support. They announce no extensions and ignore `{ cip: 95 }` in `enable()`. CIP-30 defines this behaviour for any wallet that does not implement the extension, so confirming it needs no wallet name or version, 2026-09.
**What the wallet does:** `supportedExtensions` is `[]`, `getExtensions()` is `[]`, the enabled api has no `cip95` namespace, and `signTx` has no DRep key: a DRep vote or DRep certificate that no other witness covers is refused with `TxSignError` ProofGeneration (1) at `partialSign: false`, as by a wallet without governance keys.
**What breaks:** DRep flows that call `api.cip95.getPubDRepKey()` without checking the namespace throw a TypeError instead of telling the user the wallet does not support governance.
**Seen in:** a governance forum repeats the same inline guard at every DRep call site and shows its own message. The guard itself was untested.
**How to use:** `test.use({ walletOptions: { quirks: { noCip95: true } } })`.

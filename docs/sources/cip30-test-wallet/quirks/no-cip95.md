# noCip95

**Status:** confirmed
**Observed:** wallets without Conway support. They announce no extensions and ignore `{ cip: 95 }` in `enable()`. This is not a specific wallet's bug: it is the plain CIP-30 behaviour the spec defines for any wallet that does not implement the extension, so no wallet name or version is needed to confirm it, 2026-09.
**What the wallet does:** `supportedExtensions` is `[]`, `getExtensions()` is `[]`, the enabled api has no `cip95` namespace.
**What breaks:** DRep flows that call `api.cip95.getPubDRepKey()` without checking the namespace throw a TypeError instead of telling the user the wallet does not support governance.
**Seen in:** a governance forum repeats the same inline guard at every DRep call site and shows its own message. The guard itself was untested.
**How to use:** `test.use({ walletOptions: { quirks: { noCip95: true } } })`.

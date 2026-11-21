# cip95NamespaceMissing

**Status:** reported
**Observed:** a wallet that announces CIP-95 in `supportedExtensions` and grants it in `getExtensions()`, but never attaches the `cip95` namespace. A deliberately strict variant, not yet reproduced against a named wallet version, 2026-09.
**What the wallet does:** everything claims CIP-95, `api.cip95` is `undefined`.
**What breaks:** dApps that trust `supportedExtensions` or `getExtensions()` and skip the namespace check.
**How to use:** `test.use({ walletOptions: { quirks: { cip95NamespaceMissing: true } } })`.

# answersEveryKey

**Status:** confirmed
**Observed:** the VESPR in-app browser on iOS 18.7, 2026-09-25. `window.cardano` is a proxy. Its only own key is `vespr`, but reading any other key returns the same VESPR provider object, `nami`, `eternl`, `lace` and a random key alike. `Object.keys`, `Object.getOwnPropertyNames` and the `in` operator see only `vespr`. `enable()` through an alias key opens VESPR and returns its api.
**What the wallet does:** after install, `window.cardano` returns this wallet for every string key it does not hold. Entries it holds, other wallets included, inherited members and symbols answer as before.
**What breaks:** a dApp that probes a fixed list of known wallet keys finds this wallet once per key and lists it several times. A dApp that picks a wallet by key, for example "prefer Eternl if present", connects to a different wallet than the user sees.
**Seen in:** commitproof.com, 2026-09. The wallet picker probed nine known keys with a plain property read and showed VESPR nine times. Iterating `Object.keys(window.cardano)`, or counting a known key only when `key in window.cardano`, shows it once.
**How to use:** `test.use({ walletOptions: { quirks: { answersEveryKey: true } } })` and assert that the wallet list shows one entry. Install time only, `setQuirk` refuses it.

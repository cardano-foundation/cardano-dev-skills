# lateInjection: ms

**Status:** confirmed
**Observed:** browser extensions inject `window.cardano` asynchronously, often after the page's own scripts have run. Mobile in-app browsers inject even later. Reproduced with the demo dApp in Chromium, Firefox and WebKit, 2026-09.
**What the wallet does:** the provider appears in `window.cardano` after the configured delay. The control object is available at once.
**What breaks:** a dApp that scans `window.cardano` once shortly after load never sees the wallet and shows "no wallet installed". A dApp that rescans for a few seconds finds it.
**Seen in:** commitproof.com, 2026-09. The page scanned once after 500 ms and then stayed in its card-only mode for good. Fixed by rescanning every 250 ms for up to 3 s. The failing test reproduced in WebKit but not always in Chromium, where a slow dev server page load gave the wallet time to appear before the first scan. Run this quirk in more than one engine.
**How to use:** `test.use({ walletOptions: { quirks: { lateInjection: 800 } } })` and assert on the dApp's wallet list.

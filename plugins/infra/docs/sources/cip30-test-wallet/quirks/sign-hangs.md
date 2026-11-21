# signHangs

**Status:** confirmed
**Observed:** every wallet. The signing prompt is open and the user does nothing, switched apps, or the popup is behind another window. One of the most common support cases because dApps rarely have a timeout or a visible waiting state.
**What the wallet does:** `signTx()` does not settle until the test calls `wallet.release('signTx')` (it then signs) or `wallet.reject('signTx')` (it then fails as UserDeclined).
**What breaks:** UIs with no waiting state, double submits from impatient users, timeouts that fire while the wallet is still open.
**How to use:** `test.use({ walletOptions: { quirks: { signHangs: true } } })`, assert on the waiting state, then release or reject.

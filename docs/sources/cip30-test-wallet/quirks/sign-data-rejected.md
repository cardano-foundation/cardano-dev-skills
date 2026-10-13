# signDataRejected

**Status:** confirmed
**Observed:** every wallet. The user cancels the message signing prompt.
**What the wallet does:** `signData()` and `cip95.signData()` reject with `DataSignError` `{ code: 3, info }` (UserDeclined), a plain object. Invalid arguments are still reported first, as `APIError InvalidRequest` or `DataSignError` 1 and 2.
**What breaks:** login flows that try several address forms in a row must stop at code 3 instead of prompting the user again. Flows that read `err.message` show `undefined`.
**Seen in:** a governance forum login loop that tries the bare DRep ID and then the type 6 address stops on code 3 and moves on for every other code, 2026-09. Without this quirk that branch is untested.
**How to use:** `test.use({ walletOptions: { quirks: { signDataRejected: true } } })`, or `await wallet.setQuirk('signDataRejected', true)`.

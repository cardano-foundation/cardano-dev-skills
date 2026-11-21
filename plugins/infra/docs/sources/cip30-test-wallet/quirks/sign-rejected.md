# signRejected

**Status:** confirmed
**Observed:** every wallet. The user cancels the signing prompt.
**What the wallet does:** `signTx()` rejects with `TxSignError` `{ code: 2, info }` (UserDeclined), a plain object.
**What breaks:** flows that show a generic failure or, worse, retry automatically. The right reaction is to tell the user they declined and leave the form as it was. Read code 2 together with the call it came from: from `submitTx` it is TxSendError Failure, the node refused the transaction, so a dApp that maps codes without the call shows a send failure as a user decline.
**Seen in:** a production dApp, 2026-09. After a declined signature the commit form only said "Transaction failed", because the catch block read `err.message` from the plain object. Fixed by mapping the CIP-30 code together with the call it came from.
**How to use:** `test.use({ walletOptions: { quirks: { signRejected: true } } })`, or flip it after connecting with `await wallet.setQuirk('signRejected', true)`.

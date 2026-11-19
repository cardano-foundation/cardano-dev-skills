# cip95SignData: 'bareOnly' | 'type6Only'

**Status:** reported
**Observed:** CIP-95 lets `cip95.signData` take `Address | DRepID` without a rule for telling them apart, and wallets disagree which DRep form they sign. A governance forum's login code records that VESPR signs only the bare DRep ID and fails the CIP-19 type 6 form with a "user rejected" error. Wallets that sign only the type 6 form are implied by the same code, no version recorded, 2026-09.
**What the wallet does:** `bareOnly` rejects the type 6 address with `DataSignError` 3 (UserDeclined) and signs the bare DRep ID. `type6Only` rejects the bare DRep ID with `DataSignError` 1 (ProofGeneration) and signs the type 6 address.
**What breaks:** a dApp that sends one form only locks out half the wallets. A dApp that tries both in order must not stop at the first failure unless it is a real decline, and `bareOnly` shows why that is hard: its failure looks like a decline.
**How to use:** `test.use({ walletOptions: { quirks: { cip95SignData: 'type6Only' } } })` and assert that the dApp retried with the other form.

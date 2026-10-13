# coseAddress: 'bareKeyHash'

**Status:** reported
**Observed:** some signers put the bare 28 byte DRep key hash into the COSE `address` header instead of an address, noted with cardano-signer and CIP PR #897 in a governance forum's verifier, 2026-09.
**What the wallet does:** every DRep signature carries the bare key hash in the protected `address` header, whatever form the dApp requested.
**What breaks:** verifiers that expect a 29 byte type 6 address in the header reject a valid signature. With this quirk the header no longer equals the requested type 6 address, so a test that calls `expectSignedData` must pass the bare key hash (`wallet.drepKeyHashHex`) as `address`, or omit `address` and set `allowBareKeyHash: true`.
**How to use:** `test.use({ walletOptions: { quirks: { coseAddress: 'bareKeyHash' } } })`.

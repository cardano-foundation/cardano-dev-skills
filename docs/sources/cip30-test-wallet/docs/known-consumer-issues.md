# Known consumer issues

Bugs in a consumer SDK that surface against this wallet because it is spec-conformant, not because it misbehaves. Real wallets trip the same bug.

## Evolution SDK: `cip30Wallet(api).rewardAddress()` rejects the hex-encoded reward address CIP-30 requires

**What CIP-30 says.** The Address data type is a bech32 or hex string on input, but every value the API returns "must return the hex-encoded bytes format" (CIP-30, Data Types, Address). `getRewardAddresses()` returns `Address[]`, so its entries are hex, not bech32.

**What Evolution does.** Evolution SDK 0.5.x, `sdk/client/internal/Wallets.js`, decodes the reward address bech32 only inside `rewardAddress()`, while the neighbouring `getUsedAddresses` path already carries a bech32-then-hex fallback. Handed the hex string CIP-30 mandates, the bech32 decoder throws.

**How to reproduce with this wallet.**

```ts
import { test } from 'cip30-test-wallet/playwright';
// inside a page under test, with the CIP-30 provider installed by the fixture:
// api.getRewardAddresses() returns hex, cip30Wallet(api).rewardAddress() throws
```

Connect through Evolution's `cip30Wallet` helper against any wallet installed by this fixture (default options are enough) and call `.rewardAddress()`. It throws on the hex string this wallet, and any spec-conformant wallet, returns.

**Status.** Reported upstream: not yet.

## Evolution SDK: a declined signature hides its CIP-30 code

**What CIP-30 says.** A wallet that refuses to sign rejects `signTx` with a `TxSignError`, the plain object `{ code: 2, info }` for UserDeclined. The code is how a dApp tells a declined prompt from a failure.

**What Evolution does.** Evolution SDK 0.5.14, `sdk/client/internal/Wallets.js`, builds its error from `cause.message ?? cause`. A CIP-30 error has `info`, not `message`, so the text becomes `Failed to sign transaction: Failed to sign transaction: [object Object]`. Through `signAndSubmit` the rejection is an Effect `FiberFailure`. Its `message` and its `cause` property do not carry the code, it only survives under the symbol `Symbol.for('effect/Runtime/FiberFailure/Cause')`, in `.error.cause.cause`. Real wallets that follow CIP-30 trip the same path.

**How to reproduce with this wallet.** `test.use({ walletOptions: { quirks: { signRejected: true } } })`, then build with a client made by `withCip30(api)` and call `built.signAndSubmit()`. It rejects with the message above.

**Workaround.** Read the code through the Effect symbol with the `cip30Code` helper, or sign with the wallet directly, `api.signTx(Transaction.toCBORHex(await built.toTransaction()), false)`, which rejects with the CIP-30 object itself. Both are in the Evolution recipe in [recipes.md](recipes.md#evolution-sdk).

**Status.** Reported upstream: not yet.

## Lucid Evolution: a declined signature hides its CIP-30 code

**What Lucid does.** Lucid Evolution 0.6.5 wraps the wallet's `{ code: 2, info }` rejection of `signTx` in a `(FiberFailure) TxSignerError` whose message is `[object Object]`. The code survives under the Effect symbol, as with Evolution SDK above.

**How to reproduce with this wallet.** `test.use({ walletOptions: { quirks: { signRejected: true } } })`, select the wallet with `lucid.selectWallet.fromAPI(api)` and call `tx.sign.withWallet().complete()`.

**Workaround.** The `cip30Code` helper from the Evolution recipe, or `tx.sign.withWallet().completeSafe()`, whose `left.cause` is the CIP-30 object. See the Lucid Evolution recipe in [recipes.md](recipes.md#lucid-evolution).

**Status.** Reported upstream: not yet.

## Evolution SDK: a pool registration with a tagged owner set does not parse

**What the Conway CDDL says.** `pool_owners : set<addr_keyhash>`, and a set may be a plain array or carry tag 258. CSL emits the tagged form by default.

**What Evolution does.** Evolution SDK 0.5.13, `Transaction.fromCBORHex` and `Transaction.addVKeyWitnessesHex`, throws a `ParseError` for a transaction whose `pool_registration` certificate carries the tagged owner set. Its schema expects a plain array there. Retiring a pool, the committee certificates and every stake and DRep certificate are not affected.

**How to reproduce with this wallet.** Build a pool registration with CSL, sign it with this wallet at `partialSign: true` and merge the witness set with `Transaction.addVKeyWitnessesHex`. The merge throws before anything is submitted. The wallet itself signs the transaction correctly.

**Workaround.** Merge the witness set with CSL. Evolution's own builder is expected to emit the plain array form, which is untested here.

**Status.** Reported upstream: not yet.

## Mesh 2.0 beta: getCollateral throws when the wallet returns null

**What CIP-30 says.** `getCollateral` is typed `TransactionUnspentOutput[] | null`. A wallet that cannot cover the requested collateral returns `null`.

**What Mesh does.** `@meshsdk/wallet` 2.0.0-beta.11, `CardanoBrowserWallet.getCollateral`, calls `api.getCollateral()` without an argument and without a fallback, and `getCollateralMesh` maps over the result without a null guard. A `null` answer becomes a TypeError. Mesh core 1.9.1 guards the same result with `?? []`.

**How to reproduce with this wallet.** This wallet returns `null` when its pure ADA UTxOs cannot cover 5 ADA. Configure a wallet whose UTxOs all hold tokens, or `utxos: [{ lovelace: 1_000_000 }]`, then call getCollateral through Mesh 2.0 beta. Measured 2026-09-29 by reading the package source, not by running it.

**Workaround.** Configure at least one pure ADA UTxO of 5 ADA or more, or use Mesh core 1.9.1.

**Status.** Reported upstream: not yet.

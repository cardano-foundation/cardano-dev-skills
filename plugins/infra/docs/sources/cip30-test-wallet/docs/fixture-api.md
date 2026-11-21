# Fixture reference

`cip30-test-wallet/playwright` exports `test`, `expect`, `expectSignedBy`, `expectSignedData` and `attachWallet(page, options)`, plus the types `WalletHandle`, `WalletOptions`, `ChainOptions`, `LedgerUtxo`, `SignedDataExpectation` and `SignerRole`. `WalletHandle` and `LedgerUtxo` come from this entry only. `attachWallet` installs the wallet on a page of your own Playwright code, without the test runner, and returns the same `wallet` handle with the ledger in Node. Call it before the first navigation, once per page, and never on a page the `test` fixture already set up. The main entry `cip30-test-wallet` exports `prepareWallet`, `initScript`, `DEFAULT_MNEMONIC`, `QUIRK_NAMES`, the two assertions and the error codes with `ChwError`, plus their types. Other modules in the package are internal and can change in any release.

## `test.use({ walletOptions })`

| Option | Default | Meaning |
|---|---|---|
| `name` | `'chw'` | Key under `window.cardano` |
| `displayName` | `'Test Wallet'` | CIP-30 `name` |
| `icon` | the project logo as an SVG data URI | CIP-30 `icon` |
| `networkId` | `0` | `0` testnets, `1` mainnet. Addresses follow it |
| `mnemonic` | public CSL test vector | CIP-1852 account source. The keys end up in the page and in Playwright traces, so use a throwaway mnemonic, at most one with testnet funds for [chain mode](../README.md#chain-mode), never one that holds real funds. The default is public, anything at its addresses belongs to everyone |
| `accountIndex` | `0` | CIP-1852 account, 0 to 2^31 - 1 |
| `install` | `true` | Set `false` to skip injecting the provider. The key and address members (`name`, `addresses`, `paymentPublicKeyHex`, `stakePublicKeyHex`, `drepPublicKeyHex`, `drepKeyHashHex`, `drepId`) still work, `utxos()` still reads the ledger in Node, `calls`, `lastSubmittedTx`, `setQuirk`, `release` and `reject` reject. Read by the fixture and `attachWallet`, `init-script` refuses `false` |
| `utxos` | `[{ lovelace: 10_000_000 }]`, none with `ledger.chain` | Owned outputs, in order. Each is `{ lovelace, assets?, datumHash?, inlineDatum?, scriptRef? }`. `assets` maps units (policy id hex plus asset name hex) to quantities up to 2^64 - 1. `datumHash` is 32 bytes of hex, `inlineDatum` the CBOR hex of a `plutus_data`, set one of the two at most. `scriptRef` is the CBOR hex of the Conway CDDL `script` inside a script reference, without its tag 24 wrapper: `[0, native_script]` for a native script, `[1, bytes]`, `[2, bytes]` or `[3, bytes]` for a Plutus V1, V2 or V3 script. Ids are deterministic per name and position. Not with `ledger.chain` |
| `foreignUtxos` | `[]` | Outputs the ledger knows but does not own, for multi-party transactions. Each is `{ txId, index, addressHex, lovelace }`, the transaction id as 64 hex characters and the address as the hex of its raw bytes, plus the optional `assets`, `datumHash`, `inlineDatum` and `scriptRef` of `utxos`. A `scriptRef` here provides a reference script for script transactions, the way a UTxO holding a validator does on chain. Not with `ledger.chain` |
| `quirks` | `{}` | See the quirk catalogue |
| `stakeRegistered` | `false` | CIP-95: the starting value for whether the stake key is registered. Defaults to a fresh, unregistered wallet. Registration certificates in submitted transactions change it. Not with `ledger.chain`, the chain reports the registration |
| `ledger` | `{ state: true }` | `state: false` keeps the configured UTxOs and stake registration after `submitTx`. By default a submitted transaction spends its inputs, creates its outputs and applies stake registration certificates |
| `ledger.checks` | `false` | `true` makes `submitTx` refuse what a Conway node would refuse, with `TxSendError` Failure naming the node's rules. Not with `state: false`. See [Ledger checks](../README.md#ledger-checks) |
| `ledger.protocolParams` | preprod for `networkId` 0, mainnet for 1 | Overrides single parameters for the checks: `minFeeA`, `minFeeB`, `maxTxSize`, `maxValSize`, `keyDeposit`, `poolDeposit`, `drepDeposit`, `govActionDeposit`, `coinsPerUtxoByte`, `priceMem`, `priceSteps`, `maxTxExMem`, `maxTxExSteps`, `collateralPercent`, `maxCollateralInputs`, `minFeeRefScriptCostPerByte`, `costModels` and `protocolMajorVersion` (11). Integers as number, bigint or string, prices as `[numerator, denominator]` or a decimal such as `0.0577`. `costModels` takes `PlutusV1`, `PlutusV2` and `PlutusV3` as integer arrays the way Koios returns them, a language left out keeps its default. `protocolMajorVersion` changes only how scripts are evaluated and, from 11 on, whether the spend and reference inputs of a Plutus V3 script may overlap, the rule names stay those of protocol 11. Only with `checks` |
| `ledger.currentSlot` | none | Slot number the validity interval is checked against. Without it the validity interval is not checked. Only with `checks` |
| `ledger.drepRegistered` | `false` | The wallet's DRep key starts registered, with the DRep deposit. Only with `checks` |
| `ledger.network` | preprod for `networkId` 0, mainnet for 1 | `'mainnet'`, `'preprod'` or `'preview'`: the slot calendar that turns the validity interval into the time a Plutus script sees. `mainnet` needs `networkId` 1, the other two `networkId` 0. The protocol parameter defaults still follow `networkId`. Only with `checks` |
| `ledger.chain` | none | `{ provider: 'ogmios', url }` or `{ provider: 'koios', network, url?, token? }`, each with an optional `allowMainnetSigning`. UTxOs and stake registration come from that chain and `submitTx` submits to it, see [Chain mode](../README.md#chain-mode). With `provider: 'ogmios'` a stake key that is registered without any pool or DRep delegation reads as unregistered once its transaction is confirmed, since Ogmios 7.0.0 does not list such keys in its reward account summary. Koios is not affected. Throws together with `utxos`, `foreignUtxos`, `stakeRegistered`, `ledger.state: false`, `ledger.checks: true` or the options that only apply with the checks. Fixture and `attachWallet` only, `init-script` refuses it |

## `wallet` handle

The wallet is an automatic fixture: it is installed for every test in a file that imports this `test`, whether or not the test destructures `wallet`.

| Member | Type | Meaning |
|---|---|---|
| `name` | `string` | The `window.cardano` key |
| `addresses.payment`, `addresses.reward` | `string` | bech32 |
| `paymentPublicKeyHex`, `stakePublicKeyHex` | `string` | Raw 32-byte public keys |
| `drepPublicKeyHex`, `drepKeyHashHex` | `string` | Raw 32-byte DRep public key and its hash, both hex |
| `drepId` | `string` | CIP-129 DRep id, bech32 with prefix `drep` |
| `calls(method?)` | `Promise<JournalEntry[]>` | Journal, optionally filtered |
| `lastSubmittedTx()` | `Promise<string \| undefined>` | Hex CBOR of the last `submitTx` call on the current page that has not failed. A call still running counts as well, so wait until the submit resolved, for example for what the dApp shows afterwards, before you read it. Once it resolved, the wallet accepted the transaction, with `ledger.chain` the chain did. `undefined` after a navigation |
| `utxos()` | `Promise<LedgerUtxo[]>` | The wallet's unspent outputs after every submitted transaction of the test, in the shape of `foreignUtxos`. Kept in Node, it survives reloads and origin changes. With `ledger.chain`: the chain's outputs at the base address, with the wallet's pending transactions applied |
| `setQuirk(name, value)` | `Promise<void>` | Flip a quirk at runtime. Rejects with `InvalidRequest` for an unknown quirk name, for a `submitFails` value that is neither `true`, `false`, `undefined` nor a non-empty string, and for `lateInjection` or `answersEveryKey` after install, they only apply at install time through `walletOptions.quirks` |
| `release('signTx')`, `reject('signTx')` | `Promise<number>` | End a hanging `signTx`, resolving to how many calls it settled. Nothing pending resolves to `0` |

A `JournalEntry` is `{ method, args, result?, error?, t }`. Results of `enable` are journaled as `'[api]'`. Key material never appears in the journal. CIP-95 methods carry a `cip95.` prefix: `cip95.getPubDRepKey`, `cip95.getRegisteredPubStakeKeys`, `cip95.getUnregisteredPubStakeKeys`, `cip95.signData`.

## What lives where

The ledger lives for the test, the journal and runtime quirks live for one page load. After a navigation `wallet.utxos()` shows the updated outputs and `lastSubmittedTx()` returns `undefined`.

- **Ledger, in Node.** The wallet's outputs and stake registration after every submitted transaction are kept in the test process behind a page binding. They survive reloads, navigations and origin changes, and every document this page loads sees the same state. Popups and pages from `context.newPage()` get no wallet. The page reaches the ledger through a binding named `window.__chwLedger`, next to the control object `window.__chw`. `wallet.utxos()` reads it, also before the first navigation and with `install: false`.
- **Journal and quirks, in the page.** The journal and every `setQuirk` change are reset to the wallet's initial configuration by each navigation. Read `wallet.calls()` before navigating away from the page you want to assert on, not after.
- **A page without the binding.** If a page does not have the binding, that page keeps its own ledger and logs a `console.warn`. `wallet.utxos()` does not see the state of that page.
- **Chain mode.** With `ledger.chain` the ledger in Node keeps only the wallet's pending transactions. Everything else is read from the provider at each call, so a new test sees what earlier tests left on that chain.

## `expectSignedBy(txHex, wallet, options?)`

Throws unless `txHex` carries a vkey witness whose key is that of every role in `options.roles` (payment by default) and whose signature verifies over the transaction's body hash. Use it on `await wallet.lastSubmittedTx()`.

`options.roles` names the keys that must have signed, any of `payment`, `stake` and `drep`, default `['payment']`. An empty list is an error. A vote needs `['payment', 'drep']`, a vote delegation `['payment', 'stake']`.

## `expectSignedData(result, expected)`

Proves a `signData` or `cip95.signData` result the way a careful verifier does. `result` is `{ signature, key }`, the hex CBOR pair the wallet returns. `expected` is:

| Field | Type | Meaning |
|---|---|---|
| `payload` | `string` | Hex of the payload the dApp asked the wallet to sign |
| `address` | `string`, optional | Hex or bech32. When set, the COSE `address` header must hold exactly these bytes |
| `publicKeyHex` | `string`, optional | When set, the COSE key must be exactly this key |
| `allowBareKeyHash` | `boolean`, optional | Accept a bare 28 byte key hash in the address header without naming it in `address` |

It checks, in order: `COSE_Key` and `COSE_Sign1` decode, `alg` is EdDSA on both, the payload is unhashed and equal to `expected.payload`, the Ed25519 signature verifies over the `Sig_structure`, the key and address match `expected` when given, and the key is bound to the address in the protected header. A bare 28 byte header is taken as the key hash itself, as CIP-95 DRep signatures may carry it, but only when `address` names that hash or `allowBareKeyHash` is set. Otherwise it fails, so a CIP-30 signature that drops the address from its header cannot pass. Throws with a specific reason on any mismatch, returns `{ address, publicKey }` on success.

```ts
const [call] = await wallet.calls('signData');
expectSignedData(call!.result as { signature: string; key: string }, {
  payload: Buffer.from('demo message').toString('hex'),
  address: call!.args[0] as string,
  publicKeyHex: wallet.stakePublicKeyHex,
});
```

## Errors

CIP-30 errors are plain objects: `APIError` `{ code: -1 | -2 | -3 | -4, info }`, `TxSignError` `{ code: 1 | 2 | 3, info }`, `DataSignError` `{ code: 1 | 2 | 3, info }` (`ProofGeneration`, `AddressNotPK`, `UserDeclined`), `TxSendError` `{ code: 1 | 2, info }` (`Refused`, `Failure`) from `submitTx`, `PaginateError` `{ maxSize }`. `submitTx` rejects with TxSendError Failure when the ledger checks or, in chain mode, the chain refuse a transaction, and `info` names the node's rules, for example `ConwayApplyTxError [ConwayUtxowFailure (UtxoFailure (FeeTooSmallUTxO ...))]`. A chain refusal the wallet cannot map to a rule keeps the text of Ogmios, `Ogmios <code>: <message>`. The `submitFails` quirk rejects the same way, with `info` `the node refused the transaction` for `true` or the configured string. The wallet never raises Refused itself. Harness diagnoses are `ChwError` instances with `code` `CHW_UNRESOLVED_INPUT`, `CHW_UNRESOLVED_SCRIPT`, `CHW_UNSUPPORTED_TX_FORM`, from the ledger checks `CHW_EVALUATOR_UNAVAILABLE` when they cannot load the Plutus evaluator and `CHW_EVALUATOR_FAILED` when the evaluator stops on a transaction without a failing script, with its own message, and in chain mode `CHW_CHAIN_UNAVAILABLE` when the provider cannot be reached or answers with something unexpected, naming provider, method and HTTP status. `CHW_MAINNET_LOCKED` comes from `signTx` in chain mode on mainnet without `allowMainnetSigning`, `signData` and `submitTx` are not locked. Decoding failures become `APIError` InvalidRequest. Code 3, `DeprecatedCertificate` (CIP-95), comes for the certificates 5 and 6 that Conway removed, genesis key delegation and move instantaneous rewards, at both `partialSign` values and before any prompt quirk such as `signHangs`.

The deployed-site check lives in [doctor.md](doctor.md).

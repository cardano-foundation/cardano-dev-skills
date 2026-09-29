# Fixture reference

`cip30-test-wallet/playwright` exports `test`, `expect`, `expectSignedBy` and `expectSignedData`. The main entry `cip30-test-wallet` exports `prepareWallet`, `initScript`, `DEFAULT_MNEMONIC`, `QUIRK_NAMES`, the two assertions and the error codes with `ChwError`, plus their types. Other modules in the package are internal and can change in any release.

## `test.use({ walletOptions })`

| Option | Default | Meaning |
|---|---|---|
| `name` | `'chw'` | Key under `window.cardano` |
| `displayName` | `'Test Wallet'` | CIP-30 `name` |
| `icon` | the project logo as an SVG data URI | CIP-30 `icon` |
| `networkId` | `0` | `0` testnets, `1` mainnet. Addresses follow it |
| `mnemonic` | public CSL test vector | CIP-1852 account source. Never use a funded mnemonic, the keys end up in the page and in Playwright traces |
| `accountIndex` | `0` | CIP-1852 account, 0 to 2^31 - 1 |
| `install` | `true` | Set `false` to skip injecting the provider. `name`, `addresses`, `paymentPublicKeyHex` and `stakePublicKeyHex` still work, every other handle member rejects |
| `utxos` | `[{ lovelace: 10_000_000 }]` | Owned outputs, in order. Ids are deterministic per name and position |
| `foreignUtxos` | `[]` | Outputs the ledger knows but does not own, for multi-party transactions |
| `quirks` | `{}` | See the quirk catalogue |
| `stakeRegistered` | `false` | CIP-95: report the stake key as registered. Defaults to a fresh, unregistered wallet |

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
| `lastSubmittedTx()` | `Promise<string \| undefined>` | Hex CBOR handed to `submitTx` |
| `setQuirk(name, value)` | `Promise<void>` | Flip a quirk at runtime. Rejects with `InvalidRequest` for an unknown quirk name, and for `lateInjection` or `answersEveryKey` after install, they only apply at install time through `walletOptions.quirks` |
| `release('signTx')`, `reject('signTx')` | `Promise<number>` | End a hanging `signTx`, resolving to how many calls it settled. Nothing pending resolves to `0` |

A `JournalEntry` is `{ method, args, result?, error?, t }`. Results of `enable` are journaled as `'[api]'`. Key material never appears in the journal. CIP-95 methods carry a `cip95.` prefix: `cip95.getPubDRepKey`, `cip95.getRegisteredPubStakeKeys`, `cip95.getUnregisteredPubStakeKeys`, `cip95.signData`.

## State lives in the page

The journal and every `setQuirk` change live in the page, not in the test process. Each navigation resets both to the wallet's initial configuration. Read `wallet.calls()` before navigating away from the page you want to assert on, not after.

## `expectSignedBy(txHex, wallet)`

Throws unless `txHex` carries a vkey witness whose key is the wallet's payment key and whose signature verifies over the transaction's body hash. Use it on `await wallet.lastSubmittedTx()`.

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

CIP-30 errors are plain objects: `APIError` `{ code: -1 | -2 | -3 | -4, info }`, `TxSignError` `{ code: 1 | 2, info }`, `DataSignError` `{ code: 1 | 2 | 3, info }` (`ProofGeneration`, `AddressNotPK`, `UserDeclined`), `PaginateError` `{ maxSize }`. Harness diagnoses are `ChwError` instances with `code` `CHW_UNRESOLVED_INPUT` or `CHW_UNSUPPORTED_TX_FORM`. Decoding failures become `APIError` InvalidRequest.

The deployed-site check lives in [doctor.md](doctor.md).

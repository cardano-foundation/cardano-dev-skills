# Recipes

Complete patterns for the tasks that come up when a dApp is tested with this wallet. The library recipes and the snippets against the demo dApp ran verbatim in Chromium, Firefox and WebKit, the dApp snippets ran inside those dApps. The library recipes name the version they were tested with. Snippets that use a placeholder page such as `/checkout` are templates: their pattern ran against a real app with that app's own selectors. The dev server recipe ran against an Astro app with that app's own module and function names, and the devnet setup follows the one the package's CI runs.

## Read this first: where the wallet's funds live

The wallet's UTxOs are synthetic. They exist inside the wallet only, not on any chain. That decides how a dApp has to be wired for a test to pass:

- **Build from the wallet.** A transaction builder must take its inputs from CIP-30 `getUtxos()`. Evolution SDK, Mesh and Lucid Evolution all do that when they are connected to the CIP-30 api, see their recipes below. A builder that looks the address up at Blockfrost, Koios or a chain indexer finds nothing, coin selection fails.
- **Protocol parameters still come from the network.** Fee calculation needs them. Serve them from a recorded answer and the test runs offline, see [Protocol parameters offline](#protocol-parameters-offline).
- **Nothing reaches a chain.** The wallet's `submitTx` records the transaction, applies it to the wallet's UTxOs and returns its id. A library that submits through its own provider, or a dApp that hands the signed transaction to its backend, would send a transaction whose inputs do not exist. Intercept that request with `page.route` and check the transaction instead, see [A backend or provider that submits](#a-backend-or-provider-that-submits).
- **Chain checks cannot see synthetic funds.** A token-gated page, a balance read from an indexer or a check that an address is a registered DRep needs a wallet that really has that state on the dApp's network, passed in through `walletOptions.mnemonic`. See [Pages behind a wallet login](../README.md#pages-behind-a-wallet-login).

All of this holds for the default ledger. In chain mode, with `walletOptions.ledger.chain`, the wallet's UTxOs are real chain UTxOs and `submitTx` submits, so a builder that asks an indexer and a backend that submits work as in production, see [Testing against a local devnet](#testing-against-a-local-devnet).

## Serving a test page on a fake origin

The recipes serve a bundled dApp on `https://dapp.test/` with `page.route`, so no dev server is needed. Against your own app use its dev server or deployed URL instead, the wallet is installed the same way.

Wait for something the app renders after its code has run before you click. A bundle with WebAssembly, as Lucid Evolution produces, can take a few seconds to start in Firefox, and a click on a button that is already in the static HTML is lost in that time.

```ts
import { readFileSync } from 'node:fs';
import type { Page } from '@playwright/test';

const html = readFileSync('dapp/index.html', 'utf8');
const app = readFileSync('dapp/app.js', 'utf8');

export async function serve(page: Page) {
  await page.route('https://dapp.test/**', (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path === '/app.js') return route.fulfill({ contentType: 'text/javascript', body: app });
    return route.fulfill({ contentType: 'text/html', body: html });
  });
  await page.goto('https://dapp.test/');
}
```

## Bundling a dApp for the test page

Only needed for a test page like the one above. Your own app's bundler already produces what its pages load. These are the builds the recipes were tested with, esbuild 0.28:

- **Evolution SDK:** a plain bundle, `npx esbuild dapp/app.ts --bundle --format=iife --platform=browser --outfile=dapp/app.js`.
- **Mesh:** needs polyfills for Node's `Buffer` and `process`, through `esbuild-plugins-node-modules-polyfill` 1.8.
- **Lucid Evolution:** the same polyfills plus its WebAssembly, embedded with `esbuild-plugin-wasm` 1.1.

```js
// build.mjs, for Lucid Evolution. For Mesh drop wasmLoader.
import { build } from 'esbuild';
import { nodeModulesPolyfillPlugin } from 'esbuild-plugins-node-modules-polyfill';
import { wasmLoader } from 'esbuild-plugin-wasm';

await build({
  entryPoints: ['dapp/app.ts'],
  outfile: 'dapp/app.js',
  bundle: true,
  platform: 'browser',
  format: 'esm',
  target: 'es2022',
  plugins: [nodeModulesPolyfillPlugin({ globals: { Buffer: true, process: true } }), wasmLoader({ mode: 'embedded' })],
});
```

An ESM bundle loads with `<script type="module" src="/app.js"></script>`.

## Evolution SDK

Tested with `@evolution-sdk/evolution` 0.5.14. The package's own tests use 0.6.0.

A client built with `withCip30(api)` takes its UTxOs from the wallet's `getUtxos()`, no `availableUtxos` option needed. It asks Koios only for protocol parameters (`epoch_params`). It always signs with `signTx(tx, true)`, a partial signature.

```ts
// dApp side
import { Address, Assets, Client, preprod, TransactionHash } from '@evolution-sdk/evolution';

const api = await (window as any).cardano[walletName].enable();
if ((await api.getNetworkId()) !== 0) throw new Error('wrong network: switch your wallet to preprod');

const client = Client.make(preprod).withKoios({ baseUrl: 'https://preprod.koios.rest/api/v1' }).withCip30(api);
const built = await client
  .newTx()
  .payToAddress({ address: Address.fromBech32(recipient), assets: Assets.fromLovelace(5_000_000n) })
  .build();
const txHash = TransactionHash.toHex(await built.signAndSubmit());
```

`signAndSubmit` submits through the provider, Koios here, never through the wallet's `submitTx`. In a test that request has to be intercepted:

```ts
import { test, expect, expectSignedBy } from 'cip30-test-wallet/playwright';

test.use({ walletOptions: { name: 'eternl', networkId: 0, utxos: [{ lovelace: 50_000_000 }, { lovelace: 3_000_000 }] } });

test('pays 5 ADA with a transaction the wallet really signed', async ({ page, wallet }) => {
  await stubProtocolParameters(page); // see "Protocol parameters offline"
  let submitted: string | undefined;
  await page.route('https://preprod.koios.rest/api/v1/submittx', async (route) => {
    submitted = route.request().postDataBuffer()!.toString('hex');
    await route.fulfill({
      contentType: 'application/json',
      headers: { 'access-control-allow-origin': '*' },
      body: JSON.stringify('cd'.repeat(32)),
    });
  });
  await serve(page);
  await page.getByRole('button', { name: 'Pay', exact: true }).click();
  await expect(page.locator('#result')).toHaveText('submitted ' + 'cd'.repeat(32));

  expect((await wallet.calls('signTx'))[0]!.args[1]).toBe(true);
  expectSignedBy(submitted!, wallet);
});
```

When the user declines, `sign` and `signAndSubmit` reject with an Effect `FiberFailure` whose message ends in `[object Object]`, see [known consumer issues](known-consumer-issues.md#evolution-sdk-a-declined-signature-hides-its-cip-30-code). The CIP-30 code is still inside, under an Effect symbol. Sign and submit in two steps, so the code is only read for the signing call: code 2 means UserDeclined from `signTx` but TxSendError Failure from `submitTx`.

```ts
// The CIP-30 code of a wallet error, also inside an Effect FiberFailure.
function cip30Code(e: any): number | undefined {
  const failure = e?.[Symbol.for('effect/Runtime/FiberFailure/Cause')]?.error;
  for (let c = failure ?? e; c; c = c.cause) if (typeof c.code === 'number') return c.code;
  return undefined;
}

let signed;
try {
  signed = await built.sign();
} catch (e) {
  if (cip30Code(e) === 2) return showMessage('You declined the signature in your wallet.');
  throw e;
}
// A failed submit is a failure, never a decline.
const txHash = TransactionHash.toHex(await signed.submit());
```

Or sign with the wallet directly, then the rejection is the CIP-30 object itself:

```ts
import { Transaction } from '@evolution-sdk/evolution';

const unsigned = Transaction.toCBORHex(await built.toTransaction());
let witnessSet: string;
try {
  witnessSet = await api.signTx(unsigned, false);
} catch (e) {
  if ((e as { code?: unknown } | null)?.code === 2) return showMessage('You declined the signature in your wallet.');
  throw e;
}
const signed = Transaction.addVKeyWitnessesHex(unsigned, witnessSet);
// Hand `signed` to api.submitTx or to your backend. A code 2 from submitTx is TxSendError Failure, the node refused the transaction.
```

## Mesh

Tested with `@meshsdk/core` 1.9.1.

`BrowserWallet.getUtxos()` reads the wallet over CIP-30, but `MeshTxBuilder` does not find the wallet on its own: pass the UTxOs with `selectUtxosFrom`. Mesh needs no chain data for a payment, without `params` it calculates with built-in protocol parameters. Pass current ones through `new MeshTxBuilder({ params })` when the fee has to match the network. Mesh submits through the wallet's `submitTx`, so `wallet.lastSubmittedTx()` holds the transaction.

```ts
// dApp side
import { BrowserWallet, MeshTxBuilder } from '@meshsdk/core';

const wallet = await BrowserWallet.enable(walletName);
const builder = new MeshTxBuilder();
builder
  .txOut(recipient, [{ unit: 'lovelace', quantity: '5000000' }])
  .changeAddress(await wallet.getChangeAddress())
  .selectUtxosFrom(await wallet.getUtxos());
const unsigned = await builder.complete();
const signed = await wallet.signTx(unsigned);
const txHash = await wallet.submitTx(signed);
```

```ts
test('pays 5 ADA with Mesh', async ({ page, wallet }) => {
  await serve(page);
  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText(/submitted [0-9a-f]{64}/)).toBeVisible();

  expectSignedBy((await wallet.lastSubmittedTx())!, wallet);
});
```

A declined signature reaches the dApp as the CIP-30 object `{ code: 2, info }` from `wallet.signTx`. Code 2 from `wallet.submitTx` is TxSendError Failure, the node refused the transaction, so map the code together with the call it came from. The browser bundle needs polyfills for Node's `Buffer` and `process`, a bundler plugin for Node built-ins covers both.

## Lucid Evolution

Tested with `@lucid-evolution/lucid` 0.6.5.

`selectWallet.fromAPI(api)` takes the UTxOs from the wallet. `Lucid(new Koios(...), 'Preprod')` loads protocol parameters once at start, from `epoch_params?limit=1`, which the stub in [Protocol parameters offline](#protocol-parameters-offline) answers. Lucid signs with `signTx(tx, true)` and submits through the wallet's `submitTx`.

```ts
// dApp side
import { Koios, Lucid } from '@lucid-evolution/lucid';

const api = await (window as any).cardano[walletName].enable();
const lucid = await Lucid(new Koios('https://preprod.koios.rest/api/v1'), 'Preprod');
lucid.selectWallet.fromAPI(api);
const tx = await lucid.newTx().pay.ToAddress(recipient, { lovelace: 5_000_000n }).complete();
const signed = await tx.sign.withWallet().complete();
const txHash = await signed.submit();
```

```ts
test('pays 5 ADA with Lucid Evolution', async ({ page, wallet }) => {
  await stubProtocolParameters(page);
  await serve(page);
  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText(/submitted [0-9a-f]{64}/)).toBeVisible();

  expect((await wallet.calls('signTx'))[0]!.args[1]).toBe(true);
  expectSignedBy((await wallet.lastSubmittedTx())!, wallet);
});
```

A declined signature becomes a `(FiberFailure) TxSignerError` with the message `[object Object]`, the same wrapping as in Evolution SDK. The `cip30Code` helper from the Evolution recipe reads the code from it. Alternatively `tx.sign.withWallet().completeSafe()` returns the failure instead of throwing, its `left.cause` is the CIP-30 object. Read the code only around the signing call: `signed.submit()` goes through the wallet's `submitTx`, where code 2 is TxSendError Failure. The browser bundle embeds WebAssembly and needs polyfills for Node built-ins. A page with a Content Security Policy has to allow `'wasm-unsafe-eval'` in `script-src`, plain `'unsafe-eval'` is not needed.

## Protocol parameters offline

Record the answer once and serve it from a file. For Koios preprod:

```bash
curl -s "https://preprod.koios.rest/api/v1/epoch_params?limit=1&order=epoch_no.desc" -o fixtures/koios-epoch-params.json
```

```ts
import { readFileSync } from 'node:fs';
import type { Page } from '@playwright/test';

const epochParams = readFileSync('fixtures/koios-epoch-params.json', 'utf8');

export async function stubProtocolParameters(page: Page) {
  // Playwright tries the most recently added route first, so the catch-all goes in first.
  // Any other Koios call means the builder looked for chain data it cannot find.
  await page.route('https://preprod.koios.rest/**', (route) => route.abort());
  await page.route('https://preprod.koios.rest/api/v1/epoch_params*', (route) =>
    route.fulfill({
      contentType: 'application/json',
      // The dApp runs on another origin, without this header the browser drops the answer.
      headers: { 'access-control-allow-origin': '*' },
      body: epochParams,
    }),
  );
}
```

Two details decide whether this works: the order of the two routes, and the CORS header. A missing header shows up in the dApp as a failed protocol parameter request. Record the file again when the network's parameters change. Builders read more than the fee from it, minimum output values, size limits and deposits among them, so a stale file can change the transaction or make the build fail.

If the app goes through its own proxy, as many do because Koios sends no CORS headers, route the proxy path instead, for example `**/api/koios/**`.

## A backend or provider that submits

Whatever submits the signed transaction, intercept that request, keep the transaction and prove the signature on it. Nothing leaves the test, unless the test runs in chain mode.

```ts
test('the backend receives a transaction the wallet really signed', async ({ page, wallet }) => {
  let submitted: string | undefined;
  await page.route('**/api/submit', async (route) => {
    submitted = route.request().postDataJSON().tx;
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ txHash: 'ab'.repeat(32) }) });
  });
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText('ab'.repeat(32))).toBeVisible();

  expectSignedBy(submitted!, wallet);
  expect(await wallet.calls('submitTx')).toHaveLength(0);
});
```

For a provider that posts raw CBOR (Koios `submittx`, Blockfrost `tx/submit`) read the body with `route.request().postDataBuffer()!.toString('hex')`, as in the Evolution recipe.

## User-side failures

Each quirk reproduces one thing a real user or wallet does. The wallet answers with the error a real wallet sends, and the test checks what the dApp tells the user.

| The user... | walletOptions | What the dApp receives |
|---|---|---|
| declines the connection | `quirks: { enableRejected: true }` | `enable()` rejects with `{ code: -3 }` (APIError Refused) |
| declines the signature | `quirks: { signRejected: true }` | `signTx` rejects with `{ code: 2 }` (TxSignError UserDeclined) |
| declines to sign a message | `quirks: { signDataRejected: true }` | `signData` rejects with `{ code: 3 }` (DataSignError UserDeclined) |
| sends a transaction the node refuses | `quirks: { submitFails: true }` | `submitTx` rejects with `{ code: 2 }` (TxSendError Failure), the same code a declined signature has. A string in place of `true` becomes the `info` |
| never answers the signature prompt | `quirks: { signHangs: true }` | `signTx` stays pending until the test calls `wallet.release('signTx')` or `wallet.reject('signTx')` |
| has the wallet on the other network | `networkId: 1` (dApp on a testnet) | `getNetworkId()` returns 1, addresses are mainnet addresses |
| has a wallet that injects late | `quirks: { lateInjection: 1500 }` | `window.cardano[name]` appears after 1.5 seconds |
| has a wallet without CIP-95 | `quirks: { noCip95: true }` | `supportedExtensions` is empty, `enable({ extensions: [{ cip: 95 }] })` grants nothing |

Every switch has a note with where it was observed in [quirks/README.md](../quirks/README.md).

```ts
test.describe('the user never answers the wallet', () => {
  test.use({ walletOptions: { quirks: { signHangs: true } } });

  test('the page waits, then reports the decline', async ({ page, wallet }) => {
    await page.goto('/checkout');
    await page.getByRole('button', { name: 'Pay' }).click();
    await expect(page.getByText('Waiting for your wallet')).toBeVisible();
    await wallet.reject('signTx');
    await expect(page.getByText('You declined the signature')).toBeVisible();
  });
});
```

## Vote as a DRep

A vote is signed with the DRep key, so the test proves the payment and the DRep signature. The demo dApp only needs the wallet to have a DRep key, the default mnemonic works.

```ts
test('a DRep vote is signed with the payment and the DRep key', async ({ page, wallet }) => {
  await page.goto('/strict/');
  await expect(page.locator('#wallets')).toHaveText('chw');
  await page.locator('#connect').click();
  await expect(page.locator('#connect-result')).toHaveText('network 0');
  await page.locator('#vote').click();
  await expect(page.locator('#vote-result')).toHaveText(/^submitted [0-9a-f]{64}$/);
  expectSignedBy((await wallet.lastSubmittedTx())!, wallet, { roles: ['payment', 'drep'] });
});
```

A dApp that checks the DRep on chain needs a testnet wallet registered as DRep. Pass its mnemonic through an environment variable and skip the test when it is missing, as in [Pages behind a wallet login](../README.md#pages-behind-a-wallet-login). For a vote delegation use `{ roles: ['payment', 'stake'] }`.

## A wallet that holds a token

Give the wallet a UTxO with a token and read it back through the demo's Balance button. The unit is the policy id hex followed by the asset name hex.

```ts
const POLICY = 'ab'.repeat(28);

test.use({ walletOptions: { utxos: [{ lovelace: 10_000_000, assets: { [POLICY + '41']: 1 } }] } });

test('the wallet holds one token kind', async ({ page }) => {
  await page.goto('/strict/');
  await expect(page.locator('#wallets')).toHaveText('chw');
  await page.locator('#connect').click();
  await expect(page.locator('#connect-result')).toHaveText('network 0');
  await page.locator('#balance').click();
  await expect(page.locator('#balance-result')).toHaveText('10000000 lovelace, 1 token kind');
});
```

A page that checks token ownership on chain, through an indexer or its backend, does not see the synthetic UTxOs by default, in chain mode the UTxOs are real. A page that reads `getBalance` or `getUtxos` in the browser does. See [Pages behind a wallet login](../README.md#pages-behind-a-wallet-login).

## Reading the wallet's UTxOs after a submit

A submitted transaction spends its inputs and creates its outputs. `wallet.utxos()` reads the result from the test process, so it is still there after a reload or a change of origin. The commit button of the demo dApp spends UTxO 0 and pays back to the wallet:

```ts
import type { Page } from '@playwright/test';
import { expect, test } from 'cip30-test-wallet/playwright';

async function connect(page: Page, url = '/strict/') {
  await page.goto(url);
  await expect(page.locator('#wallets')).toHaveText('chw');
  await page.locator('#connect').click();
  await expect(page.locator('#connect-result')).toHaveText('network 0');
}

async function commit(page: Page): Promise<string> {
  await page.locator('#commit').click();
  await expect(page.locator('#commit-result')).toHaveText(/^submitted [0-9a-f]{64}$/);
  return (await page.locator('#commit-result').textContent())!.replace('submitted ', '');
}

test('the commit spends UTxO 0 and pays back to the wallet', async ({ page, wallet }) => {
  await connect(page);
  const id = await commit(page);
  const utxos = await wallet.utxos();
  expect(utxos).toHaveLength(1);
  expect(utxos[0]!.txId).toBe(id);
});
```

`test.use({ walletOptions: { ledger: { state: false } } })` keeps the configured UTxOs and stake registration, as before 0.8.0.

## Seeing the node's rejection offline

A node refuses a transaction whose fee is too low, whose inputs are gone or whose value does not balance, and a dApp has to show that to the user. With `ledger: { checks: true }` the wallet refuses such a transaction the same way, as `{ code: 2, info }` with the node's rule names in `info`. The dApp's builder computes its fee from the parameters it fetched, the wallet checks against its own. Raising `minFeeB` for the wallet reproduces a fee a node would refuse without touching the dApp:

```ts
test.use({ walletOptions: { ledger: { checks: true, protocolParams: { minFeeB: 1_000_000 } } } });

test('the dApp shows the node rejection of a fee that is too low', async ({ page, wallet }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Connect' }).click();
  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText(/FeeTooSmallUTxO/)).toBeVisible(); // whatever your app shows for a refused submit

  const [call] = await wallet.calls('submitTx');
  expect(call!.error).toMatchObject({ code: 2, info: expect.stringContaining('FeeTooSmallUTxO') });
  expect(await wallet.lastSubmittedTx()).toBeUndefined();
});
```

The wallet's UTxOs stay as they were, a corrected transaction over the same inputs goes through afterwards. For a rejection without a failing transaction, `quirks: { submitFails: 'ConwayApplyTxError [...]' }` answers every `submitTx` with that string as `info`, see [User-side failures](#user-side-failures).

## A dApp that spends from a script

A dApp that spends from a contract builds the transaction from chain data. The wallet has to know every input it cannot find in its own UTxOs: the UTxO the contract locks and, when the validator is used as a reference script, the UTxO holding it. Without them `signTx` raises `CHW_UNRESOLVED_INPUT`. A dApp that attaches the validator to the transaction itself needs only the locked UTxO. In [chain mode](../README.md#chain-mode) the wallet reads both from the chain and refuses `foreignUtxos`, the fragment below is for the default ledger.

```ts
// The validator is an always succeeding Plutus V3 script compiled with aiken, its hash 5d0f74...02078e3 makes the script address.
test.use({
  walletOptions: {
    foreignUtxos: [
      { txId: 'aa'.repeat(32), index: 0, addressHex: '705d0f747d4eb70739ff667eed99b934de3a3e5054fae1e368902078e3', lovelace: 5_000_000, inlineDatum: 'd87980' },
      { txId: 'bb'.repeat(32), index: 0, addressHex: '705d0f747d4eb70739ff667eed99b934de3a3e5054fae1e368902078e3', lovelace: 20_000_000, scriptRef: '8203585e585c01010029800aba2aba1aab9eaab9dab9a4888896600264653001300600198031803800cc0180092225980099b8748008c01cdd500144c8cc892898050009805180580098041baa0028a51401830060013003375400d149a26cac8009' },
    ],
  },
});
```

This fragment only configures the wallet. A unit test checks that it is accepted and that the reference script hash matches the script address.

The wallet signs for the collateral and every key the transaction needs from it. `signTx` never runs the validator. With `ledger: { checks: true }` `submitTx` runs it in Node, within the ExUnits its redeemer declares. A validator that fails or needs more than that is refused as `ValidationTagMismatch`, a script data hash that does not match as `ScriptIntegrityHashMismatch`, see [Ledger checks](../README.md#ledger-checks). Without the checks and without a chain, a redeemer or budget that a node would reject passes here. In [chain mode](../README.md#chain-mode) the node runs the validator.

## Testing against a local devnet

A dApp whose backend reads the chain, or a flow that has to be confirmed, needs real UTxOs. `@evolution-sdk/devnet` runs a cardano-node with Ogmios in Docker, its genesis funds the wallet, and `ledger.chain` points the wallet at it. Install it with its peers, exact versions:

```bash
npm install --save-dev --save-exact @evolution-sdk/devnet@3.0.21 @evolution-sdk/evolution@0.6.0 @evolution-sdk/scalus-uplc@2.0.20 @evolution-sdk/aiken-uplc@2.0.20
```

A global setup starts the devnet once per run, on protocol 11 with cardano-node 11.0.1 and Ogmios 7.0.0 and a block every second, and funds accounts 0 to 3 of the test mnemonic with 10,000 ADA each. Two settings are needed that the devnet package does not set itself for node 11, the P2P topology and `ExperimentalHardForksEnabled: false`:

```ts
// devnet-setup.ts, globalSetup in playwright.config.ts
import { execFileSync } from 'node:child_process';
import { rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { Cluster, Config } from '@evolution-sdk/devnet';
import { Address } from '@evolution-sdk/evolution';
import { prepareWallet } from 'cip30-test-wallet';

export default async function devnetSetup() {
  const name = 'dapp-devnet';
  const now = Math.floor(Date.now() / 1000);
  const shelley = Config.DEFAULT_SHELLEY_GENESIS;
  const funds = Object.fromEntries(
    [0, 1, 2, 3].map((accountIndex) => [Address.toHex(Address.fromBech32(prepareWallet({ accountIndex }).addresses.payment)), 10_000_000_000]),
  );
  const cluster = await Cluster.make({
    clusterName: name,
    image: 'ghcr.io/intersectmbo/cardano-node:11.0.1',
    ogmios: { image: 'cardanosolutions/ogmios:v7.0.0' },
    kupo: { enabled: false },
    nodeConfig: { ExperimentalHardForksEnabled: false },
    byronGenesis: { ...Config.DEFAULT_BYRON_GENESIS, startTime: now },
    shelleyGenesis: {
      ...shelley,
      systemStart: new Date(now * 1000).toISOString(),
      slotLength: 1,
      initialFunds: { ...shelley.initialFunds, ...funds },
      protocolParams: { ...shelley.protocolParams, protocolVersion: { major: 11, minor: 0 } },
    },
  });
  // cardano-node 11 reads only the P2P topology format.
  const [node] = JSON.parse(execFileSync('docker', ['inspect', cluster.cardanoNode.id], { encoding: 'utf8' }));
  const configDir: string = node.Mounts.find((m: { Destination: string }) => m.Destination === '/opt/cardano/config').Source;
  writeFileSync(join(configDir, 'topology.json'), JSON.stringify({ localRoots: [], publicRoots: [], useLedgerAfterSlot: -1 }));
  await Cluster.start(cluster);

  const url = `http://127.0.0.1:${cluster.ports.ogmios}`;
  for (let attempt = 0; ; attempt++) {
    const tip = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', method: 'queryNetwork/tip' }) })
      .then((response) => response.json())
      .catch(() => undefined);
    if (tip?.result?.slot > 0) break;
    if (attempt === 300) throw new Error('the devnet produced no block');
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  process.env.DEVNET_OGMIOS = url;

  return async () => {
    await Cluster.remove(cluster);
    execFileSync('docker', ['volume', 'rm', `${name}-ipc`]);
    rmSync(configDir, { recursive: true, force: true });
  };
}
```

The devnet has its own protocol parameters, its cost models differ from mainnet and preprod. A dApp that hardcodes parameters or cost models has to read them from the devnet, through Ogmios `queryLedgerState/protocolParameters`. Each test file takes its own account, so files can run in parallel without spending each other's UTxOs. With `fullyParallel: true` the tests inside one file run in parallel as well and share its account, so a file whose tests spend runs them in order:

```ts
import { expect, expectSignedBy, test } from 'cip30-test-wallet/playwright';

test.use({ walletOptions: { accountIndex: 1, ledger: { chain: { provider: 'ogmios', url: process.env.DEVNET_OGMIOS! } } } });
test.describe.configure({ mode: 'serial' });

test('the payment is submitted to the devnet', async ({ page, wallet }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Connect' }).click();
  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText('Payment sent')).toBeVisible(); // whatever your app shows after the submit

  const tx = (await wallet.lastSubmittedTx())!;
  expectSignedBy(tx, wallet);
  // The wallet shows the change at once, the chain after the next block, about a second later.
  expect((await wallet.utxos()).length).toBeGreaterThan(0);
});
```

The package's own CI runs a setup like this one, its browser test pays from chain UTxOs on the demo dApp in three engines and checks the balance before and after the block.

## Reading the journal

`wallet.calls()` lists every CIP-30 call of the current page in order, with arguments and result or error. It answers questions a screenshot cannot: did the dApp check the network before building, did it ask for a partial signature, did it retry.

```ts
test('connect checks the network before it reads addresses', async ({ page, wallet }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Connect' }).click();
  await expect(page.getByText('Connected')).toBeVisible();

  const methods = (await wallet.calls()).map((e) => e.method);
  expect(methods).toContain('getNetworkId');
  expect(methods).toContain('getUsedAddresses');
  expect(methods.indexOf('getNetworkId')).toBeLessThan(methods.indexOf('getUsedAddresses'));
  expect(await wallet.calls('signTx')).toHaveLength(0);
});
```

The journal lives in the page and starts empty after every navigation, see [fixture-api.md](fixture-api.md#what-lives-where). Read it before the dApp navigates away, or hold the navigation with `page.route` as the login recipe does.

## Testing a wallet module directly on a dev server

A dev server built on Vite (Vite, Astro, SvelteKit, Nuxt) serves source modules by path. A test can import the dApp's own wallet module in the page and call it, without clicking through a page that sits behind a login:

```ts
test.use({ walletOptions: { name: 'eternl', networkId: 0, utxos: [{ lovelace: 50_000_000 }] } });

test('the wallet connector connects and builds a signed payment', async ({ page, wallet }) => {
  await page.goto('/');
  // The path is resolved by the dev server in the page, pass it in as a value.
  const result = await page.evaluate(async (modulePath) => {
    const mod = await import(modulePath);
    const connected = await mod.connectWallet('eternl', 0);
    const signed = await mod.buildPaymentTx('eternl', 'addr_test1...', 5_000_000);
    return { connected, signed };
  }, '/src/lib/wallet-connector.ts');
  expect(result.connected.networkId).toBe(0);
  expectSignedBy(result.signed, wallet);
});
```

Module path and function names are the app's own. Any request the module makes to a session-protected route, a chain proxy for example, can be served with `page.route` as above.

## Signing in with a message

A `signData` login usually ends in a navigation, and a navigation empties the journal. Hold the verify request, read the signature while the login page is still there, then let the request through:

```ts
import { test, expect, expectSignedData } from 'cip30-test-wallet/playwright';
import type { JournalEntry } from 'cip30-test-wallet';

test('signs in with a message the wallet really signed', async ({ page, wallet }) => {
  let signData: JournalEntry[] = [];
  await page.route('**/api/auth/verify', async (route) => {
    signData = await wallet.calls('signData');
    await route.fallback();
  });
  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with wallet' }).click();
  await page.waitForURL('**/home/');

  const [call] = signData;
  expect(call).toBeDefined();
  expectSignedData(call!.result as { signature: string; key: string }, {
    payload: call!.args[1] as string,
    address: call!.args[0] as string,
  });
});
```

`route.fallback()` hands the request on to the app's real backend, or to another route the test registered earlier. To log in once per role and reuse the session, see [Pages behind a wallet login](../README.md#pages-behind-a-wallet-login). The checks `expectSignedData` runs are in [fixture-api.md](fixture-api.md#expectsigneddataresult-expected).

## Without the test runner

An agent that drives a browser through Playwright MCP, or any code that is not a Playwright test, loads the wallet from a script file. See [init-script.md](init-script.md).

## Running inside an agent sandbox

On macOS a coding agent's sandbox keeps every Playwright browser from starting. Under Codex with `--sandbox workspace-write` or `read-only`, Chromium, Firefox and WebKit abort at launch because they cannot register with the window server. Playwright reports only that the browser closed, and macOS opens a "quit unexpectedly" dialog for each abort, so a test run with retries and workers can stack dozens of them. No launch flag or environment variable avoids it. Outside the sandbox all three engines run normally.

Playwright tests that start a browser, and `doctor --deep`, therefore run outside the sandbox: in the developer's own terminal, or as a single command the developer approves when the agent asks for it. Writing tests, tests that start no browser and a static `doctor` run work inside the sandbox. `doctor --deep` reads `CODEX_SANDBOX=seatbelt`, which Codex sets for sandboxed commands, and stops before it launches a browser. When a browser fails to start on macOS anyway, doctor adds the likely cause to Playwright's message.

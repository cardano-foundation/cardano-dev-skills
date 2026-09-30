<img src="https://raw.githubusercontent.com/Lichtstaub/cip30-test-wallet/main/media/logo.svg" width="96" height="96" alt="cip30-test-wallet logo: a wallet between code braces">

# cip30-test-wallet

[![CI](https://github.com/Lichtstaub/cip30-test-wallet/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Lichtstaub/cip30-test-wallet/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/cip30-test-wallet)](https://www.npmjs.com/package/cip30-test-wallet)
[![node](https://img.shields.io/node/v/cip30-test-wallet)](https://github.com/Lichtstaub/cip30-test-wallet/blob/main/package.json)

`cip30-test-wallet` reproduces real Cardano wallet failures in automated browser tests, with no node, faucet, extension, or shared chain state.

It injects a CIP-30 test wallet into the page under test. The wallet holds real keys, returns real UTxO CBOR, signs real transaction CBOR with a real Ed25519 signature, and records every call in a journal your test can read. A catalogue of quirks reproduces the failures that only show up on a user's machine: a wallet on the wrong network, a wallet that injects late, a user who declines or never answers.

![A Playwright test in the trace viewer: the test connects the demo dApp to the injected wallet, commits, and proves the submitted transaction carries the wallet's signature](https://raw.githubusercontent.com/Lichtstaub/cip30-test-wallet/main/media/trace-viewer.png)

A Playwright test in the trace viewer. The wallet is detected, connects on preprod and signs the commit transaction without a popup, and `expectSignedBy` proves the submitted transaction carries its signature.

**Status: 0.x.** The signing core, the Playwright fixture and the `doctor` command are covered by unit tests and by browser tests in Chromium, Firefox and WebKit, and they run in the end-to-end suites of real dApps. Until 1.0 a minor release can still change the API, the notes of each GitHub release say what changed.

Coding agents start with [AGENTS.md](https://github.com/Lichtstaub/cip30-test-wallet/blob/main/AGENTS.md).

## What is in the box

- A CIP-30 provider for the page: `apiVersion`, `name`, `icon`, `supportedExtensions`, `enable`, `isEnabled`, and the api methods `getNetworkId`, `getUtxos` (with `amount` and `paginate`), `getBalance` (with native assets), `getCollateral`, `experimental.getCollateral`, `getUsedAddresses`, `getUnusedAddresses`, `getChangeAddress`, `getRewardAddresses`, `getExtensions`, `signTx`, `submitTx`, `signData`.
- The `cip95` namespace: `getPubDRepKey`, `getRegisteredPubStakeKeys`, `getUnregisteredPubStakeKeys`, `signData`.
- A Playwright fixture: `test.use({ walletOptions })` configures the wallet, `wallet` in the test reads the journal and flips quirks at runtime.
- `expectSignedBy(txHex, wallet, { roles? })`: proves the transaction your dApp submitted really carries the wallet's signature (payment by default, optionally stake and DRep) over its body hash. Recording `submitTx` alone proves nothing.
- `expectSignedData(result, expected)`: proves a `signData` or `cip95.signData` result the way a careful verifier does, checking the COSE signature, key and address.
- The quirk catalogue in [`quirks/`](quirks/README.md), a provenance note for every switch.
- `doctor`: a command line check of a deployed dApp for the secure-context and content-security-policy traps, with a browser mode that measures wallet detection.

`signData` follows CIP-30 and CIP-8 byte for byte with Emurgo's message-signing library: payment key for base, pointer and enterprise addresses, stake key for reward addresses. CIP-95 is announced by default: `getPubDRepKey`, the registered and unregistered stake keys, and `cip95.signData` with the bare DRep ID or a type 6 address. `signTx` signs Conway governance transactions: stake and vote delegation certificates with the stake key, DRep registration, update and retirement and DRep votes with the DRep key. Pool and committee certificates are never witnessed by the wallet, as CIP-95 requires. Pre-Conway certificates are refused with `TxSignError` `DeprecatedCertificate` (3).

## Not in the box yet

This release is a CIP-30 subset for transaction tests plus CIP-95, including governance transactions. Missing on purpose, tracked for later milestones: script inputs, script credentials in certificates and votes, guardrail scripts in proposals, and every transaction form outside the supported set below. `submitTx` is simulated: it records the transaction and returns its id, it never talks to a node. Fees, validity and script execution are not checked.

## Getting started

You have a dApp with a wallet connect and want its wallet flows under test. Each step below stands on its own, stop wherever the coverage is enough.

### 1. Install and point Playwright at your app

```bash
npm install --save-dev cip30-test-wallet @playwright/test
npx playwright install chromium
```

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: 'tests',
  use: { baseURL: 'http://localhost:5173' },
  webServer: { command: 'npm run dev', url: 'http://localhost:5173', reuseExistingServer: !process.env.CI },
});
```

Use your dev server's command and port. A deployed URL works as `baseURL` too, without `webServer`.

### 2. Connect

```ts
// tests/connect.spec.ts
import { test, expect } from 'cip30-test-wallet/playwright';

test.use({ walletOptions: { name: 'eternl', networkId: 0 } });

test('connects to the wallet', async ({ page, wallet }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Connect' }).click();
  await expect(page.getByText('Connected')).toBeVisible(); // whatever your app shows after a connect

  expect(await wallet.calls('enable')).toHaveLength(1);
});
```

Import `test` and `expect` from `cip30-test-wallet/playwright`, not from `@playwright/test`. `name` is the key under `window.cardano`. Use one your dApp lists, many dApps only offer wallets they know. `networkId` is `0` for a testnet dApp and `1` for mainnet. This test needs no chain, no funds and no transaction builder.

### 3. What your users do to it

The failures users report and nobody can reproduce on a developer machine. Each is one line of `walletOptions`:

```ts
test.use({ walletOptions: { networkId: 1 } });                        // wallet on mainnet, your dApp expects preprod
test.use({ walletOptions: { quirks: { enableRejected: true } } });    // the user declines the connection
test.use({ walletOptions: { quirks: { lateInjection: 1500 } } });     // the wallet appears after 1.5 seconds
test.use({ walletOptions: { quirks: { signRejected: true } } });      // the user declines the signature
```

A user who never answers the signing prompt, answered by the test when your assertion is done:

```ts
test.use({ walletOptions: { quirks: { signHangs: true } } });
await page.getByRole('button', { name: 'Commit' }).click();
await expect(page.getByText('Waiting for your wallet')).toBeVisible();
await wallet.release('signTx');
```

Wallet errors are plain `{ code, info }` objects as CIP-30 requires, so a dApp that shows `err.message` shows nothing. That is the most common bug these tests find. The full list is in [User-side failures](docs/recipes.md#user-side-failures) and the [quirk catalogue](quirks/README.md).

### 4. Transactions

Two questions decide how a transaction test is wired, answer them for your dApp first:

- **Where does the builder get its inputs?** The wallet's UTxOs exist only in the wallet. A builder connected to the CIP-30 api reads them through `getUtxos()` and works. One that looks the address up at an indexer finds nothing.
- **Who submits?** The wallet's `submitTx` records the transaction and never reaches a chain. A library or backend that submits on its own has to be intercepted with `page.route`.

The details and a recipe per library follow in [Building and submitting transactions](#building-and-submitting-transactions). A test then proves the signature instead of counting calls:

```ts
// tests/commit.spec.ts
import { test, expect, expectSignedBy } from 'cip30-test-wallet/playwright';

test.use({ walletOptions: { name: 'eternl', networkId: 0, utxos: [{ lovelace: 10_000_000 }] } });

test('commit writes the expected metadata', async ({ page, wallet }) => {
  await page.goto('/commit');
  await page.getByRole('button', { name: 'Connect' }).click();
  await page.getByRole('button', { name: 'Commit' }).click();
  await expect(page.getByText('Commit submitted')).toBeVisible(); // the click does not wait for signing

  expect(await wallet.calls('signTx')).toHaveLength(1);
  const tx = await wallet.lastSubmittedTx();
  expectSignedBy(tx!, wallet);
});
```

### 5. Pages behind a wallet login, and the deployment

- A dApp that logs in with a signed message becomes testable behind the login, see [Pages behind a wallet login](#pages-behind-a-wallet-login).
- `npx cip30-test-wallet doctor <url>` checks the deployed site for the content security policy and detection problems that break wallets in mobile in-app browsers, see [doctor](#doctor).
- Let a coding agent run and extend these tests on its own, see [CI and coding agents](#ci-and-coding-agents).

The full option and handle reference is in [docs/fixture-api.md](docs/fixture-api.md).

## Building and submitting transactions

The wallet's UTxOs are synthetic, they exist inside the wallet and on no chain. Three things follow for a dApp under test:

- Build from the wallet's `getUtxos()`. Evolution SDK, Mesh and Lucid Evolution do that when they are connected to the CIP-30 api. A builder that looks the address up at a chain indexer finds nothing.
- Protocol parameters still come from the network. Serve a recorded answer with `page.route` and the test runs offline.
- Nothing reaches a chain. `submitTx` only records the transaction. A library or backend that submits on its own has to be intercepted with `page.route`, then `expectSignedBy` proves the transaction it would have sent.

Tested, complete recipes in [docs/recipes.md](docs/recipes.md):

- By library: [Evolution SDK](docs/recipes.md#evolution-sdk), [Mesh](docs/recipes.md#mesh), [Lucid Evolution](docs/recipes.md#lucid-evolution), and how to [bundle them for a test page](docs/recipes.md#bundling-a-dapp-for-the-test-page)
- [A backend or provider that submits](docs/recipes.md#a-backend-or-provider-that-submits)
- [Protocol parameters offline](docs/recipes.md#protocol-parameters-offline)
- [User-side failures](docs/recipes.md#user-side-failures): declined, hanging, wrong network, late injection
- [Reading the journal](docs/recipes.md#reading-the-journal) and [signing in with a message](docs/recipes.md#signing-in-with-a-message)
- [Testing a wallet module directly on a dev server](docs/recipes.md#testing-a-wallet-module-directly-on-a-dev-server)

## CI and coding agents

An extension wallet asks for approval in its own popup, usually behind a password, so every connect and every signature needs a human. This wallet answers inside the page. A CI job or a coding agent that drives a browser can connect, sign and submit in one unattended run, with no seed to guard and no funds to lose. The default mnemonic is a public test vector.

Everything the run produces is readable by a program:

- The journal (`wallet.calls()`) lists every CIP-30 call with its arguments, result or error.
- `expectSignedBy` and `expectSignedData` fail with a concrete reason when a signature does not verify.
- Wallet errors are CIP-30 `{ code, info }` objects. Harness problems are `ChwError`s with a stable code such as `CHW_UNSUPPORTED_TX_FORM` or `CHW_UNRESOLVED_INPUT` and a hint on what to change.
- `doctor --json` prints the full report, and the exit code (0 clean, 1 findings, 2 run failed) is enough to gate a pipeline.

So an agent that changes a wallet flow can check its own work: write or extend a Playwright test, run it, read the journal and the assertion output, fix, repeat. A few lines in your project's agent instructions are enough:

```md
Wallet flows are tested with cip30-test-wallet (Playwright fixture, import from `cip30-test-wallet/playwright`).
After changing connect, signing or submit code, run the wallet tests and check `wallet.calls()` and `expectSignedBy`.
Reproduce user-side failures with `walletOptions.quirks` (see node_modules/cip30-test-wallet/quirks/README.md), never with a real wallet.
Before writing a transaction test, read node_modules/cip30-test-wallet/AGENTS.md and node_modules/cip30-test-wallet/docs/recipes.md: the wallet's UTxOs exist only in the wallet, and anything that submits outside the wallet must be intercepted.
Before deploying, run `npx cip30-test-wallet doctor <url> --json` and treat exit code 1 as a failed check.
```

### Agents that drive the browser themselves

An agent that browses through Playwright MCP, or any driver that loads a script before the page's own scripts, gets the wallet from a file:

```bash
npx cip30-test-wallet init-script --network 0 --out wallet.js
```

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--isolated", "--init-script", "/absolute/path/to/wallet.js"]
    }
  }
}
```

Every page the agent opens then has the wallet in `window.cardano`. The agent reads the journal and controls the wallet with its evaluate tool through `window.__chw`: `journal`, `setQuirk(name, value)`, `release('signTx')` and `reject('signTx')`. Quirks, UTxOs and a mnemonic from an environment variable go in through `--options` and `--mnemonic-env`. Tested with Playwright MCP against the demo dApp under a strict content security policy. Details in [docs/init-script.md](docs/init-script.md).

Inside your own Playwright code, without the test runner, the same wallet goes in through `page.addInitScript`:

```ts
import { initScript, prepareWallet } from 'cip30-test-wallet';

await page.addInitScript({ content: initScript(prepareWallet({ networkId: 0 }).config) });
```

## Pages behind a wallet login

Many dApps log in with a signed message (CIP-8 `signData`). The test wallet signs that message like a real wallet, so the dApp issues a real session, and every page behind the login becomes testable. Sign in once per role in a setup step, save the session with Playwright's `storageState`, and reuse it in the tests. That keeps the number of logins low, which matters because login endpoints are usually rate limited.

```ts
// tests/drep.setup.ts
import { test as setup } from 'cip30-test-wallet/playwright';

const mnemonic = process.env.E2E_DREP_MNEMONIC;
setup.skip(!mnemonic, 'needs E2E_DREP_MNEMONIC, a testnet wallet registered as DRep');
setup.use({ walletOptions: mnemonic ? { mnemonic } : {} });

setup('sign in as DRep', async ({ page }) => {
  await page.goto('/login?role=drep');
  await page.getByRole('button', { name: 'Sign in with wallet' }).click();
  await page.waitForURL('**/home/');
  await page.context().storageState({ path: 'playwright/.auth/drep.json' });
});
```

Tests that depend on this setup project start with `test.use({ storageState: 'playwright/.auth/drep.json' })`. Keep the auth folder out of version control.

What decides whether a login works:

- **Roles without chain state** work with any mnemonic, the default one included, for example a plain account login with the reward address.
- **Roles the dApp checks on chain** need a wallet that really has that role on the dApp's network, for example a DRep registered on preprod. Pass its mnemonic through an environment variable, never commit it. Its keys end up in traces like any other, so use a testnet wallet only.
- **Governance actions are signed.** Votes, vote delegation and DRep updates are signed with the right keys. `submitTx` still only records the transaction, so a vote never reaches the chain from a test.
- **Token-gated pages** that check ownership on chain, through an indexer or their backend, do not see the synthetic UTxOs, the address itself has to hold the tokens. Pages that read `getBalance` or `getUtxos` in the browser do see them.

The fixture injects into any URL, so this also works against a deployed site, not only a local dev server. The wallet's network has to match the site's. Against a mainnet site only flows that cost nothing make sense, such as a message-signing login, and only with a mnemonic that holds nothing. Remember that a production login creates real accounts and sessions on that site.

## Keys and secrets

The wallet's extended private keys are serialised into the page's init script by design, that is how an injected CIP-30 provider signs without a node process to call back into. So they appear in Playwright traces, HAR files and any dump of the page. The same holds for the file `init-script` writes, keep it out of version control. Use only throwaway mnemonics for tests, never one that holds real funds. The default mnemonic is the public CSL test vector and holds no funds.

## Defaults are spec-conformant, not convenient

Errors are plain `{ code, info }` objects, as CIP-30 requires, never `Error` instances. Code that reads `err.message` shows up immediately. `getUtxos()` returns `[]` for an empty wallet and `null` when the requested amount cannot be reached. Addresses are hex CBOR bytes. A test that is green with the defaults already tells you something.

One compatibility exception: `getCollateral()` without an argument means 5 ADA. CIP-30 calls that form possible but not specified, Mesh calls it this way and Lace answers it this way. An amount of 0 or above 5 ADA is InvalidRequest. Collateral comes from pure ADA UTxOs without datum or reference script, at most three: first in configuration order, then the largest ones if that is not enough. `null` when even that does not cover the amount.

## Supported transaction forms

The wallet decides what to sign for these body fields: inputs at key addresses, `required_signers`, withdrawals, certificates, voting procedures, proposal procedures, treasury value and donation, collateral inputs, collateral return and total collateral, plus outputs, fee, ttl, validity start, auxiliary data hash and network id. A requirement it does not own must already be covered by a valid witness in the transaction (multi-party flows), otherwise `signTx` refuses with `TxSignError` ProofGeneration. Anything else (script inputs, script credentials anywhere, guardrail scripts, mint, unknown keys) raises a harness diagnosis `ChwError` with code `CHW_UNSUPPORTED_TX_FORM` at `partialSign: false`. A harness diagnosis is never disguised as a wallet error. An input the mock ledger does not know raises `CHW_UNRESOLVED_INPUT` with a hint to add it to `utxos` or `foreignUtxos`.

Evolution SDK always calls `signTx(cbor, true)`, so with Evolution the form check above never refuses. The wallet signs only its own share and logs a `console.warn` naming every skipped form instead.

## Known consumer issues

A consumer SDK expecting real-wallet behaviour can still misbehave against a spec-conformant wallet. See [docs/known-consumer-issues.md](docs/known-consumer-issues.md), for example Evolution SDK's `cip30Wallet(api).rewardAddress()`, which rejects the hex-encoded reward address CIP-30 requires.

## The demo dApp

`examples/minimal-dapp` is a framework-free page served under a strict and a permissive Content Security Policy. It scans `window.cardano`, connects, checks the network, signs and submits a fixed transaction, casts a DRep vote, delegates its vote to its own DRep, signs a message with the stake key, and runs a DRep login that tries the bare DRep ID and the type 6 address in turn. `npm run serve:demo` starts it on port 4173, `npm run test:browser` runs the browser suite against it in Chromium, Firefox and WebKit. `npm run doctor:demo` runs `doctor --deep` against its strict, permissive and hashed variants in one go, arguments after `--` go to every run, for example `npm run doctor:demo -- --browser webkit`.

## doctor

```bash
npx cip30-test-wallet doctor https://your-dapp.example
npx cip30-test-wallet doctor https://your-dapp.example --deep --browser webkit --click '#connect' --expect '#wallet-found' --settle 3000
```

Static: secure context, every content security policy in headers and meta tags, and whether the effective script policy blocks `eval`, which is how some mobile wallet in-app browsers inject, Eternl iOS among them. Deep: when the page reads `window.cardano` and whether it retries, whether the policy really blocks `eval` inside a first-party script, and whether an injected wallet, optionally a late one, is detected. Exit 0 clean, 1 findings, 2 run failed. Details in [docs/doctor.md](docs/doctor.md).

A deep run against the strict variant of the demo dApp (`npm run serve:demo`), with a wallet that arrives after the page's only scan. Long explanations are shortened here:

```text
$ npx cip30-test-wallet doctor http://127.0.0.1:4173/strict/ --deep --inject-after 1000 --expect '#wallet-found'
cip30-test-wallet doctor  http://127.0.0.1:4173/strict/

Page
  status          200
  content type    text/html; charset=utf-8
  secure context  yes

Content security policy
  header  default-src 'none'
          script-src 'self'
          style-src 'self' 'unsafe-inline'
          connect-src 'self'
          base-uri 'none'
          form-action 'none'
  eval    blocked by policy

Deep run (chromium)
  window.cardano  accessed once, after 108 ms
  violations      script-src:eval:http://127.0.0.1:4173/strict/app.js:7
  eval probe      blocked
  injection       wallet injected at 1024 ms, present in window.cardano, 0 page reads
                    after that
  expect          #wallet-found not visible within 1500 ms

Findings (3 warnings)
  [warning] eval-blocked: eval is blocked by script-src from the header policy
    The effective script policy has no 'unsafe-eval'. Some mobile wallet in-app browsers
    inject their CIP-30 provider through eval, confirmed for Eternl iOS, [...]

  [warning] single-scan: window.cardano was read once, 108 ms after load
    One read and no retry within the observation window. [...]

  [warning] wallet-not-detected: the wallet was injected at 1024 ms but #wallet-found
            was not visible within 1500 ms
    The page read window.cardano 0 times after the injection. [...]

Result: findings above info, exit 1
```

The sections always come in this order: the page as fetched, its policies one directive per line, the browser measurements when `--deep` ran, the findings from error to info, and a result line with the exit code.

## Dependencies

Installed with the package:

- `@noble/curves`, `@noble/hashes` and `@scure/base`: Ed25519, Blake2b and bech32, pure TypeScript without WASM. Together with the package's own CBOR and signing code they are the whole page bundle. It contains no WASM and no `eval`, because both can fail under the same content security policy `doctor` diagnoses.
- `@scure/bip39`: checks the mnemonic and turns it into entropy. The package's own BIP32-Ed25519 code derives the CIP-1852 keys from it with the two `@noble` libraries, in Node only. None of this reaches the page.
- `@playwright/test`: optional peer, needed for the fixture and `doctor --deep`, not for the static `doctor`.

Used by the test suite only:

- Evolution SDK, `@emurgo/cardano-serialization-lib-nodejs` (CSL) and `@emurgo/cardano-message-signing-nodejs` are the reference implementations. Derived keys must match CSL byte for byte at every step of a few hundred seeded derivations, and match what Evolution derives. Addresses and signatures must match CSL byte for byte, and CSL must parse the UTxOs and witness sets the wallet returns. Body hashes and transaction ids must match Evolution, and Evolution must merge the witness sets without losing foreign witnesses. The COSE_Sign1 and COSE_Key that `signData` returns must match the message-signing library byte for byte. Both Emurgo libraries are Rust compiled to WASM, an independent codebase, so agreement with them is not agreement with ourselves. They are dev dependencies and are never installed by users.

The spike results the signing core was accepted on are in [docs/verification.md](docs/verification.md).

## Development

```bash
npm install
npx playwright install chromium firefox webkit
npm test              # core and page tests in Node
npm run typecheck
npm run build         # dist/node and dist/page.js
npm run test:browser  # builds first, then Playwright in three engines
npm run bundle:check  # the page bundle must stand alone: no Node, no WASM, no externals
```

### Releasing

Releases are published to npm by the release workflow, never from a local machine.

1. Bump the version on a branch with `npm version minor --no-git-tag-version` (or `patch`, or `prerelease --preid beta`), open a PR and squash merge it.
2. Tag the merge commit on `main` and push the tag: `git tag -a v0.4.0 -m v0.4.0 && git push origin v0.4.0`.
3. Approve the staged version on npmjs.com under Staged Packages (asks for 2FA). Only then is it installable.

The workflow checks that the tag matches `package.json` and sits on `main`, runs typecheck, unit tests, build and the bundle check, stages the version on npm with provenance and creates the GitHub release. A prerelease tag such as `v0.5.0-beta.1` goes to the npm dist-tag named after its identifier, `beta` here, and becomes a GitHub prerelease, a stable tag goes to `latest`. If the workflow fails after staging, approve the staged version first and then rerun it, it skips npm when that version already came from the same commit.

Related work: [cardano-test-wallet](https://github.com/cardanoapi/cardano-test-wallet) (MIT) is the conceptual predecessor, a simulated wallet built for GovTool. Sorbet and Cardano Dev Wallet are browser extensions for manual testing, with a human at the popup. This project is built for runs without one: CI pipelines and coding agents that drive a browser.

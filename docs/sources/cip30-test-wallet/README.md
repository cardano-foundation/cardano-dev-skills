<img src="https://raw.githubusercontent.com/Lichtstaub/cip30-test-wallet/main/media/logo.svg" width="96" height="96" alt="cip30-test-wallet logo: a wallet between code braces">

# cip30-test-wallet

[![CI](https://github.com/Lichtstaub/cip30-test-wallet/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Lichtstaub/cip30-test-wallet/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/cip30-test-wallet)](https://www.npmjs.com/package/cip30-test-wallet)
[![node](https://img.shields.io/node/v/cip30-test-wallet)](https://github.com/Lichtstaub/cip30-test-wallet/blob/main/package.json)

`cip30-test-wallet` reproduces real Cardano wallet failures in automated browser tests, with no node, faucet, extension, or shared chain state by default.

It injects a CIP-30 test wallet into the page under test. The wallet holds real keys, returns real UTxO CBOR, signs real transaction CBOR with a real Ed25519 signature, and records every call in a journal your test can read. A catalogue of quirks reproduces the failures that only show up on a user's machine: a wallet on the wrong network, a wallet that injects late, a user who declines or never answers.

![A Playwright test in the trace viewer: the test connects the demo dApp to the injected wallet, commits, and proves the submitted transaction carries the wallet's signature](https://raw.githubusercontent.com/Lichtstaub/cip30-test-wallet/main/media/trace-viewer.png)

A Playwright test in the trace viewer. The wallet is detected, connects on preprod and signs the commit transaction without a popup, and `expectSignedBy` proves the submitted transaction carries its signature.

**Status: 0.x.** The signing core, the Playwright fixture and the `doctor` command are covered by unit tests and by browser tests in Chromium, Firefox and WebKit, and they run in the end-to-end suites of real dApps. Until 1.0 a minor release can still change the API, the notes of each GitHub release say what changed.

The package also ships [AGENTS.md](https://github.com/Lichtstaub/cip30-test-wallet/blob/main/AGENTS.md), a short guide for coding agents that condenses the rules this README explains.

## What is in the box

- A CIP-30 provider for the page: `apiVersion`, `name`, `icon`, `supportedExtensions`, `enable`, `isEnabled`, and the api methods `getNetworkId`, `getUtxos` (with `amount` and `paginate`), `getBalance` (with native assets), `getCollateral`, `experimental.getCollateral`, `getUsedAddresses`, `getUnusedAddresses`, `getChangeAddress`, `getRewardAddresses`, `getExtensions`, `signTx`, `submitTx`, `signData`.
- The `cip95` namespace: `getPubDRepKey`, `getRegisteredPubStakeKeys`, `getUnregisteredPubStakeKeys`, `signData`.
- A Playwright fixture: `test.use({ walletOptions })` configures the wallet, `wallet` in the test reads the journal and flips quirks at runtime.
- `expectSignedBy(txHex, wallet, { roles? })`: proves the transaction your dApp submitted really carries the wallet's signature (payment by default, optionally stake and DRep) over its body hash. Recording `submitTx` alone proves nothing.
- `expectSignedData(result, expected)`: proves a `signData` or `cip95.signData` result the way a careful verifier does, checking the COSE signature, key and address.
- The quirk catalogue in [`quirks/`](quirks/README.md), a provenance note for every switch.
- `doctor`: a command line check of a deployed dApp for the secure-context and content-security-policy traps, with a browser mode that measures wallet detection.
- A ledger in Node: `submitTx` spends the inputs and creates the outputs of every transaction for the whole test, across reloads and origin changes, and `wallet.utxos()` reads it, see [Spec-conformant defaults](#spec-conformant-defaults).
- Ledger checks, opt in: with `walletOptions.ledger: { checks: true }` `submitTx` refuses what a Conway node refuses, with the node's rule names, and runs Plutus scripts locally within their declared ExUnits, see [Ledger checks](#ledger-checks).
- `attachWallet(page, options)` for Playwright code without the test runner, and `init-script` for drivers such as Playwright MCP, see [CI and coding agents](#ci-and-coding-agents).
- Chain mode, opt in: with `walletOptions.ledger.chain` the wallet reads its UTxOs and stake registration from Ogmios or Koios and `submitTx` submits for real, see [Chain mode](#chain-mode).

`signData` follows CIP-30 and CIP-8 byte for byte with Emurgo's message-signing library: payment key for base, pointer and enterprise addresses, stake key for reward addresses. CIP-95 is announced by default: `getPubDRepKey`, the registered and unregistered stake keys, and `cip95.signData` with the bare DRep ID or a type 6 address. `signTx` signs Conway governance transactions: stake and vote delegation certificates with the stake key, DRep registration, update and retirement and DRep votes with the DRep key. Pool and committee certificates are never witnessed by the wallet, as CIP-95 requires. The certificates 5 and 6 that Conway removed, genesis key delegation and move instantaneous rewards, are refused with `TxSignError` `DeprecatedCertificate` (3). The stake registration and deregistration certificates 0 and 1, which Conway kept, are still accepted.

## Not in the box yet

The wallet covers the whole CIP-30 api plus the CIP-95 extension, with one account: one base address, one reward address and the DRep key of that account. What it leaves out on purpose, any of it may come in a later release:

- **Transaction forms outside the [supported set](#supported-transaction-forms).** Inputs at Byron addresses, the pre-Conway `update` field, unknown body keys and unknown certificate or voter types make `signTx` raise `CHW_UNSUPPORTED_TX_FORM` at `partialSign: false`. The certificates 5 and 6 are refused with `TxSignError` `DeprecatedCertificate` (3), as CIP-95 requires. Pool and committee certificates are never witnessed by the wallet.
- **Other extensions and events.** CIP-95 is the only extension the wallet announces. It never raises `APIError` AccountChange (-4) and keeps its account and network for the whole test.
- **Hanging prompts other than `signTx`.** `signHangs` holds `signTx` only, `enable` and `signData` answer at once or with their rejection quirk.
- **Popups and new pages.** The fixture installs the wallet on the test's `page`. Popups and pages from `context.newPage()` get no wallet.
- **A node, by default.** `submitTx` records the transaction, applies it to the wallet's UTxOs and stake registration, and returns its id without talking to a node. Without a chain, fees, balance, witnesses, certificates and Plutus scripts are checked only with `walletOptions.ledger: { checks: true }`, see [Ledger checks](#ledger-checks), which also lists the rules that stay unchecked. Without the checks no Plutus script runs.
- **Parts of a real chain, in chain mode.** With `walletOptions.ledger.chain` the UTxOs come from Ogmios or Koios and `submitTx` submits for real, the node checks every transaction and runs its scripts. Other providers, rollbacks and UTxOs at the enterprise or pointer address of the wallet's keys are not covered, `signTx` on mainnet is locked by default, and the ledger checks, `utxos`, `foreignUtxos` and `stakeRegistered` are refused there, see [Chain mode](#chain-mode).
- **A ledger outside Node.** `init-script` keeps the ledger in the page, so it refuses the ledger checks and chain mode, and a reload resets the UTxOs to the configured ones.

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
test.use({ walletOptions: { quirks: { submitFails: true } } });       // the node refuses the transaction
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

- **Where does the builder get its inputs?** By default the wallet's UTxOs exist only in the wallet. A builder connected to the CIP-30 api reads them through `getUtxos()` and works. One that looks the address up at an indexer finds nothing. In chain mode the UTxOs are real, see [Chain mode](#chain-mode).
- **Who submits?** By default the wallet's `submitTx` records the transaction, applies it to the wallet's UTxOs and never reaches a chain. A library or backend that submits on its own has to be intercepted with `page.route`. In chain mode `submitTx` and a backend that submits both reach the chain, see [Chain mode](#chain-mode).

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

By default the wallet's UTxOs are synthetic, they exist inside the wallet and on no chain. Three things follow for a dApp under test:

- Build from the wallet's `getUtxos()`. Evolution SDK, Mesh and Lucid Evolution do that when they are connected to the CIP-30 api. A builder that looks the address up at a chain indexer finds nothing.
- Protocol parameters still come from the network. Serve a recorded answer with `page.route` and the test runs offline.
- Nothing reaches a chain. `submitTx` only records the transaction and applies it to the wallet's UTxOs. A library or backend that submits on its own has to be intercepted with `page.route`, then `expectSignedBy` proves the transaction it would have sent. In [chain mode](#chain-mode) the UTxOs are real, and both the wallet's `submitTx` and a backend that submits reach the chain.

Tested, complete recipes in [docs/recipes.md](docs/recipes.md):

- By library: [Evolution SDK](docs/recipes.md#evolution-sdk), [Mesh](docs/recipes.md#mesh), [Lucid Evolution](docs/recipes.md#lucid-evolution), and how to [bundle them for a test page](docs/recipes.md#bundling-a-dapp-for-the-test-page)
- [A backend or provider that submits](docs/recipes.md#a-backend-or-provider-that-submits)
- [Protocol parameters offline](docs/recipes.md#protocol-parameters-offline)
- [User-side failures](docs/recipes.md#user-side-failures): declined, hanging, wrong network, late injection
- [Reading the journal](docs/recipes.md#reading-the-journal) and [signing in with a message](docs/recipes.md#signing-in-with-a-message)
- [Testing a wallet module directly on a dev server](docs/recipes.md#testing-a-wallet-module-directly-on-a-dev-server)
- [Running inside an agent sandbox](docs/recipes.md#running-inside-an-agent-sandbox): browsers cannot start inside it on macOS

## CI and coding agents

An extension wallet asks for approval in its own popup, usually behind a password, so every connect and every signature needs a human. This wallet answers inside the page. A CI job or a coding agent that drives a browser can connect, sign and submit in one unattended run, with no seed to guard and no funds to lose. The default mnemonic is a public test vector.

Everything the run produces is readable by a program:

- The journal (`wallet.calls()`) lists every CIP-30 call with its arguments, result or error.
- `expectSignedBy` and `expectSignedData` fail with a concrete reason when a signature does not verify.
- Wallet errors are CIP-30 `{ code, info }` objects. Harness problems are `ChwError`s with a stable code such as `CHW_UNSUPPORTED_TX_FORM`, `CHW_UNRESOLVED_INPUT` or `CHW_UNRESOLVED_SCRIPT` and a hint on what to change.
- `doctor --json` prints the full report, and the exit code (0 clean, 1 findings, 2 run failed) is enough to gate a pipeline.

So an agent that changes a wallet flow can check its own work: write or extend a Playwright test, run it, read the journal and the assertion output, fix, repeat.

[examples/agent-instructions.md](https://github.com/Lichtstaub/cip30-test-wallet/blob/main/examples/agent-instructions.md) holds a few lines to copy into your project's own agent instructions file.

On macOS, Playwright browsers cannot start inside an agent sandbox such as Codex `--sandbox workspace-write`. Chromium, Firefox and WebKit all abort at launch because the sandbox blocks the window server, Playwright reports only a closed browser, and every abort opens a crash dialog. Browser tests and `doctor --deep` therefore run outside the sandbox, in the developer's own terminal or as a single command the developer approves. `doctor --deep` detects the Codex sandbox and stops with a hint instead of launching, see [Running inside an agent sandbox](docs/recipes.md#running-inside-an-agent-sandbox).

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

Inside your own Playwright code, without the test runner, `attachWallet(page, options)` installs the same wallet and returns the `wallet` handle. It keeps the ledger in Node, like the fixture. Call it before the first navigation, once per page, and never on a page the `test` fixture already set up:

```ts
import { attachWallet } from 'cip30-test-wallet/playwright';

const wallet = await attachWallet(page, { networkId: 0 });
```

For other drivers, `page.addInitScript` takes the script directly. The ledger then lives in the page and a reload resets it to the configured UTxOs:

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
- **Governance actions are signed.** Votes, vote delegation and DRep updates are signed with the right keys. Without a chain provider `submitTx` never reaches a chain, so a vote is never cast from a test. In [chain mode](#chain-mode) on preprod or preview it is cast for real.
- **Token-gated pages** that check ownership on chain, through an indexer or their backend, do not see the synthetic UTxOs by default, the address itself has to hold the tokens. In chain mode the UTxOs are real. Pages that read `getBalance` or `getUtxos` in the browser do see them.

The fixture injects into any URL, so this also works against a deployed site, not only a local dev server. The wallet's network has to match the site's. Against a mainnet site only flows that cost nothing make sense, such as a message-signing login, and only with a mnemonic that holds nothing. Remember that a production login creates real accounts and sessions on that site.

## Keys and secrets

The wallet's extended private keys are serialised into the page's init script by design, that is how an injected CIP-30 provider signs without a node process to call back into. So they appear in Playwright traces, HAR files and any dump of the page. The same holds for the file `init-script` writes, keep it out of version control. Use only throwaway mnemonics for tests, never one that holds real funds. The default mnemonic is the public CSL test vector. Its keys are known to everyone, so whatever is sent to its addresses can be spent by anyone.

In [chain mode](#chain-mode) on a public network, use a mnemonic of your own and pass it through an environment variable. The default mnemonic is public, and its preprod address holds UTxOs other people sent there, which `getUtxos` then shows. A Koios `token` stays in Node, it never reaches the page, the journal or an error message.

## Spec-conformant defaults

Errors are plain `{ code, info }` objects, as CIP-30 requires, never `Error` instances. Code that reads `err.message` shows up immediately. `getUtxos()` returns `[]` for an empty wallet and `null` when the requested amount cannot be reached. Addresses are the hex of the raw address bytes, never bech32. A test that is green with the defaults already tells you something.

One compatibility exception: `getCollateral()` without an argument means 5 ADA. CIP-30 calls that form possible but not specified, Mesh calls it this way and Lace answers it this way. An amount of 0 or above 5 ADA is InvalidRequest. Collateral comes from pure ADA UTxOs without datum or reference script, at most three: first in the order `getUtxos` lists them, then the largest ones if that is not enough. The limit of three stays fixed, `ledger.protocolParams.maxCollateralInputs` changes only the ledger checks. `null` when even that does not cover the amount.

State after submit: a submitted transaction spends its inputs and creates its outputs, a phase 2 invalid one spends only its collateral. `getUtxos`, `getBalance` and `getCollateral` show the result, CIP-95 reflects stake registration and unregistration certificates. The base address counts as used once the configuration gives it UTxOs or while the ledger holds one. In the Playwright fixture this state lives in Node for the whole test and survives reloads, navigations and origin changes. `wallet.utxos()` reads it. The journal still starts fresh with every page load. `walletOptions.ledger: { state: false }` keeps the configured UTxOs and stake registration as before 0.8.0. A spent output stays known for `signTx`. Without the ledger checks the wallet also accepts a second spend of it, which a node would refuse. In chain mode the chain refuses it.

## Ledger checks

With `walletOptions.ledger: { checks: true }` the wallet's `submitTx` refuses a transaction a Conway node would refuse, before anything changes. The dApp receives `TxSendError` Failure, the plain object `{ code: 2, info }`, and `info` names every failed rule the way a node reports it:

```text
ConwayApplyTxError [ConwayUtxowFailure (UtxoFailure (FeeTooSmallUTxO (Mismatch (RelGTEQ) {supplied: Coin 150000, expected: Coin 170000})))]
```

Match on the rule name. Ogmios and Blockfrost wrap the same rules in formats of their own, so the whole string differs between providers. In [chain mode](#chain-mode) the wallet turns the refusal of Ogmios into this format, with Koios as well, which hands submits to its Ogmios. A refused transaction leaves the UTxOs, the stake registration and `wallet.utxos()` as they were, and `lastSubmittedTx()` skips it. `signTx` checks nothing, the checks run at `submitTx`.

| Check | Rule a node names |
|---|---|
| Inputs, collateral inputs and reference inputs exist and are unspent | `BadInputsUTxO`, or only `ConwayMempoolFailure` when every spend input is already spent |
| Inputs, withdrawals and refunds equal outputs, fee, deposits and donation, mint included | `ValueNotConservedUTxO` |
| Fee at least the minimum from size, declared ExUnits and reference scripts | `FeeTooSmallUTxO` |
| Size, ExUnits, output value size and minimum UTxO value | `MaxTxSizeUTxO`, `ExUnitsTooBigUTxO`, `OutputTooBigUTxO`, `BabbageOutputTooSmallUTxO` |
| Validity interval, when `currentSlot` is set | `OutsideValidityIntervalUTxO` |
| Network of outputs, withdrawals and the body | `WrongNetwork`, `WrongNetworkWithdrawal`, `WrongNetworkInTxBody` |
| Collateral | `TooManyCollateralInputs`, and with redeemers `NoCollateralInputs`, `InsufficientCollateral`, `CollateralContainsNonADA`, `IncorrectTotalCollateralField`, `ScriptsNotPaidUTxO` |
| Witnesses and scripts, native scripts evaluated | `MissingVKeyWitnessesUTXOW`, `InvalidWitnessesUTXOW`, `MissingScriptWitnessesUTXOW`, `ExtraneousScriptWitnessesUTXOW`, `ScriptWitnessNotValidatingUTXOW` |
| Metadata hash in the body against the auxiliary data | `MissingTxBodyMetadataHash`, `MissingTxMetadata`, `ConflictingMetadataHash` |
| Datums of Plutus spends: a V1 or V2 script input has a datum, a datum hash has its datum in the witness set, no witness datum that no spent input, output, collateral return or reference input asks for | `UnspendableUTxONoDatumHash`, `MissingRequiredDatums`, `NotAllowedSupplementalDatums` |
| One redeemer for every Plutus script the transaction needs, at the index the ledger orders it by | `ExtraRedeemers`, `MissingRedeemers` |
| Script data hash over redeemers, datums and the cost models of the languages in use | `ScriptIntegrityHashMismatch` |
| What running a script needs: its redeemer and a script context the ledger can build | `CollectErrors` with `NoRedeemer`, `BadTranslation` |
| Every Plutus script runs within the ExUnits its redeemer declares, the result has to match `is_valid` | `ValidationTagMismatch` with `FailedUnexpectedly` or `PassedUnexpectedly` |
| Stake, pool and DRep certificates and their deposits | `StakeKeyRegisteredDELEG`, `StakeKeyNotRegisteredDELEG`, `DepositIncorrectDELEG`, `RefundIncorrectDELEG`, `StakePoolNotRegisteredOnKeyPOOL`, `ConwayDRepAlreadyRegistered`, `ConwayDRepNotRegistered`, `ConwayDRepIncorrectDeposit`, `ConwayDRepIncorrectRefund` |
| Proposal deposits, and the account a proposal returns its deposit to is registered and on the wallet's network | `ProposalDepositIncorrect`, `ProposalReturnAccountDoesNotExist`, `ProposalProcedureNetworkIdMismatch` |
| Reference scripts at most 200 KiB | `ConwayTxRefScriptsSizeTooBig` |

A missing redeemer shows up twice, as `MissingRedeemers` and as `CollectErrors (NoRedeemer ...)`, the way a node reports it. Before any script runs, the wallet checks that the ledger can build the script context of every Plutus script the transaction needs: a Plutus V1 or V2 script sees no votes, proposals, treasury donation or current treasury value and no certificate other than a stake registration, unregistration or delegation to a pool and the two pool certificates, a V1 script no inline datum in an input, reference input or output, and from protocol 11 on the spend and reference inputs of a V3 script must not overlap. What fails is `CollectErrors (BadTranslation ...)`, reported next to every other failure, as on a node. The scripts run only when every other check passes. The wallet gives each script the ExUnits its redeemer declares as budget and evaluates it with the cost models and the protocol version of its parameters, in the slot calendar of `ledger.network`. A Plutus V3 script has to return unit (CIP-117), a V3 script that returns anything else fails. A transaction with `is_valid: false` passes only when one of its scripts fails, it then spends only its collateral.

Where the wallet differs from a node: with several failing scripts it names only the first. A script that runs out of its budget and would fail later anyway is reported with its failure, a node names the budget. A redeemer pointer in `MissingRedeemers`, `NoRedeemer` and `PlutusPurposeNotSupported` reads `ConwaySpending (AsIx 0)`, the position, where a node names the item itself, such as the input. The rule names are the same. The first field of `PlutusFailure` is a shortened text: the script language, the script hash, the evaluation error and the traces of the script, without the base64 script bytes, protocol version and arguments a node prints. Match on `ValidationTagMismatch` and `FailedUnexpectedly` instead of parsing that text.

Left unchecked: pool parameters (cost, reward account network, VRF key, retirement epoch), network IDs inside governance actions, the accounts of a treasury withdrawal proposal (their network and whether they are registered), duplicate certificates or proposals, withdrawal amounts against reward balances and whether the reward account is registered, a reward balance left at unregistration, whether a delegation target (pool or DRep) is registered, whether voters and governance actions exist, committee certificates, the treasury value, a validity interval reaching past what a node can map to time (`OutsideForecast` and, for a script context, `TimeTranslationPastHorizon`, the horizon comes from consensus), Plutus scripts inside the auxiliary data, metadata strings or byte strings longer than 64 bytes, anchor URLs longer than 128 bytes, the content of governance actions beyond their deposit and return account, such as the previous action id and the guardrail script hash, Plutus scripts that do not decode (`MalformedScriptWitnesses`, `MalformedReferenceScripts`, a transaction that runs such a script raises `CHW_EVALUATOR_FAILED`), a reference input at a Byron address in a transaction that runs a script, a script context input missing from the UTxO set (`TranslationLogicMissingInput`), a redeemer that points to nothing (`RedeemerPointerPointsToNothing`), and the second field of `PlutusFailure`, the node's encoded script context, which the wallet leaves empty. The value balance still counts withdrawals.

The wallet's own stake key starts registered with the key deposit when `stakeRegistered` is `true`, its DRep key when `ledger.drepRegistered` is `true`. Every other credential and every pool starts unregistered, so a delegation of another wallet's stake key, the retirement of a pool the test did not register and a proposal that returns its deposit to another wallet's reward account are refused, even where a node would accept them because that account is registered on chain. The protocol parameters default to mainnet or preprod by `networkId`, recorded on 2026-09-30, the preprod values also hold for preview. The cost models and protocol version 11, recorded on 2026-10-04, are the same on all three networks. `ledger.protocolParams` overrides single values, cost models in the form Koios returns them. `protocolMajorVersion` changes only how scripts are evaluated and, from 11 on, the check that the spend and reference inputs of a Plutus V3 script do not overlap. The rule names stay those of protocol 11. `ledger.currentSlot` sets the slot the validity interval is checked against. `ledger.network` picks the slot calendar that turns the validity interval into the time a script sees, `mainnet`, `preprod` or `preview`, by default preprod for `networkId` 0 and mainnet for 1. Every option is in [docs/fixture-api.md](docs/fixture-api.md):

```ts
test.use({ walletOptions: { ledger: { checks: true, currentSlot: 110_000_000, protocolParams: { keyDeposit: 3_000_000, priceMem: [577, 10_000] } } } });
```

A form the checks cannot judge (Byron addresses, bootstrap witnesses, the deprecated certificates 5 and 6 and everything `signTx` reports as unsupported except unknown certificate numbers, which are `APIError` InvalidRequest) makes `submitTx` raise `CHW_UNSUPPORTED_TX_FORM`, a harness diagnosis. `submitTx` also raises `CHW_EVALUATOR_UNAVAILABLE` when the Plutus evaluator cannot be loaded and `CHW_EVALUATOR_FAILED` with the evaluator's own message when it stops on a transaction without a failing script, both harness diagnoses. The checks run in Node, with the fixture and with `attachWallet`. `init-script` has no Node side and refuses `checks`.

## Chain mode

With `walletOptions.ledger.chain` the ledger in Node asks a real chain instead of keeping synthetic UTxOs. `getUtxos`, `getBalance` and `getCollateral` show the outputs at the wallet's base address on that chain, CIP-95 reads the stake registration from the chain, and `submitTx` hands the exact bytes to the chain. A dApp under test can then build from a chain indexer, submit through its backend and wait for confirmation like in production.

```ts
// A local devnet or a node of your own, through Ogmios over HTTP
test.use({ walletOptions: { ledger: { chain: { provider: 'ogmios', url: 'http://127.0.0.1:1337' } } } });

// preprod, preview or mainnet through Koios
test.use({ walletOptions: { mnemonic: process.env.PREPROD_MNEMONIC, ledger: { chain: { provider: 'koios', network: 'preprod' } } } });
```

| Field | Meaning |
|---|---|
| `provider: 'ogmios'`, `url` | Ogmios 6 or 7, JSON-RPC over HTTP. Meant for a devnet or a node of your own. For preprod, preview and mainnet use Koios: Ogmios asks the node for the UTxOs of an address, and the node searches its whole UTxO set for them, which is slow on a public network |
| `provider: 'koios'`, `network` | `'mainnet'`, `'preprod'` or `'preview'`. Mainnet needs `networkId` 1, the other two `networkId` 0 |
| `url` (Koios) | Defaults to `https://api.koios.rest/api/v1`, `https://preprod.koios.rest/api/v1` or `https://preview.koios.rest/api/v1` |
| `token` (Koios) | Sent as `Authorization: Bearer <token>`, so it may hold letters, digits and `-._~+/` with `=` at the end, as bearer tokens do. Koios answers without one, a token raises its rate limit |
| `allowMainnetSigning` | `true` lets `signTx` sign on mainnet, see below |

Chain mode runs in Node, with the fixture and with `attachWallet`. `init-script` refuses it. It cannot be combined with `utxos`, `foreignUtxos`, `stakeRegistered`, `ledger.state: false`, `ledger.checks: true` or the options that only apply with the checks (`protocolParams`, `currentSlot`, `drepRegistered`, `network`), the chain is the only source and the node does the checking. `prepareWallet` throws for each of them with its own message. `ledger.state: true` and `ledger.checks: false` may stay, they describe chain mode. Before the page loads, the fixture and `attachWallet` ask the provider which network it serves. A chain on another network than `networkId` throws with both values. With Koios the network magic has to match `network` as well, so a preview URL under `network: 'preprod'` fails with `CHW_CHAIN_UNAVAILABLE`.

**After a submit.** The wallet does not wait for the block. Right after `submitTx` it shows the spent inputs as gone and the new outputs as its own, so a follow-up transaction can spend the change at once, as with a wallet that watches its mempool. A transaction leaves this pending overlay as soon as the chain shows one of its inputs spent, by its own block or by another transaction, and from then on the chain alone decides. `wallet.utxos()` shows the same view as the page.

**Refusals.** A transaction the chain refuses comes back as `TxSendError` Failure `{ code: 2, info }`, with `info` in the format of the [ledger checks](#ledger-checks):

```text
ConwayApplyTxError [ConwayUtxowFailure (UtxoFailure (BadInputsUTxO ...))]
```

Ogmios, also the one behind Koios, reports one failure per transaction, the one with the highest priority, so `info` names that one where a node lists every failed rule. A double spend shows `BadInputsUTxO` without the `ValueNotConservedUTxO` a node adds. A transaction whose inputs are all spent already or never existed, a resubmit for example, is refused as `ConwayMempoolFailure` before any rule runs. A refusal code the wallet does not know comes back as `Ogmios <code>: <message>`, unchanged. A second `submitTx` of the same transaction goes to the chain again and gets the chain's answer.

**Errors of the harness.** When the provider cannot be reached, times out or answers with anything but a result or a refusal, reads and `submitTx` raise `ChwError` `CHW_CHAIN_UNAVAILABLE` with the provider, the method and the HTTP status, in the page with its `code` as well. An error of Ogmios' own JSON-RPC layer counts as well, for example a transaction it cannot decode in any era, since no ledger rule judged it. The pending overlay stays as it was, a later call works again once the provider is back. A submit that timed out may still have reached the node. The wallet does not count it as pending, the first read after its block shows it. The same holds for the rare answer that names another transaction id than the one the wallet computed: the node took a transaction, the wallet raises `CHW_CHAIN_UNAVAILABLE` and does not count it as pending.

**Mainnet.** On a chain that reports mainnet the wallet does not sign transactions by default. `signTx` throws `ChwError` `CHW_MAINNET_LOCKED` before any signature exists, at both `partialSign` values, after the checks that make a malformed transaction `APIError` InvalidRequest. `signData` stays available, so a message login against a mainnet site works. `submitTx` is not locked either: a transaction signed elsewhere still goes to mainnet. `allowMainnetSigning: true` lifts the lock on `signTx` for a test. The keys sit in the page as always, in traces and HAR files, and a signature on mainnet can move real funds.

Where chain mode differs from a wallet on a real network:

- Owned UTxOs are those at the base address of the account. Outputs to the enterprise or pointer address of the same key count only while they come from the wallet's own pending transactions.
- Rollbacks are not handled. A transaction the mempool drops without any of its inputs being spent stays in the pending overlay until the test ends.
- An address counts as used while it holds UTxOs. A wallet that spends everything reads as unused again.
- Tests that share a chain and a mnemonic share UTxOs. Give each test file its own `accountIndex`, or run them with one worker. With `fullyParallel: true` the tests inside one file run in parallel as well, `test.describe.configure({ mode: 'serial' })` keeps the tests of a file that spends one after the other.
- `signTx` throws `CHW_UNRESOLVED_INPUT` for an input the chain does not show unspent and the wallet has not seen in this test: another transaction spent it, or it never existed. `CHW_UNRESOLVED_SCRIPT` means the transaction neither attaches the script nor names a reference input that holds it. The hints in both messages to add an output to `utxos` or `foreignUtxos` do not apply in chain mode, both options are refused there.
- When Ogmios sends a native reference script as JSON clauses without its CBOR, the wallet encodes the clauses with definite lengths and shortest heads, as CSL writes them. A native script written in another encoding gets another hash, and `signTx` does not count it as provided.
- With `provider: 'ogmios'`, a stake key that is registered without any pool or DRep delegation reads as unregistered once its transaction is confirmed, because Ogmios 7.0.0 does not list such keys in its reward account summary. A key that is also delegated reads correctly. Koios is not affected.
- The wallet reads outputs at Byron addresses when a transaction spends them, it never asks for the UTxOs of a Byron address.
- Public Koios may answer from several instances. Right after a confirmation one read can still show a spent input or miss the change, the next read is consistent again.

[Testing against a local devnet](docs/recipes.md#testing-against-a-local-devnet) shows a Playwright setup that starts a devnet in Docker and funds the wallet in its genesis.

## Supported transaction forms

The wallet decides what to sign for these body fields: inputs at key and script addresses, reference inputs, `required_signers`, withdrawals, certificates, mint, voting procedures, proposal procedures, treasury value and donation, collateral inputs, collateral return and total collateral, plus outputs, fee, ttl, validity start, auxiliary data hash, script data hash and network id. A requirement it does not own must already be covered by a valid witness in the transaction (multi-party flows), otherwise `signTx` refuses with `TxSignError` ProofGeneration.

Scripts come from the witness set and from the reference scripts of inputs and reference inputs, as on chain, never from collateral inputs. A native script is evaluated: the wallet signs with every key of its own the script names (never for a constitutional committee credential), and at `partialSign: false` the script must hold with those keys plus the valid witnesses already in the transaction, validity start and ttl included. A Plutus script needs no wallet witness. `signTx` never runs it, `submitTx` runs it locally only with the [ledger checks](#ledger-checks), in [chain mode](#chain-mode) the node runs it. A script the transaction needs but does not provide raises `CHW_UNRESOLVED_SCRIPT` with a hint to attach it or to add the UTxO holding it as `scriptRef` to `utxos` or `foreignUtxos`. In chain mode name that UTxO as a reference input instead.

Anything else (Byron inputs, the pre-Conway update field, unknown body keys, certificates or voters) raises a harness diagnosis `ChwError` with code `CHW_UNSUPPORTED_TX_FORM` at `partialSign: false`. A harness diagnosis is never disguised as a wallet error. An input or reference input the mock ledger does not know raises `CHW_UNRESOLVED_INPUT` with a hint to add it to `utxos` or `foreignUtxos`. `CHW_UNRESOLVED_INPUT` and `CHW_UNRESOLVED_SCRIPT` come at both `partialSign` values: without the input or the script the wallet cannot tell its own share.

Evolution SDK always calls `signTx(cbor, true)`, so with Evolution the form check above never refuses: the wallet signs only its own share and logs a `console.warn` naming every skipped form instead. A missing input or script still raises `CHW_UNRESOLVED_INPUT` or `CHW_UNRESOLVED_SCRIPT`.

## Known consumer issues

A consumer SDK expecting real-wallet behaviour can still misbehave against a spec-conformant wallet. See [docs/known-consumer-issues.md](docs/known-consumer-issues.md), for example Evolution SDK's `cip30Wallet(api).rewardAddress()`, which rejects the hex-encoded reward address CIP-30 requires.

## The demo dApp

`examples/minimal-dapp` is a framework-free page served under several content security policies: strict, permissive, strict as a meta tag, report-only and hashed, plus a strict variant that answers with status 403 for the doctor tests. It scans `window.cardano`, connects, checks the network, reads the balance, signs and submits a fixed transaction, casts a DRep vote, delegates its vote to its own DRep, signs a message with the stake key, and runs a DRep login that tries the bare DRep ID and the type 6 address in turn. `npm run serve:demo` starts it on port 4173, `npm run test:browser` runs the browser suite against it in Chromium, Firefox and WebKit. `npm run doctor:demo` runs `doctor --deep` against its strict, permissive and hashed variants in one go, arguments after `--` go to every run, for example `npm run doctor:demo -- --browser webkit`.

## In a production dApp

[DRepTalk](https://dreptalk.com), a Cardano governance forum built with Astro on Cloudflare Workers, runs its browser tests with this wallet in CI. The suite in [`e2e/`](https://github.com/katomm/dreptalk.com/tree/main/e2e) covers DRep and delegator sign-in with several wallet quirks, a vote delegation, and an info action submission whose signed transaction the test decodes and checks. The app's server reads Koios from a small local fixture server there, so the CI job needs no funds and no secrets. Runs against preprod are opt-in, by environment variable.

## doctor

```bash
npx cip30-test-wallet doctor https://your-dapp.example
npx cip30-test-wallet doctor https://your-dapp.example --deep --browser webkit --click '#connect' --expect '#wallet-found' --settle 3000
```

Static: secure context, every content security policy in headers and meta tags, and whether the effective script policy blocks `eval`, which is how some mobile wallet in-app browsers inject, Eternl iOS among them. Deep: when the page reads `window.cardano` and whether it retries, whether the policy really blocks `eval` inside a first-party script, and whether an injected wallet, optionally a late one, is detected. Exit 0 clean, 1 findings, 2 run failed. `npx cip30-test-wallet --help` prints the usage of `doctor` and `init-script`. Details in [docs/doctor.md](docs/doctor.md).

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

The sections always come in this order: the page as fetched, its policies one directive per line, the browser measurements when `--deep` ran, the findings from error to info, run errors when there were any, and a result line with the exit code.

## Dependencies

Installed with the package:

- `@noble/curves`, `@noble/hashes` and `@scure/base`: Ed25519, Blake2b and bech32, pure TypeScript without WASM. Together with the package's own CBOR and signing code they are the whole page bundle. It contains no WASM and no `eval`, because both can fail under the same content security policy `doctor` diagnoses.
- `@scure/bip39`: checks the mnemonic and turns it into entropy. The package's own BIP32-Ed25519 code derives the CIP-1852 keys from it with the two `@noble` libraries, in Node only. None of this reaches the page.
- `scalus`: a Plutus evaluator compiled to plain JavaScript, without WASM. The ledger checks run Plutus scripts with it. Only the ledger checks load it, in Node and only for a transaction that runs a Plutus script, never in the page and never for `doctor`.
- `@playwright/test`: optional peer, needed for the fixture and `doctor --deep`, not for the static `doctor`.

Used by the test suite only:

- Evolution SDK, `@emurgo/cardano-serialization-lib-nodejs` (CSL) and `@emurgo/cardano-message-signing-nodejs` are the reference implementations. Derived keys must match CSL byte for byte at every step of a few hundred seeded derivations, and match what Evolution derives. Addresses and signatures must match CSL byte for byte, and CSL must parse the UTxOs and witness sets the wallet returns. Body hashes and transaction ids must match Evolution, and Evolution must merge the witness sets without losing foreign witnesses. The COSE_Sign1 and COSE_Key that `signData` returns must match the message-signing library byte for byte. Both Emurgo libraries are Rust compiled to WASM, an independent codebase, so agreement with them is not agreement with ourselves. They are dev dependencies and are never installed by users.
- `@lucid-evolution/uplc`, aiken's Plutus evaluator compiled to WASM, is the second evaluator: for every test script the ExUnits it computes must equal those the ledger checks compute. The one exception is a V3 script that does not return unit, which aiken accepts and the ledger refuses.
- `@evolution-sdk/devnet` starts a cardano-node with Ogmios in Docker for the integration suite and the chain browser test. Its peers pin Evolution SDK 0.6.0 and two Evolution evaluators, all exact dev dependencies.

How the signing core and the browser injection were verified, and what each later feature is tested against, is in [docs/verification.md](docs/verification.md).

## Development

```bash
npm install
npx playwright install chromium firefox webkit
npm test              # core and page tests in Node
npm run typecheck
npm run build         # dist/node and dist/page.js
npm run test:browser  # builds first, then Playwright in three engines
npm run bundle:check  # the page bundle must stand alone: no Node, no WASM, no externals
npm run pack:check    # the packed tarball ships every entry point and listed file, and no sources or tests
npm run test:devnet          # integration tests against a local devnet, needs Docker
npm run test:devnet:browser  # the chain browser test in three engines against its own devnet
```

`npm run test:chain` runs the manual checks against public chains in `test-chain/`. Each one is skipped unless its environment variable is set, and none runs in CI.

### Releasing

Releases are published to npm by the release workflow, never from a local machine.

1. Bump the version on a branch with `npm version minor --no-git-tag-version` (or `patch`, or `prerelease --preid beta`). For release notes of your own, add them as `.github/release-notes/v<version>.md` in the same branch. Open a PR and squash merge it.
2. Tag the merge commit on `main` and push the tag: `git tag -a v<version> -m v<version> && git push origin v<version>`, for example `v0.10.0`.
3. Approve the staged version on npmjs.com under Staged Packages (asks for 2FA). Only then is it installable.

The workflow checks that the tag matches `package.json` and sits on `main`, runs typecheck, unit tests, build and the bundle check, stages the version on npm with provenance and creates the GitHub release, with the notes file of the tag or, without one, with notes generated from the merged pull requests. A prerelease tag such as `v0.5.0-beta.1` goes to the npm dist-tag named after its identifier, `beta` here, and becomes a GitHub prerelease, a stable tag goes to `latest`. If the workflow fails after staging, approve the staged version first and then rerun it, it skips npm when that version already came from the same commit.

Related work: [cardano-test-wallet](https://github.com/cardanoapi/cardano-test-wallet) (MIT) is the conceptual predecessor, a simulated wallet built for GovTool. Sorbet and Cardano Dev Wallet are browser extensions for manual testing, with a human at the popup. This project is built for runs without one: CI pipelines and coding agents that drive a browser.

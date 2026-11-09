# init-script

`init-script` writes the test wallet as one JavaScript file: the page bundle followed by the call that installs a configured wallet. It is meant for browser drivers that take an init script by path and run it before the page's own scripts, Playwright MCP's `--init-script` among them. Inside Playwright tests the fixture does the same job and is the better choice.

```bash
npx cip30-test-wallet init-script [--options <file.json>] [--network 0|1] [--name <name>] [--mnemonic-env <VAR>] [--out <file.js>]
```

| Flag | Meaning |
|---|---|
| `--options <file.json>` | Wallet options as JSON, the same shape as the fixture's `walletOptions`: `name`, `networkId`, `utxos`, `foreignUtxos`, `quirks`, `stakeRegistered`, `ledger` and the rest. `install: false`, `ledger.checks` and `ledger.chain` are refused |
| `--network 0\|1` | Overrides `networkId`. 0 is testnet, 1 is mainnet |
| `--name <name>` | Overrides the key under `window.cardano`, `chw` by default |
| `--mnemonic-env <VAR>` | Reads the mnemonic from this environment variable, so it never appears on the command line or in shell history |
| `--out <file.js>` | Writes the script to this file. Without it the script goes to stdout |

Flags win over the options file. Without any flag the script installs the default wallet on testnet. Exit 0 on success, 2 when an argument or the options file is invalid. `npx cip30-test-wallet init-script --help`, or `-h`, prints the usage of this command. `npx cip30-test-wallet --help` prints the usage of both commands, as does a call without arguments.

```json
{ "networkId": 0, "utxos": [{ "lovelace": 50000000 }], "quirks": { "signHangs": true } }
```

## Playwright MCP

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

Tested with `@playwright/mcp` 0.0.82 in Chrome against the demo dApp under its strict content security policy: detection, connect, `signTx` plus `submitTx`, `signData`, a `signHangs` quirk from the options file and its release through `window.__chw`. After changing options, regenerate the file and restart the MCP server.

## `window.__chw`

Without the fixture there is no `wallet` handle. The same controls are on `window.__chw`, reachable with any evaluate tool:

| Member | Meaning |
|---|---|
| `journal` | Array of `{ method, args, result?, error?, t }`, one entry per CIP-30 call, key material never included |
| `setQuirk(name, value)` | Flips a quirk at runtime. Throws for an unknown name, for the install-time quirks `lateInjection` and `answersEveryKey`, and for a `submitFails` value other than `true`, `false`, `undefined` or a non-empty string |
| `release('signTx')`, `reject('signTx')` | Ends a hanging `signTx` and returns how many calls it settled |
| `revoke()` | Disconnects the dApp in the current frame and resolves. Every api that `enable()` gave out there so far rejects each call with `APIError` Refused, `info` `the wallet revoked the connection`, a hanging `signTx` at once, and `isEnabled()` answers `false` until the next `enable()`. With `rememberEnable` it also deletes the `sessionStorage` key of the current origin. Other origins stay remembered, a script cannot reach their storage. Not journaled |

Like the fixture's journal, this state lives in the page and resets on every navigation. Read the journal before the agent navigates away.

## State after submit

Without the fixture there is no host to keep the ledger in. The wallet applies each submitted transaction to its UTxOs inside the page, until the page loads again. `--options` with `{ "ledger": { "state": false } }` switches this off.

The ledger checks (`ledger.checks`) and chain mode (`ledger.chain`) run in Node, so `init-script` refuses options that set them. Use the Playwright fixture or `attachWallet` for them.

## Remembered enable()

With `{ "rememberEnable": true }` in the options file the wallet remembers a successful `enable()` in the page's `sessionStorage`, under the key `__chw:enabled:<name>` of that origin. `isEnabled()` then answers `true` after a reload of the same tab and origin. A new tab starts without it. The page can delete the key, for example with `sessionStorage.clear()`, which takes effect from the next page load, the current document keeps a grant it already gave. `window.__chw.revoke()` deletes the key of the current origin and disconnects the current document at once. When the storage cannot be read or written the wallet remembers nothing and raises no error. The Playwright fixture keeps the grant in Node instead, where the page cannot clear it. Without the option the wallet reads and writes no storage.

## Keys

The file holds the wallet's extended private keys in plain text. Use a test mnemonic only and keep the file out of version control.

With `networkId` 1 and a mnemonic of your own the script's `signTx` throws `CHW_MAINNET_LOCKED`, unless the options file sets `allowMainnetSigning: true`. Then the command warns on stderr, stdout and the file stay the script.
